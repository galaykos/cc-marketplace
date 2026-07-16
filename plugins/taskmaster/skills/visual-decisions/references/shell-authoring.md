# Authoring a shell mockup

How to fill `assets/shell.html` once it is copied to
`taskmaster-docs/mockups/YYYY-MM-DD-<topic>.html` (the dated ledger file —
each authored pass is then copied over `current.html`, the single file the
user's preview tab watches; see the SKILL's Preview section). Read by
`visual-decisions/SKILL.md` before the first authored pass; the shell itself
carries all the polish (header, frames, compare modes, auto-reload) — never
restyle it, only fill its slots and content.

## Variant frame markup

- Tab title: `SLOT: title` in `<head>` — fill it with the decision question so
  multi-tab preview sessions and the gallery stay navigable. Because `<title>`
  is an escapable raw-text (RCDATA) element, an unfilled slot renders the literal comment text
  (`<!-- SLOT: title -->`) in the browser tab rather than nothing, so always
  fill it. (Gallery saves use the slug instead — see Gallery save format.)
- Header: `SLOT: question`, `SLOT: axis`, `SLOT: pass` (e.g. "pass 1 of 2").
- Per variant: `SLOT: variant-A-label`, `-caption`, `-content`, and numbered
  tradeoff bullets (`<li data-n="1">`) in `SLOT: tradeoffs-A`; same for B/C.
- Place `<button type="button" class="vd-callout" data-n="1">1</button>` badges
  inside variant content where each numbered bullet applies. The callout is a
  real button so it joins the tab order; hovering it OR its bullet, or focusing
  the button by keyboard, highlights the pair, and a click/Enter toggles that
  highlight (so touch and keyboard reach it, not just hover). The shell wires
  each callout to its bullet with `aria-describedby` at load, so a screen reader
  reads the tradeoff text when the callout is focused — nothing to author beyond
  matching `data-n` values.
- Two variants only? Delete the `FRAME-C-START…FRAME-C-END` block.
- Build variant content from the shell's primitives — see "Content
  primitives" below — with real density; no inline styles, no hand-rolled
  CSS colors.
- No primitive fits? Add shared classes to the `SLOT: custom-css` block —
  never style one variant differently from its rivals, EXCEPT the sanctioned
  theme-axis token presets on `.vd-content` (see Theme-axis passes); a
  hand-decorated favorite next to plain rivals is a sales pitch, not a
  comparison. `SLOT: custom-css` lives in its own `<style>` block AFTER the
  shell's main stylesheet — including its `@media print` rules — so any
  selector added here that happens to match print-visible chrome wins over
  it in source order; keep additions scoped to variant content and never
  restyle print output from this slot.

## Data-state conventions

A frame's `.vd-content` may hold sibling `<div data-state="...">` blocks; the
shell auto-injects a per-frame toggle bar listing only the states a frame
actually provides and shows one at a time. Known states, in toggle order:
`populated`, `empty`, `loading`, `error`. A frame with no `data-state`
children renders untouched (this is how a v1-shaped, single-state mockup keeps
working).

When any frame is stateful, the shell also injects a GLOBAL segmented control
into the header (`#vd-header .vd-controls`), built from the UNION of every
frame's state sets — it offers every state that appears in any frame. Picking
a state drives all frames together, so the comparison stays on one axis; each
frame's own bar remains as a secondary override that affects only that frame.

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
- Fallback on a missing state: when the global control selects a state a frame
  does not provide, that frame falls back to its FIRST available state, and
  its per-frame bar's `aria-pressed` reflects the state actually displayed
  (not the globally selected one) — a frame that can't honor the global pick
  reads honestly instead of pretending to.
- Keep frames height-comparable: `.vd-content` is capped (`max-height`) and
  content beyond the cap scrolls inside the frame, so a dense state in one
  variant can't tower over its siblings and break side-by-side scanning.

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
not about the axis under test. A theme-axis pass (see Theme-axis passes)
satisfies this rule by construction rather than by exception: its content is
required to be byte-identical across frames, so fidelity is automatically
equal — only the token preset differs, never the data.

## Starters as copy-paste content

