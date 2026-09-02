# Variant depth — what each variant varies, holds constant, and must render

Read once the scratch surface exists, before writing the first variant. Depth
comes from one clear lane, that lane's real states, and realistic data — never
from more variants (at most three, one axis).

## Pick the lane — one per preview

- **design** — the decision is layout, placement, density, or flow.
- **creative** — the decision is concept or content (copy, tone, framing).
- **dataviz** — the decision is a chart, dashboard, or metric surface.

A text-native choice with no surface (A vs B wording, no layout) is not a
previewed decision — it stays a plain multiple-choice question. Mixing lanes in
one preview breaks the comparison: two lanes is two previews.

## Design lane

Vary ONE structural axis — where things sit, what is emphasized, how dense the
data is. Hold content and theme constant so the eye compares structure, not
noise. Populate every variant identically. Name the axis out loud
(sidebar-vs-topbar, table-vs-cards, comfortable-vs-dense) so the pick is
attributable to it and nothing else.

## Creative lane

Hold the layout constant; each variant is a different concept/content DIRECTION
— hero copy, tone, feature framing — authored as genuinely divergent options,
not one draft reworded. Render them in the real components so the user judges a
shown concept, not a bullet list. Creative variants render `populated` only.
Divergent means different premises, not the same idea in different fonts.

## Dataviz lane

The decision is which chart, which encoding, or how a dashboard is laid out.
Render the project's REAL chart component (whatever it uses — shadcn `chart`,
MUI X Charts, Recharts, Chart.js) wired to its own chart tokens, with realistic
data. No chart library in the project → the decision is not a dataviz preview;
fall back to the shell mockup or a static SVG. For chart-form and
encoding guidance:

- Host `dataviz` skill installed → it GOVERNS; read it first.
- Absent → `dataviz-cheatsheet.md` beside this file is the floor: a
  deliberately frozen minimal set that does not track the host skill.

Never write the host skill in slash form (`/dataviz:…`) in any committed file —
the marketplace validator rejects unknown plugin commands.

## The depth matrix

Data lanes (design, dataviz) render every meaningful state, switchable from the
preview header:

- `populated` — realistic data, full interactivity (sort, filter, dialog).
- `empty` — the honest empty state, not a blank box.
- `loading` — a Skeleton in the real layout's shape.
- `error` — a clear failure with a retry affordance.

Each variant renders its OWN states. A variant that omits `loading` or `error`
falls through silently to whatever branch catches it — a bug no compiler
catches. Build every state your lane needs.

## Realistic data and the rationale

Populate with specific, real-shaped data ("Invoice #4821 — Northwind Traders —
$1,240.00 — overdue 12 days"), never lorem ipsum — placeholders that read like
production data expose layout and density problems that lorem hides. Each
variant carries a three-part rationale in its header line — **serves** (who it
is for), **trades** (what it gives up), **breaks** (when it fails). A variant
that cannot name a real trade or break is not actually different from its
rivals: cut it or sharpen it.

## Recording the pick

Make the winning variant self-explain: its lane, the one axis it won on, and
the state that decided it — a caption a reader who never saw the running
preview can still act on. Theme is a constant backdrop, never a variant axis;
colour decisions belong to `/ui-ux:theme`.

## Anti-patterns

- Mixing lanes in one preview.
- A variant that omits its lane's states — the demo quietly lies.
- More than three variants, or several axes at once.
- A chart with no decision behind it — dataviz is a lane for choosing a chart,
  not decoration.
