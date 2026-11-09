import { expect, test } from "@playwright/test";

/**
 * W3a opt-in browser regression (same manual/branch-gated suite as W2j/W2k).
 *
 * NO camera is started, NO MediaPipe weight, NO third-party FBX/GLB and NO
 * production pose-injection hook is used. The deterministic numerical fixture
 * is passed to the PURE module and the ORIGINAL Three.js rig by a test-only
 * dynamic import inside page.evaluate; the production UI never exposes a way
 * to inject landmarks. Chromium desktop and iPhone-sized WebKit ENGINE
 * emulation are both exercised, but neither is physical-device acceptance.
 */

const NUMERICAL_FIXTURE = {
  sourceWidth: 1280,
  sourceHeight: 720,
  viewportWidth: 800,
  viewportHeight: 450,
};

test("W3a rig mode is opt-in, bilingual, camera-free and isolated from local study", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#start")).toBeVisible();
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  // One camera stage and ONE WebGL canvas: the rig reuses the existing host.
  await expect(page.locator("#stage canvas")).toHaveCount(1);

  // Fail-closed: no production backdoor for injecting synthetic poses.
  const hooks = await page.evaluate(() => {
    const scope = window as unknown as Record<string, unknown>;
    return [
      "__magicmirrorInjectPose", "__injectPose", "__MM_POSE__", "__mmInjectFrame",
    ].map((key) => [key, typeof scope[key]] as const);
  });
  expect(hooks.every(([, kind]) => kind === "undefined")).toBe(true);

  await page.locator("#layers").click();
  await expect(page.locator("#layers-dialog")).toBeVisible();
  const proxyRadio = page.locator('input[name="overlay-mode"][value="proxy"]');
  const rigRadio = page.locator('input[name="overlay-mode"][value="rig"]');
  await expect(proxyRadio).toBeChecked();
  await expect(rigRadio).not.toBeChecked();
  await expect(page.locator("#rig-mode-status")).toContainText("未开启实验模式");
  await expect(page.locator("#overlay-mode-field")).toContainText("Reference Proxy");
  await expect(page.locator("#overlay-mode-field")).toContainText(
    "Live Original Rig (Experimental)"
  );

  // Explicit opt-in, then verify the honest limitation copy in both locales.
  await rigRadio.check();
  await expect(page.locator("#rig-mode-status")).toContainText("2.5D");
  await expect(page.locator("#rig-mode-status")).toContainText("3D 配准");
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);

  await page.locator('[data-close="layers-dialog"]').click();
  await page.locator("#language-toggle").click();
  await page.locator("#layers").click();
  await expect(page.locator("html")).toHaveAttribute("lang", "en");
  await expect(page.locator("#overlay-mode-field legend")).toContainText("Live overlay mode");
  await expect(page.locator('label:has(input[value="rig"])'))
    .toContainText("Live Original Rig (Experimental)");
  await expect(page.locator('label:has(input[value="proxy"])'))
    .toContainText("Reference Proxy");
  await expect(page.locator("#rig-mode-status"))
    .toContainText("no camera-space 3D registration");

  // Opening the local FBX/GLB study must stay isolated from live retargeting.
  await page.locator("#open-atlas-studio").click();
  await expect(page.locator("#atlas-dialog")).toBeVisible();
  await expect(page.locator("#rig-mode-status"))
    .toContainText("never camera-retargeted");
  await expect(page.locator("#stop")).toBeDisabled();
  await expect(page.locator("#video")).toHaveJSProperty("srcObject", null);
  await expect(page.locator("#stage canvas")).toHaveCount(1);
});

