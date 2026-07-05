# Changelog

All notable changes to this marketplace are documented here. The version below
is the marketplace `metadata.version`; individual plugins carry their own
version in their `plugin.json`.

## [0.14.0] - 2026-07-05

### Added

- **web-dev** 0.1.0: web-developer worker agent — generalist web implementation (routing, REST/API integration, forms and validation, state management, SSR/CSR trade-offs, accessibility baseline); stack-agnostic, defers to per-framework review plugins
- **system-design** 0.1.0: system-architect worker agent — service boundaries, data modeling, scaling paths, caching layers, sync vs async decisions with documented trade-offs; complements code-architecture's code-level scope
- **devops** 0.1.0: devops-engineer worker agent — CI/CD pipeline design, Dockerfile/compose, Kubernetes manifests, deploy strategies with stated rollback paths, observability, secrets discipline
- **database** 0.1.0: database-engineer worker agent — schema design, additive migrations, indexing strategy, query optimization, connection pooling; defers dialect review to sql/mysql/mariadb/postgresql
- **performance** 0.1.0: performance-engineer worker agent — measure-first profiling, bundle size, caching, Core Web Vitals, N+1 elimination, load testing; before/after evidence required
- **claude-authoring** 0.1.0: authoring guides for skills, agents, hooks, and plugins; routine-detector skill that proposes capturing repetitive work as a project skill; /claude-authoring:new-skill, /claude-authoring:new-agent, /claude-authoring:new-hook, /claude-authoring:new-plugin scaffold commands
- **code-review** 0.1.0: stack-agnostic review — /code-review:review command, proactive code-reviewer agent, code-smells skill (bloaters/couplers/change-preventers/dispensables + when-not-a-smell judgment); defers structure to code-architecture, depth to security, idioms to per-stack plugins
- **approaches** 0.1.0: approach-deliberation skill (2-3 structurally different candidates, honest trade-off table, pick with kill-trigger — kills first-idea anchoring), strategy-catalog skill (tracer bullet, walking skeleton, spike, strangler fig, inversion, Polya, simplest-thing, top-down/bottom-up, explain-first — each mapped to the risk it beats), /approaches:compare command
- **decision-records** 0.1.0: ADR skill with template, status lifecycle (proposed/accepted/superseded), immutable-history rule, and reading discipline (standing ADRs bind, revisit-when reopens); /decision-records:new
- **retrospective** 0.1.0: evidence-first retro protocol with three sinks (CLAUDE.md candidates proposed never silently written, skill suggestions via routine-detector, process tweaks); /retrospective:run
- **build-vs-buy** 0.1.0: gate-zero check for generic capability — shelf order (stdlib → installed deps → registry), candidate health table, take/wrap/write verdict, never-hand-roll list, wrap-thinness discipline; /build-vs-buy:check
- **rollout** 0.1.0: per-feature rollout planning — flag discipline with removal dates, backward-compat windows, expand-migrate-contract sequencing, staged exposure with gate metrics, rollback path stated before ship; /rollout:plan
- **resilience** 0.1.0: failure-mode design at every integration point — explicit timeouts with budget propagation, idempotency-first retries with backoff+jitter, circuit breaking, graceful degradation, bounded queues, delivery semantics; /resilience:review
- **docs-upkeep** 0.1.0: documentation drift prevention — drift catalog (README, changelog, API docs, config, ADR links), same-change rule, one-place-per-fact placement ladder, freshness signals; /docs-upkeep:check
- **estimation** 0.1.0: S/M/L/XL sizing with reference-class anchors, uncertainty multipliers, split triggers, size-to-done rule, estimate-vs-actual retro loop; weights align with task-runner parallel-planning; /estimation:size
- **a11y** 0.1.0: WCAG 2.1 AA audit — semantics-first, ARIA first-rule, keyboard operability, focus management, contrast ratios, forms, media, touch targets; /a11y:audit
- **everything** 0.1.0: meta-bundle — one install auto-installs all 43 plugins via the dependencies field
- **taskmaster-suite** 0.1.0: meta-bundle — taskmaster workflow plus the 30 stack-agnostic plugins (task pipeline, approach deliberation, decision records, retrospectives, build-vs-buy, rollout, resilience, docs upkeep, estimation, a11y, engineering discipline, UI/UX, code review, worker agents); excludes framework/dialect plugins

