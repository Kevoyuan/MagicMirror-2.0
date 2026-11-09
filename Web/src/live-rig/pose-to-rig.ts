/**
 * W3a PURE pose -> rig engine. ORIGINAL, screen-aligned 2.5D articulation.
 *
 * This module contains NO DOM, Worker, MediaPipe, camera or Three.js side
 * effects. It turns the already-inferred 33 numerical MediaPipe landmarks of
 * ONE camera frame into a bounded, explicitly supported arm hierarchy.
 *
 * HONESTY CONTRACT
 * - Coordinates are DISPLAY PIXELS in the same object-fit:cover / mirror
 *   space as the existing procedural proxy (`mapImageToViewport`).
 * - Normalized MediaPipe `z` is checked for finiteness ONLY. It is NEVER
 *   interpreted as measured camera depth or a 3D camera coordinate.
 * - No joint is invented. A forearm without a visible shoulder is drawn as
 *   an INDEPENDENT observed segment, never attached to a fabricated parent.
 * - No full body is required: each arm and each segment is gated separately.
 * - This is NOT anatomical AR, camera extrinsics, bone positions, skinning,
 *   inverse kinematics, clinical geometry or a medical device.
 */
import {
  mapImageToViewport, usable, type Focus, type PosePoint,
} from "../pose";
import { freshResult, type CapturedFrame } from "../telemetry";

export const RIG_LANDMARK_COUNT = 33;
/** Reuse the W1 viewer freshness contract instead of inventing another one. */
export const RIG_FRESHNESS_MS = 350;
export const RIG_DEFAULT_CONFIDENCE = 0.55;
export const RIG_DEFAULT_MAX_ANGLE_STEP = 1.15;
export const RIG_DEFAULT_STABILIZATION = 0.35;
export const RIG_MIN_SEGMENT_PX = 4;
export const RIG_DISCONTINUITY_WINDOW_MS = 250;

export type RigSide = "left" | "right";
export type RigPart = "upperArm" | "forearm";
export type RigStatus = "tracking" | "partial" | "none" | "rejected";

export interface RigPoint {
  readonly x: number;
  readonly y: number;
}

/** MediaPipe PoseLandmarker indices; anatomical LEFT/RIGHT are the person's. */
export const RIG_ARM_LANDMARKS: Readonly<Record<RigSide, Readonly<{
  shoulder: number; elbow: number; wrist: number;
}>>> = {
  left: { shoulder: 11, elbow: 13, wrist: 15 },
  right: { shoulder: 12, elbow: 14, wrist: 16 },
};

export interface RigObservation {
  readonly landmarks: readonly PosePoint[] | null;
  readonly session: number;
  readonly frameId: number;
  readonly capturedAtMs: number;
  readonly nowMs: number;
  readonly sourceWidth: number;
  readonly sourceHeight: number;
  readonly viewportWidth: number;
  readonly viewportHeight: number;
  readonly mirrored: boolean;
  readonly focus: Focus;
  readonly minConfidence?: number;
}

export interface RigOptions {
  readonly minConfidence?: number;
  readonly minSegmentPx?: number;
  readonly maxAngleStepRadians?: number;
  readonly stabilizationAlpha?: number;
  readonly maxDelayMs?: number;
}

type ResolvedOptions = Required<RigOptions>;

export interface RigSegmentState {
  readonly side: RigSide;
  readonly part: RigPart;
  readonly start: RigPoint;
  readonly end: RigPoint;
  /** Absolute direction in display space, atan2(dy, dx), wrapped to [-pi, pi]. */
  readonly angleRadians: number;
  /** Forearm angle relative to its REAL parent upper arm; null when independent. */
  readonly parentRelativeRadians: number | null;
  readonly lengthPx: number;
  /** Explicit length/scale handling: lengthPx / viewport-derived reference. */
  readonly scale: number;
  readonly confidence: number;
  readonly hierarchyAttached: boolean;
}

export interface RigArmState {
  readonly side: RigSide;
  readonly shoulder: RigPoint | null;
  readonly elbow: RigPoint | null;
  readonly wrist: RigPoint | null;
  readonly upper: RigSegmentState | null;
  readonly fore: RigSegmentState | null;
  readonly visibleSegments: number;
  readonly reasons: readonly string[];
}

