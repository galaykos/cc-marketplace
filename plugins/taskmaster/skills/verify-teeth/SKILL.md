---
name: verify-teeth
description: Use after coverage-check in the task-cards tail — lints every card's Verify line for a named assertion that would fail were the feature absent, blocking compile-only, existence-only, `|| true`, and bare "suite passes" forms.
disable-model-invocation: true
---

# Verify teeth

A card closes when its `<verify>` command exits 0. If that command passes whether the
feature works or not — `test -f out.js`, `node -e "require('./x')"`, `npm test` over an empty
suite, anything ending `|| true` — "green" proves nothing and broken code ships marked done.
This skill makes the line earn its green at authoring time, before any implementation.

## Where it sits, and when

Standing: recorded — layer 1 of three: a syntactic denylist over the line *text*, before
any code exists. Layers 2 and 3 run during execution and belong to `task-runner`
(`task-runner:behavioral-gate` § "The three-gate defense"). Runs in the task-cards tail,
after `coverage-check` — which grades whether a criterion is *claimed*, never the line's
strength — and before the task-runner handoff. Run both, in that order.

## What it does

For every card in the run, invoke the shipped denylist linter:

```
${CLAUDE_PLUGIN_ROOT}/scripts/verify-teeth-lint.sh --card <card-file>
```

It reads the card's `<verify>` element (or a legacy `**Verify:**` line) and exits **0**
(teeth: names a test / assertion / observable), **2** (weak: prints `verify-teeth: <reason>`),
or **3** (usage: no line found). On a `2`, block the card: report the reason and the fix
below, re-run after each fix until 0. The script is the single source of truth for the
pattern set — invoke it; never re-implement the list here.

## The weak forms it blocks (and the fix)

Each token is the exact `verify-teeth: <reason>` the script prints; the script's header
owns the pattern set and its caveats (the `tsc --noEmit` project-references NOTE among
them). This is only the fix table.

- `existence-only` → run the code and assert an observable *value*, not that a file exists.
- `always-true` (`|| true`, `; true`, `|| :`) → never swallow the exit code.
- `require-only` / `import-only` → a load proves the module parses, not that it behaves; assert.
- `compile-only` → compiling is not behaving; exercise the changed code path (`tsc -b` on a
  project-references root, where `--noEmit` checks nothing).
- `migration-run-only` → the DDL parsed, nothing more; assert the resulting column or a
  behavior that needs it.
- `bare-suite-pass` → name the new test or the asserted outcome, e.g.
  `pytest -k reject_malicious_host asserts 422`.

A line that names its assertion — `jest -t "rejects bad host" asserts throw`, or
`npm test -- invoice → all pass, including new test totals_rounds_half_up` — passes.

## Worked example

A card lands with:

```
<verify>node -e "require('./dist/guard.js')"  → no error</verify>
```

The linter returns exit 2 `verify-teeth: require-only`. The card's acceptance criterion is
"a request to a cloud-metadata host is refused." Requiring the module only proves it loads —
the guard could refuse nothing and this still passes. The author rewrites:

```
<verify>node --test guard.test.js  → 1 pass, including "refuses 169.254.169.254"</verify>
```

Now the line names the assertion that fails if the guard is absent. Re-run: exit 0.

## Edge cases

- **Manual / visual verify lines** ("dialog renders centered") — no command to grade; allowed,
  but only when genuinely non-automatable. A line tagged manual that still carries a shell
  command, an exit-code assertion or a greppable expectation is the
  **automatable-looking-manual-line** finding: hand it back to automate the check or say why
  the token is incidental. Author judgment, not a script block; negative-control's manual-skip
  residual is the runtime counterpart.
- **Multi-command verify** (`cmd-a && cmd-b`) — the whole line is linted; a weak segment
  anywhere blocks it.
- **No `<verify>` at all** — exit 3, a malformed card (`card-shape-lint.sh` reports it first,
  as `verify-count`).

## What it is NOT (stated limits)

Standing: unenforceable beyond syntax — it cannot prove a novel verify non-vacuous
(`grep -q TODO file.js` slips through) and sees neither an empty suite nor a hollow
assertion: those are runtime, layers 2 and 3. A green here is necessary, not
sufficient.

## Under ultra-goal (hands-off)

A weak Verify line is not auto-accepted. Hand the card back to task-cards to sharpen the line
(logged to the goal ledger). If the line genuinely cannot be made to name a positive
observation — the card is not yet a task — halt with evidence rather than lowering the bar.

## Anti-patterns

- Reimplementing the pattern list in prose here — the script is the single source of truth;
  this skill only invokes it and explains the fixes.
- Treating a `coverage-check` pass as a teeth pass — they check different things; a card can
  cover every criterion and still verify with `test -f`.
- Waving through a `2` "because the code obviously works" — obvious-works is exactly the
  plausible-but-wrong the gate exists to catch; sharpen the line instead.

## What enforces this

Standing: gate when it runs — `scripts/verify-teeth-lint.sh` exits non-zero on a
toothless Verify line. That it runs at all is now **observed, not gated**: every lint
appends a run record beside the card (`scripts/card-lint-record.sh`), and
`hooks/card-lint-observe.sh` warns on the run's first write when a card in the
registered set carries none. It warns and never blocks, it is keyed off the run
registering itself (a set executed without `/task-runner:run` is still unseen), and a
record proves invocation, not honesty — it closes forgetting, not evasion.
