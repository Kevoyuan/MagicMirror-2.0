import { describe, expect, it } from "vitest";
import { LatestOnlyGate, ProcessingWindow, freshResult, percentile } from "./telemetry";

describe("latest-only browser frame delivery", () => {
  it("rejects duplicate or backwards video time, busy calls and interval overflow", () => {
    const gate = new LatestOnlyGate(75);
    const first = gate.acquire(1000, 1.2, 3, 640, 480);
    expect(first?.frameId).toBe(1);
    expect(gate.acquire(1100, 1.3, 3, 640, 480)).toBeNull();
    gate.settle();
    expect(gate.acquire(1110, 1.2, 3, 640, 480)).toBeNull();
    expect(gate.acquire(1110, 1.3, 3, 640, 480)?.frameId).toBe(2);
    gate.reset();
    expect(gate.acquire(1, 0.04, 4, 640, 480)?.frameId).toBe(1);
  });
  it("rejects session replacement, stale, future or impossible geometry", () => {
    const sample = { frameId: 2, session: 5, capturedAtMs: 500,
      mediaTimeSeconds: 2, width: 640, height: 480 };
    expect(freshResult(sample, 5, 620)).toBe(true);
    expect(freshResult(sample, 6, 620)).toBe(false);
    expect(freshResult(sample, 5, 900)).toBe(false);
    expect(freshResult(sample, 5, 450)).toBe(false);
    expect(freshResult({ ...sample, width: 0 }, 5, 620)).toBe(false);
  });
  it("calculates measured processing and delivery percentiles", () => {
    const w = new ProcessingWindow(4);
    expect(w.summary().outputHz).toBe(0);
    for (let n = 0; n < 5; n++)
      w.record({ observedAtMs: n * 100, inferenceMs: (n + 1) * 5, deliveryMs: n * 10 });
    expect(w.summary()).toMatchObject({
      count: 4, outputHz: 10, inferenceP50Ms: 15,
      inferenceP95Ms: 25, deliveryP95Ms: 40,
    });
    w.record({ observedAtMs: 300, inferenceMs: -4, deliveryMs: 1 });
    expect(w.summary().count).toBe(4);
    w.reset();
    expect(w.summary().count).toBe(0);
  });
  it("handles percentile edge bounds without unsafe arithmetic", () => {
    expect(percentile([], 0.95)).toBe(0);
    expect(percentile([1, 2, 4, 8], 0.5)).toBe(2);
    expect(percentile([1, 2, 4, 8], 0.95)).toBe(8);
  });
});
