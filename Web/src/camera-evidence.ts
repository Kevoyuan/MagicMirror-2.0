/**
 * W3d stage 1: validate declared camera geometry AGAINST point observations
 * supplied by the owner, not camera frames or MediaPipe "world" guesses.
 *
 * This is an offline evidence audit, not a camera solver nor an approval gate.
 * Neither a low residual nor "external-unverified" provenance can certify
 * authentic physical measurements or unlock anatomy/production build.
 */
import {
  projectWorldPoint, validHypothesis,
  type CameraIntrinsics, type WorldToCamera,
  type PerspectiveHypothesis, type PerspectiveDisplay,
} from "./camera-registration";

export const MAX_CAMERA_EVIDENCE_BYTES = 128 * 1024;
export const MAX_CAMERA_EVIDENCE_OBSERVATIONS = 256;
export const CAMERA_EVIDENCE_RMSE_RATIO = 0.0125;
export const CAMERA_EVIDENCE_P95_RATIO = 0.025;

export type EvidenceSource = "synthetic-fixture" | "external-unverified";
export type EvidenceOutcome =
  | "synthetic-consistent" | "external-consistent-unverified"
  | "inconsistent" | "invalid-depth";

export interface CameraEvidencePoint {
  readonly id: string;
  readonly world: readonly [number, number, number];
  readonly image: readonly [number, number];
}
export interface CameraEvidenceCapture {
  readonly id: string;
  readonly split: "reference" | "holdout";
  readonly points: readonly CameraEvidencePoint[];
}
export interface CameraEvidenceFile {
  readonly schemaVersion: 1;
  readonly kind: "magicmirror.camera-evidence";
  readonly provenance: EvidenceSource;
  readonly cameraModel: "pinhole-no-distortion";
  readonly units: "meters-declared";
  readonly intrinsics: CameraIntrinsics;
  readonly worldToCamera: WorldToCamera;
  readonly captures: readonly CameraEvidenceCapture[];
}

export interface EvidenceMetrics {
  readonly count: number;
  readonly rmsePx: number;
  readonly p95Px: number;
  readonly maximumPx: number;
}
export interface CameraEvidenceReview {
  readonly outcome: EvidenceOutcome;
  readonly provenance: EvidenceSource;
  readonly sourceCaptures: number;
  readonly reference: EvidenceMetrics;
  readonly holdout: EvidenceMetrics;
  readonly rejectedDepthPoints: number;
  readonly cameraCalibrationApproved: false;
  readonly anatomyOverlayApproved: false;
  readonly sourceAuthenticityVerified: false;
  readonly note: "LOCAL_GEOMETRY_CHECK_UNVERIFIED";
}
type Data = Record<string, unknown>;
function record(v: unknown, label: string): Data {
  if (!v || typeof v !== "object" || Array.isArray(v)) {
    throw new Error(label + " must be an object");
  }
  return v as Data;
}
function exactKeys(v: Data, keys: readonly string[], label: string): void {
  if (Object.keys(v).some(key => !keys.includes(key)) ||
      keys.some(key => !(key in v))) {
    throw new Error(label + " contains missing or unsupported fields");
  }
}
function finite(v: unknown, min: number, max: number): v is number {
  return typeof v === "number" && Number.isFinite(v) && v >= min && v <= max;
}
function id(v: unknown): v is string {
  return typeof v === "string" && /^[A-Za-z0-9_-]{1,64}$/.test(v);
}
function numericArray(v: unknown, length: number, min: number, max: number): number[] {
  if (!Array.isArray(v) || v.length !== length ||
      !v.every(n => finite(n, min, max))) throw new Error("Invalid numeric vector");
  return v as number[];
}
function summary(values: readonly number[]): EvidenceMetrics {
  const sorted = [...values].sort((a, b) => a - b);
  const sum = sorted.reduce((s, n) => s + n * n, 0);
  return {
    count: sorted.length,
    rmsePx: Math.sqrt(sum / sorted.length),
    p95Px: sorted[Math.ceil(sorted.length * 0.95) - 1],
    maximumPx: sorted[sorted.length - 1],
  };
}
function report(
  outcome: EvidenceOutcome,
  provenance: EvidenceSource,
  sourceCaptures: number,
  reference: EvidenceMetrics,
  holdout: EvidenceMetrics,
  rejectedDepthPoints: number,
): CameraEvidenceReview {
  return {
    outcome, provenance, sourceCaptures, reference, holdout,
    rejectedDepthPoints,
    cameraCalibrationApproved: false,
    anatomyOverlayApproved: false,
    sourceAuthenticityVerified: false,
    note: "LOCAL_GEOMETRY_CHECK_UNVERIFIED",
  };
}

