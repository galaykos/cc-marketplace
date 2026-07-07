# cc-plugins-marketplace: Claude Code Plugin Marketplace

cc-plugins-marketplace is a self-hosted marketplace of best-practice plugins for Claude Code — each plugin bundles skills, commands, and agents that enforce code quality standards across your projects, from React and Vue to Laravel and beyond.

## Getting started

Three lanes in — when unsure, take the first:

1. **Start here:** run `/plugin-scout:suggest` — scans your project's manifests, suggests stack-matched and always-useful plugins in two tiers, and installs the ones you pick after confirmation.
2. **Bundle:** install `taskmaster-suite` (full taskmaster workflow + every stack-agnostic plugin, no framework/dialect plugins), `everything` (all 51 plugins), or a category bundle — `frontend-suite`, `php-suite`, `db-suite`, `quality-suite`, `process-suite`.
3. **Cherry-pick:** browse the grouped plugin tables below and install individually.

## Installation

To add the cc-plugins-marketplace marketplace to your Claude Code config:

```bash
/plugin marketplace add galaykos/cc-marketplace
```

Or with the full URL:

```bash
/plugin marketplace add https://github.com/galaykos/cc-marketplace
```

Then install individual plugins:

```bash
/plugin install <plugin>@cc-plugins-marketplace
```

For example:

```bash
/plugin install react@cc-plugins-marketplace
/plugin install laravel@cc-plugins-marketplace
/plugin install code-architecture@cc-plugins-marketplace
```

### Bundles

Meta-plugins that pull in a whole set via dependencies — one install, no picking:

```bash
# Full taskmaster workflow + every stack-agnostic plugin (task pipeline,
# engineering discipline, UI/UX, worker agents). No framework/dialect plugins.
/plugin install taskmaster-suite@cc-plugins-marketplace

# Everything in the marketplace — every plugin, all stacks.
/plugin install everything@cc-plugins-marketplace

# Or one category at a time:
/plugin install frontend-suite@cc-plugins-marketplace   # UI/UX, React, Vue, TS, Inertia, Livewire, a11y
/plugin install php-suite@cc-plugins-marketplace        # PHP, Laravel, Livewire, Inertia
/plugin install db-suite@cc-plugins-marketplace         # SQL, MySQL, MariaDB, PostgreSQL, database worker
/plugin install quality-suite@cc-plugins-marketplace    # review, testing, security, resilience, observability…
/plugin install process-suite@cc-plugins-marketplace    # git workflow, estimation, orchestration, task-runner…
```

Dependencies are resolved and installed automatically; add any framework
plugin (react, laravel, postgresql, …) individually on top as your stack
requires.

Uninstall a bundle together with its auto-installed dependencies (plugins you
installed manually are never touched; requires Claude Code 2.1.121+). Easiest:
each bundle ships its own cleanup command — run `/taskmaster-suite:uninstall`
or `/everything:uninstall` from inside Claude Code (confirms, then uninstalls
the bundle and prunes its dependencies). CLI equivalent:

```bash
claude plugin uninstall taskmaster-suite --prune
claude plugin uninstall everything --prune
claude plugin prune --dry-run   # or: preview orphaned auto-deps anytime
```

Note: uninstalling from the /plugin menu inside Claude Code does NOT prune —
dependencies stay installed. Run `claude plugin prune` from a terminal
afterwards to sweep the orphans.

## Plugins

### Frameworks & stacks