`references/starters/*.html` are curated, self-contained variant fragments —
one pattern each (landing — hero vs proof emphasis; dashboard — kpi vs table emphasis; crud-form — single vs multi-step; onboarding-flow — progress vs checklist; settings — tabs vs single scroll; dialog — inline vs modal edit; admin-table — bulk vs row actions; app-shell — sidenav vs topbar),
already state-tagged and realistic-data populated. They are reference
material, not a full-catalog splash: offer at most two, matching the
decision's direction, and only after the variants for THIS decision already
exist — a starter anchors a pass, it doesn't replace drafting one.

To use one: open the starter file, copy its whole fragment (persistent
chrome plus its `data-state` blocks) into a frame's `SLOT: variant-X-content`,
then swap its stock names/amounts/copy for the actual scenario under
discussion — a starter's placeholder data is realistic on purpose, but it is
still not this decision's data, and shipping it verbatim reads as a canned
demo instead of the user's own product. A frame built from a starter obeys
every rule above exactly like a hand-authored one (states, chrome, no
inline styles, equal fidelity with its sibling frames), EXCEPT the sanctioned
theme-axis token presets on `.vd-content` (see Theme-axis passes).

## Content primitives

`vd-app`, `vd-nav`/`vd-brand`, `vd-sidenav`, `vd-tabs`/`vd-tab`, `vd-toolbar`,
`vd-table`, `vd-cards`/`vd-card`/`vd-meta`, `vd-split`,
`vd-list`/`vd-row`/`vd-detail`,
`vd-kpis`/`vd-kpi`, `vd-form`/`vd-field`, `vd-btn` (+`vd-primary`),
`vd-input`, `vd-num`, `vd-chip` (+`vd-ok`/`vd-warn`/`vd-err`/`vd-info`/
`vd-neutral`), `vd-alert` (+`vd-warn`/`vd-err` — each severity also carries a
non-color glyph prefix, so it reads in grayscale), `vd-stepper`/`vd-step`
(`vd-step-num` + `vd-step-label` inside; states `done`/`current`/`todo`),
`vd-accordion`/`vd-acc-item` (`vd-acc-head` + `vd-acc-body` inside; one shown
open via an `open` class, the rest closed — static, no JS), `vd-dialog`/`vd-scrim`,
`vd-crumbs`, `vd-pager`, `vd-empty`, `vd-check`/`vd-switch`, `vd-avatar`,
`vd-progress`, `vd-i` (inline icon glyph). Every one of these is token-driven
(`--vd-*`); combining them is how a variant gets real density without touching
color or spacing by hand.

The three stateful primitives carry no native role, so the shell injects one at
load — additively, with no visual change: `vd-check` becomes `role="checkbox"`,
`vd-switch` becomes `role="switch"`, each with `aria-checked` mirrored from its
`vd-on` class (drop `vd-on` for the unchecked/off look and the state follows).
`vd-progress` becomes `role="progressbar"`; always set its `aria-valuenow`
yourself on the `.vd-progress` element to match the fill you author — the shell
injects the role but not the value, and a determinate bar with no
`aria-valuenow` announces as INDETERMINATE (`aria-valuenow="60"`, optionally
`aria-valuemin`/`aria-valuemax`, and an `aria-label` naming what's progressing,
e.g. `aria-label="Profile completion"` — otherwise it announces a bare
"progressbar 60%" with no subject):

```html
<div class="vd-progress" aria-valuenow="60" aria-label="Profile completion"><i style="width:60%"></i></div>
```

These three elements stay non-focusable `<span>`/`<div>` — the injected role is
a STATIC, non-interactive representation for mockup fidelity, not a working
control. Assistive tech will announce an operable checkbox/switch/progressbar
that cannot actually be toggled; that mismatch is accepted for a throwaway
mockup (the real feature, not the preview, ships the working control) but is
NOT something to carry into production markup.

Icons — `vd-i` pulls one of 12 hand-authored glyphs from the inline sprite:
`<svg class="vd-i" aria-hidden="true" focusable="false"><use href="#vd-i-NAME"/></svg>`, where `NAME` is one of
`menu`, `search`, `chevron`, `check`, `close`, `bell`, `user`, `plus`, `filter`,
`star`, `settings`, `home`. A glyph sizes to the surrounding text (`1em`) and
paints via `currentColor` (no fill), so it inherits the frame's ink in both
schemes and under any theme with no per-scheme rule. An icon-only control still
needs an accessible label (`aria-label` on its trigger); a purely decorative
glyph carries `aria-hidden="true"`.

