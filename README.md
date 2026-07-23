# cc-plugins-marketplace: Claude Code Plugin Marketplace

cc-plugins-marketplace is a self-hosted marketplace of best-practice plugins for Claude Code — each plugin bundles skills, commands, and agents that enforce code quality standards across your projects, from React and Vue to Laravel and beyond.

## Getting started

Three lanes in — when unsure, take the first:

1. **Start here:** run `/plugin-scout:suggest` — scans your project's manifests, suggests stack-matched and always-useful plugins in two tiers, and installs the ones you pick after confirmation. Add `--yes` to auto-install the stack-matched tier without the picker, and `--persist` to write the installed set into the repo's `.claude/settings.json` so teammates get it on clone.
2. **Bundle:** install the category suite matching your project — `frontend-suite`, `php-suite`, `db-suite`, `quality-suite`, `process-suite` — or `taskmaster-suite` (full taskmaster workflow + stack-agnostic engineering plugins). Browser-automation plugins (playwright, puppeteer, automation-builder) install individually. `everything` (all 69 leaf plugins) exists for zero-setup convenience at ~12.3k tokens of always-on context per session — most setups don't need it.
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

| Bundle | Plugins | Always-on context (approx.) |
|--------|---------|-----------------------------|
| `everything` | 69 | ~12.3k tokens |
| `taskmaster-suite` | 37 | ~8.6k tokens |
| `process-suite` | 13 | ~2.3k tokens |
| `quality-suite` | 15 | ~2.6k tokens |
| `frontend-suite` | 17 | ~2.4k tokens |
| `php-suite` | 6 | ~0.7k tokens |
| `db-suite` | 5 | ~0.5k tokens |

Always-on context = the skill/command/agent descriptions every installed
plugin adds to each session's context window, plus SessionStart hook output
(measured against an empty project — a lower bound; chars/4 estimate).
Per-prompt hook output (UserPromptSubmit etc.) is dynamic and not counted —
`scripts/context-budget.sh` lists those plugins at the end of each run.

```bash
# Full taskmaster workflow + its wired companions (task pipeline,
# engineering discipline, worker agents, the ui-ux visual agents the
# pipeline routes to).
/plugin install taskmaster-suite@cc-plugins-marketplace

# Everything in the marketplace — every plugin, all stacks. Convenience
# install: ~12.3k tokens of always-on context per session; prefer a category
# suite unless you want zero per-repo setup.
/plugin install everything@cc-plugins-marketplace

# Or one category at a time:
/plugin install frontend-suite@cc-plugins-marketplace   # UI/UX, React, Vue, TS, Inertia, Livewire, a11y
/plugin install php-suite@cc-plugins-marketplace        # PHP, Laravel, Livewire, Inertia
/plugin install db-suite@cc-plugins-marketplace         # SQL, MySQL, MariaDB, PostgreSQL, database worker
/plugin install quality-suite@cc-plugins-marketplace    # review, testing, security, resilience, observability…
/plugin install process-suite@cc-plugins-marketplace    # git workflow, estimation, orchestration, task-runner…

# Browser-automation plugins install individually:
/plugin install playwright@cc-plugins-marketplace       # (same for puppeteer)
```

