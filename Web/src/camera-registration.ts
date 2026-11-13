/**
 * W3c: PURE camera-space perspective reprojection verifier.
 *
 * This accepts a KNOWN hypothesis (explicit intrinsics and world-to-camera
 * transform) and checks whether hip-relative model-estimated world points
 * would project near same-frame image landmarks. It does NOT estimate camera
 * calibration, physical depth or individual anatomical bone geometry.
 *
 * All proposals are either SYNTHETIC or EXTERNALLY UNVERIFIED; this module
 * NEVER approves a real anatomy overlay from a low numerical residual.
 */
import { mapImageToViewport, usable, type PosePoint } from "./pose";
import { WORLD_FIT_INDICES } from "./world-pose";

export const PERSPECTIVE_MIN_PAIRS = 6;
export const PERSPECTIVE_MIN_DEPTH_M = 0.05;
export const PERSPECTIVE_MAX_RMSE_RATIO = 0.03;
export const PERSPECTIVE_MAX_P95_RATIO = 0.06;
export const PERSPECTIVE_INLIER_RATIO = 0.8;

export interface CameraIntrinsics {
  readonly imageWidth: number;
  readonly imageHeight: number;
  readonly fx: number;
  readonly fy: number;
  readonly cx: number;
  readonly cy: number;
}

/** 3x3 ROW-MAJOR rigid rotation and translation in model-coordinate units. */
export interface WorldToCamera {
  readonly rotation: readonly number[];
  readonly translation: readonly number[];
}

/** Unknown device calibration is NOT represented as a trusted source. */
export interface PerspectiveHypothesis {
  readonly source: "synthetic-fixture" | "external-unverified";
  readonly session: number;
  readonly frameId: number;
  readonly intrinsics: CameraIntrinsics;
  readonly worldToCamera: WorldToCamera;
}

export interface PerspectiveObservations {
  readonly session: number;
  readonly frameId: number;
  readonly imageLandmarks: readonly PosePoint[] | null;
  readonly worldLandmarks: readonly PosePoint[] | null;
}

export interface PerspectiveDisplay {
  readonly sourceWidth: number;
  readonly sourceHeight: number;
  readonly viewportWidth: number;
  readonly viewportHeight: number;
  readonly mirrored: boolean;
}

export type PerspectiveStatus =
  | "unavailable" | "identity-mismatch" | "invalid-calibration"
  | "insufficient" | "degenerate" | "invalid-depth"
  | "inconsistent" | "geometric-candidate";

export interface PerspectiveDiagnostic {
  readonly status: PerspectiveStatus;
  readonly source: PerspectiveHypothesis["source"] | "unknown";
  readonly matchedPoints: number;
  readonly rejectedDepthPoints: number;
  readonly rmsePx: number | null;
  readonly p95Px: number | null;
  readonly inlierFraction: number | null;
  readonly cameraCalibrationApproved: false;
  readonly anatomyOverlayApproved: false;
  readonly note: "GEOMETRIC_CHECK_ONLY_NOT_CAMERA_CALIBRATION";
}

export interface ProjectedCameraPoint {
  readonly uPx: number;
  readonly vPx: number;
  readonly depth: number;
}

function diagnostic(
  status: PerspectiveStatus,
  source: PerspectiveDiagnostic["source"],
  matchedPoints = 0,
  rejectedDepthPoints = 0,
  rmsePx: number | null = null,
  p95Px: number | null = null,
  inlierFraction: number | null = null,
): PerspectiveDiagnostic {
  return {
    status, source, matchedPoints, rejectedDepthPoints,
    rmsePx, p95Px, inlierFraction,
    cameraCalibrationApproved: false,
    anatomyOverlayApproved: false,
    note: "GEOMETRIC_CHECK_ONLY_NOT_CAMERA_CALIBRATION",
  };
}

function finite(v: number): boolean { return Number.isFinite(v); }
function boundedPoint(p: PosePoint | undefined): p is PosePoint {
  return !!p &&
    [p.x, p.y, p.z].every(v => finite(v) && Math.abs(v) <= 100) &&
    (p.visibility === undefined || finite(p.visibility)) &&
    (p.presence === undefined || finite(p.presence));
}

