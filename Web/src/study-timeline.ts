import type { AtlasInventory } from "./atlas-inventory";
import {
  orderStudyChain, type StudyChainNode,
} from "./kinematic-chain";
import { validRigidAngle, type SourceAxis } from "./rigid-preview";

export const MAX_STUDY_TIMELINE_MS = 10_000;
export const MAX_STUDY_KEYFRAMES = 32;

/** An authored angle in original SOURCE MODEL space, never a body frame. */
export interface StudyJointAngle {
  readonly sourceMeshId: number;
  readonly axis: SourceAxis;
  readonly degrees: number;
}
export interface StudyKeyframe {
  readonly timeMs: number;
  readonly joints: readonly StudyJointAngle[];
}
export interface StudyGraphIdentity {
  readonly sourceMeshId: number;
  readonly parentMeshId: number | null;
  readonly start: readonly [number, number, number];
  readonly end: readonly [number, number, number];
  readonly axis: SourceAxis;
}
export interface StudyTimelineDraft {
  readonly schemaVersion: 1;
  readonly kind: "magicmirror-local-virtual-chain-frames";
  readonly source: {
    readonly sha256: string;
    readonly fileSizeBytes: number;
    readonly sourceMeshCount: number;
  };
  readonly graph: readonly StudyGraphIdentity[];
  readonly frames: readonly StudyKeyframe[];
  readonly space: "ORIGINAL_MODEL_UNCALIBRATED";
  readonly motionType: "AUTHOR_SELECTED_TEST_ANGLES";
  readonly cameraRetargeting: false;
  readonly commercialReuseStatus: "NOT_REVIEWED";
  readonly warning: string;
}
function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("Invalid source-frame JSON");
  }
  return value as Record<string, unknown>;
}
function onlyKeys(data: Record<string, unknown>, keys: string[]): void {
  if (Object.keys(data).some(key => !keys.includes(key))) {
    throw new Error("Unexpected or forged frame authorization fields");
  }
}

export function studyGraphIdentity(
  nodes: readonly StudyChainNode[]
): StudyGraphIdentity[] {
  return orderStudyChain(nodes).map(node => ({
    sourceMeshId: node.sourceMeshId,
    parentMeshId: node.parentMeshId,
    start: [node.start[0], node.start[1], node.start[2]],
    end: [node.end[0], node.end[1], node.end[2]],
    axis: node.axis,
  }));
}

export function studyFrameAt(
  nodes: readonly StudyChainNode[], timeMs: number
): StudyKeyframe {
  if (!Number.isSafeInteger(timeMs) || timeMs < 0 ||
      timeMs > MAX_STUDY_TIMELINE_MS) {
    throw new Error("Study keyframe time must be within 0–10 seconds");
  }
  return {
    timeMs,
    joints: orderStudyChain(nodes).map(node => ({
      sourceMeshId: node.sourceMeshId,
      axis: node.axis,
      degrees: node.degrees,
    })),
  };
}

function validateStudyFrames(
  frames: readonly StudyKeyframe[], nodes: readonly StudyChainNode[]
): StudyKeyframe[] {
  if (!Array.isArray(frames) || frames.length < 1 ||
      frames.length > MAX_STUDY_KEYFRAMES) {
    throw new Error("Study timeline needs 1–32 explicitly captured frames");
  }
  const reference = orderStudyChain(nodes);
  let last = -1;
  const normalized: StudyKeyframe[] = [];
  for (const frame of frames) {
    const raw = asRecord(frame);
    onlyKeys(raw, ["timeMs", "joints"]);
    if (!Number.isSafeInteger(frame.timeMs) || frame.timeMs <= last ||
        frame.timeMs < 0 || frame.timeMs > MAX_STUDY_TIMELINE_MS ||
        !Array.isArray(frame.joints) ||
        frame.joints.length !== reference.length) {
      throw new Error("Timeline times must strictly ascend and every joint must be present");
    }
    const byId = new Map<number, StudyJointAngle>();
    for (const joint of frame.joints) {
      const entry = asRecord(joint);
      onlyKeys(entry, ["sourceMeshId", "axis", "degrees"]);
      if (!Number.isSafeInteger(joint.sourceMeshId) ||
          byId.has(joint.sourceMeshId) ||
          !validRigidAngle(joint.degrees)) {
        throw new Error("Keyframe contains duplicate, malformed or extreme node angles");
      }
      byId.set(joint.sourceMeshId, joint);
    }
    const joints = reference.map(node => {
      const point = byId.get(node.sourceMeshId);
      if (!point || point.axis !== node.axis) {
        throw new Error("Keyframe axes and source nodes must match the current authored graph");
      }
      return { sourceMeshId: node.sourceMeshId, axis: point.axis, degrees: point.degrees };
    });
    normalized.push({ timeMs: frame.timeMs, joints });
    last = frame.timeMs;
  }
  return normalized;
}

