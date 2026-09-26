# Product-layer packages — the selector for app surfaces

> **Last verified: 2026-09-26** — https://www.npmjs.com — the interaction-surface rows and
> the Drag & drop row. Versions, licences and the accessibility each package ships were read
> that day from npm and from each project's own docs. The other capability rows were last
> checked on 2026-08-11 (@tanstack/react-table v9 GA as of 2026-08).
>
> Maintenance status is a FILTER here, not trivia, so re-check before adopting.

The sibling of `../../motion-tiers/references/tier-budgets.md`, for the other half
of the work. `motion-tiers` decides how a surface MOVES; this decides what a
data-dense surface is BUILT from.

**Why this exists.** Without a package route, a build hand-rolls its grid, its drag
interaction, its palette — and a hand-rolled grid puts every cell in the tab order, so a
keyboard user traverses dozens of stops to leave it. A mature grid or an
accessible-primitive library gives roving tabindex by default.

## The sixth question, and why this layer has one motion does not

Run the five that `motion-tiers` runs — native-first, cost at the tier that
matters, maintenance signal, licence, absence fallback — then one more:

**What accessibility does this give me for free, and what am I signing up to
implement myself if I skip it?**

On the motion layer, skipping a library costs you an effect. Here it costs you a
WAI-ARIA pattern: roving focus, `aria-activedescendant`, type-ahead, drag
announcements, focus return on dismiss. These are specified, subtle, and
routinely got wrong by hand — and getting them wrong is invisible until someone
tries to use the thing without a mouse. Reach for a library on this layer
*because* of accessibility, not despite the bytes.

## The capability areas

Named packages sit INSIDE the decision, exactly as the motion tiers do. Naming a
package with a when-to-use and a cost is a selector; a list of blessed libraries
with no constraints is the catalog the kill-trigger forbids.

