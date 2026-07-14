# nuxt

Nuxt best practices: Nitro server routes and event-handler validation, hybrid
rendering via route rules (prerender, swr, isr, ssr: false), useFetch/useAsyncData
semantics with payload keys and dedup, the bare-$fetch double-fetch footgun,
useState versus module-scope refs (cross-request pollution), auto-imports
discipline across app/server contexts, runtimeConfig NUXT_ env overrides, and
useSeoMeta/useHead.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install nuxt@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/nuxt:review [files-or-diff]` | Review pages, composables, and server routes against the skill, pinned to the installed Nuxt version from the lockfile |

## Example

```bash
/nuxt:review app/pages/checkout.vue server/api/orders.post.ts
/nuxt:review          # reviews the current diff
```

Advice pins to the installed Nuxt version, so Nuxt 3 projects are not judged by
Nuxt 4 semantics (shallow data refs, app/ directory, undefined defaults) — and
vice versa.

## Pairs well with

- **vue3** — component-level rules for the Vue code inside these pages
- **vite** — the build layer under the Nuxt dev server and bundling
- **typescript** — the type layer this framework review skips
- **ui-ux** — styling and accessibility review for the rendered markup
