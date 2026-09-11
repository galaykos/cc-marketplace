# Skins, vocabulary, fidelity — how the prototype *could* look, never what it is built with

A prototype here is a wireframe of what to build: structure, hierarchy, copy,
tokens, flow. Two dials decide how much it looks like an app:

- **Skin** — `.theme-design/skin.css` = `server/skins/base.css` + one delta.
  The base sheet is the component vocabulary; a skin restyles it in the feel of
  a library. **Every skin is a lookalike authored from the library's public
  defaults — not the library.** Say so the first time a non-wireframe skin is
  chosen; never call a skinned page "how it will look in shadcn". Real
  components are `/design-lab:preview`'s job.
- **Rich** — the panel's checkbox, `POST /__td/rich`, `<root>/rich`. The server
  injects `data-rich` on `<html>` at serve time (pages never carry it): imagery
  gradients, chart shapes, depth, motion, shimmer. Off, the same page is a
  styled wireframe. Start off; turn it on when the question becomes "would I
  ship this", never before the structure is agreed — polish anchors decisions.

| skin | feel it borrows | what stays honest |
|---|---|---|
| `wireframe` (default) | greyscale, dashed frames, hatched imagery, hand-drawn type | overrides colour tokens on purpose — the talk stays on structure |
| `shadcn` | Tailwind-derived sizes, 1px borders, shadow-sm, pill tabs | tokens.css already uses shadcn's names, so colour is exact |
| `bootstrap` | 0.375rem radius, .375/.75rem buttons, .25rem focus halo, 500-weight headings | tokens stand in for `$primary`, `$body-bg`, `$body-color`, `$border-color` |
| `mui` | Roboto, 4px shape, uppercase buttons, Paper elevation, outlined inputs | no ripple, no theme object; `text.secondary` is a colour-mix |
| `astryx` | container radius over control radius, surface stepping, quiet borders | approximate — the real thing needs `@astryxdesign/core` and a build |

## The vocabulary (base.css) — use these, add here, never restyle in a page

| group | classes |
|---|---|
| type | `h1 h2 h3`, `.display`, `.muted`, `.small`, `.mono`, `.kbd` |
| layout | `.container .stack .stack-sm .row .row-sm .between .wrap .grow .grid .cols-2 .cols-3 .cols-4 .cols-main-aside .divider` |
| app shell | `.app .sidebar .brand .navlink[.active] .push-down .content .topbar .page .pagehead` |
| surfaces | `.card .card-head .card-foot .stat .value .trend[-up/-down] .panel .hero` |
| controls | `.btn[-primary/-secondary/-ghost/-danger/-sm/-lg/-icon] .input .select .textarea .field[.invalid] .hint .search .switch[.on] .check .segmented` |
| navigation | `.tabs .breadcrumb .pagination .dropdown .menu` |
| data | `table th td .num .badge[-primary/-success/-warning/-danger] .dot .avatar[-lg] .avatars .progress .list .feed .feed-item .kanban .col .deal .chart .spark .legend` |
| feedback | `.alert[-danger/-success] .toast .tooltip[data-tip] .empty .skeleton .dialog-backdrop .dialog .actions` |
| imagery | `.img[-square/-wide] .logo`, `<svg class="icon"><use href="/icons.svg#name"/></svg>` (49 names in `server/icons.svg`) |
| states | `data-states="empty,error"` on the page root, `.when-empty .when-loading .when-error .when-populated` |

Charts: `<div class="chart" data-kind="bars|line|area|ring" data-values="3,5,2,8" [data-labels] [data-max] [data-center]>`;
`/charts.js` draws an inline SVG. `.spark` on a stat card is the small form.

A page that needs a component not listed here gets the class **in base.css**
(then every skin renders it; add a delta only where a skin's feel differs), or
it is page-local layout and stays in the page's `<style>` as grid shape only.
Breakpoints are container queries on `body`; the panel's viewport select
narrows `body` so tablet and mobile render in place.

## Switching

- At start: `/theme-design:init html --skin bootstrap …` → `serve.py --skin`.
- In the panel: the skin selector posts `/__td/skin`; the rich checkbox posts
  `/__td/rich`; both reload and reach you as `skin` / `rich` events — log the
  preference, edit nothing.
- In chat: "show me this in MUI" → `curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"name":"mui"}' http://127.0.0.1:$PORT/__td/skin`; "make it rich" → the same with `{"on":true}` on `/__td/rich`.

A skin or rich switch is never an edit to a page or to `tokens.css`. Record it
in `decisions.md` as a preference and carry it into the brief's Direction —
the export's fourth target still writes tokens, not a skin.
