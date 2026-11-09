import { describe, expect, it } from "vitest";
import { Matrix4, Vector3 } from "three";
import {
  previewMeshLocalMatrix, sourceRootRigidDelta,
  transformedSourceEnd, validRigidAngle,
} from "./rigid-preview";

const start = [0, 0, 0] as const;
const end = [0, 2, 0] as const;
function at(matrix: Matrix4, point: [number, number, number]): Vector3 {
  return new Vector3(...point).applyMatrix4(matrix);
}

describe("W2f reversible, source-local rigid pose preview", () => {
  it("rotation about a user-selected pivot moves endpoint, leaves pivot unchanged", () => {
    const delta = sourceRootRigidDelta(start, end, "z", 90)!;
    const pivot = at(delta, [0, 0, 0]);
    const moved = at(delta, [0, 2, 0]);
    expect(pivot.distanceTo(new Vector3(0, 0, 0))).toBeLessThan(1e-8);
    expect(moved.distanceTo(new Vector3(-2, 0, 0))).toBeLessThan(1e-8);
    expect(transformedSourceEnd(start, end, "z", 90)?.[0]).toBeCloseTo(-2);
    expect(transformedSourceEnd(start, end, "z", 0)).toEqual(end);
  });

  it("preserves original source transform through arbitrary transformed ancestor frames", () => {
    const root = new Matrix4().makeTranslation(10, 3, 1)
      .multiply(new Matrix4().makeRotationY(Math.PI / 4));
    const parent = root.clone().multiply(new Matrix4().makeTranslation(4, 0, 0));
    const originalWorld = parent.clone().multiply(new Matrix4().makeTranslation(0, 2, 0));
    const local = previewMeshLocalMatrix(
      root, parent, originalWorld, start, end, "z", 90
    )!;
    const actualWorld = parent.clone().multiply(local);
    const expectedWorld = root.clone()
      .multiply(sourceRootRigidDelta(start, end, "z", 90)!)
      .multiply(root.clone().invert()).multiply(originalWorld);
    expect(actualWorld.elements).toEqual(
      expect.arrayContaining([])
    );
    for (let i = 0; i < 16; i++) {
      expect(actualWorld.elements[i]).toBeCloseTo(expectedWorld.elements[i], 8);
    }
    const reset = previewMeshLocalMatrix(
      root, parent, originalWorld, start, end, "x", 0
    )!;
    const baseline = parent.clone().invert().multiply(originalWorld);
    for (let i = 0; i < 16; i++) {
      expect(reset.elements[i]).toBeCloseTo(baseline.elements[i], 9);
    }
  });

  it("fails closed for absent, identical, malformed and extreme preview input", () => {
    expect(sourceRootRigidDelta(start, start, "y", 30)).toBeNull();
    expect(sourceRootRigidDelta(null, end, "x", 10)).toBeNull();
    expect(sourceRootRigidDelta([NaN, 0, 0], end, "z", 10)).toBeNull();
    expect(sourceRootRigidDelta(start, end, "z", 91)).toBeNull();
    expect(sourceRootRigidDelta(start, end, "a" as "x", 10)).toBeNull();
    expect(validRigidAngle(-90)).toBe(true);
    expect(validRigidAngle(-91)).toBe(false);
    expect(validRigidAngle(Infinity)).toBe(false);
    expect(previewMeshLocalMatrix(
      new Matrix4().makeScale(0, 0, 0), new Matrix4(),
      new Matrix4(), start, end, "z", 10
    )).toBeNull();
  });

  it("never accumulates drift: each output is computed from original baseline", () => {
    const identity = new Matrix4();
    const original = new Matrix4().makeTranslation(0, 2, 0);
    const a = previewMeshLocalMatrix(identity, identity, original, start, end, "z", 15)!;
    previewMeshLocalMatrix(identity, identity, a, start, end, "z", 35);
    const b = previewMeshLocalMatrix(identity, identity, original, start, end, "z", 35)!;
    const expected = sourceRootRigidDelta(start, end, "z", 35)!.multiply(original);
    for (let i = 0; i < 16; i++) expect(b.elements[i]).toBeCloseTo(expected.elements[i], 9);
  });
});
