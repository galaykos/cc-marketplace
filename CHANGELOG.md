# Changelog

All notable changes to this marketplace are documented here. The version below
is the marketplace `metadata.version`; individual plugins carry their own
version in their `plugin.json`.

## [0.29.0] - 2026-07-06

### Added

- **javascript** 0.1.0: new plugin — vanilla (non-TypeScript) JavaScript best practices: version-aware ES feature floors (ES2020–ES2024) resolved from engines/browserslist/lockfile, strict equality and coercion traps, ESM vs CommonJS interop, async correctness and the event loop, this-binding and closures/leaks, immutability, error handling, boundary validation, number precision/BigInt, prototype-pollution safety. Includes /javascript:review
- **vite** 0.1.0: new plugin — Vite best practices: VITE_-prefix env security (secrets never shipped to client bundles), dep pre-bundling, code splitting and manualChunks, base for sub-path deploys, dev server.proxy, define stringify pitfalls, import.meta.glob, asset handling, build.target alignment, SSR, library mode, plugin order, HMR guards; version-pinned to the locked vite version and vite.config. Includes /vite:review
- **README.md** for 11 stack plugins that lacked one (php, laravel, react, react-native, vue2, vue3, livewire, sql, mysql, mariadb, postgresql) — install / commands / example / pairs-well-with, mirroring the typescript/inertia template

### Changed

