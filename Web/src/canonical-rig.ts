/**
 * W2n1: author-defined ORIGINAL humanoid reference joint topology.
 *
 * This is a skeletal COMPUTING TEST RIG, not an anatomical atlas, bone
 * measurements, calibrated camera pose, or externally licensed mesh.
 * +X = the figure's own LEFT; +Y = up; +Z = forwards in fixture space.
 * These axes must NOT be assumed for an arbitrary imported FBX/GLB.
 */
export const CANONICAL_RIG_REST = [
  { id: "pelvis", parent: null, position: [0, 0, 0] },
  { id: "spine", parent: "pelvis", position: [0, 0.30, 0] },
  { id: "chest", parent: "spine", position: [0, 0.62, 0] },
  { id: "neck", parent: "chest", position: [0, 0.86, 0] },
  { id: "head", parent: "neck", position: [0, 1.11, 0] },
  { id: "left_shoulder", parent: "chest", position: [0.26, 0.76, 0] },
  { id: "left_elbow", parent: "left_shoulder", position: [0.55, 0.52, 0] },
  { id: "left_wrist", parent: "left_elbow", position: [0.79, 0.31, 0] },
  { id: "right_shoulder", parent: "chest", position: [-0.26, 0.76, 0] },
  { id: "right_elbow", parent: "right_shoulder", position: [-0.55, 0.52, 0] },
  { id: "right_wrist", parent: "right_elbow", position: [-0.79, 0.31, 0] },
  { id: "left_hip", parent: "pelvis", position: [0.17, -0.15, 0] },
  { id: "left_knee", parent: "left_hip", position: [0.19, -0.64, 0.02] },
  { id: "left_ankle", parent: "left_knee", position: [0.20, -1.11, 0.06] },
  { id: "left_foot", parent: "left_ankle", position: [0.20, -1.17, 0.25] },
  { id: "right_hip", parent: "pelvis", position: [-0.17, -0.15, 0] },
  { id: "right_knee", parent: "right_hip", position: [-0.19, -0.64, 0.02] },
  { id: "right_ankle", parent: "right_knee", position: [-0.20, -1.11, 0.06] },
  { id: "right_foot", parent: "right_ankle", position: [-0.20, -1.17, 0.25] },
] as const;

export type CanonicalRigJointId = (typeof CANONICAL_RIG_REST)[number]["id"];

export interface CanonicalRigJoint {
  readonly id: CanonicalRigJointId;
  readonly parent: CanonicalRigJointId | null;
  readonly position: readonly [number, number, number];
}

export interface CanonicalRigAudit {
  readonly status: "plausible-original-fixture" | "invalid";
  readonly count: number;
  readonly failures: readonly string[];
  readonly units: "authored-fictional-units";
  readonly anatomicalVerificationApproved: false;
  readonly cameraRegistrationApproved: false;
  readonly retargetingApproved: false;
  readonly publicationRightsApproved: false;
}

const expected = new Map<string, CanonicalRigJoint>(
  CANONICAL_RIG_REST.map(j => [j.id, j as CanonicalRigJoint]),
);

function finite3(value: unknown): value is readonly [number, number, number] {
  return Array.isArray(value) && value.length === 3 &&
    value.every(v => typeof v === "number" &&
      Number.isFinite(v) && Math.abs(v) <= 10);
}

