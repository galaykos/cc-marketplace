# Changelog — design-studio

Consumer-facing changes only. Newest first. Entries below 0.5.0 are theme-design's
history, kept verbatim: the plugin was renamed, not restarted.

## 0.5.0

### Changed
- **Renamed from theme-design; design-lab merged in** (marketplace-consolidation-plan,
  2026-09-14). One plugin now carries the browser design session, the
  real-component preview and the registry MCP servers — the three surfaces that
  decide how something looks, which had the tightest overlap in the tree and were
  always installed together through craft-suite.
- Commands are `/design-studio:init`, `/design-studio:export` (from theme-design)
  and `/design-studio:preview` (from design-lab, was `/design-lab:preview`). <!-- removed-ok -->
- The session's working directory is `.design-studio/` (was `.theme-design/`), in
  `serve.py`'s default `--root`, the skill, the hook and the router rule. An open
  session under the old directory is not resumed: export it from the old plugin
  first, or rename the directory.
- `lane.tsv`: the real-component preview yields to a running design session as
  well as to taskmaster's shell mockup — the README stated the first edge for two
  releases and no lane carried it.

### Added
- `real-preview` skill, `scripts/preview-cleanup.sh` and its harness, `mcp/server.mjs`
  and `.mcp.json` (the local `registry-source` server and ReUI's hosted one), all
  from design-lab 0.2.1 unchanged except for the plugin name inside them.

## 0.4.1

### Fixed
- `.when-populated` is `display: contents` in the base sheet, so a page can wrap
  its populated blocks without breaking the parent grid and the state selector
  still hides them (an inline `display` on the wrapper used to win).

## 0.4.0

### Added
- Fidelity dial: a **rich** checkbox in the panel (`POST /__td/rich`, `<root>/rich`)
  turns on imagery gradients, chart shapes, depth, shimmer and motion; the server
  injects `data-rich` on `<html>` at serve time so pages stay clean.
- `server/skins/base.css`: one component vocabulary (~40 classes — app shell,
  stats with sparklines, tables, kanban, tabs, breadcrumbs, pagination, menus,
  dialogs, toasts, alerts, empty states, skeletons, forms, switches, segmented
  controls, progress, avatars, charts, imagery, states) and container-query
  breakpoints; skins are now deltas on it.
- `server/icons.svg`: a 49-symbol stroke icon sprite served at `/icons.svg`.
- `server/charts.js`: bars / line / area / ring shapes from `data-values`, served
  at `/charts.js`; the export copies both assets.
- Panel: viewport select (desktop / tablet 820 / mobile 390, narrows `body` so the
  container queries fire) and a state select driven by `data-states` on the page
  root (`.when-empty` / `.when-populated` …). Both preview-only, both reach the
  session as `viewport` / `state` events.
- `references/patterns.md`: twelve page archetypes (landing, auth, onboarding,
  dashboard, list, detail, form, settings, inbox, checkout, kanban, empty) with
  the blocks and states each declares — the start point for any future mockup.
- `tokens.css`: `--success`, `--warning`, `--font-display`, `--text-3xl`,
  `--sidebar-w`.

### Changed
- Skin files are deltas; `/skin.css` and `<root>/skin.css` are base + delta.
- `assets/page-shell.html` links `/charts.js` and shows icon, chart and state
  conventions in its slot comment; layout primitives moved to the base sheet.
- SKILL: pages start from an archetype with realistic content and declared states.

## 0.3.1

### Fixed
- Editor: the active tool now survives navigation (sessionStorage), so a flow
  can be walked with Go across pages without re-picking it on each one.

## 0.3.0

### Added
- Multi-page flows: the panel's **Go** tool (and Alt+click in any tool) follows
  links inside the canvas and posts a `navigate` event; a page switcher lists
  every page; `partials/<name>.html` + `<!-- include: name -->` is inlined at
  serve time (missing partial → visible marker); `flow.json` records which link
  on which page leads where, served at `GET /__td/flow` and shown as "Flows from
  this page" in the panel; the brief gets a Flows section as a mermaid graph;
  the export inlines partials and relativises page links. Contract in
  `references/flows.md`; states are variants of one page, not pages.

### Fixed
- Editor: Alt+click on a link was cancelled by an unconditional `preventDefault`
  right after the Alt check, so no link could ever be followed in the canvas.

## 0.2.1

### Added
- Presence: while a `/__td/next` is blocked the server reports `listening: true`
  (`/__td/state`, SSE `presence`); the panel header shows **listening** / **away**
  with a tooltip saying what happens to a message sent while away. Harness-gated.
  Found in use: a message typed while the session was between polls sat in the
  queue with no signal to the user.

### Changed
- Panel counter reads "N queued" (gestures and messages since the last reply)
  instead of "N pending".

## 0.2.0

### Added
- Skins: `.theme-design/skin.css` renders the prototype vocabulary in the feel of
  `wireframe` (new default: greyscale, dashed, colour tokens ignored on purpose),
  `shadcn`, `bootstrap`, `mui` or `astryx`. Every skin is a lookalike authored from
  the library's public defaults — not the library, and the docs say so. `--skin`
  on `serve.py` and `/theme-design:init`; `GET /__td/skins`, `POST /__td/skin` <!-- removed-ok -->
  (copies the file, the watcher reloads, a `skin` event reaches the session);
  `/skin.css` falls back to wireframe when the root has none. Harness-gated.
- Panel: a skin selector next to the tools.
- `references/skins.md`: the vocabulary a skin must style and the honesty line
  per skin.

### Changed
- `assets/page-shell.html` carries layout classes only; the component recipes
  (`.card`, `.btn`, `.input`, `.badge`, table, `.avatar`, `.img`) moved to the
  skins so the look can switch under a page. Pages generated by 0.1.x keep their
  inline recipes and simply render over the skin.

## 0.1.1

### Fixed
- `pending-events.sh` cut its 3,000-char injection mid-JSON and still advanced the
  cursor past the cut, so any gesture past roughly the seventh in a batch was lost
  from both surfaces. It now prints whole events only, advances the cursor to the
  last one printed, and says how many stay queued for the next poll. Gated by the
  harness.
- Editor: the first click after a drag dropped on a sibling was swallowed (the
  `justDragged` guard waited for a `click` the browser never fires when mousedown
  and mouseup hit different elements). The guard now expires with the mouseup.
- Editor: a colour pick reported `computed` AFTER the preview, so the skill's
  nearest-token match saw the new colour. `describe()` is captured before the
  first preview frame.
- Server: `/favicon.ico` answers 204 when the root has none, instead of logging a
  404 in every session's console.

### Added
- Editor panel follows `prefers-color-scheme: dark`.
- Event protocol: `page: "/"` is `pages/index.html` in html mode, stated.

## 0.1.0

### Added
- `/theme-design:init` — opens a browser design session: a stdlib Python server <!-- removed-ok -->
  (`server/serve.py`) serves standalone HTML prototypes (`html` mode) or proxies the
  project's dev server (`proxy` mode) with a chat + direct-manipulation editor
  injected into every page. Claude long-polls `/__td/next` from the running session,
  applies gestures to real files, replies through `/__td/reply`, and the page
  live-reloads.
- `/theme-design:export` — tokens.css (light + dark, contrast-checked), prototype <!-- removed-ok -->
  pages, a design brief from the session's decisions and transcript, and an
  optional direct write into the project's theme file.
- `design-session` skill with the event protocol and export targets as references,
  a shadcn-named `tokens.css` starter and a token-only page shell.
- `pending-events.sh` UserPromptSubmit hook — injects unconsumed browser events into
  a terminal turn while a session is running; silent otherwise.
- Harness `scripts/__tests__/serve.test.sh` (26 assertions) covering the bridge
  contract, editor injection, CSRF header, traversal refusal, SSE, proxy injection
  and Location rewriting, and the status/stop lifecycle.