- **laravel** 0.2.0: skill gains a version-awareness pair of sections (know-the-version + a doc-verified per-version leverage map for Laravel 10/11/12) and a mass-assignment security section ($fillable vs $guarded, the $request->all() OWASP trap, casts()/API-Resource notes); two new Common-mistakes bullets; plugin.json and marketplace descriptions synced
- **frontend-suite** 0.2.0: javascript and vite added to bundle dependencies
- **php-suite** 0.2.0: vite added to bundle dependencies (Laravel's default asset bundler)
- **everything** 0.9.0: javascript and vite added to bundle dependencies

## [0.28.0] - 2026-07-06

### Added

- **automations-suite** 0.1.0: new plugin suite for browser automation and anti-detect browsing — five per-tool navigator plugins, a cross-tool planner, and a shared worker agent, bundled by the `automations-suite` meta-bundle
- **playwright** 0.1.0: new plugin — Playwright navigator: current API from live docs (playwright.dev), link map (locators, auto-wait, network interception, storageState auth, test runner, trace, connectOverCDP), robust-automation patterns, and driving an anti-detect browser over CDP. Includes /playwright:check
- **puppeteer** 0.1.0: new plugin — Puppeteer navigator: current API from live docs (pptr.dev), waits, request interception, puppeteer-extra stealth, and attaching to an anti-detect browser via browserWSEndpoint. Includes /puppeteer:check
- **adspower** 0.1.0: new plugin — AdsPower Local API navigator: profile lifecycle, start/stop browser, the CDP/WebSocket handoff to a driver, rate limits and status codes. Includes /adspower:check
- **kameleo** 0.1.0: new plugin — Kameleo Local API/SDK navigator: fingerprint → profile → start flow, connecting a driver over CDP, fingerprint configuration. Includes /kameleo:check
- **camoufox** 0.1.0: new plugin — Camoufox navigator: current Python usage (camoufox.com), launch options (humanize, geoip, os, proxy, config), and the Playwright-Firefox integration it exposes. Includes /camoufox:check
- **automation-builder** 0.1.0: new plugin — browser-automation planner and worker: a think-process skill (tool choice → sequenced plan) plus a browser-automation-engineer agent that scaffolds and runs automations. Includes /automation-builder:build

### Changed

- **everything** 0.8.0: playwright, puppeteer, adspower, kameleo, camoufox, automation-builder added to bundle dependencies (six new leaf plugins)

## [0.27.0] - 2026-07-06

### Added

- **taskmaster** 0.11.0: new `erd` skill — spec-time data-model diagrams (mermaid erDiagram in the spec's Data Model section, inline-SVG approval preview via the shared diagram.html slot); pointer hooks in grill, visual-decisions, and task-cards; Data Model section is a binding contract for implementation cards. README row synced

## [0.26.0] - 2026-07-06

### Changed

- **approaches** 0.2.0: new opinion-round skill — three parallel blind opinion-lens subagents (Standards Purist, Quality-over-Speed, Skeptic-Investigator) argue refactor-shaped tasks independently; inline synthesis converges to one pick + kill-trigger in a single round, auto-proceeding unless the split is structural; UserPromptSubmit nudge hook (fail-open, non-blocking) and /approaches:opinions manual command

## [0.25.0] - 2026-07-06

### Changed

- **taskmaster** 0.10.0: pipeline wires companions in — code-architecture plan check on the spec before card-splitting and a decision-records ADR offer, both installed-guarded (grill handoff mirrors the offer); task cards carry a "Skills to apply" field stamped from the stack-scan inventory and are sized via the estimation plugin when installed
- **task-runner** 0.5.0: conditional reviewer pass after each task's verify passes (code-reviewer always; ui-ux/architecture/security reviewers by task content) — blocker/major findings re-enter the bounded fix loop under the same 3-cycle cap; docs-upkeep drift check joins the completion gate
- validator: hard trigger-surface gates — skill descriptions must carry "Use when/before/after/during" phrasing, agent descriptions need PROACTIVELY or an explicit sub-dispatch marker ("Spawned by")

## [0.24.0] - 2026-07-05

### Added

- **observability** 0.1.0: new plugin — application observability with judgment: structured JSON logs with correlation IDs, log-level semantics, log hygiene (no secrets/PII, bounded payloads), RED/USE metrics without cardinality bombs, trace-context propagation, symptom-based alerting, liveness-vs-readiness health checks. Includes /observability:review
- **error-handling** 0.1.0: new plugin — language-agnostic error-handling discipline: fail fast on programmer errors, handle operational errors where you can act, no swallowed exceptions, wrap-and-rethrow with cause chains, typed errors over message-string matching, one report per failure, operator-grade messages, user-facing vs internal split. Includes /error-handling:review
- **concurrency** 0.1.0: new plugin — application-level concurrency safety: check-then-act races, optimistic vs pessimistic locking, idempotency keys for retried operations, queue-consumer dedup under at-least-once delivery, distributed locks with TTL + fencing, async parallel-write pitfalls, transaction limits. Includes /concurrency:review
- **frontend-suite**, **php-suite**, **db-suite**, **quality-suite**, **process-suite** 0.1.0: five category bundles — schema-native one-command install per README category, each with its own /`<bundle>`:uninstall prune command. A plugin may appear in several bundles; bundles never contain other bundles
- **code-architecture** 0.6.0: new solid-principles skill (SOLID applied with judgment — detection cue, fix, and when-NOT counterweight per principle) and /code-architecture:solid review command

### Changed

- **everything** 0.7.0: design-preview, observability, error-handling, concurrency added to bundle dependencies (now 51 — every non-bundle plugin)
- Boundary sharpening — overlap-cluster descriptions now name their deferrals in both directions: **dev-env** 0.3.2 ↔ **devops** 0.1.1 (local dev environments vs CI/CD + production), **api-design** 0.3.2 ↔ **api-docs-first** 0.2.1 ↔ **meta-api** 0.2.1 (own APIs vs third-party docs vs Meta platform), **code-architecture** ↔ system-design (code-level structure vs system topology), code-review → framework review plugins (already stated; README row synced)

## [0.23.0] - 2026-07-05

### Added

- **design-preview** 0.1.0: new plugin — real-component visual decisions for Vite + React: candidate variants rendered with the project's own components on its dev server via a scratch HTML entry, strict consent + verified cleanup; falls back to taskmaster's shell mockups. Includes /design-preview:preview

### Changed

- **taskmaster** 0.9.0: theme-aware mockup shell with content primitives, motion decision passes, live-preview infra unified on one server with per-purpose files
- **api-design** 0.3.1, **code-architecture** 0.5.2, **dev-env** 0.3.1: live-preview integration mentions (contract-preview artifact, current-vs-target diagrams, topology diagram before YAML)

## [0.22.0] - 2026-07-05

### Added

- **orchestration** 0.1.0: new plugin — subagent orchestration discipline. delegation-contracts skill (self-contained prompt contracts with scope locks, compressed evidence-backed return formats, model/effort tiering per stage, scout-then-fanout, isolation rules for parallel writers) and verification-panels skill (cost-gated refuter voting, judge panels over independent attempts, loop-until-dry discovery, completeness-critic passes). Both auto-trigger from context. Includes /orchestration:review (report-only audit of fan-out plans and drafted agent prompts)

### Changed

- **everything** 0.6.0, **taskmaster-suite** 0.5.0: orchestration added to bundle dependencies
- **task-runner** 0.4.1, **code-architecture** 0.5.1, **taskmaster** 0.5.1, **git-workflow** 0.1.1: one-line delegation pointers to the orchestration plugin (parallel-planning, task-execution, task-orchestration, task-cards, worktree-isolation skills)

## [0.21.0] - 2026-07-05

### Added

- **packages** 0.1.0: new plugin — composer/npm dependency hygiene: semver constraint strategy (caret default, exact-pin cases, composer ~ vs npm ~ trap), lockfile discipline (commit always, npm ci/composer install in CI, regenerate on conflict), security-audit triage with fix lanes, and patch/minor/major upgrade lanes. Includes /packages:audit (report-only)

### Changed

- **everything** 0.5.0, **taskmaster-suite** 0.4.0: packages added to bundle dependencies

## [0.20.0] - 2026-07-05

### Changed

- **everything** 0.4.0: dependencies now include plugin-scout — added to the marketplace in 0.16.0 but never picked up by the bundle, leaving "installs every plugin" one plugin short

## [0.19.0] - 2026-07-05

### Added

- **hindsight** 0.1.0: new plugin — cross-session self-improvement loop. A SessionEnd hook appends per-session friction stats (turns, errors, best-effort friction events) to a gitignored project-local ledger (`.claude/hindsight/ledger.jsonl`); `/hindsight:harvest` ranks unmined sessions by friction score (fallback: direct transcript listing covers pre-install history), fans out a transcript-miner agent per session, applies a ≥2-session recurrence gate, and proposes CLAUDE.md rules, skill/plugin ideas, and failed-approach warnings — applied only on explicit approval; each report is also saved to `.claude/hindsight/reports/`

### Changed

- **everything** 0.3.0, **taskmaster-suite** 0.3.0: hindsight added to bundle dependencies

## [0.18.0] - 2026-07-05

### Changed

- **task-runner** 0.4.0: dropped the live run-board HTML — a status table duplicates what the task index and the conversation already show and goes stale when regeneration is forgotten. New rule in the task-execution skill ("No status theater"): HTML/localhost artifacts are reserved for content that earns the medium — mockups, interactive walkthroughs, behavior-proving demos, brainstorm canvases; command, README, and marketplace description updated to match

## [0.17.0] - 2026-07-05

### Changed

- Model-tier convention for agents — model now matches the cost of a wrong answer: **code-architecture** 0.5.0 (architecture-reviewer), **code-review** 0.2.0 (code-reviewer), and **system-design** 0.2.0 (system-architect) switch judgment-heavy agents from `model: sonnet` to `model: opus`; **taskmaster** 0.5.0 drops context-scout from `effort: xhigh` to `effort: high` (mechanical recon); **claude-authoring** 0.2.0 documents the tier table (opus/sonnet/haiku by wrong-answer cost), the orthogonal effort knob, and the per-invocation dispatch override in the authoring-agents skill

## [0.16.0] - 2026-07-05

### Added

- **plugin-scout** 0.1.0: new plugin — scans the current project's manifests (composer.json, package.json, tsconfig.json, .env, docker files) and suggests marketplace plugins in two tiers: stack-matched with per-row evidence, and the universal always-useful set; marks already-installed plugins via `claude plugin list`, reuses stack-scan's inventory when installed, and installs picked plugins via `claude plugin install <name>@cc-plugins-marketplace` after an AskUserQuestion confirm (headless: prints the commands). Includes /plugin-scout:suggest

## [0.15.0] - 2026-07-05

### Changed

- **everything** 0.2.0, **taskmaster-suite** 0.2.0: self-cleaning uninstall — each bundle ships /everything:uninstall and /taskmaster-suite:uninstall, which confirm via a selectable choice, then run `claude plugin uninstall <bundle> --prune -y` so the bundle and its auto-installed dependencies go in one step (the /plugin menu's uninstall does not prune); bundle descriptions now say so
- README: bundle uninstall instructions — --prune flag, standalone `claude plugin prune`, and the /plugin-menu-does-not-prune gotcha

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

- Suite-wide handoff-offer audit (43 findings across 3 review passes, all fixed): every command or skill that ends with a logical next step — apply the review fixes, run the engine-specific review, implement the approved plan/contract, record the ADR, finish the branch, run the retro — now offers it as a selectable choice (AskUserQuestion) instead of leaving a command to type; bare commands remain only for headless runs. Minor bumps: react 0.2.0, react-native 0.2.0, vue2 0.2.0, vue3 0.2.0, php 0.2.0, laravel 0.2.0, livewire 0.2.0, sql 0.2.0, mysql 0.2.0, mariadb 0.2.0, postgresql 0.2.0, typescript 0.2.0, inertia 0.3.0, code-architecture 0.4.0, design-patterns 0.2.0, api-docs-first 0.2.0, meta-api 0.2.0, stack-scan 0.2.0, api-design 0.3.0, dev-env 0.3.0
- **decision-records** (within 0.1.0): ADRs live at taskmaster-docs/adr/ — all suite output (specs, tasks, ADRs) under the one taskmaster-docs/ root
- **taskmaster** 0.4.0: pipeline outputs move from docs/ to taskmaster-docs/ (specs and task cards) — no collision with a project's own docs/ or superpowers' docs/plans; brainstorm skill now offers the grill continuation instead of auto-running it
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
