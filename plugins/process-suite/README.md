# process-suite

Meta-bundle: the engineering-process category in one install — git workflow,
approach deliberation, hindsight mining, docs upkeep, subagent orchestration,
task execution, stack scanning, plugin scouting, and skill routing. Uninstalls
cleanly: `/process-suite:uninstall` removes the bundle and prunes the plugins
it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install process-suite@cc-plugins-marketplace
```

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle still overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **~8,391 chars** (LC_ALL=C bytes — the marketplace's deterministic measure, ~1% above what the CLI counts) — over
budget, the host reduces entries to name-only in priority order, silently, so
skills stop being reachable without any error.

On the 1M-context tier (30,000 chars) this bundle fits with room to spare. If you
run the default 200k window, add to the `settings.json` of the project where you
use this bundle:

```json
{ "skillListingBudgetFraction": 0.02 }
```

That raises the listing budget to 12,000 chars at 200k. The cost is real but
small: the fraction is a ceiling, not a purchase — it only admits description
text that was previously being evicted.

## What's included

- **git-workflow** — worktree isolation and the branch-finish protocol
  (verify, merge/PR/park, clean up), plus `/git-workflow:finish`
- **approaches** — 2-3 structurally different approaches with a kill-trigger
  before implementing, plus the merged build-vs-buy, estimation, rollout, and
  pattern-selection disciplines: `/approaches:compare`, `/approaches:opinions`,
  `/approaches:build-vs-buy`, `/approaches:size`, `/approaches:rollout`,
  `/approaches:pattern`
- **hindsight** — mines session transcripts for cross-session friction,
  applied only on approval, plus `/hindsight:harvest`
- **api-design** — REST/GraphQL/gRPC design review and spec-first scaffolding, docs
  verified before integration code, and the docs-upkeep drift scan after a change,
  plus `/api-design:check` and `/api-design:drift`
- **orchestration** — delegation contracts and verification panels for
  subagent fan-outs, plus `/orchestration:review`
- **task-runner** — scope-locked task execution with bounded verify-fix loops,
  plus `/task-runner:plan` and `/task-runner:run`
- **stack-scan** — inventory of installed runtimes, frameworks, and packages
  vs manifests, plus `/stack-scan:report`
- **plugin-scout** — stack-matched marketplace plugin suggestions, plus
  `/plugin-scout:suggest`
- **lean** — prices every line, test, comment, and file as a debit, so the
  smallest change that satisfies the requirement is the one that ships
- **skill-router** — hook that auto-loads the matching best-practice skill on
  edit

| Command | What it does |
|---------|--------------|
| `/process-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **taskmaster** — turns vague requests into specs and task cards that
  task-runner then executes
- **quality-suite** — the code-quality review category alongside this
  process discipline
