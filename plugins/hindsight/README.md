# hindsight

Reads your past sessions and tells you what kept going wrong. A SessionEnd hook records
cheap friction stats for every ended session and every subagent it spawned, in a file on
this machine (the ledger). `/hindsight:harvest` ranks the worst unmined transcripts with a
script, mines each with a read-only agent, and proposes CLAUDE.md rules, memory entries,
lint/CI checks, skill ideas, failed-approach warnings, and defects against the plugin
artifact that was running. Nothing is applied without your explicit approval.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install hindsight@cc-plugins-marketplace
```

## Use

| Invocation | What it does |
|---------|--------------|
| `/hindsight:harvest` | Mine the top 5 unmined transcripts of this project by friction score |
| `/hindsight:harvest 12` · `all` | Mine the top 12, or every candidate |
| `/hindsight:harvest since 7 days` | Only transcripts that ended in the last 7 days |
| `/hindsight:harvest all projects` | Every project on this machine. It reads other repositories' session history, so it runs only when you ask for it in so many words |

`/hindsight:harvest` is the skill's name; the plugin ships no command file.

Beside the host: for auditing a CLAUDE.md that already exists, use Claude Code's
`/doctor prompt-audit` (2.1.283+). This plugin dropped its own audit command in 0.13.0.
The host deletes transcripts after `cleanupPeriodDays` (default 30); a harvest can only
read what is still on disk.

## How it works

1. **Collect (automatic)** — on every SessionEnd, a fail-silent hook parses the
   session transcript and appends one stats row (`turns`, `user_msgs`, `errors`,
   `friction_events`, timestamps) to the ledger, then one more row per subagent
   transcript under `<session_id>/subagents/`, tagged `kind:"agent"` with the
   `agent_type` from its `.meta.json`. Malformed transcripts, missing `jq`, or
   unreadable files never produce errors or block session end; a session with hundreds
   of agents may hit the hook timeout, which loses the tail of the agent rows and
   never the session row.
2. **Select (script)** — `scripts/select.sh` prints the unmined transcripts, ledger rows
   first by `3 × friction_events + 2 × errors + turns`, then transcripts the hook never
   recorded, newest first. One row per conversation: a resumed session is one row and a
   fork folds into its longer copy. Deleted transcripts are dropped and counted.
3. **Mine (on demand)** — one read-only `transcript-miner` agent per selected transcript.
   Findings are clustered under a two-session recurrence gate: a proposal needs evidence
   from at least two sessions; a single-session pattern is listed as a candidate.
4. **Apply (on approval)** — approved rules go to one of four homes: a repo-binding rule
   appends to CLAUDE.md; a rule about how *you* want to be worked with becomes a
   `feedback` entry in Claude Code's own memory at `~/.claude/projects/<slug>/memory/`;
   a finding about the codebase becomes a note in `brain/<area>.md` when the brain
   plugin's map exists; a mechanical correction becomes a proposed check in the linter,
   pre-commit hooks or CI the repo already runs, printed for you to apply and never
   written. Ideas hand off to a `/new-skill` or `/new-plugin` project skill when the
   project has one. Warnings land in `.claude/hindsight/anti-patterns.md`.
5. **Mark (script)** — `select.sh --mark` flags every mined transcript in the ledger, so
   the next harvest does not offer it again.

Credit: the proposed-check destination in `harvest` adapts a rule from
mattpocock/skills v1.2.3 (MIT, © 2026 Matt Pocock), rewritten here rather than copied.

## What has teeth

| Rule | Standing |
|---|---|
| Ranking, one row per conversation (resumes and forks folded), mined and deleted transcripts dropped, `--mark` | **gate** in the marketplace repository: `scripts/__tests__/select.test.sh` |
| The session row and one row per subagent | **gate** there too: `scripts/__tests__/collect.test.sh` |
| Two-session recurrence before a proposal; the existing-coverage check; defect vs idea | **agent-graded** — the skill says so, no script checks a report |
| Other projects are read only on an explicit ask | **recorded** — `--all-projects` is a flag the skill is told to keep for that |
| An applied rule helped | **unenforceable** here. It takes an eval with a control arm; this plugin does not measure it. The before-and-after table earlier versions printed was removed in 0.13.0 because it could not tell apart rules applied together |

## Ledger

Stats live in `$HOME/.claude/hindsight/<slug>/ledger.jsonl` — **outside the
project tree**, beside nothing you have to gitignore. `<slug>` is the same one
Claude Code uses for `~/.claude/projects/`: the absolute working directory with
every non-alphanumeric character replaced by `-`. One JSON line per ended
session:

```json
{"v":1,"session_id":"...","ts_start":"...","ts_end":"...","turns":12,"friction_events":3,"errors":1,"user_msgs":9,"reason":"exit","transcript_path":"...","mined":false}
```

Agent rows carry the same fields plus `"kind":"agent"`, `"agent_id"`, and
`"agent_type"` (e.g. `code-review:code-reviewer`); a row without `kind` is a
session.

`friction_events` is a best-effort heuristic count of tool-result
error/rejection markers — it undercounts rather than crashes, and a session that
was quiet and wrong ranks low.

Reports are saved beside the ledger at `reports/YYYY-MM-DD.md`. The one file this
plugin writes into the project is `<project>/.claude/hindsight/anti-patterns.md`, and
only when you pick a warning at the apply gate (a brain note goes into the brain
plugin's committed `brain/` map, again only on a pick). That file is **team-shared and
must be committed** — a CLAUDE.md pointer references it. Do not ignore `.claude/`
wholesale: other plugins keep team files there too.

## Skill-use log

A second hook, `hooks/skill-use.sh`, appends one row per Skill-tool call to
`$HOME/.claude/hindsight/<slug>/skills.jsonl`. Nothing this plugin ships reads it. It
exists for the marketplace repository's `scripts/turn-cost.sh --skills`, which counts
which shipped skills ever fire. Turn it off with `CC_SKILL_LOG=off` or the `/config`
option; you lose nothing as an installer.

## Pairs with

- **brain** — a harvest destination: a codebase finding approved at the apply gate
  lands as a note in `brain/<area>.md` (or `brain/decisions.md`), only when
  `brain/INDEX.md` exists. Agent-graded; no script checks the routing.
- **stack-scan** (plugin-scout skill) — suggests hindsight per repo as an any-project
  core row.

## Contents

- **Hooks**, two: the SessionEnd stats collector (`hooks/collect.sh`) and the
  PostToolUse `Skill` invocation log (`hooks/skill-use.sh`); both bash + jq, fail-silent
- **Script**: `scripts/select.sh` — ranks unmined transcripts and marks mined ones
- **Skill**: harvest — select, fan out, recurrence gate, four-section report, apply gate
- **Agent**: transcript-miner — read-only per-transcript mining, compressed findings
