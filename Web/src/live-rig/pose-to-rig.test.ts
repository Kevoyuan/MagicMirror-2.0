import { describe, expect, it } from "vitest";
import type { PosePoint } from "../pose";
import {
  LiveRigTracker, computeRigFrame, shortestAngleDelta, wrapRadians,
  RIG_ARM_LANDMARKS, RIG_FRESHNESS_MS,
  type RigObservation, type RigSide,
} from "./pose-to-rig";

/**
 * Deterministic numerical pose fixtures only. No camera frames, model weights,
 * third-party meshes, Worker, DOM or WebGL are used anywhere in this suite.
 */
const SRC_W = 1280;
const SRC_H = 720;

function point(x: number, y: number, confidence = 0.95): PosePoint {
  return { x, y, z: 0, visibility: confidence, presence: confidence };
}

function blank(): PosePoint[] {
  return Array.from({ length: 33 }, () => point(0.5, 0.5, 0));
}

interface ArmCoords {
  shoulder: [number, number];
  elbow: [number, number];
  wrist: [number, number];
  confidence?: number;
}

const LEFT_HORIZONTAL: ArmCoords = {
  shoulder: [0.30, 0.40], elbow: [0.45, 0.40], wrist: [0.60, 0.40],
};
const RIGHT_HORIZONTAL: ArmCoords = {
  shoulder: [0.70, 0.40], elbow: [0.55, 0.40], wrist: [0.40, 0.40],
};

function withArm(points: PosePoint[], side: RigSide, coords: ArmCoords): PosePoint[] {
  const copy = points.slice();
  const index = RIG_ARM_LANDMARKS[side];
  const confidence = coords.confidence ?? 0.95;
  copy[index.shoulder] = point(...coords.shoulder, confidence);
  copy[index.elbow] = point(...coords.elbow, confidence);
  copy[index.wrist] = point(...coords.wrist, confidence);
  return copy;
}

function observation(overrides: Partial<RigObservation> = {}): RigObservation {
  return {
    landmarks: withArm(withArm(blank(), "left", LEFT_HORIZONTAL), "right", RIGHT_HORIZONTAL),
    session: 1,
    frameId: 1,
    capturedAtMs: 1_000,
    nowMs: 1_100,
    sourceWidth: SRC_W,
    sourceHeight: SRC_H,
    viewportWidth: SRC_W,
    viewportHeight: SRC_H,
    mirrored: false,
    focus: "whole",
    ...overrides,
  };
}

const closeTo = (actual: number, expected: number, tolerance = 1e-9): void => {
  expect(Number.isFinite(actual)).toBe(true);
  expect(Math.abs(shortestAngleDelta(actual, expected))).toBeLessThanOrEqual(tolerance);
};

