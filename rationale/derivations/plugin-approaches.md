# approaches hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the file named in the `##` heading, with only each comment's `# ` leader (and the indentation before it) removed; the lines the file kept are not repeated here. A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-approaches.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/approaches/hooks/compact-recovery.sh

### Header

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH.

SessionStart, matcher `compact` ONLY. Re-asserts the deliberation marker after a
compaction has taken the decision out of the model's context.

WHY THIS HOOK EXISTS. approach-deliberation's own SKILL.md says, under "Double-run
guard", "Check the MARKER, never memory" — a heading citation, not a line number,
because the line number here was 4 rows stale by 2026-09-15. The marker is
`.claude/approaches/deliberated.json` and
it survives compaction perfectly well. What does NOT survive is the model's
knowledge that a deliberation happened at all, so it never thinks to look. The
documented failure is a compacted session re-litigating a shape that was already
decided: the marker was on disk the whole time and nothing pointed at it.

WHY SessionStart AND NOT PreCompact. PreCompact is the intuitive choice and it
does not work: Claude Code writes PreCompact stdout to the debug log and never
adds it to the model's context. The documented exceptions are UserPromptSubmit,
UserPromptExpansion, SessionStart and PostModelSwitch. SessionStart is also the
event that carries a `compact` source, so it is both the only channel that
reaches the model and the only one that knows a compaction just happened.

WHY IT COSTS NOTHING IN THE COMMON CASE. The matcher is `compact`, so this is
silent on startup, resume, clear and fork. A session that never compacts never
pays. A session that compacts pays ~40 tokens once per compaction — set against
re-running a four-persona blind panel, which is what it prevents.

LIMITATION (honest scope):
  - Advisory. SessionStart stdout informs a turn; it cannot block one. If the
    model re-deliberates anyway, nothing here stops it.
  - It re-asserts THAT a decision exists and which task it was for. It does not
    restore the REASONING — the alternatives weighed, the kill-trigger. Those
    live in the transcript the compaction just summarized, and no hook can pull
    them back.
  - It cannot tell whether the marker's task is still the task in hand. A marker
    from an abandoned task is announced exactly like a live one for as long as it
    is inside the TTL below; the skill's own staleness rules still apply. What the
    TTL removes is only the UNBOUNDED case — a marker with no writer left alive
    announcing a decision forever, because nothing but this hook ever read it and
    nothing at all ever deleted it (AR 11, 2026-09-22).
  - Marker-shaped only. A deliberation that ran and never wrote the marker is
    invisible here, the same blind spot the skill already carries.

WHERE IT LOOKS: the project root (state-root block below), not the payload cwd. The
cwd follows the model's `cd` (finding 2, rationale/2026-09-25-session-plugin-usage-
review.md), so a compaction after `cd app/Models` looked for the marker in
app/Models/.claude/ and announced nothing. The message names the absolute path it
found, for the same reason.
```

### The source check

```text
Belt and braces: the hooks.json matcher already scopes this to compaction, but
a hand-edited settings.json could wire it without one.
```

### The TTL

```text
TTL, mtime, 120 minutes — the same number and the same mechanism as the shared
phase sentinel (templates/blocks/phase-guard.md, cc_phase_ttl_min), deliberately,
because the two files have the same shape of problem: prose writes them, nothing
deletes them, and a silent reader that trusts a dead one has no remedy. mtime, not
a timestamp field: portable shell cannot parse ISO-8601, and the file is rewritten
whenever a new deliberation lands, so mtime IS the decision's age.

Past the TTL: IGNORE and DELETE. Deleting is the point — leaving it would re-run
this find on every compaction of every future session for a decision nobody can
still act on. Expiring early degrades to today's pre-hook behaviour (the model
re-deliberates, which is a cost in tokens); expiring late re-asserts a decision the
session has moved past, which is a cost in WRONG WORK. The two are not symmetric,
so this errs toward forgetting.
```
