import { expect, test, type Page } from "@playwright/test";
import { readFile } from "node:fs/promises";

/**
 * This E2E path intentionally NEVER calls Start camera.
 * No third-party FBX, copyrighted anatomy assets or MediaPipe weights
 * are loaded. Only browser-generated original boxes are tested.
 */
async function openPrivateDemo(page: Page): Promise<void> {
  await page.goto("/");
  await page.locator("#layers").click();
  await expect(page.locator("#layers-dialog")).toBeVisible();
  await page.locator("#open-atlas-studio").click();
  await expect(page.locator("#atlas-dialog")).toBeVisible();
  await page.locator("#atlas-demo").click();
  await expect(page.locator("#atlas-chain-stop")).toBeEnabled({
    timeout: 50_000,
  });
  await expect(page.locator("#atlas-part-count")).toContainText("3");
  await expect(page.locator("#atlas-timeline-frames button")).toHaveCount(3);
}

test("camera stays off; Leonardo dialogs and English UI remain usable", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#start")).toBeVisible();
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await page.locator("#language-toggle").click();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await page.locator("#layers").click();
  await expect(page.locator("#layers-dialog")).toBeVisible();
  await page.locator("#open-atlas-studio").click();
  await expect(page.locator("#atlas-dialog")).toBeVisible();
  await expect(page.locator("#atlas-demo")).toBeVisible();
  await page.locator('[data-close="atlas-dialog"]').click();
  await expect(page.locator("#atlas-dialog")).not.toBeVisible();
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
});

test("original in-browser GLB loads into real WebGL and replays the bounded chain", async ({ page }) => {
  await openPrivateDemo(page);
  await expect(page.locator("#atlas-chain-list button")).toHaveCount(3);
  await expect(page.locator("#atlas-chain-status")).toContainText("三方块示例");

  const chainNodes = page.locator("#atlas-chain-list button");
  await chainNodes.nth(1).click();
  await expect(page.locator("#atlas-chain-angle")).toBeEnabled();
  await page.locator("#atlas-chain-angle").focus();
  await page.keyboard.press("ArrowRight");
  await expect(page.locator("#atlas-chain-degrees")).not.toHaveText("0°");

  await page.locator("#atlas-timeline-frames button").last().click();
  await expect(page.locator("#atlas-timeline-display")).toHaveText("3.0s");
  await page.locator("#atlas-timeline-play").click();
  await expect(page.locator("#atlas-timeline-pause")).toBeEnabled();
  await expect(page.locator("#atlas-timeline-status")).toContainText("循环播放");
  await page.locator("#atlas-timeline-pause").click();
  await expect(page.locator("#atlas-timeline-play")).toBeEnabled();

  await page.locator('[data-close="atlas-dialog"]').click();
  await expect(page.locator("#atlas-dialog")).not.toBeVisible();
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
});

test("downloaded local timeline is source-locked; forged import fails atomically", async ({ page }) => {
  await openPrivateDemo(page);
  const downloadPromise = page.waitForEvent("download");
  await page.locator("#atlas-timeline-export").click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toMatch(/virtual-frames\.json$/);

  const filePath = await download.path();
  expect(filePath).toBeTruthy();
  const raw = JSON.parse(await readFile(filePath!, "utf8")) as {
    kind: string;
    cameraRetargeting: boolean;
    commercialReuseStatus: string;
    source: { sha256: string };
    frames: unknown[];
    [key: string]: unknown;
  };
  expect(raw.kind).toBe("magicmirror-local-virtual-chain-frames");
  expect(raw.frames).toHaveLength(3);
  expect(raw.cameraRetargeting).toBe(false);
  expect(raw.commercialReuseStatus).toBe("NOT_REVIEWED");
  expect(raw.source.sha256).toMatch(/^[a-f0-9]{64}$/);
  expect(JSON.stringify(raw)).not.toContain("POSITION_ATTRIBUTE");

  const invalid = {
    ...raw,
    source: { ...raw.source, sha256: "0".repeat(64) },
  };
  await page.locator("#atlas-timeline-import").setInputFiles({
    name: "tampered-frames.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(invalid)),
  });
  await expect(page.locator("#atlas-timeline-status")).toContainText("被拒绝");
  await expect(page.locator("#atlas-timeline-frames button")).toHaveCount(3);

  await page.locator("#atlas-timeline-import").setInputFiles({
    name: "restored-frames.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(raw)),
  });
  await expect(page.locator("#atlas-timeline-status")).toContainText("已导入 3 个");
  await expect(page.locator("#atlas-timeline-frames button")).toHaveCount(3);
});
