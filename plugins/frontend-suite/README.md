# frontend-suite

Meta-bundle: the frontend stack category in one install — UI/UX stacks,
web-dev (Next.js, React Native and Vite skills behind `/web-dev:review`, the
generalist worker and the opus-floored frontend-reviewer), file-aware skill
auto-routing, the WCAG audit inside ui-ux, and code-review (the review fan-in
plus comment discipline: the no-comment default and its write-time denies).
Inertia lives in the laravel plugin. The creative-build studio (craft-layer, design-lab) moved to the craft-suite bundle, so
ordinary frontend app work does not pay the studio's always-on context.
Uninstalls cleanly: `/frontend-suite:uninstall` removes the bundle and
prunes the plugins it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install frontend-suite@cc-plugins-marketplace
```

## Context-window requirement (read before installing)

**Standing: `gate` for the declaration's presence, `recorded` for its numbers** —
`pc_listing_declaration` fails the build if this section disappears while the
bundle still overflows; nothing checks the figures below, so recompute them with
`bash scripts/context-budget.sh` before trusting them.

Claude Code budgets the skill listing it sends the model at
`contextWindowTokens x bytesPerToken x skillListingBudgetFraction` (default
fraction 0.01). On the default 200k window with a current-tokenizer model that is
**6,000 chars**, and this bundle's listing costs **~6,400 chars** (LC_ALL=C bytes —
the marketplace's deterministic measure, ~1% above what the CLI counts) — over
budget since ui-ux 0.20.0 added the Material UI and library-agnostic skills, so
the host reduces entries to name-only in priority order, silently, and the
evicted skills stop being reachable without any error.

On the 1M-context tier (30,000 chars) this bundle fits with room to spare. If you
run the default 200k window, add to the `settings.json` of the project where you
use this bundle:

```json
{ "skillListingBudgetFraction": 0.02 }
```

That raises the listing budget to 12,000 chars at 200k. The fraction is a
ceiling, not a purchase — it only admits description text that was previously
being evicted.

## What's included

One bullet per bundled plugin, in dependency order (4):

- **skill-router** — file-aware skill auto-routing: hooks load the matching
  best-practice skill(s) as files are edited
- **ui-ux** — per-stack UI skills (shadcn/ui, ReUI, Aceternity, Astryx, Material UI,
  Tailwind) and the library-agnostic `component-libraries` floor for any other
  React component library, plus `/ui-ux:build`, `/ui-ux:review`, `/ui-ux:theme`
- **web-dev** — Next.js (App Router boundaries, opt-in caching, server
  actions), React Native (lists, navigation, Expo inversions) and Vite (env
  security, chunking, `base`) skills behind one `/web-dev:review`, plus the
  generalist web-developer worker and the opus-floored frontend-reviewer
- **code-review** — `/code-review:review`, the stack-agnostic fan-in, plus
  comment discipline: the default is no comment, and write-time hooks deny
  restatement, commented-out code, signature-repeating JSDoc tags and any new
  file over the 0.4:1 comment ceiling, once per file per session

| Command | What it does |
|---------|--------------|
| `/frontend-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **craft-suite** — the creative-build studio half: craft-layer's design
  pipeline and motion catalog, design-lab's preview and registry MCP
- **laravel** — the backend that Inertia frontends sit on
- **resilience** — `/resilience:performance-review`, hotspot and cache-correctness review beyond the UI layer
- **testing** — test review for the components these stacks produce
