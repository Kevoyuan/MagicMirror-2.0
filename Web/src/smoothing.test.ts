import { describe, expect, it } from "vitest";
import { TemporalPoseStabilizer } from "./smoothing";
import { usable, type PosePoint } from "./pose";

const blank = () => Array.from({ length: 33 }, (): PosePoint => ({
  x: 0.4, y: 0.4, z: 0, visibility: 0.98, presence: 0.98,
}));
describe("visual-only pose stabilization, no invented bones", () => {
  it("smooths small valid motion without inventing invisible joints", () => {
    const s = new TemporalPoseStabilizer();
    const initial = blank();
    expect(s.sample(initial, 10)?.[11].x).toBe(0.4);
    const moved = blank();
    moved[11].x = 0.5;
    moved[13].visibility = 0.0;
    const result = s.sample(moved, 85)!;
    expect(result[11].x).toBeGreaterThan(0.4);
    expect(result[11].x).toBeLessThan(0.5);
    expect(usable(result[13])).toBe(false);
  });
  it("hides implausible keypoint teleport and reacquires, never extrapolates", () => {
    const s = new TemporalPoseStabilizer();
    s.sample(blank(), 100);
    const jump = blank();
    jump[11].x = 0.99;
    const hidden = s.sample(jump, 160)!;
    expect(usable(hidden[11])).toBe(false);
    const next = s.sample(jump, 230)!;
    expect(usable(next[11])).toBe(true);
    expect(next[11].x).toBe(0.99);
  });
  it("resets on lost person or long video stream gap", () => {
    const s = new TemporalPoseStabilizer();
    s.sample(blank(), 0);
    expect(s.sample(null, 70)).toBeNull();
    const resumed = blank();
    resumed[11].x = 0.6;
    expect(s.sample(resumed, 100)?.[11].x).toBe(0.6);
    resumed[11].x = 0.9;
    expect(s.sample(resumed, 1500)?.[11].x).toBe(0.9);
  });
  it("rejects out-of-order time and never retains all-invalid poses", () => {
    const s = new TemporalPoseStabilizer();
    s.sample(blank(), 200);
    expect(s.sample(blank(), 199)).toBeNull();
    const invalid = blank();
    invalid[11].x = Number.NaN;
    expect(usable(s.sample(invalid, 220)![11])).toBe(false);
  });
});
