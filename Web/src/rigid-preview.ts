import { Matrix4, Vector3 } from "three";
import {
  sufficientAnchorDistance, validSourcePoint,
  type SourcePoint3,
} from "./atlas-anchors";

/**
 * W2f: reversible demonstration for one UN-SKINNED source mesh.
 * The clicked point A is the user-provided pivot; B is an uncalibrated
 * reference end. The user chooses a SOURCE-ROOT X/Y/Z rotation axis.
 * This is neither a physiological joint nor a human pose retargeter.
 */
export type SourceAxis = "x" | "y" | "z";
export const RIGID_PREVIEW_MAX_DEGREES = 90;

export function validRigidAngle(angleDegrees: number): boolean {
  return Number.isFinite(angleDegrees) &&
    Math.abs(angleDegrees) <= RIGID_PREVIEW_MAX_DEGREES;
}

export function validRigidSource(
  a: SourcePoint3 | null, b: SourcePoint3 | null
): a is SourcePoint3 {
  return validSourcePoint(a) && validSourcePoint(b) &&
    sufficientAnchorDistance(a, b);
}

/** Delta in original imported model-root space, not camera/patient space. */
export function sourceRootRigidDelta(
  start: SourcePoint3 | null, end: SourcePoint3 | null,
  axis: SourceAxis, angleDegrees: number
): Matrix4 | null {
  if (!validRigidSource(start, end) || !validRigidAngle(angleDegrees)) return null;
  const axes: Record<SourceAxis, [number, number, number]> = {
    x: [1, 0, 0], y: [0, 1, 0], z: [0, 0, 1],
  };
  if (!Object.prototype.hasOwnProperty.call(axes, axis)) return null;
  const pivot = new Vector3(...start);
  const localAxis = new Vector3(...axes[axis]);
  return new Matrix4()
    .makeTranslation(pivot.x, pivot.y, pivot.z)
    .multiply(new Matrix4().makeRotationAxis(
      localAxis, angleDegrees * Math.PI / 180
    ))
    .multiply(new Matrix4().makeTranslation(-pivot.x, -pivot.y, -pivot.z));
}

/**
 * Apply the exact source-root delta to the original mesh WORLD matrix,
 * then put it back in its real original parent frame. Doing this from
 * baseline on every slider change prevents accumulated drift and works
 * even when parent/root transforms are nontrivial.
 *
 * Result should be assigned to mesh.matrix with matrixAutoUpdate=false;
 * no destructive geometry edits, skin weights or source file rewriting.
 */
export function previewMeshLocalMatrix(
  originalRootWorld: Matrix4, originalParentWorld: Matrix4,
  originalMeshWorld: Matrix4,
  start: SourcePoint3 | null, end: SourcePoint3 | null,
  axis: SourceAxis, angleDegrees: number
): Matrix4 | null {
  const delta = sourceRootRigidDelta(start, end, axis, angleDegrees);
  if (!delta) return null;
  const frames = [originalRootWorld, originalParentWorld, originalMeshWorld];
  if (frames.some(matrix =>
    !matrix.elements.every(Number.isFinite) ||
    !Number.isFinite(matrix.determinant())
  )) return null;
  if (Math.abs(originalRootWorld.determinant()) < 1e-20 ||
      Math.abs(originalParentWorld.determinant()) < 1e-20) return null;
  const rootInverse = originalRootWorld.clone().invert();
  const parentInverse = originalParentWorld.clone().invert();
  return parentInverse.multiply(originalRootWorld).multiply(delta)
    .multiply(rootInverse).multiply(originalMeshWorld);
}

export function transformedSourceEnd(
  start: SourcePoint3 | null, end: SourcePoint3 | null,
  axis: SourceAxis, angleDegrees: number
): SourcePoint3 | null {
  const delta = sourceRootRigidDelta(start, end, axis, angleDegrees);
  if (!delta || !end) return null;
  const moved = new Vector3(...end).applyMatrix4(delta);
  const point: SourcePoint3 = [moved.x, moved.y, moved.z];
  return validSourcePoint(point) ? point : null;
}
