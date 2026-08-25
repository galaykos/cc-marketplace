# testing

Testing best practices: test pyramid and what to actually test, Pest/PHPUnit and
Vitest/Jest idioms, Playwright/Dusk e2e discipline, factories and fixtures,
mocking boundaries, flaky-test causes, coverage traps.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install testing@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/testing:review [files-or-diff]` | Review tests (and untested production changes) against the testing-best-practices skill; findings as `path:line — problem — fix` by severity |
| `/testing:flake-hunt [--runs N] [--shuffle "<flag>"] [--baseline FILE]` | Hunt and classify flaky tests — repeated runs in fixed and randomized order, set-diffed into order-dependent / non-deterministic / broken, each with its fix lane |

## Hook

| Hook | Event | What it does | Standing |
|------|-------|--------------|----------|
| `test-shape.sh` | `PostToolUse` on `Edit\|Write\|MultiEdit` of a test path | Reads the written test file's **body** and names blocks that may not earn their place: assertion-free blocks, three-or-more near-identical blocks differing only in a literal, and reflection reaches into a non-public member. At most 4 findings per file, 3 files per context. | advisory |

It reports locations, never a verdict, and it deliberately does **not** score a
test count or a test:code ratio — there is no correct ratio, so a threshold would
fire on legitimately dense work and wave through a bloated suite sitting under it.
That reasoning is on the record in the `lean` plugin's `cost-model` skill and in
`testing-best-practices/references/proportionality.md`; naming three specific
shapes at a line is a different claim from scoring a number.

Silence it with `CC_TEST_SHAPE=off`, or `CC_REMIND=off` for every advisory nudge
in this marketplace.

## Example

```bash
/testing:review tests/Feature/OrderExportTest.php
/testing:review            # reviews the current diff
```

The skill also auto-triggers when writing or refactoring tests, keeping advice
pinned to the test stack actually installed (Pest vs PHPUnit, Vitest vs Jest —
resolved from lockfiles, not assumed).

A second skill, **tdd**, carries the workflow: red-green-refactor with
"fail for the right reason" verification, one behavior per cycle, and the
red-green regression proof for bug fixes (test must fail on unfixed code —
revert-fail-restore when the fix already exists). Taskmaster card acceptance
criteria double as the test list.

## Pairs well with

- **task-runner** — its verify commands are only as good as the tests behind them
- **security** — findings often land as regression tests
