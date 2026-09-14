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
| `testing:review` — **retired in 0.10.0** | `/code-review:review` loads `testing-best-practices` for any diff touching tests or untested production code, in one pass with every other matching rubric. The rubric did not change; one listing entry did |
| `/testing:flake-hunt [--runs N] [--shuffle "<runner flag>"] [--baseline FILE]` | Hunt and classify flaky tests — repeated runs in fixed and randomized order, set-diffed into order-dependent / non-deterministic / broken, each with its fix lane |

## Hook

| Hook | Event | What it does | Standing |
|------|-------|--------------|----------|
| `protect-tests.sh` | `PreToolUse` on a write to a test path | Denies a skip/exclusive marker added with no reason on its line (`it.skip`, `test.only`, `xit`, `@pytest.mark.skip`, `markTestSkipped`, `t.Skip(`, `#[ignore]`, `@Disabled`), and a rewrite that leaves a test file with no tests. A same-line reason (`// skip: flaky on CI, #1421`) is accepted — that is the mechanism. `CC_PROTECT_TESTS=off` disables it | **gate** — `permissionDecision: "deny"`; 24 assertions in `scripts/__tests__/protect-tests.test.sh`. Does NOT catch a test weakened rather than skipped |
| `test-shape.sh` | `PostToolUse` on `Edit\|Write\|MultiEdit` of a test path | Reads the written test file's **body** and names blocks that may not earn their place: assertion-free blocks, three-or-more near-identical blocks differing only in a literal, and reflection reaches into a non-public member. At most 4 findings per file, 3 files per context. | advisory |

It reports locations, never a verdict, and it deliberately does **not** score a
test count or a test:code ratio — there is no correct ratio, so a threshold would
fire on legitimately dense work and wave through a bloated suite sitting under it.
That reasoning is on the record in
`testing-best-practices/references/proportionality.md` (it was also in the `lean`
plugin's `cost-model` skill until that plugin was removed on 2026-09-14) <!-- removed-ok -->;
naming three specific
shapes at a line is a different claim from scoring a number.

Silence it with `CC_TEST_SHAPE=off`, or `CC_REMIND=off` for every advisory nudge
in this marketplace.

## Example

```bash
/code-review:review tests/Feature/OrderExportTest.php   # loads testing-best-practices
/code-review:review        # reviews the current diff, test rubric folded in
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
