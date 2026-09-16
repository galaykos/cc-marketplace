---
description: Measure this session's transcript — the six candour axes (unresolved citations, unevidenced reversals, flattery, apologies, defensiveness, emotion) and, when a terse level is active or --brevity is passed, turn-final prose lines against the level's budget. Report-only.
argument-hint: "[--session-file PATH] [--last N] [--examples N] [--brevity] [--tokens] [--all] [--since Nd]"
disable-model-invocation: true
---

# /candor:check

Two measurements, one command. Run the candour scan and report what it prints:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/candor-scan.sh" $ARGUMENTS
```

(Strip `--brevity`, `--tokens`, `--all` and `--since` before passing the rest;
the scan does not know them.)

Report the table verbatim, then the examples for any axis with a non-zero count.
Read the examples before saying anything about a number — several axes match
quoted text, so a hit is a candidate, not a verdict.

Then, **if a terse level is active** (`CC_TERSE` set, or
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode` exists) **or `--brevity` was
passed**, run the brevity measurement and report that too:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/measure.sh" $ARGUMENTS
```

(`--last N`, `--session-file`, `--tokens`, `--all`, `--since Nd` pass through;
drop `--examples` and `--brevity`.) It counts **turn-final** assistant messages —
text with no tool call in the same message — and scores each against the active
level's report ceiling. A prose line is ~100 rendered characters, so one long
paragraph counts as several; tables, code blocks and trees are free. Report the
summary numbers (count, mean, max, percent over) and the per-message rows.

Then say **one** thing per measurement: which candour axis is actually elevated
for this session and whether the examples support it; whether the brevity trend
is inside budget, or which message kinds are blowing it. No plan and no offer to
fix unless asked.

If the two gated candour axes are non-zero, that is a live defect, not a style
note: a `file:line` that does not resolve was asserted and never read, and an
unevidenced reversal changed a position on pressure alone. Name the specific
citation or the specific turn — never the count on its own.

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
- The brevity script cannot tell a work-done report from a short answer, so it
  grades everything against the larger ceiling, and prose the user explicitly
  asked for counts the same as prose nobody wanted.
- Neither script modifies anything; both always exit 0. They are measurements,
  not the gate; the gate is `hooks/gate.sh` and it runs on Stop whether or not
  this command is ever used.

If a script cannot find a transcript, pass `--session-file` with a path from
`~/.claude/projects/<flattened-cwd>/` rather than estimating the numbers by hand.
