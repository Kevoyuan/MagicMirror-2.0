import { describe, expect, it, vi } from "vitest";
import { Vector3, type MeshStandardMaterial } from "three";
import type { PosePoint } from "../pose";
import {
  computeRigFrame, RIG_ARM_LANDMARKS, ORIGINAL_RIG_LABEL,
  type RigFrame, type RigObservation,
} from "./index";
import { OriginalArticulatedRig } from "./original-rig";

/** Synthetic numerical fixtures; no WebGL context is required for matrices. */
const SRC_W = 1280;
const SRC_H = 720;
const point = (x: number, y: number, confidence = 0.95): PosePoint =>
  ({ x, y, z: 0, visibility: confidence, presence: confidence });
const blank = (): PosePoint[] =>
  Array.from({ length: 33 }, () => point(0.5, 0.5, 0));

const LEFT = {
  shoulder: [0.30, 0.40] as [number, number],
  elbow: [0.45, 0.40] as [number, number],
  wrist: [0.60, 0.40] as [number, number],
};
const RIGHT = {
  shoulder: [0.70, 0.40] as [number, number],
  elbow: [0.55, 0.40] as [number, number],
  wrist: [0.40, 0.40] as [number, number],
};

function armPoints(
  points: PosePoint[],
  indices: { shoulder: number; elbow: number; wrist: number },
  coords: typeof LEFT
): PosePoint[] {
  const copy = points.slice();
  copy[indices.shoulder] = point(...coords.shoulder);
  copy[indices.elbow] = point(...coords.elbow);
  copy[indices.wrist] = point(...coords.wrist);
  return copy;
}

function observation(overrides: Partial<RigObservation> = {}): RigObservation {
  return {
    landmarks: armPoints(
      armPoints(blank(), RIG_ARM_LANDMARKS.left, LEFT),
      RIG_ARM_LANDMARKS.right, RIGHT
    ),
    session: 1, frameId: 1, capturedAtMs: 1_000, nowMs: 1_100,
    sourceWidth: SRC_W, sourceHeight: SRC_H,
    viewportWidth: SRC_W, viewportHeight: SRC_H,
    mirrored: false, focus: "whole", ...overrides,
  };
}

const frame = (overrides: Partial<RigObservation> = {}): RigFrame =>
  computeRigFrame(observation(overrides));

const position = (object: { getWorldPosition(target: Vector3): Vector3 }): Vector3 =>
  object.getWorldPosition(new Vector3());

function expectVector(actual: Vector3, x: number, y: number): void {
  expect(actual.x).toBeCloseTo(x, 6);
  expect(actual.y).toBeCloseTo(y, 6);
  expect(actual.z).toBeCloseTo(0, 6);
}

