# Authoring a shell mockup

How to fill `assets/shell.html` once it is copied to
`taskmaster-docs/mockups/YYYY-MM-DD-<topic>.html` (the dated ledger file —
each authored pass is then copied over `current.html`, the single file the
user's preview tab watches; see the SKILL's Preview section). Read by
`visual-decisions/SKILL.md` before the first authored pass; the shell itself
carries all the polish (header, frames, compare modes, auto-reload) — never
restyle it, only fill its slots and content.

## Variant frame markup

- Header: `SLOT: question`, `SLOT: axis`, `SLOT: pass` (e.g. "pass 1 of 2").
- Per variant: `SLOT: variant-A-label`, `-caption`, `-content`, and numbered
  tradeoff bullets (`<li data-n="1">`) in `SLOT: tradeoffs-A`; same for B/C.
- Place `<span class="vd-callout" data-n="1">1</span>` badges inside variant
  content where each numbered bullet applies — hovering either highlights
  the pair.
- Two variants only? Delete the `FRAME-C-START…FRAME-C-END` block.
- Build variant content from the shell's primitives — see "Content
  primitives" below — with real density; no inline styles, no hand-rolled
  CSS colors.
- No primitive fits? Add shared classes to the `SLOT: custom-css` block —
  never style one variant differently from its rivals; a hand-decorated
  favorite next to plain rivals is a sales pitch, not a comparison.

## Data-state conventions

A frame's `.vd-content` may hold sibling `<div data-state="...">` blocks; the
shell auto-injects a toggle bar listing only the states a frame actually
provides and shows one at a time. Known states, in toggle order: `populated`,
`empty`, `loading`, `error`. A frame with no `data-state` children renders
untouched (this is how a v1-shaped, single-state mockup keeps working).

- Elements that are NOT tagged `data-state` are persistent chrome — a nav
  bar, toolbar, crumb trail, or tab strip placed as a plain sibling before
  the `data-state` blocks stays visible across every state instead of
  flickering out during `loading`/`error`. Prefer this over duplicating the
  chrome inside each state block.
- Build only the states the decision actually needs — a static content pass
  (landing copy, pricing) may need only `populated` and `empty`; a data
  surface (dashboard, table, list-detail) should show `populated` and at
  least one failure/void mode so the pick accounts for more than the happy
  path.
- `empty` is the honest empty state (a real "nothing here yet" message plus
  its call to action), never a blank box. `loading` and `error` reuse the
  same surrounding chrome with the main content swapped for a `.vd-empty`
  placeholder or a `.vd-alert.vd-err` message with a retry action — there is
  no shimmer/skeleton primitive, so don't invent one with inline styles.

## Max-3 rule

At most 3 variants (frames A/B/C), differing on ONE axis at a time. Two axes
varying together is two decisions and two mockup passes, not one; more than
3 variants produces "whichever" instead of an attributable pick. This holds
for every pass regardless of source — hand-authored, starter-seeded, or a
gallery re-use.

## Realistic-data discipline

Populate every state with specific, real-shaped data — an invoice with a
number, a customer with a name, an amount with cents, a date that could be
today's — never lorem ipsum and never a generic "Item 1 / Item 2" filler.
Placeholders that read like production data expose real layout and density
problems (a name that wraps, an amount that doesn't right-align, a status
chip that clips) that lorem-shaped filler hides entirely. Equal fidelity
across variants matters as much as realism within one: if A gets a fully
fleshed table and B gets three placeholder rows, the pick is about effort,
not about the axis under test.

## Starters as copy-paste content

`references/starters/*.html` are curated, self-contained variant fragments —
one pattern each (landing, dashboard, crud-form, onboarding-flow, settings),
already state-tagged and realistic-data populated. They are reference
material, not a five-pattern splash: offer at most two, matching the
decision's direction, and only after the variants for THIS decision already
exist — a starter anchors a pass, it doesn't replace drafting one.

To use one: open the starter file, copy its whole fragment (persistent
chrome plus its `data-state` blocks) into a frame's `SLOT: variant-X-content`,
then swap its stock names/amounts/copy for the actual scenario under
discussion — a starter's placeholder data is realistic on purpose, but it is
still not this decision's data, and shipping it verbatim reads as a canned
demo instead of the user's own product. A frame built from a starter obeys
every rule above exactly like a hand-authored one (states, chrome, no
inline styles, equal fidelity with its sibling frames).

## Content primitives

`vd-app`, `vd-nav`, `vd-sidenav`, `vd-tabs`, `vd-toolbar`, `vd-table`,
`vd-cards`/`vd-card`, `vd-split`, `vd-list`/`vd-row`/`vd-detail`,
`vd-kpis`/`vd-kpi`, `vd-form`/`vd-field`, `vd-btn` (+`vd-primary`),
`vd-input`, `vd-num`, `vd-chip` (+`vd-ok`/`vd-warn`/
`vd-err`), `vd-alert` (+`vd-warn`/`vd-err`), `vd-dialog`/`vd-scrim`,
`vd-crumbs`, `vd-pager`, `vd-empty`, `vd-check`/`vd-switch`, `vd-avatar`,
`vd-progress`. Every one of these is token-driven (`--vd-*`); combining them
is how a variant gets real density without touching color or spacing by
hand.

## Motion passes

For a motion decision, keep variants identical in structure and differ on
ONE motion axis via the shell's `vd-anim` plus one `vd-m-*` class
(`vd-m-fade`, `vd-m-slide-up/-down/-left/-right`, `vd-m-scale`, modified by
`vd-m-spring`, `vd-m-fast`/`vd-m-slow`, or the hover/press feedback classes
`vd-m-hover-lift`/`vd-m-hover-glow`/`vd-m-press`). A frame containing
`.vd-anim` gets an auto-injected Replay button; `prefers-reduced-motion`
renders every animated element static. Decorative animation anywhere else
in a mockup is banned — motion is only ever the thing being decided.

## Gallery save format

On an ACCEPTED pick — not "quick ASCII only", not an abandoned pass — save
the winning variant as a FULL shell-wrapped document (a copy of the current
mockup file reduced to the single winning frame, shell CSS/JS intact) so it
renders styled and standalone when browsed through the preview server:

- Path: `taskmaster-docs/mockups/gallery/YYYY-MM-DD-<slug>.html`, dated the
  day of the pick, `<slug>` a short kebab-case name for the decision.
- Collision on that path: append `-2`, then `-3`, … — never overwrite a
  prior save; each accepted pick keeps its own file forever.
- Append one line to `taskmaster-docs/mockups/gallery/INDEX.md` (create the
  file, with a one-line header, if it doesn't exist yet): date, slug,
  decision (one line), source spec path — so the gallery is browsable both
  as files (through the same preview server) and as an index table.
- No auto-save without an explicit accepted pick; a mockup the user never
  picked from is not gallery material.
