import { describe, expect, it } from "vitest";
import { buildLocalAtlasInventory } from "./atlas-inventory";
import {
  makeRightsWorksheet, auditRightsWorksheet,
  rightsWorksheetDownloadName, MAX_RIGHTS_WORKSHEET_BYTES,
} from "./atlas-rights";

const inventory = buildLocalAtlasInventory({
  fileName: "Study Bones.fbx", fileSizeBytes: 12001,
  sourceSHA256: "b".repeat(64), importedMeshes: 3, triangles: 600,
  skinnedMeshes: 0, authoredJoints: 0,
  parts: [
    { id: 0, name: "Bone A", path: "Root / Bone A", triangles: 100, visible: true },
    { id: 1, name: "Inner Ear", path: "Root / Inner Ear", triangles: 200, visible: true },
    { id: 2, name: "Kidney", path: "Root / Kidney", triangles: 300, visible: false },
  ],
});
function editable(): any {
  return JSON.parse(JSON.stringify(makeRightsWorksheet(inventory)));
}
function fill(row: any, licenseId: string): void {
  row.licenseId = licenseId;
  row.author = "Verified later by human";
  row.originalSourceURL = "https://example.org/anatomy/source";
  row.licenseEvidenceURL = "https://example.org/anatomy/license";
  row.attribution = "Research notes - not a license grant";
}
describe("W2m per-mesh rights worksheet on a REAL local inventory identity", () => {
  it("starts with a separate unknown-rights row per actual source mesh", () => {
    const draft = makeRightsWorksheet(inventory);
    expect(draft.entries).toHaveLength(3);
    expect(draft.entries[1].sourceMeshName).toBe("Inner Ear");
    expect(draft.entries[2].sourceHierarchyPath).toBe("Root / Kidney");
    expect(draft.entries.every(x => x.reviewStatus === "NOT_REVIEWED" &&
      x.licenseId === "UNVERIFIED" && x.author === null)).toBe(true);
    const audit = auditRightsWorksheet(draft, inventory);
    expect(audit).toMatchObject({
      count: 3, missingEvidence: 3, unresolvedLicense: 3,
      nonCommercial: 0, status: "NOT_REVIEWED",
      redistributionApproved: false, commercialUseApproved: false,
    });
  });
  it("flags upstream-like noncommercial exceptions and share-alike separately", () => {
    const draft = editable();
    fill(draft.entries[0], "CC-BY-SA-4.0");
    fill(draft.entries[1], "CC-BY-NC-SA-4.0");
    fill(draft.entries[2], "CC-BY-NC-4.0");
    const result = auditRightsWorksheet(draft, inventory);
    expect(result.nonCommercial).toBe(2);
    expect(result.shareAlike).toBe(2);
    expect(result.missingEvidence).toBe(0);
    expect(result.unresolvedLicense).toBe(0);
    expect(result.readyForHumanReview).toBe(1);
    expect(result.redistributionApproved).toBe(false);
    expect(result.commercialUseApproved).toBe(false);
  });
  it("does NOT accept license claims as legal approval, even with evidence URLs", () => {
    const draft = editable();
    for (const row of draft.entries) fill(row, "CC-BY-4.0");
    const result = auditRightsWorksheet(draft, inventory);
    expect(result.readyForHumanReview).toBe(3);
    expect(result.status).toBe("NOT_REVIEWED");
    expect(result.redistributionApproved).toBe(false);
    expect(result.commercialUseApproved).toBe(false);
    expect(result.note).toBe("HUMAN_PER_MESH_RIGHTS_REVIEW_REQUIRED");
  });
  it("prevents cross-source worksheet replay and source mesh swaps", () => {
    const draft = editable();
    draft.sourceSHA256 = "c".repeat(64);
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/different/);
    draft.sourceSHA256 = inventory.sourceSHA256;
    draft.entries[0].sourceHierarchyPath = draft.entries[1].sourceHierarchyPath;
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/identity/);
    draft.entries[0].sourceHierarchyPath = inventory.perMesh[0].originalHierarchyPath;
    draft.sourceSizeBytes += 1;
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/different/);
  });
  it("refuses attempts to claim licensing, publication or commercial approval", () => {
    const draft = editable();
    draft.redistributionApproved = true;
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/cannot claim/);
    draft.redistributionApproved = false;
    draft.entries[0].reviewStatus = "CLEARED";
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/unreviewed/);
    draft.entries[0].reviewStatus = "NOT_REVIEWED";
    draft.entries[0].licenseId = "CC0";
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/unreviewed/);
  });
  it("rejects extra injected keys, insecure source URLs and unbounded free text", () => {
    const draft = editable();
    draft.entries[0].userGPS = "private";
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/unsupported/);
    delete draft.entries[0].userGPS;
    draft.entries[0].originalSourceURL = "javascript:alert(1)";
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/insecure/);
    draft.entries[0].originalSourceURL = "https://me:password@example.org/a";
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/insecure/);
    draft.entries[0].originalSourceURL = null;
    draft.entries[0].author = "X".repeat(241);
    expect(() => auditRightsWorksheet(draft, inventory)).toThrow(/attribution/);
  });
  it("preserves one safe local download filename and bounds the import", () => {
    expect(rightsWorksheetDownloadName("../Study Bones.fbx")).toBe(
      "MagicMirror-Study_Bones-mesh-rights-worksheet.json"
    );
    expect(MAX_RIGHTS_WORKSHEET_BYTES).toBe(8 * 1024 * 1024);
  });
});
