# Dense-UI patterns — tables, dashboards, stat tiles

Layout and density recipes for CRM/SaaS/admin surfaces. Numbers are starting
points on a real design-token scale (see `plugins/ui-ux/skills/design-tokens`),
not fixed pixels. Chart form and color are **not** here — those follow the
`dataviz` skill. This file owns layout, spacing, grouping, and states.

## App shell

The frame around every screen, and the most visible "not a real product" tell
when it is improvised per run: the data can be right and the build still reads
as a demo because the chrome keeps reinventing itself. The grammar is settled —
spend the invention on the data, not the shell.

- **Sidebar**: grouped nav with labeled sections and exactly ONE active state —
  the current page, nowhere else. It collapses to an icon rail, not to nothing,
  so the map survives when the user reclaims the width.
- **Org/workspace switcher pinned top, user menu pinned bottom.** Both are
  identity; identity anchors the shell's two ends.
- **Page-level sub-nav lives in the page, not the shell.** Tabs for a record's
  sections sit under the page header; putting them in the sidebar makes the
  shell mutate per route, and a map that mutates stops being a map.
- **Breadcrumbs only past two levels of hierarchy** — at two levels they
  restate the sidebar's active state in smaller type.
- **Page header**: title left, primary action right, metadata (owner, status,
  last updated) under the title. One primary action; the rest overflow.

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

**Density has an accessibility floor.** WCAG 2.2 SC 2.5.8 (Target Size (Minimum), AA)
requires pointer targets of at least 24×24 CSS pixels. Compact rows are exactly where
this breaks: a row-action kebab, an inline checkbox, or a sort affordance sized to a
32px row can fall under the floor even though the row itself does not. Size the
TARGET, not the row — a 24px hit area inside a shorter row, via padding rather than
icon size — or keep the affordance out of compact mode. The criterion's spacing
exception can carry a smaller icon only when the surrounding untargeted space
genuinely makes up the 24px, which a dense grid rarely provides. Verification belongs
to `/a11y:audit`; the decision belongs here, because density is decided here.

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
- Cap visible columns by the READ, not by a number: you have too many the moment
  horizontal scrolling becomes the primary way people read the table. Push the rest
  behind a row-expand, a detail drawer, or a column picker. (`~7±2` is a workable
  starting guess, not a standard — no major design system publishes a column ceiling,
  so treat any specific number as a heuristic to test against the real data.)

**Rows and grouping**

- Prefer a hairline row divider or a subtle zebra — not both. Zebra earns its
  keep only past ~15 rows; below that it is noise.
- Group with a sticky section header (e.g. by owner, stage, date bucket) before
  reaching for nested/tree rows. Two grouping levels is the practical ceiling.
- Sticky header row and sticky identity (first) column once the table scrolls.
- Show density in whitespace, not lines: rely on alignment and padding rhythm so
  most borders can disappear. Every added rule line is ink competing with data.

**Keyboard traversal — a grid is ONE tab stop, not one per cell**

A grid of interactive cells put every cell in the tab order is the most common
way a dense surface becomes hostile to the people who most need it. A modest
5×9 board is 45 tab stops standing between the keyboard user and the rest of the
page; a real CRM table is hundreds.

- Give the grid a **roving tabindex**: exactly one cell carries `tabindex="0"`,
  every other carries `tabindex="-1"`, and arrow keys move focus between them.
  Tab enters and leaves the grid; it never walks it.
- Move the roving cell on focus as well as on arrow, so pointer and keyboard
  agree about where the user is.
- `Home` / `End` to the row's ends is cheap and expected; add `PageUp`/`PageDown`
  once a grid is taller than a viewport.
- The same rule covers cell-level checkboxes, day/hour boards, calendar grids,
  and seat maps — anything where a two-dimensional structure carries controls.

This is a LAYOUT decision, not an accessibility afterthought, which is why it
lives here: the traversal model is decided when the grid is designed, and
retrofitting it means rewriting the component.

**Row actions**

- Primary action inline (a link on the identity cell); secondary actions in a
  right-pinned kebab/overflow that appears on row hover/focus.
- Bulk actions live in a toolbar that replaces the header when rows are selected;
  show the selected count and a clear-selection affordance.