- Even-application rule: icons are applied EVENLY across ALL frames or not at
  all — an icon-decorated favorite next to text-only rivals is a sales pitch
  (same rule as per-variant styling, with the same kind of sanctioned
  exception: icon presence may differ between frames ONLY when iconography IS
  the axis under test, e.g. an icon-led rail vs a label-led rail). There is no
  per-primitive default icon — authors opt in explicitly, so a mixed set is
  never an accident.

Never rely on chip or alert hue alone to carry status — the five chip
semantics sit close together once desaturated, so pair the color with the
chip's text label (and the alert's built-in severity glyph) so status still
reads in grayscale and for color-blind viewers.

Type ramp & prose — text primitives for editorial/marketing and reading
content. Editorial/marketing hierarchy uses the ramp — never hand-set font
sizes.

- `vd-display` / `vd-t1` / `vd-t2` — the heading ramp (≈2rem / 1.5rem /
  1.2rem; title levels, not to be confused with the `vd-h10`…`vd-h100`
  bar-height utilities below), class-scoped so they never touch a frame's own
  h2 label; use for hero and section headings.
- `vd-tagline` — a softened lead-in line (~1rem, ink-soft) under a hero heading.
- `vd-small` — fine print / captions (.78rem, ink-soft).
- `vd-prose` — a measured reading column (max 65ch) for article/landing copy;
  it styles the `h3`/`p`/`ul`/`blockquote` inside it (the blockquote gets an
  inline-start accent bar). Heading discipline: the frame owns the h2, so
  prose content starts at h3, never h1/h2.
- `vd-lede` — an article's opening paragraph inside `vd-prose` (slightly
  larger, softened) to set the intro apart without a heading.

Chart & media placeholders — CSS-only, token-driven stand-ins. They are for
placement/size/type decisions (chart on the left vs on top, how much room a
hero image needs), NOT data viz: the numbers are shape, not truth, so read
them as blocks of the right size, never as real values.

- `vd-bars` — a bar chart: a flex row of `<i>` bars sharing a baseline; give
  each bar a `vd-h10`…`vd-h100` class for its height (no inline style).
- `vd-spark` — a compact inline bar strip for a KPI, cell, or heading; its
  `<i>` bars also take `vd-h10`…`vd-h100`.
- `vd-h10`…`vd-h100` — bar-height utilities (10% steps) for `vd-bars`/`vd-spark`.
- `vd-donut` — a conic-gradient ring with a hollow center; set the filled
  sweep with a `vd-p10`…`vd-p90` class on the same element.
- `vd-p10`…`vd-p90` — donut-fill utilities driving `--vd-donut-p` (10% steps).
- `vd-media` / `vd-thumb` — a token-tinted gradient box holding image-shaped
  space; use `vd-media` for a feature/hero region, `vd-thumb` for a grid tile.
- `vd-r-16x9` / `vd-r-4x3` / `vd-r-1x1` — aspect-ratio modifiers for
  `vd-media`/`vd-thumb`; the box sizes to its container's width.

Marketing cluster — whole landing/pricing sections. They add structure only, so
headings still come from the ramp and color/size are never hand-set; a marketing
pass (landing copy, pricing) is static content and needs only `populated`/`empty`
states at minimum (see Data-state conventions — it may skip `loading`/`error`).
Heading discipline holds here too: the frame owns the `h2`, so hero/tier/feature
titles start at `h3` (footer column titles at `h4`).

- `vd-hero` — a centered headline/tagline/CTA stack (heading via the ramp,
  buttons via `vd-btn`); add `vd-hero-split` to set the copy beside a `vd-media`
  slot, which folds back to one column at phone width.
- `vd-tiers` / `vd-tier` — pricing columns; add `vd-featured` to mark one tier
  distinct via tokens only (a `--vd-primary` border plus a lifted shadow, no
  fill — the lift rides `--vd-shadow-md`, an accepted exception that stays
  elevated under a flat `--vd-shadow: none` preset). Inside a tier:
  `vd-tier-flag` (the featured badge), `vd-tier-price`, `vd-tier-features` (a
  check-marked list) and a `vd-btn` CTA; the tier name uses a ramp class.
