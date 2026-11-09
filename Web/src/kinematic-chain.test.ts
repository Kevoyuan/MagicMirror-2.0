import { describe, expect, it } from "vitest";
import { Matrix4, Vector3 } from "three";
import {
  countLargeStudyGaps, orderStudyChain, studyChainDeltas,
  studyGhostWorldMatrix, studyParentGapRatio,
  transformedStudyPoint, type StudyChainNode,
} from "./kinematic-chain";

const root: StudyChainNode = {
  sourceMeshId: 0, parentMeshId: null,
  start: [0, 0, 0], end: [1, 0, 0], axis: "z", degrees: 90,
};
const child: StudyChainNode = {
  sourceMeshId: 1, parentMeshId: 0,
  start: [1, 0, 0], end: [2, 0, 0], axis: "z", degrees: 90,
};
const grandchild: StudyChainNode = {
  sourceMeshId: 2, parentMeshId: 1,
  start: [2, 0, 0], end: [3, 0, 0], axis: "z", degrees: 0,
};
function approxPoint(actual: readonly number[] | null, expected: number[]): void {
  expect(actual).not.toBeNull();
  for (let i = 0; i < 3; i++) expect(actual![i]).toBeCloseTo(expected[i], 8);
}

describe("W2g source-space virtual hierarchy without skinning or calibration", () => {
  it("topologically orders deliberately out-of-order parent/child source meshes", () => {
    expect(orderStudyChain([grandchild, child, root]).map(n => n.sourceMeshId))
      .toEqual([0, 1, 2]);
  });

  it("propagates parent rotation to child and child to grandchild", () => {
    const deltas = studyChainDeltas([grandchild, root, child]);
    approxPoint(transformedStudyPoint(child.start, deltas.get(1)!), [0, 1, 0]);
    approxPoint(transformedStudyPoint(child.end, deltas.get(1)!), [-1, 1, 0]);
    // Grandchild rest end [3,0,0] follows TWO 90° pivots.
    approxPoint(transformedStudyPoint(grandchild.end, deltas.get(2)!), [-2, 1, 0]);
  });

  it("keeps original source meshes untouched, even with rotated/translated roots", () => {
    const rootWorld = new Matrix4().makeTranslation(9, 4, -1)
      .multiply(new Matrix4().makeRotationY(0.25));
    const sourceMeshWorld = rootWorld.clone()
      .multiply(new Matrix4().makeTranslation(2, 0, 0));
    const before = sourceMeshWorld.clone();
    const delta = studyChainDeltas([child, root]).get(1)!;
    const ghost = studyGhostWorldMatrix(rootWorld, sourceMeshWorld, delta)!;
    expect(ghost.equals(before)).toBe(false);
    expect(sourceMeshWorld.equals(before)).toBe(true);
    const localExpected = rootWorld.clone()
      .multiply(delta)
      .multiply(new Matrix4().makeTranslation(2, 0, 0));
    for (let i = 0; i < 16; i++) {
      expect(ghost.elements[i]).toBeCloseTo(localExpected.elements[i], 8);
    }
    const movedOrigin = new Vector3(0, 0, 0).applyMatrix4(ghost);
    expect(Number.isFinite(movedOrigin.x)).toBe(true);
  });

  it("reports large original-root endpoint gaps without asserting real joint continuity", () => {
    expect(studyParentGapRatio(root, child)).toBeCloseTo(0);
    expect(countLargeStudyGaps([root, child])).toBe(0);
    const far = { ...child, start: [100, 0, 0] as const };
    expect(countLargeStudyGaps([root, far])).toBe(1);
  });

  it("rejects cycles, self-parents, missing parents and duplicate mesh IDs", () => {
    expect(() => orderStudyChain([
      { ...root, parentMeshId: 1 }, child
    ])).toThrow(/cycle/);
    expect(() => orderStudyChain([
      root, { ...child, parentMeshId: 1 }
    ])).toThrow(/itself/);
    expect(() => orderStudyChain([
      root, { ...child, parentMeshId: 18 }
    ])).toThrow(/unselected/);
    expect(() => orderStudyChain([root, root])).toThrow(/duplicate/);
  });

  it("bounds source parts/angles and rejects absent or degenerate anchors", () => {
    expect(() => orderStudyChain([root])).toThrow(/2–12/);
    expect(() => orderStudyChain(
      Array.from({ length: 13 }, (_, i) => ({ ...root, sourceMeshId: i }))
    )).toThrow(/2–12/);
    expect(() => studyChainDeltas([
      root, { ...child, degrees: 91 }
    ])).toThrow();
    expect(() => studyChainDeltas([
      root, { ...child, end: child.start }
    ])).toThrow();
    expect(studyGhostWorldMatrix(new Matrix4().makeScale(0, 1, 1),
      new Matrix4(), new Matrix4())).toBeNull();
  });

  it("replaying original rest + new angles never accumulates drift", () => {
    const a = studyChainDeltas([root, { ...child, degrees: 25 }]).get(1)!;
    const b = studyChainDeltas([root, { ...child, degrees: -30 }]).get(1)!;
    const direct = studyChainDeltas([root, { ...child, degrees: -30 }]).get(1)!;
    expect(a.equals(b)).toBe(false);
    expect(b.equals(direct)).toBe(true);
    const identity = studyChainDeltas([
      { ...root, degrees: 0 }, { ...child, degrees: 0 }
    ]);
    expect(identity.get(1)!.equals(new Matrix4())).toBe(true);
  });
});
