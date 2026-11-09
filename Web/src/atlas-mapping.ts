import type { AtlasInventory } from "./atlas-inventory";

/**
 * A deliberately coarse MEDIA PIPE SURFACE SEGMENT taxonomy.
 * These labels are human-entered study hypotheses; do not interpret
 * the mapping as a validated bone taxonomy, rig, or body-to-camera fit.
 */
export const POSE_SEGMENTS = [
  { id: "left-upper-arm", zh: "左上臂参考", en: "Left upper arm", from: 11, to: 13 },
  { id: "left-forearm", zh: "左前臂参考", en: "Left forearm", from: 13, to: 15 },
  { id: "right-upper-arm", zh: "右上臂参考", en: "Right upper arm", from: 12, to: 14 },
  { id: "right-forearm", zh: "右前臂参考", en: "Right forearm", from: 14, to: 16 },
  { id: "left-thigh", zh: "左大腿参考", en: "Left thigh", from: 23, to: 25 },
  { id: "left-shin", zh: "左小腿参考", en: "Left shin", from: 25, to: 27 },
  { id: "right-thigh", zh: "右大腿参考", en: "Right thigh", from: 24, to: 26 },
  { id: "right-shin", zh: "右小腿参考", en: "Right shin", from: 26, to: 28 },
  { id: "shoulder-span", zh: "双肩参考", en: "Shoulder span", from: 11, to: 12 },
  { id: "left-torso", zh: "左侧躯干参考", en: "Left torso", from: 11, to: 23 },
  { id: "right-torso", zh: "右侧躯干参考", en: "Right torso", from: 12, to: 24 },
  { id: "hip-span", zh: "双髋参考", en: "Hip span", from: 23, to: 24 },
] as const;
export type PoseSegmentId = (typeof POSE_SEGMENTS)[number]["id"];
const allowed = new Set<string>(POSE_SEGMENTS.map((segment) => segment.id));
export function isPoseSegmentId(value: unknown): value is PoseSegmentId {
  return typeof value === "string" && allowed.has(value);
}

export interface DraftMeshAssignment {
  readonly sourceMeshId: number;
  readonly originalMeshName: string;
  readonly originalHierarchyPath: string;
  readonly originalTriangles: number;
  readonly poseSegment: PoseSegmentId;
  readonly reviewStatus: "USER_DRAFT_UNCALIBRATED";
}
export interface AtlasMappingDraft {
  readonly schemaVersion: 1;
  readonly kind: "magicmirror-local-pose-mesh-map";
  readonly source: {
    readonly sha256: string;
    readonly fileSizeBytes: number;
    readonly sourceMeshCount: number;
  };
  readonly sourceCoordinateFrame: "UNVERIFIED";
  readonly retargetingStatus: "NOT_READY";
  readonly commercialReuseStatus: "NOT_REVIEWED";
  readonly mappingStatus: "USER_DRAFT_ONLY";
  readonly assignments: readonly DraftMeshAssignment[];
  readonly warning: string;
}

