/**
 * W2m: per-mesh SOURCE-LOCKED legal-research worksheet for user-chosen models.
 *
 * Declared rights are UNVERIFIED user annotations. This module NEVER converts
 * a license label or URL into distribution/commercial/rigging permission.
 * It contains NO built-in Z-Anatomy mesh, metadata inference or downloads.
 */
import { inventoryDownloadName, type AtlasInventory } from "./atlas-inventory";

export type LicenseClaim =
  | "UNVERIFIED" | "CC-BY-SA-4.0" | "CC-BY-SA-2.1-JP"
  | "CC-BY-4.0" | "CC-BY-NC-SA-4.0" | "CC-BY-NC-4.0"
  | "PROPRIETARY" | "OTHER";

export const MAX_RIGHTS_WORKSHEET_BYTES = 8 * 1024 * 1024;
const LICENSES: readonly LicenseClaim[] = [
  "UNVERIFIED", "CC-BY-SA-4.0", "CC-BY-SA-2.1-JP", "CC-BY-4.0",
  "CC-BY-NC-SA-4.0", "CC-BY-NC-4.0", "PROPRIETARY", "OTHER",
];

export interface MeshRightsEntry {
  readonly sourceIndex: number;
  readonly sourceMeshName: string;
  readonly sourceHierarchyPath: string;
  readonly author: string | null;
  readonly originalSourceURL: string | null;
  readonly licenseId: LicenseClaim;
  readonly licenseEvidenceURL: string | null;
  readonly attribution: string | null;
  readonly derivativeNotes: string | null;
  readonly reviewStatus: "NOT_REVIEWED";
}
export interface RightsWorksheet {
  readonly schemaVersion: 1;
  readonly kind: "magicmirror.local-mesh-rights";
  readonly sourceSHA256: string;
  readonly sourceSizeBytes: number;
  readonly meshCount: number;
  readonly rightsStatus: "NOT_REVIEWED";
  readonly commercialUseApproved: false;
  readonly redistributionApproved: false;
  readonly entries: readonly MeshRightsEntry[];
}
export interface RightsAudit {
  readonly count: number;
  readonly nonCommercial: number;
  readonly shareAlike: number;
  readonly missingEvidence: number;
  readonly unresolvedLicense: number;
  readonly readyForHumanReview: number;
  readonly sourceLocked: true;
  readonly status: "NOT_REVIEWED";
  readonly redistributionApproved: false;
  readonly commercialUseApproved: false;
  readonly note: "HUMAN_PER_MESH_RIGHTS_REVIEW_REQUIRED";
}
function record(x: unknown, label: string): Record<string, unknown> {
  if (!x || typeof x !== "object" || Array.isArray(x)) throw new Error(label + " must be an object");
  return x as Record<string, unknown>;
}
function exactKeys(x: Record<string, unknown>, keys: readonly string[], label: string): void {
  if (keys.length !== Object.keys(x).length || keys.some(k => !(k in x))) {
    throw new Error(label + " has missing or unsupported fields");
  }
}
function optionalText(x: unknown, limit: number): x is string | null {
  return x === null ||
    (typeof x === "string" && x.trim() === x && x.length > 0 && x.length <= limit &&
     !/[\u0000-\u001f]/.test(x));
}
function optionalHTTPS(x: unknown): x is string | null {
  if (x === null) return true;
  if (!optionalText(x, 2048) || typeof x !== "string") return false;
  try {
    const url = new URL(x);
    return url.protocol === "https:" && !!url.hostname && !url.username && !url.password &&
      !["localhost", "127.0.0.1"].includes(url.hostname);
  } catch {
    return false;
  }
}
function validInventory(inventory: AtlasInventory): boolean {
  return inventory.rightsStatus === "NOT_REVIEWED" &&
    /^[a-f0-9]{64}$/.test(inventory.sourceSHA256) &&
    Number.isSafeInteger(inventory.fileSizeBytes) && inventory.fileSizeBytes > 0 &&
    inventory.observedGeometry.sourceMeshCount === inventory.perMesh.length &&
    inventory.perMesh.length > 0 && inventory.perMesh.length <= 20_000 &&
    inventory.perMesh.every((p, i) => p.sourceIndex === i &&
      p.originalHierarchyPath.trim().length > 0 &&
      p.licenseEvidence === null && p.commercialReuseReviewed === false);
}

