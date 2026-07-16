import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { baselineDir, baselinePath, baselinePathForKey, hasBaseline, listBaselines, writeBaseline, BaselineKeyError } from './store.ts';
import { checkUpdateGuards, gitStatus, type GitRunner } from './guards.ts';
import { diffPng, passesThreshold } from './diff.ts';
import { encodeRgba, pickPngSync } from './png.ts';
import { resolveUpdateMask } from './index.ts';

function tmpDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'vc-baseline-unit-'));
}

// The pixel-diff tests below round-trip a real PNG (encode/decode), which needs the
// `pngjs`/Playwright-bundled codec — absent in a bare, node_modules-free checkout. They
// stay full-strength but SKIP when no codec is resolvable; the central run (with deps)
// executes them. Pure-logic guards/store/mask/png-resolution tests never gate on this.
const CODEC_AVAILABLE = (() => {
  try {
    encodeRgba(1, 1, Buffer.alloc(4));
    return true;
  } catch {
    return false;
  }
})();
const needsCodec = CODEC_AVAILABLE ? false : 'no PNG codec (needs node_modules — deferred to central run)';

/** Tiny in-memory RGBA → PNG for hermetic diff tests (bg fill + optional rect). */
function tinyPng(
  w: number,
  h: number,
  bg: [number, number, number, number],
  rect?: { x: number; y: number; w: number; h: number; rgba: [number, number, number, number] },
): Buffer {
  const data = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = (y * w + x) * 4;
      const inRect = rect && x >= rect.x && x < rect.x + rect.w && y >= rect.y && y < rect.y + rect.h;
      const c = inRect ? rect.rgba : bg;
      data[i] = c[0];
      data[i + 1] = c[1];
      data[i + 2] = c[2];
      data[i + 3] = c[3];
    }
  }
  return encodeRgba(w, h, data);
}

// --- store: canonical __ key preserved on disk (NOT Playwright-sanitized to -) ------
test('store paths use the canonical <route>__<stepIndex>__<viewport>.png key verbatim', () => {
  const base = '/proj';
  assert.equal(baselineDir(base), path.join('/proj', '.visual-check', 'baselines'));
  assert.equal(baselinePath(base, 'home', 0, 'desktop'), path.join('/proj', '.visual-check', 'baselines', 'home__0__desktop.png'));
  assert.equal(baselinePathForKey(base, 'home__2__mobile'), path.join('/proj', '.visual-check', 'baselines', 'home__2__mobile.png'));
});

test('writeBaseline creates the store dir, hasBaseline + listBaselines observe it', () => {
  const dir = tmpDir();
  assert.equal(hasBaseline(dir, 'r__0__desktop'), false);
  assert.deepEqual(listBaselines(dir), []);
  const p = writeBaseline(dir, 'r__0__desktop', Buffer.from('not-really-a-png'));
  assert.ok(fs.existsSync(p));
  assert.equal(hasBaseline(dir, 'r__0__desktop'), true);
  assert.deepEqual(listBaselines(dir), ['r__0__desktop']);
});

// --- guards 1 + 2 (dirty tree, commit/PII ack) --------------------------------------
test('guard refuses a dirty tree without --ack-dirty', () => {
  const r = checkUpdateGuards({ git: { available: true, clean: false, dirty: ['?? x'] }, ackCommit: true, ackDirty: false });
  assert.equal(r.ok, false);
  assert.match(r.reason ?? '', /dirty git tree/);
  assert.ok(r.warnings.some((w) => /COMMITTED TO GIT/.test(w)), 'commit/PII warning always surfaced');
});

test('guard refuses a clean tree without --ack-commit (PII/commit ack required)', () => {
  const r = checkUpdateGuards({ git: { available: true, clean: true, dirty: [] }, ackCommit: false, ackDirty: false });
  assert.equal(r.ok, false);
  assert.match(r.reason ?? '', /--ack-commit/);
});

