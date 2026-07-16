import { test, expect } from '@playwright/test';
import * as path from 'path';

// Single-target scenario: goto → wait-for-stable → capture-and-diff per viewport.
// Runs once per project (viewport). The reporter turns per-project results into the
// frozen verdict.json and the runner maps that to the 0/1/2 exit contract.

const DEFAULT_FIXTURE = 'file://' + path.join(__dirname, '..', '__fixtures__', 'hello.html');
const TARGET_URL = process.env.VC_URL || DEFAULT_FIXTURE;
const STEP_TIMEOUT = Number(process.env.VC_STEP_TIMEOUT ?? '10000');

/**
 * wait-for-stable: settle the page so the capture is deterministic.
 * networkidle + font readiness + a short animation-settle beat.
 */
async function waitForStable(page: import('@playwright/test').Page): Promise<void> {
  try {
    await page.waitForLoadState('networkidle', { timeout: STEP_TIMEOUT });
  } catch {
    // networkidle is best-effort within the step budget; a busy long-poll page still
    // proceeds to capture rather than being misclassified as an infra error.
  }
  await page.evaluate(async () => {
    const d = document as unknown as { fonts?: { ready?: Promise<unknown> } };
    if (d.fonts?.ready) await d.fonts.ready;
  });
  await page.waitForTimeout(200); // animation-settle
}

test('visual-check target', async ({ page }) => {
  page.setDefaultTimeout(STEP_TIMEOUT);
  page.setDefaultNavigationTimeout(STEP_TIMEOUT);

  // A navigation failure (url unreachable, DNS, timeout) is an INFRA error → exit 2,
  // NOT a visual fail. Tag it so the reporter classifies it as status:error.
  try {
    await page.goto(TARGET_URL, { waitUntil: 'load', timeout: STEP_TIMEOUT });
  } catch (err) {
    const msg = err instanceof Error ? err.message.split('\n')[0] : String(err);
    throw new Error(`VC_INFRA goto failed: ${msg}`);
  }

  await waitForStable(page);

  // Playwright's native comparator (maxDiffPixelRatio configured in playwright.config.ts).
  await expect(page).toHaveScreenshot();
});
