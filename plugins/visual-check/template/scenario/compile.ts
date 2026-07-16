// Compile a validated scenario (card 05 `schema.ts`) into an EPHEMERAL Playwright
// `.spec.ts`, run it, and merge the per-step results into the FROZEN verdict.json
// (card 03). The generated spec + its config live under `.visual-check/generated/`
// (gitignored) and are never committed.
//
// Verb → Playwright mapping (spec D-mapping):
//   goto  → page.goto              click → page.click        type  → page.fill
//   hover → page.hover             wait  → wait-for-stable (no target) OR
//                                          page.waitForSelector (with a target)
//   expect→ web-first assertions (toBeVisible / toBeHidden)
//   match → toHaveScreenshot keyed `<route>__<stepIndex>__<viewport>`
//
// Selector / timeout semantics:
//   - action verb (goto/click/type/hover/wait-target) that cannot drive the page
//     (missing element, unreachable url, per-step timeout) → `error` → exit 2.
//   - `expect` on a missing/wrong element → `fail` (the UI is wrong) → exit 1.
//   - `match` mismatch → `fail`; a missing baseline (cannot compare) → `error`.
// This card wires the mapping + the merge; the four assert categories' full logic
// (console/layout/network) is deepened in card 07, masking in card 10.

import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseScenario, type Scenario, type SettingsOverride, type Step, type Viewport } from './schema.ts';
import { loadConfig } from '../config/loader.ts';
import type { YamlValue } from './yaml.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const templateDir = path.resolve(here, '..');

const DEFAULT_STEP_TIMEOUT_MS = 10_000; // per-step budget (spec D20)
const DEFAULT_SCENARIO_TIMEOUT_MS = 120_000; // per-scenario ceiling (spec D20)

// --- Frozen verdict.json shape (card 03 / engines.md) -----------------------
type Asserts = { dom: string[]; console: string[]; layout: string[]; network: string[] };
type Match = { viewport: string; ratio: number | null; diffPath: string; reasons: string[] };
type VerdictStep = { id: string; action: string; asserts: Asserts; match: Match; pass: boolean };
export type Verdict = {
  status: 'pass' | 'fail' | 'error';
  engine: 'playwright';
  exitCode: 0 | 1 | 2;
  scenario: string;
  steps: VerdictStep[];
  reasons: string[];
  runDir: string;
};

// --- Per-step result the generated spec writes to a sidecar -------------------
export type StepStatus = 'pass' | 'fail' | 'error' | 'skipped';
export type StepResult = {
  i: number;
  action: string;
  key: string;
  status: StepStatus;
  reasons: string[];
  asserts: Asserts;
  match: { ratio: number | null; diffPath: string };
};

function emptyAsserts(): Asserts {
  return { dom: [], console: [], layout: [], network: [] };
}

function isObject(v: YamlValue): v is { [k: string]: YamlValue } {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

/** Pull the `{selector, state, text?}` dom assertions off a step's `expect` block. */
function domAsserts(step: Step): { selector: string; state: string; text?: string }[] {
  const dom = step.expect?.dom;
  if (!Array.isArray(dom)) return [];
  return dom.filter(isObject).map((d) => {
    const selector = String(d.selector ?? '');
    const state = String(d.state ?? 'visible');
    // `text` is optional; omit the key when absent so existing captures are byte-identical.
    return typeof d.text === 'string' && d.text !== ''
      ? { selector, state, text: d.text }
      : { selector, state };
  });
}

/** A step "requests" a non-DOM category when its `expect` block carries that key. */
function requests(step: Step, key: 'console' | 'layout' | 'network'): boolean {
  const v = step.expect?.[key];
  return v !== undefined && v !== null && v !== false;
}

function normalizeUrl(u: string): string {
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(u)) return u; // already has a scheme
  if (u === 'about:blank') return u;
  return 'file://' + path.resolve(process.cwd(), u);
}

function displayRunDir(runDir: string): string {
  const rel = path.relative(templateDir, runDir);
  let d = rel && !rel.startsWith('..') && !path.isAbsolute(rel) ? rel : runDir;
  if (!d.endsWith('/')) d += '/';
  return d;
}

