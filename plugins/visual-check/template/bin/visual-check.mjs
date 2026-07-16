#!/usr/bin/env node
// Deterministic visual-check runner. The single entry that yields the 0/1/2 exit
// contract (bare `npx playwright test` cannot emit exit 2 for an unreachable url).
//
//   node bin/visual-check.mjs --url <url> --against <ref-base> [--scenario name]
//         [--max-diff-ratio 0.01] [--step-timeout 10000] [--out .visual-check/results]
//         [--update]                       # (re)write the reference baselines
//         [--baseline]                      # diff vs the committed golden-baseline store
//         [--viewport <name>]              # run ONE configured viewport instead of all
//         [--contract <spec>]              # agent-engine only → refused here (exit 2)
//         [--ack-commit] [--ack-dirty]      # --update safety acks (spec D16)
//
// `--against <base>` resolves per viewport to `<base>__<projectName>.png`
// (e.g. --against ./refs/home → refs/home__desktop.png, refs/home__mobile.png).
//
// `--update` blesses baselines and is GATED (spec D16, baseline/guards.ts): it refuses on
// a dirty git tree (unless --ack-dirty) and refuses to write committed screenshots that may
// embed auth/PII data until --ack-commit is given. `--baseline` diffs a single target
// against the committed golden-baseline store (.visual-check/baselines/) keyed by
// `<route>__0__<viewport>` (or, with --update, blesses that store), reusing baseline/index.ts;
// a missing baseline for a key is status:error "run --update first". Scenario-flow baselines
// ride the scenario `match.source:baseline` path instead.
//
// Exit: 0 all pass · 1 a real visual/functional fail · 2 tooling/infra error
// (timeout, no engine, url unreachable, missing reference).

import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const templateDir = path.resolve(__dirname, '..');
const VIEWPORTS = ['desktop', 'mobile'];

// Value-less boolean flags: everything else consumes the following token as its value.
const BOOL_FLAGS = new Map([
  ['--update', 'update'],
  ['--init', 'init'],
  ['--baseline', 'baseline'],
  ['--ack-commit', 'ackCommit'],
  ['--ack', 'ackCommit'], // alias
  ['--ack-dirty', 'ackDirty'],
  ['--ack-egress', 'ackEgress'], // URL/egress guard ack (spec D17, guards/url.ts)
]);

function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (BOOL_FLAGS.has(a)) {
      out[BOOL_FLAGS.get(a)] = true;
    } else if (a.startsWith('--')) {
      const key = a.slice(2);
      const eq = key.indexOf('=');
      if (eq >= 0) {
        out[key.slice(0, eq)] = key.slice(eq + 1);
      } else {
        // A value flag must be followed by a value, not another flag or end-of-args —
        // otherwise `--against --update` would silently swallow `--update` as the value.
        const next = argv[i + 1];
        if (next === undefined || next.startsWith('--')) {
          process.stderr.write(`visual-check: error (exit 2) → missing value for --${key}\n`);
          process.exit(2);
        }
        out[key] = next;
        i++;
      }
    } else {
      out._.push(a);
    }
  }
  return out;
}

