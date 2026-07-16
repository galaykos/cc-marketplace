// Category 3 — layout-integrity heuristics (spec D11.3).
// Reference-free breakage detection: horizontal overflow/scroll, a zero-size or
// blank/white render, and an obvious overlap/z-index collision over the asserted
// region. The DOM snapshot is gathered in the browser; the verdict is a PURE
// function of that snapshot so it is unit-testable without a browser.

import type { Page } from '@playwright/test';

export type LayoutRegion = { found: boolean; width: number; height: number; covered: boolean };
export type LayoutSnapshot = {
  scrollWidth: number;
  innerWidth: number;
  bodyText: string;
  imageCount: number;
  mediaCount: number;
  regionSelector: string | null;
  region: LayoutRegion | null;
};

/** Turn a layout snapshot into findings. Pure — no browser, no IO. */
export function evaluateLayout(s: LayoutSnapshot): string[] {
  const findings: string[] = [];

  // Horizontal overflow: content wider than the viewport (1px slack for rounding).
  // Compare against window.innerWidth, which INCLUDES the vertical scrollbar —
  // documentElement.clientWidth excludes it, so a full-width (100vw) element would
  // read as ~15px of phantom overflow on any page that has a scrollbar.
  if (s.scrollWidth > s.innerWidth + 1) {
    findings.push(`horizontal overflow: content ${s.scrollWidth}px wider than viewport ${s.innerWidth}px`);
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

  // Empty DOM: no rendered content in the DOM tree — no text, no <img>, and no
  // canvas/svg/video. This is NOT a pixel-level "blank render" check: an app that
  // paints via canvas/svg/video/background-image can have an empty text tree yet a
  // full screen, and a white-screen-full-of-text has text. The claim is scoped to
  // exactly what the DOM snapshot proves, so it can't false-positive those apps.
  if (s.bodyText.trim() === '' && s.imageCount === 0 && s.mediaCount === 0) {
    findings.push('empty DOM: no text, no images, no canvas/svg/video');
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
      innerWidth: window.innerWidth,
      bodyText: body ? body.innerText : '',
      imageCount: document.images.length,
      mediaCount: document.querySelectorAll('canvas, svg, video').length,
      regionSelector: sel,
      region,
    };
  }, regionSelector ?? null)) as LayoutSnapshot;
  return evaluateLayout(snap);
}
