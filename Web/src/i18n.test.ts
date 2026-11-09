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
  it("keeps camera-first disclosure controls bilingual", () => {
    expect(translate("透明度", "en")).toBe("Opacity");
    expect(translate("诊断", "en")).toBe("Diagnostics");
    expect(translate("阅读解剖说明", "en")).toBe("Read anatomy note");
    expect(translate("图层与许可说明", "en")).toBe("Layers & licensing");
    expect(translate("图层与许可说明", "zh")).toBe("图层与许可说明");
    expect(translate("AnatomicalOriginalMesh.fbx", "en")).toBe("AnatomicalOriginalMesh.fbx");
  });
  it("translates the W2l study session controls in both locales", () => {
    expect(translate("导出研究会话", "en")).toBe("Export study session");
    expect(translate("导入研究会话 JSON", "en")).toBe("Import study session JSON");
    expect(translate("本地研究会话 · 单文件原子恢复", "en"))
      .toContain("atomic restore");
    expect(translate("导出研究会话", "zh")).toBe("导出研究会话");
  });
  it("translates every W3a experimental-mode control and status", () => {
    expect(translate("实时叠加模式", "en")).toBe("Live overlay mode");
    expect(translate("参考骨架 / Reference Proxy", "en")).toBe("Reference Proxy");
    expect(translate("实时原创铰接模型（实验） / Live Original Rig (Experimental)", "en"))
      .toBe("Live Original Rig (Experimental)");
    expect(translate("实验模式的边界", "en")).toBe("Limits of the experimental mode");
    expect(translate("实验模式 · 铰接跟随", "en"))
      .toBe("Experimental · Articulated tracking");
    expect(translate("实验模式 · 本帧已隐藏", "en"))
      .toBe("Experimental · Frame hidden");
    expect(translate("实时叠加模式", "zh")).toBe("实时叠加模式");
    expect(translate("实验模式只使用 MagicMirror 原创程序化几何，把可见的肩—肘—腕组成屏幕对齐的 2.5D 铰接链，前臂继承上臂枢轴。它不是真实骨骼、解剖配准、相机空间 3D 重建或医学成像；导入的 FBX / GLB 模型不会参与实时跟随。", "en"))
      .toContain("camera-space 3D reconstruction");
  });
});
