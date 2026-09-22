---
description: Render a design with the project's OWN components on its OWN dev server — from a brief, a board, or a Claude Design handoff bundle — behind a consent gate, with token drift measured and every scratch file removed after the pick
argument-hint: "[brief | board.html#board=N | <handoff-bundle-dir>]"
---

Render `$ARGUMENTS` in this codebase. Invoke the `in-codebase` skill and follow it
exactly — it owns the rules for finding real components, the consent gate, the drift
table and the cleanup contract.

Resolve the argument first:

- A path to a directory holding at least one `.html` and a README or chat file →
  **handoff bundle**: run `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/handoff-drift.py <dir>`
  before anything else and put the table in front of the user.
- `<file>.html#board=N` → a board from `/design-kit:design`: read that artboard
  for structure and copy.
- Anything else → a brief.

Then, in order: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/codebase-scaffold.sh --detect`;
consent via AskUserQuestion ("Write the scratch entry (Recommended)" / "Show me the
plan only") once per session; `--create <slug>`; fill only the printed files with
real components; open the printed URL; iterate; after the pick run
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/codebase-cleanup.sh` then `--verify`, unless the
user says keep — then say in one line that `__design-kit__` paths remain.

Reply with: the stack detected, the components and variants used, the drift table
(bundle mode) with each `no token` row's resolution, gap rows, the cleanup verdict.
