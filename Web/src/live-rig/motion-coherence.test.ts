import { describe, expect, it } from "vitest";
import { Vector3 } from "three";
import type { PosePoint } from "../pose";
import {
  LiveRigTracker, computeRigFrame, shortestAngleDelta,
  RIG_ARM_LANDMARKS, RIG_DEFAULT_STABILIZATION, RIG_MAX_LAG_LENGTH_RATIO,
  type RigObservation, type RigPoint,
} from "./pose-to-rig";
import { OriginalArticulatedRig } from "./original-rig";

/**
 * Review-driven regression (PR #71, P1/P2).
 *
 * Chain under test: TWO CONSECUTIVE MOVING OBSERVATIONS -> LiveRigTracker
 * (bounded whole-pose stabilization) -> OriginalArticulatedRig.apply ->
 * real Three.js getWorldPosition / localToWorld. This is the gap the original
 * single-frame / unsmoothed tests did not cover: the old tracker filtered only
 * `angleRadians` while leaving start/end/lengthPx raw, so the GPU-drawn elbow
 * and wrist disagreed with the frame's own declared joints.
 *
 * NO camera, Worker, MediaPipe, WebGL context, model weight or third-party
 * mesh is used. All fixtures are deterministic numerical 33-point poses.
 */
const SRC_W = 1280;
const SRC_H = 720;
const SEGMENT_PX = 100;
const deg = (value: number): number => (value * Math.PI) / 180;

const pxPoint = (x: number, y: number, confidence = 0.95): PosePoint => ({
  x: x / SRC_W, y: y / SRC_H, z: 0,
  visibility: confidence, presence: confidence,
});

const blank = (): PosePoint[] =>
  Array.from({ length: 33 }, () => pxPoint(0, 0, 0));

interface Joints {
  shoulder: [number, number];
  elbow: [number, number];
  wrist: [number, number];
}

/** Only the anatomical LEFT arm (11/13/15) is present: 2 segments. */
function landmarksFor(joints: Joints): PosePoint[] {
  const points = blank();
  const index = RIG_ARM_LANDMARKS.left;
  points[index.shoulder] = pxPoint(...joints.shoulder);
  points[index.elbow] = pxPoint(...joints.elbow);
  points[index.wrist] = pxPoint(...joints.wrist);
  return points;
}

/** Frame 1: both segments at 0 deg, exactly 100 display px each. */
const REST: Joints = {
  shoulder: [300, 300], elbow: [400, 300], wrist: [500, 300],
};

/** Frame 2 (80 ms later): upper 30 deg, forearm 45 deg absolute. */
const MOVED: Joints = {
  shoulder: [300, 300],
  elbow: [
    300 + SEGMENT_PX * Math.cos(deg(30)),
    300 + SEGMENT_PX * Math.sin(deg(30)),
  ],
  wrist: [
    300 + SEGMENT_PX * Math.cos(deg(30)) + SEGMENT_PX * Math.cos(deg(45)),
    300 + SEGMENT_PX * Math.sin(deg(30)) + SEGMENT_PX * Math.sin(deg(45)),
  ],
};

function makeObservation(overrides: Partial<RigObservation> = {}): RigObservation {
  return {
    landmarks: landmarksFor(REST),
    session: 7,
    frameId: 1,
    capturedAtMs: 1_000,
    nowMs: 1_000,
    sourceWidth: SRC_W,
    sourceHeight: SRC_H,
    viewportWidth: SRC_W,
    viewportHeight: SRC_H,
    mirrored: false,
    focus: "whole",
    ...overrides,
  };
}

const restFrame = (overrides: Partial<RigObservation> = {}): RigObservation =>
  makeObservation({ landmarks: landmarksFor(REST), frameId: 1, ...overrides });

const movedFrame = (overrides: Partial<RigObservation> = {}): RigObservation =>
  makeObservation({
    landmarks: landmarksFor(MOVED),
    frameId: 2, capturedAtMs: 1_080, nowMs: 1_080,
    ...overrides,
  });

const distance = (a: RigPoint, b: RigPoint): number =>
  Math.hypot(a.x - b.x, a.y - b.y);

function expectPoint(actual: Vector3 | RigPoint, expected: RigPoint): void {
  expect(actual.x).toBeCloseTo(expected.x, 5);
  expect(actual.y).toBeCloseTo(expected.y, 5);
  if ("z" in actual) expect(actual.z).toBeCloseTo(0, 6);
}

