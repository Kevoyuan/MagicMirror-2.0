/** Real measured processing metrics; not display FPS or sensor-to-photon latency. */
export interface ProcessingSample {
  observedAtMs: number;
  inferenceMs: number;
  deliveryMs: number;
}
export interface ProcessingSummary {
  count: number;
  outputHz: number;
  inferenceP50Ms: number;
  inferenceP95Ms: number;
  deliveryP95Ms: number;
}

export function percentile(sorted: readonly number[], fraction: number): number {
  if (sorted.length === 0 || fraction < 0 || fraction > 1) return 0;
  const index = Math.ceil(fraction * sorted.length) - 1;
  return sorted[Math.max(0, Math.min(sorted.length - 1, index))];
}

export class ProcessingWindow {
  private readonly samples: ProcessingSample[] = [];
  constructor(private readonly capacity = 60) {
    if (!Number.isInteger(capacity) || capacity < 2) {
      throw new Error("Processing history needs at least 2 samples");
    }
  }
  record(sample: ProcessingSample): void {
    if (![sample.observedAtMs, sample.inferenceMs, sample.deliveryMs].every(Number.isFinite) ||
        sample.inferenceMs < 0 || sample.deliveryMs < 0) return;
    const last = this.samples.at(-1);
    if (last && sample.observedAtMs <= last.observedAtMs) return;
    this.samples.push(sample);
    if (this.samples.length > this.capacity) this.samples.shift();
  }
  summary(): ProcessingSummary {
    const count = this.samples.length;
    if (!count) return { count: 0, outputHz: 0, inferenceP50Ms: 0, inferenceP95Ms: 0, deliveryP95Ms: 0 };
    const latency = this.samples.map((s) => s.inferenceMs).sort((a, b) => a - b);
    const delivery = this.samples.map((s) => s.deliveryMs).sort((a, b) => a - b);
    const elapsed = count < 2 ? 0 :
      this.samples[count - 1].observedAtMs - this.samples[0].observedAtMs;
    return {
      count,
      outputHz: elapsed > 0 ? (count - 1) * 1000 / elapsed : 0,
      inferenceP50Ms: percentile(latency, 0.5),
      inferenceP95Ms: percentile(latency, 0.95),
      deliveryP95Ms: percentile(delivery, 0.95),
    };
  }
  reset(): void { this.samples.length = 0; }
}

export interface CapturedFrame {
  frameId: number;
  session: number;
  capturedAtMs: number;
  mediaTimeSeconds: number;
  width: number;
  height: number;
}
export interface InferenceFrame extends CapturedFrame {
  inferredInMs: number;
  landmarks: import("./pose").PosePoint[] | null;
}

/** One in-flight video snapshot and strictly monotonic media frames. */
export class LatestOnlyGate {
  private lastMediaTime = -1;
  private lastSentMs = -Infinity;
  private busy = false;
  private sequence = 0;
  constructor(private readonly minIntervalMs = 75) {}
  acquire(nowMs: number, mediaSeconds: number, session: number, width: number, height: number): CapturedFrame | null {
    if (this.busy || ![nowMs, mediaSeconds].every(Number.isFinite) ||
        mediaSeconds <= this.lastMediaTime || nowMs - this.lastSentMs < this.minIntervalMs ||
        width <= 0 || height <= 0) return null;
    this.busy = true;
    this.lastMediaTime = mediaSeconds;
    this.lastSentMs = nowMs;
    return { frameId: ++this.sequence, session, capturedAtMs: nowMs,
      mediaTimeSeconds: mediaSeconds, width, height };
  }
  settle(): void { this.busy = false; }
  reset(): void {
    this.busy = false;
    this.lastMediaTime = -1;
    this.lastSentMs = -Infinity;
    this.sequence = 0;
  }
}

/** Disallow old session results and implausibly delayed observations. */
export function freshResult(
  result: CapturedFrame,
  currentSession: number,
  nowMs: number,
  maxDelayMs = 350
): boolean {
  return result.session === currentSession &&
    Number.isFinite(nowMs) &&
    Number.isFinite(result.capturedAtMs) &&
    result.capturedAtMs <= nowMs &&
    nowMs - result.capturedAtMs <= maxDelayMs &&
    result.width > 0 && result.height > 0;
}
