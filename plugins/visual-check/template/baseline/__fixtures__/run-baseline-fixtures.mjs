// Runtime demonstration of card 10 (golden baselines · --update guards · masking).
// Real Playwright, hermetic temp git repo, real PNG store. Exits non-zero if any
// assertion fails so it doubles as an integration check.
//
//   node baseline/__fixtures__/run-baseline-fixtures.mjs
//
// Proves, against the ticker fixture (a region whose text changes every load):
//   A. --update on a CLEAN tree WITHOUT ack        → refused (commit/PII ack guard)
//   B. --update on a CLEAN tree WITH ack           → masked baseline PNG written at
//                                                    the canonical __ key
//   C. --update on a DIRTY tree WITHOUT ack        → refused (dirty-tree guard)
//   D. --baseline with the config mask (ticker)    → PASS despite the ticker changing
//   E. --baseline WITHOUT the mask                 → FAIL (proves the mask is load-bearing)
//   F. --baseline for a key with no baseline       → error "run --update first"

import { execFileSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { chromium } from '@playwright/test';
import { resolveBaselineSettings, runBaselineDiff, runBaselineUpdate } from '../index.ts';
import { baselinePath, hasBaseline } from '../store.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const tickerUrl = pathToFileURL(path.join(here, 'ticker.html')).href;

let failures = 0;
function check(label, cond, detail = '') {
  const tag = cond ? 'PASS' : 'FAIL';
  if (!cond) failures++;
  process.stdout.write(`  [${tag}] ${label}${detail ? ' — ' + detail : ''}\n`);
}

function git(cwd, ...args) {
  return execFileSync('git', args, { cwd, encoding: 'utf8' });
}

function makeRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vc-baseline-'));
  git(dir, 'init', '-q');
  git(dir, 'config', 'user.email', 'test@example.com');
  git(dir, 'config', 'user.name', 'Test');
  git(dir, 'config', 'commit.gpgsign', 'false');
  // Consumer's committed config carries the mask selector for the dynamic ticker.
  fs.mkdirSync(path.join(dir, '.visual-check'), { recursive: true });
  fs.writeFileSync(
    path.join(dir, '.visual-check', 'config.json'),
    JSON.stringify({ threshold: 0.01, mask: ['[data-testid=ticker]'] }, null, 2) + '\n',
  );
  fs.writeFileSync(path.join(dir, 'README.md'), '# fixture repo\n');
  git(dir, 'add', '-A');
  git(dir, 'commit', '-q', '-m', 'init');
  return dir;
}

const VP = { name: 'desktop', width: 800, height: 600 };
const ROUTE = 'dashboard';

async function main() {
  const baseDir = makeRepo();
  const settings = resolveBaselineSettings(baseDir);
  process.stdout.write(`repo: ${baseDir}\nmask from config: ${JSON.stringify(settings.mask)} · threshold: ${settings.threshold}\n`);

  const target = { route: ROUTE, stepIndex: 0, viewport: VP, url: tickerUrl };
  const browser = await chromium.launch();
  try {
    // --- A. clean tree, NO ack → refused ------------------------------------
    process.stdout.write('\nA. --update clean tree, no ack:\n');
    const a = await runBaselineUpdate({ baseDir, targets: [target], mask: settings.mask, ackCommit: false, ackDirty: false, browser });
    check('refused', a.ok === false, a.reason);
    check('surfaced the commit/PII warning', a.warnings.some((w) => /COMMITTED TO GIT/.test(w)));
    check('nothing written', !hasBaseline(baseDir, `${ROUTE}__0__${VP.name}`));

    // --- B. clean tree, WITH ack → masked PNG written -----------------------
    process.stdout.write('\nB. --update clean tree, --ack-commit:\n');
    const b = await runBaselineUpdate({ baseDir, targets: [target], mask: settings.mask, ackCommit: true, ackDirty: false, browser });
    const blessedPath = baselinePath(baseDir, ROUTE, 0, VP.name);
    check('write accepted', b.ok === true, b.reason || '');
    check('baseline PNG exists at canonical __ key', fs.existsSync(blessedPath), path.relative(baseDir, blessedPath));
    check('PNG is a real image (>1KB, PNG magic)', fs.existsSync(blessedPath) && fs.statSync(blessedPath).size > 1024 && fs.readFileSync(blessedPath).slice(1, 4).toString() === 'PNG');

    // --- C. dirty tree, NO ack → refused ------------------------------------
    process.stdout.write('\nC. --update dirty tree, no --ack-dirty:\n');
    fs.writeFileSync(path.join(baseDir, 'WIP.txt'), 'uncommitted work\n');
    const c = await runBaselineUpdate({ baseDir, targets: [target], mask: settings.mask, ackCommit: true, ackDirty: false, browser });
    check('refused on dirty tree', c.ok === false, c.reason);
    check('reason cites the dirty tree', !!c.reason && /dirty git tree/.test(c.reason));

    // --- D. --baseline diff WITH mask → pass despite the ticker changing ----
    process.stdout.write('\nD. --baseline diff (ticker masked):\n');
    const d = await runBaselineDiff({ baseDir, targets: [target], mask: settings.mask, threshold: settings.threshold, browser });
    const dRes = d.results[0];
    check('overall pass', d.status === 'pass' && d.exitCode === 0, `status=${d.status} ratio=${dRes.ratio}`);
    check('masked ratio at/under threshold', dRes.ratio !== null && dRes.ratio <= settings.threshold, `ratio=${dRes.ratio}`);

    // --- E. --baseline diff WITHOUT mask → fail (mask is load-bearing) ------
    process.stdout.write('\nE. --baseline diff (no mask, control):\n');
    const e = await runBaselineDiff({ baseDir, targets: [target], mask: [], threshold: settings.threshold, browser });
    check('unmasked ticker DOES fail', e.status === 'fail' && e.exitCode === 1, `status=${e.status} ratio=${e.results[0].ratio}`);

    // --- F. missing baseline → error "run --update first" -------------------
    process.stdout.write('\nF. --baseline diff for an un-blessed key:\n');
    const missing = { route: ROUTE, stepIndex: 9, viewport: VP, url: tickerUrl };
    const f = await runBaselineDiff({ baseDir, targets: [missing], mask: settings.mask, threshold: settings.threshold, browser });
    check('status error (exit 2)', f.status === 'error' && f.exitCode === 2);
    check('reason says run --update first', /run --update first/.test(f.results[0].reason || ''));
  } finally {
    await browser.close();
  }

  process.stdout.write(`\n${failures === 0 ? 'ALL BASELINE FIXTURES PASSED' : failures + ' ASSERTION(S) FAILED'}\n`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  process.stderr.write(`fixture driver crashed: ${err && err.stack ? err.stack : err}\n`);
  process.exit(2);
});
