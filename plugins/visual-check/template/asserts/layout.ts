// Category 3 — layout-integrity heuristics (spec D11.3).
// Reference-free breakage detection: horizontal overflow/scroll, a zero-size or
// blank/white render, and an obvious overlap/z-index collision over the asserted
// region. The DOM snapshot is gathered in the browser; the verdict is a PURE
// function of that snapshot so it is unit-testable without a browser.

import type { Page } from '@playwright/test';

export type LayoutRegion = { found: boolean; width: number; height: number; covered: boolean };
export type LayoutSnapshot = {
  scrollWidth: number;
  clientWidth: number;
  bodyText: string;
  imageCount: number;
  regionSelector: string | null;
  region: LayoutRegion | null;
};

/** Turn a layout snapshot into findings. Pure — no browser, no IO. */
export function evaluateLayout(s: LayoutSnapshot): string[] {
  const findings: string[] = [];

  // Horizontal overflow: content wider than the viewport (1px slack for rounding).
  if (s.scrollWidth > s.clientWidth + 1) {
    findings.push(`horizontal overflow: content ${s.scrollWidth}px wider than viewport ${s.clientWidth}px`);
  }

  if (s.region) {
    const sel = s.regionSelector || 'region';
    if (!s.region.found) {
      findings.push(`layout region ${sel} not found`);
    } else {
      if (s.region.width === 0 || s.region.height === 0) {
        findings.push(`zero-size render on ${sel} (${s.region.width}x${s.region.height})`);
      }
      if (s.region.covered) {
        findings.push(`overlap: ${sel} is obscured by a higher-stacking element`);
      }
    }
  }

  // Blank/white render: nothing painted (no visible text, no images).
  if (s.bodyText.trim() === '' && s.imageCount === 0) {
    findings.push('blank render: body has no visible text or images');
  }

  return findings;
}

/** Gather a layout snapshot from the live page, then evaluate it. */
export async function checkLayout(page: Page, regionSelector?: string | null): Promise<string[]> {
  const snap = (await page.evaluate((sel: string | null): LayoutSnapshot => {
    const de = document.documentElement;
    const body = document.body;
    let region: LayoutRegion | null = null;
    if (sel) {
      const el = document.querySelector(sel);
      if (!el) {
        region = { found: false, width: 0, height: 0, covered: false };
      } else {
        const r = el.getBoundingClientRect();
        let covered = false;
        if (r.width > 0 && r.height > 0) {
          const cx = r.left + r.width / 2;
          const cy = r.top + r.height / 2;
          const top = document.elementFromPoint(cx, cy);
          // Obscured only if a DIFFERENT, non-descendant/non-ancestor element
          // paints over the region's centre — avoids flagging inner content.
          covered = !!top && top !== el && !el.contains(top) && !top.contains(el);
        }
        region = { found: true, width: Math.round(r.width), height: Math.round(r.height), covered };
      }
    }
    return {
      scrollWidth: de.scrollWidth,
      clientWidth: de.clientWidth,
      bodyText: body ? body.innerText : '',
      imageCount: document.images.length,
      regionSelector: sel,
      region,
    };
  }, regionSelector ?? null)) as LayoutSnapshot;
  return evaluateLayout(snap);
}
