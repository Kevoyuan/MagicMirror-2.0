import type { AtlasPart } from "./atlas-catalog";

/**
 * User-exported research inventory of a LOCAL model, NOT a rightsholder's
 * licensing declaration or an automatically completed provenance review.
 * The original geometry is never written into this output.
 */
export interface AtlasInventoryInput {
  readonly fileName: string;
  readonly fileSizeBytes: number;
  readonly sourceSHA256: string;
  readonly importedMeshes: number;
  readonly triangles: number;
  readonly skinnedMeshes: number;
  readonly authoredJoints: number;
  readonly rigSamples?: {
    readonly sampledVertices: number;
    readonly unweightedVertices: number;
    readonly invalidWeightSamples: number;
    readonly invalidJointReferences: number;
    readonly suspiciousWeightSums: number;
    readonly skinnedMeshesWithoutWeightAttributes: number;
    readonly previewableAnimationClips: number;
  };
  readonly parts: readonly AtlasPart[];
}
export interface AtlasInventory {
  readonly schemaVersion: 1;
  readonly product: "MagicMirror Web - local anatomy research";
  readonly fileName: string;
  readonly fileSizeBytes: number;
  readonly sourceSHA256: string;
  readonly observedGeometry: {
    readonly sourceMeshCount: number;
    readonly totalTriangles: number;
    readonly skinnedMeshCount: number;
    readonly authoredJointCount: number;
  };
  readonly rigSampleDiagnostics: {
    readonly samplingOnly: true;
    readonly sampledVertices: number;
    readonly unweightedVertices: number;
    readonly invalidWeightSamples: number;
    readonly invalidJointReferences: number;
    readonly suspiciousWeightSums: number;
    readonly skinnedMeshesWithoutWeightAttributes: number;
    readonly previewableAnimationClips: number;
  };
  readonly perMesh: ReadonlyArray<{
    readonly sourceIndex: number;
    readonly originalMeshName: string;
    readonly originalHierarchyPath: string;
    readonly triangles: number;
    readonly licenseEvidence: null;
    readonly commercialReuseReviewed: false;
  }>;
  readonly rightsStatus: "NOT_REVIEWED";
  readonly warning: string;
}

export function buildLocalAtlasInventory(input: AtlasInventoryInput): AtlasInventory {
  if (!/^[0-9a-f]{64}$/.test(input.sourceSHA256) ||
      !Number.isSafeInteger(input.fileSizeBytes) || input.fileSizeBytes < 1 ||
      input.parts.length !== input.importedMeshes ||
      input.parts.some((part, index) =>
        part.id !== index || part.path.trim().length === 0 ||
        !Number.isSafeInteger(part.triangles) || part.triangles < 0)) {
    throw new Error("Source model identity and local mesh inventory are inconsistent");
  }
  return {
    schemaVersion: 1,
    product: "MagicMirror Web - local anatomy research",
    fileName: input.fileName,
    fileSizeBytes: input.fileSizeBytes,
    sourceSHA256: input.sourceSHA256,
    observedGeometry: {
      sourceMeshCount: input.importedMeshes,
      totalTriangles: input.triangles,
      skinnedMeshCount: input.skinnedMeshes,
      authoredJointCount: input.authoredJoints,
    },
    rigSampleDiagnostics: {
      samplingOnly: true,
      sampledVertices: input.rigSamples?.sampledVertices ?? 0,
      unweightedVertices: input.rigSamples?.unweightedVertices ?? 0,
      invalidWeightSamples: input.rigSamples?.invalidWeightSamples ?? 0,
      invalidJointReferences: input.rigSamples?.invalidJointReferences ?? 0,
      suspiciousWeightSums: input.rigSamples?.suspiciousWeightSums ?? 0,
      skinnedMeshesWithoutWeightAttributes:
        input.rigSamples?.skinnedMeshesWithoutWeightAttributes ?? 0,
      previewableAnimationClips: input.rigSamples?.previewableAnimationClips ?? 0,
    },
    perMesh: input.parts.map(part => ({
      sourceIndex: part.id,
      originalMeshName: part.name,
      originalHierarchyPath: part.path,
      triangles: part.triangles,
      licenseEvidence: null,
      commercialReuseReviewed: false,
    })),
    rightsStatus: "NOT_REVIEWED",
    warning: "Automatically extracted geometry and sampled authored-weight metadata only. No author identities, per-mesh licenses, redistribution rights, complete skinning correctness, animation retargeting, bone mappings or physical pose registration have been verified. This document MUST NOT be presented as a rights or rig clearance.",
  };
}

/** Readable local filename only; never interpreted as an HTML or URL. */
export function inventoryDownloadName(originalFileName: string): string {
  const name = originalFileName
    .replace(/\.[^.]+$/, "")
    .normalize("NFKC")
    .replace(/[^a-zA-Z0-9_-]+/g, "_")
    .replace(/^[_-]+|[_-]+$/g, "")
    .slice(0, 55);
  return `MagicMirror-${name || "local_atlas"}-source-inventory.json`;
}
