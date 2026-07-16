import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseScenario } from './schema.ts';
import { compileSpec, compileConfig, assembleVerdict, runScenarioCli, type StepResult } from './compile.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = (name: string): string => fs.readFileSync(path.join(here, '__fixtures__', name), 'utf8');
const emptyAsserts = () => ({ dom: [] as string[], console: [], layout: [], network: [] });

test('compileSpec embeds a toHaveScreenshot key <route>__<stepIndex>__<viewport> for every match step', () => {
  const scn = parseScenario(fixture('sidebar.valid.yaml'));
  const src = compileSpec(scn, { baseUrl: 'file:///tmp/sidebar.html', stepTimeoutMs: 10000, stepsDir: '/tmp/steps' });

  // The key is computed at runtime as ROUTE + '__' + i + '__' + vp; assert the pieces + verbs are present.
  assert.match(src, /toHaveScreenshot\(snap/);
  assert.match(src, /ROUTE \+ '__' \+ i \+ '__' \+ vp/);
  assert.ok(src.includes('"i":0,"verb":"goto"'), 'step 0 goto compiled');
  assert.ok(src.includes('"i":1,"verb":"click"'), 'step 1 click compiled');
  assert.ok(src.includes('"i":2,"verb":"hover"'), 'step 2 hover compiled');
  assert.ok(src.includes('"i":3,"verb":"click"'), 'step 3 click compiled');
  // Match steps flagged; the hover step (no match) is not.
  assert.ok(src.includes('"i":1,"verb":"click","target":"[data-testid=sidebar-toggle]","action":"click [data-testid=sidebar-toggle]","value":"","dom":[{"selector":"nav.sidebar","state":"visible"}],"match":true'));
  assert.ok(src.includes('"i":3') && src.includes('"selector":"nav.sidebar","state":"hidden"'), 'close step carries hidden dom assert');
});

test('compileConfig maps scenario viewports to Playwright projects and keys the snapshot path', () => {
  const scn = parseScenario(fixture('sidebar.valid.yaml'));
  const cfg = compileConfig({
    specFile: '/gen/run.spec.ts', viewports: scn.viewports, threshold: 0.02,
    stepTimeoutMs: 10000, scenarioTimeoutMs: 120000, baselineDir: '/base', outputDir: '/out',
  });
  assert.ok(cfg.includes('"name":"desktop"') && cfg.includes('"width":1280'), 'desktop project');
  assert.ok(cfg.includes('"name":"mobile"') && cfg.includes('"width":390'), 'mobile project');
  assert.ok(cfg.includes('maxDiffPixelRatio: 0.02'), 'threshold flows to comparator');
  assert.ok(cfg.includes('/base/{arg}{ext}'), 'snapshot path template keyed by {arg}');
  assert.ok(cfg.includes('timeout: 120000'), 'per-scenario ceiling');
});

test('assembleVerdict produces one entry per (step x viewport) with correct keys, status pass', () => {
  const scn = parseScenario(fixture('sidebar.valid.yaml'));
  const mk = (i: number, key: string): StepResult => ({
    i, action: `step ${i}`, key, status: 'pass', reasons: [], asserts: emptyAsserts(), match: { ratio: 0, diffPath: `${key}.png` },
  });
  const results: Record<string, StepResult[]> = {
    desktop: scn.steps.map((s) => mk(s.stepIndex, `sidebar-toggle__${s.stepIndex}__desktop`)),
    mobile: scn.steps.map((s) => mk(s.stepIndex, `sidebar-toggle__${s.stepIndex}__mobile`)),
  };
  const v = assembleVerdict({
    scenario: 'sidebar-toggle', route: 'sidebar-toggle', viewports: ['desktop', 'mobile'],
    steps: scn.steps.map((s) => ({ i: s.stepIndex, action: s.action })), resultsByViewport: results,
    runDirDisplay: '.visual-check/results/x/',
  });

  assert.equal(v.status, 'pass');
  assert.equal(v.exitCode, 0);
  assert.equal(v.steps.length, 8, '4 steps x 2 viewports');
  // ids are <route>__<stepIndex>; the 3-part capture key rides in match.diffPath.
  assert.equal(v.steps[0].id, 'sidebar-toggle__0');
  assert.equal(v.steps[0].match.viewport, 'desktop');
  assert.equal(v.steps[0].match.diffPath, 'sidebar-toggle__0__desktop.png');
  const mobileStep1 = v.steps.find((s) => s.id === 'sidebar-toggle__1' && s.match.viewport === 'mobile');
  assert.ok(mobileStep1 && mobileStep1.match.diffPath === 'sidebar-toggle__1__mobile.png');
});

test('a step that times out on a missing element rolls up to status:error / exit 2 (never fail)', () => {
  const results: Record<string, StepResult[]> = {
    desktop: [
      { i: 0, action: 'goto /', key: 'timeout-demo__0__desktop', status: 'pass', reasons: [], asserts: emptyAsserts(), match: { ratio: 0, diffPath: '' } },
      { i: 1, action: 'wait #never', key: 'timeout-demo__1__desktop', status: 'error', reasons: ['desktop: wait could not drive → Timeout 2000ms exceeded'], asserts: emptyAsserts(), match: { ratio: null, diffPath: '' } },
    ],
  };
  const v = assembleVerdict({
    scenario: 'timeout-demo', route: 'timeout-demo', viewports: ['desktop'],
    steps: [{ i: 0, action: 'goto /' }, { i: 1, action: 'wait #never' }], resultsByViewport: results,
    runDirDisplay: '.visual-check/results/x/',
  });
  assert.equal(v.status, 'error');
  assert.equal(v.exitCode, 2);
  assert.notEqual(v.status, 'fail');
  assert.ok(v.reasons.some((r) => /could not drive/.test(r)));
});

test('an expect failure rolls up to status:fail / exit 1 (UI is wrong, not a tooling error)', () => {
  const results: Record<string, StepResult[]> = {
    desktop: [
      { i: 0, action: 'click', key: 'k0', status: 'fail', reasons: ['desktop: expect failed (nav.sidebar expected visible)'],
        asserts: { dom: ['nav.sidebar expected visible'], console: [], layout: [], network: [] }, match: { ratio: null, diffPath: '' } },
    ],
  };
  const v = assembleVerdict({
    scenario: 's', route: 's', viewports: ['desktop'], steps: [{ i: 0, action: 'click' }],
    resultsByViewport: results, runDirDisplay: 'x/',
  });
  assert.equal(v.status, 'fail');
  assert.equal(v.exitCode, 1);
  assert.deepEqual(v.steps[0].asserts.dom, ['nav.sidebar expected visible']);
});

test('a missing sidecar (scenario-level timeout / crash) is error, not a silent pass', () => {
  const v = assembleVerdict({
    scenario: 's', route: 's', viewports: ['desktop'], steps: [{ i: 0, action: 'goto' }, { i: 1, action: 'click' }],
    resultsByViewport: {}, runDirDisplay: 'x/',
  });
  assert.equal(v.status, 'error');
  assert.equal(v.exitCode, 2);
  assert.equal(v.steps.length, 2, 'all steps still enumerated');
  assert.equal(v.steps[0].pass, false);
});

// --- #8: a bad --threshold is refused before Playwright is ever spawned ------
test('runScenarioCli rejects a NaN or out-of-[0,1] --threshold up front', () => {
  assert.throws(() => runScenarioCli({ threshold: 'abc' }), /--threshold must be a number in \[0, 1\]/);
  assert.throws(() => runScenarioCli({ threshold: '5' }), /--threshold must be a number in \[0, 1\]/);
  assert.throws(() => runScenarioCli({ threshold: '-0.1' }), /--threshold must be a number in \[0, 1\]/);
});

// --- Generated-spec structure: static proof of the runtime-behavior fixes ----
// These assert the compiled Playwright source is wired correctly. The RUNTIME
// behaviour (a real Playwright throw, network drain timing, layout measurement)
// needs a browser to prove end-to-end and is flagged for the central browser run.
test('[browser-flagged] the assert phase is wrapped so a thrown helper still writes the sidecar (#10)', () => {
  const scn = parseScenario(fixture('sidebar.valid.yaml'));
  const src = compileSpec(scn, { baseUrl: 'file:///tmp/sidebar.html', stepTimeoutMs: 10000, stepsDir: '/tmp/steps' });
  assert.match(src, /assert phase threw/, 'assert phase has a catch that records a per-step error');
  // The catch continues the loop, so the per-viewport sidecar write is still reached.
  assert.match(src, /fs\.writeFileSync\(path\.join\(STEPS_DIR/);
});

test('[browser-flagged] non-goto steps settle the network before draining it (#11)', () => {
  const scn = parseScenario(fixture('sidebar.valid.yaml'));
  const src = compileSpec(scn, { baseUrl: 'file:///tmp/sidebar.html', stepTimeoutMs: 10000, stepsDir: '/tmp/steps' });
  assert.match(src, /step\.verb !== 'goto'\) await waitForStable\(page\);\s*\n\s*const nr = await checkNetwork/);
});

test('[browser-flagged] layout region is derived from a present dom assert, never a hidden one (#12)', () => {
  const scn = parseScenario(fixture('sidebar.valid.yaml'));
  const src = compileSpec(scn, { baseUrl: 'file:///tmp/sidebar.html', stepTimeoutMs: 10000, stepsDir: '/tmp/steps' });
  assert.ok(!src.includes('checkLayout(page, step.dom[0] ? step.dom[0].selector : null)'), 'no longer keys layout off dom[0] blindly');
  assert.match(src, /step\.dom\.find\(\(d\) => d\.state !== 'hidden'/);
});