**Table states — build all four**

- Loading: skeleton rows matched to real column widths, not a centered spinner.
  Match the indicator to the wait (NN/g): under ~1s show nothing — an indicator that
  flashes is worse than none; ~2–10s warrants an indicator; past ~10s it must be a
  determinate progress bar, not a spinner. Skeletons suit container-shaped loads (the
  table, a card grid); a single tile refreshing in place is a spinner's job.
- Empty: one line of what belongs here + the primary create action.
- Error: inline, retryable, scoped to the table region — never a full-page throw, and
  never dressed as an empty state. "Nothing here" and "we could not load this" are
  different messages with different recovery; collapsing them strands the user.
- Filtered-empty: distinguish "no data yet" from "no matches" and offer
  clear-filters.

Filter, sort, and page state lives in the URL, not in component state — a
reload or a shared link must reproduce the exact view, including its
filtered-empty state.

## Filters and saved views

The toolbar above the table has an anatomy: search, typed filter chips, sort,
density toggle, column picker — roughly in order of use, search first.

- **Applied filters stay visible as removable chips**, with one clear-all. The
  filtered-empty state above assumes exactly this: its clear-filters affordance
  needs a visible thing to clear, or the user is told to undo something they
  cannot see.
- **Transient filters and saved views are different objects.** A filter is what
  the user is doing now; a saved view (or segment) is a filter promoted to
  navigation — named, persistent, surfaced as tabs or a view switcher. Promote
  deliberately; do not let every ad-hoc filter demand a name.
- **Facet counts** ("Stage: Won (12)") only when they are cheap to compute — a
  count that costs a query per facet is decoration bought with latency.

## Opening a record: peek vs page vs modal

- **Side panel (peek)** for scan-and-triage from a list: the list stays in
  view, and arrow / j-k moves through records without leaving it — the pattern
  modern CRMs converged on, because triage is a sequence, not a visit.
- **Full page** for deep work, and for anything that needs a permalink.
- **Modal** only for a short blocking task (confirm, quick-create). Never stack
  containers — a modal over a peek over a list is three contexts deep, and
  focus return (see `app-craft-floors.md`) rarely survives the unwind.

Inline cell editing: click or Enter edits in place; commit on blur/Enter with
the optimistic-write pattern `app-craft-floors.md` already sets; Esc reverts.
Routing every cell edit through a dialog contradicts that floor.

## Dashboards

A dashboard answers a few questions at a glance, then lets the user drill in.
It is a hierarchy of tiles, not a wall of charts.

**Layout grid**

- Lay tiles on a 12-column responsive grid; align tile edges to the column grid
  so the page reads as rows, not a ransom note.
- Reading order = importance order: the answer the user opens this page for sits
  top-left, the first fixation in LTR. KPIs across the top, supporting detail below,
  raw tables last. (Do not justify this with the F-pattern — NN/g scopes that finding
  to unformatted prose-heavy text, which a tiled dashboard is not. The reason here is
  simply that reading order is a hierarchy you control; mirror it for RTL.)
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

## Settings

- Sectioned sub-nav (Profile, Workspace, Billing, …), not one endless form —
  settings are consulted, not read top to bottom.
- Forms are single-column at a readable max-width; a full-width settings form
  is a line length no eye can track back.
- **Declare explicit-save or auto-save per section, and say which.** Either is
  fine; mixing them silently is the failure — a user who learned "changes save
  themselves" loses the one section where they did not.
- Destructive zone last, visually set apart, and undo-governed per
  `app-craft-floors.md`'s confirm-vs-undo rule: confirmation is reserved for
  the genuinely irreversible, and it says plainly what will be destroyed.

## Quick reference: chart vs table vs stat-tile

| Signal count / intent | Reach for |
| --- | --- |
| 1 number, or 2–3 KPIs | Stat tile(s) |
| Many comparable records to scan/sort/act on | Table |
| A trend, comparison, or part-of-whole to read as a shape | Chart (form/color per `dataviz`) |
| Precise values that must be read exactly | Table (or a value-labeled chart) |

When a chart wins, its type, encoding, and color are the `dataviz` skill's call —
this file stops at "a chart belongs here, size it into the tile grid above".
