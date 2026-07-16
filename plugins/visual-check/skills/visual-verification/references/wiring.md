# Wiring

How the pieces compose in a consumer project, and how each engine plugs into an
existing task runner **without changing any other plugin**.

## Dependencies reused, not reimplemented

- **`playwright`** — resolves the current browser-automation API and drives the
  browser for the deterministic engine's `template/` project.
- **`design-preview`** — renders the project's own components for the
  real-component reference source, and supplies the reuse-don't-kill launch
  doctrine `template/launch/` follows.

The skill orchestrates both; it does not vendor or fork either.

## Template layout (deterministic engine)

The plugin's `template/` is a self-contained Playwright project. The consumer
never edits it — the command invokes `template/bin/visual-check.mjs`, which wraps
`npx playwright test` to add the `0/1/2` exit contract and the frozen
`verdict.json`. Where things live:

- `bin/visual-check.mjs` — the single entry; parses flags, runs the URL/egress
  guard, launches a dev server when `--url` is absent, then drives + emits the verdict.
- `scenario/` — the frozen YAML schema + compiler (`schema.ts`, `compile.ts`).
- `baseline/` — the golden-baseline store, `--update` guards, and pixel diff.
- `config/` — `.visual-check/config.json` loader + `--init` scaffolder.
- `launch/` — dev-server detect / reuse / background-start.
- `guards/` — the URL/egress classifier wired into the drive path.

Consumer-side artifacts live under a gitignored `.visual-check/` (results and
generated specs), except the committed `.visual-check/baselines/` and
`.visual-check/config.json`.

## Resolved command surface

`/visual-check:check` parses `$ARGUMENTS` and calls the harness. Resolved flags:

| Flag | Effect |
| ---- | ------ |
| `--url <url>` | Target to render. Optional — omitted triggers the launch path. |
| `--against <base>` | Reference base name → `<base>__<viewport>.png` per viewport. |
| `--scenario <file>` | Drive a declarative multi-step YAML flow. |
| `--baseline` | Diff the committed golden-baseline store instead of `--against`. |
| `--update` | Bless the current render as the baseline (guarded — see below). |
| `--ack-commit` / `--ack-dirty` | `--update` safety acks (spec D16). |
| `--ack-egress` | Acknowledge a non-local target (spec D17). |
| `--init` | Scaffold `.visual-check/config.json` + example scenario; exit. |
| `--contract <specfile>` | Textual criterion — routes to the agent engine only. |
| `--viewport <name>` | Run one configured viewport instead of all. |

Guards are non-negotiable: `--update` refuses on a dirty tree (unless
`--ack-dirty`) and until `--ack-commit`; a non-local target refuses until
`--ack-egress`.

## (a) Deterministic engine on a taskmaster `Verify:` line

The deterministic engine yields a shell exit code, so it drops straight into a
task card's `Verify:` line as a gate — exit `0` closes the task, `1`/`2` sends it
back into the fix loop. Verbatim:

```
Verify: node ${CLAUDE_PLUGIN_ROOT}/template/bin/visual-check.mjs \
          --url http://localhost:3000/ --against ./refs/home
        # → runs `npx playwright test` under the hood; exit 0 pass · 1 fail · 2 error.
        # verdict.json + diffs land in .visual-check/results/<pid>-<uuid>/
```

`task-execution` runs that EXACT command, records the exit code + the
`visual-check: <status> (exit <code>) → <runDir>` stderr line as evidence, and
flips the task's status on `0`. Nothing about the runner changes — it already
treats a `Verify:` command as a pass/fail oracle.

In CI the same command is the job step; its exit code passes or fails the job and
`verdict.json` is uploaded as a build artifact.

## (b) Agent engine through the manual/reviewer branch

The agent engine produces **no shell exit code** (`exitCode` is `null`/omitted;
`status` alone carries the verdict), so it cannot be a `Verify:` gate. It routes
instead through task-execution's **manual/reviewer branch** — the same path that
records "dialog renders centered" as a manual check with what was observed:

```
Verify (manual/reviewer): /visual-check:check --scenario sidebar.yaml --url http://localhost:3000/
        # No @playwright/test present → the command dispatches visual-check-engineer,
        # which drives claude-in-chrome and writes verdict.json (engine:"agent",
        # exitCode:null). Record status + runDir as a MANUAL check, not an exit code.
```

The reviewer reads the emitted `verdict.json` (`status`, per-step `reasons`,
`diffPath`) and records it as manual evidence. Because it is non-deterministic,
it is never a merge gate — recommend the deterministic engine for CI. This uses
task-execution's existing manual-evidence rule verbatim: **no change to the
task-runner plugin is required.**

`config.allowLlmEngine: false` forbids the agent path entirely (its screenshots
egress to a model) — the agent declines and emits nothing.

## CI wiring

The deterministic engine is the CI gate: its exit code passes or fails the job,
and `verdict.json` is uploaded as an artifact. The agent engine has no exit code
and does not gate CI; it stays on the manual/reviewer branch above.
