// PNG decode shim. We reuse the `pngjs` build that ships INSIDE Playwright (the same
// decoder Playwright's own comparator uses) rather than adding a dependency the harness
// would otherwise not have. Resolution is defensive: a bare `pngjs` first (if a host ever
// hoists it), then Playwright's bundled export. A miss throws a clear, actionable error.

import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

export type DecodedPng = { width: number; height: number; data: Buffer | Uint8Array };
type PngInstance = { width: number; height: number; data: Buffer };
type PngCtor = new (o: { width: number; height: number }) => PngInstance;
type PngSync = { sync: { read(buf: Buffer): DecodedPng; write(png: PngInstance): Buffer } } & PngCtor;

/** Pick the usable sync codec from a required module. BOTH `pngjs` and Playwright's
 * `utilsBundle` expose it under `.PNG` — `pngjs`'s bare export is the MODULE NAMESPACE
 * `{ PNG }`, so returning it directly (the old bug) hands back an object whose `.sync`
 * is `undefined` and every decode/encode throws. Only accept `.PNG` when it actually
 * carries `.sync`; otherwise return null so resolution falls through to the next
 * candidate instead of caching a broken codec. */
export function pickPngSync(m: unknown): PngSync | null {
  const mod = m as { PNG?: PngSync } | null | undefined;
  if (mod && mod.PNG && mod.PNG.sync) return mod.PNG;
  return null;
}

function resolvePng(): PngSync {
  for (const id of ['pngjs', 'playwright-core/lib/utilsBundle']) {
    try {
      const picked = pickPngSync(require(id));
      if (picked) return picked;
    } catch {
      /* not resolvable in this host — try the next candidate */
    }
  }
  throw new Error(
    'visual-check: no PNG decoder available (expected pngjs, bundled with @playwright/test). ' +
      'Run `npm install` / `playwright install` in the harness template.',
  );
}

let cached: PngSync | null = null;

/** Decode a PNG buffer to `{ width, height, data }` (RGBA, 4 bytes/pixel). */
export function decodePng(buf: Buffer): DecodedPng {
  if (!cached) cached = resolvePng();
  return cached.sync.read(buf);
}

/** Encode a raw RGBA raster to a PNG buffer (used by tests to synthesize fixtures). */
export function encodeRgba(width: number, height: number, data: Buffer): Buffer {
  const expected = width * height * 4;
  if (data.length !== expected) {
    throw new Error(`encodeRgba: expected ${expected} bytes (${width}x${height} RGBA), got ${data.length}`);
  }
  if (!cached) cached = resolvePng();
  const png = new cached({ width, height });
  data.copy(png.data);
  return cached.sync.write(png);
}
