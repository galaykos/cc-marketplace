---
description: Open an interactive design session in the browser — chat, select, drag, resize, edit text and pick colours on HTML prototypes or on your running app, with Claude applying every gesture to real files until you export
argument-hint: [html | proxy <url>] [--skin wireframe|shadcn|bootstrap|mui|astryx] [what to design]
---

Start or resume a design-studio session for this project from $ARGUMENTS. Invoke
the `design-session` skill and follow it exactly: it owns mode resolution, the
`.design-studio/` seed, the server start, the opening reply, and the long-poll
loop you stay in until an `end` event, an export request, or a terminal prompt.

- A leading `html` or `proxy <url>` fixes the mode; `--skin <name>` picks the
  starting look (lookalikes of a library's defaults, never the library — see the
  skill's `references/skins.md`); anything after them is the opening brief (the
  first page in html mode, the first request in proxy mode).
- No mode given: detect a dev server and ask once, per the skill.
- `.design-studio/state.json` naming a live pid means a session is already open —
  print its URL, post a "resumed" reply, and enter the loop without restarting.

Print the URL in the terminal as soon as the server is up, then say nothing else
here until the loop ends; the conversation happens in the browser panel.
