# Changelog

All notable changes to this marketplace are documented here. The version below
is the marketplace `metadata.version`; individual plugins carry their own
version in their `plugin.json`.

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
