---
name: css-grid-best-practices
description: Use when building 2-D CSS Grid layouts — template areas, auto-fit/fill, minmax, subgrid, Grid vs Flexbox.
---

## Reach for Grid when the layout is genuinely two-dimensional

Grid controls rows and columns together; Flexbox only really controls one axis at a time. If a
layout needs items to align both horizontally and vertically against a shared structure (page
shells, dashboards, card grids), use Grid. Forcing Flexbox to fake a grid with `flex-wrap` and
fixed-width children breaks down as soon as content lengths vary.

```css
/* Good: real two-dimensional layout */
.page { display: grid; grid-template-columns: 240px 1fr; grid-template-rows: auto 1fr auto; }

/* Bad: flexbox approximation of a grid, alignment drifts with content */
.page { display: flex; flex-wrap: wrap; }
.page > * { flex: 0 0 240px; }
```

## Use named template areas for readable page-level layout

`grid-template-areas` makes the layout's shape visible directly in the CSS, instead of forcing
readers to mentally map numbered `grid-column`/`grid-row` lines to visual regions.

```css
/* Good */
.layout {
  display: grid;
  grid-template-areas:
    "header header"
    "nav    main"
    "footer footer";
  grid-template-columns: 200px 1fr;
}
.header { grid-area: header; }

/* Bad: numeric line placement for a static page shell, harder to scan */
.header { grid-column: 1 / 3; grid-row: 1; }
.nav { grid-column: 1; grid-row: 2; }
```

## Use `auto-fit`/`auto-fill` with `minmax()` for responsive grids without media queries

A repeating grid of cards can reflow its column count automatically based on available space,
with no breakpoints to maintain.

```css
/* Good: card count adapts to container width automatically */
.cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 1rem;
}
```

`auto-fill` keeps empty tracks (useful when you want consistent track sizing even with few
items); `auto-fit` collapses empty tracks so existing items stretch to fill the row. Pick based
on whether you want gaps to remain or be absorbed.

## Reach for subgrid when nested content must align to the parent's tracks

Without `subgrid`, a nested grid defines its own independent tracks, so child grids in different
parent cells (e.g., cards with headers of varying height) won't line up. `grid-template-columns:
subgrid` (or rows) lets a nested grid inherit the parent's track sizing so content aligns across
siblings.

```css
/* Good: card internals align across a row of cards */
.card-grid { display: grid; grid-template-columns: repeat(3, 1fr); }
.card { display: grid; grid-row: span 3; grid-template-rows: subgrid; }
```

## Know your explicit vs. implicit tracks

Tracks defined in `grid-template-columns`/`rows` are explicit; anything Grid creates on the fly
to fit overflow content (because you didn't define enough rows/columns) is implicit, sized by
`grid-auto-rows`/`grid-auto-columns` (default `auto`). Unexpected implicit tracks are usually a
sign the explicit template didn't account for real content volume — set `grid-auto-rows` on
purpose rather than being surprised by default sizing.

```css
.gallery {
  grid-template-columns: repeat(3, 1fr);
  grid-auto-rows: minmax(150px, auto); /* explicit sizing for overflow rows */
}
```

## Use `gap` for spacing between tracks, not margins on items

`gap` (formerly `grid-gap`) applies spacing only between tracks, so edge items don't get
uneven outer spacing the way margin-based spacing does, and it doesn't require negative-margin
compensation on the container.

- Good: `.grid { display: grid; gap: 1rem; }`
- Bad: `margin: 0.5rem` on every grid item, doubling gaps between items and requiring a
  container `margin: -0.5rem` hack to fix edges.

## Hand a section to Flexbox when it's really one-dimensional content flow

Toolbars, nav bars, button groups, and anything that just needs to distribute or align items
along a single line are Flexbox's job — `justify-content`, `align-items`, and `gap` solve them
with less setup than a grid template. Don't set up a full grid template for a single row of
buttons.

## Common mistakes

- Building a card/page layout with Flexbox + `flex-wrap` when it's genuinely a Grid problem.
- Placing items with numeric line numbers in a static layout that would read better as named areas.
- Using a media query to change column count when `auto-fit`/`minmax()` would do it without breakpoints.
- Nesting independent grids and expecting child content to align across siblings without `subgrid`.
- Not setting `grid-auto-rows`/`columns`, then being surprised by inconsistent implicit track sizing.
- Adding margins to grid items for spacing instead of `gap` on the container.

## Verify Against Current Docs

Subgrid and `auto-fit`/`auto-fill` browser support has changed over time, and Grid's spec has
gained features (masonry-like layouts, additional alignment keywords). Before relying on memory
for support or exact syntax, check the current docs:
https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_grid_layout
