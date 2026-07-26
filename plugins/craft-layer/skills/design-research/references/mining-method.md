# Mining method — source checklist + extraction worksheet

The full procedure the SKILL summarises. Work top to bottom: gather sources, extract
both patterns and token direction from each, then fill the templates in
`brief-templates.md`. This file re-teaches nothing about token scales or palette
generation — those live in `plugins/ui-ux/skills/design-tokens/SKILL.md` and
`plugins/ui-ux/skills/shadcn-theming/SKILL.md`.

## 1. Source checklist — where to look

Cover all three lanes. One lane alone is copying, not research.

### Lane A — Live products in the same category
A source CLASS, never a list: the 2–4 interfaces THIS audience already compares the
target against. The brief names them; this file does not.

- The products this audience opens in the next tab for the same job.
- The direct competitors the brief names, plus the category leader whose conventions
  these users already arrive expecting.
- If the brief names none, ask before mining. An unfilled source class is a gap in the
  brief — not a licence to reach for whatever ships loudest this quarter.

The test is mechanical: **if this file would need editing when a new product launches,
it has become a catalog.** A named roster ages into a house look and feeds an averager;
a source class re-derives itself per target, per audience, per year.

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

Three columns, and the third does the work. Column two records what the source DOES;
column three names the PRINCIPLE underneath it and how THIS brief re-expresses that
principle in its own terms.

**A row whose third column merely restates the second is a copy, not a finding** —
re-derive it or strike the row. "Sidebar nav, 240px" → "sidebar nav" has extracted
nothing; "persistent orientation while the workspace changes underneath → our brief
carries orientation in a fixed spine, not a sidebar" is a finding.

| Facet + prompt | What the source does | Principle → this brief's re-expression |
| --- | --- | --- |
| Layout skeleton — grid columns, max-width, hero composition, nav/sidebar shape | | |
| Content density — airy marketing vs compact data UI; whitespace rhythm | | |
| Component anatomy — card structure, table/list row, form field grouping | | |
| States — empty, loading, error, hover/focus, selected | | |
| Disclosure — tabs, accordions, drawers, modals, progressive reveal | | |
| Motion — what animates; entrance vs micro-interaction; energy (calm→lively) | | |
| Responsive — how the layout reflows at phone / tablet / full | | |

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

- Cluster findings, then read the clusters the right way round. **Where sources AGREE
  is where the category is most predictable — convergence is a flag to diverge from,
  not a convention to adopt.** Adopt an agreed pattern only where it is load-bearing
  for comprehension or accessibility, and say in the brief why it earns the exception.
  Where they diverge, that is a genuine decision to make (and a candidate to
  `/design-preview:preview`).
- Separate the two payloads: colour/type/spacing/radius/motion-feel adjectives go to the
  theme brief; layout/component/state/motion patterns go to the build task.
- Keep them describing ONE product — reconcile any contradiction before writing.
- Note every direction that is still genuinely open; those are preview forks, not brief
  lines.
- **Anti-pattern — reproducing any single source's composition.** If the briefed layout
  could be captioned "it is that one product, with our colours", the mining produced a
  clone. One source may supply a principle; none may supply the arrangement. Every
  composition line must trace to a principle held across sources or to the brief's own
  constraint — never to one source's page.

## 4. Hand off

- Fill `brief-templates.md` — the theme brief and the build task.
- Preview only undecided forks via `/design-preview:preview`.
- Let `/ui-ux:theme` generate the palette and `/ui-ux:build` apply `design-tokens`;
  this method never emits token values itself.
