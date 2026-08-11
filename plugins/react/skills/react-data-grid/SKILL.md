---
name: react-data-grid
description: Use when building or reviewing React data tables or grids — TanStack Table column defs, sorting/filtering/pagination/row-selection state, server-side data with manual modes and TanStack Query, TanStack Virtual for tall tables, shadcn DataTable composition. Match the installed @tanstack/react-table major first — v9 (useTable + tableFeatures) and v8 (useReactTable + getCoreRowModel) do not mix.
---

# React data grids

A data grid concentrates every React state discipline into one component: server
data, controlled UI state, list identity, and a headless library with two live
majors whose APIs do not mix. Most broken tables fail on one of those seams, not
in the cells.

## Match the installed major first

Read the `@tanstack/react-table` major from the lockfile BEFORE writing any
table code. This is the one library where generating from memory reliably
produces the wrong API: the model's memory defaults to v8 idioms, while shadcn's
current DataTable guide targets v9 — unchecked generation mismatches the docs
the user reads next, and the two halves contradict each other in review.

- **v9** (GA 2026-08; 9.1.2 at the stamp below) — `useTable`, with features
  registered through `tableFeatures()` from tree-shaken imports
  (`rowSortingFeature`, `createSortedRowModel()`, …). Sorting, filtering,
  pagination, and selection are opt-in; state slices exist only for registered
  features.
- **v8** — `useReactTable`, with row models passed directly:
  `getCoreRowModel()`, `getSortedRowModel()`, `getFilteredRowModel()`.

Never mix the two in one file. `getCoreRowModel()` next to `tableFeatures()`
runs nowhere and reviews as noise.

## Column defs are defined once

- Define the `columns` array at module level, or memoize it when it closes over
  props. An inline array is a new reference every render — the table
  re-initializes and controlled state (sorting, selection) resets or churns.
- Two kinds: **accessor columns** (`accessorKey` / `accessorFn`) carry data and
  can sort and filter; **display columns** (selection checkbox, actions menu)
  carry none and should not pretend to.

## Own the state deliberately

Lift `sorting`, `columnFilters`, `pagination`, and `rowSelection` as controlled,
typed state in the component that owns the grid — the table instance is a view
over state you hold, not the owner of it. Table state that must survive a reload
(the filter set a user shares or bookmarks) belongs in the URL — the URL-state
row in craft-layer's `information-design` reference `product-packages.md` names
the per-framework tool; do not rebuild that decision here.

## Server-side data

When the server pages, sorts, or filters:

- Set `manualPagination` / `manualSorting` / `manualFiltering` and pass
  `rowCount`, so the table stops re-doing the work client-side on the one page
  it has.
- Serialize the table state INTO the TanStack Query key —
  `['products', { pagination, sorting, columnFilters }]` — so every distinct
  view is its own cache entry. The key is the cache identity; the
  react-server-state skill carries the full rule.
- `placeholderData: keepPreviousData` keeps the previous page rendered while
  the next loads: page flips swap data in place instead of flashing a skeleton
  and losing scroll position.

## Row selection is keyed by server identity

Pass `getRowId: (row) => row.id`, returning the stable server id. The default
row id is the INDEX, and index-keyed `rowSelection` silently selects different
records after a re-sort or refetch — the user checked three rows, sorted a
column, and is now bulk-deleting three other rows. Nothing errors; only
identity was wrong.

## Virtualize only when tall

For row counts that make the DOM the bottleneck, integrate TanStack Virtual:
`useVirtualizer` over the table's rows, `measureElement` when row heights vary.
The caveats are the actual decision:

- Virtualized rows exist only while scrolled into view — browser find-in-page
  goes blind, and `aria-rowcount` / `aria-rowindex` must be managed by hand or
  assistive tech sees a twenty-row table.
- A list that fits its container does not get virtualized. Virtualization costs
  semantics; pay only when the row count demands it.

## shadcn composition

- Column defs live in `columns.tsx`, separate from the component that renders
  them.
- Render through the shadcn `<Table>` parts; the `DataTable` component is
  generated into your tree and stays copy-owned — extend it in place, per the
  shadcn-best-practices discipline in ui-ux.
- Column scan order, density, and the four table states (loading, empty, error,
  loaded) are design rules, and they live in craft-layer's `information-design`
  skill — defer, do not restate them here.

## Reviewing data-grid code

- The written API matches the installed major — no v8 row-model imports beside
  a v9 feature registry.
- Column defs are module-level or memoized, never inline in JSX.
- Sorting/filters/pagination/selection are controlled and typed; shareable
  state lives in the URL.
- Server-side tables set the manual flags plus `rowCount`, and the table state
  is in the query key.
- `getRowId` returns the server id anywhere row selection is enabled.
- Virtualized tables manage `aria-rowcount`; small tables are not virtualized.

## Anti-patterns

- **v8 and v9 APIs mixed in one file** — runs nowhere; whichever docs the user
  reads next contradict half the code.
- **Inline `columns` array** — table state churn on every render.
- **Index-keyed selection** — silent wrong-record selection after a re-sort.
- **Client-side pagination over server-paged data** — the table paginates the
  single page it was given.
- **Skeleton on every page flip** — `placeholderData: keepPreviousData` is
  missing.
- **Virtualizing thirty rows** — semantics cost paid for no scroll win.

> Last verified: 2026-08-11 — https://tanstack.com/table/latest