| Plugin | Description | Commands |
|--------|-------------|----------|
| **[ui-ux](plugins/ui-ux/README.md)** | UI/UX best practices: shadcn/ui, ReUI, Aceternity UI, Tailwind, CSS3, Bootstrap, CSS Grid, Flexbox + shadcn theme builder with live colour preview + ui-ux-reviewer & ui-ux-engineer agents | `/ui-ux:review`, `/ui-ux:theme` |
| **react** | React: hooks, render/memo, state management, patterns | `/react:review` |
| **react-native** | React Native: list performance, navigation, platform code, animations | `/react-native:review` |
| **vue2** | Vue 2.7: Composition API, reactivity, migration readiness | `/vue2:review` |
| **vue3** | Vue 3: script setup, composables, ref/reactive, Pinia | `/vue3:review` |
| **php** | PHP: strict types, === discipline, PSR conventions, version-aware 8.1–8.5 leverage map, exceptions, boundary security | `/php:review` |
| **laravel** | Laravel: Eloquent N+1, form requests, service layer, queues, policies | `/laravel:review` |
| **livewire** | Livewire 3: components, wire:model, performance, Alpine interop | `/livewire:review` |
| **[javascript](plugins/javascript/README.md)** | Vanilla JS: version-aware ES feature floors, === and coercion traps, ESM vs CommonJS interop, async correctness + event loop, this-binding & closures/leaks, boundary validation, BigInt, prototype-pollution safety | `/javascript:review` |
| **[typescript](plugins/typescript/README.md)** | Strict mode floor, any vs unknown, narrowing over assertions, satisfies, runtime validation at boundaries, tsconfig hygiene | `/typescript:review` |
| **[vite](plugins/vite/README.md)** | Vite: VITE_ env-leak security, dep pre-bundling, code splitting/manualChunks, base for sub-path deploys, dev server.proxy, define pitfalls, SSR, library mode, plugin order, HMR guards | `/vite:review` |
| **[inertia](plugins/inertia/README.md)** | Inertia.js (Laravel + Vue/React/Svelte): prop hygiene, partial reloads, deferred props, useForm, shared data, SSR, v1/v2 + adapter awareness | `/inertia:review` |
| **[meta-api](plugins/meta-api/README.md)** | Meta/Facebook platform navigator: current Graph API version, doc link map per product, conventions, required permissions + App Review awareness; general third-party docs → api-docs-first, own APIs → api-design | `/meta-api:check` |

### Automation & browser

| Plugin | Description | Commands |
|--------|-------------|----------|
| **[playwright](plugins/playwright/README.md)** | Playwright navigator: current API from live docs, locators/auto-wait/network/storageState/trace, robust patterns, connectOverCDP to an anti-detect browser | `/playwright:check` |
| **[puppeteer](plugins/puppeteer/README.md)** | Puppeteer navigator: current API, waits, request interception, puppeteer-extra stealth, connect via browserWSEndpoint | `/puppeteer:check` |
| **[adspower](plugins/adspower/README.md)** | AdsPower Local API: profile lifecycle, start/stop browser, CDP/WebSocket handoff to a driver, rate limits | `/adspower:check` |
| **[kameleo](plugins/kameleo/README.md)** | Kameleo Local API/SDK: fingerprint → profile → start, connect a driver over CDP, fingerprint config | `/kameleo:check` |
| **[camoufox](plugins/camoufox/README.md)** | Camoufox (anti-detect Firefox, Python): launch options (humanize, geoip, proxy, config), Playwright-Firefox integration | `/camoufox:check` |
| **[automation-builder](plugins/automation-builder/README.md)** | Automation planner + worker: tool-choice think-process, sequenced plan, browser-automation-engineer agent that scaffolds and runs | `/automation-builder:build` |

### Databases & SQL

| Plugin | Description | Commands |
|--------|-------------|----------|
| **sql** | SQL (engine-agnostic): sargable predicates, joins, index logic, NULL traps, transactions, keyset pagination, migrations | `/sql:review` |
| **mysql** | MySQL 8.0+: InnoDB clustered PK, utf8mb4, strict sql_mode, online DDL, gap locks, 8.0–8.4 leverage | `/mysql:review` |
| **mariadb** | MariaDB 10.6+: not-MySQL divergences, RETURNING, sequences, system versioning, UUID type, Galera | `/mariadb:review` |
| **postgresql** | PostgreSQL 14+: MVCC/vacuum, timestamptz/jsonb, index arsenal, lock-aware migrations, 14–18 leverage | `/postgresql:review` |
| **database** | Database worker: schema design, additive migrations, indexing, query optimization, connection pooling + database-engineer agent | — |

### Taskmaster workflow suite

