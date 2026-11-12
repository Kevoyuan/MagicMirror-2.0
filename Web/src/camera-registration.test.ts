import { describe, expect, it } from "vitest";
import type { PosePoint } from "./pose";
import {
  assessPerspectiveReprojection, projectWorldPoint,
  PERSPECTIVE_MIN_PAIRS, PERSPECTIVE_MIN_DEPTH_M,
  type PerspectiveHypothesis, type PerspectiveObservations,
  type PerspectiveDisplay,
} from "./camera-registration";
import { runSyntheticPerspectiveSelfCheck } from "./camera-registration-fixture";
import { WORLD_FIT_INDICES } from "./world-pose";

const blank = (): PosePoint[] => Array.from({ length: 33 }, () => ({
  x: 0.5, y: 0.5, z: 0, visibility: 0, presence: 0,
}));

const coordinates = [
  [-0.33, -0.4, 0.05], [0.33, -0.4, -0.04],
  [-0.47, -0.15, 0.1], [0.47, -0.15, 0.0],
  [-0.65, 0.2, 0.02], [0.65, 0.2, -0.08],
  [-0.2, 0.1, 0.05], [0.2, 0.1, -0.05],
  [-0.24, 0.45, 0], [0.24, 0.45, -0.02],
  [-0.25, 0.67, 0.09], [0.25, 0.67, -0.09],
] as const;

function sample(): {
  frame: PerspectiveObservations;
  hypothesis: PerspectiveHypothesis;
  display: PerspectiveDisplay;
} {
  const imageLandmarks = blank(), worldLandmarks = blank();
  WORLD_FIT_INDICES.forEach((index, i) => {
    const [x, y, z] = coordinates[i];
    worldLandmarks[index] = {
      x, y, z, visibility: 0.95, presence: 0.95,
    };
    // Independent known-pinhole fixture; no call into implementation.
    imageLandmarks[index] = {
      x: (400 + 510 * x / (2.5 + z)) / 800,
      y: (300 + 490 * y / (2.5 + z)) / 600,
      z: 0, visibility: 0.95, presence: 0.95,
    };
  });
  return {
    frame: { session: 4, frameId: 20, imageLandmarks, worldLandmarks },
    hypothesis: {
      source: "synthetic-fixture", session: 4, frameId: 20,
      intrinsics: {
        imageWidth: 800, imageHeight: 600,
        fx: 510, fy: 490, cx: 400, cy: 300,
      },
      worldToCamera: {
        rotation: [1, 0, 0, 0, 1, 0, 0, 0, 1],
        translation: [0, 0, 2.5],
      },
    },
    display: {
      sourceWidth: 800, sourceHeight: 600,
      viewportWidth: 800, viewportHeight: 600, mirrored: false,
    },
  };
}

