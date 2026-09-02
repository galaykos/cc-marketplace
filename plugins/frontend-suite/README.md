# frontend-suite

Meta-bundle: the frontend stack category in one install — UI/UX stacks,
web-dev (Next.js, React Native and Vite skills behind `/web-dev:review`, the
generalist worker and the opus-floored frontend-reviewer), file-aware skill
auto-routing, and the WCAG audit inside ui-ux. Inertia lives in the laravel plugin. The creative-build studio (craft-layer, design-lab) moved to the craft-suite bundle, so
ordinary frontend app work does not pay the studio's always-on context.
Uninstalls cleanly: `/frontend-suite:uninstall` removes the bundle and
prunes the plugins it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install frontend-suite@cc-plugins-marketplace
```

## What's included

One bullet per bundled plugin, in dependency order (3):

- **skill-router** — file-aware skill auto-routing: hooks load the matching
  best-practice skill(s) as files are edited
- **ui-ux** — per-stack UI skills (shadcn/ui, ReUI, Aceternity, Tailwind)
  plus `/ui-ux:build`, `/ui-ux:review`, `/ui-ux:theme`
- **web-dev** — Next.js (App Router boundaries, opt-in caching, server
  actions), React Native (lists, navigation, Expo inversions) and Vite (env
  security, chunking, `base`) skills behind one `/web-dev:review`, plus the
  generalist web-developer worker and the opus-floored frontend-reviewer

| Command | What it does |
|---------|--------------|
| `/frontend-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **craft-suite** — the creative-build studio half: craft-layer's design
  pipeline and motion catalog, design-lab's preview, studio and registry MCP
- **laravel** — the backend that Inertia frontends sit on
- **resilience** — `/resilience:performance-review`, hotspot and cache-correctness review beyond the UI layer
- **testing** — test review for the components these stacks produce
