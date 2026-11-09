import { defineConfig, devices } from "@playwright/test";

/**
 * W2j/W2k browser integration only: original generated GLB, no camera,
 * no third-party Z-Anatomy/Google model assets or public deployment.
 * CI Linux WebKit emulates iPhone Safari viewport/touch and engine,
 * but is NOT genuine iOS hardware, Safari privacy, GPU, or thermal QA.
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
  },
  projects: [
    {
      name: "chromium-desktop",
      use: {
        ...devices["Desktop Chrome"],
        launchOptions: {
          args: [
            "--enable-webgl", "--use-gl=angle", "--use-angle=swiftshader",
            "--enable-unsafe-swiftshader",
          ],
        },
      },
    },
    {
      name: "webkit-iphone-emulation",
      use: {
        ...devices["iPhone 13"],
        browserName: "webkit",
      },
    },
  ],
  webServer: {
    command: "npm run dev -- --host 127.0.0.1",
    url: "http://127.0.0.1:5173",
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
