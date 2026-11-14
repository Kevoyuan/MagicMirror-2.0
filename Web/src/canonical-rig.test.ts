import { describe, expect, it } from "vitest";
import {
  CANONICAL_RIG_REST, auditCanonicalRigRest, auditProposedWeightSamples,
  type CanonicalRigJoint,
} from "./canonical-rig";

const copy = (): CanonicalRigJoint[] => CANONICAL_RIG_REST.map(j => ({
  id: j.id, parent: j.parent,
  position: [...j.position] as [number, number, number],
}));

describe("W2n1 original canonical 19-joint rest rig (not an anatomical atlas)", () => {
  it("has one valid authored joint tree and permanent non-approval flags", () => {
    expect(CANONICAL_RIG_REST).toHaveLength(19);
    const a = auditCanonicalRigRest(copy());
    expect(a).toMatchObject({
      count: 19, status: "plausible-original-fixture", failures: [],
      units: "authored-fictional-units",
      anatomicalVerificationApproved: false,
      cameraRegistrationApproved: false,
      retargetingApproved: false,
      publicationRightsApproved: false,
    });
  });

  it("requires exact canonical joint IDs and parenting, never arbitrary mesh names", () => {
    const bad = copy();
    bad[7] = { ...bad[7], parent: "pelvis" };
    expect(auditCanonicalRigRest(bad).failures).toContain("wrong-parent");
    const missing = copy().slice(1);
    expect(auditCanonicalRigRest(missing).failures).toContain("canonical-joint-count");
    const repeated = copy();
    repeated[2] = { ...repeated[2], id: "spine" };
    expect(auditCanonicalRigRest(repeated).failures).toContain("unknown-or-duplicate-joint");
  });

  it("rejects missing/zero-length bone axes and nonfinite rest positions", () => {
    const zero = copy();
    zero[6] = { ...zero[6], position: [...zero[5].position] };
    expect(auditCanonicalRigRest(zero).failures).toContain("invalid-bone-length");
    const finite = copy();
    finite[8] = { ...finite[8], position: [Infinity, 0, 0] };
    expect(auditCanonicalRigRest(finite).failures).toContain("invalid-rest-coordinate");
  });

  it("refuses swapped left-right, inverted legs or displaced pelvis", () => {
    const left = copy();
    left[6] = { ...left[6], position: [-0.5, 0.5, 0] };
    expect(auditCanonicalRigRest(left).failures).toContain("invalid-left-side-axis");
    const right = copy();
    right[9] = { ...right[9], position: [0.5, 0.5, 0] };
    expect(auditCanonicalRigRest(right).failures).toContain("invalid-right-side-axis");
    const root = copy();
    root[0] = { ...root[0], position: [0.1, 0, 0] };
    expect(auditCanonicalRigRest(root).failures).toContain("root-must-be-origin");
    const legs = copy();
    legs[12] = { ...legs[12], position: [0.2, 0.2, 0] };
    expect(auditCanonicalRigRest(legs).failures).toContain("invalid-leg-direction");
  });

  it("accepts two smoothly blended original skin influences while never certifying anatomy", () => {
    const a = auditProposedWeightSamples(3, [
      { vertexIndex: 0, influences: [{ joint: "pelvis", weight: 1 }] },
      { vertexIndex: 1, influences: [
        { joint: "left_elbow", weight: 0.7 },
        { joint: "left_wrist", weight: 0.3 },
      ] },
      { vertexIndex: 2, influences: [{ joint: "left_wrist", weight: 1 }] },
    ]);
    expect(a).toMatchObject({
      inspected: 3, badIndices: 0, unweighted: 0,
      badNormalization: 0, badJointReferences: 0,
      tooManyInfluences: 0, onlySampled: true,
      actualMeshSkinningVerified: false, anatomyRigApproved: false,
    });
  });

  it("flags missing weights, too many influences, duplicates and unknown joints", () => {
    const a = auditProposedWeightSamples(10, [
      { vertexIndex: 0, influences: [] },
      { vertexIndex: 0, influences: [{ joint: "pelvis", weight: 0.5 }] },
      { vertexIndex: 999, influences: [{ joint: "not_real" as never, weight: 1 }] },
      { vertexIndex: 3, influences: [
        { joint: "spine", weight: 0.2 },
        { joint: "spine", weight: 0.8 },
      ] },
      { vertexIndex: 4, influences: [
        { joint: "pelvis", weight: 0.2 },
        { joint: "spine", weight: 0.2 },
        { joint: "chest", weight: 0.2 },
        { joint: "neck", weight: 0.2 },
        { joint: "head", weight: 0.2 },
      ] },
    ]);
    expect(a.unweighted).toBe(1);
    expect(a.badIndices).toBe(2);
    expect(a.badNormalization).toBe(1);
    expect(a.badJointReferences).toBeGreaterThanOrEqual(2);
    expect(a.tooManyInfluences).toBe(1);
    expect(a.anatomyRigApproved).toBe(false);
  });

  it("rejects malformed or oversized proposed sample budgets", () => {
    expect(() => auditProposedWeightSamples(0, [])).toThrow();
    expect(() => auditProposedWeightSamples(3, [])).toThrow();
    expect(() => auditProposedWeightSamples(3, Array.from({ length: 2049 }, (_, i) =>
      ({ vertexIndex: i, influences: [] })
    ))).toThrow();
  });
});