describe("W3a pose-to-rig: geometry and kinematics", () => {
  it("wraps angles and measures the shortest signed difference across +/-pi", () => {
    expect(wrapRadians(3 * Math.PI)).toBeCloseTo(-Math.PI, 9);
    closeTo(wrapRadians(-3 * Math.PI), Math.PI);
    closeTo(shortestAngleDelta(3.0, -3.0), 2 * Math.PI - 6);
    expect(Number.isNaN(wrapRadians(Number.NaN))).toBe(true);
  });

  it("builds a horizontal arm with explicit display-space length and scale", () => {
    const frame = computeRigFrame(observation());
    expect(frame.status).toBe("tracking");
    expect(frame.visibleSegments).toBe(4);
    const upper = frame.arms.left.upper!;
    expect(upper.start.x).toBeCloseTo(0.30 * SRC_W, 6);
    expect(upper.end.x).toBeCloseTo(0.45 * SRC_W, 6);
    expect(upper.lengthPx).toBeCloseTo(0.15 * SRC_W, 6);
    expect(upper.angleRadians).toBeCloseTo(0, 9);
    expect(upper.scale).toBeCloseTo(upper.lengthPx / (SRC_H * 0.14), 6);
    expect(upper.hierarchyAttached).toBe(true);
    expect(frame.arms.left.fore!.parentRelativeRadians).toBeCloseTo(0, 9);
    expect(frame.arms.left.fore!.hierarchyAttached).toBe(true);
    expect(frame.pivot!.x).toBeCloseTo(0.5 * SRC_W, 6);
  });

  it("builds a vertical arm and keeps the forearm angle parent-relative", () => {
    const vertical: ArmCoords = {
      shoulder: [0.30, 0.20], elbow: [0.30, 0.45], wrist: [0.45, 0.60],
    };
    const frame = computeRigFrame(observation({
      landmarks: withArm(blank(), "left", vertical),
    }));
    const upper = frame.arms.left.upper!;
    const fore = frame.arms.left.fore!;
    // Normalized deltas are NOT equal in pixels: source video is 1280x720.
    const expectedForeAngle = Math.atan2(
      (0.60 - 0.45) * SRC_H, (0.45 - 0.30) * SRC_W
    );
    closeTo(upper.angleRadians, Math.PI / 2);
    closeTo(fore.angleRadians, expectedForeAngle);
    closeTo(fore.parentRelativeRadians!,
      shortestAngleDelta(upper.angleRadians, fore.angleRadians));
    expect(fore.hierarchyAttached).toBe(true);
  });

  it("raises the anatomical left arm independently of the right arm", () => {
    const raised: ArmCoords = {
      shoulder: [0.40, 0.60], elbow: [0.40, 0.35], wrist: [0.55, 0.20],
    };
    const frame = computeRigFrame(observation({
      landmarks: withArm(blank(), "left", raised),
    }));
    expect(frame.status).toBe("partial");
    expect(frame.arms.right.visibleSegments).toBe(0);
    closeTo(frame.arms.left.upper!.angleRadians, -Math.PI / 2);
    closeTo(frame.arms.left.fore!.angleRadians, Math.atan2(
      (0.20 - 0.35) * SRC_H, (0.55 - 0.40) * SRC_W
    ));
    closeTo(frame.arms.left.fore!.parentRelativeRadians!,
      shortestAngleDelta(
        frame.arms.left.upper!.angleRadians,
        frame.arms.left.fore!.angleRadians
      ));
  });

  it("raises the anatomical right arm using the correct landmark indices", () => {
    const raised: ArmCoords = {
      shoulder: [0.60, 0.60], elbow: [0.60, 0.35], wrist: [0.75, 0.20],
    };
    const frame = computeRigFrame(observation({
      landmarks: withArm(blank(), "right", raised),
    }));
    expect(frame.arms.left.visibleSegments).toBe(0);
    expect(frame.arms.right.visibleSegments).toBe(2);
    closeTo(frame.arms.right.upper!.angleRadians, -Math.PI / 2);
    closeTo(frame.arms.right.fore!.parentRelativeRadians!,
      shortestAngleDelta(
        frame.arms.right.upper!.angleRadians,
        frame.arms.right.fore!.angleRadians
      ));
  });

  it("distinguishes elbow flexion from full extension", () => {
    const flexed: ArmCoords = {
      shoulder: [0.30, 0.40], elbow: [0.45, 0.40], wrist: [0.45, 0.25],
    };
    const extended: ArmCoords = {
      shoulder: [0.30, 0.40], elbow: [0.45, 0.40], wrist: [0.60, 0.40],
    };
    const flexedFrame = computeRigFrame(observation({
      landmarks: withArm(blank(), "left", flexed),
    }));
    const extendedFrame = computeRigFrame(observation({
      landmarks: withArm(blank(), "left", extended),
    }));
    closeTo(flexedFrame.arms.left.fore!.parentRelativeRadians!, -Math.PI / 2);
    closeTo(extendedFrame.arms.left.fore!.parentRelativeRadians!, 0);
    expect(flexedFrame.arms.left.fore!.start.x)
      .toBeCloseTo(flexedFrame.arms.left.upper!.end.x, 9);
    expect(flexedFrame.arms.left.fore!.start.y)
      .toBeCloseTo(flexedFrame.arms.left.upper!.end.y, 9);
  });

  it("mirrors display x but never mirrors anatomical left/right identities", () => {
    const plain = computeRigFrame(observation({ landmarks: withArm(blank(), "left", LEFT_HORIZONTAL) }));
    const mirrored = computeRigFrame(observation({
      landmarks: withArm(blank(), "left", LEFT_HORIZONTAL), mirrored: true,
    }));
    expect(mirrored.arms.left.upper).not.toBeNull();
    expect(mirrored.arms.right.visibleSegments).toBe(0);
    expect(mirrored.arms.left.upper!.start.x)
      .toBeCloseTo(SRC_W - plain.arms.left.upper!.start.x, 6);
    closeTo(mirrored.arms.left.upper!.angleRadians, Math.PI);
    expect(mirrored.arms.left.upper!.side).toBe("left");
  });

  it("applies object-fit:cover for unequal source and viewport aspect ratios", () => {
    const portrait = computeRigFrame(observation({
      viewportWidth: 360, viewportHeight: 640,
      landmarks: withArm(blank(), "left", LEFT_HORIZONTAL),
    }));
    const square = computeRigFrame(observation({
      viewportWidth: 1280, viewportHeight: 720,
      landmarks: withArm(blank(), "left", LEFT_HORIZONTAL),
    }));
    const scale = Math.max(360 / SRC_W, 640 / SRC_H);
    const xOffset = (360 - SRC_W * scale) / 2;
    expect(portrait.arms.left.upper!.start.x)
      .toBeCloseTo(0.30 * SRC_W * scale + xOffset, 6);
    expect(portrait.arms.left.upper!.end.y)
      .toBeCloseTo(0.40 * SRC_H * scale, 6);
    expect(portrait.arms.left.upper!.lengthPx)
      .not.toBeCloseTo(square.arms.left.upper!.lengthPx, 3);
    expect(portrait.arms.left.upper!.scale).toBeGreaterThan(0);
  });

  it("is deterministic for repeated identical inputs", () => {
    const first = computeRigFrame(observation());
    const second = computeRigFrame(observation());
    expect(second).toEqual(first);
  });

  it("does not accumulate angle or pivot drift over repeated frames", () => {
    const tracker = new LiveRigTracker();
    const base = observation();
    let previous = tracker.update(base);
    for (let i = 2; i <= 20; i++) {
      const next = tracker.update({
        ...base,
        frameId: i,
        capturedAtMs: 1_000 + i * 20,
        nowMs: 1_100 + i * 20,
      });
      expect(next.status).toBe("tracking");
      closeTo(next.arms.left.upper!.angleRadians, previous.arms.left.upper!.angleRadians);
      expect(Math.abs(next.pivot!.x - previous.pivot!.x)).toBeLessThan(1e-9);
      previous = next;
    }
    expect(previous.arms.left.upper!.angleRadians).toBeCloseTo(0, 9);
  });
});