export interface RigFrame {
  readonly session: number;
  readonly frameId: number;
  readonly capturedAtMs: number;
  readonly mirrored: boolean;
  readonly focus: Focus;
  readonly arms: Readonly<Record<RigSide, RigArmState>>;
  /** Stable root: shoulder midpoint, one visible shoulder, or null. */
  readonly pivot: RigPoint | null;
  readonly visibleSegments: number;
  readonly status: RigStatus;
  readonly reasons: readonly string[];
}

/** Wrap to [-pi, pi); nonfinite input stays nonfinite so callers fail closed. */
export function wrapRadians(angle: number): number {
  if (!Number.isFinite(angle)) return Number.NaN;
  const twoPi = Math.PI * 2;
  return ((angle + Math.PI) % twoPi + twoPi) % twoPi - Math.PI;
}

export function shortestAngleDelta(from: number, to: number): number {
  return wrapRadians(to - from);
}

export function displayDirection(start: RigPoint, end: RigPoint): number {
  return Math.atan2(end.y - start.y, end.x - start.x);
}

function resolveOptions(options: RigOptions, observation?: RigObservation): ResolvedOptions {
  const minConfidence = observation?.minConfidence ?? options.minConfidence ?? RIG_DEFAULT_CONFIDENCE;
  const minSegmentPx = options.minSegmentPx ?? RIG_MIN_SEGMENT_PX;
  const maxAngleStepRadians = options.maxAngleStepRadians ?? RIG_DEFAULT_MAX_ANGLE_STEP;
  const stabilizationAlpha = options.stabilizationAlpha ?? RIG_DEFAULT_STABILIZATION;
  const maxDelayMs = options.maxDelayMs ?? RIG_FRESHNESS_MS;
  return {
    minConfidence: clamp(minConfidence, 0, 1),
    minSegmentPx: Math.max(1, minSegmentPx),
    maxAngleStepRadians: Math.max(0.05, maxAngleStepRadians),
    stabilizationAlpha: clamp(stabilizationAlpha, 0, 1),
    maxDelayMs: Math.max(1, maxDelayMs),
  };
}

function clamp(value: number, low: number, high: number): number {
  return Number.isFinite(value) ? Math.min(high, Math.max(low, value)) : low;
}

function confidenceOf(point: PosePoint): number {
  const value = point.visibility ?? point.presence ?? 0;
  return Number.isFinite(value) ? value : Number.NaN;
}

function emptyArm(side: RigSide, reasons: readonly string[] = []): RigArmState {
  return {
    side, shoulder: null, elbow: null, wrist: null,
    upper: null, fore: null, visibleSegments: 0, reasons,
  };
}

function rejectedFrame(observation: RigObservation, reasons: readonly string[]): RigFrame {
  return {
    session: observation.session,
    frameId: observation.frameId,
    capturedAtMs: observation.capturedAtMs,
    mirrored: observation.mirrored,
    focus: observation.focus,
    arms: { left: emptyArm("left"), right: emptyArm("right") },
    pivot: null,
    visibleSegments: 0,
    status: "rejected",
    reasons,
  };
}

function finiteObservationMeta(observation: RigObservation): boolean {
  const numbers = [
    observation.session, observation.frameId, observation.capturedAtMs,
    observation.nowMs, observation.sourceWidth, observation.sourceHeight,
    observation.viewportWidth, observation.viewportHeight,
  ];
  return numbers.every(Number.isFinite) &&
    observation.sourceWidth > 0 && observation.sourceHeight > 0 &&
    observation.viewportWidth > 0 && observation.viewportHeight > 0 &&
    Number.isInteger(observation.session) && observation.session >= 0 &&
    Number.isInteger(observation.frameId) && observation.frameId >= 1 &&
    typeof observation.mirrored === "boolean" &&
    (observation.focus === "whole" || observation.focus === "arms" ||
      observation.focus === "legs") &&
    (observation.minConfidence === undefined ||
      (Number.isFinite(observation.minConfidence) &&
        observation.minConfidence >= 0 && observation.minConfidence <= 1));
}

