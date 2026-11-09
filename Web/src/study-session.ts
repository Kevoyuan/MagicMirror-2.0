import type { AtlasInventory } from "./atlas-inventory";
import {
  makeDraftMapping, parseDraftMapping,
  type AtlasMappingDraft, type PoseSegmentId,
} from "./atlas-mapping";
import {
  makeAnchorDraft, parseAnchorDraft, sufficientAnchorDistance,
  validSourcePoint, type AtlasAnchorDraft, type PartAnchorPair,
  type SourcePoint3,
} from "./atlas-anchors";
import {
  countLargeStudyGaps, MAX_STUDY_CHAIN_MESHES, orderStudyChain,
  studyChainDeltas, type StudyChainNode,
} from "./kinematic-chain";
import { validRigidAngle, type SourceAxis } from "./rigid-preview";
import {
  makeStudyTimelineDraft, parseStudyTimelineDraft, sampleStudyTimeline,
  type StudyJointAngle, type StudyKeyframe, type StudyTimelineDraft,
} from "./study-timeline";

/**
 * W2l: ONE explicit, LOCAL-only study restore file. It bundles the four
 * separate user-authored drafts (W2d mapping, W2e anchor points, W2g virtual
 * source chain, W2i angle keyframes) so a reviewer can restore a whole
 * in-memory research state with one verified action.
 *
 * This is NOT a rig, anatomical atlas, calibrated camera frame, skinning
 * authoring tool, patient measurement, model redistribution license, or
 * MediaPipe body retargeting record. It contains no source geometry, no
 * webcam frames and no rights approval. All import checks are all-or-nothing:
 * a single mismatch leaves the live study state untouched.
 */
export const STUDY_SESSION_KIND = "magicmirror-local-study-session" as const;

export interface StudySessionSource {
  readonly sha256: string;
  readonly fileSizeBytes: number;
  readonly sourceMeshCount: number;
}
export interface StudySessionBundle {
  readonly schemaVersion: 1;
  readonly kind: "magicmirror-local-study-session";
  readonly source: StudySessionSource;
  readonly mapping: AtlasMappingDraft;
  readonly anchors: AtlasAnchorDraft;
  /** Empty when the reviewer has not authored a 2–12 source mesh chain yet. */
  readonly chain: readonly StudyChainNode[];
  /** null when no angle keyframes were captured; never a fabricated timeline. */
  readonly timeline: StudyTimelineDraft | null;
  readonly space: "ORIGINAL_MODEL_UNCALIBRATED";
  readonly retargetingStatus: "NOT_READY";
  readonly commercialReuseStatus: "NOT_REVIEWED";
  readonly cameraRetargeting: false;
  readonly warning: string;
}
export interface StudySessionState {
  readonly mappings: Map<number, PoseSegmentId>;
  readonly anchors: Map<number, PartAnchorPair>;
  readonly chain: StudyChainNode[];
  readonly frames: StudyKeyframe[];
}

const SESSION_WARNING =
  "One local, UNCALIBRATED original-model study state only. Contains no source mesh geometry, camera frames, verified anatomy, authored joint hierarchy, skin weights, body tracking, per-mesh license evidence or commercial/public distribution approval.";

function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Malformed local study session JSON");
  }
  return value as Record<string, unknown>;
}
function strictKeys(value: Record<string, unknown>, keys: readonly string[]): void {
  if (Object.keys(value).some(key => !keys.includes(key))) {
    throw new Error("Unexpected field or forged study session approval metadata");
  }
}
function sourceIdentity(inventory: AtlasInventory): StudySessionSource {
  return {
    sha256: inventory.sourceSHA256,
    fileSizeBytes: inventory.fileSizeBytes,
    sourceMeshCount: inventory.observedGeometry.sourceMeshCount,
  };
}
function checkInventory(inventory: AtlasInventory): void {
  if (inventory.rightsStatus !== "NOT_REVIEWED" ||
      !/^[0-9a-f]{64}$/.test(inventory.sourceSHA256) ||
      inventory.perMesh.length !== inventory.observedGeometry.sourceMeshCount) {
    throw new Error("Study session requires the original, unreviewed local source model");
  }
}
function samePoint(a: SourcePoint3, b: SourcePoint3): boolean {
  return a.length === 3 && b.length === 3 &&
    a[0] === b[0] && a[1] === b[1] && a[2] === b[2];
}