describe("W3a pose-to-rig: detection quality and fail-closed inputs", () => {
  it("accepts a complete two-arm pose", () => {
    const frame = computeRigFrame(observation());
    expect(frame.status).toBe("tracking");
    expect(frame.visibleSegments).toBe(4);
    expect(frame.reasons).toHaveLength(0);
  });

  it("accepts partial upper-body observations without demanding a full body", () => {
    const frame = computeRigFrame(observation({
      focus: "arms",
      landmarks: withArm(blank(), "right", RIGHT_HORIZONTAL),
    }));
    expect(frame.status).toBe("partial");
    expect(frame.visibleSegments).toBe(2);
    expect(frame.pivot).not.toBeNull();
  });

  it("supports a forearm with NO visible shoulder as an INDEPENDENT segment", () => {
    const points = blank();
    const index = RIG_ARM_LANDMARKS.left;
    points[index.elbow] = point(0.45, 0.40);
    points[index.wrist] = point(0.60, 0.40);
    const frame = computeRigFrame(observation({ landmarks: points }));
    expect(frame.arms.left.upper).toBeNull();
    expect(frame.arms.left.fore).not.toBeNull();
    expect(frame.arms.left.fore!.hierarchyAttached).toBe(false);
    expect(frame.arms.left.fore!.parentRelativeRadians).toBeNull();
    expect(frame.arms.left.shoulder).toBeNull();
  });

  it("hides both segments when the elbow is occluded; never invents the joint", () => {
    const points = withArm(blank(), "left", LEFT_HORIZONTAL);
    points[RIG_ARM_LANDMARKS.left.elbow] = point(0.45, 0.40, 0.1);
    const frame = computeRigFrame(observation({ landmarks: points }));
    expect(frame.arms.left.upper).toBeNull();
    expect(frame.arms.left.fore).toBeNull();
    expect(frame.arms.left.visibleSegments).toBe(0);
    expect(frame.reasons).toContain("left:ELBOW_UNAVAILABLE");
  });

  it("hides a low-confidence wrist without freezing the upper arm", () => {
    const points = withArm(
      withArm(blank(), "left", LEFT_HORIZONTAL), "right", RIGHT_HORIZONTAL
    );
    points[RIG_ARM_LANDMARKS.left.wrist] = point(0.60, 0.40, 0.2);
    const frame = computeRigFrame(observation({ landmarks: points }));
    expect(frame.arms.left.upper).not.toBeNull();
    expect(frame.arms.left.fore).toBeNull();
    expect(frame.arms.right.visibleSegments).toBe(2);
    expect(frame.visibleSegments).toBe(3);
    expect(frame.reasons).toContain("left:WRIST_UNAVAILABLE");
  });

  it("rejects nonfinite landmarks anywhere in the 33-point observation", () => {
    const points = withArm(blank(), "left", LEFT_HORIZONTAL);
    points[5] = { x: Number.NaN, y: 0.5, z: 0, visibility: 0 };
    const frame = computeRigFrame(observation({ landmarks: points }));
    expect(frame.status).toBe("rejected");
    expect(frame.visibleSegments).toBe(0);
    expect(frame.reasons).toContain("NONFINITE_LANDMARK");
  });

  it("rejects a wrong landmark count and missing landmarks", () => {
    expect(computeRigFrame(observation({ landmarks: [] })).reasons)
      .toContain("INVALID_LANDMARK_COUNT");
    expect(computeRigFrame(observation({ landmarks: null })).reasons)
      .toContain("INVALID_LANDMARK_COUNT");
  });

  it("rejects zero-length / degenerate vectors", () => {
    const degenerate: ArmCoords = {
      shoulder: [0.30, 0.40], elbow: [0.30, 0.40], wrist: [0.30, 0.40],
    };
    const frame = computeRigFrame(observation({
      landmarks: withArm(blank(), "left", degenerate),
    }));
    expect(frame.status).toBe("none");
    expect(frame.visibleSegments).toBe(0);
    expect(frame.reasons).toContain("left:upperArm:DEGENERATE_SEGMENT");
    expect(frame.reasons).toContain("left:forearm:DEGENERATE_SEGMENT");
  });

  it("rejects invalid observation metadata and unsupported body regions", () => {
    expect(computeRigFrame(observation({ viewportWidth: Number.NaN })).reasons)
      .toContain("INVALID_OBSERVATION_META");
    expect(computeRigFrame(observation({ frameId: 0 })).reasons)
      .toContain("INVALID_OBSERVATION_META");
    expect(computeRigFrame(observation({ focus: "legs" })).reasons)
      .toContain("REGION_NOT_SUPPORTED");
  });

  it("never interprets normalized z as camera depth", () => {
    const points = withArm(blank(), "left", LEFT_HORIZONTAL);
    points[RIG_ARM_LANDMARKS.left.elbow] = {
      ...points[RIG_ARM_LANDMARKS.left.elbow], z: 0.9,
    };
    const frame = computeRigFrame(observation({ landmarks: points }));
    expect(frame.arms.left.upper!.end.y).toBeCloseTo(0.40 * SRC_H, 6);
    expect(frame.arms.left.upper!.lengthPx).toBeCloseTo(0.15 * SRC_W, 6);
  });

  it("hides impossibly discontinuous angle samples instead of smoothing a teleport", () => {
    const tracker = new LiveRigTracker({ stabilizationAlpha: 0 });
    const first = tracker.update(observation());
    expect(first.arms.left.upper!.angleRadians).toBeCloseTo(0, 9);
    const flipped: ArmCoords = {
      shoulder: [0.30, 0.40], elbow: [0.15, 0.40], wrist: [0.02, 0.40],
    };
    const second = tracker.update(observation({
      landmarks: withArm(blank(), "left", flipped),
      frameId: 2, capturedAtMs: 1_080, nowMs: 1_180,
    }));
    expect(second.arms.left.upper).toBeNull();
    expect(second.reasons).toContain("left:upperArm:ANGLE_DISCONTINUITY");
  });
});

