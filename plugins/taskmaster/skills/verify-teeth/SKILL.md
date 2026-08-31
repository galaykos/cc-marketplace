---
name: verify-teeth
description: Use after coverage-check in the task-cards tail — lints every card's Verify line for a named assertion that would fail were the feature absent, blocking compile-only, existence-only, `|| true`, and bare "suite passes" forms.
---

# Verify teeth

A card closes when its `**Verify:**` command exits 0. If that command passes whether the
feature works or not — `test -f out.js`, `node -e "require('./x')"`, `npm test` over an empty
suite, anything ending `|| true` — then "green" proves nothing, and broken code ships marked
done. That is the root cause behind untested, non-combat-ready output: the gate that was
supposed to prove the work is itself hollow. This skill makes the Verify line earn its green
at authoring time, before a single line of implementation is written.

## Where it sits — layer 1 of the three-layer defense

Standing: recorded — owns layer 1 only: a syntactic denylist over the Verify *line
text*, before any code exists. Layers 2 and 3 run during execution and belong to
`task-runner`, which owns the full map: `task-runner:behavioral-gate` § "The
three-gate defense".

## When it runs

In the task-cards tail, immediately after `coverage-check` and before the task-runner
handoff. `coverage-check` grades whether each success criterion is *claimed* by some card's
acceptance text; it never inspects the Verify line's strength. verify-teeth is the missing
half — it grades the Verify line itself. The two are complementary: run both, in that order,
and neither substitutes for the other.

## What it does

For every card in the run, invoke the shipped denylist linter:

```
${CLAUDE_PLUGIN_ROOT}/scripts/verify-teeth-lint.sh --card <card-file>
```

The script reads the card's `**Verify:**` line and exits:

- **0** — the line has teeth (names a specific test / assertion / observable).
- **2** — weak: it prints `verify-teeth: <reason>` naming the matched pattern.
- **3** — usage error (no Verify line found / bad args).

On a `2`, block the card: report the reason and the matching fix below; do not proceed to
the handoff until the author sharpens the line. Re-run the linter after each fix until it
exits 0. The script is the single source of truth for the pattern set — invoke it; never
re-implement the list in prose here.

## The weak forms it blocks (and the fix)

- `existence-only` (`test -f`, `test -e`, `ls` as the whole check) → run the code and assert
  an observable *value*, not merely that a file exists.
- `|| true` / `; true` → never swallow the exit code; a check that cannot fail is not a check.
- `require-only` / `import-only` (`node -e "require(...)"`, `python -c "import ..."` with no
  assertion) → an import proves the module parses, not that it behaves; add an assertion.
- `compile-only` (`tsc --noEmit`, `-fsyntax-only`, `go build` as the whole check) → compiling
  is not behaving; exercise the changed code path. **Project-references caveat:** on the very
  common root of `"files": []` + `"references"` (the Vite React-TS scaffold, most monorepos)
  `tsc --noEmit` is not merely weak, it is **vacuous** — tsc is handed zero files and exits 0
  having checked nothing, so the line is a guaranteed green even for the type errors it looks
  like it covers. `tsc -b` is the check that runs; the linter prints this as a NOTE when it
  spots that shape in the working directory's `tsconfig.json`, and a NOTE is advice, not a
  block: it reads line text, so it cannot see which config a build actually uses.
- `bare-suite-pass` (a runner invoked with no named test / assertion token) → name the new
  test or the asserted outcome, e.g. `pytest -k reject_malicious_host asserts 422`.

A line that names its assertion — `jest -t "rejects bad host" asserts throw`, or
`npm test -- invoice → all pass, including new test totals_rounds_half_up` — passes.

## Worked example

A card lands with:

```
**Verify:** node -e "require('./dist/guard.js')"  → no error
```

The linter returns exit 2 `verify-teeth: require-only`. The card's acceptance criterion is
"a request to a cloud-metadata host is refused." Requiring the module only proves it loads —
the guard could refuse nothing and this still passes. The author rewrites:

```
**Verify:** node --test guard.test.js  → 1 pass, including "refuses 169.254.169.254"
```

Now the line names the assertion that fails if the guard is absent. Re-run: exit 0.

## Edge cases

- **Manual / visual verify lines** ("dialog renders centered") — a card whose verification is
  a human observation has no command for the linter to grade; the script reports it and the
  line is allowed, but such cards must still be genuinely non-automatable, not an escape
  hatch for skippable executable checks. Name the **automatable-looking-manual-line** finding
  when a line tagged manual/visual nonetheless carries a shell command, an exit-code
  assertion, or a greppable expectation — it is contradicting its own tag. Hand it back to
  the author to either automate the check or state why the automatable-looking token is
  incidental. This is author-judgment guidance, not a syntactic block the script performs
  (see "What it is NOT"); the runtime counterpart is negative-control's manual-skip residual.
- **Multi-command verify** (`cmd-a && cmd-b`) — the whole line is linted; a weak segment
  anywhere (e.g. a trailing `|| true`) blocks it.
- **A card with no Verify line at all** — exit 3; that is a malformed card, not a teeth pass.

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