- `vd-features` — an icon/title/text grid, ~2–4 across; each `vd-feature` holds a
  `vd-feature-icon`, a ramp-class title, and a `<p>` of body copy.
- `vd-footer` — a multi-column link footer on `--vd-surface`, ink-soft; column
  titles are `<h4>` chrome, each link column a `<ul>`.

## Semantics

A mockup previews the real feature, so it models the accessible STRUCTURE that
feature will need — not a pixel skin over `<div>` soup. Build from the semantic
primitives (`<button>`, `<table>` with `<th scope>`, `<nav>`, real lists) and let
the shell add what a static preview can't express: callout buttons are wired to
their tradeoff bullets with `aria-describedby`, and `vd-check`/`vd-switch`/
`vd-progress` get their `role`/`aria-checked` (see Content primitives). Because
the structure is honest, accessibility can itself be the decision axis — two
variants differing only in how a control is exposed (a labelled switch vs an
icon-only toggle, how an error is announced) is a legitimate one-axis pass.

Heading discipline is part of that structure. The frame owns the `<h2>` label, so
a frame's content STARTS at `<h3>` and never skips a level: a `vd-card` or
`vd-dialog` title is an `<h3>`, `vd-prose` content starts at `<h3>`, and only a
genuinely deeper title (a footer column under a section `<h3>`) drops to `<h4>`.
Never pick a heading level for its size — the type ramp (`vd-display`/`vd-t1`/
`vd-t2`) and each primitive's own styling carry the visual weight.

## Width presets

The header's viewport-width control (`Phone 375` / `Tablet 768` / `Full`)
writes `data-vd-vw` on the body. `Full` (the default) keeps the current
fluid desktop layout untouched. Picking `Phone`/`Tablet` renders every
frame at the EXACT named width whenever the viewport has room for it:

- Stacked/flip always render at the exact preset width — there is only
  one frame column, so the preset simply sizes it.
