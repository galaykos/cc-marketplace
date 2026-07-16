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

function resolvePng(): PngSync {
  try {
    return require('pngjs') as PngSync;
  } catch {
    /* fall through to Playwright's bundle */
  }
  try {
    const bundle = require('playwright-core/lib/utilsBundle') as { PNG?: PngSync };
    if (bundle && bundle.PNG && bundle.PNG.sync) return bundle.PNG;
  } catch {
    /* fall through to error */
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
  if (!cached) cached = resolvePng();
  const png = new cached({ width, height });
  data.copy(png.data);
  return cached.sync.write(png);
}
