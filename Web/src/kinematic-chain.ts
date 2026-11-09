import { Matrix4, Vector3 } from "three";
import {
  sourceRootRigidDelta, validRigidAngle, validRigidSource,
  type SourceAxis,
} from "./rigid-preview";
import type { SourcePoint3 } from "./atlas-anchors";

/**
 * W2g local-only VIRTUAL chain authoring for a bounded set of user-specified
 * source meshes. This is NOT a real skeletal hierarchy, anatomy classification,
 * inverse kinematics, skinning or MediaPipe retargeting.
 */
export interface StudyChainNode {
  readonly sourceMeshId: number;
  readonly parentMeshId: number | null;
  readonly start: SourcePoint3;
  readonly end: SourcePoint3;
  readonly axis: SourceAxis;
  readonly degrees: number;
}
export const MAX_STUDY_CHAIN_MESHES = 12;

export function orderStudyChain(nodes: readonly StudyChainNode[]): StudyChainNode[] {
  if (nodes.length < 2 || nodes.length > MAX_STUDY_CHAIN_MESHES) {
    throw new Error("Study chain needs 2–12 explicitly selected source meshes");
  }
  const byId = new Map<number, StudyChainNode>();
  for (const node of nodes) {
    if (!Number.isSafeInteger(node.sourceMeshId) || node.sourceMeshId < 0 ||
        byId.has(node.sourceMeshId) ||
        (node.parentMeshId !== null &&
          (!Number.isSafeInteger(node.parentMeshId) || node.parentMeshId < 0)) ||
        !validRigidSource(node.start, node.end) ||
        !validRigidAngle(node.degrees) ||
        !sourceRootRigidDelta(node.start, node.end, node.axis, node.degrees)) {
      throw new Error("Study chain contains duplicate, malformed or unanchored source nodes");
    }
    byId.set(node.sourceMeshId, node);
  }
  const ordered: StudyChainNode[] = [];
  const visiting = new Set<number>();
  const visited = new Set<number>();
  function visit(id: number): void {
    if (visiting.has(id)) throw new Error("Study chain parent cycle detected");
    if (visited.has(id)) return;
    const node = byId.get(id);
    if (!node) throw new Error("Study chain parent refers to an unselected source mesh");
    visiting.add(id);
    if (node.parentMeshId !== null) {
      if (node.parentMeshId === id) throw new Error("Mesh cannot parent itself");
      visit(node.parentMeshId);
    }
    visiting.delete(id);
    visited.add(id);
    ordered.push(node);
  }
  for (const node of nodes) visit(node.sourceMeshId);
  return ordered;
}

/**
 * Each local pivot transform is in the ORIGINAL imported source-root frame.
 * Descendant delta is parentDelta * localDelta; the child's start is carried
 * with the parent before its own rotation, using the same immutable rest data.
 */
export function studyChainDeltas(
  nodes: readonly StudyChainNode[]
): Map<number, Matrix4> {
  const ordered = orderStudyChain(nodes);
  const world = new Map<number, Matrix4>();
  for (const node of ordered) {
    const local = sourceRootRigidDelta(
      node.start, node.end, node.axis, node.degrees
    );
    if (!local) throw new Error("Invalid model-space source transform");
    const parent = node.parentMeshId === null
      ? new Matrix4()
      : world.get(node.parentMeshId);
    if (!parent) throw new Error("Study chain contains an unresolved parent");
    world.set(node.sourceMeshId, parent.clone().multiply(local));
  }
  return world;
}

/** Ghost's scene-space transform. Original geometry and source mesh stay still. */
export function studyGhostWorldMatrix(
  originalRootWorld: Matrix4,
  originalSourceMeshWorld: Matrix4,
  sourceDelta: Matrix4
): Matrix4 | null {
  if ([originalRootWorld, originalSourceMeshWorld, sourceDelta].some(
    matrix => !matrix.elements.every(Number.isFinite)
  ) || Math.abs(originalRootWorld.determinant()) < 1e-20) return null;
  return originalRootWorld.clone()
    .multiply(sourceDelta)
    .multiply(originalRootWorld.clone().invert())
    .multiply(originalSourceMeshWorld);
}

export function transformedStudyPoint(
  originalPoint: SourcePoint3, sourceDelta: Matrix4
): SourcePoint3 | null {
  const pt = new Vector3(...originalPoint).applyMatrix4(sourceDelta);
  if (![pt.x, pt.y, pt.z].every(Number.isFinite)) return null;
  return [pt.x, pt.y, pt.z];
}

/** Gap is a geometric diagnostic, not anatomical accuracy or limb attachment. */
export function studyParentGapRatio(
  parent: StudyChainNode,
  child: StudyChainNode
): number {
  const parentLength = Math.hypot(
    parent.end[0] - parent.start[0],
    parent.end[1] - parent.start[1],
    parent.end[2] - parent.start[2]
  );
  const gap = Math.hypot(
    child.start[0] - parent.end[0],
    child.start[1] - parent.end[1],
    child.start[2] - parent.end[2]
  );
  return parentLength > 1e-7 ? gap / parentLength : Infinity;
}

export function countLargeStudyGaps(
  nodes: readonly StudyChainNode[], threshold = 0.2
): number {
  const byId = new Map(nodes.map(node => [node.sourceMeshId, node]));
  let count = 0;
  for (const node of nodes) {
    if (node.parentMeshId === null) continue;
    const parent = byId.get(node.parentMeshId);
    if (parent && studyParentGapRatio(parent, node) > threshold) count++;
  }
  return count;
}
