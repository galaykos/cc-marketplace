# hindsight hooks and scripts: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the files named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-hindsight.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/hindsight/hooks/collect.sh

### Header

```text
Absolute-path shebang (not `env bash`): the fail-silent guarantee must hold
even with a stripped/broken PATH, where `/usr/bin/env bash` itself exits 127
with stderr noise before this script ever runs.
Fail silent: never block or noise SessionEnd (D14). Appends one cheap-stats
row per ended session to $HOME/.claude/hindsight/<slug>/ledger.jsonl — machine-local,
never inside the project tree (D2, D4-D6).
Transcript JSONL format is officially unstable (D13) — every parse is
defensive and prefers undercounting over crashing.

Subagents (0.9.0): every agent the session spawned left its own transcript at
<transcript_path minus .jsonl>/subagents/agent-<id>.jsonl with a sibling
.meta.json naming its agentType. Those are the only record of what an agent
hit, and no other channel reaches them: turn-cost.sh calls subagent turns
invisible for exactly this reason. One row per agent, same stats, tagged
kind:"agent" so readers that predate the tag (outcome.sh's per-session means)
can filter them out; rows without kind are sessions. Dedup by agent_id keeps a
resumed session's second SessionEnd from re-appending the same agents. A
session with many agents can outrun the hook timeout — the session row is
written FIRST and each agent row is one append, so a timeout loses only the
tail of the agents, never the session, and never noises the exit.
```

### stats_prog

```text
One pass over a transcript: keep raw lines for marker greps and
parsed lines (malformed ones silently dropped) for structural counts.
Shared by the session and every agent transcript below.
```

### The ledger directory

```text
Machine-local state lives under $HOME, never in the project tree. The ledger holds
absolute transcript paths and per-machine session history, so it was never a project
artifact — and creating a directory inside every project this hook runs in is a cost
the plugin should not impose. $HOME is read explicitly: `~` does not expand under a
stripped environment, and an unset HOME exits 0 like every other failure here. The
slug is the same rule Claude Code uses for its projects dir — the absolute cwd with
every non-alphanumeric character replaced by '-' — so a project's ledger and its
transcripts sit under matching names.
```

## plugins/hindsight/hooks/skill-use.sh

### Header

```text
Absolute-path shebang (not `env bash`): the fail-silent guarantee must hold
even with a stripped/broken PATH, where `/usr/bin/env bash` itself exits 127
with stderr noise before this script ever runs.

PostToolUse on Skill. Appends one row per skill INVOCATION to
$HOME/.claude/hindsight/<slug>/skills.jsonl — machine-local, never inside the
project tree, same slug rule and same fail-silent contract as collect.sh.

WHY. This marketplace ships ~100 skills against roughly four real gates, and
every removal it has ever made was argued from description tokens and trigger
overlap because nothing recorded which skills a session actually used. The
skill-router's own state file (route.sh's fired-<sid>.json) knows what was
OFFERED and is deleted at SessionEnd; nothing knew what was INVOKED. The
sentence "this skill was invoked zero times in 200 sessions and costs 60
always-on tokens forever" is the only sentence that can shrink a marketplace,
and it needs this row to be writeable.

HONEST LIMITATIONS, stated because the four laws require it:
  - It proves INVOCATION, never usefulness. A skill invoked 200 times may still
    be restating what the model already knew; only a control/treatment run
    settles that. This is the denominator, not the verdict.
  - Machine-local and single-user. It is not telemetry about anyone else, it
    never leaves the machine, and CC_SKILL_LOG=off disables it outright.
    CC_SKILL_LOG unset: the /config option cc_skill_log decides.
  - It depends on the harness naming this tool `Skill`. If that changes, the
    matcher silently records nothing — the failure mode is an empty file, which
    reads identically to "nothing was used". Check the file exists before
    concluding a skill is unused.
  - Nothing reads it automatically. /hindsight:harvest reports it on request,
    which keeps hindsight's collect → harvest → apply-on-approval contract
    intact: no file in a user's repo is ever written from this data.
```

### The skill name

```text
The skill name lives in the tool input; accept both the documented field and
the plugin-qualified form without caring which, since either identifies it.
```

### The slug

```text
slug: the same rule Claude Code uses for its projects dir, and the same rule
hooks/collect.sh uses — one directory per project, shared with the ledger.
```

## plugins/hindsight/scripts/claude-md-check.sh

### Header

```text
claude-md-check.sh — the mechanical half of a CLAUDE.md audit: which of the
paths and scripts a CLAUDE.md names no longer exist.

Usage: claude-md-check.sh [repo-root]   (defaults to $PWD)
Finds: CLAUDE.md, .claude.md, .claude.local.md at any depth (node_modules,
       vendor, .git skipped). Prints per file: lines, bytes, then one row per
       stale reference — a backticked path that does not resolve from the repo
       root or the file's own directory, or a backticked `npm run X` /
       `composer X` / `make X` whose script target is not declared.
Exit 0 always — a report, not a gate. Nothing here is edited.

Residual (stated, per the has-teeth convention): only BACKTICKED references are
read, and only three script runners are resolved. A path written in prose, a
command with a variable in it, or a runner not listed is not checked and not
reported as clean — it is simply not seen. Currency of ARCHITECTURE prose
(a described module boundary that moved) is judgment, left to the command.

A token that resolves neither from the repo root nor from the file's own
directory gets one more chance: if it exists ANYWHERE in the tree as a path
suffix (`plugin.json`, `references/`, `hooks/x.sh`), it is read as an
illustrative fragment, not a stale path. Measured 2026-09-10 on this
marketplace's own CLAUDE.md before the rule: 35 rows, 3 real. A bare
extension (`.md`) is skipped outright. The cost, accepted: a root-anchored
path that went stale while a same-named file lives elsewhere is not reported.
```

## plugins/hindsight/scripts/outcome.sh

### Header

```text
outcome.sh — closes the loop the ledger always had the data for: did an
applied hindsight rule actually move the numbers in later sessions?

Usage: outcome.sh [project-cwd]   (defaults to $PWD; slug derived like collect.sh)
Reads:  $HOME/.claude/hindsight/<slug>/ledger.jsonl   (written by the SessionEnd hook;
        rows tagged kind:"agent" are subagent transcripts and are skipped here — a
        session that fans out 90 reviewers would otherwise count as 91 sessions)
        $HOME/.claude/hindsight/<slug>/applied.jsonl  (written at harvest apply time)
Prints a per-rule before/after table. Exit 0 always — a report, not a gate.

Residual (stated, per the has-teeth convention): this is CORRELATION. Sessions
after an applied rule differ in more than the rule — different work, other
rules, model updates. A moved number is a hint about where to spend a real
control/treatment run (see skill-creator's eval loop), not proof the rule
worked. The honest minimum is printed with every table; MIN_N=3 sessions per
side before any number is shown at all.
```
