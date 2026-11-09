import type { AtlasInventory } from "./atlas-inventory";
import { isPoseSegmentId, type PoseSegmentId } from "./atlas-mapping";

/** Clicked 3D points in imported original-root coordinate space, NOT patient anatomy. */
export type SourcePoint3 = readonly [number, number, number];
export interface PartAnchorPair {
  readonly start: SourcePoint3 | null;
  readonly end: SourcePoint3 | null;
}
export type AnchorEndpoint = "start" | "end";
export type AnchorPairMap = ReadonlyMap<number, PartAnchorPair>;
export interface SourceMeshAnchorDraft {
  readonly sourceMeshId: number;
  readonly originalMeshName: string;
  readonly originalHierarchyPath: string;
  readonly originalTriangles: number;
  readonly poseSegment: PoseSegmentId;
  readonly start: SourcePoint3 | null;
  readonly end: SourcePoint3 | null;
  readonly reviewStatus: "USER_SELECTED_UNCALIBRATED";
}
export interface AtlasAnchorDraft {
  readonly schemaVersion: 1;
  readonly kind: "magicmirror-source-anchor-draft";
  readonly source: {
    readonly sha256: string;
    readonly fileSizeBytes: number;
    readonly sourceMeshCount: number;
  };
  readonly sourceCoordinateFrame: "ORIGINAL_ROOT_LOCAL_UNVERIFIED";
  readonly calibrationStatus: "MANUAL_POINTS_NOT_CALIBRATED";
  readonly retargetingStatus: "NOT_READY";
  readonly commercialReuseStatus: "NOT_REVIEWED";
  readonly anchors: readonly SourceMeshAnchorDraft[];
  readonly warning: string;
}

export function validSourcePoint(value: unknown): value is SourcePoint3 {
  return Array.isArray(value) && value.length === 3 &&
    value.every((part) => typeof part === "number" &&
      Number.isFinite(part) && Math.abs(part) <= 1e9);
}
export function sufficientAnchorDistance(
  start: SourcePoint3 | null, end: SourcePoint3 | null
): boolean {
  if (!start || !end) return false;
  const distance = Math.hypot(
    start[0] - end[0], start[1] - end[1], start[2] - end[2]
  );
  return Number.isFinite(distance) && distance > 1e-7;
}
export function completeAnchorPairCount(anchors: AnchorPairMap): number {
  let count = 0;
  for (const part of anchors.values()) {
    if (sufficientAnchorDistance(part.start, part.end)) count++;
  }
  return count;
}

export function makeAnchorDraft(
  inventory: AtlasInventory,
  assignments: ReadonlyMap<number, PoseSegmentId>,
  userPoints: AnchorPairMap
): AtlasAnchorDraft {
  if (inventory.rightsStatus !== "NOT_REVIEWED" ||
      inventory.observedGeometry.sourceMeshCount !== inventory.perMesh.length ||
      userPoints.size > inventory.perMesh.length) {
    throw new Error("Original source mesh inventory and rights state are invalid");
  }
  const anchors: SourceMeshAnchorDraft[] = [];
  for (const [id, points] of userPoints) {
    const mesh = inventory.perMesh[id];
    const poseSegment = assignments.get(id);
    if (!Number.isSafeInteger(id) || !mesh || mesh.sourceIndex !== id ||
        !isPoseSegmentId(poseSegment) ||
        !validOptionalPoint(points.start) || !validOptionalPoint(points.end)) {
      throw new Error("Anchor is not attached to a mapped original source mesh");
    }
    if (points.start && points.end && !sufficientAnchorDistance(points.start, points.end)) {
      throw new Error("Two manually selected endpoints must be distinct");
    }
    anchors.push({
      sourceMeshId: id,
      originalMeshName: mesh.originalMeshName,
      originalHierarchyPath: mesh.originalHierarchyPath,
      originalTriangles: mesh.triangles,
      poseSegment,
      start: points.start,
      end: points.end,
      reviewStatus: "USER_SELECTED_UNCALIBRATED",
    });
  }
  anchors.sort((a, b) => a.sourceMeshId - b.sourceMeshId);
  return {
    schemaVersion: 1,
    kind: "magicmirror-source-anchor-draft",
    source: {
      sha256: inventory.sourceSHA256,
      fileSizeBytes: inventory.fileSizeBytes,
      sourceMeshCount: inventory.observedGeometry.sourceMeshCount,
    },
    sourceCoordinateFrame: "ORIGINAL_ROOT_LOCAL_UNVERIFIED",
    calibrationStatus: "MANUAL_POINTS_NOT_CALIBRATED",
    retargetingStatus: "NOT_READY",
    commercialReuseStatus: "NOT_REVIEWED",
    anchors,
    warning: "Manually clicked source-root 3D start/end points of user-selected local meshes only. Not a rest-pose verification, validated bone joint, fitted camera, authored skin rig, 3D pose retarget, medical data or legal rights grant.",
  };
}
function validOptionalPoint(point: unknown): point is SourcePoint3 | null {
  return point === null || validSourcePoint(point);
}
function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Malformed source anchor JSON");
  }
  return value as Record<string, unknown>;
}
function strictKeys(value: Record<string, unknown>, keys: readonly string[]): void {
  if (Object.keys(value).some(key => !keys.includes(key))) {
    throw new Error("Unexpected field or forged source anchor approval metadata");
  }
}

