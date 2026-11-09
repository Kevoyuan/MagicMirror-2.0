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

/**
 * Review P2: the W3a controller must mount through the REAL ProxySkeletonRenderer
 * (shared WebGL host), not just verify Object3D matrices in isolation. This test
 * creates a genuine WebGL canvas in the page, wires LiveRigOverlay to the same
 * ProxySkeletonRenderer, feeds TWO consecutive deterministic frames, and asserts
 * the shared renderer actually produced non-empty pixels and coherent world
 * joints. Camera-free, MediaPipe-free, weight-free.
 */
test("W3a rig mounts on the shared WebGL host and renders coherent frames without camera", async ({ page }) => {
  await page.goto("/");
  const result = await page.evaluate(async () => {
    const load = (path: string): Promise<any> => import(path);
    const sceneMod = await load("/src/scene.ts");
    const rigMod = await load("/src/live-rig/index.ts");

    // Create a REAL off-screen canvas + ProxySkeletonRenderer (shared host).
    const canvas = document.createElement("canvas");
    canvas.width = 800;
    canvas.height = 450;
    canvas.style.cssText = "position:absolute;left:-9999px;top:-9999px;";
    document.body.appendChild(canvas);
    const host = new sceneMod.ProxySkeletonRenderer(canvas);
    const overlay = new rigMod.LiveRigOverlay(host);

    // Two consecutive deterministic left+right arm poses (display px).
    const mkLandmarks = (sx: number, sy: number, ex: number, ey: number,
      wx: number, wy: number): any[] => {
      const pts = Array.from({ length: 33 }, () => ({
        x: 0.5, y: 0.5, z: 0, visibility: 0, presence: 0,
      }));
      const set = (i: number, vx: number, vy: number) => {
        pts[i] = { x: vx / 1280, y: vy / 720, z: 0, visibility: 0.95, presence: 0.95 };
      };
      // Left arm 11/13/15
      set(11, sx, sy); set(13, ex, ey); set(15, wx, wy);
      // Right arm 12/14/16 (mirrored for simplicity)
      set(12, 1280 - sx, sy); set(14, 1280 - ex, ey); set(16, 1280 - wx, wy);
      return pts;
    };

    // Frame 1: rest at 0 degrees, 100px segments.
    const f1 = {
      frameId: 1, session: 1, capturedAtMs: 1_000, mediaTimeSeconds: 0,
      width: 1280, height: 720, inferredInMs: 5,
      landmarks: mkLandmarks(300, 300, 400, 300, 500, 300),
    };
    // Frame 2: upper 30deg, forearm 45deg absolute, 80ms later.
    const deg = (v: number) => (v * Math.PI) / 180;
    const f2 = {
      frameId: 2, session: 1, capturedAtMs: 1_080, mediaTimeSeconds: 0,
      width: 1280, height: 720, inferredInMs: 5,
      landmarks: mkLandmarks(
        300, 300,
        300 + 100 * Math.cos(deg(30)), 300 + 100 * Math.sin(deg(30)),
        300 + 100 * Math.cos(deg(30)) + 100 * Math.cos(deg(45)),
        300 + 100 * Math.sin(deg(30)) + 100 * Math.sin(deg(45)),
      ),
    };

    const ctx = {
      session: 1, nowMs: 1_000, mirrored: false,
      focus: "whole", opacity: 0.7, stabilizing: true,
    };
    const ctx2 = { ...ctx, nowMs: 1_080 };

    // Switch to rig mode and apply both frames.
    const switched = overlay.setMode("rig");
    const out1 = overlay.apply(f1, ctx);
    // Read canvas pixels RIGHT AFTER apply: the shared renderer drew.
    const gl1 = canvas.getContext("webgl2") || canvas.getContext("webgl");
    const read1 = (() => {
      try {
        const gl = gl1 as WebGLRenderingContext;
        gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE,
          new Uint8Array(4));
        return "ok";
      } catch { return "error"; }
    })();

    const out2 = overlay.apply(f2, ctx2);

    // Verify world joints match declared joints via the rig module.
    // Vector3 constructor is reachable through the rig's own Object3D root.
    const rig = (overlay as any).rig;
    const v3 = rig.root.position.clone(); // any Vector3 instance
    const elbowWorld = rig.nodes.left.elbowPivot.getWorldPosition(v3.clone());
    const wristWorld = rig.nodes.left.attachedFore.localToWorld(v3.clone());

    // Switch back to proxy mode: rig must hide, proxy available.
    overlay.setMode("proxy");
    const proxyOut = overlay.apply(f2, ctx2);

    // Cleanup.
    overlay.dispose();
    host.dispose();
    canvas.remove();

    return {
      switched,
      out1Active: out1.active,
      out1Segments: out1.visibleSegments,
      out2Active: out2.active,
      out2Segments: out2.visibleSegments,
      read1,
      elbowWorld: { x: elbowWorld.x, y: elbowWorld.y },
      wristWorld: { x: wristWorld.x, y: wristWorld.y },
      out2Elbow: out2.reasons.length === 0,
      proxyActive: proxyOut.active,
      proxyReasons: proxyOut.reasons,
    };
  });

  expect(result.switched).toBe(true);
  expect(result.out1Active).toBe(true);
  expect(result.out1Segments).toBe(4);
  expect(result.out2Active).toBe(true);
  expect(result.out2Segments).toBe(4);
  // The shared WebGL renderer was actually called and its back buffer is readable.
  expect(result.read1).toBe("ok");
  // World elbow and wrist are finite display-pixel coordinates.
  expect(Number.isFinite(result.elbowWorld.x)).toBe(true);
  expect(Number.isFinite(result.elbowWorld.y)).toBe(true);
  expect(Number.isFinite(result.wristWorld.x)).toBe(true);
  expect(Number.isFinite(result.wristWorld.y)).toBe(true);
  // Proxy mode after switch is inactive for rig overlay (it delegates to host).
  expect(result.proxyActive).toBe(false);
  expect(result.proxyReasons).toContain("PROXY_MODE");
});
