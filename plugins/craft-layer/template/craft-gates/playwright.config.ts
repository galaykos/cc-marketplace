// playwright.config.ts — runs craft-layer's gates.spec.ts from the plugin: `npx playwright test --config <plugin>/template/craft-gates/playwright.config.ts` (a bare `playwright test` finds no craft gate and exits 0 having run nothing). testDir is this directory; outputDir sits under the project's cwd, never inside the installed plugin.
// Misses: the dependencies — without NODE_PATH=<project>/node_modules, @playwright/test and @axe-core/playwright fail MODULE_NOT_FOUND; which build answers at BASE_URL (CRAFT_EXPECT_TITLE, in the spec).
// Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/template/craft-gates/playwright.config.ts
import { defineConfig } from '@playwright/test'
import { resolve } from 'node:path'

export default defineConfig({
  testDir: '.',
  testMatch: /gates\.spec\.ts$/,
  outputDir: resolve(process.cwd(), '.craft-layer/test-results'),
  reporter: [['list']],
})