Recommended default: install `process-suite` globally, add the matching
category suite per project, and run `/plugin-scout:suggest` when unsure.

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
| **[ui-ux](plugins/ui-ux/README.md)** | UI/UX best practices: shadcn/ui, ReUI, Aceternity UI, Astryx, Tailwind, CSS3, Bootstrap, CSS Grid, Flexbox + theme builder (shadcn/ReUI/Aceternity, Tailwind, Bootstrap) with live colour preview + ui-ux-reviewer & ui-ux-engineer agents | `/ui-ux:review`, `/ui-ux:theme` |
| **react** | React: hooks, render/memo, state management, patterns | `/react:review` |
| **react-native** | React Native: list performance, navigation, platform code, animations | `/react-native:review` |
| **vue2** | Vue 2.7: Composition API, reactivity, migration readiness | `/vue2:review` |
| **vue3** | Vue 3: script setup, composables, ref/reactive, Pinia | `/vue3:review` |
| **[nextjs](plugins/nextjs/README.md)** | Next.js: App Router server/client boundaries, opt-in caching, server actions as public endpoints, route handlers, streaming with Suspense, next/image & next/font — version-aware 14–16 | `/nextjs:review` |
| **[nuxt](plugins/nuxt/README.md)** | Nuxt: Nitro server routes, hybrid rendering route rules, useFetch/useAsyncData payload dedup, SSR-safe useState, auto-imports discipline, runtimeConfig, SEO meta | `/nuxt:review` |
| **php** | PHP: strict types, === discipline, PSR conventions, version-aware 8.1–8.5 leverage map, exceptions, boundary security | `/php:review` |
| **laravel** | Laravel: Eloquent N+1, form requests, service layer, queues, policies | `/laravel:review` |
| **livewire** | Livewire 3/4: components, wire:model, performance, Alpine interop | `/livewire:review` |
| **[javascript](plugins/javascript/README.md)** | Vanilla JS: version-aware ES feature floors, === and coercion traps, ESM vs CommonJS interop, async correctness + event loop, this-binding & closures/leaks, boundary validation, BigInt, prototype-pollution safety | `/javascript:review` |
| **[typescript](plugins/typescript/README.md)** | Strict mode floor, any vs unknown, narrowing over assertions, satisfies, runtime validation at boundaries, tsconfig hygiene | `/typescript:review` |
| **[node-backend](plugins/node-backend/README.md)** | Server-side Node.js (Express 5, NestJS 11, Fastify 5): middleware vs DI vs plugin-encapsulation architecture, async error propagation, boundary validation (zod, class-validator), streaming/backpressure, graceful shutdown | `/node-backend:review` |
| **[vite](plugins/vite/README.md)** | Vite: VITE_ env-leak security, dep pre-bundling, code splitting/manualChunks, base for sub-path deploys, dev server.proxy, define pitfalls, SSR, library mode, plugin order, HMR guards | `/vite:review` |
| **[threejs](plugins/threejs/README.md)** | Three.js: WebGPURenderer-first (WebGL2 fallback), TSL shaders, react-three-fiber/drei, glTF/Draco/KTX2 pipelines, disposal/leak discipline, draw-call performance — version-aware per rXXX | `/threejs:review` |
| **[inertia](plugins/inertia/README.md)** | Inertia.js (Laravel + Vue/React/Svelte): prop hygiene, partial reloads, deferred props, useForm, shared data, SSR, v1/v2 + adapter awareness | `/inertia:review` |

### Automation & browser

| Plugin | Description | Commands |
|--------|-------------|----------|
| **[playwright](plugins/playwright/README.md)** | Playwright navigator: current API from live docs, locators/auto-wait/network/storageState/trace, robust patterns, connectOverCDP to attach to a running Chromium | `/playwright:check` |
| **[puppeteer](plugins/puppeteer/README.md)** | Puppeteer navigator: current API, waits, request interception, puppeteer-extra stealth, connect via browserWSEndpoint | `/puppeteer:check` |
| **[automation-builder](plugins/automation-builder/README.md)** | Automation planner + worker: tool-choice think-process, sequenced plan, browser-automation-engineer agent that scaffolds and runs | `/automation-builder:build` |

### Databases & SQL

| Plugin | Description | Commands |
|--------|-------------|----------|
| **sql** | SQL (engine-agnostic): sargable predicates, joins, index logic, NULL traps, transactions, keyset pagination, migrations | `/sql:review` |
| **mysql** | MySQL 8.0+: InnoDB clustered PK, utf8mb4, strict sql_mode, online DDL, gap locks, 8.0–8.4 + 9.7 LTS leverage | `/mysql:review` |
| **mariadb** | MariaDB 10.6+: not-MySQL divergences, RETURNING, sequences, system versioning, UUID type, Galera | `/mariadb:review` |
| **postgresql** | PostgreSQL 14+: MVCC/vacuum, timestamptz/jsonb, index arsenal, lock-aware migrations, 14–18 leverage | `/postgresql:review` |
| **database** | Database design: engine-agnostic schema, expand→contract migrations, indexing, query shape, pooling — database-design skill + database-engineer worker + a destructive-SQL PreToolUse guard | `/database:review` |

### Taskmaster workflow suite

