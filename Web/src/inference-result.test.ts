import { describe, expect, it } from "vitest";
import type { WorkerOutput } from "./inference-protocol";
import type { PosePoint } from "./pose";
import {
  MAX_WORKER_LANDMARKS,
  decideWorkerMessage,
  workerFailureText,
  type WorkerResultState,
} from "./inference-result";

const point: PosePoint = { x: 0.5, y: 0.25, z: 0.1, visibility: 0.9, presence: 0.8 };

function state(overrides: Partial<WorkerResultState> = {}): WorkerResultState {
  return {
    closed: false,
    ready: true,
    recovering: false,
    mode: "worker",
    workerAlive: true,
    pendingFrameId: 7,
    currentSession: 3,
    ...overrides,
  };
}

function result(overrides: Record<string, unknown> = {}): WorkerOutput {
  return {
    kind: "result",
    frameId: 7,
    session: 3,
    capturedAtMs: 1200,
    mediaTimeSeconds: 2.4,
    width: 1280,
    height: 720,
    inferredInMs: 18.5,
    landmarks: [point],
    ...overrides,
  } as unknown as WorkerOutput;
}

function malformed(value: unknown): WorkerOutput {
  return value as WorkerOutput;
}

describe("W1c worker result gate (pure, synthetic)", () => {
  it("accepts the single in-flight frame from the live worker session", () => {
    expect(decideWorkerMessage(state(), result())).toBe("accept");
    expect(decideWorkerMessage(state(), result({ landmarks: null }))).toBe("accept");
    expect(decideWorkerMessage(state(), result({
      landmarks: Array.from({ length: MAX_WORKER_LANDMARKS }, () => point),
    }))).toBe("accept");
  });

  it("ignores non-result messages, including ready and unrecognised payloads", () => {
    expect(decideWorkerMessage(state(), { kind: "ready" })).toBe("ignore");
    expect(decideWorkerMessage(state(), malformed({ kind: "telemetry", x: 1 }))).toBe("ignore");
    expect(decideWorkerMessage(state(), malformed(null))).toBe("ignore");
    expect(decideWorkerMessage(state(), malformed("result"))).toBe("ignore");
    expect(decideWorkerMessage(state(), malformed(undefined))).toBe("ignore");
  });

  it("ignores stale, future and wrong-session results even when the data is well formed", () => {
    for (const message of [
      result({ frameId: 6 }),
      result({ frameId: 8 }),
      result({ frameId: 7, session: 2 }),
      result({ frameId: 7, session: 4 }),
    ]) {
      expect(decideWorkerMessage(state(), message)).toBe("ignore");
    }
  });

  it("ignores results that arrive after fail/close/recover, never reusing a stale pose", () => {
    const late = result();
    expect(decideWorkerMessage(state({ pendingFrameId: 0 }), late)).toBe("ignore");
    expect(decideWorkerMessage(state({ ready: false }), late)).toBe("ignore");
    expect(decideWorkerMessage(state({ workerAlive: false }), late)).toBe("ignore");
    expect(decideWorkerMessage(state({ closed: true }), late)).toBe("ignore");
    expect(decideWorkerMessage(state({ recovering: true }), late)).toBe("ignore");
    expect(decideWorkerMessage(state({ mode: "main" }), late)).toBe("ignore");
    // A fresh frame id allocated after recovery must not revive the old one.
    expect(decideWorkerMessage(state({ pendingFrameId: 9, currentSession: 3 }), late)).toBe("ignore");
  });

  it("fails closed on a live worker fatal but ignores late fatals from dead/recovering workers", () => {
    const fatal: WorkerOutput = { kind: "fatal", message: "Bitmap rejected" };
    expect(decideWorkerMessage(state(), fatal)).toBe("fatal");
    expect(decideWorkerMessage(state({ closed: true }), fatal)).toBe("ignore");
    expect(decideWorkerMessage(state({ workerAlive: false }), fatal)).toBe("ignore");
    expect(decideWorkerMessage(state({ ready: false }), fatal)).toBe("ignore");
    expect(decideWorkerMessage(state({ recovering: true }), fatal)).toBe("ignore");
    expect(decideWorkerMessage(state({ mode: "main" }), fatal)).toBe("ignore");
    expect(decideWorkerMessage(state({ pendingFrameId: 0 }), fatal)).toBe("fatal");
  });

  it("fails closed on malformed timing, geometry, inference cost or landmarks", () => {
    const bad = [
      result({ capturedAtMs: NaN }),
      result({ capturedAtMs: Infinity }),
      result({ capturedAtMs: -1 }),
      result({ mediaTimeSeconds: "2.4" }),
      result({ mediaTimeSeconds: -0.01 }),
      result({ width: 0 }), result({ width: -1280 }), result({ height: NaN }),
      result({ inferredInMs: -1 }), result({ inferredInMs: Infinity }),
      result({ landmarks: [] }),
      result({ landmarks: Array.from({ length: MAX_WORKER_LANDMARKS + 1 }, () => point) }),
      result({ landmarks: [{ x: NaN, y: 0, z: 0 }] }),
      result({ landmarks: [{ x: 0, y: 0, z: 0, visibility: "high" }] }),
      result({ landmarks: [null] }),
      result({ landmarks: "pose" }),
      result({ landmarks: [0.5, 0.2] }),
      result({ inferredInMs: undefined }),
      malformed({ kind: "result", frameId: 7, session: 3 }),
    ];
    for (const message of bad) {
      expect(decideWorkerMessage(state(), message)).toBe("fatal");
    }
  });

  it("checks frame/session identity before validating payloads", () => {
    // A corrupt result from an OLD frame is simply dropped, not treated as a
    // fresh fatal that would tear down a healthy session.
    expect(decideWorkerMessage(state(), result({ frameId: 6, landmarks: [] }))).toBe("ignore");
    expect(decideWorkerMessage(state({ ready: false }), result({ width: 0 }))).toBe("ignore");
  });

  it("keeps failure text local and free of camera or pose data", () => {
    expect(workerFailureText({ kind: "fatal", message: "WASM load failed" })).toBe("WASM load failed");
    expect(workerFailureText({ kind: "fatal", message: "" })).toBe("Invalid MediaPipe worker result");
    expect(workerFailureText(result({ width: 0 }))).toBe("Invalid MediaPipe worker result");
    expect(workerFailureText(null)).toBe("Invalid MediaPipe worker result");
    expect(workerFailureText({ kind: "fatal", message: 42 })).toBe("Invalid MediaPipe worker result");
  });
});
