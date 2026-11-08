import { describe, expect, it } from "vitest";
import {
  coverageFor, mapImageToViewport, usable, visibleSegments,
  type PosePoint,
} from "./pose";

const blank = (): PosePoint[] =>
  Array.from({ length: 33 }, () => ({
    x: 0.5, y: 0.5, z: 0, visibility: 0,
  }));
function reveal(points: PosePoint[], ...indices: number[]) {
  for (const i of indices) {
    points[i] = { x: 0.1 + i / 70, y: 0.2 + i / 80, z: 0, visibility: 0.91 };
  }
}
describe("one-person pose reference gates", () => {
  it("accepts partial arm without the entire body", () => {
    const p = blank();
    reveal(p, 11, 13);
    expect(coverageFor(p)).toBe("partial");
    expect(visibleSegments(p, "arms").length).toBe(1);
    expect(visibleSegments(p, "legs").length).toBe(0);
  });
  it("only calls full torso coverage when shoulders and hips are visible", () => {
    const p = blank();
    reveal(p, 11, 12, 23, 24);
    expect(coverageFor(p)).toBe("torso");
    p[24].visibility = 0.02;
    expect(coverageFor(p)).toBe("none");
  });
  it("drops missing, low-confidence and nonfinite segments", () => {
    const p = blank();
    reveal(p, 11, 13);
    p[13].x = Number.NaN;
    expect(visibleSegments(p, "whole")).toEqual([]);
    expect(usable(p[13])).toBe(false);
    expect(coverageFor(p)).toBe("none");
    expect(visibleSegments(p.slice(0, 32), "whole")).toEqual([]);
  });
  it("reproduces object-fit cover cropping and selfie mirroring", () => {
    const pos = { x: 0, y: 0.5 };
    const back = mapImageToViewport(pos, 640, 480, 300, 600, false);
    const front = mapImageToViewport(pos, 640, 480, 300, 600, true);
    // scale=600/480=1.25 => rendered 800px wide; 250px cropped off both sides
    expect(back).toEqual({ x: -250, y: 300 });
    expect(front).toEqual({ x: 550, y: 300 });
  });
  it("rejects nonfinite geometry rather than showing false bones", () => {
    expect(mapImageToViewport({ x: 0.5, y: 0.5 }, 0, 480, 300, 600, false)).toBeNull();
    expect(mapImageToViewport({ x: Infinity, y: 0.5 }, 640, 480, 300, 600, false)).toBeNull();
  });
});