| Plugin | Description | Commands |
|--------|-------------|----------|
| **[taskmaster](plugins/taskmaster/README.md)** | Idea-to-execution clarification: brainstorming fuzzy ideas into designs, ambiguity ledger, batched questions, theme-aware shell mockups (project colors when detectable, compare modes, tradeoff callouts, motion passes) + interactive experience walkthroughs on one always-live preview URL, milestone-grouped single-prompt task cards + context-scout agent, spec-time ERDs (mermaid + SVG preview), spec↔card coverage gate, adversarial spec red-team | `/taskmaster:task` (or `/taskmaster`), `/taskmaster:brainstorm`, `/taskmaster:coverage`, `/taskmaster:redteam` |
| **[design-preview](plugins/design-preview/README.md)** | Real-component visual decisions for Vite + React: candidate variants rendered with the project's own components on its dev server via a scratch HTML entry (zero edits to existing files), strict consent + verified cleanup; falls back to taskmaster's shell mockups | `/design-preview:preview` |
| **[task-runner](plugins/task-runner/README.md)** | Disciplined execution: one task at a time, scope lock, bounded verify-fix loop (3 cycles max), full-suite completion gate + parallel-planning (computed subagents-vs-inline verdict, agent count, speedup estimate) | `/task-runner:run`, `/task-runner:plan` |
| **[intent-guard](plugins/intent-guard/README.md)** | Mid-run intent-vs-action attestation: a cooperative drift-guard that ledgers each Edit/Write/Bash/Agent action, has the model attest it against the declared task, and holds turn completion (Stop gate) until unattested actions and drift are reckoned — the mid-run tier between coverage-check (entry) and work-verification (exit); not tamper-proof | `/intent-guard:intent`, `/intent-guard:status` |
| **[stack-scan](plugins/stack-scan/README.md)** | Required-vs-installed inventory from composer/npm/yarn/pnpm/bun manifests, lockfiles, runtime pins, docker/CI images | `/stack-scan:report` |
| **[plugin-scout](plugins/plugin-scout/README.md)** | Scans project manifests and suggests marketplace plugins in two tiers (stack-matched with evidence, always-useful), marks installed ones, installs picked ones after confirm — `--yes` auto-installs the stack-matched tier, `--persist` writes the set into project settings | `/plugin-scout:suggest` |
| **estimation** | S/M/L/XL sizing with anchors, uncertainty multipliers, split triggers, estimate-vs-actual loop; weights feed /task-runner:plan | `/estimation:size` |
| **[hindsight](plugins/hindsight/README.md)** | Cross-session self-improvement loop: SessionEnd hook logs friction stats to a local ledger; harvest mines high-friction transcripts → CLAUDE.md rule candidates, skill/plugin ideas, failed-approach warnings — apply on approval + transcript-miner agent | `/hindsight:harvest` |
| **[skill-router](plugins/skill-router/README.md)** | File-aware skill auto-routing: a PostToolUse hook injects a directive to load the relevant best-practice skill when you edit a matching file (SQL, components, tests, Dockerfiles), a SessionStart hook primes a repo skill index, low-confidence content signals surface in a SessionEnd digest; fail-open, once per signal per session | — |
| **[brain](plugins/brain/README.md)** | Committed Obsidian-style codebase map: brain/INDEX.md indexes areas, key files, entrypoints; a SessionStart hook injects the compact map (with staleness hint) so fresh sessions start oriented + indexer agent | `/brain:brain` |
| **[compaction-advisor](plugins/compaction-advisor/README.md)** | Advice-only /compact nudge: a UserPromptSubmit hook counts user turns and, on a repeating 50-turn interval, prints one line suggesting /compact when an early chunk is no longer relevant | — |
| **[fresh-take](plugins/fresh-take/README.md)** | Independent stronger-model second opinion at key moments (stuck debugging, imminent irreversible action): facts-only brief, blind read-only consultant returns Take, Risks, one Alternative — advice only | `/fresh-take:consult` |
| **[shadcn-studio](plugins/shadcn-studio/README.md)** | Greenfield interactive shadcn staging: self-contained shadcn + Vite (Tailwind v4) sandbox on its own dev server renders agent-authored component variants side by side — real interactivity, not static HTML | `/shadcn-studio:stage` |
| **[ultra-deep-research](plugins/ultra-deep-research/README.md)** | Deep-research harness: parallel search fan-out, provenance-tiered sources, date-stamped claims, adversarial refutation before synthesis, cited report with contradiction ledger + researcher/verifier agents | `/ultra-deep-research:research` |

### Engineering discipline