export function auditCanonicalRigRest(
  input: readonly CanonicalRigJoint[],
): CanonicalRigAudit {
  const errors: string[] = [];
  if (!Array.isArray(input) ||
      input.length !== CANONICAL_RIG_REST.length) {
    errors.push("canonical-joint-count");
  }
  const seen = new Set<string>();
  const positions = new Map<string, readonly [number, number, number]>();
  for (const entry of Array.isArray(input) ? input : []) {
    if (!entry || typeof entry !== "object" ||
        typeof entry.id !== "string" || !expected.has(entry.id) ||
        seen.has(entry.id)) {
      errors.push("unknown-or-duplicate-joint");
      continue;
    }
    seen.add(entry.id);
    const fixture = expected.get(entry.id)!;
    if (fixture.parent !== entry.parent) errors.push("wrong-parent");
    if (!finite3(entry.position)) errors.push("invalid-rest-coordinate");
    else positions.set(entry.id, entry.position);
  }
  for (const joint of CANONICAL_RIG_REST) {
    const pos = positions.get(joint.id);
    if (!seen.has(joint.id)) errors.push("missing-joint");
    if (!pos) continue;
    if (joint.parent === null) {
      if (Math.hypot(...pos) > 0.001) errors.push("root-must-be-origin");
    } else {
      const parent = positions.get(joint.parent);
      if (!parent) {
        errors.push("missing-parent-position");
      } else {
        const len = Math.hypot(
          pos[0] - parent[0], pos[1] - parent[1], pos[2] - parent[2],
        );
        if (len < 0.04 || len > 1.5) errors.push("invalid-bone-length");
      }
    }
    if (joint.id.startsWith("left_") && pos[0] <= 0.01) {
      errors.push("invalid-left-side-axis");
    }
    if (joint.id.startsWith("right_") && pos[0] >= -0.01) {
      errors.push("invalid-right-side-axis");
    }
  }
  const pelvis = positions.get("pelvis"), chest = positions.get("chest");
  const head = positions.get("head"), leftKnee = positions.get("left_knee");
  const rightKnee = positions.get("right_knee");
  if (pelvis && chest && head && !(pelvis[1] < chest[1] && chest[1] < head[1])) {
    errors.push("invalid-head-torso-order");
  }
  if (pelvis && leftKnee && rightKnee &&
      !(leftKnee[1] < pelvis[1] && rightKnee[1] < pelvis[1])) {
    errors.push("invalid-leg-direction");
  }
  return {
    status: errors.length ? "invalid" : "plausible-original-fixture",
    count: seen.size,
    failures: [...new Set(errors)],
    units: "authored-fictional-units",
    anatomicalVerificationApproved: false,
    cameraRegistrationApproved: false,
    retargetingApproved: false,
    publicationRightsApproved: false,
  };
}

export interface RigWeightObservation {
  readonly vertexIndex: number;
  readonly influences: readonly {
    readonly joint: CanonicalRigJointId;
    readonly weight: number;
  }[];
}
export interface RigWeightAudit {
  readonly inspected: number;
  readonly badIndices: number;
  readonly unweighted: number;
  readonly badNormalization: number;
  readonly badJointReferences: number;
  readonly tooManyInfluences: number;
  readonly onlySampled: true;
  readonly actualMeshSkinningVerified: false;
  readonly anatomyRigApproved: false;
}

/**
 * Reports authored SAMPLE data, not full-mesh coverage or mesh weights.
 * Real imported SkinnedMesh data must be independently inspected.
 */
export function auditProposedWeightSamples(
  vertexCount: number, observations: readonly RigWeightObservation[],
): RigWeightAudit {
  if (!Number.isSafeInteger(vertexCount) || vertexCount < 1 ||
      vertexCount > 10_000_000 || !Array.isArray(observations) ||
      observations.length < 1 || observations.length > 2048) {
    throw new Error("Invalid proposed weight inspection dimensions");
  }
  const visited = new Set<number>();
  let badIndices = 0, unweighted = 0, badNormalization = 0;
  let badJointReferences = 0, tooManyInfluences = 0;
  for (const row of observations) {
    if (!row || !Number.isSafeInteger(row.vertexIndex) ||
        row.vertexIndex < 0 || row.vertexIndex >= vertexCount ||
        visited.has(row.vertexIndex)) {
      badIndices++;
    } else visited.add(row.vertexIndex);
    if (!Array.isArray(row.influences) || row.influences.length > 4) {
      tooManyInfluences++;
      continue;
    }
    if (row.influences.length === 0) {
      unweighted++;
      continue;
    }
    const joints = new Set<string>();
    let sum = 0, invalidWeight = false;
    for (const influence of row.influences) {
      if (!influence || !expected.has(influence.joint) ||
          joints.has(influence.joint)) {
        badJointReferences++;
      }
      if (influence) joints.add(influence.joint);
      if (!influence || !Number.isFinite(influence.weight) ||
          influence.weight < 0 || influence.weight > 1) {
        invalidWeight = true;
      } else sum += influence.weight;
    }
    if (invalidWeight || Math.abs(sum - 1) > 0.02) badNormalization++;
  }
  return {
    inspected: observations.length, badIndices, unweighted,
    badNormalization, badJointReferences, tooManyInfluences,
    onlySampled: true, actualMeshSkinningVerified: false,
    anatomyRigApproved: false,
  };
}
