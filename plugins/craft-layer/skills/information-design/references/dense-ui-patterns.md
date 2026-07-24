# Dense-UI patterns — tables, dashboards, stat tiles

Layout and density recipes for CRM/SaaS/admin surfaces. Numbers are starting
points on a real design-token scale (see `plugins/ui-ux/skills/design-tokens`),
not fixed pixels. Chart form and color are **not** here — those follow the
`dataviz` skill. This file owns layout, spacing, grouping, and states.

## Density modes

Offer a density the surface can switch, not one baked-in row height:

| Mode | Row height | Font | Use for |
| --- | --- | --- | --- |
| Comfortable | 48–56px | body (14–16px) | onboarding, low-volume, touch |
| Cozy (default) | 40–44px | 14px | most CRM/admin lists |
| Compact | 32–36px | 13px | power users, >50 rows on screen |

Keep the vertical rhythm on the scale: cell padding steps (`8 / 12 / 16`), not
`13px`. A compact table still uses scale steps — it drops to a smaller step, it
does not invent a value.

## Tables

The default surface for CRM/SaaS records. Reach for a table when rows are
comparable and the user scans, filters, and acts on many at once.

**Column discipline**

- Order columns by scan priority left→right: identity first (name/id), then the
  1–2 status/amount columns that drive decisions, then metadata, then row
  actions pinned right.
- Right-align numbers and currency; align decimal points so magnitudes compare
  by eye. Left-align text. Never center body cells.
- Use tabular/monospaced figures for any column the eye sums down (`font-variant-
  numeric: tabular-nums`).
- Cap column count on screen at ~7±2 meaningful columns; push the rest behind a
  row-expand or a detail drawer, not horizontal scroll as the primary read.

**Rows and grouping**

- Prefer a hairline row divider or a subtle zebra — not both. Zebra earns its
  keep only past ~15 rows; below that it is noise.
- Group with a sticky section header (e.g. by owner, stage, date bucket) before
  reaching for nested/tree rows. Two grouping levels is the practical ceiling.
- Sticky header row and sticky identity (first) column once the table scrolls.
- Show density in whitespace, not lines: rely on alignment and padding rhythm so
  most borders can disappear. Every added rule line is ink competing with data.

**Row actions**

- Primary action inline (a link on the identity cell); secondary actions in a
  right-pinned kebab/overflow that appears on row hover/focus.
- Bulk actions live in a toolbar that replaces the header when rows are selected;
  show the selected count and a clear-selection affordance.

**Table states — build all four**

- Loading: skeleton rows matched to real column widths, not a centered spinner.
- Empty: one line of what belongs here + the primary create action.
- Error: inline, retryable, scoped to the table region — never a full-page throw.
- Filtered-empty: distinguish "no data yet" from "no matches" and offer
  clear-filters.

## Dashboards

A dashboard answers a few questions at a glance, then lets the user drill in.
It is a hierarchy of tiles, not a wall of charts.

**Layout grid**

- Lay tiles on a 12-column responsive grid; align tile edges to the column grid
  so the page reads as rows, not a ransom note.
- Reading order = importance order: the answer the user opens this page for sits
  top-left (first F-pattern fixation). KPIs across the top, supporting detail
  below, raw tables last.
- Group related tiles into labeled regions ("Pipeline", "Activity") with a
  section header; whitespace between regions, tighter spacing within.
- Give tiles a consistent gutter (one scale step, e.g. `16` or `24`) and a shared
  corner radius/elevation so they read as one system.

**Tile budget**

- Aim for 4–8 tiles above the fold. Past ~10 the page becomes a search task and
  every tile loses weight. Split into tabs or separate dashboards instead.
- One question per tile. A tile that needs a paragraph to explain is two tiles or
  a detail view.

**Cross-tile consistency**

- Same metric, same format and color everywhere on the page (see `dataviz` for
  the color rules). "Revenue" is one number, formatted one way, in every tile.
- Shared time range and filters apply to the whole board from one control; do not
  let each tile carry its own silent range.

## Stat tiles (KPI cards)

A stat tile is the right home for a single number or a tight 2–3 KPI cluster —
the cases where a chart is decoration.

**Anatomy, top to bottom**

- Label (secondary weight) → the value (largest text on the tile, the primary
  signal) → one line of context: delta vs prior period, target, or a sparkline.
- Encode direction, not just sign: an up/down glyph **and** color, and state
  whether up is good (churn up is bad). Never rely on red/green alone (a11y).
- One sparkline is fine as trend context; if the trend is the point, promote it
  to a real line chart per `dataviz`.

**Grouping**

- Line KPI tiles up in a single row with equal widths so values compare by
  position. Keep number formatting identical across the row.
- 2–3 tiles read as a cluster; 6+ equal tiles read as undifferentiated — rank
  them or move the long tail into a table.

## Quick reference: chart vs table vs stat-tile

| Signal count / intent | Reach for |
| --- | --- |
| 1 number, or 2–3 KPIs | Stat tile(s) |
| Many comparable records to scan/sort/act on | Table |
| A trend, comparison, or part-of-whole to read as a shape | Chart (form/color per `dataviz`) |
| Precise values that must be read exactly | Table (or a value-labeled chart) |

When a chart wins, its type, encoding, and color are the `dataviz` skill's call —
this file stops at "a chart belongs here, size it into the tile grid above".