/** No raw coordinates are returned; parse errors never include user input. */
export function reviewCameraEvidence(value: unknown): CameraEvidenceReview {
  const root = record(value, "Evidence");
  exactKeys(root, [
    "schemaVersion", "kind", "provenance", "cameraModel", "units",
    "intrinsics", "worldToCamera", "captures",
  ], "Evidence");
  if (root.schemaVersion !== 1 || root.kind !== "magicmirror.camera-evidence" ||
      (root.provenance !== "synthetic-fixture" &&
       root.provenance !== "external-unverified") ||
      root.cameraModel !== "pinhole-no-distortion" ||
      root.units !== "meters-declared") {
    throw new Error("Unsupported untrusted camera evidence format");
  }
  const source: EvidenceSource = root.provenance;
  const k = record(root.intrinsics, "Intrinsics");
  exactKeys(k, ["imageWidth", "imageHeight", "fx", "fy", "cx", "cy"], "Intrinsics");
  const intrinsics: CameraIntrinsics = {
    imageWidth: Number(k.imageWidth),
    imageHeight: Number(k.imageHeight),
    fx: Number(k.fx), fy: Number(k.fy),
    cx: Number(k.cx), cy: Number(k.cy),
  };
  // Do not coerce strings, booleans, null etc. to legitimate measurements.
  for (const key of ["imageWidth", "imageHeight", "fx", "fy", "cx", "cy"]) {
    if (typeof k[key] !== "number") throw new Error("Camera intrinsics must be numeric");
  }
  const t = record(root.worldToCamera, "Extrinsics");
  exactKeys(t, ["rotation", "translation"], "Extrinsics");
  const rotation = numericArray(t.rotation, 9, -1000, 1000);
  const translation = numericArray(t.translation, 3, -1000, 1000);
  const worldToCamera: WorldToCamera = { rotation, translation };
  const hypothesis: PerspectiveHypothesis = {
    source: "external-unverified", session: 1, frameId: 1,
    intrinsics, worldToCamera,
  };
  const display: PerspectiveDisplay = {
    sourceWidth: intrinsics.imageWidth,
    sourceHeight: intrinsics.imageHeight,
    viewportWidth: intrinsics.imageWidth,
    viewportHeight: intrinsics.imageHeight,
    mirrored: false,
  };
  if (!validHypothesis(hypothesis, display) ||
      !Number.isSafeInteger(intrinsics.imageWidth) ||
      !Number.isSafeInteger(intrinsics.imageHeight) ||
      intrinsics.imageWidth > 8192 || intrinsics.imageHeight > 8192) {
    throw new Error("Invalid perspective model; a rigid right-handed camera is required");
  }

  if (!Array.isArray(root.captures) || root.captures.length < 2 ||
      root.captures.length > 8) {
    throw new Error("Evidence requires 2–8 independent reference/holdout captures");
  }

  const captureIds = new Set<string>();
  const referenceIds = new Set<string>(), holdoutIds = new Set<string>();
  const referenceErrors: number[] = [], holdoutErrors: number[] = [];
  const allWorld: number[][] = [];
  let points = 0, rejectedDepthPoints = 0, referenceCaptures = 0, holdoutCaptures = 0;
  for (const rawCapture of root.captures as unknown[]) {
    const capture = record(rawCapture, "Capture");
    exactKeys(capture, ["id", "split", "points"], "Capture");
    if (!id(capture.id) || captureIds.has(capture.id) ||
        (capture.split !== "reference" && capture.split !== "holdout") ||
        !Array.isArray(capture.points) || capture.points.length < 6 ||
        capture.points.length > 64) {
      throw new Error("Invalid capture identity, split or point count");
    }
    captureIds.add(capture.id);
    if (capture.split === "reference") referenceCaptures++;
    else holdoutCaptures++;
    const localIds = new Set<string>();
    for (const rawPoint of capture.points as unknown[]) {
      const point = record(rawPoint, "Target point");
      exactKeys(point, ["id", "world", "image"], "Target point");
      if (!id(point.id) || localIds.has(point.id)) {
        throw new Error("Duplicate or invalid point identity");
      }
      localIds.add(point.id);
      const ids = capture.split === "reference" ? referenceIds : holdoutIds;
      const opposite = capture.split === "reference" ? holdoutIds : referenceIds;
      if (opposite.has(point.id)) {
        throw new Error("Reference/holdout must use disjoint target point identities");
      }
      ids.add(point.id);
      const world = numericArray(point.world, 3, -100, 100);
      const observed = numericArray(point.image, 2, -1, 8193);
      if (observed[0] < 0 || observed[0] > intrinsics.imageWidth ||
          observed[1] < 0 || observed[1] > intrinsics.imageHeight) {
        throw new Error("Observation lies outside original image coordinates");
      }
      allWorld.push(world);
      const projected = projectWorldPoint(
        { x: world[0], y: world[1], z: world[2] },
        intrinsics, worldToCamera,
      );
      if (!projected) {
        rejectedDepthPoints++;
      } else {
        const error = Math.hypot(projected.uPx - observed[0], projected.vPx - observed[1]);
        if (!Number.isFinite(error)) throw new Error("Nonfinite reprojection");
        if (capture.split === "reference") referenceErrors.push(error);
        else holdoutErrors.push(error);
      }
      points++;
      if (points > MAX_CAMERA_EVIDENCE_OBSERVATIONS) {
        throw new Error("Evidence contains too many target observations");
      }
    }
  }
  if (!referenceCaptures || !holdoutCaptures ||
      referenceErrors.length + holdoutErrors.length + rejectedDepthPoints !== points ||
      points < 12) {
    throw new Error("Evidence must include independent reference and holdout samples");
  }
  const ranges = [0, 1, 2].map(axis => {
    const values = allWorld.map(p => p[axis]);
    return Math.max(...values) - Math.min(...values);
  });
  const longest = Math.max(...ranges);
  if (longest < 0.05 || Math.min(...ranges) / longest < 0.08) {
    throw new Error("Measured 3D target is too small or nearly planar/collinear");
  }
  // A single bad positive-depth assumption invalidates the entire evidence set.
  const empty: EvidenceMetrics = { count: 0, rmsePx: 0, p95Px: 0, maximumPx: 0 };
  if (rejectedDepthPoints) {
    return report("invalid-depth", source, root.captures.length, empty, empty, rejectedDepthPoints);
  }
  if (referenceErrors.length < 6 || holdoutErrors.length < 6) {
    throw new Error("Too few valid disjoint reference/holdout observations");
  }
  const reference = summary(referenceErrors), holdout = summary(holdoutErrors);
  const short = Math.min(intrinsics.imageWidth, intrinsics.imageHeight);
  const withinLimits = reference.rmsePx <= CAMERA_EVIDENCE_RMSE_RATIO * short &&
    holdout.rmsePx <= CAMERA_EVIDENCE_RMSE_RATIO * short &&
    holdout.p95Px <= CAMERA_EVIDENCE_P95_RATIO * short;
  const outcome: EvidenceOutcome = !withinLimits ? "inconsistent" :
    source === "synthetic-fixture" ? "synthetic-consistent" :
    "external-consistent-unverified";
  return report(outcome, source, root.captures.length, reference, holdout, 0);
}
