# theme-design

Design the look in the browser, with Claude applying every move. `/theme-design:init`
serves a canvas on localhost with a chat and direct-manipulation panel injected into
every page. You talk, select, drag, resize, edit text and pick colours there; the
running Claude Code session long-polls a local bridge, turns each gesture into a real
edit, replies in the panel, and the page reloads. No API key, no second app: the
session you already pay for is the brain, so every project skill and CLAUDE.md rule
it knows applies to the design work too.

| Command | What it does |
|---|---|
| `/theme-design:init [html \| proxy <url>] [--skin <name>] [brief]` | Start or resume a session. `html` serves standalone prototypes under `.theme-design/pages/` driven by one `tokens.css` and one `skin.css`; `proxy` overlays the editor on your running dev server and edits go to project source. No mode given: detects a dev server and asks once |
| `/theme-design:export [tokens\|pages\|brief\|write]` | Write `tokens.css` (light + dark, contrast-checked), the prototype pages, a design brief built from the session's decisions and transcript, and optionally merge tokens into the project's theme file after showing the diff. Stops the server if this session started it |

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install theme-design@cc-plugins-marketplace
```

Needs `python3` (stdlib only) and `curl`. The prompt hook needs `jq` and is silent without it.

## How the loop works

```
browser panel ──POST /__td/event──▶ .theme-design/events.jsonl
                                          │
Claude (this session) ◀──GET /__td/next── long-poll, advances cursor
      │ edits tokens.css / pages / project source
      └──POST /__td/reply──▶ SSE ──▶ panel line + reload
```

The Claude side is one `curl` per wait, run from the session with a five-minute
timeout; an empty batch is polled again silently. Esc in the terminal interrupts a
wait. If you type in the terminal while events are pending, the plugin's
`UserPromptSubmit` hook injects them into that turn and advances the same cursor,
so nothing is delivered twice.

Working files live in `.theme-design/` at the project root: `tokens.css`, `pages/`,
`events.jsonl`, `transcript.md`, `decisions.md`, `state.json` (live pid, port, mode)
and `cursor`. Track it or ignore it; the plugin suggests `.gitignore` once and never
decides.

## Skins: how it could look, not what it is built with

A prototype here is a wireframe of what to build. The panel's skin selector (or
`--skin` at init, or "show me this in MUI" in chat) swaps one stylesheet,
`.theme-design/skin.css`, so the same structure renders in the feel of
`wireframe` (default, greyscale), `shadcn`, `bootstrap`, `mui` or `astryx`.
**Every skin is a lookalike authored from the library's public defaults, not the
library** — no CDN, no React runtime, no registry install; the panel and the
export brief say so. Real components are `/design-lab:preview`'s job. The
vocabulary a skin styles and the honesty line per skin:
`skills/design-session/references/skins.md`.

## Multi-page flows

One file per screen under `pages/`, plain relative links between them, and the
panel's **Go** tool (or Alt+click in any tool) walks them; the page switcher
lists every page. `partials/<name>.html` + `<!-- include: name -->` is the shared
sidebar or top bar, inlined at serve time and at export. `flow.json` is the
record of which link leads where: Claude writes it as links are added or walked,
the panel shows "Flows from this page", and the brief draws it as a mermaid
graph. States (empty, error, logged-out) are variants of one page, not pages.
Contract: `skills/design-session/references/flows.md`.

## What each gesture becomes

| in the panel | Claude does |
|---|---|
| chat message (with an element selected) | the request, scoped to that element |
| drag and drop on a sibling | reorders the DOM; a drop with no target becomes a layout change in that direction, never `position:absolute` |
| corner-handle resize | width, column span, basis, padding or aspect, by the element's role, said in the reply |
| colour pick | the nearest token in `tokens.css`, or a new one under both `:root` and `.dark` |
| double-click text edit | verbatim content change |
| note on an element | a brief scoped to it |
| Go tool / Alt+click on a link | the browser follows it; Claude adds the edge to `flow.json` if the record lacked it |
| "link this to reports" with a selection | href set, edge recorded, page created from the shell if missing |
| skin selector | nothing to edit — the server swapped `skin.css`; Claude logs the preference |
| End session | export, then stop |

Three picks on one axis in a row make Claude offer candidates side by side instead
of a fourth single reveal. The full contract is
`skills/design-session/references/event-protocol.md`.

## What has teeth and what is recorded

| claim | standing |
|---|---|
| The bridge: seq-ordered events, single delivery through the cursor, editor injection, CSRF header on every mutation, traversal refusal, SSE reply and reload, proxy injection and `Location` rewrite, `--status`/`--stop`, skin list/switch/fallback, listening/away presence, partial inlining with a visible marker for a missing one, `/__td/flow` | **gate** — `scripts/__tests__/serve.test.sh`, run by CI's plugin-harness step |
| `flow.json` stays true to the links on disk | **agent-graded** — Claude writes it; `navigate` events surface a link the record missed, nothing else checks |
| A skin is presented as a lookalike, never as the library | **recorded** — the skin files and the panel label say it; nothing checks a reply repeats it |
| The hook injects only whole events, advances the cursor no further than the last one printed, and stays silent for `/theme-design:` prompts | **gate** — the same harness runs `hooks/pending-events.sh` against a live-pid fixture (skipped without `jq`, which is also when the hook itself is silent) |
| The hook is silent without a running session | **recorded** — the dynamic budget baseline records its silent cost; nothing else reads it |
| A gesture is applied faithfully to source, replies are one line, tokens over inline styles | **agent-graded** — the reply and the reload are the review; nothing scripts it |
| Contrast and light/dark completeness at export | **recorded** — the skill instructs the check; no script runs it |

## Limits, stated

- The panel header says **listening** while the session is blocked on the poll and
  **away** otherwise. Away is not broken: what you send is kept and applied when
  the session polls again — or, if you type a prompt in the terminal that runs
  the session, the hook drains it into that turn. That terminal must be in the
  project that holds `.theme-design/`; a session driving another project's root
  from elsewhere never sees the hook.
- Editor changes are preview only until Claude writes them; the page reloads from disk.
- Selectors are heuristics (`#id`, `data-td`, class + `nth-of-type`). Framework-hashed
  classes in `proxy` mode can defeat them; Claude asks for the component name.
- `proxy` mode carries no websockets: Vite/Next HMR disconnects behind it, the page
  keeps working, Claude's `reload:true` is the refresh. Cross-origin iframes inside the
  app are not editable.
- Loopback only; one session per project root; nothing is published. The URL dies
  with `--stop`.
- Not a component renderer: for variants built from a project's own components, use
  `/design-lab:preview`; for colour-only theming with candidates, `/ui-ux:theme`.

## Pairs well with

Three plugins emit a theme or a preview; the line between them is who drives, stated
here and in the other two (recorded — no lane edge, no script reads it):

- **ui-ux** — `/ui-ux:theme` is candidate-driven colour theming: it proposes, you pick.
  This plugin is session-driven direct manipulation on one surface: you gesture, the
  session applies. Both emit CSS variables; `/theme-design:export write` merges into
  the same project theme file `/ui-ux:theme` writes, diff shown first.
- **design-lab** — `/design-lab:preview` renders variants from the project's own
  components. A running session here (`.theme-design/` present) owns the preview surface
  and design-lab's fallback table hands the decision to it.
- **craft-suite** — the design bundle carries this plugin since 0.5.0.