| Plugin | Description | Commands |
|--------|-------------|----------|
| **[taskmaster](plugins/taskmaster/README.md)** | Idea-to-execution clarification: brainstorming fuzzy ideas into designs, ambiguity ledger, batched questions, theme-aware shell mockups (project colors when detectable, compare modes, tradeoff callouts, motion passes) + interactive experience walkthroughs on one always-live preview URL, milestone-grouped single-prompt task cards + context-scout agent, spec-time ERDs (mermaid + SVG preview), spec↔card coverage gate | `/taskmaster:task` (or `/taskmaster`), `/taskmaster:brainstorm`, `/taskmaster:coverage` |
| **[design-preview](plugins/design-preview/README.md)** | Real-component visual decisions for Vite + React: candidate variants rendered with the project's own components on its dev server via a scratch HTML entry (zero edits to existing files), strict consent + verified cleanup; falls back to taskmaster's shell mockups | `/design-preview:preview` |
| **[task-runner](plugins/task-runner/README.md)** | Disciplined execution: one task at a time, scope lock, bounded verify-fix loop (3 cycles max), full-suite completion gate + parallel-planning (computed subagents-vs-inline verdict, agent count, speedup estimate) | `/task-runner:run`, `/task-runner:plan` |
| **[stack-scan](plugins/stack-scan/README.md)** | Required-vs-installed inventory from composer/npm/yarn/pnpm/bun manifests, lockfiles, runtime pins, docker/CI images | `/stack-scan:report` |
| **[plugin-scout](plugins/plugin-scout/README.md)** | Scans project manifests and suggests marketplace plugins in two tiers (stack-matched with evidence, always-useful), marks installed ones, installs picked ones after confirm | `/plugin-scout:suggest` |
| **estimation** | S/M/L/XL sizing with anchors, uncertainty multipliers, split triggers, estimate-vs-actual loop; weights feed /task-runner:plan | `/estimation:size` |
| **decision-records** | ADRs: persist approach/schema/dependency decisions to taskmaster-docs/adr/ — context, rejected options, consequences, revisit-when trigger | `/decision-records:new` |
| **retrospective** | Post-milestone learning loop: surprises → CLAUDE.md candidates, repetition → skill suggestions, friction → process tweaks | `/retrospective:run` |
| **[hindsight](plugins/hindsight/README.md)** | Cross-session self-improvement loop: SessionEnd hook logs friction stats to a local ledger; harvest mines high-friction transcripts → CLAUDE.md rule candidates, skill/plugin ideas, failed-approach warnings — apply on approval + transcript-miner agent | `/hindsight:harvest` |

### Engineering discipline