- Side-by-side sizes the grid's columns to the preset width instead of
  the frame itself (sizing the frame alone would still get squeezed by
  whatever the side-by-side grid's own column happened to be). At a
  narrow viewport this means the frames may wrap to more than one row,
  or center with empty space around them if only one or two fit per row
  — each still renders at the exact device width; wrapping/centering is
  the honest result of asking for real device width side by side, not a
  bug to hide.
- A zoomed frame (Focus) always ignores the active preset and expands to
  the full available column, in every mode.

Use it to judge layout picks (sidebar vs bottom-nav, table vs cards) at
the width they'll actually run at, not desktop-only. Nothing to author:
the control sizes whatever content the frames already hold, so build
variants at real density and flip presets to check them.

## Direction

Direction (LTR/RTL) is a preview axis, like width and scheme: the header's
`Direction` toggle sets `dir`/`data-vd-dir` on `<html>` and every frame
mirrors at once. Nothing to author and nothing to hand-flip — content built
from the primitives mirrors automatically because they use logical properties
(borders, insets, indents, alignment all resolve from inline-start/-end). Do
NOT translate copy or lay out a frame differently for RTL; that is a separate
decision, not this axis. Two deliberate exceptions stay physical in both
directions: numeric cells (`vd-num`) keep right alignment (tabular convention),
and `vd-m-slide-left/-right` keep their fixed screen direction (use
`vd-m-slide-start/-end` for reading-order motion — see Motion passes).

## Marking the delta

When a one-axis pass turns on a subtle difference (a moved button, one
changed column), tag ONLY the elements that differ with `data-vd-diff` —
the same elements equally in every frame, never a frame's incidental
extras. The header's `Diffs` toggle then draws a static outline plus a
faint tint on them in all frames at once, so the eye lands on the delta
instead of hunting for it. It is static by design (no pulse or motion —
decorative animation is banned), and the button appears only when the
document carries at least one `data-vd-diff`. One caveat: the tint paints
via `background-image`, so don't tag elements whose fill IS a background
image (`.vd-donut`, `.vd-media`, `.vd-thumb`, `.vd-spark`) — tag their
wrapper instead, or the placeholder's gradient is replaced by the tint.

## Motion passes

For a motion decision, keep variants identical in structure and differ on
ONE motion axis via the shell's `vd-anim` plus one `vd-m-*` class
(`vd-m-fade`, `vd-m-slide-up/-down/-left/-right`, `vd-m-slide-start/-end`,
`vd-m-scale`, modified by `vd-m-spring`, `vd-m-fast`/`vd-m-slow`, or the
hover/press feedback classes `vd-m-hover-lift`/`vd-m-hover-glow`/`vd-m-press`).
A frame containing `.vd-anim` gets an auto-injected Replay button;
`prefers-reduced-motion` renders every animated element static. Decorative
animation anywhere else in a mockup is banned — motion is only ever the thing
being decided.

`vd-m-slide-left`/`-right` are physically fixed (always LTR-oriented) — pick
them only when the motion's screen direction is the point. For enter motion
that should follow reading order, use `vd-m-slide-start`/`-end`: they travel
toward the inline-start/-end edge (i.e. enter from the inline-end/-start edge
respectively) and mirror automatically when the Direction axis is flipped to
RTL.

## Theme-axis passes

When the decision is which visual LANGUAGE — not which layout — keep every
frame's content byte-identical and vary ONE token axis per frame via a preset
in the `SLOT: custom-css` block, scoped to `.vd-content` (NEVER `.vd-frame`, so
the header/caption/tradeoff scaffolding stays neutral and only the content
restyles), e.g. `#vd-a .vd-content{--vd-radius:0;--vd-space:6px;--vd-shadow:none}`.
Three sanctioned axes, one per pass:

- **aesthetic** — the `--vd-radius` + `--vd-space` + `--vd-shadow` bundle moving
  together as one "look" (sharp/flat vs rounded/lifted). A flat direction
  (`--vd-shadow: none`) drops elevation entirely, leaving only the border for
  separation (`--vd-line` on `--vd-paper`, a subtle ~1.3:1 contrast) — an
  accepted trade-off of the flat look, not a bug in the preset.
- **density** — `--vd-space` only (e.g. 5px / 8px / 12px). NOTE type does not
  scale on this axis: font sizes are fixed rem, so density is spacing, not size.
  `--vd-space` also sits inside the aesthetic bundle above; this overlap is
  intentional (a look and its rhythm are meant to move together there), so an
  aesthetic pass necessarily shifts spacing too — never read the two axes as
  independent variables in the same pass.
- **type family** — `--vd-font` only, and system/generic stacks ONLY (a `serif`
  or `monospace` stack vs the sans-serif default). External / web fonts are
  banned — a hard constraint: no `@font-face`, no font `<link>`.

One axis per pass; content identical across frames. The page-global project
toggle (`html[data-vd-theme]`) sets these same tokens (`--vd-radius`,
`--vd-space`, `--vd-font`) at `html`, and the per-frame preset re-declares them
directly on `.vd-content`. Both touch the same tokens — the reason they do not
conflict is ordinary cascade behavior, not separate scopes: a value declared
directly on an element always wins over one the element only inherited from an
ancestor, regardless of either rule's specificity. So the frame preset governs
inside `.vd-content`; the project theme still governs everything outside it
(chrome, scaffolding, header) where no preset re-declares the token. Never
combine a theme axis with a layout axis: that is two decisions and two passes
(Max-3 rule).

Dark scheme is a PREVIEW axis, never the decided one: the `html[data-vd-scheme]`
Scheme toggle re-renders the whole page (every frame) on the dark neutral set as
a page-wide legibility spot-check. Never run it as a second axis alongside the
pass's real axis (aesthetic/density/type/layout) — that would be two decisions in
one pass (Max-3 rule). Pick the variant in light, flip Scheme to confirm it
survives dark, flip back.

Guardrail: a new axis type adds exactly one token-axis; content identical across
frames; no new inline styles; no external font/asset.

Out of scope here: a type-SCALE multiplier axis (scaling font sizes per frame) —
font sizes stay fixed rem, so that is not a sanctioned mockup pass.

Machine gate — a theme-axis pass is only honest if the content really is
identical. Extract each frame's `.vd-content` inner HTML (the preset lives in
the `SLOT: custom-css` style block, outside `.vd-content`, so it is stripped by
construction) and diff every frame against the first; empty output = pass:

```bash
python3 - taskmaster-docs/mockups/<file>.html <<'PY'
import sys
from html.parser import HTMLParser
VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input',
        'link', 'meta', 'param', 'source', 'track', 'wbr'}
class Content(HTMLParser):
    # convert_charrefs defaults to True: entities resolve into handle_data,
    # so a frame differing only by &mdash; vs &ndash; still shows up as a diff.
    def __init__(self):
        super().__init__()
        self.depth = 0; self.parts = []; self.blocks = []
    def handle_starttag(self, tag, attrs):
        if self.depth:
            self.parts.append(self.get_starttag_text())
            if tag not in VOID: self.depth += 1
        elif 'vd-content' in dict(attrs).get('class', '').split():
            self.depth = 1; self.parts = []
    def handle_startendtag(self, tag, attrs):
        if self.depth: self.parts.append(self.get_starttag_text())
    def handle_endtag(self, tag):
        if not self.depth: return
        self.depth -= 1
        if self.depth == 0: self.blocks.append(''.join(self.parts).strip())
        else: self.parts.append('</%s>' % tag)
    def handle_data(self, data):
        if self.depth: self.parts.append(data)
    def handle_comment(self, data):
        if self.depth: self.parts.append('<!--%s-->' % data)
p = Content(); p.feed(open(sys.argv[1], encoding='utf-8').read())
for i, b in enumerate(p.blocks[1:], 1):
    if b != p.blocks[0]:
        print('vd-content[%d] differs from vd-content[0]' % i); sys.exit(1)
PY
```

## Data-shape passes

When the decision is which data SHAPE carries a scenario — flat vs nested,
embedded vs referenced, one array vs a keyed map — stage the candidate payloads
as side-by-side `.vd-code` blocks, one shape per frame. It is the payload
counterpart to a layout pass: same discipline, different primitive, and it
replaces the hand-aligned jsonc block that collapses at realistic key lengths.

- Same real scenario in every frame: the SAME order, the SAME customer, the
  SAME amounts — only the shape moves. A frame that also changes the data is
  varying two things at once, so the pick can't be attributed (Max-3 rule).
- One shape axis per pass. "flat vs nested" is one pass; "embedded vs
  referenced" is another — don't fold two shape questions into one set of frames.
- Wrap the keys that DIFFER between shapes in `<mark>` so the eye lands on the
  delta instead of re-reading identical scaffolding; leave shared keys plain.
  `.vd-k` optionally tints the other key names to help a dense payload scan.
- Realistic key lengths are mandatory — `invoice_line_items`, not `items`;
  `billing_address_id`, not `addr`. A toy payload hides exactly the wrapping and
  horizontal-scroll problems the pass exists to expose (the same reason the
  Realistic-data discipline bans lorem/`Item 1` filler).
- Frames live in `api.html` on the shared preview server — the per-purpose file
  reserved for data-shape work (see the SKILL's Preview section) — authored in
  the same shell, never a hand-built page.
- Max-3 and equal fidelity apply unchanged: at most three shapes, each fleshed
  to the same depth — no fully-modeled favorite beside a two-key stub.

Each `.vd-code` block scrolls horizontally inside its own frame, so a long line
never widens the page past the compare grid. `--vd-mono` is a token separate
from the theme-axis `--vd-font`, and the block pins `direction: ltr` because
JSON reads left-to-right by nature — a Direction-axis flip to RTL leaves the
payload upright and readable, it does not mirror the code.

## Gallery save format

On an ACCEPTED pick — not "quick ASCII only", not an abandoned pass — save
the winning variant as a FULL shell-wrapped document (a copy of the current
mockup file reduced to the single winning frame, shell CSS/JS intact) so it
renders styled and standalone when browsed through the preview server:

- Path: `taskmaster-docs/mockups/gallery/YYYY-MM-DD-<slug>.html`, dated the
  day of the pick, `<slug>` a short kebab-case name for the decision.
- Title: set `SLOT: title` to the `<slug>` (not the question) so the saved
  file is identifiable by its browser tab when the gallery is browsed.
- Collision on that path: append `-2`, then `-3`, … — never overwrite a
  prior save; each accepted pick keeps its own file forever.
- Append one line to `taskmaster-docs/mockups/gallery/INDEX.md` (create the
  file, with a one-line header, if it doesn't exist yet): date, slug,
  decision (one line), source spec path — so the gallery is browsable both
  as files (through the same preview server) and as an index table.
- No auto-save without an explicit accepted pick; a mockup the user never
  picked from is not gallery material.
