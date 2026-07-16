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

/** Thrown when a baseline key would escape the store (path traversal). */
export class BaselineKeyError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BaselineKeyError';
  }
}

/** Defense-in-depth against a poisoned key (the scenario schema already sanitizes ids,
 * this is the SECOND layer): a canonical key is a single flat filename fragment — reject
 * anything carrying a path separator, a `..` traversal, an empty string, or a NUL before
 * it is ever joined onto the store dir. */
function assertSafeKey(key: string): void {
  if (
    key === '' ||
    key.includes('/') ||
    key.includes('\\') ||
    key.includes('..') ||
    key.includes('\0') ||
    key.includes(path.sep)
  ) {
    throw new BaselineKeyError(`unsafe baseline key '${key}' (path separators / traversal not allowed)`);
  }
}

/** On-disk baseline path for a canonical key string (`<route>__<stepIndex>__<viewport>`).
 * Rejects any key that would resolve outside `.visual-check/baselines` (belt: string
 * check on the key; suspenders: the resolved path must stay under the store root). */
export function baselinePathForKey(baseDir: string, key: string): string {
  assertSafeKey(key);
  const dir = baselineDir(baseDir);
  const full = path.join(dir, `${key}.png`);
  const root = path.resolve(dir) + path.sep;
  if (!(path.resolve(full) + path.sep).startsWith(root)) {
    throw new BaselineKeyError(`baseline key '${key}' escapes the store at ${dir}`);
  }
  return full;
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
