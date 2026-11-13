import { describe, expect, it } from "vitest";
import { assessWorldPose, WORLD_FIT_INDICES } from "./world-pose";
import type { PosePoint } from "./pose";

const blank = (): PosePoint[] =>
  Array.from({ length: 33 }, () => ({
    x: 0.5, y: 0.5, z: 0, visibility: 0, presence: 0,
  }));

const modelCoords = [
  [-0.3, -0.4], [0.3, -0.4],
  [-0.5, -0.1], [0.5, -0.1],
  [-0.65, 0.2], [0.65, 0.2],
  [-0.2, 0.1], [0.2, 0.1],
  [-0.25, 0.45], [0.25, 0.45],
  [-0.3, 0.7], [0.3, 0.7],
] as const;

function fixture(mirrored = false) {
  const world = blank(), image = blank();
  WORLD_FIT_INDICES.forEach((index, i) => {
    const [x, y] = modelCoords[i];
    const u = 400 + 300 * x - 40 * y;
    const v = 250 + 40 * x + 300 * y;
    world[index] = { x, y, z: i * 0.005, visibility: 0.95, presence: 0.95 };
    image[index] = {
      x: u / 800, y: v / 600, z: 0, visibility: 0.95, presence: 0.95,
    };
  });
  return {
    image, world,
    viewport: {
      sourceWidth: 800, sourceHeight: 600,
      viewportWidth: 800, viewportHeight: 600, mirrored,
    },
  };
}

describe("W3b hip-relative world observation consistency (not calibration)", () => {
  it("fits a synthetic in-plane model without inventing camera depth", () => {
    const sample = fixture();
    const diagnostic = assessWorldPose(sample.image, sample.world, sample.viewport);
    expect(diagnostic.status).toBe("candidate");
    expect(diagnostic.matchedPoints).toBe(12);
    expect(diagnostic.rmsePx).toBeLessThan(1e-7);
    expect(diagnostic.transform?.a).toBeCloseTo(300, 6);
    expect(diagnostic.transform?.b).toBeCloseTo(40, 6);
    expect(diagnostic.note).toBe("MODEL_ESTIMATE_NOT_CAMERA_CALIBRATION");
  });

  it("handles the view mirror without swapping any body indices", () => {
    const sample = fixture(true);
    const result = assessWorldPose(sample.image, sample.world, sample.viewport);
    expect(result.status).toBe("candidate");
    expect(result.rmsePx).toBeLessThan(1e-7);
    expect(result.transform?.a).toBeCloseTo(300, 6);
    expect(result.transform?.b).toBeCloseTo(-40, 6);
  });

  it("respects the actual crop of a portrait viewport", () => {
    const sample = fixture();
    sample.viewport.viewportWidth = 360;
    sample.viewport.viewportHeight = 640;
    const result = assessWorldPose(sample.image, sample.world, sample.viewport);
    expect(result.status).toBe("candidate");
    expect(result.rmsePx).toBeLessThan(1e-7);
  });

  it("rejects missing world observations without affecting 2D tracking", () => {
    const sample = fixture();
    expect(assessWorldPose(sample.image, null, sample.viewport).status).toBe("unavailable");
    expect(assessWorldPose(null, sample.world, sample.viewport).status).toBe("unavailable");
    expect(assessWorldPose(sample.image, sample.world.slice(1), sample.viewport).status)
      .toBe("unavailable");
  });

  it("requires enough confidently matched points and nondegenerate world variance", () => {
    const sample = fixture();
    for (const id of WORLD_FIT_INDICES.slice(4)) {
      sample.image[id].visibility = 0.1;
    }
    const sparse = assessWorldPose(sample.image, sample.world, sample.viewport);
    expect(sparse.status).toBe("insufficient");
    expect(sparse.matchedPoints).toBe(4);
    const flat = fixture();
    for (const id of WORLD_FIT_INDICES) {
      flat.world[id] = { ...flat.world[id], x: 0, y: 0 };
    }
    expect(assessWorldPose(flat.image, flat.world, flat.viewport).status)
      .toBe("degenerate");
  });

  it("marks an outlier inconsistent and never approves an extrinsic fit", () => {
    const sample = fixture();
    sample.image[11] = { ...sample.image[11], x: sample.image[11].x + 0.34 };
    const result = assessWorldPose(sample.image, sample.world, sample.viewport);
    expect(result.status).toBe("inconsistent");
    expect(result.normalizedRmse).toBeGreaterThan(0.06);
    expect(result.note).toBe("MODEL_ESTIMATE_NOT_CAMERA_CALIBRATION");
  });

  it("excludes nonfinite world points without crashing or producing fake 3D", () => {
    const sample = fixture();
    sample.world[11] = { ...sample.world[11], z: Number.NaN };
    sample.world[12] = { ...sample.world[12], x: Number.POSITIVE_INFINITY };
    const result = assessWorldPose(sample.image, sample.world, sample.viewport);
    expect(result.status).toBe("candidate");
    expect(result.matchedPoints).toBe(10);
  });

  it("returns a finite, bounded fit for partially occluded limbs", () => {
    const sample = fixture();
    for (const id of [15, 16, 25, 26, 27, 28]) {
      sample.image[id].presence = 0.1;
      sample.image[id].visibility = 0.1;
    }
    const result = assessWorldPose(sample.image, sample.world, sample.viewport);
    expect(result.status).toBe("candidate");
    expect(result.matchedPoints).toBe(6);
    expect(result.transform?.pixelsPerModelMeter).toBeGreaterThan(0);
  });
});
