import { FilesetResolver, PoseLandmarker } from "@mediapipe/tasks-vision";
import type { WorkerInput, WorkerOutput } from "./inference-protocol";
import type { PosePoint } from "./pose";
import { LatestOnlyGate, type InferenceFrame, type CapturedFrame } from "./telemetry";

export type InferenceMode = "worker" | "main";
export interface InferenceOptions {
  modelURL: string;
  wasmURL: string;
  onFrame: (frame: InferenceFrame) => void;
  onFatal: (error: Error) => void;
}
function asError(error: unknown): Error {
  return error instanceof Error ? error : new Error(String(error));
}

/** One camera session owns one inference engine, worker and frame gate. */
export class LivePoseInference {
  private worker?: Worker;
  private task?: PoseLandmarker;
  private readonly gate = new LatestOnlyGate(75);
  private closed = false;
  private ready = false;
  private workerBootTimer?: ReturnType<typeof setTimeout>;
  private abortWorkerBoot?: () => void;
  private workerDeadline?: ReturnType<typeof setTimeout>;
  private recovering = false;
  private pendingFrameId = 0;
  mode: InferenceMode = "main";
  droppedFrames = 0;

  constructor(private readonly options: InferenceOptions) {}

  async initialize(): Promise<InferenceMode> {
    if (this.closed) throw new Error("Camera session already closed");
    if (typeof Worker !== "undefined" && typeof createImageBitmap === "function" &&
        typeof OffscreenCanvas !== "undefined") {
      try {
        await this.openWorker();
        this.mode = "worker";
        this.ready = true;
        return this.mode;
      } catch (err) {
        console.warn("MediaPipe Web Worker unavailable; using main-thread fallback", err);
        this.worker?.terminate();
        this.worker = undefined;
      }
    }
    if (this.closed) throw new Error("Camera session stopped");
    await this.initializeMainTask();
    this.mode = "main";
    this.ready = true;
    return this.mode;
  }

  private async initializeMainTask(): Promise<void> {
    if (this.closed) throw new Error("Camera session stopped");
    const wasm = await FilesetResolver.forVisionTasks(this.options.wasmURL);
    const localTask = await PoseLandmarker.createFromOptions(wasm, {
      baseOptions: { modelAssetPath: this.options.modelURL, delegate: "CPU" },
      runningMode: "VIDEO",
      numPoses: 1,
      minPoseDetectionConfidence: 0.5,
      minPosePresenceConfidence: 0.5,
      minTrackingConfidence: 0.5,
    });
    if (this.closed) {
      localTask.close();
      throw new Error("Camera session stopped");
    }
    this.task = localTask;
  }

  private async openWorker(): Promise<void> {
    const worker = new Worker(new URL("./pose.worker.ts", import.meta.url), { type: "module" });
    this.worker = worker;
    await new Promise<void>((resolve, reject) => {
      const onMessage = (event: MessageEvent<WorkerOutput>) => {
        const message = event.data;
        if (message.kind === "ready") {
          cleanup();
          resolve();
        } else if (message.kind === "fatal") {
          cleanup();
          reject(new Error(message.message));
        }
      };
      const onError = (event: ErrorEvent) => {
        cleanup();
        reject(new Error(event.message || "Worker initialization failed"));
      };
      const cleanup = () => {
        if (this.workerBootTimer) clearTimeout(this.workerBootTimer);
        this.workerBootTimer = undefined;
        this.abortWorkerBoot = undefined;
        worker.removeEventListener("message", onMessage);
        worker.removeEventListener("error", onError);
      };
      this.abortWorkerBoot = () => {
        cleanup();
        reject(new Error("Camera stopped during worker initialization"));
      };
      worker.addEventListener("message", onMessage);
      worker.addEventListener("error", onError);
      this.workerBootTimer = setTimeout(() => {
        cleanup();
        reject(new Error("Worker model initialization timed out"));
      }, 12000);
      const message: WorkerInput = {
        kind: "init", wasmURL: this.options.wasmURL, modelURL: this.options.modelURL,
      };
      worker.postMessage(message);
    });
    if (this.closed) {
      worker.terminate();
      throw new Error("Camera session stopped during worker setup");
    }
    worker.addEventListener("message", this.onWorkerMessage);
    worker.addEventListener("error", this.onWorkerError);
  }

  private onWorkerError = (event: ErrorEvent): void => {
    this.fail(new Error(event.message || "MediaPipe worker crashed"));
  };

