# laravel

Laravel best practices — Eloquent N+1 prevention and eager loading, form request
validation, thin controllers with service/action classes, queued jobs, authorization
policies, additive-first migrations, a per-version leverage map for Laravel 11/12/13 —
and the **Inertia.js** skill it pairs with (v1/v2/v3, Vue/React/Svelte adapters:
partial reloads, deferred and lazy props, `useForm`, shared data, SSR). Review runs
through `/code-review:review`, the fan-in that loads the Laravel skill on `.php` /
`.blade.php` and the Inertia skill when the manifests show it (the plugin's own
review entry was retired on 2026-09-14 — it was a second name for that pass).

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install laravel@cc-plugins-marketplace
```

## Review

```bash
/code-review:review app/Http/Controllers/OrderController.php
/code-review:review resources/js/Pages/Orders/Index.vue app/Http/Controllers/OrderController.php
/code-review:review         # reviews the current diff
```

`/code-review:review` (the code-review plugin) reviews controllers, models, jobs,
migrations — and Inertia pages and shared-data setup when `inertiajs/inertia-laravel`
or an `@inertiajs/*` adapter is installed — pinned to the versions in `composer.lock`
and the JS lockfile.

On an apply pick that command dispatches its finding list down its **own** static
chain — `task-runner:task-executor` if installed, else inline — not to this plugin's
worker (`plugins/code-review/commands/review.md`, "This plugin ships a REVIEWER, not a
worker"). `backend-engineer` is reached by dispatching it directly, which is what its
PROACTIVELY-phrased description asks for; it is not wired into the review's apply path.

## Skills

| Skill | Reach for it when |
|---|---|
| `laravel-best-practices` | Controllers, models, jobs, migrations — the daily Laravel surface; advice pinned to the installed `laravel/framework` |
| `inertia-best-practices` | Inertia pages, props, partial reloads, `useForm`, shared data, SSR; v2 features (deferred props, prefetching, polling, merge props) only when the lockfile shows v2+, v3 leverage (the `@inertiajs/vite` plugin owning entry/SSR wiring, ESM-only, axios removed) only on v3; adapter idiom matched from the lockfile |

Also ships the shared `backend-engineer` worker agent (PHP/Laravel) for implementation
work; the review's fix list does not route to it (see above). With `skill-router` installed the skills load on their own as
matching files are edited.

## Pairs well with

- **web-dev** — the JS side: its `frontend-reviewer` loads `inertia-best-practices` from here when installed
- **database** — the queries under the models: the sql and mariadb skills (loaded by the fan-in on SQL and migrations) and the schema worker
- **api-design** — REST contract shape and spec-first scaffolding
