# quality-suite

Meta-bundle: the code-quality category in one install — review, architecture
principles, design patterns, testing, security, accessibility, debugging,
performance, resilience, dependency hygiene, observability, error handling,
concurrency safety, and secret-leak prevention. Uninstalls cleanly:
`/quality-suite:uninstall` removes the bundle and prunes the plugins it
auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install quality-suite@cc-plugins-marketplace
```

## What's included

- **code-review** — correctness bugs, code smells, and convention drift on any diff or PR, plus `/code-review:review`
- **code-architecture** — plan-before-code, SOLID, YAGNI, and evidence-based verification via `/code-architecture:plan`, `/code-architecture:solid`, `/code-architecture:yagni`, `/code-architecture:verify`
- **design-patterns** — GoF pattern selection (or rejection) for a described problem, plus `/design-patterns:suggest`
- **testing** — test pyramid, mocking boundaries, flaky-test causes, TDD workflow, plus `/testing:review`
- **security** — OWASP-aligned code review and design-phase threat modeling, plus `/security:review`
- **a11y** — WCAG 2.1 AA audit, one line per violation with the concrete fix, plus `/a11y:audit`
- **debugging** — systematic root cause with evidence before any fix, plus `/debugging:debug`
- **performance** — measure-first hotspot and cache-correctness review, plus `/performance:review`
- **resilience** — timeouts, safe retries, and degradation paths at integration points, plus `/resilience:review`
- **packages** — composer/npm dependency hygiene and security-audit triage, plus `/packages:audit`
- **observability** — structured logs, correlation IDs, metrics without cardinality bombs, plus `/observability:review`
- **error-handling** — no swallowed exceptions, typed errors, preserved cause chains, plus `/error-handling:review`
- **concurrency** — check-then-act races, idempotency, distributed-lock pitfalls, plus `/concurrency:review`
- **secret-scanning** — PreToolUse hook that blocks high-confidence secrets at write time, plus `/secret-scanning:scan`

| Command | What it does |
|---------|--------------|
| `/quality-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **taskmaster-suite** — spec and task-card pipeline whose output these reviews gate
- **git-workflow** — full-suite verification before merge/PR when a branch finishes
- **intent-guard** — keeps the session diff aligned with the declared task intent
