/// <reference lib="webworker" />
import { FilesetResolver, PoseLandmarker } from "@mediapipe/tasks-vision";
import type { WorkerInput, WorkerOutput } from "./inference-protocol";
import type { PosePoint } from "./pose";

const scope: DedicatedWorkerGlobalScope = self as DedicatedWorkerGlobalScope;
let task: PoseLandmarker | null = null;
let lastFrameId = -1;
let lastTimestamp = -Infinity;

function send(message: WorkerOutput): void { scope.postMessage(message); }
function errorText(err: unknown): string {
  return err instanceof Error ? err.message : "Unknown MediaPipe worker error";
}

scope.addEventListener("message", async (event: MessageEvent<WorkerInput>) => {
  const data = event.data;
  if (data.kind === "init") {
    try {
      const wasm = await FilesetResolver.forVisionTasks(data.wasmURL);
      task = await PoseLandmarker.createFromOptions(wasm, {
        baseOptions: { modelAssetPath: data.modelURL, delegate: "CPU" },
        runningMode: "VIDEO",
        numPoses: 1,
        minPoseDetectionConfidence: 0.5,
        minPosePresenceConfidence: 0.5,
        minTrackingConfidence: 0.5,
      });
      send({ kind: "ready" });
    } catch (err) {
      send({ kind: "fatal", message: errorText(err) });
    }
    return;
  }

  // Worker can be unavailable or still initializing. Reject without
  // processing rather than reuse stale image bytes or join another session.
  try {
    if (!task || data.frameId <= lastFrameId ||
        data.capturedAtMs <= lastTimestamp) {
      send({ kind: "fatal", message: "Worker received stale or unordered camera frame" });
      return;
    }
    lastFrameId = data.frameId;
    lastTimestamp = data.capturedAtMs;
    const started = performance.now();
    const result = task.detectForVideo(data.bitmap, data.capturedAtMs);
    const inferredInMs = Math.max(0, performance.now() - started);
    const landmarks = result.landmarks[0] as PosePoint[] | undefined;
    send({
      kind: "result", frameId: data.frameId, session: data.session,
      capturedAtMs: data.capturedAtMs, mediaTimeSeconds: data.mediaTimeSeconds,
      width: data.width, height: data.height,
      inferredInMs, landmarks: landmarks ? landmarks.map((p) => ({
        x: p.x, y: p.y, z: p.z, visibility: p.visibility, presence: p.presence,
      })) : null,
    });
  } catch (err) {
    send({ kind: "fatal", message: errorText(err) });
  } finally {
    data.bitmap.close();
  }
});