| Plugin | Description | Commands |
|--------|-------------|----------|
| **code-architecture** | Engineering process: plan-before-code (+ current-vs-target diagrams), YAGNI, SOLID applied with judgment, task orchestration, work verification, low-cognitive-load, KISS/DRY, always-on surgical-coding discipline (Karpathy guidelines) + architecture-reviewer agent; system-level topology → system-design | `/code-architecture:plan`, `/code-architecture:verify`, `/code-architecture:yagni`, `/code-architecture:solid` |
| **design-patterns** | Design patterns: selection, fitting, anti-patterns | `/design-patterns:suggest` |
| **api-docs-first** | API-docs-first: verify docs before writing integration code; own APIs → api-design | `/api-docs-first:check` |
| **[api-design](plugins/api-design/README.md)** | REST design: resource naming, status codes, pagination, versioning, RFC 9457 errors, idempotency, Laravel API Resources + graphql-grpc skill (DataLoader, resolver authz, proto safety, streaming); third-party docs → api-docs-first | `/api-design:review` |
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
| **[security](plugins/security/README.md)** | OWASP-aligned defensive review: injection, XSS, CSRF, authz, mass assignment, uploads, secrets, dependency audit — PHP/Laravel + JS/Vue specifics + security-engineer agent + data-privacy (GDPR/CCPA) and api-auth (token/OAuth model) skills | `/security:review` |
| **[secret-scanning](plugins/secret-scanning/README.md)** | PreToolUse hook that blocks a Write/Edit introducing a high-confidence secret (cloud keys, private-key blocks, provider tokens) before it hits disk; on-demand repo sweep; fail-open, fixture-safe | `/secret-scanning:scan` |
| **[reuse-guard](plugins/reuse-guard/README.md)** | Warn-only reuse hygiene so an agent does not build on dead code: PostToolUse hook flags edits referencing session-cached deprecated symbols; on-demand Tier-2 dead-code/orphan/reachability check | `/reuse-guard:check` |
| **[payments](plugins/payments/README.md)** | Payments/billing (Stripe/Paddle): PCI-scope minimization, integer-minor-unit money, signature-verified idempotent webhooks, subscription races, dunning/proration, ledger reconciliation | `/payments:review` |
| **[i18n](plugins/i18n/README.md)** | Internationalization: semantic keys + catalogs, ICU plural/gender, locale-aware dates/numbers/currency via Intl, RTL logical properties, fallback chains, tooling extraction | `/i18n:review` |
| **[llm-app](plugins/llm-app/README.md)** | LLM apps: eval harnesses + regression gates, RAG (chunking/embeddings/retrieval quality/grounding), prompt versioning, prompt-injection defense, token-cost control | `/llm-app:review` |
| **[debugging](plugins/debugging/README.md)** | Systematic debugging: root cause before any fix, reproduce → hypothesis → smallest experiment, bisection, three-failed-fixes stop rule | `/debugging:debug` |
| **[git-workflow](plugins/git-workflow/README.md)** | Worktree isolation, branch finish protocol (verify → merge/PR/keep/discard → cleanup), review-exchange rigor both directions | `/git-workflow:finish` |
| **[dev-env](plugins/dev-env/README.md)** | Scan dependencies → generate docker-compose.yml + Dockerfile matched to the stack; audit existing docker files; CI/CD + prod deploys → devops | `/dev-env:init`, `/dev-env:review` |
| **a11y** | WCAG 2.2 AA audit: semantics, ARIA rules, keyboard, focus, contrast, forms, media — violation + fix per line | `/a11y:audit` |
| **claude-authoring** | Authoring guides for skills/agents/hooks/plugins + routine-detector (capture repetitive work as a project skill) + project-skill-suggester (proactively offer one when a task's cards share uncovered repo knowledge) | `/claude-authoring:new-skill`, `/claude-authoring:new-agent`, `/claude-authoring:new-hook`, `/claude-authoring:new-plugin` |

### Worker agents

| Plugin | Description | Commands |
|--------|-------------|----------|
| **web-dev** | Generalist web implementation worker: routing, REST/API integration, forms, state, SSR/CSR trade-offs, accessibility baseline + web-developer agent | — |
| **system-design** | System-level design: boundaries on data ownership, scaling, cache placement, async failure modes, SPOFs + domain modeling (DDD) + event-driven skill (brokers, outbox, sagas, DLQ) — skills + system-architect worker + system-design-reviewer; code-level structure → code-architecture | `/system-design:review` |
| **devops** | DevOps pipeline/infra: CI/CD ordering, image hygiene, k8s limits/probes, deploy+rollback, secrets — devops-practices skill + devops-engineer worker + devops-reviewer; in-code instrumentation → observability, local dev → dev-env | `/devops:review` |
| **performance** | Performance tuning: measure-first, N+1/index/payload/bundle/CWV hotspots, cache correctness (stampede/TTL/eviction), percentile load testing — performance-tuning skill + performance-engineer worker | `/performance:review` |

### Bundles

| Plugin | Description | Commands |
|--------|-------------|----------|
| **everything** | Meta-bundle: one install pulls every plugin in this marketplace as a dependency | `/everything:uninstall` |
| **taskmaster-suite** | Meta-bundle: taskmaster workflow + its wired companions (tasks, engineering discipline, worker agents, ui-ux visual routing) | `/taskmaster-suite:uninstall` |
| **frontend-suite** | Meta-bundle: frontend category — UI/UX stacks, React, React Native, Vue 2/3, TypeScript, Inertia, Livewire, web worker, a11y | `/frontend-suite:uninstall` |
| **php-suite** | Meta-bundle: PHP category — PHP, Laravel, Livewire, Inertia, web worker | `/php-suite:uninstall` |
| **db-suite** | Meta-bundle: database category — SQL, MySQL, MariaDB, PostgreSQL, database worker | `/db-suite:uninstall` |
| **quality-suite** | Meta-bundle: code-quality category — review, architecture, patterns, testing, security, a11y, debugging, performance, resilience, packages, observability, error-handling, concurrency | `/quality-suite:uninstall` |
| **process-suite** | Meta-bundle: engineering-process category — git workflow, approaches, hindsight, build-vs-buy, rollout, docs-upkeep, estimation, orchestration, task-runner, stack-scan, plugin-scout | `/process-suite:uninstall` |

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

Beyond the core four, the pipeline auto-wires more companions **when they are installed** (all of them ship in the `taskmaster-suite` bundle): **approaches** (blind opinion-round personas at the approach-decision step), **claude-authoring** (the project-skill-suggester offer after card-split), **estimation** (S/M/L/XL card sizing), and **ui-ux** (the engineer/reviewer agents visual cards route to, plus `/ui-ux:theme`). It also runs internal stages that need no companion: a resumable grill ledger, a convergence cap on interrogation, an adversarial spec red-team before cards, and a spec↔card coverage gate after them.

The full loop for a feature:

```bash
/stack-scan:report                                    # ground truth: what's actually installed
/taskmaster:task <one-paragraph task description>     # interrogate → spec → task cards
/task-runner:run taskmaster-docs/tasks/<date>-<slug>/00-INDEX.md # execute cards, verify each one
```

Each plugin degrades gracefully when a companion is missing — taskmaster scans manifests itself without stack-scan, and task-runner accepts any task list, not just taskmaster cards. Installed together, version facts flow into clarifying questions, cards flow into disciplined execution, and verification gates close the loop.

If you work on a specific stack, add its review plugin on top (e.g. `laravel` + `mysql` for a Laravel app, `react` + `vite` for a React frontend) — stack-scan's inventory feeds those review commands too.

## Contributing

To add a new plugin:

1. Create a directory: `plugins/<name>/.claude-plugin/`
2. Add a `plugin.json` manifest (see existing plugins for examples)
3. Update `.claude-plugin/marketplace.json` with your plugin entry
4. Run `bash scripts/validate.sh` to verify the structure

CI runs `bash scripts/validate.sh` on every push and pull request (`.github/workflows/validate.yml`). Each plugin is versioned independently in its own `plugin.json`; the marketplace version lives in `.claude-plugin/marketplace.json` and is tracked in [CHANGELOG.md](CHANGELOG.md). All plugins are owned by Ivan-WG <public@galayko.com> and released under the [MIT License](LICENSE).

## Releasing

The marketplace as a whole is versioned by `metadata.version` in `.claude-plugin/marketplace.json` and documented in [CHANGELOG.md](CHANGELOG.md). Two CI gates keep this honest: `scripts/check-version-bumps.sh` requires every changed plugin's `plugin.json` version to strictly increase, and `scripts/validate.sh` requires the top `## [X.Y.Z]` entry in the changelog to match `metadata.version`.

Tagging is a **manual** step (there is no CI auto-tag). After a pull request that bumps `metadata.version` is merged to `master`, tag the release from an up-to-date `master`:

```bash
git checkout master && git pull
git tag v<version>        # match metadata.version, e.g. git tag v0.45.0
git push --tags
```
