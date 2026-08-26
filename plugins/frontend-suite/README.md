# frontend-suite

Meta-bundle: the frontend stack category in one install — UI/UX stacks,
React, React Native, Vue 3, Next.js, Nuxt, Vite, Inertia, Livewire, the
generalist web worker, file-aware skill auto-routing, and accessibility
auditing. The creative-build studio (craft-layer, design-preview,
shadcn-studio, registry-source, threejs) moved to the craft-suite bundle, so
ordinary frontend app work does not pay the studio's always-on context.
Uninstalls cleanly: `/frontend-suite:uninstall` removes the bundle and
prunes the plugins it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install frontend-suite@cc-plugins-marketplace
```

## What's included

One bullet per bundled plugin, in dependency order (8):

- **a11y** — WCAG 2.2 AA audit with a concrete fix per violation, via
  `/a11y:audit`
- **inertia** — partial reloads, deferred props, useForm flow, SSR across
  adapters, plus `/inertia:review`
- **nextjs** — App Router server/client boundaries, opt-in caching, server
  actions, route handlers, streaming, metadata API, plus `/nextjs:review`
- **react-native** — list performance, navigation, platform-specific code,
  animations, plus `/react-native:review`
- **skill-router** — file-aware skill auto-routing: hooks load the matching
  best-practice skill(s) as files are edited
- **ui-ux** — per-stack UI skills (shadcn/ui, ReUI, Aceternity, Tailwind)
  plus `/ui-ux:build`, `/ui-ux:review`, `/ui-ux:theme`
- **vite** — env security, code splitting, base for sub-path deploys, dev
  proxy, plus `/vite:review`
- **web-dev** — the generalist web-developer worker and frontend-reviewer
  agents (no commands)

| Command | What it does |
|---------|--------------|
| `/frontend-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **craft-suite** — the creative-build studio half: craft-layer's design
  pipeline and motion catalog, design-preview, shadcn-studio,
  registry-source, threejs
- **laravel** — the backend that Inertia and Livewire frontends sit on
- **performance** — hotspot and cache-correctness review beyond the UI layer
- **testing** — test review for the components these stacks produce