export function makeDraftMapping(
  inventory: AtlasInventory,
  assignments: ReadonlyMap<number, PoseSegmentId>
): AtlasMappingDraft {
  if (inventory.rightsStatus !== "NOT_REVIEWED" ||
      inventory.perMesh.length !== inventory.observedGeometry.sourceMeshCount) {
    throw new Error("Source inventory is not an original, unreviewed mesh inventory");
  }
  if (assignments.size > inventory.perMesh.length) {
    throw new Error("More assignments than source meshes");
  }
  const result: DraftMeshAssignment[] = [];
  for (const [id, poseSegment] of assignments) {
    const part = inventory.perMesh[id];
    if (!Number.isSafeInteger(id) || !part || part.sourceIndex !== id ||
        !isPoseSegmentId(poseSegment)) {
      throw new Error("Draft mapping refers to a nonexistent part or invalid pose segment");
    }
    result.push({
      sourceMeshId: id,
      originalMeshName: part.originalMeshName,
      originalHierarchyPath: part.originalHierarchyPath,
      originalTriangles: part.triangles,
      poseSegment,
      reviewStatus: "USER_DRAFT_UNCALIBRATED",
    });
  }
  result.sort((a, b) => a.sourceMeshId - b.sourceMeshId);
  return {
    schemaVersion: 1,
    kind: "magicmirror-local-pose-mesh-map",
    source: {
      sha256: inventory.sourceSHA256,
      fileSizeBytes: inventory.fileSizeBytes,
      sourceMeshCount: inventory.observedGeometry.sourceMeshCount,
    },
    sourceCoordinateFrame: "UNVERIFIED",
    retargetingStatus: "NOT_READY",
    commercialReuseStatus: "NOT_REVIEWED",
    mappingStatus: "USER_DRAFT_ONLY",
    assignments: result,
    warning: "Manually assigned source mesh to a 2D MediaPipe surface segment. No geometry, skin weights, authored rig, camera registration, anatomy accuracy, per-mesh license, public distribution or commercial reuse approval is implied.",
  };
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("Invalid mapping JSON structure");
  }
  return value as Record<string, unknown>;
}
function onlyKeys(input: Record<string, unknown>, allowedKeys: string[]): void {
  if (Object.keys(input).some((key) => !allowedKeys.includes(key))) {
    throw new Error("Unexpected or potentially misleading metadata in mapping JSON");
  }
}

/**
 * Import is intentionally strict and tied to the ORIGINAL selected model
 * identity, not a filename. Validated draft state is returned only as a Map.
 * Supplied JSON cannot assert a license grant, bone calibration or
 * retargeting approval.
 */
export function parseDraftMapping(
  value: unknown, inventory: AtlasInventory
): Map<number, PoseSegmentId> {
  const payload = record(value);
  onlyKeys(payload, [
    "schemaVersion", "kind", "source", "sourceCoordinateFrame",
    "retargetingStatus", "commercialReuseStatus", "mappingStatus",
    "assignments", "warning",
  ]);
  if (payload.schemaVersion !== 1 ||
      payload.kind !== "magicmirror-local-pose-mesh-map" ||
      payload.sourceCoordinateFrame !== "UNVERIFIED" ||
      payload.retargetingStatus !== "NOT_READY" ||
      payload.commercialReuseStatus !== "NOT_REVIEWED" ||
      payload.mappingStatus !== "USER_DRAFT_ONLY" ||
      typeof payload.warning !== "string" || payload.warning.length < 30) {
    throw new Error("Mapping file is not a valid uncalibrated local draft");
  }
  const source = record(payload.source);
  onlyKeys(source, ["sha256", "fileSizeBytes", "sourceMeshCount"]);
  if (source.sha256 !== inventory.sourceSHA256 ||
      source.fileSizeBytes !== inventory.fileSizeBytes ||
      source.sourceMeshCount !== inventory.observedGeometry.sourceMeshCount) {
    throw new Error("Mapping source SHA-256, file size or mesh count does not match the loaded original model");
  }
  if (!Array.isArray(payload.assignments) ||
      payload.assignments.length > inventory.perMesh.length ||
      payload.assignments.length > 5000) {
    throw new Error("Invalid or excessive mesh mapping entries");
  }
  const validated = new Map<number, PoseSegmentId>();
  for (const entry of payload.assignments) {
    const assignment = record(entry);
    onlyKeys(assignment, [
      "sourceMeshId", "originalMeshName", "originalHierarchyPath",
      "originalTriangles", "poseSegment", "reviewStatus",
    ]);
    const id = assignment.sourceMeshId;
    const original = typeof id === "number" && Number.isSafeInteger(id)
      ? inventory.perMesh[id] : undefined;
    if (!original || original.sourceIndex !== id ||
        original.originalMeshName !== assignment.originalMeshName ||
        original.originalHierarchyPath !== assignment.originalHierarchyPath ||
        original.triangles !== assignment.originalTriangles ||
        !isPoseSegmentId(assignment.poseSegment) ||
        assignment.reviewStatus !== "USER_DRAFT_UNCALIBRATED" ||
        validated.has(id)) {
      throw new Error("Duplicate, altered or unsupported original mesh mapping");
    }
    validated.set(id, assignment.poseSegment);
  }
  return validated;
}
