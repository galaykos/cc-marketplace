# taskmaster: the comment text moved out of the code (2026-10-22)

The text under "Header until 0.50.0" was moved verbatim on 2026-10-22 from the file named in its `##` heading, with only each comment's `# ` leader removed; the lines the file kept are not repeated here. The sections after it are new on that day. A pointer by name was left in the file, `# Why, limits, history: rationale/derivations/plugin-taskmaster.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day they were written.

## plugins/taskmaster/hooks/clarify-gate.sh

### Header until 0.50.0

```text
Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
hold even under a stripped/broken PATH.

clarify-gate.sh — OPT-IN PreToolUse gate on Edit|Write|MultiEdit. OFF BY
DEFAULT: does nothing unless CC_CLARIFY_GATE=block is set. When enabled, it
denies the FIRST code write of a session in which remind.sh saw a work-shaped
prompt (the cc-workprompt marker), once per session, forcing one turn of
clarify-or-declare-trivial before code exists. The deny is the reflection
mechanism itself — the gate does not (cannot) verify a question round
actually happened; it buys one deliberate turn, nothing more. Standing when
enabled: gate. Standing when disabled (the default): unenforceable, and this
header says so on purpose.

Doctrine note: command-guard reserves deny for irreversible loss; a first
code edit is reversible, which is why this ships OFF and opt-in — the owner
chooses the stricter contract, it is not imposed. Under hands-off goal runs
the model should state assumptions instead of asking (see reason text).
Pattern: comment-discipline/hooks/scan.sh — the once-per-session bound is
recorded BEFORE the deny; a bound that cannot be recorded means no block.
Fail-open everywhere; CC_REMIND=off also silences it. Honest limitation:
hook input cannot distinguish main-session from subagent edits, so when the
main model's first move is to delegate, the one deny can land on a worker's
first write instead of the main session's.
CC_CLARIFY_GATE / CC_REMIND unset: the /config options cc_clarify_gate / cc_remind decide.
```

### Evidence, not a pause (2026-10-22)

```text
The reminder's line offered "or state in one line why this task is trivial enough to skip
it". The 2026-10-21 retro (rationale/session-retro-2026-10-21.md, finding 11 and row W2.5)
counted the directive firing 50 times in 30 days and being ignored, and the checker shipped
"default": "off". The old gate could not tell a session that had asked from one that had
not: it refused the first write of the session whatever had happened, once.

0.50.0 makes the round checkable. The reminder names two accepted forms, one batched
AskUserQuestion round or one line starting `Assuming:` that names what the model decided
for the user, and drops the trivial skip. The gate reads the transcript: an AskUserQuestion
tool call, or an assistant text line opening `Assuming:` (after optional spaces, `>`, `-`,
`*` or `_`), timestamped at or after the work-shaped prompt, lets the write through.
Neither refuses it, once. The deny is still the reversible-edit case the old doctrine note
withheld it from; what changed is that it now checks something, and that the advisory
alone was measured not to work.
```

### Prompt-scoped marker (2026-10-22)

```text
"Since that prompt" needs the prompt's time, and the marker was a bare directory that
remind.sh only ever created, so a work prompt answered with prose and followed by an
unrelated prompt kept the old marker armed. The reminder template (armsClarifyGate only)
now removes the marker on every human prompt past the frame test and creates it again on
a work-shaped one, so its mtime is that prompt's and a later prompt that is not
work-shaped disarms it. A harness frame (task notification, hand-back, /loop tick) and a
slash command exit before that point and leave the marker as it was. Measured on the
replay below: without the disarm, the first write after "I merged … review the latest
versions" (479f845f, 12:50) would have been judged against the marker that "create
PRs+Merge" left 14 minutes and two prompts earlier, and refused.

The gate spends the marker with rmdir before it judges, so a second write after a block,
or a parallel write, passes: one judgment per work-shaped prompt. A marker that cannot be
removed means no block, the scan.sh pattern the old header cites.
```

### Measured before the default changed (2026-10-22)

```text
Replay of the real hooks over transcripts under
~/.claude/projects/-mnt-data-Personal-git-repositories-cc-marketplace/: each human prompt
through remind.sh (the shipped classifier; the marker's mtime set to the prompt's
timestamp), each main-thread Edit/Write/MultiEdit through clarify-gate.sh with
CC_CLARIFY_GATE=block against the transcript cut at that write.

The three named transcripts (479f845f, f5492e65, 25f72aab): 3 work-shaped prompts, all in
479f845f; 1 reached a main-thread write while armed and would have been blocked
("Create a list of recommended changes …", first write a p0-quant.py under
taskmaster-docs/); 0 of those blocked were followed by an AskUserQuestion in the same
human turn. The other two work prompts were disarmed by the next human prompt before any
main-thread write. f5492e65 and 25f72aab opened with "create a git branch. …", which the
classifier reads as ship-only.

All 11 transcripts in that directory, as context: 9 work-shaped prompts, 4 armed writes,
4 would have been blocked, 2 of those 4 followed by an AskUserQuestion in the same turn.

The brief's stop condition, more than half of work prompts blocked while most were
answered by a later AskUserQuestion in the same turn, does not hold (1 of 3; 4 of 9), so
the default became block. The sample is small; the count is a floor on interruptions per
work prompt in this repo, not an estimate for others.
```

### Limits (2026-10-22)

```text
- A subagent's write is not judged and does not spend the marker (`*/subagents/*` in
  transcript_path, or a non-empty `agent_id`): a worker cannot ask the user, and the old
  gate's deny landing on a worker was its named limitation. So a turn that only delegates
  is never refused. The `agent_id` test was added after review: the SubagentStop payload in
  rationale/candor-subagent-probe-2026-09-29.md carries the parent's transcript_path, a
  PostToolUse inside a worker carries an agent_id (candor-subagent-context-probe-2026-10-01.md),
  and candor's relay.sh/reads.sh and card-lint-observe.sh already test it. Neither probe
  recorded a PreToolUse payload from inside a worker, so the path test stays beside it.
- Bash writes (heredocs, python, sed -i) are not matched; only Edit, Write and MultiEdit.
- The line test is a word match: `Assuming: nothing` passes, and the gate does not read
  whether the decisions named are the open ones.
- The reminder withholds the Assuming: route on an auth-surface prompt; the gate does not
  know the prompt was one and accepts the line there too.
- Timestamps compare at whole seconds against the marker's mtime; an assistant line in
  the same second as the prompt, from the turn before it, would count.
- A missing or unreadable transcript_path, no jq, or a stat that prints no number: no block.
```
