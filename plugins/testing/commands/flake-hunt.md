---
description: Hunt and CLASSIFY flaky tests — repeated runs across fixed and randomized order, set-diffed into order-dependent / non-deterministic / broken, each with its fix lane.
argument-hint: [--runs N] [--shuffle "<runner flag>"] [--seed N] [--baseline FILE] [--update-baseline]
---

Hunt flaky tests in this project. Resolve the test command first from what the
repo actually uses — `package.json` scripts, `composer.json` scripts, a Makefile
target, `pytest`, `go test ./...` — and say which one you chose and why.

Then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/flake-hunt.sh" --cmd "<that command>"`
with $ARGUMENTS appended. Always pass `--shuffle` with the runner's own
randomize flag — without it the single most common flake class, order dependence,
is not tested at all:

| Runner | `--shuffle` value | Seed flag the script adds |
|---|---|---|
| vitest | `--sequence.shuffle` | `--sequence.seed=N` |
| jest | `--randomize` | `--seed=N` |
| pytest (with pytest-randomly) | `-p randomly` | `--randomly-seed=N` |
| go test | `-shuffle=on` | `-shuffle=N` (replaces `on`) |
| PHPUnit / Pest | `--order-by=random` | `--random-order-seed=N` |
| RSpec | `--order random` | `--order rand:N` (replaces `random`) |

For these values every shuffled run gets its own seed, printed on its line, and a
failing shuffled run prints its replay command. `--seed N` (append it to the
arguments) replays exactly that order in every shuffled run: when it fails every
time, the order alone reproduces it, and that seed is the repro to fix against.
Any other `--shuffle` value runs verbatim with no seed, and the report must say
the failing order cannot be replayed.

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
When an order-dependent flake is found, the report also carries its seed.
Never quarantine a test as the fix — quarantine is where a test goes to be
forgotten; it is a bounded step with an owner and a date, or it is deletion
wearing a nicer word.