describe("W3a original Three.js articulated rig: hierarchy and geometry", () => {
  it("starts in a deterministic hidden rest pose", () => {
    const rig = new OriginalArticulatedRig();
    expect(rig.nodes.left.shoulderPivot.visible).toBe(false);
    expect(rig.nodes.right.shoulderPivot.visible).toBe(false);
    expect(rig.nodes.torso.visible).toBe(false);
    expect(rig.nodes.left.shoulderPivot.rotation.z).toBe(0);
    expect(rig.nodes.right.elbowPivot.position.y).toBe(0);
    expect(ORIGINAL_RIG_LABEL).toContain("Experimental · Uncalibrated");
    rig.dispose();
  });

  it("places the elbow child at the observed pivot and the forearm tip at the wrist", () => {
    const rig = new OriginalArticulatedRig();
    const pose = frame();
    expect(rig.apply(pose, 0.7)).toBe(4);
    expectVector(
      position(rig.nodes.left.shoulderPivot),
      pose.arms.left.upper!.start.x, pose.arms.left.upper!.start.y
    );
    expectVector(
      position(rig.nodes.left.elbowPivot),
      pose.arms.left.elbow!.x, pose.arms.left.elbow!.y
    );
    const tip = rig.nodes.left.attachedFore.localToWorld(new Vector3(0, 0.5, 0));
    expectVector(tip, pose.arms.left.wrist!.x, pose.arms.left.wrist!.y);
    rig.dispose();
  });

  it("keeps the elbow coherent while only the child rotates (elbow flexion)", () => {
    const rig = new OriginalArticulatedRig();
    const extended = frame();
    rig.apply(extended, 0.7);
    const elbowExtended = position(rig.nodes.left.elbowPivot).clone();
    const tipExtended = rig.nodes.left.attachedFore
      .localToWorld(new Vector3(0, 0.5, 0)).clone();

    const flexed = frame({
      landmarks: armPoints(
        armPoints(blank(), RIG_ARM_LANDMARKS.left, {
          ...LEFT, wrist: [0.45, 0.25],
        }),
        RIG_ARM_LANDMARKS.right, RIGHT
      ),
    });
    rig.apply(flexed, 0.7);
    const elbowFlexed = position(rig.nodes.left.elbowPivot);
    const tipFlexed = rig.nodes.left.attachedFore
      .localToWorld(new Vector3(0, 0.5, 0));
    expectVector(elbowFlexed, elbowExtended.x, elbowExtended.y);
    expect(Math.hypot(tipFlexed.x - tipExtended.x, tipFlexed.y - tipExtended.y))
      .toBeGreaterThan(20);
    expectVector(tipFlexed, flexed.arms.left.wrist!.x, flexed.arms.left.wrist!.y);
    rig.dispose();
  });

  it("applies parent-relative rotation inherited through the real hierarchy", () => {
    const rig = new OriginalArticulatedRig();
    const pose = frame();
    rig.apply(pose, 0.7);
    expect(rig.nodes.left.shoulderPivot.rotation.z)
      .toBeCloseTo(pose.arms.left.upper!.angleRadians - Math.PI / 2, 9);
    expect(rig.nodes.left.elbowPivot.rotation.z)
      .toBeCloseTo(pose.arms.left.fore!.parentRelativeRadians ?? 0, 9);
    expect(rig.nodes.left.elbowPivot.parent).toBe(rig.nodes.left.shoulderPivot);
    expect(rig.nodes.left.attachedFore.parent).toBe(rig.nodes.left.elbowPivot);
    rig.dispose();
  });

  it("has no cumulative rotation or position drift over repeated identical frames", () => {
    const rig = new OriginalArticulatedRig();
    const pose = frame();
    rig.apply(pose, 0.7);
    const elbow = [...rig.nodes.left.elbowPivot.matrixWorld.elements];
    const fore = [...rig.nodes.left.attachedFore.matrixWorld.elements];
    const pivot = [...rig.nodes.left.shoulderPivot.matrixWorld.elements];
    for (let i = 0; i < 25; i++) rig.apply(pose, 0.7);
    expect([...rig.nodes.left.elbowPivot.matrixWorld.elements]).toEqual(elbow);
    expect([...rig.nodes.left.attachedFore.matrixWorld.elements]).toEqual(fore);
    expect([...rig.nodes.left.shoulderPivot.matrixWorld.elements]).toEqual(pivot);
    rig.dispose();
  });

  it("reuses immutable source geometry/materials instead of allocating per frame", () => {
    const rig = new OriginalArticulatedRig();
    const children = rig.root.children.length;
    const boneId = rig.nodes.left.upper.geometry.uuid;
    const jointId = rig.nodes.left.elbowJoint.geometry.uuid;
    const materialId = (rig.nodes.left.upper.material as MeshStandardMaterial).uuid;
    for (let i = 0; i < 10; i++) rig.apply(frame(), 0.65);
    expect(rig.root.children.length).toBe(children);
    expect(rig.nodes.left.upper.geometry.uuid).toBe(boneId);
    expect(rig.nodes.left.elbowJoint.geometry.uuid).toBe(jointId);
    expect((rig.nodes.left.upper.material as MeshStandardMaterial).uuid).toBe(materialId);
    expect(rig.nodes.left.upper.geometry).toBe(rig.nodes.right.upper.geometry);
    expect(rig.nodes.left.upper.geometry.getAttribute("position").count)
      .toBeGreaterThan(0);
    rig.dispose();
  });

  it("mirrors display placement with the same deterministic hierarchy", () => {
    const rig = new OriginalArticulatedRig();
    const pose = frame({ mirrored: true });
    rig.apply(pose, 0.7);
    expectVector(position(rig.nodes.left.elbowPivot),
      pose.arms.left.elbow!.x, pose.arms.left.elbow!.y);
    const tip = rig.nodes.left.attachedFore.localToWorld(new Vector3(0, 0.5, 0));
    expectVector(tip, pose.arms.left.wrist!.x, pose.arms.left.wrist!.y);
    rig.dispose();
  });
});

