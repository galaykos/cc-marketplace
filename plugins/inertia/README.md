# inertia

Inertia.js best practices (Laravel + Vue): partial reloads, deferred and lazy
props, `useForm` flow, shared data via middleware, prop hygiene, SSR, code
splitting, v1 vs v2 feature awareness.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install inertia@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/inertia:review [files-or-diff]` | Review pages, controllers, and shared-data setup against the skill, pinned to the installed inertia-laravel / @inertiajs versions |

## Example

```bash
/inertia:review resources/js/Pages/Orders/Index.vue app/Http/Controllers/OrderController.php
/inertia:review            # reviews the current diff
```

v2 features (deferred props, prefetching, polling, merge props) are only
suggested when the lockfile shows v2 — v1 projects get v1 advice.

## Pairs well with

- **laravel** — backend side of the same pages
- **vue3** — component-level review; inertia:review covers the bridge
