// Runtime driver for the THREE flag-reconciliation fixes wired into bin/visual-check.mjs.
// Real Playwright, real captures, real 0/1/2 exit contract. Exits non-zero if any assertion
// fails so it doubles as an integration check (mirrors baseline/__fixtures__/run-baseline-fixtures.mjs).
//
//   node bin/__fixtures__/run-cli-fixtures.mjs
//
// Proves, against the committed hello fixture:
//   1. --baseline single-target   → diffs the committed golden store; PASS when aligned,
//                                    status:error "run --update first" when the store is empty.
//   2. --viewport <name>          → runs ONLY the named viewport across the single-page,
//                                    baseline, and scenario paths; an unknown name errors.
//   3. --contract <spec>          → refused on the deterministic bin (exit 2, agent-only message).

import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const templateDir = path.resolve(here, '..', '..');
const binPath = path.join(templateDir, 'bin', 'visual-check.mjs');
const fixturesDir = path.join(templateDir, '__fixtures__');
const helloUrl = pathToFileURL(path.join(fixturesDir, 'hello.html')).href;
const againstBase = path.join(fixturesDir, 'hello'); // resolves to hello__desktop.png / hello__mobile.png
const scenarioFile = path.join(templateDir, 'scenario', '__fixtures__', 'viewport-smoke.yaml');

let failures = 0;
function check(label, cond, detail = '') {
  const tag = cond ? 'PASS' : 'FAIL';
  if (!cond) failures++;
  process.stdout.write(`  [${tag}] ${label}${detail ? ' — ' + detail : ''}\n`);
}

/** Invoke the bin, capture exit code + stderr, and read back the frozen verdict.json. */
function runBin(extra, { cwd = templateDir } = {}) {
  const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'vc-cli-out-'));
  const r = spawnSync('node', [binPath, ...extra, '--out', outDir], { cwd, encoding: 'utf8' });
  const stderr = r.stderr || '';
  let verdict = null;
  const m = /→\s*(\S+)/.exec(stderr);
  if (m) {
    const runDir = path.resolve(templateDir, m[1]);
    const vp = path.join(runDir, 'verdict.json');
    if (fs.existsSync(vp)) {
      try {
        verdict = JSON.parse(fs.readFileSync(vp, 'utf8'));
      } catch {
        /* leave null */
      }
    }
  }
  return { code: r.status, stdout: r.stdout || '', stderr, verdict };
}

function tmpProject() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'vc-cli-proj-'));
}

function viewportsOf(verdict) {
  return [...new Set((verdict?.steps ?? []).map((s) => s.match?.viewport))];
}

// --- 1. --baseline single-target ------------------------------------------------------
process.stdout.write('\n1. --baseline single-target (committed golden store):\n');

// 1a. Missing baseline (empty store) → status:error "run --update first".
const proj1 = tmpProject();
const miss = runBin(['--url', helloUrl, '--baseline', '--project', proj1]);
check('empty store errors (exit 2)', miss.code === 2, `code=${miss.code} status=${miss.verdict?.status}`);
check(
  'reason says run --update first',
  (miss.verdict?.reasons ?? []).some((r) => /run --update first/.test(r)),
  JSON.stringify(miss.verdict?.reasons ?? []),
);

// 1b. Bless the store, then diff it → PASS when aligned.
const proj2 = tmpProject();
const bless = runBin(['--url', helloUrl, '--baseline', '--update', '--ack-commit', '--project', proj2]);
check('--baseline --update blesses (exit 0)', bless.code === 0, `code=${bless.code} status=${bless.verdict?.status}`);
check(
  'golden PNGs written to the store',
  fs.existsSync(path.join(proj2, '.visual-check', 'baselines', 'hello__0__desktop.png')),
);
const diff = runBin(['--url', helloUrl, '--baseline', '--project', proj2]);
check('--baseline diff passes when aligned (exit 0)', diff.code === 0, `code=${diff.code} status=${diff.verdict?.status}`);

// --- 2. --viewport <name> -------------------------------------------------------------
process.stdout.write('\n2. --viewport filter (single-page · baseline · scenario):\n');

// 2a. Single-page path: --viewport desktop runs ONLY desktop.
const sp = runBin(['--url', helloUrl, '--against', againstBase, '--viewport', 'desktop']);
check('single-page desktop passes (exit 0)', sp.code === 0, `code=${sp.code}`);
check('single-page verdict has ONLY desktop', JSON.stringify(viewportsOf(sp.verdict)) === '["desktop"]', JSON.stringify(viewportsOf(sp.verdict)));

// 2b. Single-page unknown viewport → error clearly.
const spBad = runBin(['--url', helloUrl, '--against', againstBase, '--viewport', 'tablet']);
check('single-page unknown viewport errors (exit 2)', spBad.code === 2, `code=${spBad.code}`);
check('single-page unknown viewport reason is clear', /unknown --viewport 'tablet'/.test(spBad.stderr) || (spBad.verdict?.reasons ?? []).some((r) => /unknown --viewport 'tablet'/.test(r)));

// 2c. Baseline path honours --viewport (bless + diff only desktop).
const proj3 = tmpProject();
runBin(['--url', helloUrl, '--baseline', '--update', '--ack-commit', '--viewport', 'desktop', '--project', proj3]);
check('baseline bless wrote only desktop', fs.existsSync(path.join(proj3, '.visual-check', 'baselines', 'hello__0__desktop.png')) && !fs.existsSync(path.join(proj3, '.visual-check', 'baselines', 'hello__0__mobile.png')));
const blDesk = runBin(['--url', helloUrl, '--baseline', '--viewport', 'desktop', '--project', proj3]);
check('baseline verdict has ONLY desktop', JSON.stringify(viewportsOf(blDesk.verdict)) === '["desktop"]', JSON.stringify(viewportsOf(blDesk.verdict)));
const blBad = runBin(['--url', helloUrl, '--baseline', '--viewport', 'tablet', '--project', proj3]);
check('baseline unknown viewport errors (exit 2)', blBad.code === 2, `code=${blBad.code}`);

// 2d. Scenario path honours --viewport.
const sc = runBin(['--scenario', scenarioFile, '--url', helloUrl, '--viewport', 'desktop']);
check('scenario desktop-only passes (exit 0)', sc.code === 0, `code=${sc.code} status=${sc.verdict?.status}`);
check('scenario verdict has ONLY desktop', JSON.stringify(viewportsOf(sc.verdict)) === '["desktop"]', JSON.stringify(viewportsOf(sc.verdict)));
const scBad = runBin(['--scenario', scenarioFile, '--url', helloUrl, '--viewport', 'tablet']);
check('scenario unknown viewport errors (exit 2)', scBad.code === 2, `code=${scBad.code}`);
check('scenario unknown viewport reason is clear', /unknown --viewport 'tablet'/.test(scBad.stderr));

// --- 3. --contract <spec> -------------------------------------------------------------
process.stdout.write('\n3. --contract refused on the deterministic bin:\n');
const contract = runBin(['--url', helloUrl, '--against', againstBase, '--contract', 'criteria.txt']);
check('--contract exits 2', contract.code === 2, `code=${contract.code}`);
check('--contract message is agent-only', /contract is agent-engine only/.test(contract.stderr), contract.stderr.trim().split('\n').pop());

process.stdout.write(`\n${failures === 0 ? 'ALL CLI FIXTURES PASSED' : failures + ' ASSERTION(S) FAILED'}\n`);
process.exit(failures === 0 ? 0 : 1);
