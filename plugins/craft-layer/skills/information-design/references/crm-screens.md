# CRM screens — the grammar of a record-centric product

This file covers screen anatomy. The invariants live in `dense-ui-patterns.md` and are cited
here, not restated:
- column scan order;
- numeric alignment and tabular figures;
- one tab stop per grid;
- the four table states;
- URL-held filter state;
- saved views vs transient filters;
- peek vs page vs modal;
- inline-edit commit and revert.

The floors that keep the app from shipping grey are in `app-craft-floors.md`. Stage colour is a
category role, not a status role (`ui-ux:theming-system`).

**Standing.** Each rule carries a tag:
- `recorded`: reached through `information-design`'s pointer. Nothing reads it back.
- `agent-graded`: the rule cites a WCAG 2.2 success criterion, which `/ui-ux:audit` judges.

The "without it" failures are an inference from reviewing shipped products, not a
measurement.

## Typed cell kinds

Every column declares a type, and the type decides how the cell renders. The header shows a
decorative type icon (`aria-hidden`) beside a text label.

| Kind | Renders as | The usual mistake |
| --- | --- | --- |
| entity | mark + name; the name is the row's link | a bare string with no link |
| person | round avatar + name; the avatar has `alt=""` because the name sits beside it | a broken image; the name repeated in `alt` |
| domain, email, phone | a quiet chip, or a `mailto:` / `tel:` link | plain text the user must copy |
| stage | a tinted pill in the category role | the status role, so "Won" reads as "success" |
| score | a segmented meter + the number | a meter alone |
| boolean | glyph + word ("✓ Yes") | a bare glyph or a coloured dot |
| amount | right-aligned, tabular, currency code muted | centred, or the code at full weight |
| date | relative ("3 d ago"), with the absolute date in `<time datetime>` and on hover or focus | relative only, or a hover-only tooltip |
| tags | the first two, then a "+N" button that reveals the rest | an ellipsis that hides them |
| relation | linked record chips, with a count past two | an unlinked list of names |

Two more controls:
- **Selection column.** A leading checkbox column. The header checkbox has an indeterminate
  state and says whether it selects the page or every match.
- **Add column.** The last header is a real button named "Add column".

`agent-graded` for names, roles and colour (SC 1.1.1, 1.4.1, 1.4.13, 4.1.2); the anatomy is
`recorded`.

## View switcher with a count

- **Page header:** the object icon and title, then the current view name with its count ("All
  companies · 1,284").
- **Controls:** a menu of saved views, then Filter · Sort · Display as text buttons, then one
  primary action ("New company").
- **The count follows the filter.** It updates when the filter changes, and it is part of the
  switcher's accessible name.
- *Without it:* a view menu with no count, or a count left stale after filtering.

`recorded`

## Board

- **Column header:** stage, record count, and the column's sum of the primary amount
  ("Proposal · 7 · $184,500"). The sum uses tabular figures and the same currency format as the
  table.
  - *Without it:* count-only headers, which hide the pipeline's value. `recorded`
- **Card:**
  - the record title, the amount and the owner avatar;
  - the next-step date, with overdue shown as a word and a glyph;
  - at most one row of tags;
  - no description paragraph.

  `agent-graded` (SC 1.4.1)
- **Keyboard move.**
  - Space picks a card up, arrows move it within and across columns, Space drops it, and
    Escape cancels.
  - Each step announces the item, the column and the position: "Halden Freight renewal moved to
    Proposal, 2 of 7".
  - dnd-kit's default announcements interpolate the raw `id` ("Picked up draggable item 42").
    Pass label-based announcements (`product-packages.md`, Drag & drop row).
  - Focus stays on the moved card after the drop.

  `agent-graded` (SC 2.1.1, 4.1.3)
- **A non-drag route.** Every card has a "Move to stage" menu (SC 2.5.7). `agent-graded`
- **The move is an optimistic write.** It rolls back on rejection (`app-craft-floors.md` §1).
  The card makes a shared-layout move (§4) that becomes instant under reduced motion.
  `recorded`

## Record page

- **Header:** the mark and name, then three to six key fields editable in place (owner, stage,
  amount, close date), then ONE primary action. Commit and revert work as
  `dense-ui-patterns.md` sets them.
- **Tabs:** Activity, Email, Notes, Tasks, Files. The tabs sit in the page, under the header,
  not in the shell.
- **Activity timeline:**
  - an `<ol>`, newest first, grouped by day under sticky day headers;
  - each entry: type icon, actor, verb, object, and a relative time in `<time datetime>`;
  - a type filter, and a composer at the top for a note or a logged call;
  - *without it:* a flat pile of cards with timestamps no machine can read.
- **Attribute rail**, on the right:
  - every field, grouped (About, Deal, System) and editable in place;
  - empty fields show "Add" rather than disappearing;
  - related records (people, open deals) as compact linked lists with counts;
  - at narrow widths the rail moves below the header, never into a hidden drawer.

`recorded`

## Three-pane inbox with a context panel

- **Layout:** views, then the thread list, then the thread, then a context panel. The panel
  holds the CRM record: stage, owner, open tasks, contacts and recent activity.
- **Landmarks:** each pane is a labelled region.
- **The thread list:**
  - is one tab stop, with arrow keys or j/k;
  - keeps focus in the list during triage (Enter moves into the thread; arrows never throw
    focus there);
  - shows unread as weight plus a marker, not tint alone.
- **The context panel** is collapsible, and its open state persists.
- **Single-key shortcuts** (j, k, e) fire only while the list has focus, or they can be turned
  off or remapped (SC 2.1.4). *Without it:* shortcuts fire while the user types a reply.

`agent-graded` (SC 1.3.1, 1.4.1, 2.1.4); layout `recorded`

## Day-column planner

- **Layout:** days are columns (a time axis, or a task list per day), with a backlog or calendar
  rail beside them.
- **Moving tasks:** tasks move between days with the board's keyboard sequence and its
  non-drag menu.
- **Keyboard:** the grid is one tab stop.
- **Today:** labelled in words, not only with a tint.
- **Time grids:** zones, DST, overlap and resize follow `scheduling-surfaces.md`.

`agent-graded` (SC 2.5.7, 1.4.1); layout `recorded`
