import { describe, expect, it } from "vitest";
import { makeDraftMapping, mappingDownloadName, parseDraftMapping, POSE_SEGMENTS } from "./atlas-mapping";
import { buildLocalAtlasInventory } from "./atlas-inventory";

const inventory = buildLocalAtlasInventory({
  fileName: "SkeletalSystem100.fbx",
  fileSizeBytes: 41_339_660,
  sourceSHA256: "a".repeat(64),
  importedMeshes: 3,
  triangles: 500,
  skinnedMeshes: 0,
  authoredJoints: 0,
  parts: [
    { id: 0, name: "Femur_L", path: "BoneGroup / Femur_L", triangles: 300, visible: true },
    { id: 1, name: "Femur_R", path: "BoneGroup / Femur_R", triangles: 100, visible: true },
    { id: 2, name: "Unknown", path: "Other / Unknown", triangles: 100, visible: false },
  ],
});

describe("no-authorization manual mesh-to-MediaPipe-segment drafts", () => {
  it("uses only observed MediaPipe proxy segments, not inferred bones", () => {
    expect(POSE_SEGMENTS).toHaveLength(12);
    expect(POSE_SEGMENTS[0]).toMatchObject({ from: 11, to: 13 });
    const mapped = new Map([[0, "left-thigh"], [1, "right-thigh"]] as const);
    const draft = makeDraftMapping(inventory, mapped);
    expect(draft).toMatchObject({
      commercialReuseStatus: "NOT_REVIEWED",
      mappingStatus: "USER_DRAFT_ONLY",
      sourceCoordinateFrame: "UNVERIFIED",
      retargetingStatus: "NOT_READY",
    });
    expect(draft.assignments.map(x => x.sourceMeshId)).toEqual([0, 1]);
    expect(draft.assignments[0].reviewStatus).toBe("USER_DRAFT_UNCALIBRATED");
    expect(parseDraftMapping(draft, inventory)).toEqual(mapped);
  });
  it("rejects modified source identity, geometries or original names", () => {
    const mapping = makeDraftMapping(inventory, new Map([[0, "left-thigh"]]));
    expect(() => parseDraftMapping({
      ...mapping, source: { ...mapping.source, sha256: "b".repeat(64) }
    }, inventory)).toThrow(/SHA-256/);
    expect(() => parseDraftMapping({
      ...mapping, assignments: [{ ...mapping.assignments[0], originalTriangles: 6 }]
    }, inventory)).toThrow(/altered/);
    expect(() => parseDraftMapping({
      ...mapping, assignments: [{ ...mapping.assignments[0], originalMeshName: "Forged" }]
    }, inventory)).toThrow(/altered/);
  });
  it("rejects duplicate assignments, unknown body segments and any fake approval flags", () => {
    const mapping = makeDraftMapping(inventory, new Map([[0, "left-thigh"]]));
    expect(() => parseDraftMapping({
      ...mapping, assignments: [mapping.assignments[0], mapping.assignments[0]]
    }, inventory)).toThrow(/Duplicate/);
    expect(() => parseDraftMapping({
      ...mapping, assignments: [{ ...mapping.assignments[0], poseSegment: "spine" }]
    }, inventory)).toThrow();
    expect(() => parseDraftMapping({
      ...mapping, commercialReuseStatus: "APPROVED"
    }, inventory)).toThrow();
    expect(() => parseDraftMapping({
      ...mapping, anatomicalReviewApproved: true
    }, inventory)).toThrow(/Unexpected/);
  });
  it("exports safe explicit local filenames, never raw source paths", () => {
    expect(mappingDownloadName("../../SkeletalSystem100.fbx")).toBe(
      "MagicMirror-SkeletalSystem100-manual-pose-map.json"
    );
    expect(mappingDownloadName("未知文件.glb")).toBe(
      "MagicMirror-local_atlas-manual-pose-map.json"
    );
  });
  it("blocks invented part IDs and may export an empty draft", () => {
    expect(makeDraftMapping(inventory, new Map()).assignments).toEqual([]);
    expect(() => makeDraftMapping(inventory, new Map([[50, "right-shin"]]))).toThrow();
  });
});
