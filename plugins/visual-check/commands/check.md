---
description: Visual QA check — render a URL (or drive a multi-step scenario) in a real browser and diff it against an approved baseline image, reporting pass/fail/error with the run-dir artifact paths. Wires --url + --against, --scenario, no-url launch, --baseline/--update/--init; --contract (agent-textual) and --viewport (selects a configured viewport) are noted.
argument-hint: --url <url> --against <image> | --scenario <file> --url <url> | --baseline | --update | --init
---

Run a visual-check verification driven by `$ARGUMENTS`. This command,
`/visual-check:check`, is an **agent-orchestrated prompt, not a shell script** — only
the deterministic engine's underlying `npx playwright test` yields a shell exit code;
you interpret the resulting `verdict.json`.

## 1. Parse `$ARGUMENTS`

Pick the mode by the flags present:

- **Single-page compare** — `--url <url>` + `--against <image>`. `--url` is the target
  to render (an http(s) URL, or a local file path the harness resolves to a `file://`
  URL); `--against` is the reference **base name**, resolved per viewport to
  `<image>__desktop.png` and `<image>__mobile.png`.
- **Scenario mode** — `--scenario <file>` + `--url <url>`. `--scenario` is a
  declarative YAML flow (see `skills/visual-verification/references/scenario-schema.md`)
  the harness compiles and drives step by step; `--url` is the base target. Use this
  for multi-step interaction QA (open/close a sidebar, assert not-broken at each step).
- **No `--url` (launch)** — `--url` is OPTIONAL. When omitted, the harness detects a
  launchable dev project in the repo and **reuses a running dev server or
  background-starts one** (`template/launch/`), then drives that URL. If the project is
  **not launchable** (no dev script / framework detected), the harness exits `2` asking
  you to **provide a `--url`** — it never hangs. Only a server this run started is
  stopped afterward.

If neither a target URL nor a launchable project is resolvable, stop and show the usage
line above — do not guess a value.

These flags are **wired** and route straight to the harness (`template/bin/visual-check.mjs`):

- **`--init`** — scaffold a starter `.visual-check/config.json` + example scenario into
  the project (idempotent; existing files are kept and announced). Runs and exits
  without driving a browser.
- **`--update`** — (re)bless the current render as the reference baseline. **Guarded**
  (spec D16): refused on a dirty git tree unless `--ack-dirty`, and refused until
  `--ack-commit` acknowledges that committed screenshots may embed auth/PII data.
- **`--baseline`** — diff against the committed golden-baseline store
  (`.visual-check/baselines/`) instead of an ad-hoc `--against` image.

Two more flags shape the run — one routes engines, one filters viewports:

- **`--contract <specfile>`** — a *textual* visual criterion, judged by the **agent
  engine only** (never pixel-diffed; see `skills/visual-verification/references/engines.md`).
  The deterministic engine has no image to diff for prose, so a contract routes to the
  agent engine; passed straight to the deterministic harness it is **refused** (exit `2`
  with an agent-only message) rather than silently ignored.
- **`--viewport <name>`** — runs one configured viewport (from `config.json` or the
  scenario) instead of every viewport. The deterministic harness filters to it on the
  single-page, scenario, and baseline paths; an unknown name errors (exit `2`).

## 2. Consent gate — first use only, do not skip (spec D15)

Before writing anything or driving a browser, check whether a `.visual-check/`
directory already exists at the repo root.

- **It does NOT exist → this is a first run.** Announce, in plain text, that proceeding
  will (a) create and write under `.visual-check/` (run artifacts: screenshots, diffs,
  and `verdict.json`), (b) possibly launch a local dev server, and (c) drive a real
  browser against the target. Then ask for explicit opt-in (AskUserQuestion: Proceed /
  Cancel). Do **not** create `.visual-check/`, launch a server, or drive the browser
  until the user opts in. On decline, stop and report that nothing was written or driven.
- **It already exists →** consent was given on a prior run; proceed without re-prompting.

## 3. Detect the engine (spec A6)