### Changed

- **taskmaster** 0.4.0: pipeline outputs move from docs/ to taskmaster-docs/ (specs and task cards) — no collision with a project's own docs/ or superpowers' docs/plans
- **claude-authoring** (within 0.1.0): authoring-skills guide gains the handoff-offer convention — completed skills/commands offer the logical next command as a selectable choice (AskUserQuestion), never homework to type; bare commands only when headless. Applied across task-runner:plan, approaches:compare, build-vs-buy:check, retrospective:run, rollout:plan, resilience:review, estimation:size, a11y:audit
- **task-runner** 0.3.0: parallel-planning skill + /task-runner:plan — computes the subagents-vs-inline decision from the task list itself (dependency levels, disjoint-file groups, critical path, ≥1.5x adjusted-speedup gate, ≤6-agent cap, replan rules); recommendation is optional, user picks the mode
- **ui-ux** 0.4.0: ui-ux-engineer worker agent — implements layouts, responsive breakpoints, spacing/color systems, element placement alongside the existing ui-ux-reviewer
- **testing** 0.3.0: test-engineer worker agent — authors and runs unit/integration/e2e tests, coverage-gap analysis, fixtures and boundary-only mocking
- **security** 0.2.0: security-engineer worker agent — implements defensive fixes: auth flows, OWASP remediations, headers/CSP, dependency-audit remediation

## [0.13.0] - 2026-07-05

### Added

- **code-architecture** 0.3.0: surgical-coding skill — always-on discipline for everyday edits outside the pipeline, adapted from Andrej Karpathy's LLM-coding guidelines (multica-ai/andrej-karpathy-skills, MIT): surface assumptions and competing interpretations before coding, every changed line traces to the request, the orphan rule (delete your own orphans incl. tests, flag pre-existing dead code instead), simplicity floor, vague-ask → verifiable-goal transformation with step→verify plans

## [0.12.0] - 2026-07-05

Superpowers parity batch — ports the remaining high-value workflows from obra/superpowers (MIT) into the suite, rewritten in house voice, so the marketplace stands alone without it.

### Added

- **taskmaster** 0.3.0: brainstorm skill + `/taskmaster:brainstorm` — fuzzy idea → approved design doc (one question at a time, decomposition of oversized ideas, 2–3 explored approaches, sectional approval, spec self-review, user gate), then approval-gated handoff into the grill pipeline with the design pre-seeding the ledger
- **debugging** plugin: systematic-debugging skill + `/debugging:debug` — root cause before any fix; reproduce → first error → what changed → one falsifiable hypothesis → smallest experiment; bisection; three-failed-fixes stop rule mirroring task-runner's park rule
- **git-workflow** plugin: worktree-isolation, branch-completion (full-suite gate → evidence → merge/PR/keep/discard with cleanup), and review-exchange (self-review before requesting; verify feedback technically before implementing) + `/git-workflow:finish`
- **testing** 0.2.0: tdd skill — red-green-refactor with fail-for-the-right-reason verification, red-green regression proof for bug fixes (revert-fail-restore), test-list burn-down, taskmaster acceptance criteria as the test list

### Covered without porting

writing-plans/executing-plans (taskmaster cards + task-runner), verification-before-completion (task-runner evidence discipline), dispatching-parallel-agents/subagent-driven-development (task-runner parallel groups + re-verification)

## [0.11.0] - 2026-07-05

### Added

Interactive artifacts across the suite — closing "how it works" vs "how it should work" gaps with things you can look at and click:

- **code-architecture** 0.2.0: structural plans render a current-vs-target architecture diagram (two SVG panels, current drawn from code evidence with file citations) on the live preview URL; target approved before the task sequence
- **task-runner** 0.2.0: live run board — auto-reloading HTML view of the task index (statuses, current task, evidence tails, backlog), regenerated at every status flip; the index stays the single source of truth
- **dev-env** 0.2.0: topology diagram before YAML — proposed services, connections, ports, and volumes as SVG alongside the service-plan table
- **api-design** 0.2.0: contract preview artifact — proposed endpoints with real example payloads and problem+json error bodies as a live page, approved before implementation

## [0.10.1] - 2026-07-05

### Changed