describe("W3a pose-to-rig: camera lifecycle", () => {
  it("rejects frames from an old camera session", () => {
    const tracker = new LiveRigTracker();
    tracker.update(observation({ session: 2 }));
    const old = tracker.update(observation({ session: 1, frameId: 2 }));
    expect(old.status).toBe("rejected");
    expect(old.reasons).toContain("OLD_SESSION");
    expect(old.visibleSegments).toBe(0);
  });

  it("rejects out-of-order and duplicate frame ids", () => {
    const tracker = new LiveRigTracker();
    tracker.update(observation({ frameId: 7 }));
    expect(tracker.update(observation({ frameId: 7 })).reasons)
      .toContain("OUT_OF_ORDER_FRAME");
    expect(tracker.update(observation({ frameId: 6 })).reasons)
      .toContain("OUT_OF_ORDER_FRAME");
    expect(tracker.update(observation({ frameId: 8 })).status).toBe("tracking");
  });

  it("uses the existing 350 ms freshness contract", () => {
    expect(RIG_FRESHNESS_MS).toBe(350);
    const stale = computeRigFrame(observation()); // pure frame never decides freshness
    expect(stale.status).toBe("tracking");
    const tracker = new LiveRigTracker();
    expect(tracker.update(observation({
      capturedAtMs: 1_000, nowMs: 1_000 + 351,
    })).reasons).toContain("STALE_RESULT");
    expect(tracker.update(observation({
      capturedAtMs: 1_000, nowMs: 1_000 + 349,
    })).status).toBe("tracking");
  });

  it("pause hides everything; resume clears stale transform history", () => {
    const tracker = new LiveRigTracker();
    tracker.update(observation());
    tracker.pause();
    expect(tracker.isPaused).toBe(true);
    expect(tracker.update(observation({ frameId: 2 })).reasons).toContain("PAUSED");
    tracker.resume();
    const resumed = tracker.update(observation({ frameId: 3 }));
    expect(resumed.status).toBe("tracking");
  });

  it("camera flip resets angle history rather than interpolating across mirror space", () => {
    const tracker = new LiveRigTracker({ stabilizationAlpha: 0 });
    tracker.update(observation());
    const flipped = tracker.update(observation({
      mirrored: true, frameId: 2, capturedAtMs: 1_080, nowMs: 1_180,
    }));
    expect(flipped.status).toBe("tracking");
    closeTo(flipped.arms.left.upper!.angleRadians, Math.PI);
  });

  it("camera stop/restart and a hidden tab accept a fresh session with frame id 1", () => {
    const tracker = new LiveRigTracker();
    tracker.update(observation({ session: 3, frameId: 12 }));
    tracker.reset(); // stopCamera(), visibilitychange or pagehide
    const restarted = tracker.update(observation({ session: 4, frameId: 1 }));
    expect(restarted.status).toBe("tracking");
    expect(restarted.session).toBe(4);
  });

  it("worker failure/fallback clears transform history but keeps the session usable", () => {
    const tracker = new LiveRigTracker();
    tracker.update(observation({ session: 5, frameId: 3 }));
    tracker.clearTransforms(); // recovery to throttled main-thread inference
    const recovered = tracker.update(observation({
      session: 5, frameId: 4, capturedAtMs: 1_100, nowMs: 1_200,
    }));
    expect(recovered.status).toBe("tracking");
    expect(recovered.session).toBe(5);
  });

  it("tracking loss clears history and never returns invented geometry", () => {
    const tracker = new LiveRigTracker();
    tracker.update(observation());
    const lost = tracker.update(observation({
      landmarks: null, frameId: 2, capturedAtMs: 1_080, nowMs: 1_180,
    }));
    expect(lost.status).toBe("rejected");
    expect(lost.visibleSegments).toBe(0);
    expect(lost.arms.left.upper).toBeNull();
    expect(lost.arms.right.fore).toBeNull();
  });

  it("stabilization can be disabled and re-enabled without losing ordering", () => {
    const tracker = new LiveRigTracker();
    tracker.update(observation());
    tracker.setStabilization(false);
    expect(tracker.update(observation({ frameId: 2 })).status).toBe("tracking");
    tracker.setStabilization(true);
    expect(tracker.update(observation({ frameId: 3 })).status).toBe("tracking");
  });
});
