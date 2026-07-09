---
name: deep-staging
description: Use when authoring staged variants inside a running shadcn-studio sandbox — decides the lane (design / creative / dataviz), what each variant varies and holds constant, and which states to build, so staged options carry real substance instead of one frame with a caption. Read after the studio skill has a sandbox running; studio owns the lifecycle, this owns the substance.
---

## Where this sits

studio provisions, serves, and cleans up the sandbox; this skill decides WHAT to
author in it and HOW DEEP. Read it once studio has a stage running, before
writing any `src/variants/*.tsx`. The two never overlap: lifecycle is studio's,
substance is here.

A staged option is thin when it is one frame with a caption. Depth comes from a
clear lane, the states that lane actually has, real interactivity, and realistic
data — never from more variants (still at most three, one axis).

## Pick the lane — one per stage

Every stage is exactly ONE lane; set `lane` on the stage config. Mixing lanes in
one stage breaks the shared state toggle and the comparison.

- **design** — the decision is layout, placement, density, or flow.
- **creative** — the decision is concept or content (copy, tone, framing).
- **dataviz** — the decision is a chart, dashboard, or metric surface.

A text-native choice with no surface (A vs B wording, no layout) is not a staged
decision — it stays a plain multiple-choice question.

## Design lane

Vary ONE structural axis — where things sit, what is emphasized, how dense the
data is. Hold content and theme constant across variants so the eye compares
structure, not noise. Populate every variant identically with realistic data.
Name the axis out loud (sidebar-vs-topbar, table-vs-cards, comfortable-vs-dense)
so the pick is attributable to it and nothing else — two axes at once is two
stages, not one.

## Creative lane

Hold the layout constant; each variant is a different concept/content DIRECTION
— hero copy, tone, feature framing — authored as N genuinely divergent options
(not one draft reworded). Render them in real components so the user judges a
shown concept, not a bullet list. Creative variants have the `populated` state
only; the harness suppresses the toggle. Three to four directions is the useful
range — enough to show the space, few enough to decide; divergent means different
premises, not the same idea in different fonts.

## Dataviz lane

The decision is which chart, which encoding, or how a dashboard is laid out.
Render the REAL shadcn `chart` (Recharts) wired to the `--chart-1..5` tokens,
with realistic data. For chart-form and encoding guidance:

- Host `dataviz` skill installed → it GOVERNS; read it first.
- Absent → use `references/dataviz-cheatsheet.md` in this skill as the floor: a
  deliberately frozen minimal set (form heuristic, encoding discipline, when NOT
  to chart) that does not track the host skill — that staleness is by design.

Never write the host skill in slash form (`/dataviz:…`) in any committed file —
the marketplace validator rejects unknown plugin commands and fails the build.

## The depth matrix

Data lanes (design, dataviz) exercise every meaningful state; the toggle exposes
all four:

- `populated` — realistic data, full interactivity (sort, filter, dialog).
- `empty` — the honest empty state, not a blank box.
- `loading` — a Skeleton in the real layout's shape.
- `error` — a clear failure with a retry affordance.

Creative lane renders `populated` only. Each variant Component renders its OWN
states — the harness only routes `state` and gates the toggle by lane. Widening
the state union does NOT force a variant to handle a new state (it falls through
silently to whatever branch catches it), so a variant that omits `loading` or
`error` is a bug the compiler will not catch. Build every state your lane needs.

## Realistic data and the tradeoff line

Populate with specific, real-shaped data ("Invoice #4821 — Northwind Traders —
$1,240.00 — overdue 12 days"), never lorem ipsum — placeholders that read like
production data expose layout and density problems that lorem hides. Each variant
carries a one-line `tradeoff`; richer per-option rationale is a later concern,
not this skill's.

## shadcn wiring

Compose from the vendored primitives per `ui-ux:shadcn-best-practices`
(composition over props, Radix behavior preserved). Theme is a constant backdrop,
never a variant axis: the sandbox ships neutral tokens and color is never the
thing being decided — that is a separate theming concern entirely.

## Recording the pick

studio records THAT a pick happened and copies the chosen JSX out before it
cleans up the sandbox. Your job here is to make the winning variant self-explain:
its lane, the one axis it won on, and the state that decided it — a caption a
reader who never saw the running sandbox can still act on.

## Anti-patterns

- Mixing lanes in one stage — the shared toggle and the comparison both break.
- A variant that omits its lane's states — `loading`/`error` silently render as
  the populated (or empty) branch, and the four-state demo quietly lies.
- More than three variants, or several axes at once — the pick stops being
  attributable to any one difference.
- A chart with no decision behind it — dataviz is a lane for choosing a chart,
  not decoration to prove the sandbox can draw one.
- Reaching into studio's lifecycle — servers, ports, cleanup — from here. Wrong
  skill: this one only decides what to author.
