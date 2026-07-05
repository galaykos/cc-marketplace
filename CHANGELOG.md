# Changelog

All notable changes to this marketplace are documented here. The version below
is the marketplace `metadata.version`; individual plugins carry their own
version in their `plugin.json`.

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
