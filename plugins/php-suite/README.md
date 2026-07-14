# php-suite

Meta-bundle: the PHP category in one install — PHP and Laravel best practices,
Livewire, Inertia, Vite (Laravel's default asset bundler), and the generalist
web worker. Uninstall cleanly with `/php-suite:uninstall` — removes the bundle
and prunes its auto-installed plugins.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install php-suite@cc-plugins-marketplace
```

Installing the bundle pulls in every plugin below as a dependency.

## What's included

- **php** — PHP best practices (strict types, PSR conventions, version-aware 8.1-8.5 leverage) with `/php:review`
- **laravel** — Laravel framework review (Eloquent N+1 prevention, form requests, thin controllers, migrations) with `/laravel:review`
- **livewire** — Livewire 3 component conventions, wire:model modifiers, performance, and Alpine interop with `/livewire:review`
- **inertia** — Inertia.js partial reloads, deferred props, useForm flow, and SSR across the Laravel adapters with `/inertia:review`
- **vite** — Vite env security, code splitting, and build-config review pinned to the locked vite version with `/vite:review`
- **web-dev** — generalist web-developer worker plus a frontend-reviewer agent that defers stack idioms to the per-framework plugins

## Commands

| Command | What it does |
|---------|--------------|
| `/php-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **db-suite** — the database category bundle for the persistence side of a PHP app
- **quality-suite** — the code-quality category bundle (review, testing, security, and more) on top of the stack rules
- **dev-env** — docker-compose scaffolding and Docker review for the services a PHP app runs against
