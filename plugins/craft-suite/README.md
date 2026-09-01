# craft-suite

Meta-bundle: the creative-build studio in one install — concept-first
creative direction with a tiered motion catalog, real-component visual
decisions, greenfield shadcn staging, live registry sourcing, WebGL/Three.js
effects, and the two companions the studio requires (ui-ux, a11y). Split out
of frontend-suite so ordinary frontend app work does not pay the studio's
always-on context. Uninstalls cleanly: `/craft-suite:uninstall` removes the
bundle and prunes the plugins it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install craft-suite@cc-plugins-marketplace
```

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle still overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **~8,796 chars** (LC_ALL=C bytes — the marketplace's deterministic measure, ~1% above what the CLI counts) — over
budget, the host reduces entries to name-only in priority order, silently, so
skills stop being reachable without any error.

On the 1M-context tier (30,000 chars) this bundle fits with room to spare. If you
run the default 200k window, add to the `settings.json` of the project where you
use this bundle:

```json
{ "skillListingBudgetFraction": 0.02 }
```

That raises the listing budget to 12,000 chars at 200k. The cost is real but
small: the fraction is a ceiling, not a purchase — it only admits description
text that was previously being evicted.

## What's included

One bullet per bundled plugin, in dependency order (7):

- **a11y** — WCAG 2.2 AA audit with a concrete fix per violation, via
  `/a11y:audit`
- **craft-layer** — creative direction, section decisions, asset sourcing,
  and tiered motion for distinctive builds, via `/craft-layer:craft`
- **design-preview** — visual decisions rendered with the project's OWN
  components on its own dev server, via `/design-preview:preview`
- **registry-source** — live component-registry MCP servers (Aceternity,
  shadcn, Magic UI, ReUI) so sourcing reads the source, never memory
- **shadcn-studio** — self-contained shadcn + Vite sandbox for staging
  interactive component variants, via `/shadcn-studio:stage`
- **threejs** — WebGPU-first Three.js review, TSL shaders, R3F/drei, asset
  pipelines, disposal discipline, plus `/threejs:review`
- **ui-ux** — per-stack UI skills (shadcn/ui, ReUI, Aceternity, Tailwind)
  plus `/ui-ux:build`, `/ui-ux:review`, `/ui-ux:theme`

ui-ux and a11y are listed here AND in frontend-suite on purpose: craft-layer
delegates theming to ui-ux and auditing to `/a11y:audit`, so a standalone
craft-suite install must carry both. Installing both suites installs each
companion once.

| Command | What it does |
|---------|--------------|
| `/craft-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **frontend-suite** — the stack half: Next.js/React Native/Vite reviews and
  the generalist web worker for the app the studio decorates
- **performance** — motion and WebGL work is exactly where frame budgets die
