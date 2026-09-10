---
name: design-session
description: Use when a theme-design session is open or requested — /theme-design:init, "let's design the look", "prototype the screen", "move that card", "make the header bigger", a pending-browser-events line in a prompt — the live loop between the browser canvas and this session, in html-prototype or dev-server-proxy mode, until export or end.
---

## What this is

A design conversation held in the browser, driven by this session. The plugin's
server (`${CLAUDE_PLUGIN_ROOT}/server/serve.py`) serves a canvas with an editor
panel injected; the user chats and gestures there; you block on a long-poll,
apply what arrived to real files, post a one-line reply, and wait again. The
terminal is idle while the browser is in use, and the user may still type here;
the plugin's prompt hook then injects unconsumed events into that turn.

Two modes, chosen once at start and recorded in `.theme-design/state.json`:

| mode | canvas | you edit | reload |
|---|---|---|---|
| `html` | `.theme-design/pages/*.html` + `.theme-design/tokens.css` | those files | automatic on save |
| `proxy` | the project's dev server, proxied with the editor injected | the project's source | you post `reload:true` |

Read `references/event-protocol.md` before the first event: it is the contract
for every event shape and how each becomes an edit. `references/export-targets.md`
is the end of the session; do not read it before then.

## Start

1. Resolve the mode. `$ARGUMENTS` naming `html` or `proxy <url>` decides; else
   detect a dev server (`package.json` scripts with `dev`/`start`, a `.env` port,
   `lsof` on 3000/5173/8000/8080) and offer ONE AskUserQuestion:
   "Standalone HTML prototypes (Recommended for a new look)" / "Your running app at
   <url> with the editor overlaid". No dev server found and no URL given → `html`,
   said in one line.
2. Seed `.theme-design/` if absent: `mkdir -p .theme-design/pages`, copy
   `assets/tokens.css` (relative to this skill) to `.theme-design/tokens.css`. In
   `html` mode with no pages, build `pages/index.html` from `assets/page-shell.html`
   and the user's opening description before opening the browser — an empty canvas
   invites a chat about nothing. Suggest `.theme-design/` for `.gitignore` once; the
   user decides whether decisions are tracked.
3. Start the server in the background, port `${THEME_DESIGN_PORT:-8140}`:
   `python3 "${CLAUDE_PLUGIN_ROOT}/server/serve.py" --root .theme-design --mode html --open`
   (or `--mode proxy --proxy <url> --open`). `--status` reports a live session;
   `--stop` ends one. A refused start names the pid holding the root — do not
   kill a session another terminal owns without asking.
4. Post the opening line so the panel is not blank:
   `curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"text":"…"}' http://127.0.0.1:$PORT/__td/reply`
   Then print the URL in the terminal and enter the loop.

## The loop

```bash
curl -s --max-time 295 "http://127.0.0.1:${THEME_DESIGN_PORT:-8140}/__td/next?timeout=280"
```

Run it with the Bash tool's timeout at 300000 ms. `[]` means nothing happened;
call it again without commentary. A batch is a JSON array, oldest first, already
marked consumed — apply it as one turn:

1. Read every event before editing. A `select` followed by a `message` is one
   intent ("this element" + "do this"); a `move` then `move` on the same selector
   is the last position, not two edits.
2. Make the gesture real in source, per the protocol table. Colour, radius,
   spacing and type gestures go to `tokens.css` when the element's value came
   from a token, and to the element only when the user said "just this one".
   Layout gestures edit the page (or the component in proxy mode). Never leave a
   change as an inline `style=""` the editor previewed: the preview vanishes on
   reload and the user reads that as "Claude ignored me".
3. In `proxy` mode locate the source for a selector by grepping the class names
   and visible text from the event; when two files match, ask in the reply
   rather than editing both. After editing, post `reload:true`.
4. Reply in ONE line through `/__td/reply` — what changed and, when you chose
   between readings, which one. Questions go there too; the answer arrives as
   the next `message` event. The transcript is the server's, not yours to keep.
5. Append one line per accepted change to `.theme-design/decisions.md`
   (`- <date> <page or file>: <what> — <why the user said>`); the export reads it.
6. Wait again. Stop looping on an `end` event, on a message that says export or
   stop, or when the user types in the terminal (Esc interrupts the wait).

Batch size is the user's pace: never reply "applying…" and then apply; the reply
IS the signal that the reload they see is finished.

## Judgement calls the protocol cannot make

- A `move` with no `drop` target is a coordinate delta. Translate it into the
  layout the page already uses (grid order, flex order, a margin), never into
  `position:absolute` — the user dragged to say "over there", not "off the flow".
- A `resize` on a flex or grid child changes the track or the basis; on a card it
  changes padding or max-width; on an image it changes the aspect ratio. Say
  which you did.
- A `style` colour pick maps to the nearest token; when none is near, propose a
  new token name in the reply and add it in `tokens.css` under both `:root` and
  `.dark` — a light-only value is half a decision.
- A `text` edit is content; write it verbatim and do not "improve" it.
- An `annotate` is a brief for that element; treat it as a message scoped there.
- Three gestures on one axis in a row (colour, colour, colour) mean the axis is
  unsettled: offer two or three candidates side by side on one page in `html`
  mode instead of a fourth single reveal.

## Ending

On `end`, or `/theme-design:export`, follow `references/export-targets.md`, then
`python3 "${CLAUDE_PLUGIN_ROOT}/server/serve.py" --root .theme-design --stop`
only if this session started the server. Report the URL is gone, where the
exports were written, and how to resume (`/theme-design:init` reuses the root).

## Standing and limits

- **Recorded, not gated:** everything in this file. The server harness
  (`scripts/__tests__/serve.test.sh`) proves the bridge contract; nothing checks
  that a gesture was applied faithfully — that is the reply's job, and the user
  sees the reload.
- The editor's live changes are preview only. The page reloads from disk.
- Selectors are heuristics (`#id`, `data-td`, class + `nth-of-type`). In `proxy`
  mode a framework-hashed class can defeat them; ask for the component name.
- `proxy` mode cannot carry websockets: Vite/Next HMR disconnects behind it and
  the page keeps working; your `reload:true` is the refresh. Cross-origin
  iframes inside the app are not editable.
- Loopback only, one root per session, state-changing routes need the
  `X-Theme-Design` header. Nothing is published; the URL dies with `--stop`.
- One session per project root. A second `init` reports the first's pid.
