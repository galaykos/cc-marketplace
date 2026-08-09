---
description: Hunt and CLASSIFY flaky tests — repeated runs across fixed and randomized order, set-diffed into order-dependent / non-deterministic / broken, each with its fix lane.
argument-hint: [--runs N] [--shuffle "<runner flag>"] [--baseline FILE]
---

Hunt flaky tests in this project. Resolve the test command first from what the
repo actually uses — `package.json` scripts, `composer.json` scripts, a Makefile
target, `pytest`, `go test ./...` — and say which one you chose and why.

**Run the sweep in a subagent.** This command executes the whole suite N times;
at the default N that is the largest single block of tool output any command in
this marketplace produces, and none of it is the deliverable — the classification
table is. Dispatch the run with the Agent tool and keep only what it returns.
Three things the dispatch must carry, because a subagent has neither of them:

- the **resolved absolute path** — expand `${CLAUDE_PLUGIN_ROOT}` yourself and paste
  the literal path; the variable does not exist in a subagent's environment;
- the resolved test command and the runner's `--shuffle` value from the table below,
  already decided by you — the agent re-deriving them defeats the point;
- the return contract: **the script's classification block verbatim, the N used, and
  whether `--shuffle` was passed** — nothing else. No run logs, no per-test output,
  no summary prose.

Run inline instead when the suite is small enough that N runs finish in a minute or
two, or when the runner needs a TTY the subagent will not have. The apply pick in
step "Then apply" stays in THIS thread either way — a subagent cannot ask the user
anything.

Then run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/flake-hunt.sh --cmd "<that command>"`
with $ARGUMENTS appended. Always pass `--shuffle` with the runner's own
randomize flag — without it the single most common flake class, order dependence,
is not tested at all:

| Runner | `--shuffle` value |
|---|---|
| vitest | `--sequence.shuffle` |
| jest | `--randomize` |
| pytest (with pytest-randomly) | `-p randomly` |
| go test | `-shuffle=on` |
| PHPUnit / Pest | `--order-by=random` |
| RSpec | `--order random` |

Report the script's classification verbatim — the classes are the deliverable, not
the count. Three lanes, three different fixes, and guessing between them is the
failure this command exists to end:

- **order-dependent** — shared state between tests. Fix isolation, not the test.
- **non-deterministic** — clock, network or concurrency. Freeze time, stub the
  network, delete the sleep.
- **broken** — failed every run. Not flaky. Read the failure.

Then apply, on a pick: dispatch the fix list down
`testing:test-engineer → task-runner:task-executor if installed → inline`.

Two things must appear in the report even when nothing is found, because their
absence is what turns a clean run into a false assurance: the N used (a 1-in-50
flake almost never shows at N=5), and whether `--shuffle` was actually passed.
Never quarantine a test as the fix — quarantine is where a test goes to be
forgotten; it is a bounded step with an owner and a date, or it is deletion
wearing a nicer word.
