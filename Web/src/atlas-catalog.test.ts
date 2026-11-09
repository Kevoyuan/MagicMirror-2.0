import { describe, expect, it } from "vitest";
import { effectivePartVisibility, normalizedPartQuery, searchAtlasParts, sourcePathForPart, type AtlasPart } from "./atlas-catalog";

const fixtures: AtlasPart[] = [
  { id: 0, name: "Femur_L", path: "Skeleton / Left / Femur_L", triangles: 120, visible: true },
  { id: 1, name: "Femur_R", path: "Skeleton / Right / Femur_R", triangles: 117, visible: false },
  { id: 2, name: "Radius_L", path: "Skeleton / Left / Radius_L", triangles: 72, visible: true },
  { id: 3, name: "Unnamed", path: "Other / Digit_01", triangles: 20, visible: true },
];
describe("LOCAL anatomy part search and visibility", () => {
  it("searches original mesh names and hierarchy without invented anatomical mappings", () => {
    const r = searchAtlasParts(fixtures, "femur");
    expect(r.matches.map(p => p.id)).toEqual([0, 1]);
    expect(r.hiddenParts).toBe(1);
    expect(searchAtlasParts(fixtures, "left").totalMatches).toBe(2);
    expect(searchAtlasParts(fixtures, "DIGIT_01").matches[0]?.id).toBe(3);
  });
  it("bounds output to protect mobile DOM and reports truncation honestly", () => {
    const r = searchAtlasParts(fixtures, "", 2);
    expect(r.totalMatches).toBe(4);
    expect(r.matches).toHaveLength(2);
    expect(r.truncated).toBe(true);
    expect(searchAtlasParts(fixtures, "no matching source").matches).toHaveLength(0);
  });
  it("restores individual visibility after temporary isolate mode", () => {
    expect(effectivePartVisibility(false, 0, null)).toBe(false);
    expect(effectivePartVisibility(false, 0, 0)).toBe(true);
    expect(effectivePartVisibility(true, 0, 1)).toBe(false);
    expect(effectivePartVisibility(true, 0, null)).toBe(true);
  });
  it("normalizes user query while keeping exact source filenames stored", () => {
    expect(normalizedPartQuery("  FＥＭＵＲ  ")).toBe("femur");
    expect(fixtures[0].name).toBe("Femur_L");
    expect(sourcePathForPart(["System", "Left"], "Femur")).toBe("System / Left / Femur");
  });
});
