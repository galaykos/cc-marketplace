import { defineConfig } from '@playwright/test';
import * as path from 'path';

// The deterministic single-target harness. The runner (bin/visual-check.mjs) drives
// this config through env vars so the SAME config serves both the wrapper's 0/1/2 exit
// contract and a bare `npx playwright test` self-test against the shipped fixture.

const FIXTURES = path.join(__dirname, '__fixtures__');

// Per-viewport reference lookup. `--against <base>` resolves to `<base>__<projectName>.png`.
// Bare `npx playwright test` falls back to the hello fixture so the harness is self-testing.
const SNAPSHOT_TEMPLATE =
  process.env.VC_SNAPSHOT_TEMPLATE || path.join(FIXTURES, 'hello__{projectName}.png');

const MAX_DIFF_PIXEL_RATIO = Number(process.env.VC_MAX_DIFF_RATIO ?? '0.01');
const SCENARIO_TIMEOUT_MS = 120_000; // per-scenario hard ceiling → timeout maps to exit 2
const STEP_TIMEOUT_MS = Number(process.env.VC_STEP_TIMEOUT ?? '10000'); // per-step budget

// Results land in a run-unique dir so concurrent runs never collide.
const RUN_DIR = process.env.VC_RUN_DIR;

export default defineConfig({
  testDir: path.join(__dirname, 'tests'),
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: true,
  timeout: SCENARIO_TIMEOUT_MS,
  outputDir: RUN_DIR ? path.join(RUN_DIR, 'pw-output') : path.join(__dirname, 'test-results'),
  snapshotPathTemplate: SNAPSHOT_TEMPLATE,
  reporter: [['line'], ['./reporter/verdict-reporter.ts']],
  expect: {
    timeout: 15_000,
    toHaveScreenshot: {
      maxDiffPixelRatio: MAX_DIFF_PIXEL_RATIO,
      animations: 'disabled',
      caret: 'hide',
      scale: 'css',
    },
  },
  use: {
    headless: true,
    actionTimeout: STEP_TIMEOUT_MS,
    navigationTimeout: STEP_TIMEOUT_MS,
  },
  projects: [
    {
      name: 'desktop',
      use: { browserName: 'chromium', viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 },
    },
    {
      name: 'mobile',
      use: { browserName: 'chromium', viewport: { width: 375, height: 812 }, deviceScaleFactor: 1 },
    },
  ],
});
