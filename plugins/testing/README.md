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

## Example

```bash
/testing:review tests/Feature/OrderExportTest.php
/testing:review            # reviews the current diff
```

The skill also auto-triggers when writing or refactoring tests, keeping advice
pinned to the test stack actually installed (Pest vs PHPUnit, Vitest vs Jest —
resolved from lockfiles, not assumed).

## Pairs well with

- **task-runner** — its verify commands are only as good as the tests behind them
- **security** — findings often land as regression tests