function normalizeUrl(u) {
  if (/^[a-z][a-z0-9+.-]*:\/\//i.test(u)) return u; // has a scheme (http, https, file)
  return 'file://' + path.resolve(process.cwd(), u); // local path → file:// URL
}

function displayRunDir(runDir) {
  const rel = path.relative(templateDir, runDir);
  let d = rel && !rel.startsWith('..') && !path.isAbsolute(rel) ? rel : runDir;
  if (!d.endsWith('/')) d += '/';
  return d;
}

// Route slug from a target URL — the `<route>` half of the baseline store key
// (`<route>__<stepIndex>__<viewport>`). Mirrors reporter/verdict-reporter.ts `slug`.
function slug(u) {
  try {
    const parsed = new URL(u);
    const p = (parsed.pathname || '/').replace(/\/+$/, '') || '/';
    const base = p === '/' ? 'root' : path.basename(p).replace(/\.[^.]+$/, '');
    return base.replace(/[^a-z0-9]+/gi, '-').replace(/^-+|-+$/g, '').toLowerCase() || 'root';
  } catch {
    return 'target';
  }
}

const EMPTY_ASSERTS = () => ({ dom: [], console: [], layout: [], network: [] });

// --baseline single-target (spec D8): route the single page through the committed golden
// store (baseline/index.ts) keyed by `<route>__0__<viewport>` instead of an ad-hoc --against
// image. Diff by default; with --update, bless the store (guards already cleared in main()).
// A missing baseline for a requested key is status:error "run --update first" — never a
// silent pass. --viewport narrows the resolved viewports to the named one. Writes the frozen
// verdict.json into runDir and returns the 0/1/2 exit code.
async function runBaselineTarget({ args, url, scenario, runDir }) {
  const baseDir = args.project ? path.resolve(process.cwd(), args.project) : process.cwd();
  const bmod = await import(pathToFileURL(path.join(templateDir, 'baseline', 'index.ts')).href);
  const thr = args.threshold ?? args['max-diff-ratio'];
  const cliThreshold = thr !== undefined && thr !== null && String(thr) !== '' ? Number(thr) : undefined;
  const settings = bmod.resolveBaselineSettings(baseDir, cliThreshold);

  let viewports = settings.viewports;
  if (args.viewport !== undefined) {
    viewports = settings.viewports.filter((v) => v.name === args.viewport);
    if (viewports.length === 0) {
      exitError(
        runDir,
        scenario,
        url,
        `unknown --viewport '${args.viewport}' — configured viewports: ${settings.viewports.map((v) => v.name).join(', ')}`,
      );
    }
  }

  const route = slug(url);
  const targets = viewports.map((v) => ({
    route,
    stepIndex: 0,
    viewport: { name: v.name, width: v.width, height: v.height },
    url,
  }));

  let verdict;
  if (args.update) {
    const run = await bmod.runBaselineUpdate({
      baseDir,
      targets,
      mask: settings.mask,
      ackCommit: !!args.ackCommit,
      ackDirty: !!args.ackDirty,
    });
    if (!run.ok) exitError(runDir, scenario, url, run.reason || '--update refused');
    verdict = {
      status: 'pass',
      engine: 'playwright',
      exitCode: 0,
      scenario,
      steps: run.written.map((w, idx) => ({
        id: `${route}__${idx}`,
        action: `baseline update ${w.key}`,
        asserts: EMPTY_ASSERTS(),
        match: { viewport: w.key.split('__').pop(), ratio: 0, diffPath: '', reasons: [] },
        pass: true,
      })),
      reasons: [],
      runDir: displayRunDir(runDir),
    };
  } else {
    const run = await bmod.runBaselineDiff({
      baseDir,
      targets,
      mask: settings.mask,
      threshold: settings.threshold,
    });
    verdict = {
      status: run.status,
      engine: 'playwright',
      exitCode: run.exitCode,
      scenario,
      steps: run.results.map((r, idx) => ({
        id: `${route}__${idx}`,
        action: `baseline diff ${r.key}`,
        asserts: EMPTY_ASSERTS(),
        match: {
          viewport: r.key.split('__').pop(),
          ratio: r.ratio,
          diffPath: '',
          reasons: r.reason ? [r.reason] : [],
        },
        pass: r.status === 'pass',
      })),
      reasons: run.results.flatMap((r) => (r.reason ? [r.reason] : [])),
      runDir: displayRunDir(runDir),
    };
  }

  fs.writeFileSync(path.join(runDir, 'verdict.json'), JSON.stringify(verdict, null, 2) + '\n');
  process.stderr.write(`visual-check: ${verdict.status} (exit ${verdict.exitCode}) → ${verdict.runDir}\n`);
  return typeof verdict.exitCode === 'number' ? verdict.exitCode : 2;
}

function writeErrorVerdict(runDir, scenario, url, reason) {
  const verdict = {
    status: 'error',
    engine: 'playwright',
    exitCode: 2,
    scenario,
    steps: [],
    reasons: [reason],
    runDir: displayRunDir(runDir),
  };
  fs.mkdirSync(runDir, { recursive: true });
  fs.writeFileSync(path.join(runDir, 'verdict.json'), JSON.stringify(verdict, null, 2) + '\n');
  return verdict;
}

function exitError(runDir, scenario, url, reason) {
  const verdict = writeErrorVerdict(runDir, scenario, url, reason);
  process.stderr.write(`visual-check: error (exit 2) → ${verdict.runDir} (${reason})\n`);
  process.exit(2);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  // --contract (skills/.../references/engines.md): a PROSE visual criterion has no image
  // for the DETERMINISTIC engine to pixel-diff. Refuse honestly (exit 2) instead of
  // silently ignoring a documented flag — check.md routes --contract to the AGENT engine.
  if ('contract' in args) {
    process.stderr.write(
      'visual-check: error (exit 2) → contract is agent-engine only; run without @playwright/test or via the agent engine\n',
    );
    process.exit(2);
  }

  // --init (spec A5): scaffold a starter .visual-check/config.json + example scenario
  // into the consumer's project (cwd). Idempotent — existing files are kept, announced.
  if (args.init) {
    const mod = await import(pathToFileURL(path.join(templateDir, 'config', 'init.ts')).href);
    const res = mod.initProject(process.cwd());
    for (const f of res.created) process.stdout.write(`visual-check: wrote ${f}\n`);
    for (const f of res.skipped) process.stdout.write(`visual-check: kept existing ${f}\n`);
    process.exit(0);
  }

  // --update safety gate (spec D16, baseline/guards.ts): blessing a baseline commits a
  // screenshot of a real app to git, so it is refused on a dirty tree (unless --ack-dirty)
  // and until the commit/PII warning is acknowledged (--ack-commit). Applies to BOTH the
  // scenario-file and single-target update flows below, before either captures anything.
  if (args.update) {
    const baseDir = args.project ? path.resolve(process.cwd(), args.project) : process.cwd();
    const g = await import(pathToFileURL(path.join(templateDir, 'baseline', 'guards.ts')).href);
    const guard = g.checkUpdateGuards({
      git: g.gitStatus(baseDir),
      ackCommit: !!args.ackCommit,
      ackDirty: !!args.ackDirty,
    });
    for (const w of guard.warnings) process.stderr.write(w + '\n');
    if (!guard.ok) {
      process.stderr.write(`visual-check: --update refused (exit 2) → ${guard.reason}\n`);
      process.exit(2);
    }
  }

  // Multi-step scenario flow: when `--scenario` names an existing FILE, compile it
  // to an ephemeral Playwright spec and run that (bin/scenario/compile.ts). A bare
  // `--scenario <label>` (not a file) keeps the card-03 single-target behaviour.
  if (args.scenario) {
    const scenarioPath = path.resolve(process.cwd(), args.scenario);
    if (fs.existsSync(scenarioPath) && fs.statSync(scenarioPath).isFile()) {
      // URL/egress guard for scenario runs (spec D17). The single-page path guards its
      // target below, but a scenario file dispatches + process.exit()s BEFORE reaching it —
      // so an explicit `--url` here must clear the SAME classification (guards/url.ts) or a
      // scenario would silently drive a production / internal / cloud-metadata host. Use the
      // identical normalizeUrl as the single-page path. A no-`--url` scenario launches a
      // localhost dev server (safe) and needs no check.
      if (args.url) {
        const target = normalizeUrl(args.url);
        const guardMod = await import(pathToFileURL(path.join(templateDir, 'guards', 'url.ts')).href);
        const egress = guardMod.evaluateEgressGuard({ urls: [{ role: 'target', url: target }], ack: !!args.ackEgress });
        for (const w of egress.warnings) process.stderr.write(w + '\n');
        if (!egress.ok) {
          process.stderr.write(`visual-check: error (exit 2) → ${egress.reason}\n`);
          process.exit(2);
        }
      }
      const mod = await import(pathToFileURL(path.join(templateDir, 'scenario', 'compile.ts')).href);
      const code = mod.runScenarioCli({ ...args, scenarioFile: scenarioPath });
      process.exit(typeof code === 'number' ? code : 2);
    }
  }

  // Validate the CLI diff threshold (--threshold / --max-diff-ratio) once, for the
  // baseline + single-page paths below: it must be a number in [0, 1]. An unvalidated NaN
  // would make EVERY diff fail; a >1 value would silently no-op the diff. Reject a malformed
  // value as a usage error (exit 2) rather than letting it corrupt the verdict. (The
  // scenario/compile.ts path exits above and validates its own threshold layer.)
  const rawThreshold = args.threshold ?? args['max-diff-ratio'];
  if (rawThreshold !== undefined && rawThreshold !== null && String(rawThreshold) !== '') {
    const n = Number(rawThreshold);
    if (Number.isNaN(n) || n < 0 || n > 1) {
      process.stderr.write(
        `visual-check: error (exit 2) → --threshold must be a number in [0, 1] (got '${rawThreshold}')\n`,
      );
      process.exit(2);
    }
  }

  const scenario = args.scenario || 'default';
  const resultsBase = path.resolve(templateDir, args.out || path.join('.visual-check', 'results'));
  const runDir = path.join(resultsBase, `${process.pid}-${randomUUID()}`);
  fs.mkdirSync(runDir, { recursive: true });

  // No `--url` (card 11): render the consumer's real app by REUSING a running dev
  // server or background-starting one (launch/ — the design-preview reuse-don't-kill
  // doctrine). A `--url` given skips this entirely and the existing capture flow
  // below uses it verbatim. Not launchable → exit 2 ("provide a --url"), never a
  // hang. Only a server THIS run started is stopped — gracefully on success, and
  // via a SIGKILL reap hook on every other exit path.
  let launchHandle = null;
  if (!args.url) {
    const projectDir = args.project ? path.resolve(process.cwd(), args.project) : process.cwd();
    const { launchTarget } = await import(pathToFileURL(path.join(templateDir, 'launch', 'index.mjs')).href);
    const launch = await launchTarget({ projectDir });
    if (!launch.ok) {
      exitError(runDir, scenario, '', launch.reason);
    }
    args.url = launch.url;
    if (launch.started) {
      launchHandle = launch;
      const reap = () => {
        try {
          launch.stopSync();
        } catch {
          /* best-effort */
        }
      };
      process.on('exit', reap);
      process.on('SIGINT', () => process.exit(130));
      process.on('SIGTERM', () => process.exit(143));
    }
    process.stderr.write(`visual-check: ${launch.started ? 'launched' : 'reusing'} dev server → ${launch.url}\n`);
  }

  // --baseline needs no --against (it diffs the committed golden store, not an ad-hoc image).
  if (!args.url || (!args.against && !args.baseline)) {
    exitError(
      runDir,
      scenario,
      args.url || '',
      'usage: --url <url> --against <ref-base> are required (or --baseline for the golden store)',
    );
  }

  const url = normalizeUrl(args.url);

  // URL/egress guard (spec D17, guards/url.ts): before driving, classify the target.
  // A localhost/dev/file:// target runs freely; a PRODUCTION, INTERNAL, or cloud-
  // METADATA host is non-local — WARN and REFUSE (exit 2) until --ack-egress is given,
  // so a check never silently drives a live site or lets a metadata endpoint (SSRF)
  // exfiltrate cloud credentials. A launched/reused dev server is localhost → clears it.
  const guardMod = await import(pathToFileURL(path.join(templateDir, 'guards', 'url.ts')).href);
  const egress = guardMod.evaluateEgressGuard({ urls: [{ role: 'target', url }], ack: !!args.ackEgress });
  for (const w of egress.warnings) process.stderr.write(w + '\n');
  if (!egress.ok) {
    exitError(runDir, scenario, url, egress.reason);
  }

  // --baseline single-target: diff (or bless) the committed golden store instead of running
  // the --against Playwright flow. Own capture + pixel diff via baseline/index.ts.
  if (args.baseline) {
    const code = await runBaselineTarget({ args, url, scenario, runDir });
    if (launchHandle) await launchHandle.stop();
    process.exit(code);
  }

  const againstBase = path.resolve(process.cwd(), args.against);

  // --viewport: run ONE configured viewport instead of all. The single-page harness projects
  // are desktop/mobile (playwright.config.ts); an unknown name errors (exit 2) rather than
  // silently running every viewport. Narrows the preflight and is passed to `--project` below.
  let selectedViewports = VIEWPORTS;
  if (args.viewport !== undefined) {
    if (!VIEWPORTS.includes(args.viewport)) {
      exitError(runDir, scenario, url, `unknown --viewport '${args.viewport}' — configured viewports: ${VIEWPORTS.join(', ')}`);
    }
    selectedViewports = [args.viewport];
  }

  // Preflight: every selected viewport reference must exist (missing reference → error → 2).
  if (!args.update) {
    const missing = selectedViewports.map((v) => `${againstBase}__${v}.png`).filter((p) => !fs.existsSync(p));
    if (missing.length) {
      exitError(runDir, scenario, url, `missing reference: ${missing.join(', ')}`);
    }
  }

  const env = {
    ...process.env,
    VC_URL: url,
    VC_SCENARIO: scenario,
    VC_RUN_DIR: runDir,
    VC_SNAPSHOT_TEMPLATE: `${againstBase}__{projectName}.png`,
    VC_MAX_DIFF_RATIO: String(args['max-diff-ratio'] ?? '0.01'),
    VC_STEP_TIMEOUT: String(args['step-timeout'] ?? '10000'),
  };

  const pwArgs = ['playwright', 'test'];
  if (args.viewport !== undefined) pwArgs.push(`--project=${args.viewport}`);
  if (args.update) pwArgs.push('--update-snapshots');

  const res = spawnSync('npx', pwArgs, { cwd: templateDir, env, stdio: 'inherit' });

  if (res.error) {
    exitError(runDir, scenario, url, `playwright launch failed: ${res.error.message}`);
  }

  const verdictPath = path.join(runDir, 'verdict.json');
  if (!fs.existsSync(verdictPath)) {
    exitError(runDir, scenario, url, `no verdict produced (playwright exited ${res.status})`);
  }

  let verdict;
  try {
    verdict = JSON.parse(fs.readFileSync(verdictPath, 'utf8'));
  } catch (e) {
    exitError(runDir, scenario, url, `unreadable verdict.json: ${e.message}`);
  }

  if (launchHandle) await launchHandle.stop(); // graceful reap of the server this run started

  process.stderr.write(`visual-check: ${verdict.status} (exit ${verdict.exitCode}) → ${verdict.runDir}\n`);
  process.exit(typeof verdict.exitCode === 'number' ? verdict.exitCode : 2);
}

main().catch((e) => {
  process.stderr.write(`visual-check: fatal → ${e && e.message ? e.message : e}\n`);
  process.exit(2);
});
