import { expect, test } from "@playwright/test";

/**
 * W2n1 tests the ACTUAL Three.js SkinnedMesh -> exported GLB -> GLTFLoader
 * path in the local-only study dialog, not camera-tracked anatomy.
 */
test("original 19-joint skinned GLB loads with authored skin weights and bend clip", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await page.locator("#layers").click();
  await page.locator("#open-atlas-studio").click();
  const dialog = page.locator("#atlas-dialog");
  await expect(dialog).toBeVisible();
  const button = page.locator("#atlas-skinned-demo");
  await expect(button).toBeEnabled();
  await button.click();

  const diagnostics = page.locator("#atlas-rig-info");
  await expect(diagnostics).toContainText("已绑定网格 1 个", { timeout: 60_000 });
  await expect(diagnostics).toContainText("关节 19 个");
  await expect(diagnostics).toContainText("无权重 0");
  await expect(diagnostics).toContainText("异常权重 0");
  await expect(diagnostics).toContainText("越界关节 0");
  await expect(diagnostics).toContainText("权重和异常 0");
  await expect(diagnostics).toContainText("非绑定验收");
  // A genuinely skinned ORIGINAL GLB still does not imply legal anatomical rights.
  await expect(page.locator("#atlas-rights-export")).toBeEnabled();
  await expect(page.locator("#atlas-rights-status")).toContainText("所有来源网格仍待逐项版权审核");

  const clip = page.locator("#atlas-clip");
  await expect(clip).toBeEnabled();
  await expect(clip.locator("option")).toHaveCount(1);
  await expect(clip.locator("option").first()).toContainText("Original joint-bend study");
  await page.locator("#atlas-play-animation").click();
  await expect(page.locator("#atlas-pause-animation")).toBeEnabled();
  await page.locator("#atlas-pause-animation").click();
  await expect(page.locator("#atlas-play-animation")).toBeEnabled();

  // Still a separate, user-initiated local study surface.
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#stage canvas")).toHaveCount(1);
  await dialog.locator('[data-close="atlas-dialog"]').click();
  await expect(dialog).not.toBeVisible();
});

test("W2n1 original skinning demo remains explicitly non-anatomical and bilingual", async ({ page }) => {
  await page.goto("/");
  await page.locator("#language-toggle").click();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await page.locator("#layers").click();
  await page.locator("#open-atlas-studio").click();
  const button = page.locator("#atlas-skinned-demo");
  await expect(button).toContainText("original 19-joint skinned rig");
  await expect(page.locator("#atlas-dialog")).toContainText("NOT an anatomical mesh");
  await expect(page.locator("#atlas-dialog")).toContainText("NOT a");
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#stop")).toBeDisabled();
});
