# quality-principles-suite

Meta-bundle: the code-quality disciplines that **advise**. Every plugin here is
read-only counsel — a skill a reviewer or engineer applies with judgment. Nothing
in this bundle can fail a build, block a write, or hold a turn.

That is the whole reason it exists separately. `quality-suite` used to carry all
fourteen quality plugins together, so a project that wanted the enforcing half paid
for the advisory half's always-on description context whether or not it used it.
The split lets you take either, or both. testing joined this side in 0.2.0: it
ships review skills and no hook, which by the split's own rule makes it advisory.

| | `quality-suite` | this bundle |
|---|---|---|
| Plugins | 8 | 9 |
| Standing | carries a mechanism — a Stop gate, a pre-write deny, a write-time warn, a router | advisory only |
| Take it when | you want quality rules that bite | you want the disciplines and will apply them yourself |

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install quality-principles-suite@cc-plugins-marketplace
```

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle still overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **~8,020 chars** (LC_ALL=C bytes — the marketplace's deterministic measure, ~1% above what the CLI counts) — over
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

- **approaches** — compare structurally different approaches, build-vs-buy, GoF pattern selection *and rejection*, sizing, rollout planning, and a blind four-persona opinion round: `/approaches:compare`, `/approaches:pattern`, `/approaches:build-vs-buy`, `/approaches:size`, `/approaches:rollout`, `/approaches:opinions`
- **security** — OWASP-aligned code review, API auth, data privacy, and design-phase threat modeling, plus `/security:review`
- **debugging** — systematic root cause with evidence before any fix, plus `/debugging:debug`
- **performance** — measure-first hotspot and cache-correctness review, plus `/performance:review`
- **resilience** — timeouts, safe retries, degradation paths, plus the merged error-handling (catches, cause chains) and concurrency (races, idempotency, locks) disciplines: `/resilience:review`, `/resilience:error-review`, `/resilience:concurrency-review`
- **stack-scan** — installed-stack inventory (`/stack-scan:report`) and composer/npm dependency hygiene with security-audit triage (`/stack-scan:audit`)
- **observability** — structured logs, correlation IDs, metrics without cardinality bombs, plus `/observability:review`
- **testing** — test pyramid, mocking boundaries, flaky-test causes, TDD workflow, plus `/testing:review` and `/testing:flake-hunt`

| Command | What it does |
|---------|--------------|
| `/quality-principles-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Honest limitation

Advisory means advisory. These plugins produce findings a person or an agent then
has to act on; none of them is a gate. If you want the quality rules that actually
stop something, that is `quality-suite`, and installing both is the normal case —
the split is about being able to *choose*, not a recommendation to take only one.

## Pairs well with

- **quality-suite** — the enforcing half; the two were one bundle until 0.7.0
- **taskmaster-suite** — the spec and task-card pipeline whose output these reviews read
- **git-workflow** — full-suite verification before merge/PR when a branch finishes
