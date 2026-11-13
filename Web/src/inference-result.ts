import type { WorkerOutput } from "./inference-protocol";
import type { PosePoint } from "./pose";

/**
 * W1c pure gate for MediaPipe worker messages. No DOM, Worker, camera or
 * MediaPipe side effects, so the fail-closed contract can be unit tested.
 *
 * A worker can initialize successfully and still crash, stall or reject an
 * ImageBitmap. Any result that arrives AFTER such a failure belongs to an
 * old frame/session and MUST NOT be drawn as a reused pose. This gate also
 * refuses results carrying malformed timing, geometry or landmark numbers.
 */
export interface WorkerResultState {
  readonly closed: boolean;
  readonly ready: boolean;
  /** True while the main-thread fallback model is being created. */
  readonly recovering: boolean;
  readonly mode: "worker" | "main";
  readonly workerAlive: boolean;
  /** Invalidated (set < 1) by fail()/close() so late results never match. */
  readonly pendingFrameId: number;
  readonly currentSession: number;
}

export type WorkerMessageDecision = "accept" | "ignore" | "fatal";

/** PoseLandmarker VIDEO estimates at most 33 landmarks for ONE person. */
export const MAX_WORKER_LANDMARKS = 33;

function finite(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}
function optionalFinite(value: unknown): boolean {
  return value === undefined || finite(value);
}
function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return value as Record<string, unknown>;
}
function validLandmarks(value: unknown): value is PosePoint[] | null {
  // `null` is the one honest "no pose detected" value. The worker sends a
  // full 33-point list otherwise; an empty list is a corrupt payload.
  if (value === null) return true;
  if (!Array.isArray(value) || value.length === 0 || value.length > MAX_WORKER_LANDMARKS) return false;
  return value.every((point: unknown) => {
    if (!point || typeof point !== "object" || Array.isArray(point)) return false;
    const p = asRecord(point);
    return finite(p.x) && finite(p.y) && finite(p.z) &&
      optionalFinite(p.visibility) && optionalFinite(p.presence);
  });
}

/**
 * Missing world points preserve 2D tracking. Malformed PRESENT world payloads
 * must be rejected before entering local W3b diagnostics.
 */
function validWorldLandmarks(value: unknown): boolean {
  if (value === undefined || value === null) return true;
  return Array.isArray(value) && value.length === 33 &&
    value.every((point: unknown) => {
      const p = asRecord(point);
      return finite(p.x) && finite(p.y) && finite(p.z) &&
        Math.abs(p.x) <= 100 && Math.abs(p.y) <= 100 && Math.abs(p.z) <= 100 &&
        optionalFinite(p.visibility) && optionalFinite(p.presence);
    });
}

/**
 * "accept" draws the frame; "ignore" drops a stale/late/unknown message;
 * "fatal" fails the worker closed (hide geometry, then safe fallback).
 */
export function decideWorkerMessage(
  state: WorkerResultState, message: WorkerOutput
): WorkerMessageDecision {
  if (state.closed) return "ignore";
  const data = asRecord(message);
  if (data.kind === "fatal") {
    // A late fatal from an already terminated worker must not kill a session
    // that is recovering on the throttled main-thread fallback.
    if (!state.ready || !state.workerAlive || state.recovering ||
        state.mode !== "worker") return "ignore";
    return "fatal";
  }
  if (data.kind !== "result") return "ignore";
  // Fail closed after any crash, stall, close or fallback attempt.
  if (!state.ready || !state.workerAlive || state.recovering ||
      state.mode !== "worker" || state.pendingFrameId < 1) return "ignore";
  if (data.frameId !== state.pendingFrameId ||
      data.session !== state.currentSession) return "ignore";

  const width = data.width, height = data.height;
  const inferred = data.inferredInMs;
  if (!finite(data.capturedAtMs) || data.capturedAtMs < 0 ||
      !finite(data.mediaTimeSeconds) || data.mediaTimeSeconds < 0 ||
      !finite(width) || width <= 0 || !finite(height) || height <= 0 ||
      !finite(inferred) || inferred < 0 || !validLandmarks(data.landmarks) ||
      !validWorldLandmarks(data.worldLandmarks) ||
      (data.worldLandmarks != null &&
        (!Array.isArray(data.landmarks) || data.landmarks.length !== 33))) {
    return "fatal";
  }
  return "accept";
}

/** Local error text only; never includes camera image or pose data. */
export function workerFailureText(message: unknown): string {
  const data = asRecord(message);
  if (data.kind === "fatal" && typeof data.message === "string" && data.message) {
    return data.message;
  }
  return "Invalid MediaPipe worker result";
}
