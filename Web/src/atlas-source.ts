/** A LOCAL file is preview-only; never a distribution-rights or medical approval. */
export interface LocalAtlasFileMeta { name: string; size: number }
export type LocalAtlasFormat = "fbx" | "glb";
export const MAX_LOCAL_ATLAS_BYTES = 75 * 1024 * 1024;

export function inspectLocalAtlasFile(file: LocalAtlasFileMeta): LocalAtlasFormat {
  if (!Number.isSafeInteger(file.size) || file.size <= 0 ||
      file.size > MAX_LOCAL_ATLAS_BYTES) {
    throw new Error("The local model must be 1–75 MB. Large anatomy models can exhaust browser GPU memory.");
  }
  const extension = file.name.split(".").pop()?.toLowerCase();
  if (extension !== "fbx" && extension !== "glb") {
    throw new Error("Only local .fbx or self-contained .glb files are supported. No external downloads or uploads.");
  }
  return extension;
}

/** Default anatomical labels assume model axes only, not validated anatomical coordinate frames. */
export type SliceOrientation = "none" | "axial-y" | "sagittal-x" | "coronal-z";
export function sliceNormal(orientation: SliceOrientation): [number, number, number] | null {
  switch (orientation) {
    case "none": return null;
    case "axial-y": return [0, 1, 0];
    case "sagittal-x": return [1, 0, 0];
    case "coronal-z": return [0, 0, 1];
  }
}

export function normalizeSlice(percentage: number): number {
  if (!Number.isFinite(percentage)) return 0;
  return Math.max(-1, Math.min(1, (percentage - 50) / 50));
}