function project(
  point: PosePoint, observation: RigObservation, options: ResolvedOptions
): RigPoint | null {
  if (!usable(point, options.minConfidence)) return null;
  const mapped = mapImageToViewport(
    point, observation.sourceWidth, observation.sourceHeight,
    observation.viewportWidth, observation.viewportHeight, observation.mirrored
  );
  if (!mapped || !Number.isFinite(mapped.x) || !Number.isFinite(mapped.y)) return null;
  return { x: mapped.x, y: mapped.y };
}

function referenceLengthPx(observation: RigObservation): number {
  return Math.max(8, Math.min(observation.viewportWidth, observation.viewportHeight) * 0.14);
}

function makeSegment(
  side: RigSide,
  part: RigPart,
  start: RigPoint,
  end: RigPoint,
  confidence: number,
  observation: RigObservation,
  options: ResolvedOptions,
  parent: RigSegmentState | null,
  reasons: string[]
): RigSegmentState | null {
  const lengthPx = Math.hypot(end.x - start.x, end.y - start.y);
  if (!Number.isFinite(lengthPx) || lengthPx < options.minSegmentPx) {
    reasons.push(`${side}:${part}:DEGENERATE_SEGMENT`);
    return null;
  }
  const angleRadians = displayDirection(start, end);
  if (!Number.isFinite(angleRadians)) {
    reasons.push(`${side}:${part}:NONFINITE_ANGLE`);
    return null;
  }
  const parentRelativeRadians = part === "forearm" && parent
    ? shortestAngleDelta(parent.angleRadians, angleRadians)
    : null;
  return {
    side, part, start, end, angleRadians, parentRelativeRadians,
    lengthPx,
    scale: clamp(lengthPx / referenceLengthPx(observation), 0.01, 100),
    confidence,
    hierarchyAttached: part === "upperArm" ? true : parent !== null,
  };
}

function buildArm(
  side: RigSide,
  points: readonly PosePoint[],
  observation: RigObservation,
  options: ResolvedOptions
): RigArmState {
  const reasons: string[] = [];
  const index = RIG_ARM_LANDMARKS[side];
  const rawShoulder = points[index.shoulder];
  const rawElbow = points[index.elbow];
  const rawWrist = points[index.wrist];

  const shoulder = project(rawShoulder, observation, options);
  const elbow = project(rawElbow, observation, options);
  const wrist = project(rawWrist, observation, options);
  if (!shoulder) reasons.push(`${side}:SHOULDER_UNAVAILABLE`);
  if (!elbow) reasons.push(`${side}:ELBOW_UNAVAILABLE`);
  if (!wrist) reasons.push(`${side}:WRIST_UNAVAILABLE`);

  let upper: RigSegmentState | null = null;
  let fore: RigSegmentState | null = null;
  if (shoulder && elbow) {
    upper = makeSegment(
      side, "upperArm", shoulder, elbow,
      Math.min(confidenceOf(rawShoulder), confidenceOf(rawElbow)),
      observation, options, null, reasons
    );
  }
  if (elbow && wrist) {
    fore = makeSegment(
      side, "forearm", elbow, wrist,
      Math.min(confidenceOf(rawElbow), confidenceOf(rawWrist)),
      observation, options, upper, reasons
    );
  }
  const visibleSegments = (upper ? 1 : 0) + (fore ? 1 : 0);
  return { side, shoulder, elbow, wrist, upper, fore, visibleSegments, reasons };
}

/**
 * PURE single-frame transform. Does not keep history and never mutates input.
 * The returned frame is safe to render directly, but production code should
 * use `LiveRigTracker` so session/ordering/freshness/angle guards also apply.
 */
