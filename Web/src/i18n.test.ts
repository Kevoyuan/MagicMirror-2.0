import { describe, expect, it } from "vitest";
import { translate } from "./i18n";

describe("Web bilingual presentation", () => {
  it("translates the observable UI without affecting pose geometry", () => {
    expect(translate("开启摄像头", "en")).toBe("Start camera");
    expect(translate("暂停叠加", "en")).toBe("Pause overlay");
    expect(translate("已识别 · 局部姿态", "en")).toContain("Partial body");
  });
  it("preserves Chinese text and unknown scientific identifiers", () => {
    expect(translate("解剖图层", "zh")).toBe("解剖图层");
    expect(translate("SkeletalSystem100.fbx", "en")).toBe("SkeletalSystem100.fbx");
  });
});