export function validHypothesis(
  hypothesis: PerspectiveHypothesis, display: PerspectiveDisplay,
): boolean {
  const { intrinsics: k, worldToCamera: t } = hypothesis;
  if (hypothesis.source !== "synthetic-fixture" &&
      hypothesis.source !== "external-unverified") return false;
  if (![hypothesis.session, hypothesis.frameId].every(Number.isSafeInteger) ||
      hypothesis.session < 0 || hypothesis.frameId < 1) return false;
  if (!Number.isFinite(display.sourceWidth) ||
      !Number.isFinite(display.sourceHeight) ||
      !Number.isFinite(display.viewportWidth) ||
      !Number.isFinite(display.viewportHeight) ||
      display.sourceWidth <= 0 || display.sourceHeight <= 0 ||
      display.viewportWidth <= 0 || display.viewportHeight <= 0 ||
      typeof display.mirrored !== "boolean") return false;
  if (![k.imageWidth, k.imageHeight, k.fx, k.fy, k.cx, k.cy].every(finite) ||
      k.imageWidth !== display.sourceWidth ||
      k.imageHeight !== display.sourceHeight ||
      k.fx <= 0 || k.fy <= 0 || k.fx > 1e6 || k.fy > 1e6 ||
      k.cx < -k.imageWidth || k.cx > 2 * k.imageWidth ||
      k.cy < -k.imageHeight || k.cy > 2 * k.imageHeight) return false;

  const r = t.rotation, xyz = t.translation;
  if (r.length !== 9 || xyz.length !== 3 ||
      ![...r, ...xyz].every(v => finite(v) && Math.abs(v) <= 1e3)) return false;
  const dot = (a: number, b: number): number =>
    r[a] * r[b] + r[a + 1] * r[b + 1] + r[a + 2] * r[b + 2];
  if (Math.abs(dot(0, 0) - 1) > 1e-3 ||
      Math.abs(dot(3, 3) - 1) > 1e-3 ||
      Math.abs(dot(6, 6) - 1) > 1e-3 ||
      Math.abs(dot(0, 3)) > 1e-3 ||
      Math.abs(dot(0, 6)) > 1e-3 ||
      Math.abs(dot(3, 6)) > 1e-3) return false;
  const det =
    r[0] * (r[4] * r[8] - r[5] * r[7]) -
    r[1] * (r[3] * r[8] - r[5] * r[6]) +
    r[2] * (r[3] * r[7] - r[4] * r[6]);
  return Math.abs(det - 1) <= 1e-3;
}

/**
 * Pinhole model, +Z forward, +X image right, +Y image down. No lens distortion.
 * World/model coordinates are NOT independently measured. The world-to-camera
 * transform is an explicit hypothesis, never inferred from MediaPipe z.
 */
export function projectWorldPoint(
  point: Readonly<Pick<PosePoint, "x" | "y" | "z">>,
  intrinsics: CameraIntrinsics,
  extrinsics: WorldToCamera,
): ProjectedCameraPoint | null {
  if (![point.x, point.y, point.z].every(finite)) return null;
  const r = extrinsics.rotation, t = extrinsics.translation;
  if (r.length !== 9 || t.length !== 3) return null;
  const x = r[0] * point.x + r[1] * point.y + r[2] * point.z + t[0];
  const y = r[3] * point.x + r[4] * point.y + r[5] * point.z + t[1];
  const depth = r[6] * point.x + r[7] * point.y + r[8] * point.z + t[2];
  if (![x, y, depth].every(finite) || depth <= PERSPECTIVE_MIN_DEPTH_M) return null;
  const uPx = intrinsics.fx * x / depth + intrinsics.cx;
  const vPx = intrinsics.fy * y / depth + intrinsics.cy;
  return [uPx, vPx].every(finite) ? { uPx, vPx, depth } : null;
}

