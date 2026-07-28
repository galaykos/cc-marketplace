# quality-suite

Meta-bundle: the code-quality plugins that carry a **mechanism** — something that
gates, blocks, warns at write time, or routes — in one install. Review and code
smells, architecture principles with the evidence-at-claim Stop gate, testing,
comment discipline, secret-leak prevention, and file-aware skill auto-routing.
Uninstalls cleanly: `/quality-suite:uninstall` removes the bundle and prunes the
plugins it auto-installed.

The eight advisory disciplines this bundle used to carry — security, a11y,
debugging, performance, resilience, packages, observability, approaches — moved to
**quality-principles-suite** in 0.5.0. They were never gates, and bundling them here
meant a project wanting enforcement paid for their always-on description context
too. Install both if you want what the old bundle was; the split exists so that is
a choice.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install quality-suite@cc-plugins-marketplace
```

## What's included

- **code-review** — correctness bugs, code smells, and convention drift on any diff or PR, plus `/code-review:review`
- **code-architecture** — plan-before-code, SOLID, YAGNI, and evidence-based verification via `/code-architecture:plan`, `/code-architecture:solid`, `/code-architecture:yagni`, `/code-architecture:verify`
- **testing** — test pyramid, mocking boundaries, flaky-test causes, TDD workflow, plus `/testing:review`
- **secret-scanning** — PreToolUse hook that blocks high-confidence secrets at write time, plus `/secret-scanning:scan`
- **skill-router** — hook that auto-loads the matching best-practice skill on edit
- **comment-discipline** — routes every fact to the artifact that cannot lie about it and spends comments only where nothing else can hold them; a PostToolUse hook warns on all five noise categories and a PreToolUse lane denies the two strictest before the write, plus `/comment-discipline:review`

| Command | What it does |
|---------|--------------|
| `/quality-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **quality-principles-suite** — the advisory half, split out of this bundle in 0.5.0
- **taskmaster-suite** — spec and task-card pipeline whose output these reviews gate
- **git-workflow** — full-suite verification before merge/PR when a branch finishes