/** Start with the actual local geometry manifest, never guessed license data. */
export function makeRightsWorksheet(inventory: AtlasInventory): RightsWorksheet {
  if (!validInventory(inventory)) {
    throw new Error("No valid, unreviewed local source mesh inventory");
  }
  return {
    schemaVersion: 1, kind: "magicmirror.local-mesh-rights",
    sourceSHA256: inventory.sourceSHA256,
    sourceSizeBytes: inventory.fileSizeBytes,
    meshCount: inventory.perMesh.length,
    rightsStatus: "NOT_REVIEWED",
    commercialUseApproved: false,
    redistributionApproved: false,
    entries: inventory.perMesh.map(mesh => ({
      sourceIndex: mesh.sourceIndex,
      sourceMeshName: mesh.originalMeshName,
      sourceHierarchyPath: mesh.originalHierarchyPath,
      author: null, originalSourceURL: null,
      licenseId: "UNVERIFIED", licenseEvidenceURL: null,
      attribution: null, derivativeNotes: null,
      reviewStatus: "NOT_REVIEWED",
    })),
  };
}

/**
 * An input file may list a claimed license/evidence, but cannot assert that
 * any grant or release has been reviewed. Returns counts, NOT raw text.
 */
export function auditRightsWorksheet(value: unknown, inventory: AtlasInventory): RightsAudit {
  if (!validInventory(inventory)) throw new Error("Local source inventory is unavailable");
  const root = record(value, "Rights worksheet");
  exactKeys(root, [
    "schemaVersion", "kind", "sourceSHA256", "sourceSizeBytes", "meshCount",
    "rightsStatus", "commercialUseApproved", "redistributionApproved", "entries",
  ], "Rights worksheet");
  if (root.schemaVersion !== 1 || root.kind !== "magicmirror.local-mesh-rights" ||
      root.rightsStatus !== "NOT_REVIEWED" ||
      root.commercialUseApproved !== false || root.redistributionApproved !== false) {
    throw new Error("Rights worksheet cannot claim a reviewed publication status");
  }
  if (root.sourceSHA256 !== inventory.sourceSHA256 ||
      root.sourceSizeBytes !== inventory.fileSizeBytes ||
      root.meshCount !== inventory.perMesh.length ||
      !Array.isArray(root.entries) ||
      root.entries.length !== inventory.perMesh.length) {
    throw new Error("Rights worksheet belongs to a different local source file");
  }
  let nonCommercial = 0, shareAlike = 0, missingEvidence = 0;
  let unresolvedLicense = 0, readyForHumanReview = 0;
  for (let i = 0; i < inventory.perMesh.length; i++) {
    const row = record(root.entries[i], "Mesh evidence");
    exactKeys(row, [
      "sourceIndex", "sourceMeshName", "sourceHierarchyPath", "author",
      "originalSourceURL", "licenseId", "licenseEvidenceURL",
      "attribution", "derivativeNotes", "reviewStatus",
    ], "Mesh evidence");
    const mesh = inventory.perMesh[i];
    if (row.sourceIndex !== mesh.sourceIndex ||
        row.sourceMeshName !== mesh.originalMeshName ||
        row.sourceHierarchyPath !== mesh.originalHierarchyPath ||
        row.reviewStatus !== "NOT_REVIEWED" ||
        !LICENSES.includes(row.licenseId as LicenseClaim)) {
      throw new Error("Mesh identity or unreviewed rights status is invalid");
    }
    if (!optionalText(row.author, 240) ||
        !optionalHTTPS(row.originalSourceURL) ||
        !optionalHTTPS(row.licenseEvidenceURL) ||
        !optionalText(row.attribution, 1000) ||
        !optionalText(row.derivativeNotes, 1000)) {
      throw new Error("Mesh evidence has invalid attribution or insecure link");
    }
    const license = row.licenseId as LicenseClaim;
    const nc = license === "CC-BY-NC-4.0" || license === "CC-BY-NC-SA-4.0";
    const sa = license === "CC-BY-SA-4.0" ||
      license === "CC-BY-SA-2.1-JP" || license === "CC-BY-NC-SA-4.0";
    if (nc) nonCommercial++;
    if (sa) shareAlike++;
    const unresolved = license === "UNVERIFIED" ||
      license === "PROPRIETARY" || license === "OTHER";
    if (unresolved) unresolvedLicense++;
    const missing = !row.author || !row.originalSourceURL ||
      !row.licenseEvidenceURL || !row.attribution;
    if (missing) missingEvidence++;
    if (!missing && !unresolved && !nc) readyForHumanReview++;
  }
  return {
    count: root.entries.length, nonCommercial, shareAlike, missingEvidence,
    unresolvedLicense, readyForHumanReview, sourceLocked: true,
    status: "NOT_REVIEWED",
    redistributionApproved: false, commercialUseApproved: false,
    note: "HUMAN_PER_MESH_RIGHTS_REVIEW_REQUIRED",
  };
}
export function rightsWorksheetDownloadName(sourceName: string): string {
  return inventoryDownloadName(sourceName).replace(
    "-source-inventory.json", "-mesh-rights-worksheet.json",
  );
}