/**
 * A chain node's A/B points MUST be the exact validated W2e anchor points of
 * the SAME original mesh. Never let an imported chain silently carry a
 * different coordinate frame than the anchor draft it is restored with.
 */
function normalizeChain(
  value: unknown, inventory: AtlasInventory,
  mappings: ReadonlyMap<number, PoseSegmentId>,
  anchors: ReadonlyMap<number, PartAnchorPair>
): StudyChainNode[] {
  if (!Array.isArray(value) || value.length > MAX_STUDY_CHAIN_MESHES ||
      value.length === 1) {
    throw new Error("Study session chain needs 0 or 2–12 original source meshes");
  }
  if (value.length === 0) return [];
  const result: StudyChainNode[] = [];
  const seen = new Set<number>();
  for (const entry of value) {
    const node = asRecord(entry);
    strictKeys(node, [
      "sourceMeshId", "parentMeshId", "start", "end", "axis", "degrees",
    ]);
    const id = node.sourceMeshId;
    if (!Number.isSafeInteger(id) || (id as number) < 0 || seen.has(id as number) ||
        !inventory.perMesh[id as number] || !mappings.has(id as number)) {
      throw new Error("Unknown, duplicate or unmapped source mesh in study chain");
    }
    seen.add(id as number);
    const parent = node.parentMeshId;
    if (parent !== null &&
        (!Number.isSafeInteger(parent) || (parent as number) < 0 ||
          parent === id)) {
      throw new Error("Invalid manual parent reference in study chain");
    }
    const pair = anchors.get(id as number);
    if (!pair || !validSourcePoint(pair.start) || !validSourcePoint(pair.end) ||
        !sufficientAnchorDistance(pair.start, pair.end) ||
        !validSourcePoint(node.start) || !validSourcePoint(node.end) ||
        !samePoint(node.start as SourcePoint3, pair.start) ||
        !samePoint(node.end as SourcePoint3, pair.end)) {
      throw new Error("Study chain A/B points disagree with the validated anchor draft");
    }
    const axis = node.axis;
    if (axis !== "x" && axis !== "y" && axis !== "z") {
      throw new Error("Study chain source axis must be original-model X, Y or Z");
    }
    if (typeof node.degrees !== "number" ||
        !validRigidAngle(node.degrees as number)) {
      throw new Error("Study chain angle is malformed or exceeds ±90 degrees");
    }
    result.push({
      sourceMeshId: id as number,
      parentMeshId: parent as number | null,
      start: pair.start, end: pair.end,
      axis: axis as SourceAxis, degrees: node.degrees as number,
    });
  }
  // Rejects cycles, unselected parents, singular anchors and invalid angles.
  return orderStudyChain(result);
}

/** Explicit user-triggered download only. Nothing is persisted automatically. */
export function makeStudySession(
  inventory: AtlasInventory,
  mappings: ReadonlyMap<number, PoseSegmentId>,
  anchors: ReadonlyMap<number, PartAnchorPair>,
  chain: readonly StudyChainNode[],
  frames: readonly StudyKeyframe[]
): StudySessionBundle {
  checkInventory(inventory);
  const ordered = normalizeChain(chain, inventory, mappings, anchors);
  if (ordered.length === 0 && frames.length > 0) {
    throw new Error("Angle keyframes require a 2–12 authored source chain");
  }
  const timeline = frames.length
    ? makeStudyTimelineDraft(inventory, ordered, frames)
    : null;
  return {
    schemaVersion: 1,
    kind: STUDY_SESSION_KIND,
    source: sourceIdentity(inventory),
    mapping: makeDraftMapping(inventory, mappings),
    anchors: makeAnchorDraft(inventory, mappings, anchors),
    chain: ordered,
    timeline,
    space: "ORIGINAL_MODEL_UNCALIBRATED",
    retargetingStatus: "NOT_READY",
    commercialReuseStatus: "NOT_REVIEWED",
    cameraRetargeting: false,
    warning: SESSION_WARNING,
  };
}

