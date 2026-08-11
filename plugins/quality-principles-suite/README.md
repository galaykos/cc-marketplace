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
| Plugins | 6 | 9 |
| Standing | carries a mechanism — a Stop gate, a pre-write deny, a write-time warn, a router | advisory only |
| Take it when | you want quality rules that bite | you want the disciplines and will apply them yourself |

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install quality-principles-suite@cc-plugins-marketplace
```

## What's included

- **approaches** — compare structurally different approaches, build-vs-buy, GoF pattern selection *and rejection*, sizing, rollout planning, and a blind four-persona opinion round: `/approaches:compare`, `/approaches:pattern`, `/approaches:build-vs-buy`, `/approaches:size`, `/approaches:rollout`, `/approaches:opinions`
- **security** — OWASP-aligned code review, API auth, data privacy, and design-phase threat modeling, plus `/security:review`
- **a11y** — WCAG 2.2 AA audit, one line per violation with the concrete fix, plus `/a11y:audit`
- **debugging** — systematic root cause with evidence before any fix, plus `/debugging:debug`
- **performance** — measure-first hotspot and cache-correctness review, plus `/performance:review`
- **resilience** — timeouts, safe retries, degradation paths, plus the merged error-handling (catches, cause chains) and concurrency (races, idempotency, locks) disciplines: `/resilience:review`, `/resilience:error-review`, `/resilience:concurrency-review`
- **packages** — composer/npm dependency hygiene and security-audit triage, plus `/packages:audit`
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
