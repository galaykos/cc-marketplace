# craft-suite

Meta-bundle: the creative-build studio in one install — concept-first
creative direction with a tiered motion catalog and WebGL/Three.js effects
(craft-layer), and the companion it requires: ui-ux, which carries the per-library
stack skills, the WCAG audit, CSS-variable theming with a live colour preview, and the
accessibility engineer that applies an audit's fix list. Split out of frontend-suite so
ordinary frontend app work does not pay the studio's always-on context. Uninstalls
cleanly: `/craft-suite:uninstall` removes the bundle and every plugin it lists as a
dependency at the same scope, minus anything another installed suite also lists — read
the list it prints before accepting it, because it cannot tell a hand-install from an
auto-install.

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
**6,000 chars**, and this bundle's listing costs **8,524 chars** (LC_ALL=C bytes — the marketplace's deterministic measure, ~1% above what the CLI counts; measured 2026-09-15, `bash scripts/context-budget.sh`, listing channel) — over
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

One bullet per bundled plugin, in dependency order (2):

- **craft-layer** — creative direction, section decisions, asset sourcing,
  and tiered motion for distinctive builds, via `/craft-layer:craft`
- **ui-ux** — per-stack UI skills (shadcn/ui, ReUI, Aceternity, Astryx, Material UI,
  Tailwind) and the library-agnostic `component-libraries` floor for any other React or
  Vue component library, plus `/ui-ux:build`, `/ui-ux:audit` and `/ui-ux:theme`.
  design-studio was retired 2026-09-14: its browser design session
  measured one real use, its real-component preview became a rung of
  `taskmaster:visual-decisions`, and live registry lookups now go to shadcn's own MCP
  server and ReUI's hosted one, named in the stack skills <!-- removed-ok -->

ui-ux is listed here AND in frontend-suite on purpose: craft-layer
delegates theming to ui-ux and auditing to `/ui-ux:audit`, so a standalone
craft-suite install must carry both. Installing both suites installs each
companion once.

| Command | What it does |
|---------|--------------|
| `/craft-suite:uninstall` | Uninstall the bundle AND remove every plugin it lists as a dependency at the same scope, minus anything another installed suite also lists — one step, no orphans. It cannot tell an auto-install from one you made yourself: install records routinely carry no marker, so a dependency you installed by hand appears in the removal list and the confirm step is what protects it |

## Pairs well with

- **frontend-suite** — the stack half: Next.js/React Native/Vite reviews and
  the generalist web worker for the app the studio decorates
- **resilience** — its `/resilience:review --concern performance`: motion and WebGL work is exactly where frame budgets die