// The compact per-step descriptor embedded in the generated spec. Field order is
// load-bearing (compile.test.ts asserts on the serialized prefix); new category
// request flags are appended AFTER `match`.
type CompiledStep = {
  i: number;
  verb: Step['verb'];
  target: string | null;
  action: string;
  value: string;
  dom: { selector: string; state: string; text?: string }[];
  match: boolean;
  console: boolean;
  layout: boolean;
  network: boolean;
};

function compileSteps(scenario: Scenario): CompiledStep[] {
  return scenario.steps.map((s) => ({
    i: s.stepIndex,
    verb: s.verb,
    target: s.target,
    action: s.action,
    value: s.text ?? '', // `type` input text — from the dedicated `text` field, never `label`
    dom: domAsserts(s),
    match: s.match !== null,
    console: requests(s, 'console'),
    layout: requests(s, 'layout'),
    network: requests(s, 'network'),
  }));
}

/**
 * Generate the ephemeral Playwright spec source. Pure: no IO. It embeds the
 * scenario as JSON literals and drives it step-by-step, writing a per-viewport
 * sidecar (`<viewport>.json`) of {@link StepResult}s the orchestrator merges.
 */
export function compileSpec(
  scenario: Scenario,
  o: { baseUrl: string; stepTimeoutMs: number; stepsDir: string; assertsImport?: string },
): string {
  const route = scenario.id;
  const steps = compileSteps(scenario);
  // Import base for the four assert-category modules, resolved by Playwright's
  // loader relative to the generated spec's dir (default matches the real layout:
  // .visual-check/generated/<run>.spec.ts → ../../asserts/*). Extensionless so
  // Playwright's TS resolver picks up the `.ts` source.
  const A = (o.assertsImport ?? '../../asserts').replace(/\\/g, '/').replace(/\/$/, '');
  return `import { test, expect } from '@playwright/test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { checkDom } from '${A}/dom';
import { captureConsole } from '${A}/console';
import { checkLayout } from '${A}/layout';
import { captureNetwork, checkNetwork } from '${A}/network';

// GENERATED — ephemeral, do not edit or commit (see .visual-check/ .gitignore).
const ROUTE = ${JSON.stringify(route)};
const BASE_URL = ${JSON.stringify(o.baseUrl)};
const STEP_TIMEOUT = ${o.stepTimeoutMs};
const STEPS_DIR = ${JSON.stringify(o.stepsDir)};
const STEPS = ${JSON.stringify(steps)};

const keyFor = (i, vp) => ROUTE + '__' + i + '__' + vp;
const firstLine = (s) => String(s || '').split('\\n').map((x) => x.trim()).filter(Boolean)[0] || 'unknown error';
const parseRatio = (s) => {
  const m = /ratio\\s+(\\d*\\.?\\d+)/i.exec(String(s || ''));
  if (m) return Number(m[1]);
  const p = /(\\d*\\.?\\d+)\\s*%\\s*of all image pixels/i.exec(String(s || ''));
  return p ? Number(p[1]) / 100 : null;
};
const resolveGoto = (target) => {
  if (!target || target === '/') return BASE_URL;
  if (/^[a-z][a-z0-9+.-]*:\\/\\//i.test(target)) return target;
  try { return new URL(target, BASE_URL).href; } catch { return BASE_URL; }
};
async function waitForStable(page) {
  try { await page.waitForLoadState('networkidle', { timeout: STEP_TIMEOUT }); } catch { /* best-effort */ }
  await page.evaluate(async () => { const d = document; if (d.fonts && d.fonts.ready) await d.fonts.ready; });
  await page.waitForTimeout(150); // animation-settle
}

test('scenario ' + ROUTE, async ({ page }, testInfo) => {
  const vp = testInfo.project.name;
  page.setDefaultTimeout(STEP_TIMEOUT);
  page.setDefaultNavigationTimeout(STEP_TIMEOUT);
  const results = [];
  let halted = false;

  // Category 2 + 4 capture is page-level and cumulative — attach ONCE before
  // driving so nothing that fires during the flow is missed; per-step drains
  // attribute each finding to the step whose action provoked it.
  const consoleCap = captureConsole(page);
  const netCap = captureNetwork(page);

  for (const step of STEPS) {
    const key = keyFor(step.i, vp);
    const base = { i: step.i, action: step.action, key, reasons: [],
      asserts: { dom: [], console: [], layout: [], network: [] }, match: { ratio: null, diffPath: '' } };
    if (halted) { results.push({ ...base, status: 'skipped', reasons: ['skipped: a prior step errored'] }); continue; }

    // --- action phase: driving the page; a failure means we CANNOT drive → error.
    try {
      switch (step.verb) {
        case 'goto': await page.goto(resolveGoto(step.target), { waitUntil: 'load', timeout: STEP_TIMEOUT }); await waitForStable(page); break;
        case 'click': await page.click(step.target, { timeout: STEP_TIMEOUT }); break;
        case 'type': await page.fill(step.target, step.value, { timeout: STEP_TIMEOUT }); break;
        case 'hover': await page.hover(step.target, { timeout: STEP_TIMEOUT }); break;
        case 'wait':
          if (step.target) await page.waitForSelector(step.target, { timeout: STEP_TIMEOUT });
          else await waitForStable(page);
          break;
      }
    } catch (err) {
      results.push({ ...base, status: 'error', reasons: [vp + ': ' + step.verb + ' could not drive → ' + firstLine(err && err.message)] });
      halted = true;
      continue;
    }

    // --- assert phase: the four "not broken" categories. Only requested ones run;
    // unrequested stay []. A category with findings makes the step fail; a network
    // INFRA failure (server died) is error, not fail. The whole phase is wrapped: a
    // THROWN helper (a real Playwright error) marks THIS step error and still lets the
    // loop reach the per-viewport sidecar write below — otherwise the throw would abort
    // the test and every step, including already-passed ones, would read "not reached".
    const asserts = { dom: [], console: [], layout: [], network: [] };
    const infra = [];
    try {
      if (step.dom.length) asserts.dom = await checkDom(page, expect, step.dom, STEP_TIMEOUT);
      if (step.console) asserts.console = consoleCap.drain();
      if (step.layout) {
        // Derive the layout region only from a dom assert that expects the element
        // PRESENT. A step asserting it hidden/absent must not drive a bogus
        // "region not found" / zero-size layout finding.
        const region = step.dom.find((d) => d.state !== 'hidden' && d.state !== 'absent' && d.state !== 'detached');
        asserts.layout = await checkLayout(page, region ? region.selector : null);
      }
      if (step.network) {
        // Non-goto actions (click/type/hover) drain immediately, so a request the
        // action provoked may not have emitted yet — settle the network first so its
        // failure is attributed to THIS step (goto already settled in the action phase).
        if (step.verb !== 'goto') await waitForStable(page);
        const nr = await checkNetwork(page, netCap.drain());
        asserts.network = nr.findings;
        for (const m of nr.infra) infra.push(m);
      }
    } catch (err) {
      results.push({ ...base, status: 'error', asserts, reasons: [vp + ': assert phase threw → ' + firstLine(err && err.message)] });
      halted = true;
      continue;
    }

    if (infra.length) {
      results.push({ ...base, status: 'error', asserts, reasons: infra.map((m) => vp + ': ' + m) });
      halted = true;
      continue;
    }
    const findings = [...asserts.dom, ...asserts.console, ...asserts.layout, ...asserts.network];
    if (findings.length) {
      results.push({ ...base, status: 'fail', asserts, reasons: [vp + ': assert failed (' + findings.join('; ') + ')'] });
      continue;
    }

    // --- match phase: toHaveScreenshot keyed <route>__<stepIndex>__<viewport>.
    if (step.match) {
      const snap = key + '.png';
      try {
        await expect(page).toHaveScreenshot(snap, { timeout: STEP_TIMEOUT });
        results.push({ ...base, status: 'pass', asserts, match: { ratio: 0, diffPath: snap } });
      } catch (err) {
        const raw = String(err && err.message);
        if (/doesn't exist|does not exist|writing actual|no snapshot/i.test(raw)) {
          results.push({ ...base, status: 'error', asserts, reasons: [vp + ': missing baseline ' + snap] });
          halted = true;
        } else {
          results.push({ ...base, status: 'fail', asserts, match: { ratio: parseRatio(raw), diffPath: key + '.diff.png' },
            reasons: [vp + ': screenshot mismatch (' + firstLine(raw) + ')'] });
        }
      }
      continue;
    }

    results.push({ ...base, status: 'pass', asserts });
  }

  fs.mkdirSync(STEPS_DIR, { recursive: true });
  fs.writeFileSync(path.join(STEPS_DIR, vp + '.json'), JSON.stringify(results));
});
`;
}

