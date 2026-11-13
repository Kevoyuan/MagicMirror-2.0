import { expect, test } from "@playwright/test";

/**
 * W3c: Synthetic camera-space projective geometry ONLY.
 *
 * This browser suite does not start getUserMedia, load a third-party model,
 * collect or inject a camera frame, or perform a real device calibration.
 * WebKit iPhone viewport/engine emulation is NOT physical iOS Safari QA.
 */
test("W3c in-app self-check is synthetic, bilingual, camera-free and readable", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#start")).toBeVisible();
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#stage canvas")).toHaveCount(1);

  await page.locator(".diagnostics-disclosure > summary").click();
  const panel = page.locator(".diagnostics-panel");
  const action = page.locator("#registration-self-check");
  await expect(panel).toBeVisible();
  await expect(action).toBeVisible();
  await expect(page.locator("#registration-self-check-status"))
    .toContainText("未执行");

  // The previously overlapping W3b 2D/world metrics now stack vertically.
  const metric = await page.locator("#frame-metric").boundingBox();
  const world = await page.locator("#world-pose-metric").boundingBox();
  expect(metric).not.toBeNull();
  expect(world).not.toBeNull();
  expect(world!.y).toBeGreaterThan(metric!.y);

  await action.click();
  const status = page.locator("#registration-self-check-status");
  await expect(status).toContainText("仅合成相机");
  await expect(status).toContainText("真实设备未标定");
  await expect(status).toContainText("12 点");
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#stage canvas")).toHaveCount(1);

  await page.locator("#language-toggle").click();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(action).toHaveText("Run synthetic camera check");
  await expect(status).toContainText("SYNTHETIC ONLY");
  await expect(status).toContainText("real device NOT calibrated");
  await expect(page.locator("#stop")).toBeDisabled();

  // The diagnostic is not a secret camera- or atlas-injection mode.
  expect(await page.evaluate(() =>
    typeof (window as unknown as Record<string, unknown>).__magicmirrorInjectPose,
  )).toBe("undefined");
});

test("W3c projective math rejects bad calibration and never approves anatomy", async ({ page }) => {
  await page.goto("/");
  const result = await page.evaluate(async () => {
    // Test-only Vite source import. No production injection hook is introduced.
    const load = (path: string): Promise<any> => import(path);
    const registration = await load("/src/camera-registration.ts");
    const fixture = await load("/src/camera-registration-fixture.ts");
    const good = fixture.runSyntheticPerspectiveSelfCheck();
    const intrinsic = {
      imageWidth: 800, imageHeight: 600, fx: 510, fy: 490, cx: 400, cy: 300,
    };
    const ray = registration.projectWorldPoint(
      { x: 0.2, y: -0.1, z: 0 },
      intrinsic,
      { rotation: [1, 0, 0, 0, 1, 0, 0, 0, 1], translation: [0, 0, 2.5] },
    );
    const behindCamera = registration.projectWorldPoint(
      { x: 0, y: 0, z: -3 },
      intrinsic,
      { rotation: [1, 0, 0, 0, 1, 0, 0, 0, 1], translation: [0, 0, 2.5] },
    );
    return {
      status: good.status,
      matched: good.matchedPoints,
      error: good.rmsePx,
      source: good.source,
      approvedCamera: good.cameraCalibrationApproved,
      approvedAtlas: good.anatomyOverlayApproved,
      note: good.note,
      ray, behindCamera,
    };
  });
  expect(result.status).toBe("geometric-candidate");
  expect(result.matched).toBe(12);
  expect(result.error).toBeLessThan(1e-7);
  expect(result.source).toBe("synthetic-fixture");
  expect(result.approvedCamera).toBe(false);
  expect(result.approvedAtlas).toBe(false);
  expect(result.note).toContain("NOT_CAMERA_CALIBRATION");
  expect(result.ray.uPx).toBeCloseTo(440.8, 6);
  expect(result.ray.vPx).toBeCloseTo(280.4, 6);
  expect(result.behindCamera).toBeNull();
});