export function computeRigFrame(
  observation: RigObservation, options: RigOptions = {}
): RigFrame {
  const resolved = resolveOptions(options, observation);
  if (!finiteObservationMeta(observation)) {
    return rejectedFrame(observation, ["INVALID_OBSERVATION_META"]);
  }
  if (observation.focus === "legs") {
    // The W3a original rig is an ARM chain only; do not fabricate leg bones.
    return rejectedFrame(observation, ["REGION_NOT_SUPPORTED"]);
  }
  const points = observation.landmarks;
  if (!points || points.length !== RIG_LANDMARK_COUNT) {
    return rejectedFrame(observation, ["INVALID_LANDMARK_COUNT"]);
  }
  for (const point of points) {
    if (!point || ![point.x, point.y, point.z].every(Number.isFinite)) {
      return rejectedFrame(observation, ["NONFINITE_LANDMARK"]);
    }
  }

  const left = buildArm("left", points, observation, resolved);
  const right = buildArm("right", points, observation, resolved);
  const reasons = [...left.reasons, ...right.reasons];
  const visibleSegments = left.visibleSegments + right.visibleSegments;
  const shoulders = [left.shoulder, right.shoulder].filter(
    (point): point is RigPoint => point !== null
  );
  let pivot: RigPoint | null = null;
  if (shoulders.length === 2) {
    pivot = {
      x: (shoulders[0].x + shoulders[1].x) / 2,
      y: (shoulders[0].y + shoulders[1].y) / 2,
    };
  } else if (shoulders.length === 1) {
    pivot = { ...shoulders[0] };
  }
  const status: RigStatus = visibleSegments === 0
    ? "none"
    : left.visibleSegments === 2 && right.visibleSegments === 2
      ? "tracking" : "partial";
  return {
    session: observation.session,
    frameId: observation.frameId,
    capturedAtMs: observation.capturedAtMs,
    mirrored: observation.mirrored,
    focus: observation.focus,
    arms: { left, right },
    pivot,
    visibleSegments,
    status,
    reasons,
  };
}

/**
 * Bounded, optional stabilization with explicit reset semantics.
 * Owns ONLY transform history: camera/inference ownership stays in main.ts.
 */
export class LiveRigTracker {
  private session = -1;
  private lastFrameId = 0;
  private lastAcceptedAtMs = -Infinity;
  private paused = false;
  private mirrored: boolean | undefined;
  private stabilizationEnabled = true;
  private readonly angleHistory = new Map<string, number>();
  private pivotHistory: RigPoint | null = null;
  private readonly options: ResolvedOptions;

  constructor(options: RigOptions = {}) {
    this.options = resolveOptions(options);
  }

  /** Full reset: camera stop/restart, page hidden, or a replaced session. */
  reset(): void {
    this.session = -1;
    this.lastFrameId = 0;
    this.paused = false;
    this.mirrored = undefined;
    this.stabilizationEnabled = true;
    this.clearTransforms();
  }

  /** Drop transform history without breaking frame/session ordering. */
  clearTransforms(): void {
    this.lastAcceptedAtMs = -Infinity;
    this.angleHistory.clear();
    this.pivotHistory = null;
  }

  pause(): void {
    this.paused = true;
    this.clearTransforms();
  }

  resume(): void {
    this.paused = false;
    this.clearTransforms();
  }

  setStabilization(enabled: boolean): void {
    if (this.stabilizationEnabled === enabled) return;
    this.stabilizationEnabled = enabled;
    this.clearTransforms();
  }

  get currentSession(): number { return this.session; }
  get lastFrame(): number { return this.lastFrameId; }
  get isPaused(): boolean { return this.paused; }

