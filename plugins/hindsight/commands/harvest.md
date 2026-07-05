---
description: "Mine session transcripts for cross-session friction — propose CLAUDE.md rules, skill/plugin ideas, and failed-approach warnings, applied only on approval."
---

# Harvest

Invoke the `harvest` skill from the hindsight plugin on `$ARGUMENTS` — a
session count or `all`, defaulting to the top 5 unmined sessions.

The pipeline: rank unmined sessions from `.claude/hindsight/ledger.jsonl`
by weighted friction score, falling back to raw transcripts in
`~/.claude/projects/<slug>/` (ranked by recency and size) when no ledger
row exists; fan out one read-only `transcript-miner` agent per selected
session in parallel; synthesize the compressed findings under a
two-session recurrence gate; report four sections — friction stats
digest, CLAUDE.md rule candidates, skill/plugin ideas, failed-approach
warnings — inline and saved to `.claude/hindsight/reports/YYYY-MM-DD.md`;
then gate every application behind an AskUserQuestion multiselect per
category. Nothing is written without an explicit pick.
