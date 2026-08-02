---
description: Hunt and CLASSIFY flaky tests — repeated runs across fixed and randomized order, set-diffed into order-dependent / non-deterministic / broken, each with its fix lane.
argument-hint: [--runs N] [--shuffle "<runner flag>"] [--baseline FILE]
---

Hunt flaky tests in this project. Resolve the test command first from what the
repo actually uses — `package.json` scripts, `composer.json` scripts, a Makefile
target, `pytest`, `go test ./...` — and say which one you chose and why.

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