  update(observation: RigObservation): RigFrame {
    if (this.paused) return rejectedFrame(observation, ["PAUSED"]);
    if (!finiteObservationMeta(observation)) {
      return rejectedFrame(observation, ["INVALID_OBSERVATION_META"]);
    }
    if (observation.session < this.session) {
      return rejectedFrame(observation, ["OLD_SESSION"]);
    }
    if (observation.session !== this.session) {
      this.session = observation.session;
      this.lastFrameId = 0;
      this.mirrored = observation.mirrored;
      this.clearTransforms();
    } else if (observation.mirrored !== this.mirrored) {
      // A camera flip reverses display space; never interpolate across it.
      this.mirrored = observation.mirrored;
      this.clearTransforms();
    }
    if (observation.frameId <= this.lastFrameId) {
      return rejectedFrame(observation, ["OUT_OF_ORDER_FRAME"]);
    }
    const captured: CapturedFrame = {
      frameId: observation.frameId,
      session: observation.session,
      capturedAtMs: observation.capturedAtMs,
      mediaTimeSeconds: 0,
      width: observation.sourceWidth,
      height: observation.sourceHeight,
    };
    if (!freshResult(captured, observation.session, observation.nowMs, this.options.maxDelayMs)) {
      return rejectedFrame(observation, ["STALE_RESULT"]);
    }

    const raw = computeRigFrame(observation, this.options);
    if (raw.status === "rejected") {
      this.clearTransforms();
      this.lastFrameId = observation.frameId;
      this.lastAcceptedAtMs = observation.nowMs;
      return raw;
    }
    if (raw.visibleSegments === 0) {
      // Tracking loss must NOT freeze or reuse any stale anatomy onscreen.
      this.clearTransforms();
      this.lastFrameId = observation.frameId;
      this.lastAcceptedAtMs = observation.nowMs;
      return { ...raw, reasons: [...raw.reasons, "NO_SUPPORTED_SEGMENTS"] };
    }

    const reasons = [...raw.reasons];
    const dt = observation.nowMs - this.lastAcceptedAtMs;
    const withinContinuityWindow = Number.isFinite(dt) && dt >= 0 &&
      dt < RIG_DISCONTINUITY_WINDOW_MS;
    const alpha = this.stabilizationEnabled ? this.options.stabilizationAlpha : 0;

    const stabilize = (
      side: RigSide, part: RigPart, segment: RigSegmentState | null
    ): RigSegmentState | null => {
      const key = `${side}:${part}`;
      if (!segment) {
        // Only this segment's history is dropped; the other arm stays stable.
        this.angleHistory.delete(key);
        return null;
      }
      const previous = this.angleHistory.get(key);
      let angle = segment.angleRadians;
      if (previous !== undefined && withinContinuityWindow) {
        const delta = shortestAngleDelta(previous, angle);
        if (Math.abs(delta) > this.options.maxAngleStepRadians) {
          // An impossible jump is hidden for this frame, not smoothed into
          // an invented intermediate bone position.
          this.angleHistory.delete(key);
          reasons.push(`${key}:ANGLE_DISCONTINUITY`);
          return null;
        }
        if (alpha > 0) angle = wrapRadians(previous + alpha * delta);
      }
      this.angleHistory.set(key, angle);
      return { ...segment, angleRadians: angle };
    };

    const buildSide = (side: RigSide): RigArmState => {
      const arm = raw.arms[side];
      const upper = stabilize(side, "upperArm", arm.upper);
      const fore = stabilize(side, "forearm", arm.fore);
      const attachedFore = fore && upper && fore.hierarchyAttached
        ? {
          ...fore,
          parentRelativeRadians: shortestAngleDelta(
            upper.angleRadians, fore.angleRadians
          ),
        }
        : fore;
      const visible = (upper ? 1 : 0) + (attachedFore ? 1 : 0);
      return {
        ...arm, upper, fore: attachedFore, visibleSegments: visible,
        reasons: [...arm.reasons],
      };
    };
    const arms = { left: buildSide("left"), right: buildSide("right") };

    let pivot = raw.pivot;
    if (pivot && this.pivotHistory && withinContinuityWindow && alpha > 0) {
      // Absolute interpolation, never accumulated: no positional drift.
      pivot = {
        x: this.pivotHistory.x + alpha * (pivot.x - this.pivotHistory.x),
        y: this.pivotHistory.y + alpha * (pivot.y - this.pivotHistory.y),
      };
    }
    this.pivotHistory = pivot ? { ...pivot } : null;
    this.lastFrameId = observation.frameId;
    this.lastAcceptedAtMs = observation.nowMs;

    const visibleSegments = arms.left.visibleSegments + arms.right.visibleSegments;
    const status: RigStatus = visibleSegments === 0 ? "none"
      : arms.left.visibleSegments === 2 && arms.right.visibleSegments === 2
        ? "tracking" : "partial";
    return {
      ...raw, arms, pivot, visibleSegments, status, reasons,
    };
  }
}
