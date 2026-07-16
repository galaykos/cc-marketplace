// Pixel diff between a stored baseline and a fresh capture. Because masked regions are
// painted the SAME solid colour in both images (see `capture.ts`), they compare equal
// and contribute nothing to the ratio — diff-time masking falls out with no per-region
// bookkeeping. A per-channel tolerance absorbs sub-pixel antialiasing noise; the ratio
// is (differing pixels / total pixels), compared against the resolved config threshold.

import { decodePng } from './png.ts';

export type DiffResult = {
  ratio: number; // differing pixels / total pixels (1 when dimensions differ)
  diffPixels: number;
  totalPixels: number;
  dimensionMismatch: boolean;
  baseline: { width: number; height: number };
  actual: { width: number; height: number };
};

/** Compare two PNG buffers. `tolerance` is the max per-channel delta (0-255) a pixel may
 * drift before it counts as different (default 3, to swallow AA jitter). */
export function diffPng(baselineBuf: Buffer, actualBuf: Buffer, tolerance = 3): DiffResult {
  const a = decodePng(baselineBuf);
  const b = decodePng(actualBuf);
  const baseline = { width: a.width, height: a.height };
  const actual = { width: b.width, height: b.height };

  if (a.width !== b.width || a.height !== b.height) {
    // A genuine layout shift, not a maskable dynamic region → maximally different.
    const totalPixels = Math.max(a.width * a.height, b.width * b.height);
    return { ratio: 1, diffPixels: totalPixels, totalPixels, dimensionMismatch: true, baseline, actual };
  }

  const da = a.data;
  const db = b.data;
  const totalPixels = a.width * a.height;
  let diffPixels = 0;
  for (let p = 0; p < totalPixels; p++) {
    const i = p * 4;
    if (
      Math.abs(da[i] - db[i]) > tolerance ||
      Math.abs(da[i + 1] - db[i + 1]) > tolerance ||
      Math.abs(da[i + 2] - db[i + 2]) > tolerance ||
      Math.abs(da[i + 3] - db[i + 3]) > tolerance
    ) {
      diffPixels++;
    }
  }
  return {
    ratio: totalPixels === 0 ? 0 : diffPixels / totalPixels,
    diffPixels,
    totalPixels,
    dimensionMismatch: false,
    baseline,
    actual,
  };
}

/** A capture passes when its diff ratio is at or below the resolved threshold. */
export function passesThreshold(result: DiffResult, threshold: number): boolean {
  return !result.dimensionMismatch && result.ratio <= threshold;
}
