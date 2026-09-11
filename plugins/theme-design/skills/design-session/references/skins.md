# Skins — how the prototype *could* look, never what it is built with

A prototype here is a wireframe of what to build: structure, hierarchy, copy,
tokens. A skin is one stylesheet, `.theme-design/skin.css`, that renders the
prototype vocabulary in the feel of a component library so the user can see
how the same structure *could* look in it. **Every skin is a lookalike authored
from the library's public defaults — not the library.** Say so the first time a
non-wireframe skin is chosen; never call a skinned page "how it will look in
shadcn". Real components are `/design-lab:preview`'s job.

Shipped, from `${CLAUDE_PLUGIN_ROOT}/server/skins/`:

| skin | feel it borrows | what stays honest |
|---|---|---|
| `wireframe` (default) | greyscale, dashed frames, hatched image boxes | ignores colour tokens on purpose — the talk stays on structure |
| `shadcn` | Tailwind-derived sizes, 1px borders, shadow-sm; tokens.css already uses shadcn's names | colour is exact, components are recipes |
| `bootstrap` | 0.375rem radius, .375/.75rem buttons, .25rem focus halo, 500-weight headings | tokens stand in for `$primary`, `$body-bg`, `$body-color`, `$border-color` |
| `mui` | Roboto, 4px shape, uppercase 500-weight buttons, Paper elevation | no ripple, no theme object; `text.secondary` is a colour-mix |
| `astryx` | container radius over control radius, surface stepping, quiet borders | approximate — the real thing needs `@astryxdesign/core` and a build |

## The vocabulary a skin must style

Pages use these classes and nothing library-specific; a skin styles all of them:
`body`, `h1 h2 h3`, `a`, `.card`, `.btn`, `.btn-primary`, `.btn-secondary`,
`.input`, `.muted`, `.badge`, `.badge-primary`, `table th td`, `.avatar`, `.img`.
Layout classes (`.container .stack .row .grid`) live in the page shell and are
skin-independent. A page that needs a new component gets a class here, styled
in every skin, or it is page-local layout and does not belong to the skin.

## Switching

- At start: `/theme-design:init html --skin bootstrap …` → `serve.py --skin`.
- In the panel: the skin selector posts `/__td/skin`; the server copies the file,
  the watcher reloads, and a `skin` event reaches you so you can log the decision.
- In chat: "show me this in MUI" → `curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"name":"mui"}' http://127.0.0.1:$PORT/__td/skin`.

A skin switch is never an edit to a page or to `tokens.css`. Record it in
`decisions.md` as a preference ("prefers the MUI feel for density"), and carry
it into the brief's Direction — the export's fourth target still writes tokens,
not a skin.