/**
 * Strict all-or-nothing import. Existing W2d/W2e/W2i parsers are reused so
 * every original SHA, mesh name/path/triangle, segment, node and anti-forgery
 * gate still applies. Callers may replace live state ONLY after this returns.
 */
export function parseStudySession(
  value: unknown, inventory: AtlasInventory
): StudySessionState {
  checkInventory(inventory);
  const bundle = asRecord(value);
  strictKeys(bundle, [
    "schemaVersion", "kind", "source", "mapping", "anchors", "chain",
    "timeline", "space", "retargetingStatus", "commercialReuseStatus",
    "cameraRetargeting", "warning",
  ]);
  if (bundle.schemaVersion !== 1 || bundle.kind !== STUDY_SESSION_KIND ||
      bundle.space !== "ORIGINAL_MODEL_UNCALIBRATED" ||
      bundle.retargetingStatus !== "NOT_READY" ||
      bundle.commercialReuseStatus !== "NOT_REVIEWED" ||
      bundle.cameraRetargeting !== false ||
      typeof bundle.warning !== "string" || bundle.warning.length < 40) {
    throw new Error("Study session cannot assert calibration, medical or rights approval");
  }
  const source = asRecord(bundle.source);
  strictKeys(source, ["sha256", "fileSizeBytes", "sourceMeshCount"]);
  const expected = sourceIdentity(inventory);
  if (source.sha256 !== expected.sha256 ||
      source.fileSizeBytes !== expected.fileSizeBytes ||
      source.sourceMeshCount !== expected.sourceMeshCount) {
    throw new Error("Study session ORIGINAL source SHA-256, size or mesh count mismatch");
  }
  const mappings = parseDraftMapping(bundle.mapping, inventory);
  const anchors = parseAnchorDraft(bundle.anchors, inventory, mappings);
  const chain = normalizeChain(bundle.chain, inventory, mappings, anchors);
  if (chain.length === 0 && bundle.timeline !== null) {
    throw new Error("A study session without a source chain cannot contain keyframes");
  }
  const frames = bundle.timeline === null
    ? []
    : parseStudyTimelineDraft(bundle.timeline, inventory, chain);
  return { mappings, anchors, chain, frames };
}

type DeltaMap = ReturnType<typeof studyChainDeltas>;

function replayDeltas(
  ordered: readonly StudyChainNode[], joints: readonly StudyJointAngle[]
): DeltaMap {
  const byId = new Map(joints.map(joint => [joint.sourceMeshId, joint]));
  if (byId.size !== ordered.length) {
    throw new Error("Replay sample does not cover the authored source chain");
  }
  const atSample = ordered.map(node => {
    const joint = byId.get(node.sourceMeshId);
    if (!joint || joint.axis !== node.axis || !validRigidAngle(joint.degrees)) {
      throw new Error("Replay sample axes or angles are inconsistent");
    }
    return { ...node, degrees: joint.degrees };
  });
  return studyChainDeltas(atSample);
}

/** Max absolute element difference between two source-root delta batches. */
function matrixBatchDiff(a: DeltaMap, b: DeltaMap): number {
  if (a.size !== b.size) throw new Error("Replay source-chain batch size changed");
  let max = 0;
  for (const [id, matrix] of a) {
    const other = b.get(id);
    if (!other) throw new Error("Replay source-chain node disappeared");
    for (let index = 0; index < 16; index++) {
      const diff = Math.abs(matrix.elements[index] - other.elements[index]);
      if (!Number.isFinite(diff)) throw new Error("Non-finite replay matrix");
      if (diff > max) max = diff;
    }
  }
  return max;
}

export interface StudyReplayDiagnostics {
  readonly frameCount: number;
  readonly sampledPoints: number;
  readonly nodeCount: number;
  /** True only if repeated replays are bit-identical AND have no drift. */
  readonly deterministic: boolean;
  readonly maxReplayDrift: number;
  readonly maxAngleStepDegrees: number;
  readonly largeSourceGaps: number;
  readonly minAngleDegrees: number;
  readonly maxAngleDegrees: number;
  readonly scope: "SYNTHETIC_SOURCE_MATRIX_REPLAY_ONLY";
}

