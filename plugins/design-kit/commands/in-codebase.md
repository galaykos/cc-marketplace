---
description: Render a design with the project's OWN components on its OWN dev server — from a brief, a board, or a Claude Design handoff bundle — behind a consent gate, with token drift measured and every scratch file removed after the pick
argument-hint: "[brief | board.html#board=N | <handoff-bundle-dir>]"
---

Render `$ARGUMENTS` in this codebase. Invoke the `in-codebase` skill and follow it
exactly — it owns the rules for finding real components, the consent gate, the drift
table and the cleanup contract. Every script call goes through
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh"`; run `dk.sh check` first and repeat its line.

Resolve the argument first:

- **Nothing** → the latest unread pick: `dk.sh decision --latest --consume`. Its prose
  names the board, the artboard, the knob values and the text edits — every line is a
  requirement. Exit 3 means no pick is waiting: say so and ask for a brief or a board.
- A path to a directory holding at least one `.html` and a README or chat file →
  **handoff bundle**: run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/handoff-drift.py" <dir>`
  before anything else and put the table in front of the user.
- `<file>.html#board=N` → a board from `/design-kit:design`: read that artboard
  for structure and copy (`dk.sh decision --board <file>` reads its recorded edits too).
- Anything else → a brief.

Then, in order: `dk.sh scratch --detect`; consent via AskUserQuestion once per session —
say what the choice buys before offering it: the scratch entry is a few throwaway files
written into the project tree under `__design-kit__/` paths and removed after the pick, so
the design renders on the project's own dev server with its own components. Labels:
"Write the scratch entry (Recommended)" / "Show me the plan only". No write before the
first is chosen. Then
`dk.sh scratch --create <slug> --brief "<one line>"` (the brief seeds the variant strip; omitted, the workshop's brief is used); fill only the printed files with real components;
open the printed URL; iterate; after the pick `dk.sh scratch --cleanup` then
`dk.sh scratch --verify`, unless the user says keep — then say in one line that
`__design-kit__` paths remain. Record what rendered the pick:
`dk.sh decision --record "<board/brief>, artboard N, components: …, gaps: …"`.

Reply with: the stack detected, the components and variants used, the drift table
(bundle mode) with each `no token` row's resolution, gap rows, the cleanup verdict.