test('guard allows a clean tree with --ack-commit, and a dirty tree with both acks', () => {
  assert.equal(checkUpdateGuards({ git: { available: true, clean: true, dirty: [] }, ackCommit: true, ackDirty: false }).ok, true);
  assert.equal(checkUpdateGuards({ git: { available: true, clean: false, dirty: ['?? x'] }, ackCommit: true, ackDirty: true }).ok, true);
});

test('a non-repo baseDir reports available:false so only the commit ack gates', () => {
  const notRepo: GitRunner = () => ({ status: 128, stdout: '' });
  const st = gitStatus('/whatever', notRepo);
  assert.deepEqual(st, { available: false, clean: true, dirty: [] });
  assert.equal(checkUpdateGuards({ git: st, ackCommit: false, ackDirty: false }).ok, false);
  assert.equal(checkUpdateGuards({ git: st, ackCommit: true, ackDirty: false }).ok, true);
});

test('gitStatus parses porcelain output into a dirty list via the injected runner', () => {
  const fake: GitRunner = (args) => {
    if (args[0] === 'rev-parse') return { status: 0, stdout: 'true\n' };
    return { status: 0, stdout: ' M a.ts\n?? b.ts\n' };
  };
  const st = gitStatus('/repo', fake);
  assert.equal(st.available, true);
  assert.equal(st.clean, false);
  assert.deepEqual(st.dirty, [' M a.ts', '?? b.ts']);
});

// --- diff: identical → 0, masked-equal region excluded, dimension shift → fail ------
test('diffPng: identical buffers → ratio 0 and passes any threshold', { skip: needsCodec }, () => {
  const a = tinyPng(4, 4, [10, 20, 30, 255]);
  const r = diffPng(a, Buffer.from(a));
  assert.equal(r.diffPixels, 0);
  assert.equal(r.ratio, 0);
  assert.equal(passesThreshold(r, 0), true);
});

test('diffPng: differing pixels raise the ratio; threshold gates pass/fail', { skip: needsCodec }, () => {
  const a = tinyPng(10, 10, [0, 0, 0, 255]);
  const b = tinyPng(10, 10, [0, 0, 0, 255], { x: 0, y: 0, w: 5, h: 10, rgba: [255, 255, 255, 255] });
  const r = diffPng(a, b);
  assert.equal(r.totalPixels, 100);
  assert.equal(r.diffPixels, 50);
  assert.equal(r.ratio, 0.5);
  assert.equal(passesThreshold(r, 0.01), false);
  assert.equal(passesThreshold(r, 0.6), true);
});

test('diffPng: a masked-equal region (identical paint) contributes nothing to the ratio', { skip: needsCodec }, () => {
  const a = tinyPng(10, 10, [0, 0, 0, 255], { x: 0, y: 0, w: 10, h: 5, rgba: [255, 0, 255, 255] });
  const b = tinyPng(10, 10, [0, 0, 0, 255], { x: 0, y: 0, w: 10, h: 5, rgba: [255, 0, 255, 255] });
  assert.equal(diffPng(a, b).diffPixels, 0);
});

test('diffPng: a dimension change is a maximal, non-passing diff', { skip: needsCodec }, () => {
  const a = tinyPng(4, 4, [0, 0, 0, 255]);
  const b = tinyPng(8, 4, [0, 0, 0, 255]);
  const r = diffPng(a, b);
  assert.equal(r.dimensionMismatch, true);
  assert.equal(r.ratio, 1);
  assert.equal(passesThreshold(r, 0.99), false);
});

// --- #4 dirty guard fails CLOSED on a git-status error (confirmed work tree) ----------
test('gitStatus fails CLOSED: a confirmed work tree whose `git status` errors is dirty/unknown', () => {
  // rev-parse confirms IT IS a work tree, but `git status --porcelain` fails (index lock,
  // perms). We must NOT report clean — that would skip the dirty guard and let --update
  // proceed on an unverified tree (fail-OPEN). Treat as dirty/unknown → --ack-dirty required.
  const brokenStatus: GitRunner = (args) =>
    args[0] === 'rev-parse' ? { status: 0, stdout: 'true\n' } : { status: 128, stdout: '' };
  const st = gitStatus('/repo', brokenStatus);
  assert.equal(st.available, true, 'still a work tree');
  assert.equal(st.clean, false, 'cannot prove clean → treated as dirty');
  assert.deepEqual(st.dirty, ['<status unavailable>']);
  // fail-closed: --update is refused without --ack-dirty, and honoured with it.
  assert.equal(checkUpdateGuards({ git: st, ackCommit: true, ackDirty: false }).ok, false);
  assert.equal(checkUpdateGuards({ git: st, ackCommit: true, ackDirty: true }).ok, true);
});