describe("W3c perspective reprojection: explicit-calibration geometry (synthetic)", () => {
  it("passes an independent synthetic scene without approving anatomy", () => {
    const s = sample();
    const result = assessPerspectiveReprojection(s.frame, s.hypothesis, s.display);
    expect(result.status).toBe("geometric-candidate");
    expect(result.matchedPoints).toBe(12);
    expect(result.rmsePx).toBeLessThan(1e-8);
    expect(result.p95Px).toBeLessThan(1e-8);
    expect(result.inlierFraction).toBe(1);
    expect(result.cameraCalibrationApproved).toBe(false);
    expect(result.anatomyOverlayApproved).toBe(false);
    expect(result.note).toBe("GEOMETRIC_CHECK_ONLY_NOT_CAMERA_CALIBRATION");
  });

  it("offers a one-click camera-free fixture with explicitly synthetic evidence", () => {
    const result = runSyntheticPerspectiveSelfCheck();
    expect(result.status).toBe("geometric-candidate");
    expect(result.source).toBe("synthetic-fixture");
    expect(result.cameraCalibrationApproved).toBe(false);
    expect(result.anatomyOverlayApproved).toBe(false);
  });

  it("checks the exact camera-session and frame identity", () => {
    const s = sample();
    expect(assessPerspectiveReprojection(
      { ...s.frame, session: 5 }, s.hypothesis, s.display,
    ).status).toBe("identity-mismatch");
    expect(assessPerspectiveReprojection(
      { ...s.frame, frameId: 19 }, s.hypothesis, s.display,
    ).status).toBe("identity-mismatch");
  });

  it("fails closed with missing or incorrectly sized world points", () => {
    const s = sample();
    expect(assessPerspectiveReprojection(
      { ...s.frame, worldLandmarks: null }, s.hypothesis, s.display,
    ).status).toBe("unavailable");
    expect(assessPerspectiveReprojection(
      { ...s.frame, imageLandmarks: null }, s.hypothesis, s.display,
    ).status).toBe("unavailable");
    expect(assessPerspectiveReprojection(
      { ...s.frame, worldLandmarks: s.frame.worldLandmarks!.slice(1) },
      s.hypothesis, s.display,
    ).status).toBe("invalid-calibration");
  });

  it("rejects nonfinite world values even if selected joints happen to be valid", () => {
    const s = sample();
    const world = [...s.frame.worldLandmarks!];
    world[0] = { ...world[0], z: NaN };
    expect(assessPerspectiveReprojection(
      { ...s.frame, worldLandmarks: world }, s.hypothesis, s.display,
    ).status).toBe("invalid-calibration");
  });

  it("rejects mismatched camera source dimensions or invalid focal lengths", () => {
    const s = sample();
    expect(assessPerspectiveReprojection(
      s.frame, s.hypothesis,
      { ...s.display, sourceWidth: 1280 },
    ).status).toBe("invalid-calibration");
    expect(assessPerspectiveReprojection(s.frame, {
      ...s.hypothesis,
      intrinsics: { ...s.hypothesis.intrinsics, fx: 0 },
    }, s.display).status).toBe("invalid-calibration");
    expect(assessPerspectiveReprojection(s.frame, {
      ...s.hypothesis,
      intrinsics: { ...s.hypothesis.intrinsics, cx: NaN },
    }, s.display).status).toBe("invalid-calibration");
  });

  it("rejects a reflected, scaled or non-orthonormal camera rotation", () => {
    const s = sample();
    for (const rotation of [
      [-1, 0, 0, 0, 1, 0, 0, 0, 1], // reflection, determinant -1
      [2, 0, 0, 0, 1, 0, 0, 0, 1], // not unit length
      [1, 0.01, 0, 0, 1, 0, 0, 0, 1], // not orthogonal
    ]) {
      expect(assessPerspectiveReprojection(s.frame, {
        ...s.hypothesis,
        worldToCamera: { ...s.hypothesis.worldToCamera, rotation },
      }, s.display).status).toBe("invalid-calibration");
    }
  });

  it("flags negative or too-small camera depth, never drawing behind the lens", () => {
    const s = sample();
    expect(PERSPECTIVE_MIN_DEPTH_M).toBeGreaterThan(0);
    const result = assessPerspectiveReprojection(s.frame, {
      ...s.hypothesis,
      worldToCamera: {
        ...s.hypothesis.worldToCamera, translation: [0, 0, -2.5],
      },
    }, s.display);
    expect(result.status).toBe("invalid-depth");
    expect(result.rejectedDepthPoints).toBeGreaterThan(0);
    expect(result.cameraCalibrationApproved).toBe(false);
  });

  it("detects wrong camera extrinsics even when all inputs are finite", () => {
    const s = sample();
    const result = assessPerspectiveReprojection(s.frame, {
      ...s.hypothesis,
      source: "external-unverified",
      worldToCamera: {
        ...s.hypothesis.worldToCamera, translation: [0.45, 0, 2.5],
      },
    }, s.display);
    expect(result.status).toBe("inconsistent");
    expect(result.rmsePx).toBeGreaterThan(30);
    expect(result.anatomyOverlayApproved).toBe(false);
  });

  it("keeps mirrored and portrait cover-crop displays in the same coordinate frame", () => {
    const s = sample();
    for (const display of [
      { ...s.display, mirrored: true },
      { ...s.display, viewportWidth: 360, viewportHeight: 640 },
      { ...s.display, viewportWidth: 360, viewportHeight: 640, mirrored: true },
    ]) {
      const result = assessPerspectiveReprojection(s.frame, s.hypothesis, display);
      expect(result.status).toBe("geometric-candidate");
      expect(result.rmsePx).toBeLessThan(1e-8);
    }
  });

  it("supports partial bodies with >=6 matched points and rejects sparse poses", () => {
    const s = sample();
    expect(PERSPECTIVE_MIN_PAIRS).toBe(6);
    const world = [...s.frame.worldLandmarks!];
    for (const index of WORLD_FIT_INDICES.slice(6)) {
      world[index] = { ...world[index], visibility: 0.05 };
    }
    const candidate = assessPerspectiveReprojection(
      { ...s.frame, worldLandmarks: world }, s.hypothesis, s.display,
    );
    expect(candidate.matchedPoints).toBe(6);
    expect(candidate.status).toBe("geometric-candidate");
    world[WORLD_FIT_INDICES[5]] = { ...world[WORLD_FIT_INDICES[5]], visibility: 0.05 };
    const sparse = assessPerspectiveReprojection(
      { ...s.frame, worldLandmarks: world }, s.hypothesis, s.display,
    );
    expect(sparse.status).toBe("insufficient");
    expect(sparse.matchedPoints).toBe(5);
  });

  it("rejects collinear image-space observations as degenerate evidence", () => {
    const s = sample();
    const image = s.frame.imageLandmarks!.map(p => ({ ...p }));
    for (const index of WORLD_FIT_INDICES) image[index].y = 0.5;
    const result = assessPerspectiveReprojection(
      { ...s.frame, imageLandmarks: image }, s.hypothesis, s.display,
    );
    expect(result.status).toBe("degenerate");
  });

  it("uses worst-case residual and inliers, not only average RMSE", () => {
    const s = sample();
    const image = s.frame.imageLandmarks!.map(p => ({ ...p }));
    image[15].x += 0.30;
    image[16].x -= 0.30;
    const result = assessPerspectiveReprojection(
      { ...s.frame, imageLandmarks: image }, s.hypothesis, s.display,
    );
    expect(result.status).toBe("inconsistent");
    expect(result.p95Px).toBeGreaterThan(100);
    expect(result.inlierFraction).toBeLessThan(0.9);
  });

  it("rejects invalid source provenance and never upgrades unverified evidence", () => {
    const s = sample();
    expect(assessPerspectiveReprojection(
      s.frame, { ...s.hypothesis, source: "device-certified" as never },
      s.display,
    ).status).toBe("invalid-calibration");
    const result = assessPerspectiveReprojection(
      s.frame, { ...s.hypothesis, source: "external-unverified" }, s.display,
    );
    expect(result.status).toBe("geometric-candidate");
    expect(result.source).toBe("external-unverified");
    expect(result.anatomyOverlayApproved).toBe(false);
  });

  it("returns a simple pinhole projection with positive camera depth", () => {
    const s = sample();
    const projected = projectWorldPoint(
      { x: 0.2, y: -0.1, z: 0 },
      s.hypothesis.intrinsics, s.hypothesis.worldToCamera,
    );
    expect(projected?.uPx).toBeCloseTo(440.8, 6);
    expect(projected?.vPx).toBeCloseTo(280.4, 6);
    expect(projected?.depth).toBeCloseTo(2.5, 9);
    expect(projectWorldPoint(
      { x: 0, y: 0, z: -3 },
      s.hypothesis.intrinsics, s.hypothesis.worldToCamera,
    )).toBeNull();
  });
});
