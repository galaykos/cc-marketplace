---
name: harvest
description: Use when /hindsight:harvest runs, or the user asks what keeps going wrong across PAST sessions — recurring friction in session and subagent transcripts: corrections repeated, chores redone, fixes abandoned twice, proposed as CLAUDE.md rules, memory entries and skill ideas on approval.
---

Deep mining happens here, on demand: the SessionEnd hook only collects cheap
stats, so the ledger ranks candidates and every FINDING is read out of a
transcript. Nothing is written without an explicit user pick.

## Locate data

- Ledger: `$HOME/.claude/hindsight/<slug>/ledger.jsonl` — machine-local, not
  in the project tree. One JSON row per session, schema v1:
  `{"v":1, "session_id", "ts_start", "ts_end", "turns", "friction_events",
  "errors", "user_msgs", "reason", "transcript_path", "mined": false}`.
  The hook also writes one row per subagent the session spawned,
  same fields plus `"kind":"agent", "agent_id", "agent_type"` (`agent_type` is
  the spawned name, e.g. `code-review:code-reviewer`; `unknown` when the
  meta file was missing). A row without `kind` is a session.
- Transcripts: `~/.claude/projects/<slug>/*.jsonl`; agent transcripts under
  `~/.claude/projects/<slug>/<session_id>/subagents/agent-*.jsonl`, each with
  a sibling `.meta.json` naming `agentType`. `<slug>` is the same in both
  paths: the absolute cwd with every non-alphanumeric character replaced by
  `-`.
- A missing ledger is not an error — the fallback below covers projects
  where the hook never ran (pre-install history, jq-less machines).

## Rank and select

1. Parse the ledger, skipping malformed lines; keep rows where `mined`
   is false.
2. Score each unmined row with hardcoded v1 weights (no tuning):
   `3 × friction_events + 2 × errors + 1 × turns`. Higher scores first.
3. Fallback: list transcripts under the slug directory — session files and
   `*/subagents/agent-*.jsonl` alike — that have NO ledger row at all; rank
   those by recency plus file size (newer and larger first) and append them
   below the scored ledger rows. Agent rows compete in the same list as
   sessions by the same score; a session that fanned out many agents does
   not get a quota, and a low-friction agent simply ranks low.
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
transcripts into the main context. For an agent row, also pass
`agent_type` and say it is a subagent transcript: its "user" turns are the
orchestrator's dispatch prompt, so a correction there is a re-dispatch,
not a human redirect. A miner failing on one transcript
does not abort the harvest; record the failure and continue.

## Synthesize

- Dedupe and cluster findings across sessions: the same correction
  phrased differently, the same chore repeated, the same fix attempted
  and abandoned twice — each cluster keeps its source session ids.
- Recurrence gate: propose a CLAUDE.md rule or a skill/plugin idea only
  when the cluster has evidence from ≥2 distinct sessions.
- Existing-coverage check, before any proposal reaches the report: grep
  the project's CLAUDE.md, the installed skills' descriptions, and `brain/`
  when it exists for the rule the candidate states. Already covered → report it as a routing or
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
   skipped or failed transcripts. When agent rows were mined, add a
   per-`agent_type` line (rows, mean friction, mean errors) — attribution
   of WHERE friction landed, not proof of what caused it.
2. **CLAUDE.md rule candidates** — one proposed rule line each, backed
   by evidence quotes from ≥2 sessions with session ids.
3. **Skill/plugin ideas** — recurring chores or missing capabilities
   worth capturing, each with its cross-session evidence. When a cluster's
   evidence comes from agent rows whose `agent_type` carries a `plugin:`
   prefix, name the artifact (`<plugin>/agents/<name>.md`) and file it as
   a **defect** against it, not as a new idea — and tier the evidence:
   *defect* (the artifact's own rule or tool was active and failed; a
   transcript quote is enough), *recurrence* (≥2 sessions; a proposal, with
   the control arm still owed), *outcome* (section 0; correlational). A
   change to a shipped plugin is not an improvement until an eval case
   built from the friction — prompt = the request, grader = the correction
   — fails without the artifact and passes with it.
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

- Rules → **three destinations, and the pick names which.** A rule that binds the
  REPO — a convention, a command to run, a constraint any contributor inherits —
  is appended to the project's CLAUDE.md, where it is committed and reviewed in a
  PR. A rule that binds how THIS USER wants to be worked with — a correction they
  gave, an approach they confirmed — belongs in Claude Code's own memory instead:
  one file under `~/.claude/projects/<slug>/memory/` with `metadata.type:
  feedback`, the fact followed by its **Why:** and **How to apply:** lines, plus a
  one-line pointer appended to that directory's `MEMORY.md` index. It is
  machine-local and personal, so committing it to a shared CLAUDE.md would impose
  one person's preference on the team. A finding that describes the CODEBASE —
  where something lives, a trap in one specific module, a choice that was
  settled — is neither a rule nor a preference: when `brain/INDEX.md` exists
  (brain plugin), offer it as a **brain note**, one bullet appended under a
  `## Notes` heading in the `brain/<area>.md` whose `## Files` lists the module
  (`brain/decisions.md` for a settled choice; the area's `INDEX.md` line names it
  when unsure). It is committed and shared like the map; the indexer carries
  `## Notes` over verbatim, so tell the user no `/brain index` is needed after a
  note. Offer the destination as part of the option's label; when the memory
  directory or `brain/INDEX.md` is not present, fall back to CLAUDE.md and say
  that is what happened. The recurrence gate applies to all three alike.
- Ideas → hand each pick to a `/new-skill` or `/new-plugin` project skill
  (whichever fits the idea's size) when the project has one — the marketplace
  repository keeps both under `.claude/skills/`; else write the idea as a
  one-paragraph scaffold brief in the harvest output for manual capture.
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
`{"v":1,"ts":"<now, ISO-8601 UTC>","kind":"rule|note|idea|warning","text":"<the
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

Standing: recorded — current project only, never another slug's ledgers. Never edits
application code: outputs are CLAUDE.md lines, `feedback` memory files under
`~/.claude/projects/<slug>/memory/`, brain notes under `brain/` (only when the brain
plugin's map exists), files under
`$HOME/.claude/hindsight/<slug>/`, the project's `.claude/hindsight/anti-patterns.md`,
and the scaffold handoffs above. No auto-apply — every write passes the apply gate
above. Transcript JSONL is officially unstable: skip malformed lines, tolerate
missing fields, never hard-fail on format drift.