// --- #2 store path-traversal rejection (defense-in-depth, second layer after schema) --
test('baselinePathForKey rejects traversal / separator keys but keeps canonical keys', () => {
  assert.throws(() => baselinePathForKey('/proj', '../evil'), BaselineKeyError);
  assert.throws(() => baselinePathForKey('/proj', 'a/b'), BaselineKeyError);
  assert.throws(() => baselinePathForKey('/proj', 'a\\b'), BaselineKeyError);
  assert.throws(() => baselinePathForKey('/proj', '..'), BaselineKeyError);
  assert.throws(() => baselinePathForKey('/proj', ''), BaselineKeyError);
  assert.throws(() => baselinePathForKey('/proj', '..%2fsneaky/../x'), BaselineKeyError);
  // a legit canonical key still resolves inside the store, unchanged
  assert.equal(
    baselinePathForKey('/proj', 'home__0__desktop'),
    path.join('/proj', '.visual-check', 'baselines', 'home__0__desktop.png'),
  );
  // has/read/write share the chokepoint, so a poisoned key is rejected there too
  assert.throws(() => hasBaseline('/proj', '../../etc/passwd'), BaselineKeyError);
  assert.throws(() => writeBaseline(tmpDir(), 'x/../../y', Buffer.from('p')), BaselineKeyError);
});

// --- #5 runBaselineUpdate resolves the mask from config when the caller omits it -------
test('resolveUpdateMask honours an explicit mask and falls back to config when omitted', () => {
  const dir = tmpDir();
  // no config + omitted → default empty mask (safe: nothing to paint, but resolved not blind)
  assert.deepEqual(resolveUpdateMask(dir, undefined), []);
  // an EXPLICIT empty mask means "told: nothing sensitive" — honoured verbatim
  assert.deepEqual(resolveUpdateMask(dir, []), []);
  // explicit selectors honoured verbatim
  assert.deepEqual(resolveUpdateMask(dir, ['.token']), ['.token']);
  // OMITTED (undefined) now resolves the config mask — the guard-3 fix: a mis-wired caller
  // can no longer bless an UNMASKED capture of a PII region.
  fs.mkdirSync(path.join(dir, '.visual-check'), { recursive: true });
  fs.writeFileSync(
    path.join(dir, '.visual-check', 'config.json'),
    JSON.stringify({ mask: ['.pii', '[data-secret]'] }),
  );
  assert.deepEqual(resolveUpdateMask(dir, undefined), ['.pii', '[data-secret]']);
  // an explicit [] still overrides config (told: nothing) — distinct from undefined
  assert.deepEqual(resolveUpdateMask(dir, []), []);
});

// --- #6 png resolver reaches THROUGH the pngjs module namespace to the .PNG codec -----
test('pickPngSync returns .PNG (which carries .sync), not the bare module namespace', () => {
  const codec = { sync: { read: () => ({}), write: () => Buffer.alloc(0) } };
  // pngjs' bare `require('pngjs')` is the NAMESPACE { PNG } — returning it directly (old
  // bug) yields `.sync === undefined`. The fix reaches through `.PNG`.
  assert.equal(pickPngSync({ PNG: codec }), codec);
  // a namespace whose .PNG lacks .sync is unusable → null so resolution falls through
  assert.equal(pickPngSync({ PNG: {} }), null);
  assert.equal(pickPngSync({}), null);
  assert.equal(pickPngSync(null), null);
  assert.equal(pickPngSync(undefined), null);
});