/** Uses existing cover/mirror mapping for BOTH observed and predicted pixels. */
export function assessPerspectiveReprojection(
  frame: PerspectiveObservations,
  hypothesis: PerspectiveHypothesis,
  display: PerspectiveDisplay,
): PerspectiveDiagnostic {
  const source = hypothesis.source === "synthetic-fixture" ||
    hypothesis.source === "external-unverified" ? hypothesis.source : "unknown";
  if (!validHypothesis(hypothesis, display)) return diagnostic("invalid-calibration", source);
  if (frame.session !== hypothesis.session || frame.frameId !== hypothesis.frameId ||
      !Number.isSafeInteger(frame.session) || !Number.isSafeInteger(frame.frameId)) {
    return diagnostic("identity-mismatch", source);
  }
  const image = frame.imageLandmarks, world = frame.worldLandmarks;
  if (!image || !world) return diagnostic("unavailable", source);
  if (image.length !== 33 || world.length !== 33) {
    return diagnostic("invalid-calibration", source);
  }
  if (world.some(p => !boundedPoint(p))) return diagnostic("invalid-calibration", source);
  let rejectedDepthPoints = 0;
  let matchedPoints = 0;
  let weightedErrors = 0;
  let totalWeight = 0;
  let inliers = 0;
  const errors: number[] = [];
  const observedPoints: Array<{ x: number; y: number }> = [];
  const { sourceWidth, sourceHeight, viewportWidth, viewportHeight, mirrored } = display;
  const screenShort = Math.min(viewportWidth, viewportHeight);

  for (const index of WORLD_FIT_INDICES) {
    const p = image[index], w = world[index];
    if (!usable(p) || !boundedPoint(w)) continue;
    const confidence = Math.min(
      p.visibility ?? p.presence ?? 0,
      w.visibility ?? w.presence ?? 1,
    );
    if (confidence < 0.55) continue;
    const observed = mapImageToViewport(
      p, sourceWidth, sourceHeight, viewportWidth, viewportHeight, mirrored,
    );
    if (!observed) continue;
    const camera = projectWorldPoint(w, hypothesis.intrinsics, hypothesis.worldToCamera);
    if (!camera) {
      rejectedDepthPoints++;
      continue;
    }
    const predicted = mapImageToViewport(
      { x: camera.uPx / sourceWidth, y: camera.vPx / sourceHeight },
      sourceWidth, sourceHeight, viewportWidth, viewportHeight, mirrored,
    );
    if (!predicted) return diagnostic("invalid-calibration", source);
    const error = Math.hypot(predicted.x - observed.x, predicted.y - observed.y);
    if (!finite(error)) return diagnostic("invalid-calibration", source);
    weightedErrors += confidence * error * error;
    totalWeight += confidence;
    errors.push(error);
    observedPoints.push(observed);
    if (error / screenShort <= 0.04) inliers++;
    matchedPoints++;
  }

  if (rejectedDepthPoints > 0) {
    return diagnostic("invalid-depth", source, matchedPoints, rejectedDepthPoints);
  }
  if (matchedPoints < PERSPECTIVE_MIN_PAIRS || totalWeight <= 0) {
    return diagnostic("insufficient", source, matchedPoints);
  }

  // A tiny/collinear screen cluster cannot establish meaningful 3D agreement.
  const xs = observedPoints.map(p => p.x), ys = observedPoints.map(p => p.y);
  const spanX = Math.max(...xs) - Math.min(...xs);
  const spanY = Math.max(...ys) - Math.min(...ys);
  if (Math.min(spanX, spanY) < screenShort * 0.05) {
    return diagnostic("degenerate", source, matchedPoints);
  }
  const rmsePx = Math.sqrt(weightedErrors / totalWeight);
  errors.sort((a, b) => a - b);
  const p95Px = errors[Math.max(0, Math.ceil(errors.length * 0.95) - 1)];
  const inlierFraction = inliers / matchedPoints;
  const consistent =
    rmsePx / screenShort <= PERSPECTIVE_MAX_RMSE_RATIO &&
    p95Px / screenShort <= PERSPECTIVE_MAX_P95_RATIO &&
    inlierFraction >= PERSPECTIVE_INLIER_RATIO;
  return diagnostic(
    consistent ? "geometric-candidate" : "inconsistent",
    source, matchedPoints, 0, rmsePx, p95Px, inlierFraction,
  );
}
