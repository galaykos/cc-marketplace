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

#### Lane C is the ENFORCED lane — every brief-named source owes a ROW

Nothing above is new, and that is the point. This lane already sends the run at the
target's own marketing site, and `design-research` runs at step 1 at EVERY ambition tier
with no gate on it, so "read the URL the brief handed you" has been the rule the whole
time. It was ignored anyway: a run met a `403` on the client's own published page, wrote it
down as a finding, carried on without the copy, and filled the offer spine with the
product's API facts instead. A rule stated a fourth time would have changed nothing. What
changes it is a row.

**Every URL, repo path and attached file the brief NAMES gets a row in
`craft/content-source.md`'s Sources table**
(`craft-layer/skills/creative-direction/references/content-source.md`), carrying the origin,
the date, and the `Method` that retrieved it — `fetch`, `browser (escalated ← <status>)`,
`file`, `pasted`, or `fetch-failed` with its reason. That is the reference board's `Method`
vocabulary, deliberately: one question, one column, no parallel machinery. A retrieval that
returns 403, 5xx or an empty document ESCALATES before it is called unavailable — the ladder
is `craft-layer/skills/ultra-craft/references/research-mandate.md` § "When a fetch fails",
which binds at every tier and is not restated here.

A brief-named source with NO row is a finding at audit, and it bites at every tier: the
content-source artifact is written on a `one-shot` or `restrained` run exactly as on a
boosted one, and the audit rebuilds the expected list from the contract's `Raw brief:`,
which is stored verbatim. A brief-named URL is a SUPPLIED INPUT, not research — mining depth
is what ambition and the boost buy, and neither of them is what decides whether the run read
what it was handed. On a BOOSTED run the same source additionally appears on
`craft/reference-board.md` as a brand-assets-lane row and counts toward the six-source
floor; the board is a boosted-run artifact, so it is never what carries this elsewhere.

Recording an obstacle is not clearing it. The row is what makes the difference between the
two visible to something other than a person reading the page at the end.

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
  `/design-lab:preview`).
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
- Preview only undecided forks via `/design-lab:preview`.
- Let `/ui-ux:theme` generate the palette and `/ui-ux:build` apply `design-tokens`;
  this method never emits token values itself.
