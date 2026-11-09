import { describe, expect, it } from "vitest";
import { ORIGINAL_STUDY_DEMO } from "./study-demo";
import { sufficientAnchorDistance } from "./atlas-anchors";
import { orderStudyChain, countLargeStudyGaps } from "./kinematic-chain";

describe("original camera-free three-box learning fixture", () => {
  it("supplies three distinct named source meshes with genuine geometric pivot data", () => {
    expect(ORIGINAL_STUDY_DEMO).toHaveLength(3);
    expect(new Set(ORIGINAL_STUDY_DEMO.map(p => p.sourceName)).size).toBe(3);
    for (const segment of ORIGINAL_STUDY_DEMO) {
      expect(sufficientAnchorDistance(segment.start, segment.end)).toBe(true);
    }
  });

  it("is a bounded, source-only hierarchy with original root coordinates", () => {
    const byName = new Map(ORIGINAL_STUDY_DEMO.map((s, i) => [s.sourceName, i]));
    const nodes = ORIGINAL_STUDY_DEMO.map((s, sourceMeshId) => ({
      sourceMeshId,
      parentMeshId: s.parentSourceName === null
        ? null : byName.get(s.parentSourceName)!,
      start: s.start, end: s.end, axis: "z" as const,
      degrees: s.initialAngle,
    }));
    expect(orderStudyChain(nodes)).toHaveLength(3);
    expect(countLargeStudyGaps(nodes)).toBe(0);
    expect(nodes.reduce((acc, item) => acc + item.degrees, 0)).toBe(10);
  });
});
