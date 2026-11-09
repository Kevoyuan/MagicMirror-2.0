import { describe, expect, it } from "vitest";
import { coverRect } from "./snapshot";

describe("explicit local screenshot framing", () => {
  it("matches object-fit cover for portrait stage", () => {
    expect(coverRect(640, 480, 300, 600)).toEqual({
      x: -250, y: 0, width: 800, height: 600,
    });
  });
  it("matches horizontally cropped landscape stage", () => {
    expect(coverRect(1920, 1080, 1000, 600)).toEqual({
      x: (1000 - 600 * 1920 / 1080) / 2,
      y: 0, width: 600 * 1920 / 1080, height: 600,
    });
  });
  it("fails closed for malformed dimensions", () => {
    expect(coverRect(0, 720, 300, 400)).toBeNull();
    expect(coverRect(Infinity, 720, 300, 400)).toBeNull();
    expect(coverRect(640, 480, -300, 400)).toBeNull();
  });
});