| Capability | Reach for it when | Candidates | Free accessibility | Skip it when |
| --- | --- | --- | --- | --- |
| **Data grid** | rows are sorted, filtered, pinned, resized, or selected in bulk | TanStack Table (headless — you own markup), AG Grid (batteries, heavier, licence tiers); usage wiring — column defs, controlled state, server-side pagination — comes from the chosen library's own docs for the installed major: this row decides the package, their docs teach the wiring | headless gives you none — pair with primitives; batteries give grid semantics | a static list under ~50 rows with no interaction |
| **Virtualization** | the row count makes the DOM the bottleneck; measure before assuming | TanStack Virtual; wire the virtualizer into the grid per the TanStack docs for the installed major | none — you still own semantics, and virtualized rows break find-in-page and `aria-rowcount` if unmanaged | the list fits; virtualization costs correctness |
| **Accessible primitives** | ANY custom widget: menu, dialog, combobox, tabs, disclosure, tooltip | Base UI (shadcn's default), Radix, React Aria | the whole point — focus trap and return, roving focus, type-ahead, dismissal, ARIA wiring | a native element does the job; `<button>`/`<details>`/`<dialog>` first |
| **Drag & drop** | reorder, kanban, scheduling boards | dnd-kit (`@dnd-kit/core` is now the legacy line; `@dnd-kit/react` is 0.x), Pragmatic DnD | keyboard sensors and screen-reader announcements, the part hand-rolled drag always misses. BUT dnd-kit's default announcements read the raw `id` ("Picked up draggable item 42"): pass label-based `announcements` that name the item and its position | a click/tap route is genuinely enough; you owe one anyway (WCAG 2.5.7) |
| **Command palette** | keyboard-first product, or the action surface outgrew the nav | cmdk, or a combobox from the primitives library | combobox semantics, `aria-activedescendant`, type-ahead | the app has few actions; a palette over eight commands is theatre |
| **Forms + validation** | more than about three fields, or any cross-field rule | React Hook Form (ecosystem default, most examples) or TanStack Form (first-party type-safe field API — pick it when the app is already on TanStack Router/Query), with a schema validator; shadcn documents both, so match the project's existing choice before adding a second form stack | error association (`aria-describedby`), invalid state, focus-to-first-error | one or two fields — native constraint validation is lighter and better |
| **Charts** | `information-design`'s chart-vs-table decision landed on chart | Recharts (composable, common with shadcn), visx/D3 (bespoke, expensive) | almost none — you owe the table alternative and a text summary regardless | a stat tile or table answers it; most "chart" requests are not charts |
| **Server state** | data is fetched, cached, refetched, or mutated optimistically | TanStack Query, or the framework's own loader/action layer | none directly — but it is what makes the perceived-speed floor reachable | one static payload |
| **URL / filter state** | filters, sort, tabs, or page must survive reload and be shareable | TanStack Router validated `search` params (typed; Router/Start apps), nuqs (Next.js), or a plain `URLSearchParams` sync | none directly — but back/forward and share-a-view are UX floors | truly ephemeral UI: open menus, hover, drafts |
| **Date & time** | scheduling, ranges, recurring, or any timezone crosses a boundary | date-fns / Temporal where available | none — pair with a primitives datepicker or a native input | a formatted timestamp; `Intl.DateTimeFormat` is built in |

## Interaction-surface widgets — where the library gives least

For these widgets the sixth question has the smallest answer. A library settles rendering and
leaves most of the accessibility to you, so the table carries two columns: what comes free, and
what you still owe. The owed half is spelled out in `scheduling-surfaces.md`,
`spatial-surfaces.md` and `live-surfaces.md`.

| Capability | Candidates (checked 2026-09-26) | Free accessibility | You still owe |
| --- | --- | --- | --- |
| **Scheduler** | FullCalendar 7: standard views MIT; resource and timeline views premium, with a licence key; named zones through its `temporal-polyfill` peer; RRULE through `@fullcalendar/rrule`. Schedule-X 4: MIT core, with drag and resize moved to paid plugins. react-big-calendar: keyboard access to events was declined upstream. Or the component library's own calendar (`ui-ux:component-libraries`) | FullCalendar: interactive elements are tabbable; events are tabbable only with `eventInteractive: true`. No documented keyboard move | the keyboard move, the non-drag edit dialog (SC 2.5.7), zone-correct storage, event names |
| **Maps** | MapLibre GL JS 6: BSD-3, ESM-only, WebGL2; `react-map-gl/maplibre` in React. Leaflet 1.9: 2.0 is still alpha. Mapbox GL JS: proprietary terms and an access token | keyboard pan and zoom on the map; `cooperativeGestures` (MapLibre); Leaflet markers tabbable with `keyboard` + `alt` | focus, role and name for custom markers; the list twin; clustering (Leaflet.markercluster was last published 2021); the client-only import; token restriction |
| **Rich text** | Tiptap 3: MIT core, some Pro extensions paid. Lexical 0.x: MIT; `@lexical/a11y`. ProseMirror directly for a bespoke editor. For incidental formatting, a `<textarea>` plus Markdown | semantic output (Tiptap); the WAI-ARIA keyboard model (Lexical, which says to verify conformance in your integration) | the toolbar as `role="toolbar"` with roving focus (Tiptap is headless and says accessibility is yours); `immediatelyRender: false` under SSR; sanitising on render (`security:security-review`); APIs pinned to the installed major |
| **Network graph** (read-only) | Sigma.js 3 + graphology: WebGL, thousands of nodes; v4 in beta. Cytoscape.js: canvas, with WebGL as a provisional preview. force-graph. d3-force + SVG for a few hundred nodes | none: every option draws pixels, with no DOM per node | the node-and-edge table twin, keyboard selection, a text summary, layout off the render path |
| **Flow editor** | React Flow (`@xyflow/react` 12): MIT; Pro is a paid subscription for examples and support. Svelte Flow for Svelte | focusable nodes and edges; arrow-key moves of the selection; a live region announcing moves; `ariaLabelConfig` | a route to connect nodes without dragging; the node table; never `disableKeyboardA11y` |
| **Diff viewer** | `diff` (jsdiff) to compute; `@codemirror/merge` for side-by-side and unified views; Monaco `DiffEditor` (heavy, no mobile browsers); `react-diff-viewer-continued`; `diff2html` to render a patch | Monaco's accessible diff viewer: F7 and Shift+F7 step through the changes | `<ins>`/`<del>` or a ± glyph, never colour alone (SC 1.4.1); synced scroll across panes; large diffs computed off the main thread; merges that commit only whole choices |
| **Code viewer** | Shiki 4: static HTML at build or server time; Node ≥ 20. CodeMirror 6 for editing. Monaco for IDE-grade editing, with no mobile browser support | CodeMirror: screen-reader support, and no keyboard trap by default because it leaves Tab alone. Shiki: plain `<pre><code>` and no client JS | a language label and a named copy button; if `indentWithTab` is bound, keep the Escape-then-Tab exit (SC 2.1.2) |
| **Upload** | Uppy 6: its Dashboard is built for keyboard and screen readers; `@uppy/tus` for resumable uploads. react-dropzone 20: headless. FilePond 4: v5 in beta; `react-filepond` last published 2024-12 | Uppy's Dashboard. react-dropzone renders a real `<input type="file">` and a keyboard-activatable root, but that root has `role="presentation"`: override it to `button` | a drop zone that is also a real button; per-file progress and errors as text; revoked object URLs; direct-to-storage uploads for large files; server-side checks |
| **Collaboration, presence** | Yjs 13 with `y-websocket` or Hocuspocus. Tiptap `Collaboration` + `CollaborationCaret` (the v3 name; `CollaborationCursor` ended at v2). Liveblocks (hosted, commercial) | none | presence that expires (Yjs awareness drops a peer after 30 s of silence); names on cursors and avatars; no announcement per remote keystroke; resync after a reconnect; a record of who changed what |

## Motion on a data surface is the SAME tiers, a different job

Nothing here replaces `motion-tiers`, and a data surface is not a
motion-free surface. Route it to the existing tiers:

- **Tier 1 — UI state / layout** (Motion) — layout/FLIP transitions when a filter narrows a list, a
  row enters or leaves, a card moves column, a drawer opens. Shared-layout
  animation is what makes a re-sort readable instead of a flash.
- **Tier 2 — Timeline / SVG** (anime.js) — value interpolation on a KPI that changed, chart draw-in
  and series morphs, staggered reveal of a tile row.

Both stay inside the existing per-tier and cumulative budgets, and both answer to
the data-motion floor in `app-craft-floors.md`: motion may clarify where a number
went, and may never delay the first read of it.

## Anti-patterns

- **Hand-rolling a widget a primitives library specifies.** The bytes you saved
  are cheaper than the focus management you did not write.
- **Batteries where headless fits, or headless where you have no primitives.**
  Headless plus hand-rolled markup is the combination that loses the semantics.
- **Virtualizing on instinct.** Measure the row count that actually hurts; the
  published guidance from the grid projects does not name a threshold because
  there is not one.
- **A palette as decoration.** ⌘K over a handful of actions is genre cosplay.
- **Charting because the tile looked empty.** The container decision is
  `information-design`'s and comes first.
- **Treating this layer as motion-free** — see above; a dense surface earns
  transitions that carry meaning.
