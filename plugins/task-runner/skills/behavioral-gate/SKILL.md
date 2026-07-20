---
name: behavioral-gate
description: Use during run completion (and the tracks merged-branch final gate) — actually run the produced artifact: its test suite via a real runner plus a smoke of each shell entrypoint, not just re-linting. Fails an empty suite, a code run with zero runnable check, a crashing entrypoint, a documented-but-dead flag.
---

# Behavioral gate

A green run should mean the produced code *works*, but the completion gate has historically
run "whatever the repo defines" — which for a freshly generated subtree is often a static
linter (JSON shape, frontmatter, line budgets) that never executes a single line of the new
code. So an SSRF guard that fails open, a documented flag that is a silent no-op, and a test
suite that collects zero tests all pass a fully green run. This gate closes that hole: at
completion it **runs the artifact**, and refuses to certify code it could not exercise.

## The three-gate defense

This gate is the completion-time layer of a three-part defense against green-that-proves-
nothing; it is deliberately not the whole thing:

1. **Author-time (`taskmaster:verify-teeth`).** Blocks a weak Verify *line* before code
   exists — the cheap first filter.
2. **Per-card runtime (negative-control, in `task-execution`).** Proves each card with a
   resolvable target and an automatable verify — on every dispatch path (inline, delegated,
   parallel-group, and tracks, plus the crew fix-loop re-check on directly-dispatched
   cards) — goes RED against a targeted feature disable,
   that the check discriminates. The residual exempt classes (manual/visual verify lines, an
   unresolvable `--target`) are skipped with a note, not proven here, and lean on this gate.
3. **Completion runtime (this gate).** Runs the whole produced artifact once at the end —
   the suite is non-empty, the code executes, entrypoints and their flags actually do
   something.

Layers 1–2 are per-card and can be scoped out or skipped; this gate is the run-level backstop
that a code-producing run shipped *something* runnable and non-empty. None substitutes for
the others.

## Where it runs

- **Serial completion protocol** — as an added gate alongside the full check suite, never
  replacing it. The suite catches lint/type/build regressions; this catches "the new code
  never ran."
- **Tracks merged-branch final gate** — on the merged run branch, so the integrated result
  of all tracks is exercised, not just re-linted (see `track-orchestration`).

Invoke the shipped script (it is the authoritative logic; this skill only drives it):

```
${CLAUDE_PLUGIN_ROOT}/scripts/behavioral-gate.sh --changed "<the run's touched files>" \
  [--entrypoint <bin> ...] [--differential 'flag::with::without' ...]
```

## What it does

1. **Classify.** Resolve a test runner for the touched-file languages. If none resolves and
   only non-executable/doc types were touched, exit 0 labeled `no-executable-surface` — an
   honest lint-only run, not a failure. Otherwise the run needs behavioral coverage. The
   classifier is objective (runner detection + file type), never author discretion, so a run
   cannot dodge the gate by declaring its untested code "lint-only".
2. **Own-tests.** Run the resolved runner non-interactively, under a hard timeout, in a temp
   cwd. Apply per-runner **empty-detection** (see `references/runners.md`): an empty or
   zero-collected suite is `empty-suite` (exit 2), not a pass. A runner that exposes no empty
   signal **fails closed** for a code-producing run — silence is never a pass.
3. **Zero-check.** A run that needs coverage but ships neither a runnable own-test nor a
   smokable entrypoint exits 2 `no-behavioral-coverage`.
4. **Entrypoint smoke.** Each shell-executable entrypoint is invoked in its declared
   non-destructive form and asserted non-error (`entrypoint-error` on crash). For each
   declared affordance, a **differential** check runs the entrypoint with and without the
   flag and asserts the observable output differs — a no-effect flag is `dead-affordance`
   (exit 2). "Assert not error" alone cannot catch a no-op flag; the differential can.
5. **Honest report.** A markdown command/skill entrypoint is not shell-executable; the gate
   reports `not-shell-smokable → routed to B2/review` and continues — never a silent pass.

## Exit contract

| Exit | Meaning | Completion action |
|------|---------|-------------------|
| 0 | covered, or honest `no-executable-surface` | gate passes |
| 2 | `empty-suite` / `no-behavioral-coverage` / `entrypoint-error` / `dead-affordance` | block completion |
| 3 | usage | fix the invocation |

## Worked example

A run generates a plugin whose `test` script is `vitest run` over a directory with no test
files. Vitest exits 0 ("no test files found"), so the repo's full suite is green and the run
reports 13/13 cards done. The behavioral gate classifies the run as needing coverage (`.ts`
files touched, a runner resolves), runs the suite, applies empty-detection, sees zero
collected tests, and exits 2 `empty-suite`. Completion is blocked with the artifact path —
the false-green that previously shipped is now caught before the run closes.

## Safety

The gate executes produced code, which is arbitrary-code-execution by design. It runs under a
hard timeout, in a temp cwd, and never mutates the caller's live working tree. An entrypoint
smoke uses only the declared non-destructive form. A suite that needs an unavailable
environment is reported as skipped-with-reason, not silently passed.

## Under ultra-goal (hands-off)

A behavioral-gate failure **parks-and-stops** — it is never auto-taken. A hands-off run does
not close on a green that the gate contradicts; the failing label + artifact path is
surfaced for the operator.

## Enforcement — the Stop hook, and the honest residual

The completion protocol runs this gate and, on a pass, records it to
`.claude/task-runner/gate-pass.json` (`{"head":"<HEAD sha>"}`). The task-runner **Stop
hook** (`hooks/completion-gate.sh`) reads that record: for a run that registered itself
(`.claude/task-runner/active-run.json`, written at run start per `run.md` step 1), it
refuses a clean stop unless a gate pass is recorded for the current HEAD — a reminder by
default, a hard block under `TASK_RUNNER_STOP_GATE=block`. So a registered run can no longer
stop "done" on a green repo suite that never ran the produced code.

The residual is named, not hidden: the hook is a *records* check — cheap, fires on every
yield, and never executes the produced tests (the completion protocol does that in
isolation). It is keyed off the run registering itself, so a run that never writes
`active-run.json` is not enforced (fail-open), and a recorded pass could in principle be
forged. What the hook closes is the honest-but-forgetful skip; deliberate evasion now
requires actively omitting the register or faking the record, not merely forgetting to run
the gate.

Two further residuals it does **not** close: a non-index run (a todo or plan list) records
no card counts in `gate-pass.json`, so the card-completeness check never fires for it — only
taskmaster-index runs are backstopped against a silently-skipped card. And the per-card
negative-control (layer 2 above) is instruction-only: no hook enforces that each card's
control run actually happened.

## Anti-patterns

- Reimplementing runner detection or empty-detection in prose — the script + `runners.md`
  are the single source of truth.
- Treating `no-executable-surface` as a failure — a genuinely doc-only run is honestly
  lint-gated; the gate says so rather than failing it.
- Accepting a green suite without the gate "because the suite passed" — the suite passing is
  exactly the false-green this gate exists to test for emptiness.