test("W3a deterministic pose fixture yields a coherent original articulated rig", async ({ page }) => {
  await page.goto("/");
  const result = await page.evaluate(async (sizes) => {
    // Test-only dynamic import of source modules from the Vite dev server.
    // The production bundle exposes no equivalent injection path.
    const load = (path: string): Promise<any> => import(path);
    const pure = await load("/src/live-rig/pose-to-rig.ts");
    const rigModule = await load("/src/live-rig/original-rig.ts");

    const landmarks = Array.from({ length: 33 }, () => ({
      x: 0.5, y: 0.5, z: 0, visibility: 0, presence: 0,
    }));
    const at = (index: number, x: number, y: number, confidence = 0.95): void => {
      landmarks[index] = { x, y, z: 0, visibility: confidence, presence: confidence };
    };
    // Anatomical left = 11/13/15, right = 12/14/16 (person's own sides).
    at(11, 0.35, 0.4); at(13, 0.28, 0.55); at(15, 0.22, 0.7);
    at(12, 0.65, 0.4); at(14, 0.72, 0.55); at(16, 0.78, 0.7);

    const base = {
      landmarks,
      session: 1,
      frameId: 1,
      capturedAtMs: 1000,
      nowMs: 1000,
      sourceWidth: sizes.sourceWidth,
      sourceHeight: sizes.sourceHeight,
      viewportWidth: sizes.viewportWidth,
      viewportHeight: sizes.viewportHeight,
      mirrored: false,
      focus: "whole",
    };
    const frame = pure.computeRigFrame(base);
    const model = new rigModule.OriginalArticulatedRig();
    const visibleMeshes = model.apply(frame, 0.65);
    const Vector3 = model.root.position.constructor;
    const tip = model.nodes.left.attachedFore.localToWorld(new Vector3(0, 0.5, 0));

    const mirrored = pure.computeRigFrame({ ...base, mirrored: true, frameId: 2 });
    const legs = pure.computeRigFrame({ ...base, focus: "legs", frameId: 3 });
    const singleArm = pure.computeRigFrame({
      ...base,
      frameId: 4,
      landmarks: landmarks.map((point, index) =>
        index === 12 || index === 14 || index === 16
          ? { ...point, visibility: 0, presence: 0 } : point),
    });
    const shoulderless = pure.computeRigFrame({
      ...base,
      frameId: 5,
      landmarks: landmarks.map((point, index) =>
        index === 11 ? { ...point, visibility: 0, presence: 0 } : point),
    });
    const tracker = new pure.LiveRigTracker();
    const stale = tracker.update({ ...base, frameId: 6, nowMs: 5000 });
    const label: string = rigModule.ORIGINAL_RIG_LABEL;
    model.dispose();

    return {
      status: frame.status,
      segments: frame.visibleSegments,
      drawnMeshes: visibleMeshes,
      attached: frame.arms.left.fore.hierarchyAttached,
      parentRelative: frame.arms.left.fore.parentRelativeRadians,
      wrist: frame.arms.left.wrist,
      tip: { x: tip.x, y: tip.y },
      mirroredWristX: mirrored.arms.left.wrist.x,
      legsReasons: legs.reasons,
      singleArmSegments: singleArm.visibleSegments,
      singleArmStatus: singleArm.status,
      shoulderlessUpper: shoulderless.arms.left.upper,
      shoulderlessAttached: shoulderless.arms.left.fore.hierarchyAttached,
      staleReasons: stale.reasons,
      label,
    };
  }, NUMERICAL_FIXTURE);

  expect(result.status).toBe("tracking");
  expect(result.segments).toBe(4);
  expect(result.drawnMeshes).toBe(4);
  expect(result.attached).toBe(true);
  expect(result.parentRelative).not.toBeNull();
  // object-fit:cover with equal aspect ratios: 0.22*800 and 0.70*450.
  expect(result.wrist.x).toBeCloseTo(176, 6);
  expect(result.wrist.y).toBeCloseTo(315, 6);
  // The FOREARM is a CHILD of the upper-arm pivot: its world tip is the wrist.
  expect(result.tip.x).toBeCloseTo(result.wrist.x, 4);
  expect(result.tip.y).toBeCloseTo(result.wrist.y, 4);
  // Mirror reverses display-space x but does not swap anatomical sides.
  expect(result.mirroredWristX).toBeCloseTo(624, 6);
  // No invented leg chain, no invented hidden shoulder.
  expect(result.legsReasons).toContain("REGION_NOT_SUPPORTED");
  expect(result.singleArmSegments).toBe(2);
  expect(result.singleArmStatus).toBe("partial");
  expect(result.shoulderlessUpper).toBeNull();
  expect(result.shoulderlessAttached).toBe(false);
  expect(result.staleReasons).toContain("STALE_RESULT");
  expect(result.label).toContain("Uncalibrated");
});
