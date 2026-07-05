# inertia

Inertia.js best practices for Laravel with the Vue, React, or Svelte adapter:
partial reloads, deferred and lazy props, `useForm` flow, shared data via
middleware, prop hygiene, SSR, code splitting, v1 vs v2 feature awareness.

The core Inertia API (useForm, Link, router, usePage) is the same across
adapters — advice detects the installed adapter from the lockfile and matches
its idiom (`onMounted` vs `useEffect`, `.vue` vs `.tsx` page globs, Pinia vs
Zustand anti-patterns).

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install inertia@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/inertia:review [files-or-diff]` | Review pages, controllers, and shared-data setup against the skill, pinned to the installed inertia-laravel version and adapter (@inertiajs/vue3, react, or svelte) |

## Example

```bash
/inertia:review resources/js/Pages/Orders/Index.vue app/Http/Controllers/OrderController.php
/inertia:review            # reviews the current diff
```

v2 features (deferred props, prefetching, polling, merge props) are only
suggested when the lockfile shows v2 — v1 projects get v1 advice.

## Pairs well with

- **laravel** — backend side of the same pages
- **vue3 / react** — component-level review for your adapter; inertia:review covers the bridge
