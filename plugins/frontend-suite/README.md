# frontend-suite

Meta-bundle: the frontend category in one install — UI/UX stacks, React,
React Native, Vue 3, Next.js, Nuxt, Vite, Three.js, Inertia, Livewire, the
generalist web worker, the craft layer, real-component visual decisions,
greenfield shadcn staging, live registry sourcing, file-aware skill
auto-routing, and accessibility auditing. Uninstalls cleanly:
`/frontend-suite:uninstall` removes the bundle and prunes the plugins it
auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install frontend-suite@cc-plugins-marketplace
```

## What's included

One bullet per bundled plugin, in dependency order (17):

- **a11y** — WCAG 2.2 AA audit with a concrete fix per violation, via
  `/a11y:audit`
- **craft-layer** — creative direction, section decisions, asset sourcing,
  and tiered motion for distinctive builds, via `/craft-layer:craft`
- **design-preview** — visual decisions rendered with the project's OWN
  components on its own dev server, via `/design-preview:preview`
- **inertia** — partial reloads, deferred props, useForm flow, SSR across
  adapters, plus `/inertia:review`
- **livewire** — Livewire 3/4 conventions, wire:model modifiers, Alpine
  interop, plus `/livewire:review`
- **nextjs** — App Router server/client boundaries, opt-in caching, server
  actions, route handlers, streaming, metadata API, plus `/nextjs:review`
- **nuxt** — Nitro server routes, hybrid rendering route rules,
  useFetch/useAsyncData, SSR-safe state, auto-imports discipline, plus
  `/nuxt:review`
- **react** — server-state caching discipline (TanStack Query/SWR/RTK Query)
- **react-native** — list performance, navigation, platform-specific code,
  animations, plus `/react-native:review`
- **registry-source** — live component-registry MCP servers (Aceternity,
  shadcn, Magic UI, ReUI) so sourcing reads the source, never memory
- **shadcn-studio** — self-contained shadcn + Vite sandbox for staging
  interactive component variants, via `/shadcn-studio:stage`
- **skill-router** — file-aware skill auto-routing: hooks load the matching
  best-practice skill(s) as files are edited
- **threejs** — WebGPU-first Three.js review, TSL shaders, R3F/drei, asset
  pipelines, disposal discipline, plus `/threejs:review`
- **ui-ux** — per-stack UI skills (shadcn/ui, ReUI, Aceternity, Tailwind)
  plus `/ui-ux:build`, `/ui-ux:review`, `/ui-ux:theme`
- **vite** — env security, code splitting, base for sub-path deploys, dev
  proxy, plus `/vite:review`
- **vue3** — script setup, composables, ref/reactive pitfalls, Pinia, plus
  `/vue3:review`
- **web-dev** — the generalist web-developer worker and frontend-reviewer
  agents (no commands)

| Command | What it does |
|---------|--------------|
| `/frontend-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **laravel** — the backend that Inertia and Livewire frontends sit on
- **performance** — hotspot and cache-correctness review beyond the UI layer
- **testing** — test review for the components these stacks produce
