import { describe, expect, it } from "vitest";
import { buildLocalAtlasInventory, inventoryDownloadName } from "./atlas-inventory";

const data = {
  fileName: "SkeletalSystem100.fbx",
  fileSizeBytes: 41_339_660,
  sourceSHA256: "a".repeat(64),
  importedMeshes: 2,
  triangles: 300,
  skinnedMeshes: 0,
  authoredJoints: 0,
  parts: [
    { id: 0, name: "Bone_A", path: "Root / Bone_A", triangles: 200, visible: true },
    { id: 1, name: "Bone_B", path: "Root / Bone_B", triangles: 100, visible: false },
  ],
};
describe("private original-model source inventory export", () => {
  it("keeps file identity/real source names while asserting NO rights review", () => {
    const result = buildLocalAtlasInventory(data);
    expect(result).toMatchObject({
      schemaVersion: 1, rightsStatus: "NOT_REVIEWED",
      sourceSHA256: "a".repeat(64),
      observedGeometry: { sourceMeshCount: 2, authoredJointCount: 0 },
    });
    expect(result.perMesh[1]).toMatchObject({
      originalHierarchyPath: "Root / Bone_B",
      commercialReuseReviewed: false, licenseEvidence: null,
    });
    expect(JSON.stringify(result)).not.toContain("commercialReuseReviewed\":true");
  });
  it("cannot fabricate an approved source review from malformed hashes/parts", () => {
    expect(() => buildLocalAtlasInventory({ ...data, sourceSHA256: "unknown" })).toThrow();
    expect(() => buildLocalAtlasInventory({ ...data, importedMeshes: 3 })).toThrow();
    expect(() => buildLocalAtlasInventory({
      ...data, parts: [{ ...data.parts[0], id: 42 }, data.parts[1]]
    })).toThrow();
  });
  it("exports a safe, explicit local JSON filename", () => {
    expect(inventoryDownloadName("../../SkeletalSystem100.fbx")).toBe(
      "MagicMirror-SkeletalSystem100-source-inventory.json"
    );
    expect(inventoryDownloadName("未知模型.fbx")).toBe(
      "MagicMirror-_-source-inventory.json"
    );
  });
});
