# cc-plugins-marketplace: Claude Code Plugin Marketplace

cc-plugins-marketplace is a self-hosted marketplace of best-practice plugins for Claude Code. Each plugin bundles skills, commands, and agents that enforce code quality standards across your projects—from React and Vue to Laravel and beyond.

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
| **sql** | SQL (engine-agnostic): sargable predicates, joins, index logic, NULL traps, transactions, keyset pagination, migrations | `/sql:review` |
| **mysql** | MySQL 8.0+: InnoDB clustered PK, utf8mb4, strict sql_mode, online DDL, gap locks, 8.0–8.4 leverage | `/mysql:review` |
| **mariadb** | MariaDB 10.6+: not-MySQL divergences, RETURNING, sequences, system versioning, UUID type, Galera | `/mariadb:review` |
| **postgresql** | PostgreSQL 14+: MVCC/vacuum, timestamptz/jsonb, index arsenal, lock-aware migrations, 14–18 leverage | `/postgresql:review` |
| **code-architecture** | Engineering process: plan-before-code (+ current-vs-target diagrams), YAGNI, task orchestration, work verification, low-cognitive-load, KISS/DRY, always-on surgical-coding discipline (Karpathy guidelines) + architecture-reviewer agent | `/code-architecture:plan`, `/code-architecture:verify`, `/code-architecture:yagni` |
| **design-patterns** | Design patterns: selection, fitting, anti-patterns | `/design-patterns:suggest` |
| **api-docs-first** | API-docs-first: verify docs before writing integration code | `/api-docs-first:check` |
| **[meta-api](plugins/meta-api/README.md)** | Meta/Facebook platform navigator: current Graph API version, doc link map per product, conventions, required permissions + App Review awareness | `/meta-api:check` |
| **[taskmaster](plugins/taskmaster/README.md)** | Idea-to-execution clarification: brainstorming fuzzy ideas into designs, ambiguity ledger, batched questions, mockups + interactive experience walkthroughs on one always-live preview URL, milestone-grouped single-prompt task cards + context-scout agent | `/taskmaster:task` (or `/taskmaster`), `/taskmaster:brainstorm` |
| **[task-runner](plugins/task-runner/README.md)** | Disciplined execution: one task at a time, scope lock, bounded verify-fix loop (3 cycles max), full-suite completion gate + parallel-planning (computed subagents-vs-inline verdict, agent count, speedup estimate) | `/task-runner:run`, `/task-runner:plan` |
| **[stack-scan](plugins/stack-scan/README.md)** | Required-vs-installed inventory from composer/npm/yarn/pnpm/bun manifests, lockfiles, runtime pins, docker/CI images | `/stack-scan:report` |
| **[plugin-scout](plugins/plugin-scout/README.md)** | Scans project manifests and suggests marketplace plugins in two tiers (stack-matched with evidence, always-useful), marks installed ones, installs picked ones after confirm | `/plugin-scout:suggest` |
| **[testing](plugins/testing/README.md)** | Test pyramid, Pest/PHPUnit + Vitest/Jest idioms, Playwright/Dusk e2e, factories, mocking boundaries, flaky-test causes, coverage traps + TDD workflow (red-green-refactor, regression proof) + test-engineer agent | `/testing:review` |
| **[debugging](plugins/debugging/README.md)** | Systematic debugging: root cause before any fix, reproduce → hypothesis → smallest experiment, bisection, three-failed-fixes stop rule | `/debugging:debug` |
| **[git-workflow](plugins/git-workflow/README.md)** | Worktree isolation, branch finish protocol (verify → merge/PR/keep/discard → cleanup), review-exchange rigor both directions | `/git-workflow:finish` |
| **[hindsight](plugins/hindsight/README.md)** | Cross-session self-improvement loop: SessionEnd hook logs friction stats to a local ledger; harvest mines high-friction transcripts → CLAUDE.md rule candidates, skill/plugin ideas, failed-approach warnings — apply on approval + transcript-miner agent | `/hindsight:harvest` |
| **[security](plugins/security/README.md)** | OWASP-aligned defensive review: injection, XSS, CSRF, authz, mass assignment, uploads, secrets, dependency audit — PHP/Laravel + JS/Vue specifics + security-engineer agent | `/security:review` |
| **[typescript](plugins/typescript/README.md)** | Strict mode floor, any vs unknown, narrowing over assertions, satisfies, runtime validation at boundaries, tsconfig hygiene | `/typescript:review` |
| **[inertia](plugins/inertia/README.md)** | Inertia.js (Laravel + Vue/React/Svelte): prop hygiene, partial reloads, deferred props, useForm, shared data, SSR, v1/v2 + adapter awareness | `/inertia:review` |
| **[api-design](plugins/api-design/README.md)** | REST design: resource naming, status codes, pagination, versioning, RFC 9457 errors, idempotency, Laravel API Resources | `/api-design:review` |
| **[dev-env](plugins/dev-env/README.md)** | Scan dependencies → generate docker-compose.yml + Dockerfile matched to the stack; audit existing docker files | `/dev-env:init`, `/dev-env:review` |
| **web-dev** | Generalist web implementation worker: routing, REST/API integration, forms, state, SSR/CSR trade-offs, accessibility baseline + web-developer agent | — |
| **system-design** | System-level design worker: service boundaries, data modeling, scaling, caching, sync vs async with documented trade-offs + system-architect agent | — |
| **devops** | DevOps worker: CI/CD pipelines, Docker/K8s, deploy strategies with rollback paths, observability, secrets discipline + devops-engineer agent | — |
| **database** | Database worker: schema design, additive migrations, indexing, query optimization, connection pooling + database-engineer agent | — |
| **performance** | Performance worker: measure-first profiling, bundle size, caching, Core Web Vitals, N+1 elimination, load testing + performance-engineer agent | — |
| **claude-authoring** | Authoring guides for skills/agents/hooks/plugins + routine-detector that suggests capturing repetitive work as a project skill | `/claude-authoring:new-skill`, `/claude-authoring:new-agent`, `/claude-authoring:new-hook`, `/claude-authoring:new-plugin` |
| **code-review** | Stack-agnostic review: correctness bugs, code smells, convention drift — severity-sorted findings + code-reviewer agent + code-smells skill | `/code-review:review` |
| **approaches** | Approach deliberation: 2–3 structurally different candidates, trade-off table, pick + kill-trigger + strategy catalog (tracer bullet, spike, strangler fig, inversion…) | `/approaches:compare` |
| **decision-records** | ADRs: persist approach/schema/dependency decisions to taskmaster-docs/adr/ — context, rejected options, consequences, revisit-when trigger | `/decision-records:new` |
| **retrospective** | Post-milestone learning loop: surprises → CLAUDE.md candidates, repetition → skill suggestions, friction → process tweaks | `/retrospective:run` |
| **build-vs-buy** | Gate zero for generic capability: library/stdlib search, health table, take/wrap/write verdict, never-hand-roll list | `/build-vs-buy:check` |
| **rollout** | Per-feature rollout: flags with removal dates, compat windows, expand-migrate-contract, staged exposure with gate metrics, rollback path before ship | `/rollout:plan` |
| **resilience** | Failure-mode design at integration points: timeouts, safe retries + idempotency, circuit breaking, degradation, backpressure, delivery semantics | `/resilience:review` |
| **docs-upkeep** | Doc drift prevention: README/changelog/ADR/API-doc sync in the same change that invalidated them | `/docs-upkeep:check` |
| **estimation** | S/M/L/XL sizing with anchors, uncertainty multipliers, split triggers, estimate-vs-actual loop; weights feed /task-runner:plan | `/estimation:size` |
| **a11y** | WCAG 2.1 AA audit: semantics, ARIA rules, keyboard, focus, contrast, forms, media — violation + fix per line | `/a11y:audit` |
| **everything** | Meta-bundle: one install pulls every plugin in this marketplace as a dependency | `/everything:uninstall` |
| **taskmaster-suite** | Meta-bundle: taskmaster workflow + all stack-agnostic plugins (tasks, engineering discipline, UI/UX, worker agents) — no framework/dialect plugins | `/taskmaster-suite:uninstall` |

