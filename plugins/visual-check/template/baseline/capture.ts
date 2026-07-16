// Playwright capture with PRE-CAPTURE masking (guard 3, spec D16). The config `mask`
// selectors are painted with a solid colour AT CAPTURE TIME via Playwright's native
// `screenshot({ mask })`, so a masked dynamic/sensitive region:
//   (a) never enters a committed baseline PNG — the pixels are gone before blessing, and
//   (b) is byte-identical between a baseline and a later capture (same paint colour),
//       so `diff.ts` sees zero difference there without any region bookkeeping.
// The SAME mask is applied for `--update` (write) and `--baseline` (diff); that shared
// paint is what makes diff-time masking fall out for free.

import { chromium, type Browser } from '@playwright/test';

export const MASK_COLOR = '#FF00FF';

export type CaptureOptions = {
  url: string;
  viewport: { width: number; height: number };
  mask?: string[];
  maskColor?: string;
  stepTimeoutMs?: number;
  waitForStable?: boolean;
};

async function waitForStable(page: import('@playwright/test').Page, timeout: number): Promise<void> {
  try {
    await page.waitForLoadState('networkidle', { timeout });
  } catch {
    /* best-effort — a chatty page must not block a capture */
  }
  try {
    await page.evaluate(async () => {
      const d = document;
      if (d.fonts && d.fonts.ready) await d.fonts.ready;
    });
  } catch {
    /* ignore */
  }
  await page.waitForTimeout(150); // animation-settle parity with the scenario flow
}

/** Capture one masked full-viewport PNG using an already-launched browser. */
export async function captureWithBrowser(browser: Browser, o: CaptureOptions): Promise<Buffer> {
  const timeout = o.stepTimeoutMs ?? 10_000;
  const context = await browser.newContext({ viewport: o.viewport, deviceScaleFactor: 1 });
  const page = await context.newPage();
  page.setDefaultTimeout(timeout);
  page.setDefaultNavigationTimeout(timeout);
  try {
    await page.goto(o.url, { waitUntil: 'load', timeout });
    if (o.waitForStable !== false) await waitForStable(page, timeout);
    const locators = (o.mask ?? []).map((s) => page.locator(s));
    return await page.screenshot({
      animations: 'disabled',
      caret: 'hide',
      scale: 'css',
      mask: locators,
      maskColor: o.maskColor ?? MASK_COLOR,
    });
  } finally {
    await context.close();
  }
}

/** Convenience: owns the browser lifecycle for a single capture. */
export async function capture(o: CaptureOptions): Promise<Buffer> {
  const browser = await chromium.launch();
  try {
    return await captureWithBrowser(browser, o);
  } finally {
    await browser.close();
  }
}
