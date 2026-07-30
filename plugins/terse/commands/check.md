---
description: Measure this session's turn-final messages against the active terse budget — prose lines per message, mean, max, percent over ceiling. Report-only, changes nothing.
argument-hint: "[--last N] [--session-file PATH]"
---

# /terse:check

Run the measurement script and report what it prints:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/measure.sh" $ARGUMENTS
```

It counts **turn-final** assistant messages — text with no tool call in the same
message — and scores each against the active level's report ceiling. A prose line
is ~100 rendered characters, so one long paragraph counts as several; tables, code
blocks and trees are free.

Report the three summary numbers (count, mean, max, percent over) and the per-message
rows. Then say **one** thing: whether the trend is inside budget, or which message
kinds are blowing it. No plan, no offer to fix, unless the user asks.

If the script cannot find a transcript, pass `--session-file` with the path from
`~/.claude/projects/<flattened-cwd>/` rather than guessing at the numbers.

Honest scope, state it if the numbers are used to argue anything: the script cannot
tell a work-done report from a short answer, so it grades everything against the
larger ceiling, and prose the user explicitly asked for counts the same as prose
nobody wanted.