/** Independent source + mapping integrity check, all-or-nothing import. */
export function parseAnchorDraft(
  data: unknown,
  inventory: AtlasInventory,
  assignments: ReadonlyMap<number, PoseSegmentId>
): Map<number, PartAnchorPair> {
  const draft = asRecord(data);
  strictKeys(draft, [
    "schemaVersion", "kind", "source", "sourceCoordinateFrame",
    "calibrationStatus", "retargetingStatus", "commercialReuseStatus",
    "anchors", "warning",
  ]);
  if (draft.schemaVersion !== 1 || draft.kind !== "magicmirror-source-anchor-draft" ||
      draft.sourceCoordinateFrame !== "ORIGINAL_ROOT_LOCAL_UNVERIFIED" ||
      draft.calibrationStatus !== "MANUAL_POINTS_NOT_CALIBRATED" ||
      draft.retargetingStatus !== "NOT_READY" ||
      draft.commercialReuseStatus !== "NOT_REVIEWED" ||
      typeof draft.warning !== "string" || draft.warning.length < 30) {
    throw new Error("Anchor draft cannot claim a calibrated or rights-reviewed rig");
  }
  const source = asRecord(draft.source);
  strictKeys(source, ["sha256", "fileSizeBytes", "sourceMeshCount"]);
  if (source.sha256 !== inventory.sourceSHA256 ||
      source.fileSizeBytes !== inventory.fileSizeBytes ||
      source.sourceMeshCount !== inventory.observedGeometry.sourceMeshCount) {
    throw new Error("Original source SHA-256/size/mesh count mismatch");
  }
  if (!Array.isArray(draft.anchors) ||
      draft.anchors.length > inventory.perMesh.length ||
      draft.anchors.length > 5000) {
    throw new Error("Excessive or invalid source model anchor count");
  }
  const clean = new Map<number, PartAnchorPair>();
  for (const entry of draft.anchors) {
    const candidate = asRecord(entry);
    strictKeys(candidate, [
      "sourceMeshId", "originalMeshName", "originalHierarchyPath",
      "originalTriangles", "poseSegment", "start", "end", "reviewStatus",
    ]);
    const id = candidate.sourceMeshId;
    const mesh = typeof id === "number" && Number.isSafeInteger(id)
      ? inventory.perMesh[id] : undefined;
    const segment = assignments.get(id as number);
    if (!mesh || mesh.sourceIndex !== id ||
        candidate.originalMeshName !== mesh.originalMeshName ||
        candidate.originalHierarchyPath !== mesh.originalHierarchyPath ||
        candidate.originalTriangles !== mesh.triangles ||
        candidate.poseSegment !== segment || !isPoseSegmentId(segment) ||
        candidate.reviewStatus !== "USER_SELECTED_UNCALIBRATED" ||
        !validOptionalPoint(candidate.start) || !validOptionalPoint(candidate.end) ||
        clean.has(id as number)) {
      throw new Error("Unknown, altered, duplicated or unmapped original mesh anchor");
    }
    if (candidate.start && candidate.end &&
        !sufficientAnchorDistance(candidate.start as SourcePoint3,
          candidate.end as SourcePoint3)) {
      throw new Error("Anchor endpoints overlap or have invalid distance");
    }
    clean.set(id as number, {
      start: candidate.start as SourcePoint3 | null,
      end: candidate.end as SourcePoint3 | null,
    });
  }
  return clean;
}