- If the consumer project has `@playwright/test` resolvable from the repo (e.g.
  `node -e "require.resolve('@playwright/test')"` succeeds, or it is a declared dev
  dependency with `node_modules` installed) → **deterministic engine**; go to step 4.
- Else, if the agent has the `claude-in-chrome` capability → **agent engine**. Dispatch the
  `visual-check-engineer` subagent (this plugin's `agents/visual-check-engineer.md`) to drive
  the check, passing the parsed inputs (the resolved target/scenario and `--against`
  reference) and the resolved settings. First honor two gates before it drives: if the
  project `config.json` sets `allowLlmEngine: false`, stop and report that the agent engine
  is forbidden for this project (its screenshots would egress to a model) — do not dispatch;
  and if the scenario is mutating without `allowMutations: true`, it is refused. The agent
  produces **no shell exit code** — it emits the frozen `verdict.json` with `engine:"agent"`
  into a run dir and `status` carries the verdict; read it back at step 5 and note that this
  result is non-deterministic (recommend the deterministic Playwright engine for CI). Do not
  fabricate a verdict.
- Else (neither) → stop with a clear no-engine message: "No visual-check engine available —
  install `@playwright/test` for the deterministic engine, or run in an agent with
  `claude-in-chrome`." Do nothing further; write nothing.

## 4. Run the deterministic harness

Invoke the harness shipped in this plugin's `template/`, matching the parsed mode:

- **Single-page compare:**

  ```
  node ${CLAUDE_PLUGIN_ROOT}/template/bin/visual-check.mjs --url <url> --against <image>
  ```

- **Scenario mode:**

  ```
  node ${CLAUDE_PLUGIN_ROOT}/template/bin/visual-check.mjs --scenario <file> --url <url>
  ```

  The harness compiles the scenario to an ephemeral spec under the gitignored
  `.visual-check/generated/`, drives each step, and evaluates the four "not broken"
  categories (`dom`/`console`/`layout`/`network`) plus each `match` checkpoint.

- **No `--url` (launch):** drop `--url` and the harness launches/reuses a dev server
  first, then diffs; a non-launchable project exits `2` ("provide a `--url`").
- **Golden baseline / bless / init:** add `--baseline` to diff the committed store,
  `--update --ack-commit [--ack-dirty]` to bless a new baseline, or `--init` to scaffold
  config (init runs and exits without driving).

**URL/egress guard (spec D17):** before it drives, the harness classifies the target.
A localhost / dev-host / `file://` target runs freely; a **production**, **internal**
private-network, or **cloud-metadata** host is non-local — it WARNS and **refuses**
(exit `2`) until `--ack-egress` is passed, so a check never silently drives a live site
or lets a metadata endpoint exfiltrate cloud credentials.

Each form resolves references per viewport, runs `npx playwright test` under the hood, and
exits `0` (pass) / `1` (fail) / `2` (error, e.g. unreachable url, per-step or per-scenario
timeout, missing reference, non-local target without `--ack-egress`). Each writes
`verdict.json` into a per-run directory `.visual-check/results/<pid>-<uuid>/` and prints
that path on stderr: `visual-check: <status> (exit <code>) → <runDir>`.

## 5. Read back the verdict and report

Read `verdict.json` from the printed run directory — the frozen schema (`status`,
`engine`, `exitCode`, `scenario`, `steps[]`, `reasons[]`, `runDir`). Report:

- **pass** (`status:pass`, exit 0) — the render matched the baseline within tolerance for
  every viewport. Give the run-dir path where the screenshots and verdict live.
- **fail** (`status:fail`, exit 1) — a real visual mismatch. List each failing step's
  `viewport`, `ratio`, and `diffPath` (under the run dir), plus the top-level `reasons`.
- **error** (`status:error`, exit 2) — the run could not complete. Report `reasons` and the
  run-dir path so the artifacts can be inspected.

Never invent a pass: if no `verdict.json` was produced, treat the run as an error and
report the harness's stderr rather than claiming success.
