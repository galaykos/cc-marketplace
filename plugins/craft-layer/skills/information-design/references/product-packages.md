# Product-layer packages — the selector for app surfaces

> **Last verified: 2026-08-11** — the package names and the capability split below;
> @tanstack/react-table v9 is GA as of 2026-08. Maintenance status is a FILTER
> here, not trivia, so re-check before adopting.

The sibling of `../../motion-tiers/references/tier-budgets.md`, for the other half
of the work. `motion-tiers` decides how a surface MOVES; this decides what a
data-dense surface is BUILT from.

**Why this exists.** craft-layer named eighteen motion and visual packages and
zero application packages, while claiming CRM and SaaS as targets. The result is
predictable: a build hand-rolls its grid, its drag interaction, its palette. Two
demo builds did exactly that, and the hand-rolled rota grid shipped with every
cell in the tab order — a keyboard user traversing 45 stops to reach the rest of
the page. A mature grid or an accessible-primitive library gives roving tabindex
by default. **That bug was the cost of having rules and no routing.**

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
| **Data grid** | rows are sorted, filtered, pinned, resized, or selected in bulk | TanStack Table (headless — you own markup), AG Grid (batteries, heavier, licence tiers); usage wiring — column defs, controlled state, server-side pagination — is the `react` plugin's `react-data-grid` skill: this row decides the package, that skill teaches the wiring | headless gives you none — pair with primitives; batteries give grid semantics | a static list under ~50 rows with no interaction |
| **Virtualization** | the row count makes the DOM the bottleneck; measure before assuming | TanStack Virtual; virtualizer-into-grid wiring lives in the same `react-data-grid` skill | none — you still own semantics, and virtualized rows break find-in-page and `aria-rowcount` if unmanaged | the list fits; virtualization costs correctness |
| **Accessible primitives** | ANY custom widget: menu, dialog, combobox, tabs, disclosure, tooltip | Base UI (shadcn's default), Radix, React Aria | the whole point — focus trap and return, roving focus, type-ahead, dismissal, ARIA wiring | a native element does the job; `<button>`/`<details>`/`<dialog>` first |
| **Drag & drop** | reorder, kanban, scheduling boards | dnd-kit (keyboard sensor + live-region announcements built in), Pragmatic DnD | keyboard sensors and screen-reader announcements — the part hand-rolls always miss | a click/tap route is genuinely enough; you owe one anyway (WCAG 2.5.7) |
| **Command palette** | keyboard-first product, or the action surface outgrew the nav | cmdk, or a combobox from the primitives library | combobox semantics, `aria-activedescendant`, type-ahead | the app has few actions; a palette over eight commands is theatre |
| **Forms + validation** | more than about three fields, or any cross-field rule | React Hook Form (ecosystem default, most examples) or TanStack Form (first-party type-safe field API — pick it when the app is already on TanStack Router/Query), with a schema validator; shadcn documents both, so match the project's existing choice before adding a second form stack | error association (`aria-describedby`), invalid state, focus-to-first-error | one or two fields — native constraint validation is lighter and better |
| **Charts** | `information-design`'s chart-vs-table decision landed on chart | Recharts (composable, common with shadcn), visx/D3 (bespoke, expensive) | almost none — you owe the table alternative and a text summary regardless | a stat tile or table answers it; most "chart" requests are not charts |
| **Server state** | data is fetched, cached, refetched, or mutated optimistically | TanStack Query, or the framework's own loader/action layer | none directly — but it is what makes the perceived-speed floor reachable | one static payload |
| **URL / filter state** | filters, sort, tabs, or page must survive reload and be shareable | TanStack Router validated `search` params (typed; Router/Start apps), nuqs (Next.js), or a plain `URLSearchParams` sync | none directly — but back/forward and share-a-view are UX floors | truly ephemeral UI: open menus, hover, drafts |
| **Date & time** | scheduling, ranges, recurring, or any timezone crosses a boundary | date-fns / Temporal where available | none — pair with a primitives datepicker or a native input | a formatted timestamp; `Intl.DateTimeFormat` is built in |

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