## Usage

Skills auto-trigger based on context (e.g., `react-best-practices` activates when writing React code). Commands like `/react:review` are invoked manually. You can also invoke them from the command line or via the plugin menu.

Plugins with their own README carry detailed usage and examples — see the links in the plugin table above. The highlights:

### Running taskmaster

```bash
/plugin install taskmaster@cc-plugins-marketplace
/taskmaster Add CSV export to the orders page with date-range filtering
```

`/taskmaster` is shorthand for `/taskmaster:task`. It interrogates the task with batched questions (grounded in a codebase scan by the context-scout agent), writes a spec, and emits single-prompt task cards for `/task-runner:run`. A full annotated conversation example lives in the [taskmaster README](plugins/taskmaster/README.md).

### Optimal setup: the taskmaster workflow suite

taskmaster works standalone, but it reaches its full potential with three companion plugins installed alongside it:

```bash
/plugin install stack-scan@cc-plugins-marketplace
/plugin install taskmaster@cc-plugins-marketplace
/plugin install task-runner@cc-plugins-marketplace
/plugin install code-architecture@cc-plugins-marketplace
```

How the pieces fit together:

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
/code-architecture:verify                             # final verification pass
```

Each plugin degrades gracefully when a companion is missing — taskmaster scans manifests itself without stack-scan, and task-runner accepts any task list, not just taskmaster cards. But installed together, version facts flow into clarifying questions, cards flow into disciplined execution, and verification gates close the loop.

If you work on a specific stack, add its review plugin on top (e.g. `laravel` + `mysql` for a Laravel app, `react` + `ui-ux` for a React frontend) — stack-scan's inventory feeds those review commands too.

## Contributing

To add a new plugin:

1. Create a directory: `plugins/<name>/.claude-plugin/`
2. Add a `plugin.json` manifest (see existing plugins for examples)
3. Update `.claude-plugin/marketplace.json` with your plugin entry
4. Run `bash scripts/validate.sh` to verify the structure

Individual plugins are versioned in their own `plugin.json` (currently `0.1.0`); the marketplace version lives in `.claude-plugin/marketplace.json` and is tracked in [CHANGELOG.md](CHANGELOG.md). All plugins are owned by Ivan-WG <public@galayko.com> and released under the [MIT License](LICENSE).
