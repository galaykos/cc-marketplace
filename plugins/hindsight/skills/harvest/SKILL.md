---
name: harvest
description: Use when /hindsight:harvest runs or the user asks what keeps going wrong across PAST sessions. Recurring friction in session and subagent transcripts (corrections repeated, chores redone, fixes abandoned twice) is proposed as CLAUDE.md rules, memory entries and skill ideas on approval.
---

Deep mining happens here, on demand: the SessionEnd hook only collects cheap
stats, a script ranks the candidates, and every FINDING is read out of a
transcript. Nothing is written without an explicit user pick.

## Select

Run the selector; do not rank or parse the ledger by hand:

    bash "${CLAUDE_PLUGIN_ROOT}/scripts/select.sh" [--top N|all] [--since DAYS] [--all-projects]

- `$ARGUMENTS` maps straight on: a number or `all` is `--top` (default 5);
  "last week" or "since the 1st" is `--since <days>`.
- It prints one TSV row per unmined transcript — `score kind agent_type ts_end
  transcript` — ledger rows first by `3 × friction_events + 2 × errors + turns`,
  then transcripts the hook never recorded (`score` is `-`), newest first. A
  resumed session is one row, and a forked session folds into the copy that
  ranks highest, so each row is a distinct conversation. A transcript the host already deleted is dropped
  and counted on stderr; carry that count into the report.
- `kind` is `session` or `agent`. An agent row is a subagent transcript, and
  `agent_type` is the spawned name, e.g. `code-review:code-reviewer`.
- **Current project by default.** Pass `--all-projects` only when the user asks
  for every project in so many words: it reads other repositories' session
  history. Standing: recorded — the flag is the only thing between the two.

Data, for reference: the ledger is `$HOME/.claude/hindsight/<slug>/ledger.jsonl`,
transcripts are `~/.claude/projects/<slug>/*.jsonl` and
`<session_id>/subagents/agent-*.jsonl`; `<slug>` is the absolute cwd with every
non-alphanumeric character replaced by `-`. The host deletes transcripts after
`cleanupPeriodDays` (default 30), so a harvest older than that has nothing to read.

## Fan out

Dispatch one `transcript-miner` agent per selected row, in parallel, at most 20
to a message (the host rejects launches past 20 running subagents). Each miner is read-only and returns compressed findings:
corrections the user gave, repeated chores, failed fix attempts, and the context
around friction events. Pass each agent its transcript path and the row's
`kind` — never load raw transcripts into the main context. For an agent row,
also pass `agent_type` and say it is a subagent transcript: its "user" turns are
the orchestrator's dispatch prompt, so a correction there is a re-dispatch, not
a human redirect. A miner failing on one transcript does not abort the harvest;
record the failure and continue.

## Synthesize

- Dedupe and cluster findings across sessions: the same correction
  phrased differently, the same chore repeated, the same fix attempted
  and abandoned twice — each cluster keeps its source session ids.
- Recurrence gate: propose a CLAUDE.md rule or a skill/plugin idea only
  when the cluster has evidence from ≥2 distinct sessions. A single-session
  pattern is listed under the report's digest as a candidate, not proposed.
- Existing-coverage check, before any proposal reaches the report: grep
  the project's CLAUDE.md, the installed skills' descriptions, and `brain/`
  when it exists for the rule the candidate states — and, for a fixed pattern,
  the lint config and CI workflows for a check that already enforces it.
  Already covered → report it as a routing or
  compliance gap ("the rule exists at X and was not followed"), never as
  a new rule — the approving user otherwise sees evidence FOR the rule
  and no evidence it already exists, which is how duplicates accumulate.

## Report

Produce exactly four sections:

1. **Friction stats digest** — transcripts mined, top friction contexts,
   single-session candidates, plus any dropped or failed transcripts. When agent
   rows were mined, add a per-`agent_type` line (rows, findings) — attribution
   of WHERE friction landed, not proof of what caused it.
2. **CLAUDE.md rule and check candidates** — one proposed rule line each,
   or the proposed check for a fixed pattern (apply gate, Rules), backed
   by evidence quotes from ≥2 sessions with session ids.
3. **Skill/plugin ideas and defects** — recurring chores or missing capabilities
   worth capturing, each with its cross-session evidence. When a cluster's
   evidence comes from agent rows whose `agent_type` carries a `plugin:`
   prefix, or from a session where a named plugin's hook or skill was active,
   name the artifact (`<plugin>/agents/<name>.md`, the hook, the skill) and
   file it as a **defect** against it, not as a new idea — and tier the
   evidence: *defect* (the artifact's own rule or tool was active and failed; a
   transcript quote is enough), *recurrence* (≥2 sessions; a proposal, with
   the control arm still owed). A change to a shipped plugin is not an
   improvement until an eval case built from the friction — prompt = the
   request, grader = the correction — fails without the artifact and passes
   with it.
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

- Rules → **four destinations, and the pick names which.** A rule that binds the
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
  note. When the correction is mechanical — the same call, import or path every
  time — prose asks the model to remember what a machine can refuse: propose the
  **check** instead, in the tool the repo already runs (its linter, its pre-commit
  hooks, its CI). When the existing-coverage check found that check configured
  but never invoked, wiring it is the proposal. On a pick, print the exact
  change — file and lines — for the user to apply, and write nothing. Standing:
  recorded — no script tells a fixed pattern from a judgement call. Offer the
  destination as part of the
  option's label; when the memory directory or `brain/INDEX.md` is not present,
  fall back to CLAUDE.md and say that is what happened. The recurrence gate
  applies to all four alike.
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

## Mark mined

After the report is shown, mark every transcript a miner read, including the
ones whose findings were all declined:

    bash "${CLAUDE_PLUGIN_ROOT}/scripts/select.sh" --mark <transcript> [<transcript> ...]

It sets `"mined": true` on every ledger row for that transcript and its forks, and
adds a row for one the hook never recorded, so the next harvest does not offer it again.
Do not edit the ledger by hand. A transcript whose miner failed stays unmarked.

## Boundaries

Never edits application code: outputs are CLAUDE.md lines, `feedback` memory
files under `~/.claude/projects/<slug>/memory/`, brain notes under `brain/`
(only when the brain plugin's map exists), files under
`$HOME/.claude/hindsight/<slug>/`, the project's `.claude/hindsight/anti-patterns.md`,
and the scaffold handoffs above. Never writes a lint config, pre-commit hook or CI
file: a proposed check is printed for the user to apply. No auto-apply — every write
passes the apply gate above. Whether an applied rule helped is not measured here:
that takes an eval with a control arm, not a before-and-after count. Transcript
JSONL is officially unstable: skip malformed lines, tolerate missing fields, never
hard-fail on format drift.