- **taskmaster** 0.2.1: pipeline no longer ends by printing a command — when task-runner is installed it asks "Start execution now?" and on approval invokes the task-execution skill on the fresh `00-INDEX.md` directly; manual `/task-runner:run` remains the fallback (decline, headless, or task-runner absent)

## [0.10.0] - 2026-07-05

### Added

- **taskmaster** 0.2.0: scales to whole experiences — new experience-walkthrough skill assembles accepted visual picks into one interactive clickable demo (screens, state toggles, failure exits) on the live preview URL and walks the user through it with a task script before the spec freezes; grill gains big-task slicing (decompose into screens/flows, per-slice grilling, cross-slice contract rows); task-cards gains milestone grouping (independently shippable checkpoints with their own full-suite verify)

## [0.9.0] - 2026-07-05

### Added

- **ui-ux** 0.3.0: ReUI (reui.io) and Aceternity UI (ui.aceternity.com) skills — registry install discipline, owned-code rules, token/theme alignment, motion dependency and performance budgets, reduced-motion accessibility; both docs-first (no npm version to pin — the live docs page is the source of truth). `/ui-ux:review` now detects and reviews both.

## [0.8.0] - 2026-07-05

### Added

- **meta-api** plugin: Meta (Facebook) developer platform navigator — always-current Graph API version from the changelog, predefined doc-link map per product (Graph, Pages, Instagram, WhatsApp, Messenger, Marketing), platform conventions (tokens, fields, cursor pagination, error codes, webhooks), required-permissions answers with Standard/Advanced access and App Review awareness (`/meta-api:check` + reminder hook)

## [0.7.1] - 2026-07-05

### Changed

- **inertia** 0.2.0: adapter-aware — advice now pins to the installed adapter (`@inertiajs/vue3`, `@inertiajs/react`, or `@inertiajs/svelte`) and matches its idiom instead of assuming Vue

## [0.7.0] - 2026-07-05

### Added

- **ui-ux** 0.2.0: shadcn-theming skill and `/ui-ux:theme` command — design a shadcn/ui token set (light + dark, contrast-checked) and iterate on one always-live preview URL showing swatches and real component mockups; applies to `globals.css` only after a confirmed diff
- ui-ux plugin README

## [0.6.0] - 2026-07-05

### Added

- **testing** plugin: test pyramid, Pest/PHPUnit and Vitest/Jest idioms, Playwright/Dusk e2e discipline, mocking boundaries, flaky-test causes (`/testing:review`)
- **security** plugin: OWASP-aligned defensive review mapped to PHP/Laravel and JS/Vue (`/security:review`)
- **typescript** plugin: strict-mode discipline, narrowing over assertions, runtime validation at boundaries (`/typescript:review`)
- **inertia** plugin: Inertia.js best practices for Laravel + Vue (`/inertia:review`)
- **api-design** plugin: REST resource naming, status codes, pagination, versioning, RFC 9457 errors (`/api-design:review`)
- **dev-env** plugin: scan dependencies and generate a matching docker-compose.yml + Dockerfile (`/dev-env:init`), audit existing docker files (`/dev-env:review`)
- `/taskmaster` shorthand command (alias of `/taskmaster:task`)
- MIT LICENSE
- GitHub Actions workflow running `scripts/validate.sh` on push and PR
- Cross-reference check in `scripts/validate.sh`: `/plugin:command` mentions must resolve to a listed plugin
- Per-plugin READMEs with usage examples (taskmaster, task-runner, stack-scan, and all six new plugins); root README slimmed to summaries + links
- This changelog

### Changed

- taskmaster pipeline runs stack-scan inventory first when installed; final output names `/task-runner:run` when available

## [0.5.0] - 2026-07-04

### Added

- Database plugins: sql, mysql, mariadb, postgresql
- task-runner plugin: disciplined task execution with bounded verify-fix loops
- stack-scan plugin: required-vs-installed version inventory

### Changed

- Renamed grill-me plugin to taskmaster; documented the taskmaster workflow suite (stack-scan + taskmaster + task-runner + code-architecture)
- README install instructions point at github.com/galaykos/cc-marketplace

## [0.4.0] and earlier

- Initial plugins: ui-ux, react, react-native, vue2, vue3, php, laravel, livewire, code-architecture, design-patterns, api-docs-first, grill-me
