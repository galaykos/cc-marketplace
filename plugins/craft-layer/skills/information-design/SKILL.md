---
name: information-design
description: Use when designing or reviewing data-dense CRM, SaaS, or admin surfaces — dashboards, tables, list views, stat/KPI tiles — to set information hierarchy (primary/secondary/tertiary signal), tune data density and grouping, and decide chart vs table vs stat-tile. Chart form and color defer to the dataviz skill.
---

# Information design for dense surfaces

The raw ask was "eye-catching, eye candy, **informative**". This skill owns the
informative half for CRM/SaaS/admin screens — the ones that carry a lot of data
and still have to be read in one glance. Craft without information design is
decoration; a dashboard where everything shouts says nothing.

Scope: hierarchy, density, and the chart/table/stat-tile decision. Out of scope:
chart form and color (the `dataviz` skill owns those — cite it, never restate
it), design tokens (`plugins/ui-ux/skills/design-tokens`), and motion detail
(`../motion-tiers/SKILL.md`). Full layout recipes live in
`references/dense-ui-patterns.md`.

## Establish a signal hierarchy first

Every screen has exactly one job. Before styling, rank what is on it into three
tiers, and make the visual weight match the rank — not the other way round.

- **Primary signal** — the one number or record the user opened this screen to
  read. There is *one* per surface (per region on a dashboard). It gets the most
  weight: largest size, highest contrast, top-left / first fixation. If two
  things are primary, you have two screens or two regions.
- **Secondary signal** — what qualifies the primary: the delta, the status, the
  owner, the due date. Present and scannable, deliberately quieter — smaller,
  lower contrast, or set beside the primary as support.
- **Tertiary signal** — metadata, IDs, timestamps, row actions. Available on
  demand (hover, a detail drawer, an expand) but never competing for the first
  read. Tertiary content at primary weight is the most common density failure.

Rank with weight, not just size: contrast, position, whitespace, and color all
encode importance. Spend your strongest encoding (size + contrast + position)
once, on the primary. Demote everything else. A screen where five elements share
the top weight has no hierarchy — the eye finds no entry point and bounces.

Let research drive the ranking. `../design-research/SKILL.md` produces the brief
that says what this surface is *for* and who reads it; that intent decides which
signal is primary. Do not rank by what is easy to query — rank by the decision
the user came to make.

## Tune data density deliberately

Dense is a feature for CRM/SaaS power users, not an accident. The goal is high
information-per-pixel that stays legible — reached through alignment and rhythm,
not by cramming or by drawing a line around everything.

- **Group before you separate.** Proximity and shared alignment group related
  fields with no borders at all. Reach for whitespace first, a hairline divider
  second, a boxed card only when a region truly stands apart. Every rule line is
  ink that competes with data.
- **Rhythm on a scale.** All spacing comes from the token scale (`8 / 12 / 16 /
  24 …`). Tight *within* a group, looser *between* groups — that contrast is what
  makes a dense screen scannable instead of a grey slab. `padding: 13px` is a bug.
- **Align relentlessly.** Left-align text, right-align and decimal-align numbers,
  use tabular figures for any column the eye sums. Alignment does the work most
  borders are added to fake.
- **Offer density, do not hard-code it.** Comfortable / cozy / compact row
  heights let the user choose their information-per-pixel. See the density-mode
  table in `references/dense-ui-patterns.md`.

### Tables

The default CRM/SaaS surface: many comparable records the user scans, sorts,
filters, and acts on. Order columns by scan priority (identity → decision-driving
status/amount → metadata → right-pinned actions), cap visible columns near 7±2,
keep the header and identity column sticky, and build all four states — loading
(skeleton), empty, error, filtered-empty. Recipes: `references/dense-ui-patterns.md`.

### Dashboards

A dashboard answers a few questions at a glance, then lets the user drill in — a
hierarchy of tiles on a 12-column grid, not a wall of charts. Reading order is
importance order: the primary signal top-left, KPIs across the top, supporting
detail below, raw tables last. Aim for 4–8 tiles above the fold; past ~10 the
page becomes a search task. Layout and cross-tile consistency rules:
`references/dense-ui-patterns.md`.

## Decide: chart vs table vs stat-tile

Pick the container from the *count and intent* of the signal, before picking any
chart type. Most CRM/SaaS "chart" requests are really a stat tile or a table.

- **One number, or 2–3 KPIs → stat tile.** A single value or a tight KPI cluster.
  A chart for three numbers is decoration; a big value with a delta reads faster.
- **Many comparable records, exact values, scan/sort/act → table.** When the user
  needs to read precise values, compare rows, or take row actions, a table beats
  a chart every time. Do not chart what people need to read exactly.
- **A trend, a comparison, or a part-of-whole read as a *shape* → chart.** Reach
  for a chart only when the *pattern* is the message and no single number or row
  carries it: a trend over time, a distribution, a ranked comparison.

When a chart wins, stop here: its **form and color are the `dataviz` skill's
call** — mark selection, encoding accuracy, axis and legend discipline, and
palette all live there. This skill only decides *that* a chart belongs and sizes
it into the tile grid. Do not duplicate `dataviz` guidance in craft-layer files,
and never write the skill in slash form in committed text — cite it by name.

## Motion serves the reading, never the data

Motion supports information; it must not bury it. Transitions clarify *where a
number went* (a row entering, a filter narrowing, a value counting up) — they are
wayfinding, not spectacle. A KPI that animates every poll is noise; animate on
change, respect `prefers-reduced-motion`, and never delay the first read behind
an entrance. Tier and budget decisions live in `../motion-tiers/SKILL.md`.

## Anti-patterns

- **Flat weight / no entry point.** Five elements at the same size and contrast;
  the eye finds nowhere to land. Rank into primary/secondary/tertiary and demote.
- **Chart-as-decoration.** A gauge or donut standing in for two numbers. If ≤3
  values answer the question, use a stat tile.
- **Box-everything density.** A border around every field to force grouping.
  Group with proximity and alignment; delete the boxes.
- **Off-scale spacing.** `margin: 13px`, mixed gutters. Every gap is a scale step.
- **Right-shouting metadata.** Timestamps and IDs at primary weight, drowning the
  value that matters. Push tertiary content to hover or a drawer.
- **Duplicating dataviz.** Restating chart-type or color rules here. Cite the
  `dataviz` skill and link out; craft-layer references, it does not re-teach.