const worldElbow = (rig: OriginalArticulatedRig): Vector3 =>
  rig.nodes.left.elbowPivot.getWorldPosition(new Vector3());

const worldWrist = (rig: OriginalArticulatedRig): Vector3 =>
  rig.nodes.left.attachedFore.localToWorld(new Vector3(0, 0.5, 0));

describe("W3a review P1: two moving frames -> tracker -> THREE world joints", () => {
  it("keeps declared joints, segment endpoints and GPU world positions IDENTICAL", () => {
    const tracker = new LiveRigTracker();
    const first = tracker.update(restFrame());
    const second = tracker.update(movedFrame());
    expect(second.arms.left.upper).not.toBeNull();
    expect(second.arms.left.fore).not.toBeNull();
    expect(second.arms.left.fore!.hierarchyAttached).toBe(true);

    const rig = new OriginalArticulatedRig();
    expect(rig.apply(first, 0.7)).toBe(2);
    expectPoint(worldElbow(rig), first.arms.left.elbow!);
    expectPoint(worldWrist(rig), first.arms.left.wrist!);

    // Frame 2 is written as ABSOLUTE transforms onto the SAME rig instance.
    expect(rig.apply(second, 0.7)).toBe(2);
    const elbowWorld = worldElbow(rig);
    const wristWorld = worldWrist(rig);
    const arm = second.arms.left;
    expectPoint(elbowWorld, arm.elbow!);
    expectPoint(wristWorld, arm.wrist!);

    // Internally coherent: one filtered joint set feeds every derived field.
    expectPoint(arm.upper!.end, arm.elbow!);
    expectPoint(arm.fore!.start, arm.elbow!);
    expectPoint(arm.fore!.end, arm.wrist!);
    expectPoint(arm.upper!.start, arm.shoulder!);
    expect(arm.upper!.lengthPx)
      .toBeCloseTo(distance(arm.upper!.start, arm.upper!.end), 6);
    expect(arm.fore!.lengthPx)
      .toBeCloseTo(distance(arm.fore!.start, arm.fore!.end), 6);
    expect(arm.upper!.angleRadians).toBeCloseTo(
      Math.atan2(
        arm.upper!.end.y - arm.upper!.start.y,
        arm.upper!.end.x - arm.upper!.start.x
      ), 9);
    expect(arm.fore!.parentRelativeRadians!).toBeCloseTo(
      shortestAngleDelta(arm.upper!.angleRadians, arm.fore!.angleRadians), 9
    );
    // One visible shoulder => the torso pivot is that SAME filtered point.
    expectPoint(second.pivot!, arm.shoulder!);
    expectPoint(rig.nodes.left.shoulderPivot.getWorldPosition(new Vector3()),
      arm.shoulder!);
    rig.dispose();
  });

  it("bounds the display lag and makes it decay geometrically without drift", () => {
    const tracker = new LiveRigTracker();
    const first = tracker.update(restFrame());
    const second = tracker.update(movedFrame());
    const rawSecond = computeRigFrame(movedFrame()); // pure frame is NEVER filtered
    const cap = RIG_MAX_LAG_LENGTH_RATIO * Math.min(
      rawSecond.arms.left.upper!.lengthPx,
      rawSecond.arms.left.fore!.lengthPx
    );
    expect(RIG_DEFAULT_STABILIZATION).toBe(0.35);
    expect(cap).toBeCloseTo(0.25 * SEGMENT_PX, 6);

    // The pure module stays RAW; only the tracker introduces a bounded lag.
    expectPoint(rawSecond.arms.left.wrist!, {
      x: MOVED.wrist[0], y: MOVED.wrist[1],
    });
    const lag = distance(second.arms.left.wrist!, rawSecond.arms.left.wrist!);
    expect(lag).toBeGreaterThan(0); // smoothing really is active
    expect(lag).toBeLessThanOrEqual(cap + 1e-6);
    expect(distance(second.arms.left.elbow!, rawSecond.arms.left.elbow!))
      .toBeLessThanOrEqual(cap + 1e-6);

    // A cap-clamped joint is still on the previous -> observed ray: it is a
    // lag, never an invented off-ray intermediate bone position.
    const previous = first.arms.left.wrist!;
    const observed = rawSecond.arms.left.wrist!;
    const displayed = second.arms.left.wrist!;
    const cross =
      (displayed.x - observed.x) * (previous.y - observed.y) -
      (displayed.y - observed.y) * (previous.x - observed.x);
    expect(Math.abs(cross)).toBeLessThan(1e-6);

    // Constant observation => geometric convergence, no accumulated drift.
    const lags: number[] = [];
    for (let i = 3; i <= 10; i++) {
      const step = tracker.update(movedFrame({
        frameId: i,
        capturedAtMs: 1_000 + (i - 1) * 80,
        nowMs: 1_000 + (i - 1) * 80,
      }));
      lags.push(distance(step.arms.left.wrist!, observed));
    }
    expect(lags[0]).toBeLessThan(lag);
    for (let i = 1; i < lags.length; i++) expect(lags[i]).toBeLessThan(lags[i - 1]);
    expect(lags[lags.length - 1]).toBeLessThan(2); // < 2 display px residual
  });

  it("keeps the SAME coherence through object-fit:cover crop and mirror", () => {
    const crop = {
      viewportWidth: 360, viewportHeight: 640, mirrored: true,
    };
    const tracker = new LiveRigTracker();
    const first = tracker.update(restFrame(crop));
    const second = tracker.update(movedFrame(crop));
    const rawSecond = computeRigFrame(movedFrame(crop));
    expect(second.mirrored).toBe(true);
    expect(second.arms.left.upper).not.toBeNull();
    // Mirror really changed the display-space x (cover crop included).
    expect(second.arms.left.wrist!.x)
      .not.toBeCloseTo(rawSecond.arms.left.wrist!.x === 0 ? -1 : 0, 3);

    const rig = new OriginalArticulatedRig();
    rig.apply(first, 0.7);
    expect(rig.apply(second, 0.7)).toBe(2);
    expectPoint(worldElbow(rig), second.arms.left.elbow!);
    expectPoint(worldWrist(rig), second.arms.left.wrist!);
    expectPoint(second.arms.left.upper!.end, second.arms.left.fore!.start);
    expectPoint(second.arms.left.fore!.end, second.arms.left.wrist!);
    rig.dispose();
  });

  it("has ZERO lag when stabilization is disabled, still fully coherent", () => {
    const tracker = new LiveRigTracker({ stabilizationAlpha: 0 });
    tracker.update(restFrame());
    const second = tracker.update(movedFrame());
    const rawSecond = computeRigFrame(movedFrame());
    expectPoint(second.arms.left.elbow!, rawSecond.arms.left.elbow!);
    expectPoint(second.arms.left.wrist!, rawSecond.arms.left.wrist!);

    const rig = new OriginalArticulatedRig();
    expect(rig.apply(second, 0.7)).toBe(2);
    expectPoint(worldElbow(rig), rawSecond.arms.left.elbow!);
    expectPoint(worldWrist(rig), rawSecond.arms.left.wrist!);
    rig.dispose();
  });

  it("renders a surviving forearm INDEPENDENTLY when its parent is rejected", () => {
    // Upper teleports by pi; the forearm keeps its 0 rad observation angle.
    const detached: Joints = {
      shoulder: [300, 300], elbow: [200, 300], wrist: [300, 300],
    };
    const tracker = new LiveRigTracker({ stabilizationAlpha: 0 });
    const first = tracker.update(restFrame());
    const second = tracker.update(movedFrame({
      landmarks: landmarksFor(detached),
    }));
    expect(second.reasons).toContain("left:upperArm:ANGLE_DISCONTINUITY");
    expect(second.arms.left.upper).toBeNull();
    expect(second.arms.left.fore!.hierarchyAttached).toBe(false);
    expect(second.arms.left.fore!.parentRelativeRadians).toBeNull();

    const rig = new OriginalArticulatedRig();
    rig.apply(first, 0.7);
    expect(rig.apply(second, 0.7)).toBe(1);
    expect(rig.nodes.left.shoulderPivot.visible).toBe(false);
    expect(rig.nodes.left.elbowPivot.visible).toBe(false);
    expect(rig.nodes.left.independentPivot.visible).toBe(true);
    const tip = rig.nodes.left.independentFore
      .localToWorld(new Vector3(0, 0.5, 0));
    expectPoint(tip, second.arms.left.wrist!);
    rig.dispose();
  });
});