| Plugin | Description | Commands |
|--------|-------------|----------|
| **code-architecture** | Engineering process: plan-before-code (+ current-vs-target diagrams), YAGNI, SOLID applied with judgment, task orchestration, work verification, low-cognitive-load, KISS/DRY, always-on surgical-coding discipline (Karpathy guidelines) + architecture-reviewer agent; system-level topology → system-design | `/code-architecture:plan`, `/code-architecture:verify`, `/code-architecture:yagni`, `/code-architecture:solid` |
| **design-patterns** | Design patterns: selection, fitting, anti-patterns | `/design-patterns:suggest` |
| **api-docs-first** | API-docs-first: verify docs before writing integration code; own APIs → api-design | `/api-docs-first:check` |
| **[api-design](plugins/api-design/README.md)** | REST design: resource naming, status codes, pagination, versioning, RFC 9457 errors, idempotency, Laravel API Resources; third-party docs → api-docs-first | `/api-design:review` |
| **code-review** | Stack-agnostic review: correctness bugs, code smells, convention drift — severity-sorted findings + code-reviewer agent + code-smells skill; stack idioms → framework review plugins | `/code-review:review` |
| **approaches** | Approach deliberation: 2–3 structurally different candidates, trade-off table, pick + kill-trigger + strategy catalog (tracer bullet, spike, strangler fig, inversion…) + auto-nudged opinion round (blind persona subagents: Standards Purist / Quality-over-Speed / Skeptic-Investigator → one-round pick) | `/approaches:compare`, `/approaches:opinions` |
| **build-vs-buy** | Gate zero for generic capability: library/stdlib search, health table, take/wrap/write verdict, never-hand-roll list | `/build-vs-buy:check` |
| **rollout** | Per-feature rollout: flags with removal dates, compat windows, expand-migrate-contract, staged exposure with gate metrics, rollback path before ship | `/rollout:plan` |
| **resilience** | Failure-mode design at integration points: timeouts, safe retries + idempotency, circuit breaking, degradation, backpressure, delivery semantics | `/resilience:review` |
| **docs-upkeep** | Doc drift prevention: README/changelog/ADR/API-doc sync in the same change that invalidated them | `/docs-upkeep:check` |
| **packages** | Composer/npm dependency hygiene — constraints, lockfiles, audit triage, upgrade lanes | `/packages:audit` |
| **observability** | Structured JSON logs + correlation IDs, log-level semantics, RED/USE metrics without cardinality bombs, trace propagation, symptom-based alerting, honest health checks | `/observability:review` |
| **error-handling** | Crash on programmer errors, handle operational errors where you can act, typed errors over message matching, cause chains, one report per failure, no swallowed exceptions | `/error-handling:review` |
| **concurrency** | Check-then-act races, optimistic vs pessimistic locking, idempotency keys, queue-consumer dedup under at-least-once, distributed locks with TTL + fencing, async parallel-write pitfalls | `/concurrency:review` |
| **orchestration** | Subagent orchestration: delegation contracts, compressed returns, model tiering, refuter/judge panels, loop-until-dry | `/orchestration:review` |
| **[testing](plugins/testing/README.md)** | Test pyramid, Pest/PHPUnit + Vitest/Jest idioms, Playwright/Dusk e2e, factories, mocking boundaries, flaky-test causes, coverage traps + TDD workflow (red-green-refactor, regression proof) + test-engineer agent | `/testing:review` |
| **[security](plugins/security/README.md)** | OWASP-aligned defensive review: injection, XSS, CSRF, authz, mass assignment, uploads, secrets, dependency audit — PHP/Laravel + JS/Vue specifics + security-engineer agent | `/security:review` |
| **[debugging](plugins/debugging/README.md)** | Systematic debugging: root cause before any fix, reproduce → hypothesis → smallest experiment, bisection, three-failed-fixes stop rule | `/debugging:debug` |
| **[git-workflow](plugins/git-workflow/README.md)** | Worktree isolation, branch finish protocol (verify → merge/PR/keep/discard → cleanup), review-exchange rigor both directions | `/git-workflow:finish` |
| **[dev-env](plugins/dev-env/README.md)** | Scan dependencies → generate docker-compose.yml + Dockerfile matched to the stack; audit existing docker files; CI/CD + prod deploys → devops | `/dev-env:init`, `/dev-env:review` |
| **a11y** | WCAG 2.1 AA audit: semantics, ARIA rules, keyboard, focus, contrast, forms, media — violation + fix per line | `/a11y:audit` |
| **claude-authoring** | Authoring guides for skills/agents/hooks/plugins + routine-detector (capture repetitive work as a project skill) + project-skill-suggester (proactively offer one when a task's cards share uncovered repo knowledge) | `/claude-authoring:new-skill`, `/claude-authoring:new-agent`, `/claude-authoring:new-hook`, `/claude-authoring:new-plugin` |

### Worker agents

| Plugin | Description | Commands |
|--------|-------------|----------|
| **web-dev** | Generalist web implementation worker: routing, REST/API integration, forms, state, SSR/CSR trade-offs, accessibility baseline + web-developer agent | — |
| **system-design** | System-level design worker: service boundaries, data modeling, scaling, caching, sync vs async with documented trade-offs + system-architect agent; code-level structure → code-architecture | — |
| **devops** | DevOps worker: CI/CD pipelines, Docker/K8s, deploy strategies with rollback paths, observability, secrets discipline + devops-engineer agent; local dev environments → dev-env | — |
| **performance** | Performance worker: measure-first profiling, bundle size, caching, Core Web Vitals, N+1 elimination, load testing + performance-engineer agent | — |

### Bundles

| Plugin | Description | Commands |
|--------|-------------|----------|
| **everything** | Meta-bundle: one install pulls every plugin in this marketplace as a dependency | `/everything:uninstall` |
| **taskmaster-suite** | Meta-bundle: taskmaster workflow + all stack-agnostic plugins (tasks, engineering discipline, UI/UX, worker agents) — no framework/dialect plugins | `/taskmaster-suite:uninstall` |
| **frontend-suite** | Meta-bundle: frontend category — UI/UX stacks, React, React Native, Vue 2/3, TypeScript, Inertia, Livewire, web worker, a11y | `/frontend-suite:uninstall` |
| **php-suite** | Meta-bundle: PHP category — PHP, Laravel, Livewire, Inertia, web worker | `/php-suite:uninstall` |
| **db-suite** | Meta-bundle: database category — SQL, MySQL, MariaDB, PostgreSQL, database worker | `/db-suite:uninstall` |
| **quality-suite** | Meta-bundle: code-quality category — review, architecture, patterns, testing, security, a11y, debugging, performance, resilience, packages, observability, error-handling, concurrency | `/quality-suite:uninstall` |
| **process-suite** | Meta-bundle: engineering-process category — git workflow, approaches, ADRs, retrospectives, hindsight, build-vs-buy, rollout, docs-upkeep, estimation, orchestration, task-runner, stack-scan, plugin-scout | `/process-suite:uninstall` |
| **automations-suite** | Meta-bundle: browser-automation category — Playwright, Puppeteer, AdsPower, Kameleo, Camoufox, automation-builder | `/automations-suite:uninstall` |

## Usage

Skills auto-trigger based on context (e.g., `react-best-practices` activates when writing React code). Commands like `/react:review` are invoked manually. You can also invoke them from the command line or via the plugin menu.

Plugins with their own README carry detailed usage and examples — see the links in the plugin tables above.

### Optimal setup: the taskmaster workflow suite

`/taskmaster` (shorthand for `/taskmaster:task`) interrogates the task with batched questions (grounded in a codebase scan by the context-scout agent), writes a spec, and emits single-prompt task cards for `/task-runner:run` — a full annotated conversation example lives in the [taskmaster README](plugins/taskmaster/README.md). It reaches its full potential with three companion plugins installed alongside it:

| Plugin | Role in the workflow |
|--------|----------------------|
| **stack-scan** | Runs first. Inventories the actual installed versions (lockfiles, runtime pins, docker images) so taskmaster's context-scout cites real constraints instead of guesses |
| **taskmaster** | Clarifies the task: interrogation → spec → single-prompt task cards |
| **task-runner** | Executes the cards one at a time with scope lock, bounded verify-fix loops, and a full-suite completion gate |
| **code-architecture** | Supplies the process gates used throughout: plan-before-code, YAGNI checks, and the work-verification discipline task-runner applies to the whole run |

The full loop for a feature:

```bash
/stack-scan:report                                    # ground truth: what's actually installed
/taskmaster:task <one-paragraph task description>     # interrogate → spec → task cards
/task-runner:run taskmaster-docs/tasks/<date>-<slug>/00-INDEX.md # execute cards, verify each one
```

Each plugin degrades gracefully when a companion is missing — taskmaster scans manifests itself without stack-scan, and task-runner accepts any task list, not just taskmaster cards. Installed together, version facts flow into clarifying questions, cards flow into disciplined execution, and verification gates close the loop.

If you work on a specific stack, add its review plugin on top (e.g. `laravel` + `mysql` for a Laravel app, `react` + `ui-ux` for a React frontend) — stack-scan's inventory feeds those review commands too.

## Contributing

To add a new plugin:

1. Create a directory: `plugins/<name>/.claude-plugin/`
2. Add a `plugin.json` manifest (see existing plugins for examples)
3. Update `.claude-plugin/marketplace.json` with your plugin entry
4. Run `bash scripts/validate.sh` to verify the structure

CI runs `bash scripts/validate.sh` on every push and pull request (`.github/workflows/validate.yml`). Each plugin is versioned independently in its own `plugin.json`; the marketplace version lives in `.claude-plugin/marketplace.json` and is tracked in [CHANGELOG.md](CHANGELOG.md). All plugins are owned by Ivan-WG <public@galayko.com> and released under the [MIT License](LICENSE).
