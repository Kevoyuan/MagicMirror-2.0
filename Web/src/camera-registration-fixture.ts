/**
 * Deterministic, GENERATED 3D geometry fixture for a camera-free self-check.
 * Real camera frames, MediaPipe model weights and user data are NEVER used.
 * The fixture is NOT a pose injection hook; it is only diagnostic geometry.
 */
import type { PosePoint } from "./pose";
import {
  assessPerspectiveReprojection,
  type PerspectiveDiagnostic,
  type PerspectiveHypothesis,
} from "./camera-registration";
import { WORLD_FIT_INDICES } from "./world-pose";

const MODEL_COORDS = [
  [-0.33, -0.40, 0.05], [0.33, -0.40, -0.04],
  [-0.47, -0.15, 0.10], [0.47, -0.15, 0.00],
  [-0.65, 0.20, 0.02], [0.65, 0.20, -0.08],
  [-0.20, 0.10, 0.05], [0.20, 0.10, -0.05],
  [-0.24, 0.45, 0.00], [0.24, 0.45, -0.02],
  [-0.25, 0.67, 0.09], [0.25, 0.67, -0.09],
] as const;

const blank = (): PosePoint[] => Array.from({ length: 33 }, () => ({
  x: 0.5, y: 0.5, z: 0, visibility: 0, presence: 0,
}));

/** All observations generated independently of projectWorldPoint(). */
export function runSyntheticPerspectiveSelfCheck(): PerspectiveDiagnostic {
  const imageLandmarks = blank(), worldLandmarks = blank();
  const intrinsics = {
    imageWidth: 800, imageHeight: 600, fx: 510, fy: 490, cx: 400, cy: 300,
  };
  WORLD_FIT_INDICES.forEach((index, i) => {
    const [x, y, z] = MODEL_COORDS[i];
    worldLandmarks[index] = {
      x, y, z, visibility: 0.95, presence: 0.95,
    };
    // A DIFFERENT, independent pinhole calculation for the synthetic truth.
    imageLandmarks[index] = {
      x: (400 + (510 * x) / (2.5 + z)) / 800,
      y: (300 + (490 * y) / (2.5 + z)) / 600,
      z: 0,
      visibility: 0.95, presence: 0.95,
    };
  });
  const hypothesis: PerspectiveHypothesis = {
    source: "synthetic-fixture", session: 1, frameId: 1,
    intrinsics,
    worldToCamera: {
      rotation: [1, 0, 0, 0, 1, 0, 0, 0, 1],
      translation: [0, 0, 2.5],
    },
  };
  return assessPerspectiveReprojection(
    { session: 1, frameId: 1, imageLandmarks, worldLandmarks },
    hypothesis,
    {
      sourceWidth: 800, sourceHeight: 600,
      viewportWidth: 800, viewportHeight: 600, mirrored: false,
    },
  );
}