/** Generate the ephemeral Playwright config that runs a single generated spec. */
export function compileConfig(o: {
  specFile: string;
  viewports: Viewport[];
  threshold: number;
  stepTimeoutMs: number;
  scenarioTimeoutMs: number;
  baselineDir: string;
  outputDir: string;
}): string {
  const projects = o.viewports.map((v) => ({ name: v.name, use: { viewport: { width: v.width, height: v.height } } }));
  return `import { defineConfig } from '@playwright/test';
// GENERATED — ephemeral, do not edit or commit.
export default defineConfig({
  testDir: ${JSON.stringify(path.dirname(o.specFile))},
  testMatch: ${JSON.stringify(path.basename(o.specFile))},
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: ${o.scenarioTimeoutMs},
  outputDir: ${JSON.stringify(o.outputDir)},
  snapshotPathTemplate: ${JSON.stringify(path.join(o.baselineDir, '{arg}{ext}'))},
  reporter: [['line']],
  expect: {
    timeout: ${o.stepTimeoutMs},
    toHaveScreenshot: { maxDiffPixelRatio: ${o.threshold}, animations: 'disabled', caret: 'hide', scale: 'css' },
  },
  use: { headless: true, actionTimeout: ${o.stepTimeoutMs}, navigationTimeout: ${o.stepTimeoutMs} },
  projects: ${JSON.stringify(projects)},
});
`;
}

/**
 * Merge per-viewport {@link StepResult} sidecars into the FROZEN verdict schema.
 * Pure: no IO. One verdict step per (scenario step × viewport); `match.viewport`
 * carries the viewport and `match.diffPath` carries the `<route>__<stepIndex>__<viewport>`
 * capture key. Timeout / drive-failures roll up to status `error` (exit 2), never `fail`.
 */
export function assembleVerdict(a: {
  scenario: string;
  route: string;
  viewports: string[];
  steps: { i: number; action: string }[];
  resultsByViewport: Record<string, StepResult[]>;
  runDirDisplay: string;
  launchError?: string | null;
}): Verdict {
  const steps: VerdictStep[] = [];
  const reasons: string[] = [];
  let sawError = false;
  let sawFail = false;

  if (a.launchError) {
    sawError = true;
    reasons.push(`playwright launch failed: ${a.launchError}`);
  }

  for (const vp of a.viewports) {
    const present = vp in a.resultsByViewport;
    const byIndex = new Map((a.resultsByViewport[vp] ?? []).map((r) => [r.i, r]));

    for (const st of a.steps) {
      const r = byIndex.get(st.i);
      let pass = false;
      let stReasons: string[];
      let asserts = emptyAsserts();
      let ratio: number | null = null;
      let diffPath = '';

      if (!r) {
        // Sidecar missing entirely (scenario-level timeout / crash) or step unreached.
        sawError = true;
        stReasons = [present ? `${vp}: step ${st.i} not reached` : `${vp}: scenario did not complete (timeout or crash)`];
      } else if (r.status === 'pass') {
        pass = true;
        stReasons = [];
        asserts = r.asserts ?? emptyAsserts();
        ratio = r.match?.ratio ?? 0;
        diffPath = r.match?.diffPath ?? '';
      } else if (r.status === 'error') {
        sawError = true;
        stReasons = r.reasons ?? [];
        asserts = r.asserts ?? emptyAsserts();
      } else if (r.status === 'fail') {
        sawFail = true;
        stReasons = r.reasons ?? [];
        asserts = r.asserts ?? emptyAsserts();
        ratio = r.match?.ratio ?? null;
        diffPath = r.match?.diffPath ?? '';
      } else {
        // 'skipped' — a prior step in this viewport already errored (sawError set there).
        stReasons = r.reasons ?? [];
      }

      reasons.push(...stReasons);
      steps.push({
        id: `${a.route}__${st.i}`,
        action: st.action,
        asserts,
        match: { viewport: vp, ratio, diffPath, reasons: stReasons },
        pass,
      });
    }
  }

  const status: Verdict['status'] = sawError ? 'error' : sawFail ? 'fail' : 'pass';
  const exitCode: Verdict['exitCode'] = sawError ? 2 : sawFail ? 1 : 0;

  return {
    status,
    engine: 'playwright',
    exitCode,
    scenario: a.scenario,
    steps,
    reasons,
    runDir: a.runDirDisplay,
  };
}

