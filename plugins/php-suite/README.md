# php-suite

Meta-bundle: the PHP category in one install — laravel (Laravel best practices
and the Inertia.js skill behind one `/laravel:review`, plus the backend-engineer
worker), web-dev (the generalist worker, the frontend-reviewer, and the Vite
skill for Laravel's default asset bundler) and code-review (the review fan-in
plus comment discipline: the no-comment default and its write-time denies).
Uninstall cleanly with `/php-suite:uninstall` — removes the bundle
and prunes its auto-installed plugins.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install php-suite@cc-plugins-marketplace
```

Installing the bundle pulls in every plugin below as a dependency.

## What's included

- **laravel** — Laravel framework review (Eloquent N+1 prevention, form requests, thin controllers, migrations) and Inertia.js (partial reloads, deferred props, useForm flow, SSR across the adapters) with one `/laravel:review`, plus the backend-engineer worker
- **web-dev** — generalist web-developer worker, the opus-floored frontend-reviewer, and the Vite skill (env security, code splitting, build config pinned to the locked vite version) via `/web-dev:review`
- **code-review** — `/code-review:review`, the stack-agnostic fan-in, plus comment discipline: the default is no comment, and write-time hooks deny restatement, commented-out code, signature-repeating PHPDoc tags and any new file over the 0.4:1 comment ceiling, once per file per session

## Commands

| Command | What it does |
|---------|--------------|
| `/php-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **database** — the persistence side of a PHP app: `/database:review`, the sql and mariadb skills, the schema worker
- **quality-suite** — the rest of the enforcing-mechanism bundle (architecture's evidence gate, candor, command guard, secret scanning, lean; testing and security now live in **quality-principles-suite**) on top of the stack rules
- **devops** — `/devops:init` compose scaffolding and Docker review for the services a PHP app runs against
