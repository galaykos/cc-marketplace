---
description: Measure this session's transcript against the six candour axes — unresolved citations, unevidenced reversals, flattery, apologies, defensiveness, emotion. Report-only.
argument-hint: "[--session-file PATH] [--last N] [--examples N]"
---

# /candor:check

Run the scan and report what it prints:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/candor-scan.sh" $ARGUMENTS
```

Report the table verbatim, then the examples for any axis with a non-zero count.
Read the examples before saying anything about a number — several axes match
quoted text, so a hit is a candidate, not a verdict.

Then say **one** thing: which axis is actually elevated for this session, and
whether the examples support it. No plan and no offer to fix unless asked.

If the two gated axes are non-zero, that is a live defect, not a style note: a
`file:line` that does not resolve was asserted and never read, and an unevidenced
reversal changed a position on pressure alone. Name the specific citation or the
specific turn — never the count on its own.

Honest scope, and state it if the numbers are used to argue anything:

- **The citation axis is backward-looking and the gate is not.** The scan resolves
  every historical citation against the tree as it is *now*, so a file since
  edited, renamed or deleted reports as unresolved even though the citation was
  true when it was written. Measured across 47 real transcripts and 3,848
  assistant messages: 168 unresolved citations, of which the recognisable
  majority were exactly that — `plugin-checks.sh:531` in a file that has since
  shrunk to 518 lines. Prefer `--last 40` for a reading about the current
  session, and open the file before calling any single hit a fabrication. The
  Stop gate has no such problem: it judges one message against the tree at the
  moment that message is sent.
- Citations resolve against the **transcript's own recorded `cwd`**, printed at
  the top of the report, not the shell's. If that directory no longer exists the
  scan falls back to `$(pwd)` and the citation counts become meaningless — check
  the printed root first.
- The four recorded axes are pattern counts with no judgement behind them. An
  apology the user asked for, a defensive phrase inside a quotation, and a
  legitimate `you're right` immediately after a tool call all count.
- Counts are per assistant message, not per occurrence — a message apologising
  four times counts once.
- `--last N` limits the window to the last N assistant messages; without it the
  whole transcript is measured, so a long session's early turns dominate.
- The scan never modifies anything and always exits 0. It is a measurement, not
  the gate; the gate is `hooks/gate.sh` and it runs on Stop whether or not this
  command is ever used.

If the script cannot find a transcript, pass `--session-file` with a path from
`~/.claude/projects/<flattened-cwd>/` rather than estimating the numbers by hand.
