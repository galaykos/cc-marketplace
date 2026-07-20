# taskmaster-suite

Meta-bundle: the full clarification-to-execution workflow plus its wired
companions — taskmaster planning, task-runner execution, engineering
discipline, the stack-agnostic review/process toolkit, and the pipeline's
visual path (ui-ux, design-preview). Uninstalls cleanly:
`/taskmaster-suite:uninstall` removes the bundle and prunes the plugins it
auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install taskmaster-suite@cc-plugins-marketplace
```

## What's included

- **taskmaster** — clarification-to-spec pipeline: grill, brainstorm, red-team, coverage, task cards (`/taskmaster:task`)
- **task-runner** — executes task lists with scope lock and bounded verify-fix loops (`/task-runner:run`)
- **stack-scan** — inventories what is actually installed before version-dependent advice
- **plugin-scout** — suggests marketplace plugins matched to the project's manifests
- **code-architecture** — plan-before-code, SOLID/YAGNI audits, work verification
- **design-patterns** — suggests (or rejects) a design pattern for a described problem
- **git-workflow** — branch completion, worktree isolation, review exchange
- **hindsight** — mines session transcripts for cross-session friction fixes
- **debugging** — systematic root-cause-with-evidence before any fix
- **testing** — TDD discipline and test review against testing best practices
- **security** — security review and threat modeling
- **api-design** — API contract review and spec-first scaffolding
- **api-docs-first** — checks current API docs back the integration code
- **sql** — engine-agnostic SQL discipline and review
- **dev-env** — docker-compose generation and Docker best-practice audits
- **web-dev** — generalist web-developer worker and frontend-reviewer agents
- **ui-ux** — ui-ux engineer + reviewer agents and `/ui-ux:theme` that the pipeline's visual cards route to
- **design-preview** — serves visual-decision mockups on a live preview port for full-fidelity picks
- **system-design** — system design and domain-modeling review
- **devops** — CI/CD, Kubernetes, and deploy/secret config review
- **database** — engine-agnostic schema, migration, and indexing review
- **performance** — hotspot and cache-correctness review
- **claude-authoring** — scaffolds new skills, commands, agents, hooks, plugins
- **code-review** — severity-sorted correctness and smell review of diffs
- **approaches** — compares structurally different approaches before implementation
- **retrospective** — five-minute retro routed into CLAUDE.md, skills, process
- **build-vs-buy** — existing-solution check before implementing a capability
- **rollout** — flag strategy, exposure stages, and rollback path before shipping
- **resilience** — failure-mode gap review: timeouts, retries, degradation
- **docs-upkeep** — documentation drift scan with exact fixes
- **estimation** — S/M/L/XL sizing with split recommendations
- **a11y** — WCAG 2.2 AA audits of UI code
- **packages** — dependency vulnerability and outdated-package audit
- **orchestration** — delegation contracts and verification panels for fan-outs
- **error-handling** — swallowed-exception and catch-block audits
- **concurrency** — race, idempotency, and lock-hazard audits
- **observability** — logging, correlation-ID, and silent-catch audits
- **skill-router** — hook that auto-loads the matching best-practice skill on edit
- **brain** — committed codebase map injected at session start

## What's excluded, and why

Inclusion test: a plugin joins this bundle when the pipeline hard-wires it into
the default flow — ui-ux (the closed agent-tag set and `/ui-ux:theme`) and
design-preview (visual-decisions' in-repo mockup preview) are in for exactly
that reason. Notable exclusions: **shadcn-studio** — pipeline-referenced but a standalone
opt-in staging sandbox that stands up its own dev server (the greenfield /
non-React path); **laravel** and the other stack plugins — stack-specific;
**intent-guard**, **secret-scanning**, **reuse-guard**, **compaction-advisor** —
hook-heavy and behavior-changing, install them deliberately;
**ultra-deep-research** — heavy research harness, opt-in.

## Uninstall

| Command | What it does |
|---------|--------------|
| `/taskmaster-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **php-suite** — PHP/Laravel/Livewire/Inertia stack specifics the bundle leaves out
- **frontend-suite** — React/Vue/TS framework specifics left out of this bundle
- **db-suite** — MySQL/MariaDB/PostgreSQL dialect review beyond the included sql plugin
