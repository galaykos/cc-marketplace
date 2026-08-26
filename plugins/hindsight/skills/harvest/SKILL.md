---
name: harvest
description: Use when the user runs /hindsight:harvest or asks to mine PAST session transcripts for cross-session friction — fans out read-only transcript miners, applies a two-session recurrence gate, proposes CLAUDE.md rules and skill ideas on explicit approval.
---

## Purpose

Mine this project's Claude Code session history for recurring friction and
turn it into apply-on-approval proposals: CLAUDE.md rule candidates,
skill/plugin ideas, and failed-approach warnings, plus a friction stats
digest. Deep mining happens here on demand; the SessionEnd hook only
collects cheap stats. Nothing is written without an explicit user pick.

## Locate data

- Ledger: `$HOME/.claude/hindsight/<slug>/ledger.jsonl` — machine-local, not
  in the project tree. One JSON row per session, schema v1:
  `{"v":1, "session_id", "ts_start", "ts_end", "turns", "friction_events",
  "errors", "user_msgs", "reason", "transcript_path", "mined": false}`.
- Transcripts: `~/.claude/projects/<slug>/*.jsonl`. `<slug>` is the same in
  both paths: the absolute cwd with every non-alphanumeric character
  replaced by `-`.
- A missing ledger is not an error — the fallback below covers projects
  where the hook never ran (pre-install history, jq-less machines).

## Rank and select

1. Parse the ledger, skipping malformed lines; keep rows where `mined`
   is false.
2. Score each unmined row with hardcoded v1 weights (no tuning):
   `3 × friction_events + 2 × errors + 1 × turns`. Higher scores first.
3. Fallback: list transcripts under the slug directory that have NO
   ledger row at all; rank those by recency plus file size (newer and
   larger first) and append them below the scored ledger rows.
4. From the merged list pick the top 5 by default. `$ARGUMENTS` overrides
   the count: a number selects the top N; `all` selects every candidate.
5. Drop candidates whose transcript file no longer exists on disk and
   note each skip in the report's stats digest.

## Fan out

Dispatch one `transcript-miner` agent per selected session, all in
parallel in a single message. Each miner is read-only and returns
compressed findings: corrections the user gave, repeated chores, failed
fix attempts, and the context around friction events. Pass each agent
its transcript path and the session's ledger metadata — never load raw
transcripts into the main context. A miner failing on one transcript
does not abort the harvest; record the failure and continue.

## Synthesize

- Dedupe and cluster findings across sessions: the same correction
  phrased differently, the same chore repeated, the same fix attempted
  and abandoned twice — each cluster keeps its source session ids.
- Recurrence gate: propose a CLAUDE.md rule or a skill/plugin idea only
  when the cluster has evidence from ≥2 distinct sessions.
- Existing-coverage check, before any proposal reaches the report: grep
  the project's CLAUDE.md and the installed skills' descriptions for the
  rule the candidate states. Already covered → report it as a routing or
  compliance gap ("the rule exists at X and was not followed"), never as
  a new rule — the approving user otherwise sees evidence FOR the rule
  and no evidence it already exists, which is how duplicates accumulate.
- Single-session patterns are parked, not proposed: record each in the
  ledger as a candidate entry. When a later harvest finds corroborating
  evidence in another session, auto-promote the candidate to a full
  proposal in that harvest's report.

## Report

Produce exactly five sections:

0. **Outcome check** — run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/outcome.sh`
   and include its table verbatim: it grades PREVIOUS harvests' applied rules
   (mean friction/errors per session, before vs after each apply) from the
   ledger. Correlational only — the script says so itself; a "worsened" row is
   a candidate for retracting the rule in this harvest's apply gate.
1. **Friction stats digest** — sessions mined, total turns, friction
   events, errors, user messages, top friction contexts, plus any
   skipped or failed transcripts.
2. **CLAUDE.md rule candidates** — one proposed rule line each, backed
   by evidence quotes from ≥2 sessions with session ids.
3. **Skill/plugin ideas** — recurring chores or missing capabilities
   worth capturing, each with its cross-session evidence.
4. **Failed-approach warnings** — approaches tried and abandoned, with
   what worked instead when the transcripts show it.

Show the report inline AND save a copy to
`$HOME/.claude/hindsight/<slug>/reports/YYYY-MM-DD.md` (today's date,
creating the directory if needed; a same-day re-harvest overwrites the
file). Reports are machine-local, beside the ledger — never in the project.

## Apply gate

Ask via AskUserQuestion with multiSelect, one question per non-empty
category, each proposal a separate option and every question carrying a
"Skip this category" option. On approval only:

- Rules → append the picked lines to the project's CLAUDE.md.
- Ideas → hand each pick to `/claude-authoring:new-skill` or
  `/claude-authoring:new-plugin` (whichever fits the idea's size) when
  claude-authoring is installed; else write the idea as a one-paragraph
  scaffold brief in the harvest output for manual capture.
- Warnings → write picks to `<project>/.claude/hindsight/anti-patterns.md` — the
  ONE project-tree file this plugin writes, and only on an explicit pick. It is
  team-shared, so it must be tracked, not gitignored, or the committed pointer
  below does not resolve for teammates. Everything else stays machine-local. Then
  propose exactly ONE pointer line for CLAUDE.md referencing that file — the
  pointer is itself an option, never auto-added.

Nothing is written without an explicit pick; declining every option is
a valid outcome and still counts as a completed harvest.

**Record every applied pick** (rules, ideas, warnings alike) so the next
harvest's outcome check can grade it: append one line per pick to
`$HOME/.claude/hindsight/<slug>/applied.jsonl` —
`{"v":1,"ts":"<now, ISO-8601 UTC>","kind":"rule|idea|warning","text":"<the
applied line>","sessions":[<source session ids>]}`. A pick applied but not
recorded is invisible to the loop — record at the moment of the write.

## Mark mined

- Set `"mined": true` on every ledger row whose session was processed,
  rewriting the ledger atomically (temp file, then move).
- For fallback-mined transcripts that had no ledger row, create one now,
  already marked `"mined": true`, populated best-effort from the
  transcript (unknown fields null, `"v":1` always present).
- Mining status updates even when the user declines all proposals — a
  session is mined once its findings have been reported.

## Boundaries

- Current project only — never mine other projects' slug directories or
  cross-project ledgers.
- Never edits application code: outputs are CLAUDE.md lines, files under
  `$HOME/.claude/hindsight/<slug>/`, the project's
  `.claude/hindsight/anti-patterns.md`, and claude-authoring handoffs,
  nothing else.
- No auto-apply — every write passes the apply gate above.
- Transcript JSONL format is officially unstable; read defensively —
  skip malformed lines, tolerate missing fields, never hard-fail on
  format drift.
