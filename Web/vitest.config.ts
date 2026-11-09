import { defineConfig } from "vitest/config";

/**
 * Keep fast pure unit tests isolated from opt-in Playwright .spec.ts files.
 * Chromium E2E is run separately via npm run test:browser.
 */
export default defineConfig({
  test: {
    include: ["src/**/*.test.ts"],
  },
});