  private onWorkerMessage = (event: MessageEvent<WorkerOutput>): void => {
    if (this.closed) return;
    const message = event.data;
    if (message.kind === "fatal") {
      this.fail(new Error(message.message));
      return;
    }
    if (message.kind !== "result") return;
    if (message.frameId !== this.pendingFrameId) {
      // A stale result from an earlier in-flight task can never overwrite
      // a more recent pose. Our stream is latest-only by construction.
      return;
    }
    if (this.workerDeadline) clearTimeout(this.workerDeadline);
    this.workerDeadline = undefined;
    this.gate.settle();
    this.options.onFrame({
      frameId: message.frameId, session: message.session,
      capturedAtMs: message.capturedAtMs,
      mediaTimeSeconds: message.mediaTimeSeconds,
      width: message.width, height: message.height,
      inferredInMs: message.inferredInMs, landmarks: message.landmarks,
    });
  };

  /**
   * Returns instantly when a worker frame is posted. While worker is busy,
   * no additional image is captured (latest-only; no runaway image queue).
   * Main-thread fallback is intentionally throttled and synchronous.
   */
  submit(video: HTMLVideoElement, nowMs: number, session: number): void {
    if (!this.ready || this.closed) return;
    const frame = this.gate.acquire(
      nowMs, video.currentTime, session, video.videoWidth, video.videoHeight,
    );
    if (!frame) {
      this.droppedFrames++;
      return;
    }
    this.pendingFrameId = frame.frameId;
    if (this.worker) {
      void this.postBitmap(video, frame);
      return;
    }
    this.inferMain(video, frame);
  }

  private async postBitmap(video: HTMLVideoElement, frame: CapturedFrame): Promise<void> {
    let bitmap: ImageBitmap | undefined;
    try {
      bitmap = await createImageBitmap(video);
      if (this.closed || !this.worker || frame.frameId !== this.pendingFrameId) {
        bitmap.close();
        return;
      }
      const message: WorkerInput = { kind: "frame", ...frame, bitmap };
      this.worker.postMessage(message, [bitmap]);
      bitmap = undefined; // now owned by worker
      this.workerDeadline = setTimeout(() => {
        this.fail(new Error("MediaPipe worker inference stalled"));
      }, 2000);
    } catch (err) {
      bitmap?.close();
      this.fail(asError(err));
    }
  }

  private inferMain(video: HTMLVideoElement, frame: CapturedFrame): void {
    try {
      if (!this.task) throw new Error("Main-thread MediaPipe model not initialized");
      const start = performance.now();
      const result = this.task.detectForVideo(video, frame.capturedAtMs);
      const duration = Math.max(0, performance.now() - start);
      const points = result.landmarks[0] as PosePoint[] | undefined;
      this.options.onFrame({
        ...frame, inferredInMs: duration,
        landmarks: points ? points.map((p) => ({
          x: p.x, y: p.y, z: p.z, visibility: p.visibility, presence: p.presence,
        })) : null,
      });
    } catch (err) {
      this.fail(asError(err));
    } finally {
      this.gate.settle();
    }
  }

  private fail(error: Error): void {
    if (this.closed) return;
    this.ready = false;
    this.worker?.terminate();
    this.worker = undefined;
    if (this.workerDeadline) clearTimeout(this.workerDeadline);
    this.workerDeadline = undefined;
    this.gate.settle();
    if (this.mode === "worker" && !this.recovering) {
      // A Worker can initialize successfully yet fail to ingest a
      // video ImageBitmap on Safari. Recover locally once, without
      // silently keeping a stale pose on screen.
      this.recovering = true;
      void this.initializeMainTask().then(() => {
        if (this.closed) return;
        this.mode = "main";
        this.ready = true;
        this.recovering = false;
        console.warn("Pose worker failed; resumed throttled main-thread inference", error);
      }).catch((fallbackError: unknown) => {
        if (this.closed) return;
        this.recovering = false;
        this.options.onFatal(asError(fallbackError));
      });
      return;
    }
    this.options.onFatal(error);
  }

  close(): void {
    if (this.closed) return;
    this.closed = true;
    this.ready = false;
    this.abortWorkerBoot?.();
    if (this.workerBootTimer) clearTimeout(this.workerBootTimer);
    if (this.workerDeadline) clearTimeout(this.workerDeadline);
    this.worker?.terminate();
    this.worker = undefined;
    this.task?.close();
    this.task = undefined;
    this.gate.reset();
  }
}
