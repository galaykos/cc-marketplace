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

All current marketplace plugins (52 today) install as dependencies, grouped here by theme:

- **Stacks** — laravel, inertia, react-native, nextjs, vite, web-dev, threejs: framework best-practice skills and reviews
- **UI & accessibility** — ui-ux, shadcn-studio, design-preview, craft-layer, registry-source, a11y: component build/review, staged visual decisions, crafted animated experiences, registry-sourced components, WCAG auditing
- **Data** — sql, mariadb, database: engine-specific and engine-agnostic schema and query review
- **APIs & architecture** — api-design (incl. graphql-grpc skill), api-docs-first (incl. the docs-upkeep drift scan), system-design (incl. event-driven skill), code-architecture: contract, topology, and structure review
- **Delivery** — taskmaster, task-runner, git-workflow, code-review, testing, debugging, dev-env, devops: spec-to-ship pipeline and its gates
- **Quality & safety** — security (incl. data-privacy + api-auth skills), secret-scanning, command-guard, packages, performance, resilience (incl. error-handling + concurrency skills), observability, comment-discipline, candor: audits and write-time guards that catch defects before they ship, plus a Stop gate on the two dishonesty shapes a script can prove
- **Process** — approaches (incl. build-vs-buy, estimation, rollout, pattern-selection skills), hindsight, fresh-take: decision and learning loops around the work
- **Claude tooling** — claude-authoring, orchestration, skill-router, terse, lean, brain, plugin-scout, vercel-skills-scout, stack-scan, ultra-deep-research, llm-app: extending and steering Claude Code itself
- **Domain** — payments, i18n: payment-integration and internationalization review

Prefer a themed slice instead? The focused bundles — php-suite, frontend-suite,
craft-suite, db-suite, quality-suite, quality-principles-suite,
taskmaster-suite, process-suite, product-suite — each install one category.

## Uninstall

| Command | What it does |
|---------|--------------|
| `/everything:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |
