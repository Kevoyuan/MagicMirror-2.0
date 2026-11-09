import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { WorkerInput, WorkerOutput } from "./inference-protocol";
import type { InferenceFrame } from "./telemetry";
import type { PosePoint } from "./pose";
import { LivePoseInference } from "./inference";

type FrameMessage = Extract<WorkerInput, { kind: "frame" }>;
type Listener = (event: never) => void;

const point: PosePoint = { x: 0.2, y: 0.3, z: 0, visibility: 0.9, presence: 0.8 };

/**
 * Synthetic Worker. terminate() deliberately keeps listeners so a queued
 * late message/error can still be delivered, exactly like the browser race
 * the W1c gate must survive. No real MediaPipe, camera or GPU is involved.
 */
class FakeWorker {
  static instances: FakeWorker[] = [];
  static autoReady = true;
  static reset(): void {
    FakeWorker.instances = [];
    FakeWorker.autoReady = true;
  }
  readonly messages: WorkerInput[] = [];
  terminated = false;
  private readonly listeners = new Map<string, Set<Listener>>();

  constructor(_url: URL, _options: WorkerOptions) {
    FakeWorker.instances.push(this);
  }
  addEventListener(type: string, listener: Listener): void {
    const set = this.listeners.get(type) ?? new Set<Listener>();
    set.add(listener);
    this.listeners.set(type, set);
  }
  removeEventListener(type: string, listener: Listener): void {
    this.listeners.get(type)?.delete(listener);
  }
  postMessage(message: WorkerInput, _transfer?: Transferable[]): void {
    this.messages.push(message);
    if (message.kind === "init" && FakeWorker.autoReady) {
      queueMicrotask(() => this.emitMessage({ kind: "ready" }));
    }
  }
  terminate(): void { this.terminated = true; }
  emitMessage(data: unknown): void {
    for (const listener of this.listeners.get("message") ?? []) {
      listener({ data } as never);
    }
  }
  emitError(message: string): void {
    for (const listener of this.listeners.get("error") ?? []) {
      listener({ message } as never);
    }
  }
  frameMessages(): FrameMessage[] {
    return this.messages.filter((m): m is FrameMessage => m.kind === "frame");
  }
}

const mocks = vi.hoisted(() => {
  const detectForVideo = vi.fn(() => ({
    landmarks: [[{ x: 0.2, y: 0.3, z: 0, visibility: 0.9, presence: 0.8 }]],
  }));
  const close = vi.fn();
  return {
    detectForVideo,
    close,
    forVisionTasks: vi.fn(async () => ({})),
    createFromOptions: vi.fn(async () => ({ detectForVideo, close })),
  };
});

vi.mock("@mediapipe/tasks-vision", () => ({
  FilesetResolver: { forVisionTasks: mocks.forVisionTasks },
  PoseLandmarker: { createFromOptions: mocks.createFromOptions },
}));

interface BitmapStub { closed: boolean; close(): void }
const bitmaps: BitmapStub[] = [];
let restoreWarn: () => void = () => {};

beforeEach(() => {
  vi.useFakeTimers();
  FakeWorker.reset();
  bitmaps.length = 0;
  mocks.detectForVideo.mockClear();
  mocks.createFromOptions.mockClear();
  mocks.forVisionTasks.mockClear();
  mocks.close.mockClear();
  const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
  restoreWarn = () => warn.mockRestore();
  vi.stubGlobal("Worker", FakeWorker);
  vi.stubGlobal("OffscreenCanvas", class FakeOffscreenCanvas {});
  vi.stubGlobal("createImageBitmap", vi.fn(async () => {
    const bitmap: BitmapStub = { closed: false, close() { this.closed = true; } };
    bitmaps.push(bitmap);
    return bitmap;
  }));
});

afterEach(() => {
  restoreWarn();
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

function makeVideo(mediaTime = 1.2): HTMLVideoElement {
  return { currentTime: mediaTime, videoWidth: 640, videoHeight: 480 } as unknown as HTMLVideoElement;
}

function makeEngine() {
  const frames: InferenceFrame[] = [];
  const fatals: Error[] = [];
  const engine = new LivePoseInference({
    modelURL: "local://pose_landmarker_lite.task",
    wasmURL: "local://wasm",
    onFrame: (frame) => { frames.push(frame); },
    onFatal: (error) => { fatals.push(error); },
  });
  return { engine, frames, fatals };
}

function frameMessage(worker: FakeWorker, index = 0): FrameMessage {
  const message = worker.frameMessages()[index];
  if (!message) throw new Error(`No worker frame posted at index ${index}`);
  return message;
}

function workerResult(frame: FrameMessage, overrides: Record<string, unknown> = {}): WorkerOutput {
  return {
    kind: "result",
    frameId: frame.frameId, session: frame.session,
    capturedAtMs: frame.capturedAtMs, mediaTimeSeconds: frame.mediaTimeSeconds,
    width: frame.width, height: frame.height,
    inferredInMs: 12, landmarks: [point],
    ...overrides,
  } as unknown as WorkerOutput;
}

describe("W1c LivePoseInference fail-closed lifecycle (synthetic)", () => {
  it("boots a worker, delivers one frame and ignores duplicate/stale results", async () => {
    const { engine, frames, fatals } = makeEngine();
    expect(await engine.initialize()).toBe("worker");
    const worker = FakeWorker.instances[0];
    expect(worker.messages[0]).toMatchObject({ kind: "init" });

    engine.submit(makeVideo(1.2), 1000, 5);
    await vi.advanceTimersByTimeAsync(0);
    const first = frameMessage(worker);
    expect(first).toMatchObject({ frameId: 1, session: 5, width: 640, height: 480 });
    expect(bitmaps[0].closed).toBe(false); // ownership transferred to worker

    worker.emitMessage(workerResult(first));
    expect(frames).toHaveLength(1);
    expect(frames[0]).toMatchObject({ frameId: 1, session: 5, inferredInMs: 12, landmarks: [point] });
    worker.emitMessage(workerResult(first)); // duplicate delivery
    worker.emitMessage(workerResult(first, { session: 6, frameId: 99 }));
    expect(frames).toHaveLength(1);
    expect(fatals).toHaveLength(0);
    expect(engine.mode).toBe("worker");

    engine.submit(makeVideo(1.3), 1200, 5);
    await vi.advanceTimersByTimeAsync(0);
    worker.emitMessage(workerResult(frameMessage(worker, 1)));
    expect(frames).toHaveLength(2);
    expect(frames[1].frameId).toBe(2); // ids stay monotonic across the gate
    engine.close();
  });

  it("drops late frames after a stall, then safely resumes on the main thread", async () => {
    const { engine, frames, fatals } = makeEngine();
    await engine.initialize();
    const worker = FakeWorker.instances[0];
    engine.submit(makeVideo(1.2), 1000, 5);
    await vi.advanceTimersByTimeAsync(0);
    const stalled = frameMessage(worker);

    await vi.advanceTimersByTimeAsync(2000); // 2s worker deadline
    expect(worker.terminated).toBe(true);
    expect(engine.mode).toBe("main");
    expect(fatals).toHaveLength(0);

    worker.emitMessage(workerResult(stalled));
    worker.emitError("late crash from terminated worker");
    expect(frames).toHaveLength(0);
    expect(fatals).toHaveLength(0);

    engine.submit(makeVideo(1.3), 3000, 5);
    expect(frames).toHaveLength(1);
    expect(frames[0].frameId).toBe(2);
    expect(frames[0].landmarks).toHaveLength(1);
    expect(mocks.detectForVideo).toHaveBeenCalledTimes(1);
    engine.close();
  });

  it("recovers from a worker crash without reusing a pose or firing onFatal", async () => {
    const { engine, frames, fatals } = makeEngine();
    await engine.initialize();
    const worker = FakeWorker.instances[0];
    worker.emitError("WASM trap");
    await vi.advanceTimersByTimeAsync(0);

    expect(worker.terminated).toBe(true);
    expect(engine.mode).toBe("main");
    expect(fatals).toHaveLength(0);
    expect(mocks.createFromOptions).toHaveBeenCalledTimes(1);

    engine.submit(makeVideo(2), 1000, 8);
    expect(frames).toHaveLength(1);
    expect(frames[0].session).toBe(8);
    engine.close();
  });

  it("fails closed on malformed worker results instead of drawing them", async () => {
    const { engine, frames, fatals } = makeEngine();
    await engine.initialize();
    const worker = FakeWorker.instances[0];
    engine.submit(makeVideo(1.2), 1000, 5);
    await vi.advanceTimersByTimeAsync(0);
    const frame = frameMessage(worker);

    worker.emitMessage(workerResult(frame, { landmarks: [{ x: NaN, y: 0, z: 0 }] }));
    await vi.advanceTimersByTimeAsync(0);
    expect(frames).toHaveLength(0);
    expect(fatals).toHaveLength(0);
    expect(worker.terminated).toBe(true);
    expect(engine.mode).toBe("main");
    engine.close();
  });

  it("closes a bitmap that resolves after the worker already died", async () => {
    let releaseBitmap: ((value: BitmapStub) => void) | undefined;
    vi.stubGlobal("createImageBitmap", vi.fn(() => new Promise<BitmapStub>((resolve) => {
      releaseBitmap = resolve;
    })));
    const { engine, frames, fatals } = makeEngine();
    await engine.initialize();
    const worker = FakeWorker.instances[0];
    engine.submit(makeVideo(1.2), 1000, 5);

    worker.emitError("crash while bitmap was being created");
    await vi.advanceTimersByTimeAsync(0);
    expect(engine.mode).toBe("main");

    const bitmap: BitmapStub = { closed: false, close() { this.closed = true; } };
    releaseBitmap?.(bitmap);
    await vi.advanceTimersByTimeAsync(0);
    expect(bitmap.closed).toBe(true);
    expect(worker.frameMessages()).toHaveLength(0);
    expect(frames).toHaveLength(0);
    expect(fatals).toHaveLength(0);
    engine.close();
  });

  it("rejects close() during worker boot and never reports a frame", async () => {
    FakeWorker.autoReady = false;
    const { engine, frames, fatals } = makeEngine();
    const booting = engine.initialize();
    engine.close();
    await expect(booting).rejects.toThrow(/stopped/i);
    expect(FakeWorker.instances[0].terminated).toBe(true);
    expect(frames).toHaveLength(0);
    expect(fatals).toHaveLength(0);
    expect(mocks.createFromOptions).not.toHaveBeenCalled();
  });

  it("reports a fatal error when main-thread inference itself throws", async () => {
    vi.stubGlobal("Worker", undefined); // force the throttled main-thread path
    mocks.detectForVideo.mockImplementationOnce(() => {
      throw new Error("CPU model failure");
    });
    const { engine, frames, fatals } = makeEngine();
    expect(await engine.initialize()).toBe("main");
    engine.submit(makeVideo(1), 1000, 4);
    expect(frames).toHaveLength(0);
    expect(fatals.map((e) => e.message)).toEqual(["CPU model failure"]);
    engine.submit(makeVideo(2), 2000, 4); // closed for new work
    expect(frames).toHaveLength(0);
    engine.close();
  });
});
