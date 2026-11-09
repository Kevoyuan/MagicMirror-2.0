/**
 * W3a controller contract: one shared overlay host, explicit opt-in mode and
 * fail-closed session gating. No DOM, Worker, MediaPipe or WebGL is created;
 * these tests only observe the structural host calls and Object3D visibility.
 */
import { describe, expect, it } from "vitest";
import type { Object3D } from "three";
import type { PosePoint } from "../pose";
import type { InferenceFrame } from "../telemetry";
import {
  LiveRigOverlay,
  type OverlayRenderHost,
  type RigFrameContext,
} from "./rig-controller";

const SRC_W = 1280;
const SRC_H = 720;
const NOW = 10_000;
const VIEW = { width: 800, height: 450 };

function pose(): PosePoint[] {
  const blank = Array.from({ length: 33 }, () => ({
    x: 0.5, y: 0.5, z: 0, visibility: 0, presence: 0,
  }));
  const at = (index: number, x: number, y: number): void => {
    blank[index] = { x, y, z: 0, visibility: 0.95, presence: 0.95 };
  };
  // Anatomical left (11/13/15) and right (12/14/16), both with a real parent.
  at(11, 0.35, 0.4); at(13, 0.28, 0.55); at(15, 0.22, 0.7);
  at(12, 0.65, 0.4); at(14, 0.72, 0.55); at(16, 0.78, 0.7);
  return blank;
}

function frame(overrides: Partial<InferenceFrame> = {}): InferenceFrame {
  return {
    frameId: 1,
    session: 1,
    capturedAtMs: NOW,
    mediaTimeSeconds: 1,
    width: SRC_W,
    height: SRC_H,
    inferredInMs: 6,
    landmarks: pose(),
    ...overrides,
  };
}

function context(overrides: Partial<RigFrameContext> = {}): RigFrameContext {
  return {
    session: 1,
    nowMs: NOW,
    mirrored: false,
    focus: "whole",
    opacity: 0.65,
    stabilizing: true,
    ...overrides,
  };
}

interface FakeHost extends OverlayRenderHost {
  attached: Object3D[];
  detached: Object3D[];
  counts: {
    attach: number; detach: number; hideProxy: number;
    render: number; renderForCapture: number;
  };
}

function fakeHost(): FakeHost {
  const attached: Object3D[] = [];
  const detached: Object3D[] = [];
  const counts = {
    attach: 0, detach: 0, hideProxy: 0, render: 0, renderForCapture: 0,
  };
  return {
    attached, detached, counts,
    attach: (object: Object3D) => { counts.attach++; attached.push(object); },
    detach: (object: Object3D) => { counts.detach++; detached.push(object); },
    hideProxy: () => { counts.hideProxy++; },
    render: () => { counts.render++; },
    renderForCapture: () => { counts.renderForCapture++; },
    viewport: () => VIEW,
  };
}

function visibleMeshCount(root: Object3D): number {
  let count = 0;
  root.traverse((object) => {
    if (object.type === "Mesh" && object.visible) count++;
  });
  return count;
}

describe("W3a LiveRigOverlay opt-in controller", () => {
  it("defaults to the Reference Proxy and never attaches a rig", () => {
    const host = fakeHost();
    const overlay = new LiveRigOverlay(host);
    expect(overlay.currentMode).toBe("proxy");
    const outcome = overlay.apply(frame(), context());
    expect(outcome).toMatchObject({ active: false, visibleSegments: 0, reasons: ["PROXY_MODE"] });
    expect(host.attached).toHaveLength(0);
    expect(host.counts.render).toBe(0);
  });

  it("attaches exactly ONE original rig to the existing host and renders it", () => {
    const host = fakeHost();
    const overlay = new LiveRigOverlay(host);
    expect(overlay.setMode("rig")).toBe(true);
    expect(overlay.currentMode).toBe("rig");
    expect(host.attached).toHaveLength(1);
    expect(host.attached[0].name).toBe("W3a-original-articulated-rig");
    expect(host.viewport()).toEqual(VIEW);

    const outcome = overlay.apply(frame(), context());
    expect(outcome.active).toBe(true);
    expect(outcome.visibleSegments).toBe(4);
    expect(outcome.status).toBe("tracking");
    expect(host.counts.render).toBe(2); // exactly setMode + apply
    expect(visibleMeshCount(host.attached[0])).toBeGreaterThan(0);
  });

  it("rejects a frame from a different camera session without drawing", () => {
    const host = fakeHost();
    const overlay = new LiveRigOverlay(host);
    overlay.setMode("rig");
    const before = host.counts.render;
    const outcome = overlay.apply(frame({ session: 0 }), context({ session: 1 }));
    expect(outcome).toMatchObject({ active: false, reasons: ["OLD_SESSION"] });
    expect(host.counts.render).toBe(before);
  });

  it("hides every experimental mesh on pause, tracking loss and reset", () => {
    const host = fakeHost();
    const overlay = new LiveRigOverlay(host);
    overlay.setMode("rig");
    expect(overlay.apply(frame(), context()).visibleSegments).toBe(4);

    overlay.pause();
    expect(visibleMeshCount(host.attached[0])).toBe(0);
    expect(overlay.apply(frame({ frameId: 2 }), context()).reasons).toContain("PAUSED");

    overlay.resume();
    expect(overlay.apply(frame({ frameId: 3 }), context()).visibleSegments).toBe(4);
    overlay.hide();
    expect(visibleMeshCount(host.attached[0])).toBe(0);

    overlay.reset();
    expect(overlay.apply(frame({ frameId: 4 }), context()).visibleSegments).toBe(4);
  });

  it("falls back to proxy mode and detaches only on dispose", () => {
    const host = fakeHost();
    const overlay = new LiveRigOverlay(host);
    overlay.setMode("rig");
    expect(overlay.setMode("proxy")).toBe(true);
    expect(overlay.currentMode).toBe("proxy");
    expect(host.detached).toHaveLength(0);
    expect(visibleMeshCount(host.attached[0])).toBe(0);
    expect(overlay.apply(frame(), context()).reasons).toEqual(["PROXY_MODE"]);

    overlay.dispose();
    expect(host.detached).toHaveLength(1);
    expect(overlay.currentMode).toBe("proxy");
  });

  it("keeps frame ordering across a worker fallback and an unsupported region", () => {
    const host = fakeHost();
    const overlay = new LiveRigOverlay(host);
    overlay.setMode("rig");
    overlay.setStabilization(false);
    overlay.clearTransforms(); // worker -> main fallback
    expect(overlay.apply(frame({ frameId: 1 }), context()).visibleSegments).toBe(4);
    const legs = overlay.apply(frame({ frameId: 2 }), context({ focus: "legs" }));
    expect(legs.visibleSegments).toBe(0);
    expect(legs.reasons).toContain("REGION_NOT_SUPPORTED");
    expect(visibleMeshCount(host.attached[0])).toBe(0);
    // An out-of-order frame is not allowed to resurrect a hidden chain.
    expect(overlay.apply(frame({ frameId: 2 }), context()).reasons)
      .toContain("OUT_OF_ORDER_FRAME");
  });

  it("renders the shared host exactly once for an explicit local capture", () => {
    const host = fakeHost();
    const overlay = new LiveRigOverlay(host);
    overlay.renderForCapture();
    expect(host.counts.renderForCapture).toBe(1);
    expect(host.counts.render).toBe(0);
  });
});
