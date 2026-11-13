import type { PosePoint } from "./pose";
import type { CapturedFrame } from "./telemetry";

export type WorkerInput =
  | { kind: "init"; wasmURL: string; modelURL: string }
  | ({ kind: "frame"; bitmap: ImageBitmap } & CapturedFrame);

export type WorkerOutput =
  | { kind: "ready" }
  | { kind: "fatal"; message: string }
  | ({ kind: "result"; inferredInMs: number; landmarks: PosePoint[] | null; worldLandmarks?: PosePoint[] | null } & CapturedFrame);

/**
 * This schema transfers only numerical image + hip-relative world landmarks back out.
 * World data is a MODEL ESTIMATE, not calibrated camera depth.
 * The camera image bitmap is explicitly closed by the worker.
 */