export type RunOptions = {
  scenarioFile: string;
  urlOverride?: string;
  stepTimeoutMs?: number;
  scenarioTimeoutMs?: number;
  update?: boolean;
  thresholdOverride?: number;
  viewportFilter?: string; // --viewport <name>: narrow the resolved viewports to this one
};

export type RunResult = {
  verdict: Verdict;
  exitCode: number;
  scenario: Scenario;
  specPath: string;
  configPath: string;
  verdictPath: string;
  runDir: string;
};

/**
 * Orchestrate a scenario run: parse → write the ephemeral spec + config under
 * `.visual-check/generated/` → `npx playwright test` → merge sidecars into
 * verdict.json under `.visual-check/results/<run>/`. Returns the verdict + paths.
 */
export function runScenario(o: RunOptions): RunResult {
  // Settings (threshold / viewports / mask) flow through the ONE precedence chain
  // (spec D18): CLI flag > scenario file > .visual-check/config.json > built-in
  // default. Config is discovered from the consumer's project cwd; the CLI layer
  // carries any --threshold override. No more hardcoded defaults live here.
  const config = loadConfig(process.cwd());
  const cli: SettingsOverride = {};
  if (o.thresholdOverride !== undefined) cli.threshold = o.thresholdOverride;
  const scenario = parseScenario(fs.readFileSync(o.scenarioFile, 'utf8'), { config: config.override, cli });

  // --viewport <name>: narrow the resolved viewports to just the named one (unknown name →
  // clear error, surfaced by the bin as exit 2). Applied after the precedence chain resolved
  // scenario.viewports, so the filter honours config/scenario overrides.
  if (o.viewportFilter !== undefined) {
    const filtered = scenario.viewports.filter((v) => v.name === o.viewportFilter);
    if (filtered.length === 0) {
      throw new Error(
        `unknown --viewport '${o.viewportFilter}' — configured viewports: ${scenario.viewports.map((v) => v.name).join(', ')}`,
      );
    }
    scenario.viewports = filtered;
  }

  const run = `${process.pid}-${randomUUID()}`;
  const generatedDir = path.join(templateDir, '.visual-check', 'generated');
  const runDir = path.join(templateDir, '.visual-check', 'results', run);
  const stepsDir = path.join(runDir, 'steps');
  const baselineDir = path.join(runDir, 'baselines');
  fs.mkdirSync(generatedDir, { recursive: true });
  fs.mkdirSync(stepsDir, { recursive: true });
  fs.mkdirSync(baselineDir, { recursive: true });

  // Normalize BOTH sources the same way — a relative `scenario.url` must become a
  // real (file://) URL just like a --url override does, not be handed to Playwright raw.
  const baseUrl = normalizeUrl(o.urlOverride ?? scenario.url);
  const stepTimeoutMs = o.stepTimeoutMs ?? DEFAULT_STEP_TIMEOUT_MS;
  const scenarioTimeoutMs = o.scenarioTimeoutMs ?? DEFAULT_SCENARIO_TIMEOUT_MS;
  // Already resolved through the chain (CLI override was threaded into parseScenario).
  const threshold = scenario.threshold;

  const specPath = path.join(generatedDir, `${run}.spec.ts`);
  const configPath = path.join(generatedDir, `${run}.config.ts`);
  // Relative import base from the generated spec's dir to template/asserts/, as a
  // POSIX specifier Playwright's loader can resolve.
  const assertsImport = path.relative(generatedDir, path.join(templateDir, 'asserts')).split(path.sep).join('/');
  fs.writeFileSync(specPath, compileSpec(scenario, { baseUrl, stepTimeoutMs, stepsDir, assertsImport }));
  fs.writeFileSync(
    configPath,
    compileConfig({
      specFile: specPath,
      viewports: scenario.viewports,
      threshold,
      stepTimeoutMs,
      scenarioTimeoutMs,
      baselineDir,
      outputDir: path.join(runDir, 'pw-output'),
    }),
  );

  const pwArgs = ['playwright', 'test', '--config', configPath];
  if (o.update) pwArgs.push('--update-snapshots');
  const res = spawnSync('npx', pwArgs, { cwd: templateDir, stdio: 'inherit' });

  const resultsByViewport: Record<string, StepResult[]> = {};
  for (const vp of scenario.viewports) {
    const f = path.join(stepsDir, `${vp.name}.json`);
    if (fs.existsSync(f)) {
      try {
        resultsByViewport[vp.name] = JSON.parse(fs.readFileSync(f, 'utf8')) as StepResult[];
      } catch {
        resultsByViewport[vp.name] = [];
      }
    }
  }

  const verdict = assembleVerdict({
    scenario: scenario.id,
    route: scenario.id,
    viewports: scenario.viewports.map((v) => v.name),
    steps: scenario.steps.map((s) => ({ i: s.stepIndex, action: s.action })),
    resultsByViewport,
    runDirDisplay: displayRunDir(runDir),
    launchError: res.error ? res.error.message : null,
  });

  const verdictPath = path.join(runDir, 'verdict.json');
  fs.writeFileSync(verdictPath, JSON.stringify(verdict, null, 2) + '\n');

  return { verdict, exitCode: verdict.exitCode, scenario, specPath, configPath, verdictPath, runDir };
}

