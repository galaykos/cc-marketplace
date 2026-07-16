// Golden-baseline orchestration (spec D8 / D16): ties the store, the `--update` guards,
// masked capture, and the pixel diff together, sourcing `mask` + `threshold` from the ONE
// resolved-config chain (config/loader.ts) — never duplicating precedence here.
//
//   --update  → guard (dirty tree, commit/PII ack) → capture EACH target with the config
//               mask painted out → write masked PNG to `.visual-check/baselines/<key>.png`.
//   --baseline→ capture EACH target with the SAME mask → diff vs the stored baseline; a
//               missing baseline for a requested key is `status:error` "run --update first",
//               never a silent pass.

// `@playwright/test` and `./capture.ts` are loaded LAZILY (dynamic import, inside the
// capture paths only) so pure orchestration — guards, mask resolution, store paths —
// is exercisable without the browser toolchain installed. The type import is erased.
import type { Browser } from '@playwright/test';
import { loadConfig, resolveEffectiveSettings, type Settings } from '../config/loader.ts';
import { captureKey } from '../scenario/schema.ts';
import { diffPng, passesThreshold, type DiffResult } from './diff.ts';
import { checkUpdateGuards, gitStatus, type GitStatus } from './guards.ts';
import { baselinePathForKey, hasBaseline, readBaseline, writeBaseline } from './store.ts';

/** Lazily load the masked-capture fn (pulls in Playwright only when we actually capture). */
async function loadCapture() {
  return (await import('./capture.ts')).captureWithBrowser;
}

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

/** The mask actually painted for a capture. An explicit `mask` from the caller — even
 * `[]`, which means "nothing to mask" — is honoured verbatim; when the caller OMITS it
 * (`undefined`) we resolve the config `mask` through the shared settings chain so a
 * committed baseline is NEVER blessed unmasked because a caller mis-wired the option
 * (guard 3, spec D16). `undefined` = "not told" (fall back to config); `[]` = "told,
 * nothing sensitive" — the two are kept distinct. */
export function resolveUpdateMask(baseDir: string, mask?: string[]): string[] {
  if (mask !== undefined) return mask;
  return resolveBaselineSettings(baseDir).mask;
}

type Common = {
  baseDir: string;
  targets: BaselineTarget[];
  mask?: string[];
  browser?: Browser; // reuse a caller's browser; otherwise one is launched + closed
};

async function withBrowser<T>(browser: Browser | undefined, fn: (b: Browser) => Promise<T>): Promise<T> {
  if (browser) return fn(browser);
  const { chromium } = await import('@playwright/test');
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
  if (o.targets.length === 0) {
    return { ok: false, reason: 'no targets to bless (empty target set)', warnings: guard.warnings, written: [] };
  }

  // Guard 3: ALWAYS resolve the effective mask from config when the caller omits it, so a
  // mis-wired/omitted `mask` can never bless an UNMASKED capture with rendered PII in it.
  const mask = resolveUpdateMask(o.baseDir, o.mask);
  const written: { key: string; path: string }[] = [];
  await withBrowser(o.browser, async (b) => {
    const captureWithBrowser = await loadCapture();
    for (const t of o.targets) {
      const png = await captureWithBrowser(b, { url: t.url, viewport: t.viewport, mask });
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
  if (o.targets.length === 0) {
    return { status: 'error', exitCode: 2, results: [] };
  }
  const mask = resolveUpdateMask(o.baseDir, o.mask);
  const results: DiffTargetResult[] = [];
  await withBrowser(o.browser, async (b) => {
    const captureWithBrowser = await loadCapture();
    for (const t of o.targets) {
      const key = captureKey(t.route, t.stepIndex, t.viewport.name);
      // One unreachable route / decode failure must not abort the whole batch: record it
      // as this target's error and keep going.
      try {
        if (!hasBaseline(o.baseDir, key)) {
          results.push({
            key,
            status: 'error',
            ratio: null,
            reason: `no baseline at ${baselinePathForKey(o.baseDir, key)} — run --update first`,
          });
          continue;
        }
        const actual = await captureWithBrowser(b, { url: t.url, viewport: t.viewport, mask });
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
      } catch (e) {
        results.push({ key, status: 'error', ratio: null, reason: `capture/diff failed: ${(e as Error).message}` });
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
