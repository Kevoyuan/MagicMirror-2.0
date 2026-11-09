import { describe, expect, it } from "vitest";
import { buildLocalAtlasInventory } from "./atlas-inventory";
import {
  completeAnchorPairCount, makeAnchorDraft, parseAnchorDraft,
  sufficientAnchorDistance, validSourcePoint,
} from "./atlas-anchors";

const inventory = buildLocalAtlasInventory({
  fileName: "SkeletalSystem100.fbx", fileSizeBytes: 1000,
  sourceSHA256: "b".repeat(64), importedMeshes: 2, triangles: 400,
  skinnedMeshes: 0, authoredJoints: 0,
  parts: [
    { id: 0, name: "Bone_01", path: "Root / Bone_01", triangles: 200, visible: true },
    { id: 1, name: "Bone_02", path: "Root / Bone_02", triangles: 200, visible: true },
  ],
});
const segments = new Map([[0, "left-upper-arm"], [1, "left-forearm"]] as const);
const endpoints = new Map([
  [0, { start: [10, 0, -1] as const, end: [8, 2, 4] as const }],
  [1, { start: [2, 3, 4] as const, end: null }],
]);

describe("private author-selected local model coordinate anchors", () => {
  it("roundtrips only original SHA bound, mapped, uncalibrated endpoints", () => {
    const draft = makeAnchorDraft(inventory, segments, endpoints);
    expect(draft.anchors).toHaveLength(2);
    expect(draft).toMatchObject({
      commercialReuseStatus: "NOT_REVIEWED",
      calibrationStatus: "MANUAL_POINTS_NOT_CALIBRATED",
      sourceCoordinateFrame: "ORIGINAL_ROOT_LOCAL_UNVERIFIED",
      retargetingStatus: "NOT_READY",
    });
    expect(parseAnchorDraft(draft, inventory, segments)).toEqual(endpoints);
    expect(completeAnchorPairCount(endpoints)).toBe(1);
  });
  it("handles hidden/intermediate model points without treating them as actual joints", () => {
    expect(validSourcePoint([-10, 2, 500])).toBe(true);
    expect(validSourcePoint([0, NaN, 0])).toBe(false);
    expect(validSourcePoint([0, 1])).toBe(false);
    expect(validSourcePoint([1e20, 0, 0])).toBe(false);
    expect(sufficientAnchorDistance([0, 0, 0], [0, 0, 0])).toBe(false);
    expect(sufficientAnchorDistance([0, 0, 0], [0, 1e-4, 0])).toBe(true);
  });
  it("rejects different source and changed human mapping without partial import", () => {
    const draft = makeAnchorDraft(inventory, segments, endpoints);
    expect(() => parseAnchorDraft({
      ...draft, source: { ...draft.source, sha256: "a".repeat(64) }
    }, inventory, segments)).toThrow(/SHA-256/);
    expect(() => parseAnchorDraft(draft, inventory,
      new Map([[0, "right-upper-arm"]] as const))).toThrow(/unmapped/);
  });
  it("blocks forged claims, duplicate source parts, bad positions and unknown metadata", () => {
    const draft = makeAnchorDraft(inventory, segments, endpoints);
    expect(() => parseAnchorDraft({
      ...draft, calibrationStatus: "APPROVED"
    }, inventory, segments)).toThrow(/calibrated/);
    expect(() => parseAnchorDraft({
      ...draft, clinicallyAccurate: true
    }, inventory, segments)).toThrow(/forged/);
    expect(() => parseAnchorDraft({
      ...draft, anchors: [draft.anchors[0], draft.anchors[0]]
    }, inventory, segments)).toThrow();
    expect(() => parseAnchorDraft({
      ...draft, anchors: [{ ...draft.anchors[0], start: [Infinity, 0, 0] }]
    }, inventory, segments)).toThrow();
    expect(() => parseAnchorDraft({
      ...draft, anchors: [{ ...draft.anchors[0], end: [10, 0, -1] }]
    }, inventory, segments)).toThrow(/overlap/);
  });
});
