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
| `/theme-design:init [html \| proxy <url>] [brief]` | Start or resume a session. `html` serves standalone prototypes under `.theme-design/pages/` driven by one `tokens.css`; `proxy` overlays the editor on your running dev server and edits go to project source. No mode given: detects a dev server and asks once |
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

## What each gesture becomes

| in the panel | Claude does |
|---|---|
| chat message (with an element selected) | the request, scoped to that element |
| drag and drop on a sibling | reorders the DOM; a drop with no target becomes a layout change in that direction, never `position:absolute` |
| corner-handle resize | width, column span, basis, padding or aspect, by the element's role, said in the reply |
| colour pick | the nearest token in `tokens.css`, or a new one under both `:root` and `.dark` |
| double-click text edit | verbatim content change |
| note on an element | a brief scoped to it |
| End session | export, then stop |

Three picks on one axis in a row make Claude offer candidates side by side instead
of a fourth single reveal. The full contract is
`skills/design-session/references/event-protocol.md`.

## What has teeth and what is recorded

| claim | standing |
|---|---|
| The bridge: seq-ordered events, single delivery through the cursor, editor injection, CSRF header on every mutation, traversal refusal, SSE reply and reload, proxy injection and `Location` rewrite, `--status`/`--stop` | **gate** — `scripts/__tests__/serve.test.sh`, run by CI's plugin-harness step |
| The hook is silent without a running session and injects with one | **gate** — same harness step exercises `hooks/pending-events.sh` only by inspection; the dynamic budget baseline records its silent cost |
| A gesture is applied faithfully to source, replies are one line, tokens over inline styles | **agent-graded** — the reply and the reload are the review; nothing scripts it |
| Contrast and light/dark completeness at export | **recorded** — the skill instructs the check; no script runs it |

## Limits, stated

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