describe("W3a original rig: partial observations and lifecycle", () => {
  it("keeps one arm alive when the other disappears from view", () => {
    const rig = new OriginalArticulatedRig();
    rig.apply(frame(), 0.7);
    expect(rig.apply(frame({
      landmarks: armPoints(blank(), RIG_ARM_LANDMARKS.right, RIGHT),
    }), 0.7)).toBe(2);
    expect(rig.nodes.right.shoulderPivot.visible).toBe(true);
    expect(rig.nodes.right.attachedFore.visible).toBe(true);
    expect(rig.nodes.left.shoulderPivot.visible).toBe(false);
    expect(rig.nodes.left.upper.visible).toBe(false);
    expect(rig.nodes.left.independentFore.visible).toBe(false);
    expect(rig.nodes.torso.visible).toBe(false);
    rig.dispose();
  });

  it("draws a shoulder-less forearm independently without inventing a parent", () => {
    const rig = new OriginalArticulatedRig();
    const points = blank();
    points[RIG_ARM_LANDMARKS.left.elbow] = point(0.45, 0.40);
    points[RIG_ARM_LANDMARKS.left.wrist] = point(0.60, 0.40);
    const pose = computeRigFrame(observation({ landmarks: points }));
    expect(rig.apply(pose, 0.7)).toBe(1);
    expect(rig.nodes.left.shoulderPivot.visible).toBe(false);
    expect(rig.nodes.left.elbowPivot.visible).toBe(false);
    expect(rig.nodes.left.independentPivot.visible).toBe(true);
    const tip = rig.nodes.left.independentFore.localToWorld(new Vector3(0, 0.5, 0));
    expectVector(tip, pose.arms.left.wrist!.x, pose.arms.left.wrist!.y);
    rig.dispose();
  });

  it("hides everything for a rejected, stale or empty observation", () => {
    const rig = new OriginalArticulatedRig();
    rig.apply(frame(), 0.7);
    expect(rig.apply(computeRigFrame(observation({ landmarks: null })), 0.7)).toBe(0);
    expect(rig.nodes.left.shoulderPivot.visible).toBe(false);
    expect(rig.nodes.right.attachedFore.visible).toBe(false);
    expect(rig.nodes.torso.visible).toBe(false);
    expect(rig.apply(frame(), 0.7)).toBe(4); // recovers on the next valid frame
    rig.dispose();
  });

  it("explicitly disposes geometries, materials and detaches the root", () => {
    const rig = new OriginalArticulatedRig();
    const geometry = rig.nodes.left.upper.geometry;
    const joint = rig.nodes.left.elbowJoint.geometry;
    const torso = rig.nodes.torso.geometry;
    const material = rig.nodes.left.upper.material as MeshStandardMaterial;
    const geometrySpy = vi.spyOn(geometry, "dispose");
    const jointSpy = vi.spyOn(joint, "dispose");
    const torsoSpy = vi.spyOn(torso, "dispose");
    const materialSpy = vi.spyOn(material, "dispose");
    rig.apply(frame(), 0.7);
    rig.dispose();
    expect(rig.isDisposed).toBe(true);
    expect(geometrySpy).toHaveBeenCalledTimes(1);
    expect(jointSpy).toHaveBeenCalledTimes(1);
    expect(torsoSpy).toHaveBeenCalledTimes(1);
    expect(materialSpy).toHaveBeenCalledTimes(1);
    expect(rig.root.parent).toBeNull();
    expect(rig.apply(frame(), 0.7)).toBe(0);
    rig.dispose(); // idempotent
    expect(geometrySpy).toHaveBeenCalledTimes(1);
  });

  it("clamps opacity instead of producing invalid material state", () => {
    const rig = new OriginalArticulatedRig();
    rig.apply(frame(), Number.NaN);
    const material = rig.nodes.left.upper.material as { opacity: number };
    expect(material.opacity).toBeGreaterThan(0);
    expect(material.opacity).toBeLessThanOrEqual(0.95);
    rig.dispose();
  });
});
