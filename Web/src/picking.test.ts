import { describe, expect, it } from "vitest";
import { pointToSegmentDistance, pickSegment } from "./picking";
import { educationFor } from "./education";

const segment = {
  fromIndex: 11, toIndex: 13,
  start: { x: 10, y: 20 },
  end: { x: 110, y: 20 },
};
describe("interactive reference limb notes", () => {
  it("taps an actual observed proxy segment, not an empty part", () => {
    expect(pickSegment(60, 27, [segment])?.toIndex).toBe(13);
    expect(pickSegment(60, 100, [segment])).toBeNull();
    expect(pointToSegmentDistance(120, 20, segment)).toBe(10);
  });
  it("handles malformed and degenerate geometries safely", () => {
    expect(pickSegment(NaN, 20, [segment])).toBeNull();
    expect(pointToSegmentDistance(5, 6, {
      ...segment, start: { x: 5, y: 6 }, end: { x: 5, y: 6 }
    })).toBe(0);
    expect(pickSegment(10, 20, [{ ...segment, end: { x: NaN, y: 0 } }])).toBeNull();
  });
  it("returns source-honest anatomy notes only for supported segments", () => {
    const note = educationFor(11, 13);
    expect(note?.titleZh).toContain("肱骨");
    expect(note?.descriptionEn).toContain("surface landmarks");
    expect(educationFor(0, 11)).toBeNull();
  });
});