/** Adapter for `bin/visual-check.mjs --scenario <file>`. Returns the process exit code. */
export function runScenarioCli(args: Record<string, unknown>): number {
  const thresholdArg = args.threshold ?? args['max-diff-ratio'];
  // Validate the CLI override up front (parseScenario only checks the scenario file's
  // own threshold, not this override). Reject NaN / out-of-range before we spawn
  // Playwright, so a typo fails fast with a clear message instead of a bad comparator.
  let thresholdOverride: number | undefined;
  if (thresholdArg !== undefined) {
    thresholdOverride = Number(thresholdArg);
    if (!Number.isFinite(thresholdOverride) || thresholdOverride < 0 || thresholdOverride > 1) {
      throw new Error(`--threshold must be a number in [0, 1]; got '${String(thresholdArg)}'`);
    }
  }
  const { verdict } = runScenario({
    scenarioFile: String(args.scenarioFile),
    urlOverride: args.url ? String(args.url) : undefined,
    stepTimeoutMs: args['step-timeout'] ? Number(args['step-timeout']) : undefined,
    update: !!args.update,
    thresholdOverride,
    viewportFilter: args.viewport !== undefined ? String(args.viewport) : undefined,
  });
  process.stderr.write(`visual-check: ${verdict.status} (exit ${verdict.exitCode}) → ${verdict.runDir}\n`);
  return typeof verdict.exitCode === 'number' ? verdict.exitCode : 2;
}
