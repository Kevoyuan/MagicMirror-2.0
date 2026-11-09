import type { PosePoint } from "./pose";
import type { CapturedFrame } from "./telemetry";

export type WorkerInput =
  | { kind: "init"; wasmURL: string; modelURL: string }
  | ({ kind: "frame"; bitmap: ImageBitmap } & CapturedFrame);

export type WorkerOutput =
  | { kind: "ready" }
  | { kind: "fatal"; message: string }
  | ({ kind: "result"; inferredInMs: number; landmarks: PosePoint[] | null } & CapturedFrame);

/**
 * This schema deliberately transfers only numerical landmarks back out.
 * The camera image bitmap is explicitly closed by the worker.
 */
