import { expect, test } from "@playwright/test";
import { readFile } from "node:fs/promises";

/** W2m: generated original 3-box model; NO camera or third-party anatomy. */
test("W2m actual local model exports source-locked UNKNOWN-rights entries; NC import stays blocked", async ({ page }) => {
  await page.goto("/");
  await page.locator("#layers").click();
  await page.locator("#open-atlas-studio").click();
  await expect(page.locator("#atlas-dialog")).toBeVisible();
  await expect(page.locator("#atlas-rights-export")).toBeDisabled();
  await expect(page.locator("#atlas-rights-import")).toBeDisabled();
  await page.locator("#atlas-demo").click();
  await expect(page.locator("#atlas-rights-export")).toBeEnabled({ timeout: 50_000 });
  await expect(page.locator("#atlas-rights-import")).toBeEnabled();

  const promise = page.waitForEvent("download");
  await page.locator("#atlas-rights-export").click();
  const downloaded = await promise;
  expect(downloaded.suggestedFilename()).toContain("mesh-rights-worksheet");
  const path = await downloaded.path();
  expect(path).toBeTruthy();
  const worksheet = JSON.parse(await readFile(path!, "utf8"));
  expect(worksheet.schemaVersion).toBe(1);
  expect(worksheet.kind).toBe("magicmirror.local-mesh-rights");
  expect(worksheet.entries).toHaveLength(3);
  expect(worksheet.sourceSHA256).toMatch(/^[0-9a-f]{64}$/);
  expect(worksheet.entries.every((x: any) =>
    x.licenseId === "UNVERIFIED" && x.reviewStatus === "NOT_REVIEWED",
  )).toBe(true);
  expect(worksheet.redistributionApproved).toBe(false);
  expect(worksheet.commercialUseApproved).toBe(false);

  worksheet.entries[1].licenseId = "CC-BY-NC-SA-4.0";
  const importFile = page.locator("#atlas-rights-import");
  await importFile.setInputFiles({
    name: "annotated-local-rights.json", mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(worksheet)),
  });
  await expect(page.locator("#atlas-rights-status")).toContainText("NC 禁商用 1");
  await expect(page.locator("#atlas-rights-status")).toContainText("SA 相同方式共享 1");
  await expect(page.locator("#atlas-rights-status")).toContainText("不可公开分发");
  await expect(importFile).toHaveValue("");

  worksheet.sourceSHA256 = "f".repeat(64);
  await importFile.setInputFiles({
    name: "forged-model-rights.json", mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(worksheet)),
  });
  await expect(page.locator("#atlas-rights-status")).toContainText("证据不匹配");
  await expect(importFile).toHaveValue("");
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#stop")).toBeDisabled();
});
