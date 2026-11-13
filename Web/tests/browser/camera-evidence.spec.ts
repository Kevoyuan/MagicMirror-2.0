import { expect, test } from "@playwright/test";

/**
 * W3d browser-only local evidence workflow; NO real camera, model weights,
 * imported meshes, external services or calibration approval.
 */
test("W3d offline evidence is a modal, camera-free, bilingual and nonapproving", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#start")).toBeVisible();
  await page.locator(".diagnostics-disclosure > summary").click();
  await page.locator("#open-camera-evidence").click();
  const dialog = page.locator("#camera-evidence-dialog");
  await expect(dialog).toBeVisible();
  await expect(page.locator("#camera-evidence-status")).toContainText("尚未检查证据");

  const fixture = await page.evaluate(async () => {
    const module = await import("/src/camera-evidence-fixture.ts");
    return JSON.stringify(module.makeSyntheticCameraEvidence());
  });
  await page.locator("#camera-evidence-file").setInputFiles({
    name: "generated-synthetic.json", mimeType: "application/json",
    buffer: Buffer.from(fixture),
  });
  await expect(page.locator("#camera-evidence-status")).toContainText("合成证据");
  await expect(page.locator("#camera-evidence-status")).toContainText("验证集 8");
  await expect(page.locator("#camera-evidence-status")).toContainText("未标定/未授权叠加");
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);

  // Close native modal before interacting with the app header.
  await dialog.locator("[data-close]").click();
  await expect(dialog).not.toBeVisible();
  await page.locator("#language-toggle").click();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await page.locator("#open-camera-evidence").click();
  await expect(dialog).toBeVisible();
  await expect(page.locator("#camera-evidence-status")).toContainText("SYNTHETIC");
  await expect(page.locator("#camera-evidence-status")).toContainText("NOT calibrated");
  await expect(page.locator("#camera-evidence-status")).toContainText("NOT approved");
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#stage canvas")).toHaveCount(1);
});

test("W3d unverified external evidence remains unverified and bad files fail closed", async ({ page }) => {
  await page.goto("/");
  await page.locator(".diagnostics-disclosure > summary").click();
  await page.locator("#open-camera-evidence").click();
  const external = await page.evaluate(async () => {
    const module = await import("/src/camera-evidence-fixture.ts");
    return JSON.stringify(module.makeSyntheticCameraEvidence("external-unverified"));
  });
  const upload = page.locator("#camera-evidence-file");
  await upload.setInputFiles({
    name: "external-geometry.json", mimeType: "application/json",
    buffer: Buffer.from(external),
  });
  await expect(page.locator("#camera-evidence-status")).toContainText("外部来源未核实");
  await expect(page.locator("#camera-evidence-status")).toContainText("未标定");
  const corrupted = JSON.parse(external);
  corrupted.captures[1].points[0].world[2] = null;
  await upload.setInputFiles({
    name: "invalid-data.json", mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(corrupted)),
  });
  await expect(page.locator("#camera-evidence-status")).toContainText("证据文件无效");
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#stage canvas")).toHaveCount(1);
});
