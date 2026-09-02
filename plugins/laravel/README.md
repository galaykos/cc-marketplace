# laravel

Laravel best practices — Eloquent N+1 prevention and eager loading, form request
validation, thin controllers with service/action classes, queued jobs, authorization
policies, additive-first migrations, a per-version leverage map for Laravel 11/12/13 —
and the **Inertia.js** skill it pairs with (v1/v2/v3, Vue/React/Svelte adapters:
partial reloads, deferred and lazy props, `useForm`, shared data, SSR), behind one
`/laravel:review` that loads Inertia when the manifests show it.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install laravel@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/laravel:review [files-or-diff]` | Review controllers, models, jobs, migrations — and Inertia pages and shared-data setup when `inertiajs/inertia-laravel` or an `@inertiajs/*` adapter is installed — pinned to the versions in `composer.lock` and the JS lockfile |

```bash
/laravel:review app/Http/Controllers/OrderController.php
/laravel:review resources/js/Pages/Orders/Index.vue app/Http/Controllers/OrderController.php
/laravel:review         # reviews the current diff
```

## Skills

| Skill | Reach for it when |
|---|---|
| `laravel-best-practices` | Controllers, models, jobs, migrations — the daily Laravel surface; advice pinned to the installed `laravel/framework` |
| `inertia-best-practices` | Inertia pages, props, partial reloads, `useForm`, shared data, SSR; v2 features (deferred props, prefetching, polling, merge props) only when the lockfile shows v2+, v3 leverage (the `@inertiajs/vite` plugin owning entry/SSR wiring, ESM-only, axios removed) only on v3; adapter idiom matched from the lockfile |

Also ships the shared `backend-engineer` worker agent (PHP/Laravel) that the review
routes its fixes to. With `skill-router` installed the skills load on their own as
matching files are edited.

## Pairs well with

- **web-dev** — the JS side: its `frontend-reviewer` loads `inertia-best-practices` from here when installed
- **sql** / **mariadb** — the queries under the models
- **api-design** — REST contract shape and spec-first scaffolding