/**
 * Pure, bounded, camera-free matrix replay study. It compares independent
 * recomputations from the IMMUTABLE authored rest data at each keyframe and
 * at interpolation midpoints. Zero drift proves only that this synthetic
 * source-root transform is reproducible; it proves NOTHING about real
 * anatomy, camera registration, WebGL rendering or device performance.
 */
export function studyReplayDiagnostics(
  nodes: readonly StudyChainNode[], frames: readonly StudyKeyframe[]
): StudyReplayDiagnostics {
  const scope = "SYNTHETIC_SOURCE_MATRIX_REPLAY_ONLY" as const;
  if (nodes.length < 2 || frames.length === 0) {
    return {
      frameCount: frames.length, sampledPoints: 0, nodeCount: nodes.length,
      deterministic: false, maxReplayDrift: 0, maxAngleStepDegrees: 0,
      largeSourceGaps: nodes.length >= 2 ? countLargeStudyGaps(nodes) : 0,
      minAngleDegrees: 0, maxAngleDegrees: 0, scope,
    };
  }
  const ordered = orderStudyChain(nodes);
  const times: number[] = [];
  for (const [index, frame] of frames.entries()) {
    if (index > 0 && frame.timeMs <= frames[index - 1].timeMs) {
      throw new Error("Replay keyframe times must strictly ascend");
    }
    times.push(frame.timeMs);
    if (index > 0) times.push((frames[index - 1].timeMs + frame.timeMs) / 2);
  }
  let minAngle = Infinity, maxAngle = -Infinity, maxStep = 0;
  for (const [index, frame] of frames.entries()) {
    const previous = index > 0 ? frames[index - 1] : null;
    for (const joint of frame.joints) {
      if (!validRigidAngle(joint.degrees)) {
        throw new Error("Replay frame contains an extreme angle");
      }
      minAngle = Math.min(minAngle, joint.degrees);
      maxAngle = Math.max(maxAngle, joint.degrees);
      const before = previous?.joints.find(j => j.sourceMeshId === joint.sourceMeshId);
      if (before) maxStep = Math.max(maxStep, Math.abs(joint.degrees - before.degrees));
    }
  }
  let drift = 0;
  let firstBatch: DeltaMap | null = null;
  for (const time of times) {
    const joints = sampleStudyTimeline(frames, time);
    if (!joints) throw new Error("Replay sample could not be interpolated");
    const batch = replayDeltas(ordered, joints);
    drift = Math.max(drift, matrixBatchDiff(batch, replayDeltas(ordered, joints)));
    firstBatch ??= batch;
  }
  // Restart the whole sequence and compare frame 0: transforms must come from
  // immutable rest data, never compound on the previously displayed pose.
  const restartJoints = sampleStudyTimeline(frames, frames[0].timeMs);
  if (!restartJoints || !firstBatch) throw new Error("Empty replay sequence");
  drift = Math.max(drift,
    matrixBatchDiff(firstBatch, replayDeltas(ordered, restartJoints)));
  return {
    frameCount: frames.length, sampledPoints: times.length,
    nodeCount: ordered.length, deterministic: drift === 0,
    maxReplayDrift: drift, maxAngleStepDegrees: maxStep,
    largeSourceGaps: countLargeStudyGaps(ordered),
    minAngleDegrees: Number.isFinite(minAngle) ? minAngle : 0,
    maxAngleDegrees: Number.isFinite(maxAngle) ? maxAngle : 0,
    scope,
  };
}

/** Local download filename only; never interpreted as HTML, URL or a path. */
export function studySessionDownloadName(sourceName: string): string {
  const simple = sourceName.replace(/\.[^.]+$/, "").normalize("NFKC")
    .replace(/[^a-zA-Z0-9_-]+/g, "_")
    .replace(/^[_-]+|[_-]+$/g, "").slice(0, 50);
  return `MagicMirror-${simple || "local_atlas"}-study-session.json`;
}
