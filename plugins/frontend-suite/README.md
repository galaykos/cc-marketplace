# frontend-suite

Meta-bundle: the frontend category in one install — UI/UX stacks, React,
React Native, Vue 3, Next.js, Nuxt, JavaScript, TypeScript, Vite, Inertia, Livewire, the
generalist web worker, real-component visual decisions, greenfield shadcn
staging, and accessibility auditing. Uninstalls cleanly:
`/frontend-suite:uninstall` removes the bundle and prunes the plugins it
auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install frontend-suite@cc-plugins-marketplace
```

## What's included

- **ui-ux** — per-stack UI skills (shadcn/ui, ReUI, Aceternity, Tailwind,
  CSS3, Bootstrap, Grid, Flexbox) plus `/ui-ux:build`, `/ui-ux:review`,
  `/ui-ux:theme`
- **react** — hooks rules, render/memo performance, server-state caching,
  plus `/react:review`
- **react-native** — list performance, navigation, platform-specific code,
  animations, plus `/react-native:review`
- **vue3** — script setup, composables, ref/reactive pitfalls, Pinia, plus
  `/vue3:review`

Note: **vue2** (Vue 2 is EOL) is no longer bundled — install it standalone for
legacy-app maintenance: `/plugin install vue2@cc-plugins-marketplace`.
- **javascript** — version-aware ES feature floors, coercion traps, ESM/CJS
  interop, async correctness, plus `/javascript:review`
- **typescript** — strict mode as the floor, narrowing over assertions,
  satisfies, runtime validation, plus `/typescript:review`
- **vite** — env security, code splitting, base for sub-path deploys, dev
  proxy, plus `/vite:review`
- **inertia** — partial reloads, deferred props, useForm flow, SSR across
  adapters, plus `/inertia:review`
- **livewire** — Livewire 3 conventions, wire:model modifiers, Alpine
  interop, plus `/livewire:review`
- **web-dev** — the generalist web-developer worker and frontend-reviewer
  agents (no commands)
- **design-preview** — visual decisions rendered with the project's OWN
  components on its own dev server, via `/design-preview:preview`
- **shadcn-studio** — self-contained shadcn + Vite sandbox for staging
  interactive component variants, via `/shadcn-studio:stage`
- **a11y** — WCAG 2.1 AA audit with a concrete fix per violation, via
  `/a11y:audit`
- **nextjs** — App Router server/client boundaries, opt-in caching, server
  actions, route handlers, streaming, metadata API, plus `/nextjs:review`
- **nuxt** — Nitro server routes, hybrid rendering route rules,
  useFetch/useAsyncData, SSR-safe state, auto-imports discipline, plus
  `/nuxt:review`

| Command | What it does |
|---------|--------------|
| `/frontend-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **laravel** — the backend that Inertia and Livewire frontends sit on
- **performance** — hotspot and cache-correctness review beyond the UI layer
- **testing** — test review for the components these stacks produce
