# taskmaster-suite

Meta-bundle: the clarification-to-execution pipeline and only what it dispatches
into — taskmaster planning, task-runner execution, orchestration,
code-architecture, approaches, stack-scan and skill-router, plus the ui-ux,
testing and security lanes its cards route to. Trimmed from 32 members to 10 on
2026-08-31 so the bundle fits the host's skill-listing budget; see "What's
excluded, and why". Uninstalls cleanly:
`/taskmaster-suite:uninstall` removes the bundle and prunes the plugins it
auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install taskmaster-suite@cc-plugins-marketplace
```

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle still overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **~15,500 chars** (LC_ALL=C bytes — the marketplace's deterministic measure, ~1% above what the CLI counts) — over
budget, the host reduces entries to name-only in priority order, silently, so
skills stop being reachable without any error.

On the 1M-context tier (30,000 chars) this bundle fits with room to spare. If you
run the default 200k window, add to the `settings.json` of the project where you
use this bundle:

```json
{ "skillListingBudgetFraction": 0.03 }
```

That raises the listing budget to 18,000 chars at 200k. The cost is real but
small: the fraction is a ceiling, not a purchase — it only admits description
text that was previously being evicted.

## What's included

- **taskmaster** — clarification-to-spec pipeline: grill, brainstorm, red-team, coverage, task cards (`/taskmaster:task`)
- **task-runner** — executes task lists with scope lock and bounded verify-fix loops (`/task-runner:run`)
- **orchestration** — delegation contracts and verification panels for fan-outs
- **code-architecture** — plan-before-code, SOLID/YAGNI audits, work verification
- **approaches** — compares structurally different approaches before implementation; also owns the merged build-vs-buy, estimation, rollout, and pattern-selection disciplines
- **stack-scan** — inventories what is actually installed before version-dependent advice
- **skill-router** — hook that auto-loads the matching best-practice skill on edit
- **ui-ux** — ui-ux engineer + reviewer agents and `/ui-ux:theme` that the pipeline's visual cards route to
- **testing** — TDD discipline and test review against testing best practices
- **security** — security review and threat modeling

## What's excluded, and why

**The bundle was cut from 32 members to 10 on 2026-08-31, and the reason is a
ceiling that is not ours.** Claude Code budgets its skill listing by the formula
in the "Context-window requirement" section above — **6,000 chars on the default
200k window, 30,000 at 1M** — and past it the host **drops descriptions, leaving
names only**, with the surviving set varying between identical reloads. At 32
members this bundle cost ~32,700 entry-chars: over even the 1M budget, and 5.4x
the 200k floor. The overflow was not a token cost — dropped text is never sent
and never charged — it was **reachability**, and it was paid by every member,
including the pipeline core. At 10 members (~15,500 entry-chars) it fits at 1M
outright and at 200k with the settings line above. (An earlier revision of this
section claimed a "~15,000-char absolute default" and that "14,581 chars fit" —
both derived from a cap that turned out not to exist; superseded by the measured
formula, `rationale/2026-08-31-token-cost-review.md` addendum.) The measurement
and the cost model are in `rationale/2026-08-31-token-cost-review.md`.

Inclusion test, in that order of precedence: a plugin stays when the pipeline
hard-wires it into the default flow. ui-ux is in for exactly that reason — the
closed agent-tag set routes visual cards to its engineer/reviewer agents, and
specs bind `/ui-ux:theme`; without it those cards degrade to generic routing.
testing and security stay because task cards dispatch into both.

**Everything cut is still shipped and still works — install it directly.** The
22 removed: a11y, api-design, api-docs-first, brain, claude-authoring,
code-review, comment-discipline, database, debugging, devops,
git-workflow, hindsight, lean, observability, packages, performance,
plugin-scout, resilience, sql, system-design, web-dev. Several are excellent and
several are near-core — `code-review` and `git-workflow` especially — but a
bundle that cannot surface its own members' descriptions is not doing them a
favour by listing them. Take the ones your work actually needs.

Still excluded for the older reasons: **design-preview** and **shadcn-studio**
— the two optional full-fidelity escalations above taskmaster's built-in mockup
preview, both "when installed" upgrades and stack-specific; **laravel** and the
other stack plugins — stack-specific; **secret-scanning** — hook-heavy and
behavior-changing, install it deliberately; **ultra-deep-research** — heavy
research harness, opt-in.

## Uninstall

| Command | What it does |
|---------|--------------|
| `/taskmaster-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **php-suite** — PHP/Laravel/Inertia stack specifics the bundle leaves out
- **frontend-suite** — React/Vue/TS framework specifics left out of this bundle; its sibling **craft-suite** carries the design-preview/shadcn-studio fidelity escalations
