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
| `/testing:flake-hunt [--runs N] [--shuffle "<runner flag>"] [--baseline FILE] [--update-baseline]` | Hunt and classify flaky tests — repeated runs in fixed and randomized order, set-diffed into order-dependent / non-deterministic / broken, each with its fix lane. `--baseline FILE` exits 2 only on a flake not already in that file; `--update-baseline` rewrites it |

## Hook

| Hook | Event | What it does | Standing |
|------|-------|--------------|----------|
| `protect-tests.sh` | `PreToolUse` on a write to a test path, including a Bash heredoc/echo written to one | Denies a skip/exclusive marker added with no reason on its line (`it.skip`, `test.only`, `xit`, `@pytest.mark.skip`, `markTestSkipped`, `t.Skip(`, `#[ignore]`, `@Disabled`), and a rewrite that leaves a test file with no tests. A same-line reason (`// skip: flaky on CI, #1421`) is accepted — that is the mechanism. `CC_PROTECT_TESTS=off` disables it | **gate** — `permissionDecision: "deny"`; fixtures in `scripts/__tests__/protect-tests.test.sh`. Does NOT catch a test weakened rather than skipped, nor a Bash write through an interpreter, `cp`/`mv`, a `{ …; } > f` group or a path held in a variable (the hook header lists every gap) |
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

## Mods (Claude Code ≥ 2.1.291)

Since 0.13.0 the plugin also ships a hooks module, `hooks/suggest.ts`, listed under
`modules` in `hooks/hooks.json` beside the classic hooks, which fire with or without them.

- **What.** At the end of a turn in which one test command (the same text, whitespace
  aside) has both passed and failed in this session with no successful `Write`, `Edit`,
  `MultiEdit` or `NotebookEdit` between those runs, the prompt box offers
  `/testing:flake-hunt` as a next-step suggestion: Tab accepts it, and nothing runs until
  you send it. A fail, then a fix, then a pass is not a flake and offers nothing.
- **Test commands** are `npm`/`pnpm`/`yarn`/`bun` `test` (with or without `run`), `vitest`,
  `jest`, `pytest`, `phpunit`, `pest`, `artisan test`, `go test`, `cargo test`, `rspec`,
  `mocha`, `playwright test` and `dotnet test`, a path prefix allowed
  (`vendor/bin/pest`). A change made through `Bash` (`sed -i`, `git checkout`) is not seen
  as an edit, so a fix applied that way can read as a flake.
- **When it stays silent.** While a phase sentinel is live (a taskmaster or task-runner run
  owns the turn). Once shown for a command, not again for that command in this session.
- **Off switch.** `CC_SUGGEST=off`, environment only, silences this and every other
  next-step suggestion of this marketplace together.
- **CLI.** With mods off in the host, on a CLI below 2.1.287 (which loads no module), on
  2.1.288-2.1.290, or with `CC_SUGGEST=off`, the module offers nothing and the classic hooks
  work as before. On CLI 2.1.287 with mods on, the module still registers its `tool.call`
  hook (the version check runs inside it), and that CLI's own bug — a plugin's `tool.call`
  hook breaking Bash and file search in worktree subagents, fixed in 2.1.288 — applies even
  with `CC_SUGGEST=off`: upgrade the CLI or turn mods off.
- **Limits.** The prompt box holds one suggestion: when another plugin offers one at the
  same turn end the later replaces the earlier, and Claude Code's own suggestion is not
  suppressed. What was shown is kept in memory, so a new session offers it again. A failed
  command is one the CLI answers as an error; how a non-zero exit reaches a hook was not
  observed live (**recorded**, from the mods API's result shape).
- **Standing.** The conditions above are a **gate**: `tests/suggest.test.ts` runs under
  `claude plugin test` in CI. Whether a flagged pair is a real flake is the hunt's job.

## Pairs well with

- **task-runner** — its verify commands are only as good as the tests behind them
- **security** — findings often land as regression tests
