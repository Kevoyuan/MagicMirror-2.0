import { defineConfig, devices } from "@playwright/test";

/**
 * W2j browser smoke: only the ORIGINAL code-generated GLB and offline
 * source-model angle timeline. No webcam, Google .task, actual Z-Anatomy
 * files, licensed model redistribution or browser camera permission.
 *
 * The CI Chromium software rasterizer executes real WebGL + GLTF
 * Exporter/Loader; it is NOT hardware iPhone Safari/Chrome acceptance.
 */
export default defineConfig({
  testDir: "./tests/browser",
  fullyParallel: false,
  workers: 1,
  timeout: 90_000,
  expect: { timeout: 25_000 },
  reporter: process.env.CI ? [["line"], ["html", {
    open: "never", outputFolder: "playwright-report",
  }]] : "list",
  use: {
    baseURL: "http://127.0.0.1:5173",
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    video: "off",
    ...devices["Desktop Chrome"],
    launchOptions: {
      args: [
        "--enable-webgl",
        "--use-gl=angle",
        "--use-angle=swiftshader",
        "--enable-unsafe-swiftshader",
      ],
    },
  },
  webServer: {
    command: "npm run dev -- --host 127.0.0.1",
    url: "http://127.0.0.1:5173",
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