export function makeStudyTimelineDraft(
  source: AtlasInventory,
  nodes: readonly StudyChainNode[],
  frames: readonly StudyKeyframe[]
): StudyTimelineDraft {
  if (source.rightsStatus !== "NOT_REVIEWED" ||
      !/^[0-9a-f]{64}$/.test(source.sourceSHA256)) {
    throw new Error("A verified local source file identity is required");
  }
  const graph = studyGraphIdentity(nodes);
  if (graph.some(node => !source.perMesh[node.sourceMeshId])) {
    throw new Error("Timeline graph refers to a missing original source mesh");
  }
  return {
    schemaVersion: 1,
    kind: "magicmirror-local-virtual-chain-frames",
    source: {
      sha256: source.sourceSHA256,
      fileSizeBytes: source.fileSizeBytes,
      sourceMeshCount: source.observedGeometry.sourceMeshCount,
    },
    graph,
    frames: validateStudyFrames(frames, nodes),
    space: "ORIGINAL_MODEL_UNCALIBRATED",
    motionType: "AUTHOR_SELECTED_TEST_ANGLES",
    cameraRetargeting: false,
    commercialReuseStatus: "NOT_REVIEWED",
    warning: "This is an uncalibrated local source-model angle study only. No camera frames, original geometry, verified anatomy, authored bone weights, commercial rights or body tracking are encoded.",
  };
}

/** Strict fail-closed import: exact ORIGINAL source AND manually authored graph. */
export function parseStudyTimelineDraft(
  value: unknown, source: AtlasInventory,
  nodes: readonly StudyChainNode[]
): StudyKeyframe[] {
  const draft = asRecord(value);
  onlyKeys(draft, [
    "schemaVersion", "kind", "source", "graph", "frames", "space",
    "motionType", "cameraRetargeting", "commercialReuseStatus", "warning",
  ]);
  if (draft.schemaVersion !== 1 ||
      draft.kind !== "magicmirror-local-virtual-chain-frames" ||
      draft.space !== "ORIGINAL_MODEL_UNCALIBRATED" ||
      draft.motionType !== "AUTHOR_SELECTED_TEST_ANGLES" ||
      draft.cameraRetargeting !== false ||
      draft.commercialReuseStatus !== "NOT_REVIEWED" ||
      typeof draft.warning !== "string" || draft.warning.length < 40) {
    throw new Error("Timeline cannot assert camera/medical calibration or rights approval");
  }
  const original = asRecord(draft.source);
  onlyKeys(original, ["sha256", "fileSizeBytes", "sourceMeshCount"]);
  if (original.sha256 !== source.sourceSHA256 ||
      original.fileSizeBytes !== source.fileSizeBytes ||
      original.sourceMeshCount !== source.observedGeometry.sourceMeshCount) {
    throw new Error("Timeline ORIGINAL source SHA-256 or file identity mismatch");
  }
  const graph = studyGraphIdentity(nodes);
  if (!Array.isArray(draft.graph) || draft.graph.length !== graph.length) {
    throw new Error("Timeline graph no longer matches current source mapping/anchors");
  }
  for (const [index, expected] of graph.entries()) {
    const g = asRecord(draft.graph[index]);
    onlyKeys(g, ["sourceMeshId", "parentMeshId", "start", "end", "axis"]);
    if (JSON.stringify(g) !== JSON.stringify(expected)) {
      throw new Error("Timeline source node parent/anchor/axis mismatch");
    }
  }
  if (!Array.isArray(draft.frames)) {
    throw new Error("Missing source timeline frames");
  }
  return validateStudyFrames(draft.frames as StudyKeyframe[], nodes);
}

/** Deterministic bounded linear keyframe interpolation; never predicts bones. */
export function sampleStudyTimeline(
  frames: readonly StudyKeyframe[], atMs: number
): StudyJointAngle[] | null {
  if (!Number.isFinite(atMs) || frames.length === 0) return null;
  const leftBound = frames[0];
  const rightBound = frames[frames.length - 1];
  if (!leftBound || !rightBound) return null;
  if (atMs <= leftBound.timeMs) return leftBound.joints.map(j => ({...j}));
  if (atMs >= rightBound.timeMs) return rightBound.joints.map(j => ({...j}));
  let upper = 1;
  while (upper < frames.length && frames[upper].timeMs < atMs) upper++;
  const a = frames[upper - 1], b = frames[upper];
  if (!a || !b || b.timeMs <= a.timeMs ||
      a.joints.length !== b.joints.length) return null;
  const t = (atMs - a.timeMs) / (b.timeMs - a.timeMs);
  return a.joints.map((joint, index) => {
    const next = b.joints[index];
    if (!next || joint.axis !== next.axis ||
        joint.sourceMeshId !== next.sourceMeshId) {
      throw new Error("Study animation axes or nodes changed between keyframes");
    }
    return {
      sourceMeshId: joint.sourceMeshId, axis: joint.axis,
      degrees: joint.degrees + t * (next.degrees - joint.degrees),
    };
  });
}

export function timelineDownloadName(sourceName: string): string {
  const simple = sourceName.replace(/\.[^.]+$/, "").normalize("NFKC")
    .replace(/[^a-zA-Z0-9_-]+/g, "_")
    .replace(/^[_-]+|[_-]+$/g, "").slice(0, 50);
  return `MagicMirror-${simple || "local_atlas"}-virtual-frames.json`;
}
