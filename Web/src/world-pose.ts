/**
 * W3b: locally inspect whether MediaPipe's model-estimated hip-relative
 * world landmarks are approximately consistent with the SAME frame's image
 * landmarks. This is an IN-PLANE weak-perspective similarity fit only.
 *
 * There are no camera intrinsics, extrinsics, scene depth or calibrated body
 * dimensions here. Never use this transform to unlock an anatomical overlay.
 */
import { mapImageToViewport, usable, type PosePoint } from "./pose";

export const WORLD_FIT_INDICES = [
  11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28,
] as const;
export const WORLD_FIT_MIN_PAIRS = 5;
export const WORLD_FIT_MAX_NORMALIZED_RMSE = 0.06;

export interface WorldFitViewport {
  readonly sourceWidth: number;
  readonly sourceHeight: number;
  readonly viewportWidth: number;
  readonly viewportHeight: number;
  readonly mirrored: boolean;
}
export type WorldFitStatus =
  | "unavailable" | "insufficient" | "degenerate"
  | "inconsistent" | "candidate";

/** Screen pixels = [a -b; b a] * [possibly mirrored world X; world Y] + [tx,ty]. */
export interface WorldFitTransform {
  readonly a: number;
  readonly b: number;
  readonly tx: number;
  readonly ty: number;
  readonly pixelsPerModelMeter: number;
}
export interface WorldPoseDiagnostic {
  readonly status: WorldFitStatus;
  readonly matchedPoints: number;
  readonly rmsePx: number | null;
  readonly normalizedRmse: number | null;
  readonly transform: WorldFitTransform | null;
  readonly note: "MODEL_ESTIMATE_NOT_CAMERA_CALIBRATION";
}

type Pair = { x: number; y: number; u: number; v: number; weight: number };

function output(
  status: WorldFitStatus, matchedPoints: number,
  rmsePx: number | null = null, normalizedRmse: number | null = null,
  transform: WorldFitTransform | null = null
): WorldPoseDiagnostic {
  return {
    status, matchedPoints, rmsePx, normalizedRmse, transform,
    note: "MODEL_ESTIMATE_NOT_CAMERA_CALIBRATION",
  };
}
function validWorldPoint(p: PosePoint | undefined): p is PosePoint {
  return !!p && [p.x, p.y, p.z].every(
    value => Number.isFinite(value) && Math.abs(value) <= 100
  ) && (p.visibility === undefined || Number.isFinite(p.visibility)) &&
    (p.presence === undefined || Number.isFinite(p.presence));
}

/**
 * Weighted least-squares 2D similarity. World Z is validated but never treated
 * as measured camera depth. The mirror is applied to world X ONLY to handle
 * the view's horizontal reflection without swapping anatomical identities.
 *
 * A low residual means "in-plane consistency candidate" — not a calibrated
 * camera, physical body measurement, correct depth or clinically true rig.
 */
export function assessWorldPose(
  image: readonly PosePoint[] | null | undefined,
  world: readonly PosePoint[] | null | undefined,
  viewport: WorldFitViewport,
): WorldPoseDiagnostic {
  if (!image || !world || image.length !== 33 || world.length !== 33) {
    return output("unavailable", 0);
  }
  if (![viewport.sourceWidth, viewport.sourceHeight,
    viewport.viewportWidth, viewport.viewportHeight].every(
    value => Number.isFinite(value) && value > 0
  ) || typeof viewport.mirrored !== "boolean") {
    return output("degenerate", 0);
  }

  const pairs: Pair[] = [];
  for (const index of WORLD_FIT_INDICES) {
    const p = image[index], w = world[index];
    if (!usable(p) || !validWorldPoint(w)) continue;
    const confidence = Math.min(
      p.visibility ?? p.presence ?? 0,
      w.visibility ?? w.presence ?? 1
    );
    if (!Number.isFinite(confidence) || confidence < 0.55) continue;
    const projected = mapImageToViewport(
      p, viewport.sourceWidth, viewport.sourceHeight,
      viewport.viewportWidth, viewport.viewportHeight, viewport.mirrored,
    );
    if (!projected) continue;
    pairs.push({
      x: viewport.mirrored ? -w.x : w.x, y: w.y,
      u: projected.x, v: projected.y, weight: confidence,
    });
  }
  if (pairs.length < WORLD_FIT_MIN_PAIRS) return output("insufficient", pairs.length);

  const sumW = pairs.reduce((s, p) => s + p.weight, 0);
  if (!Number.isFinite(sumW) || sumW <= 0) return output("degenerate", pairs.length);
  const means = pairs.reduce((s, p) => ({
    x: s.x + p.weight * p.x, y: s.y + p.weight * p.y,
    u: s.u + p.weight * p.u, v: s.v + p.weight * p.v,
  }), { x: 0, y: 0, u: 0, v: 0 });
  const cx = means.x / sumW, cy = means.y / sumW;
  const cu = means.u / sumW, cv = means.v / sumW;
  let denominator = 0, numeratorA = 0, numeratorB = 0;
  for (const p of pairs) {
    const x = p.x - cx, y = p.y - cy;
    const u = p.u - cu, v = p.v - cv;
    denominator += p.weight * (x * x + y * y);
    numeratorA += p.weight * (x * u + y * v);
    numeratorB += p.weight * (x * v - y * u);
  }
  if (!Number.isFinite(denominator) || denominator / sumW < 1e-8) {
    return output("degenerate", pairs.length);
  }
  const a = numeratorA / denominator, b = numeratorB / denominator;
  const tx = cu - a * cx + b * cy;
  const ty = cv - b * cx - a * cy;
  const scale = Math.hypot(a, b);
  if (![a, b, tx, ty, scale].every(Number.isFinite) || scale < 1e-6) {
    return output("degenerate", pairs.length);
  }
  const sumError = pairs.reduce((s, p) => {
    const du = a * p.x - b * p.y + tx - p.u;
    const dv = b * p.x + a * p.y + ty - p.v;
    return s + p.weight * (du * du + dv * dv);
  }, 0);
  const rmse = Math.sqrt(sumError / sumW);
  const normalized = rmse / Math.min(viewport.viewportWidth, viewport.viewportHeight);
  if (![rmse, normalized].every(Number.isFinite)) return output("degenerate", pairs.length);
  const transform = { a, b, tx, ty, pixelsPerModelMeter: scale };
  return output(
    normalized <= WORLD_FIT_MAX_NORMALIZED_RMSE ? "candidate" : "inconsistent",
    pairs.length, rmse, normalized, transform,
  );
}
