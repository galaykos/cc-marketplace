# ui-ux

UI/UX best practices with per-stack skills — shadcn/ui, ReUI, Aceternity UI,
Tailwind, CSS3, Bootstrap, CSS Grid, Flexbox — plus a shadcn theme builder
with a live colour-preview URL and a ui-ux-reviewer agent.

Registry libraries (shadcn, [ReUI](https://reui.io/docs),
[Aceternity](https://ui.aceternity.com/components)) get docs-first treatment:
they have no npm version to pin against, so component APIs are verified on the
live docs page, never from memory. The skills split roles cleanly — shadcn/ReUI
for app UI, Aceternity for motion-heavy marketing pages, one primitive set per
project, everything themed through the same CSS-variable tokens.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install ui-ux@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/ui-ux:review [files-or-diff]` | Review UI code against the per-stack skills (shadcn, ReUI, Aceternity, Tailwind, CSS Grid, Flexbox…) |
| `/ui-ux:theme [brand-color-vibe-or-reference]` | Create or restyle a shadcn/ui theme with a live preview URL |

## Theme builder example

```bash
/ui-ux:theme deep teal, calm SaaS dashboard vibe
```

What happens:

1. Reads `components.json`, the current `globals.css`, and the Tailwind major
   version from the lockfile — v4 gets oklch tokens, v3 gets HSL triplets.
2. Generates up to 3 candidate token sets (light + dark, contrast-checked) and
   serves them at the shared preview URL `http://localhost:${PREVIEW_PORT:-8123}/theme.html` —
   swatch grid plus real component mockups (buttons, card, alert, badges,
   chart strip), light and dark side by side.
3. You pick per round (one axis at a time: hue → warmth → radius); the page
   auto-reloads on every regeneration — same URL the whole session.
4. On acceptance it shows the diff against your existing `globals.css` and
   applies only after a yes.

Colours are judged rendered on components, not as variable names — a `primary`
that looks great as a swatch can fail hard as a button.

## Contents

- **Skills**: shadcn-best-practices, shadcn-theming, reui-best-practices,
  aceternity-best-practices, tailwind-best-practices, css3-best-practices,
  bootstrap-best-practices, css-grid-best-practices, flexbox-best-practices
- **Agent**: ui-ux-reviewer

## Pairs well with

- **taskmaster** — its visual-decisions skill uses the same always-live mockup
  pattern for layout/flow choices
- **react / vue3** — component-logic review alongside the visual layer
