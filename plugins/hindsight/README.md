# hindsight

Cross-session self-improvement loop: a SessionEnd hook records cheap friction
stats for every ended session into a project-local ledger, and `/hindsight:harvest`
mines the worst offenders' transcripts for recurring friction — proposing
CLAUDE.md rules, skill/plugin ideas, and failed-approach warnings. Nothing is
applied without your explicit approval.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install hindsight@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/hindsight:harvest [N\|all]` | Mine the top N unmined sessions (default 5) ranked by friction score; rank raw transcripts from `~/.claude/projects/<slug>/` when no ledger row exists. Reports a friction stats digest, CLAUDE.md rule candidates, skill/plugin ideas, and failed-approach warnings — inline and saved to `.claude/hindsight/reports/YYYY-MM-DD.md` — then gates every application behind a per-category multiselect |

## How it works

1. **Collect (automatic)** — on every SessionEnd, a fail-silent hook parses the
   session transcript and appends one stats row (`turns`, `user_msgs`, `errors`,
   `friction_events`, timestamps) to the ledger. Malformed transcripts, missing
   `jq`, or unreadable files never produce errors or block session end.
2. **Harvest (on demand)** — `/hindsight:harvest` picks the highest-friction
   unmined sessions from the ledger, fans out one read-only `transcript-miner`
   agent per session, and synthesizes findings under a two-session recurrence
   gate: proposals need evidence from at least two sessions; single-session
   patterns are parked as candidates until corroborated.
3. **Apply (on approval)** — approved rules append to CLAUDE.md, ideas hand off
   to `/claude-authoring:new-skill` or `/claude-authoring:new-plugin`, warnings
   land in `.claude/hindsight/anti-patterns.md`. Nothing is written without an
   explicit pick.

## Ledger

Stats live in `<project>/.claude/hindsight/ledger.jsonl` — one JSON line per
ended session:

```json
{"v":1,"session_id":"...","ts_start":"...","ts_end":"...","turns":12,"friction_events":3,"errors":1,"user_msgs":9,"reason":"exit","transcript_path":"...","mined":false}
```

`friction_events` is a best-effort heuristic count of tool-result
error/rejection markers — it undercounts rather than crashes, and low-signal
sessions simply rank low at harvest time.

**Gitignore only the machine-local state.** The ledger (absolute transcript paths,
per-machine session history) and per-run reports must not be committed — but the
curated `anti-patterns.md` is team-shared (a committed CLAUDE.md pointer references
it), so ignore the transient paths only, never `.claude/hindsight/` wholesale:

```gitignore
.claude/hindsight/ledger.jsonl
.claude/hindsight/reports/
```

## Contents

- **Hook**: SessionEnd stats collector (`hooks/collect.sh`) — bash + jq,
  fail-silent by design
- **Command**: `/hindsight:harvest` — ledger-first mining with raw-transcript
  fallback
- **Skill**: harvest — ranking, recurrence gate, four-section report, apply gate
- **Agent**: transcript-miner — read-only per-session mining, compressed findings
