import { describe, expect, it } from "vitest";
import { inspectRigSamples, usableAnimationStudyClip } from "./rig-diagnostics";

describe("only genuinely authored skinning is eligible for rig diagnostics", () => {
  it("recognizes valid authored joint weights using bounded samples", () => {
    const r = inspectRigSamples({
      vertexCount: 3, jointCount: 2, influenceSlots: 4,
      readWeight: (_v, s) => (s === 0 ? 0.75 : s === 1 ? 0.25 : 0),
      readJoint: (_v, s) => s === 1 ? 1 : 0,
    });
    expect(r).toMatchObject({
      sampledVertices: 3, influencedVertices: 3,
      unweightedVertices: 0, invalidWeightSamples: 0,
      invalidJointReferences: 0, suspiciousWeightSums: 0,
      maxActiveInfluences: 2,
    });
  });
  it("reports unweighted vertices and invalid joint references without inventing weights", () => {
    const r = inspectRigSamples({
      vertexCount: 2, jointCount: 1, influenceSlots: 2,
      readWeight: (v, s) => v === 0 ? 0 : s === 0 ? 0.6 : 0,
      readJoint: (_v, s) => s === 0 ? 8 : 0,
    });
    expect(r.unweightedVertices).toBe(1);
    expect(r.invalidJointReferences).toBe(1);
    expect(r.suspiciousWeightSums).toBe(1);
  });
  it("rejects malformed or nonfinite weights with safe upper sampling budgets", () => {
    const r = inspectRigSamples({
      vertexCount: 5000, jointCount: 4, influenceSlots: 1,
      readWeight: () => NaN,
      readJoint: () => 0,
    }, 128);
    expect(r.sampledVertices).toBeLessThanOrEqual(128);
    expect(r.invalidWeightSamples).toBe(r.sampledVertices);
    expect(() => inspectRigSamples({
      vertexCount: -1, jointCount: 2, influenceSlots: 4,
      readWeight: () => 0, readJoint: () => 0,
    })).toThrow();
  });
  it("prevents invalid or immense imported animation tracks from preview", () => {
    expect(usableAnimationStudyClip({
      id: 0, name: "demo", durationSeconds: 2, trackCount: 24,
    })).toBe(true);
    expect(usableAnimationStudyClip({
      id: 0, name: "unknown", durationSeconds: Infinity, trackCount: 24,
    })).toBe(false);
    expect(usableAnimationStudyClip({
      id: 1, name: "oversized", durationSeconds: 10, trackCount: 12000,
    })).toBe(false);
  });
});
