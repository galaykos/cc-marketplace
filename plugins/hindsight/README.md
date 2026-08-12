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
| `/hindsight:harvest [N\|all]` | Mine the top N unmined sessions (default 5) ranked by friction score; rank raw transcripts from `~/.claude/projects/<slug>/` when no ledger row exists. Reports a friction stats digest, CLAUDE.md rule candidates, skill/plugin ideas, and failed-approach warnings — inline and saved to `$HOME/.claude/hindsight/<slug>/reports/YYYY-MM-DD.md` — then gates every application behind a per-category multiselect |

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

Stats live in `$HOME/.claude/hindsight/<slug>/ledger.jsonl` — **outside the
project tree**, beside nothing you have to gitignore. `<slug>` is the same one
Claude Code uses for `~/.claude/projects/`: the absolute working directory with
every non-alphanumeric character replaced by `-`. One JSON line per ended
session:

```json
{"v":1,"session_id":"...","ts_start":"...","ts_end":"...","turns":12,"friction_events":3,"errors":1,"user_msgs":9,"reason":"exit","transcript_path":"...","mined":false}
```

`friction_events` is a best-effort heuristic count of tool-result
error/rejection markers — it undercounts rather than crashes, and low-signal
sessions simply rank low at harvest time.

**There is nothing to gitignore.** The ledger and the per-run reports are
machine-local by construction — absolute transcript paths and per-machine session
history were never project artifacts, so they live under `$HOME` and no longer
create a directory inside your project.

The one file this plugin writes into the project is
`<project>/.claude/hindsight/anti-patterns.md`, and only when you explicitly pick a
warning at the apply gate. That one is **team-shared and must be committed** — a
CLAUDE.md pointer references it, and ignoring it breaks the pointer for teammates.
Do not ignore `.claude/` wholesale to be safe: other plugins keep team files there
too, e.g. plugin-scout's `--persist` writes `.claude/settings.json`.

**Upgrading from a project-local ledger?** Nothing is migrated. An existing
`<project>/.claude/hindsight/ledger.jsonl` is simply no longer read — harvest falls
back to ranking raw transcripts from `~/.claude/projects/<slug>/`, which is the same
path it already used for pre-install history, so the first harvest after upgrading
still has data to work with. The old directory is safe to delete.

## The loop is now closed (0.5.0)

The ledger always held the data to grade an applied rule and nothing read it back.
Now: every apply-gate pick is recorded to `applied.jsonl`, and each harvest opens by
running `scripts/outcome.sh` (fixture harness in CI) — mean friction/errors per
session, before vs after each applied rule, with a hard ≥3-sessions-per-side floor
before any number is shown. Standing: the computation is mechanical; the attribution
is correlational and the script prints that caveat with every table — a "worsened"
row is a retraction candidate, not a verdict.

## Contents

- **Hook**: SessionEnd stats collector (`hooks/collect.sh`) — bash + jq,
  fail-silent by design
- **Command**: `/hindsight:harvest` — ledger-first mining with raw-transcript
  fallback
- **Skill**: harvest — ranking, recurrence gate, four-section report, apply gate
- **Agent**: transcript-miner — read-only per-session mining, compressed findings
