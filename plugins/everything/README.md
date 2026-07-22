# everything

Meta-bundle: installs every plugin in this marketplace as a dependency — all
stacks, all workflows, all agents. One install, full suite. Uninstall cleanly
with `/everything:uninstall`, which removes the bundle and prunes the plugins
it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install everything@cc-plugins-marketplace
```

## What's included

All current marketplace plugins (70 today) install as dependencies, grouped here by theme:

- **Stacks** — php, laravel, livewire, inertia, javascript, typescript, react, react-native, nextjs, nuxt, vue2, vue3, node-backend, vite, web-dev: language and framework best-practice skills and reviews
- **UI & accessibility** — ui-ux, shadcn-studio, design-preview, a11y: component build/review, staged visual decisions, WCAG auditing
- **Data** — sql, mysql, mariadb, postgresql, database: engine-specific and engine-agnostic schema and query review
- **APIs & architecture** — api-design (incl. graphql-grpc skill), api-docs-first, system-design (incl. event-driven skill), code-architecture, design-patterns: contract, topology, and structure review
- **Delivery** — taskmaster, task-runner, git-workflow, code-review, testing, debugging, dev-env, devops, rollout: spec-to-ship pipeline and its gates
- **Quality & safety** — security (incl. data-privacy + api-auth skills), secret-scanning, packages, performance, resilience, error-handling, concurrency, observability, intent-guard, reuse-guard: audits that catch defects before they ship
- **Process** — approaches, retrospective, build-vs-buy, estimation, docs-upkeep, hindsight: decision and learning loops around the work
- **Browser automation** — playwright, puppeteer, automation-builder: driving real browsers and building automations on them
- **Claude tooling** — claude-authoring, orchestration, skill-router, brain, plugin-scout, stack-scan, compaction-advisor, ultra-deep-research, llm-app: extending and steering Claude Code itself
- **Domain** — payments, i18n: payment-integration and internationalization review

Prefer a themed slice instead? The focused bundles — php-suite, frontend-suite,
db-suite, quality-suite, taskmaster-suite, process-suite —
each install one category; browser-automation plugins install individually.

## Uninstall

| Command | What it does |
|---------|--------------|
| `/everything:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |
