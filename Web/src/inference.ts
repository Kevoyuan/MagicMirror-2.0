import { FilesetResolver, PoseLandmarker } from "@mediapipe/tasks-vision";
import type { WorkerInput, WorkerOutput } from "./inference-protocol";
import type { PosePoint } from "./pose";
import { LatestOnlyGate, type InferenceFrame, type CapturedFrame } from "./telemetry";
import {
  decideWorkerMessage, workerFailureText, type WorkerResultState,
} from "./inference-result";

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

/** No real camera session uses a negative id; used to invalidate late results. */
const INVALID_SESSION = -1;

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
  private currentSession = INVALID_SESSION;
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
        this.worker?.terminate();
        this.worker = undefined;
        if (this.closed) throw asError(err);
        console.warn("MediaPipe Web Worker unavailable; using main-thread fallback", err);
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
      this.worker = undefined;
      throw new Error("Camera session stopped during worker setup");
    }
    worker.addEventListener("message", this.onWorkerMessage);
    worker.addEventListener("error", this.onWorkerError);
  }

  /** Immutable snapshot consumed by the pure W1c fail-closed gate. */
  private resultState(): WorkerResultState {
    return {
      closed: this.closed,
      ready: this.ready,
      recovering: this.recovering,
      mode: this.mode,
      workerAlive: this.worker !== undefined,
      pendingFrameId: this.pendingFrameId,
      currentSession: this.currentSession,
    };
  }

  private onWorkerError = (event: ErrorEvent): void => {
    const message: WorkerOutput = {
      kind: "fatal", message: event.message || "MediaPipe worker crashed",
    };
    // A terminated worker may still deliver a queued error event. Ignore it
    // once the session is closed, recovering or already on the main path.
    if (decideWorkerMessage(this.resultState(), message) !== "fatal") return;
    this.fail(new Error(workerFailureText(message)));
  };

  private onWorkerMessage = (event: MessageEvent<WorkerOutput>): void => {
    const message = event.data;
    const decision = decideWorkerMessage(this.resultState(), message);
    if (decision === "fatal") {
      this.fail(new Error(workerFailureText(message)));
      return;
    }
    // "ignore" covers closed/recovering sessions, stale frame ids, replaced
    // camera sessions, late results after a crash/stall and unknown payloads.
    if (decision !== "accept" || message.kind !== "result") return;
    if (this.workerDeadline) clearTimeout(this.workerDeadline);
    this.workerDeadline = undefined;
    this.gate.settle();
    this.pendingFrameId = 0; // consume the frame so duplicates are ignored
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
    if (!this.ready || this.closed || this.recovering) return;
    const frame = this.gate.acquire(
      nowMs, video.currentTime, session, video.videoWidth, video.videoHeight,
    );
    if (!frame) {
      this.droppedFrames++;
      return;
    }
    this.pendingFrameId = frame.frameId;
    this.currentSession = frame.session;
    if (this.worker) {
      void this.postBitmap(video, frame);
      return;
    }
    this.inferMain(video, frame);
  }

  private frameIsCurrent(frame: CapturedFrame, workerExpected: boolean): boolean {
    return !this.closed && this.ready && !this.recovering &&
      frame.frameId === this.pendingFrameId && frame.session === this.currentSession &&
      (workerExpected ? this.mode === "worker" && this.worker !== undefined
        : this.mode === "main");
  }

  private async postBitmap(video: HTMLVideoElement, frame: CapturedFrame): Promise<void> {
    let bitmap: ImageBitmap | undefined;
    try {
      bitmap = await createImageBitmap(video);
      const worker = this.worker;
      if (!worker || !this.frameIsCurrent(frame, true)) {
        bitmap.close();
        return;
      }
      const message: WorkerInput = { kind: "frame", ...frame, bitmap };
      worker.postMessage(message, [bitmap]);
      bitmap = undefined; // now owned by worker
      const stalledFrameId = frame.frameId;
      this.workerDeadline = setTimeout(() => {
        if (this.pendingFrameId === stalledFrameId && !this.closed && !this.recovering &&
            this.mode === "worker" && this.worker !== undefined) {
          this.fail(new Error("MediaPipe worker inference stalled"));
        }
      }, 2000);
    } catch (err) {
      bitmap?.close();
      // A bitmap failure for an already abandoned frame must not tear down a
      // healthy/recovered session.
      if (!this.frameIsCurrent(frame, true)) return;
      this.fail(asError(err));
    }
  }

  private inferMain(video: HTMLVideoElement, frame: CapturedFrame): void {
    try {
      if (!this.frameIsCurrent(frame, false)) return;
      if (!this.task) throw new Error("Main-thread MediaPipe model not initialized");
      const start = performance.now();
      const result = this.task.detectForVideo(video, frame.capturedAtMs);
      const duration = Math.max(0, performance.now() - start);
      if (!this.frameIsCurrent(frame, false)) return;
      const points = result.landmarks[0] as PosePoint[] | undefined;
      this.pendingFrameId = 0;
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
    // Invalidate the in-flight identity synchronously. Any result/error that
    // arrives after this point belongs to a dead worker and must be dropped,
    // never drawn as a reused pose.
    this.pendingFrameId = 0;
    this.currentSession = INVALID_SESSION;
    this.worker?.terminate();
    this.worker = undefined;
    if (this.workerDeadline) clearTimeout(this.workerDeadline);
    this.workerDeadline = undefined;
    // settle(), not reset(): frame ids stay monotonic across the fallback so
    // the viewer's lastReceivedFrameId guard still accepts main-thread frames.
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
    this.recovering = false;
    this.pendingFrameId = 0;
    this.currentSession = INVALID_SESSION;
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
