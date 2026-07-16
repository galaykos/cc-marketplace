// Golden-baseline orchestration (spec D8 / D16): ties the store, the `--update` guards,
// masked capture, and the pixel diff together, sourcing `mask` + `threshold` from the ONE
// resolved-config chain (config/loader.ts) — never duplicating precedence here.
//
//   --update  → guard (dirty tree, commit/PII ack) → capture EACH target with the config
//               mask painted out → write masked PNG to `.visual-check/baselines/<key>.png`.
//   --baseline→ capture EACH target with the SAME mask → diff vs the stored baseline; a
//               missing baseline for a requested key is `status:error` "run --update first",
//               never a silent pass.

import type { Browser } from '@playwright/test';
import { chromium } from '@playwright/test';
import { loadConfig, resolveEffectiveSettings, type Settings } from '../config/loader.ts';
import { captureKey } from '../scenario/schema.ts';
import { captureWithBrowser } from './capture.ts';
import { diffPng, passesThreshold, type DiffResult } from './diff.ts';
import { checkUpdateGuards, gitStatus, type GitStatus } from './guards.ts';
import { baselinePathForKey, hasBaseline, readBaseline, writeBaseline } from './store.ts';

export type BaselineTarget = {
  route: string;
  stepIndex: number;
  viewport: { name: string; width: number; height: number };
  url: string;
};

/** Resolve mask/threshold/viewports for `baseDir` through the shared config chain. */
export function resolveBaselineSettings(baseDir: string, cliThreshold?: number): Settings {
  const cfg = loadConfig(baseDir);
  const cli = cliThreshold !== undefined ? { threshold: cliThreshold } : {};
  return resolveEffectiveSettings({ config: cfg.override, cli });
}

type Common = {
  baseDir: string;
  targets: BaselineTarget[];
  mask?: string[];
  browser?: Browser; // reuse a caller's browser; otherwise one is launched + closed
};

async function withBrowser<T>(browser: Browser | undefined, fn: (b: Browser) => Promise<T>): Promise<T> {
  if (browser) return fn(browser);
  const b = await chromium.launch();
  try {
    return await fn(b);
  } finally {
    await b.close();
  }
}

export type UpdateResult = {
  ok: boolean;
  reason?: string;
  warnings: string[];
  written: { key: string; path: string }[];
};

/** Bless baselines. Runs guards 1+2 FIRST (nothing is captured or written on refusal),
 * then captures every target with the config mask painted out (guard 3) and writes it. */
export async function runBaselineUpdate(
  o: Common & { ackCommit: boolean; ackDirty: boolean; git?: GitStatus },
): Promise<UpdateResult> {
  const git = o.git ?? gitStatus(o.baseDir);
  const guard = checkUpdateGuards({ git, ackCommit: o.ackCommit, ackDirty: o.ackDirty });
  if (!guard.ok) return { ok: false, reason: guard.reason, warnings: guard.warnings, written: [] };

  const written: { key: string; path: string }[] = [];
  await withBrowser(o.browser, async (b) => {
    for (const t of o.targets) {
      const png = await captureWithBrowser(b, { url: t.url, viewport: t.viewport, mask: o.mask });
      const key = captureKey(t.route, t.stepIndex, t.viewport.name);
      const p = writeBaseline(o.baseDir, key, png);
      written.push({ key, path: p });
    }
  });
  return { ok: true, warnings: guard.warnings, written };
}

export type DiffTargetResult = {
  key: string;
  status: 'pass' | 'fail' | 'error';
  ratio: number | null;
  reason?: string;
  diff?: DiffResult;
};

export type DiffRunResult = {
  status: 'pass' | 'fail' | 'error';
  exitCode: 0 | 1 | 2;
  results: DiffTargetResult[];
};

/** Diff current captures against the committed store. Missing baseline → error (exit 2,
 * "run --update first"); a ratio over threshold → fail (exit 1); otherwise pass. Masked
 * regions never contribute (identical paint in both images). */
export async function runBaselineDiff(o: Common & { threshold: number }): Promise<DiffRunResult> {
  const results: DiffTargetResult[] = [];
  await withBrowser(o.browser, async (b) => {
    for (const t of o.targets) {
      const key = captureKey(t.route, t.stepIndex, t.viewport.name);
      if (!hasBaseline(o.baseDir, key)) {
        results.push({
          key,
          status: 'error',
          ratio: null,
          reason: `no baseline at ${baselinePathForKey(o.baseDir, key)} — run --update first`,
        });
        continue;
      }
      const actual = await captureWithBrowser(b, { url: t.url, viewport: t.viewport, mask: o.mask });
      const result = diffPng(readBaseline(o.baseDir, key), actual);
      if (passesThreshold(result, o.threshold)) {
        results.push({ key, status: 'pass', ratio: result.ratio, diff: result });
      } else {
        results.push({
          key,
          status: 'fail',
          ratio: result.ratio,
          diff: result,
          reason: result.dimensionMismatch
            ? `dimension mismatch (baseline ${result.baseline.width}x${result.baseline.height} vs ${result.actual.width}x${result.actual.height})`
            : `pixel ratio ${result.ratio.toFixed(4)} exceeds threshold ${o.threshold}`,
        });
      }
    }
  });

  const sawError = results.some((r) => r.status === 'error');
  const sawFail = results.some((r) => r.status === 'fail');
  const status: DiffRunResult['status'] = sawError ? 'error' : sawFail ? 'fail' : 'pass';
  const exitCode: DiffRunResult['exitCode'] = sawError ? 2 : sawFail ? 1 : 0;
  return { status, exitCode, results };
}

export { gitStatus } from './guards.ts';
export { baselineDir, baselinePath, baselinePathForKey, hasBaseline } from './store.ts';
