# AGENTS.md — Codex conventions for this repo

This repository is BOTH a Claude Code plugin marketplace (`plugins/`, canonical) and a
Codex marketplace (`.agents/`, `codex/`, generated one-way by `scripts/gen-codex/`).
Do not hand-edit anything under `.agents/` or `codex/` — regenerate with
`node scripts/gen-codex/gen.mjs`; `scripts/validate-codex.sh` enforces freshness.

## Codex install

- `codex plugin marketplace add galaykos/cc-marketplace` — skills + hooks.
- `git clone` this repo, then `bash codex/install-agents.sh` — the subagents
  (Codex plugins cannot bundle subagents, so they install out-of-band).

## Per-plugin fidelity (consumer authoritative copy lives in the catalog/manifests)

| Plugin | Faithful | Degraded | Dropped | Co-installs |
|--------|----------|----------|---------|-------------|
| a11y | 1 | 1 | 0 | — |
| adspower | 3 | 1 | 0 | — |
| api-design | 1 | 1 | 0 | — |
| api-docs-first | 2 | 1 | 0 | — |
| approaches | 4 | 3 | 0 | — |
| automation-builder | 2 | 2 | 0 | — |
| automations-suite | — | — | grouping-only (installs nothing) | — |
| brain | 1 | 2 | 0 | — |
| build-vs-buy | 1 | 1 | 0 | — |
| camoufox | 3 | 1 | 0 | — |
| claude-authoring | 6 | 4 | 0 | — |
| code-architecture | 8 | 5 | 0 | — |
| code-review | 1 | 2 | 0 | — |
| concurrency | 1 | 1 | 0 | — |
| database | 0 | 1 | 0 | mariadb-best-practices, mysql-best-practices, postgresql-best-practices, sql-best-practices |
| db-suite | — | — | grouping-only (installs nothing) | — |
| debugging | 1 | 1 | 0 | — |
| decision-records | 1 | 1 | 0 | — |
| design-patterns | 1 | 1 | 0 | — |
| design-preview | 1 | 1 | 0 | — |
| dev-env | 2 | 2 | 0 | — |
| devops | 0 | 1 | 0 | docker-best-practices |
| docs-upkeep | 1 | 1 | 0 | — |
| error-handling | 1 | 1 | 0 | — |
| estimation | 1 | 1 | 0 | — |
| everything | — | — | grouping-only (installs nothing) | — |
| frontend-suite | — | — | grouping-only (installs nothing) | — |
| git-workflow | 3 | 1 | 0 | — |
| hindsight | 0 | 3 | 2 | — |
| inertia | 1 | 1 | 0 | — |
| javascript | 1 | 1 | 0 | — |
| kameleo | 3 | 1 | 0 | — |
| laravel | 1 | 1 | 0 | — |
| livewire | 1 | 1 | 0 | — |
| mariadb | 1 | 1 | 0 | — |
| meta-api | 2 | 1 | 0 | — |
| mysql | 1 | 1 | 0 | — |
| observability | 1 | 1 | 0 | — |
| orchestration | 2 | 4 | 0 | — |
| packages | 1 | 1 | 0 | — |
| performance | 0 | 1 | 0 | — |
| php | 1 | 1 | 0 | — |
| php-suite | — | — | grouping-only (installs nothing) | — |
| playwright | 3 | 1 | 0 | — |
| plugin-scout | 1 | 0 | 1 | — |
| postgresql | 1 | 1 | 0 | — |
| process-suite | — | — | grouping-only (installs nothing) | — |
| puppeteer | 3 | 1 | 0 | — |
| quality-suite | — | — | grouping-only (installs nothing) | — |
| react | 1 | 1 | 0 | — |
| react-native | 1 | 1 | 0 | — |
| resilience | 1 | 1 | 0 | — |
| retrospective | 1 | 1 | 0 | — |
| rollout | 1 | 1 | 0 | — |
| security | 1 | 2 | 0 | — |
| shadcn-studio | 2 | 1 | 0 | — |
| skill-router | 1 | 0 | 1 | — |
| sql | 1 | 1 | 0 | — |
| stack-scan | 1 | 1 | 0 | — |
| system-design | 0 | 1 | 0 | — |
| task-runner | 1 | 3 | 0 | — |
| taskmaster | 10 | 9 | 0 | — |
| taskmaster-suite | — | — | grouping-only (installs nothing) | — |
| testing | 2 | 2 | 0 | — |
| typescript | 1 | 1 | 0 | — |
| ui-ux | 9 | 4 | 0 | — |
| vite | 1 | 1 | 0 | — |
| vue2 | 1 | 1 | 0 | — |
| vue3 | 1 | 1 | 0 | — |
| web-dev | 0 | 1 | 0 | javascript-best-practices, laravel-best-practices, react-best-practices, typescript-best-practices, vue2-best-practices, vue3-best-practices |
