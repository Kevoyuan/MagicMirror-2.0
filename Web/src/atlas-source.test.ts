import { describe, expect, it } from "vitest";
import {
  inspectLocalAtlasFile, normalizeSlice, sliceNormal, MAX_LOCAL_ATLAS_BYTES,
} from "./atlas-source";

describe("private local anatomy study asset boundary", () => {
  it("accepts only user-chosen FBX or self-contained GLB", () => {
    expect(inspectLocalAtlasFile({ name: "SkeletalSystem100.fbx", size: 41_339_660 })).toBe("fbx");
    expect(inspectLocalAtlasFile({ name: "MY_BONES.GLB", size: 32 })).toBe("glb");
    for (const name of ["uncleared.usdz", "model.gltf", "binary.zip", "../mesh.exe"]) {
      expect(() => inspectLocalAtlasFile({ name, size: 99 })).toThrow();
    }
  });
  it("rejects excessively large/empty local input before allocation", () => {
    expect(() => inspectLocalAtlasFile({ name: "bones.fbx", size: 0 })).toThrow();
    expect(() => inspectLocalAtlasFile({ name: "bones.fbx", size: MAX_LOCAL_ATLAS_BYTES + 1 })).toThrow();
  });
  it("defines model-space slicing axes, not clinically registered planes", () => {
    expect(sliceNormal("none")).toBeNull();
    expect(sliceNormal("axial-y")).toEqual([0, 1, 0]);
    expect(sliceNormal("sagittal-x")).toEqual([1, 0, 0]);
    expect(sliceNormal("coronal-z")).toEqual([0, 0, 1]);
    expect(normalizeSlice(0)).toBe(-1);
    expect(normalizeSlice(50)).toBe(0);
    expect(normalizeSlice(100)).toBe(1);
    expect(normalizeSlice(1000)).toBe(1);
    expect(normalizeSlice(NaN)).toBe(0);
  });
});
