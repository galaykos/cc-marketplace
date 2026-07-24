# Mining method — source checklist + extraction worksheet

The full procedure the SKILL summarises. Work top to bottom: gather sources, extract
both patterns and token direction from each, then fill the templates in
`brief-templates.md`. This file re-teaches nothing about token scales or palette
generation — those live in `plugins/ui-ux/skills/design-tokens/SKILL.md` and
`plugins/ui-ux/skills/shadcn-theming/SKILL.md`.

## 1. Source checklist — where to look

Cover all three lanes. One lane alone is copying, not research.

### Lane A — Live products in the same category
The real interfaces the target's users compare it against. Pick 2–4.

- SaaS / dashboards: Linear, Stripe, Vercel, Height, Retool, Ramp.
- Marketing / landing: the target's direct competitors' sites.
- Category leaders whose conventions users already expect.

For each, walk beyond the hero: sign-up, empty state, a populated table or list, a
settings page, a loading and an error state. Craft shows in the boring screens.

### Lane B — Pattern galleries
For breadth on a single pattern, not whole-page inspiration.

- Mobbin (real app flows, mobile + web), Godly, Land-book, SaaS Landing Page.
- Refactoring UI (composition/spacing reasoning), Page Flows, UI Sources, Nicelydone.
- Component-level: shadcn/ui, ReUI, Aceternity, Origin UI galleries for the actual
  target stack.

Search by pattern ("pricing table", "onboarding", "empty state", "command palette")
and collect 3–5 treatments so you extract a convention rather than one opinion.

### Lane C — The target's own brand assets
The brand has already decided things; honour them before inventing.

- Existing marketing site and product screenshots.
- Logo, brand guide, colour/type specimens, social/app-store assets.
- Any existing design tokens, Figma library, or component kit.

If a brand palette or typeface already exists, the theme brief ECHOES it rather than
proposing a fresh one — say so explicitly in the brief.

## 2. Extraction worksheet

For every source, record BOTH columns. A source that only yields colour is under-mined.

### 2a. Interaction & layout PATTERNS (→ the `/ui-ux:build` task)

| Facet | Prompt | Capture |
| --- | --- | --- |
| Layout skeleton | Grid columns, max-width, hero composition, nav/sidebar shape | |
| Content density | Airy marketing vs compact data UI; whitespace rhythm | |
| Component anatomy | Card structure, table/list row, form field grouping | |
| States | Empty, loading, error, hover/focus, selected | |
| Disclosure | Tabs, accordions, drawers, modals, progressive reveal | |
| Motion | What animates; entrance vs micro-interaction; energy (calm→lively) | |
| Responsive | How the layout reflows at phone / tablet / full | |

### 2b. Token DIRECTION (→ the `/ui-ux:theme` string)

Record as adjectives and references — NOT hex or px. Values are generated downstream.

| Facet | Prompt | Capture (adjectives/refs) |
| --- | --- | --- |
| Colour | Brand hue family, warmth, light/dark priority, surface chroma | |
| Type | Serif/sans/mono mix, display-vs-body contrast, weight range | |
| Spacing | Airy vs compact, base rhythm | |
| Radius | Sharp / slightly-rounded / pill | |
| Elevation | Flat / bordered / shadowed depth | |
| Motion feel | Snappy / smooth / dramatic — the token direction, not the choreography | |

## 3. Synthesise

- Cluster findings: where sources agree, that is the convention; where they diverge,
  that is a decision to make (and a candidate to `/design-preview:preview`).
- Separate the two payloads: colour/type/spacing/radius/motion-feel adjectives go to the
  theme brief; layout/component/state/motion patterns go to the build task.
- Keep them describing ONE product — reconcile any contradiction before writing.
- Note every direction that is still genuinely open; those are preview forks, not brief
  lines.

## 4. Hand off

- Fill `brief-templates.md` — the theme brief and the build task.
- Preview only undecided forks via `/design-preview:preview`.
- Let `/ui-ux:theme` generate the palette and `/ui-ux:build` apply `design-tokens`;
  this method never emits token values itself.
