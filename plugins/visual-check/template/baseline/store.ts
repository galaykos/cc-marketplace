// Committed golden-baseline store (spec D8). Baselines live at
// `.visual-check/baselines/<route>__<stepIndex>__<viewport>.png` — the CANONICAL
// per-step capture key from card 05 (`schema.ts` captureKey), double-underscores
// preserved verbatim. We own the store filenames ourselves precisely because
// Playwright's snapshot writer sanitizes `__` → `-` on disk (card 07); the store
// therefore never routes through `toHaveScreenshot`, so the on-disk name equals the
// key that also rides in verdict.json `match.diffPath`.

import * as fs from 'node:fs';
import * as path from 'node:path';
import { captureKey } from '../scenario/schema.ts';

export const BASELINE_SUBDIR = path.join('.visual-check', 'baselines');

/** `<baseDir>/.visual-check/baselines` — the consumer-committed reference store. */
export function baselineDir(baseDir: string): string {
  return path.join(baseDir, BASELINE_SUBDIR);
}

/** On-disk baseline path for a canonical key string (`<route>__<stepIndex>__<viewport>`). */
export function baselinePathForKey(baseDir: string, key: string): string {
  return path.join(baselineDir(baseDir), `${key}.png`);
}

/** On-disk baseline path from the (route, stepIndex, viewport) triple. */
export function baselinePath(baseDir: string, route: string, stepIndex: number, viewport: string): string {
  return baselinePathForKey(baseDir, captureKey(route, stepIndex, viewport));
}

export function hasBaseline(baseDir: string, key: string): boolean {
  return fs.existsSync(baselinePathForKey(baseDir, key));
}

export function readBaseline(baseDir: string, key: string): Buffer {
  return fs.readFileSync(baselinePathForKey(baseDir, key));
}

/** Write a (already-masked) PNG buffer to the store, creating the dir as needed. */
export function writeBaseline(baseDir: string, key: string, png: Buffer): string {
  const p = baselinePathForKey(baseDir, key);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, png);
  return p;
}

/** List the canonical keys currently present in the store (basenames minus `.png`). */
export function listBaselines(baseDir: string): string[] {
  const dir = baselineDir(baseDir);
  if (!fs.existsSync(dir)) return [];
  return fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.png'))
    .map((f) => f.slice(0, -'.png'.length))
    .sort();
}
