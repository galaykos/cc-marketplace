# task-runner: the comment text moved out of the code (2026-10-22)

The text below was moved verbatim on 2026-10-22 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-task-runner.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved. One statement below is no longer true and is kept as written: "The run's own card index under the root is not exempt" — since task-runner 0.48.1 the index `active-run.json` names (`index_path`) is exempt.

## plugins/task-runner/hooks/scope.sh

### Header

```text
PostToolUse scope-lock tripwire. When a REGISTERED run (.claude/task-runner/active-run.json
at the project root) has declared its allowed files in .claude/task-runner/scope*.json,
this warns (non-blocking) if a write landed OUTSIDE the union of those sets — the "touch
only files the task lists" discipline made mechanical. The warning is emitted as the
PostToolUse stdout JSON envelope
({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}},
exit 0) — the one non-blocking channel the executing model actually receives;
plain stdout text with exit 0 never reaches it (same channel reasoning as
candor's gate.sh clause 4, whose Stop event reaches the model only through exit 2).
No registered run, or no live scope file → no-op (the discipline is opt-in per run).
A Bash call that exits non-zero fires PostToolUseFailure instead, registered for Bash too;
the envelope then names that event. Such a command may have stopped before its redirect, so a
named target the previous call's marker post-dates is skipped, and on a call with no marker
(the run's first) a named target takes the effects wording below, never "revert". Fail-open.

WHAT IT SEES (0.41.0). Edit/Write/MultiEdit through `.tool_input.file_path`, AND Bash:
the files a command writes by `>`/`>>`, heredoc, `tee` or `sed -i`/`perl -i`, parsed by
cc_bash_write_targets below, resolved against the Bash call's cwd, kept only when they
are existing regular files under the project root, at most 8 per call (MAX_BASH_TARGETS).
Measured 2026-09-25 (rationale/2026-09-25-session-plugin-usage-review.md, finding 1): with
the host's `bashFirst` auto mode, 233 of 238 main-thread writes in one session were
`cat > file`, so an Edit/Write-only tripwire was blind on the default write path.

INTERPRETER WRITES (0.47.0). After a command naming python, node, php, ruby, perl, deno,
bun, cp, mv, install or patch, also each file git reports changed or untracked since this
hook's previous call in the run (the bash-write-effects block below), at most 8
(MAX_BASH_EFFECTS), judged against the scope as an Edit of it is. In four sessions of the
2026-10-13 retro, 40-85% of code writes went through interpreter heredocs (python3 - <<'EOF'
… open(p,'w')), which the parser cannot name. Such a path is worded apart from a named
target: it changed since the previous tool call and may not be this command's write, so
the warning sends the agent to `git diff` and never tells it to revert what it did not
write. The marker is dated on every Edit, Write and Bash call of a registered run, so an
Edit's file is not read again by the next Bash call; outside a run nothing is written. A
marker older than active-run.json, or dated by another session, reads nothing.
Everything under .claude/task-runner/ is the run's own state (active-run.json,
gate-pass.json, the scope files) and is never checked — a run commonly writes those
with `cat >`, and no card lists them.

STATE ROOT (0.41.0). Scope files are read from the project root, not the payload cwd,
which follows the model's `cd` (same review, finding 2): a run whose shell sat in
app/Models looked for app/Models/.claude/task-runner/, found nothing, and was silently
disarmed.

COVERAGE: every LIVE scope file in the run's state dir — the inline path's scope.json AND
the per-card scope-<cardId>.json files routing.md writes for delegated and tracked
cards — read as ONE UNION. An edit outside the union warns; an edit any live card
declared does not. Union, not per-file, because this hook cannot tell WHICH card an
Edit belongs to: the payload carries a path, not a card id, and charging an edit
against the wrong card's list would warn on correct work.

LIVE means: active-run.json exists, and the scope file is not older than it. Measured
(same review, finding 8): a finished run's scope-*.json files, left on disk, flagged the
NEXT task's spec edit as scope creep — the union was read whether or not a run was live.
A scope file from an earlier registration is now ignored, so re-registering a run
retires every stale file without deleting it.

WHAT IT STILL DOES NOT CATCH:
  - A WORKER IN ANOTHER WORKTREE. A subagent's Edit fires in ITS session with ITS
    cwd; a track worktree is a different tree with no active-run.json of its own, so
    its edits arm nothing here. That path is enforced by the prose diff-vs-declared
    check on return.
  - Scope-file drift INSIDE a live run. A card whose scope file is never written is
    unbounded here, and a finished card's scope-<cardId>.json written after this
    registration still WIDENS the union — the union fails toward silence, which is the
    right failure for an advisory tripwire and the wrong one for a gate. This is not a
    gate. mtimes compare at whole seconds under macOS's bash 3.2, so a stale file
    written in the same second as the registration counts as live.
  - Bash writes neither the parser nor git can name: a path held in a variable, a target
    past the eighth; after an interpreter run, a writer the effects block does not name
    (make, git apply, npx prettier --write), a gitignored output, a repo with no git, a
    file written then reverted, a mv or cp -p destination (it keeps the source's mtime),
    files past the eighth, and every write of the first Bash call after a registration
    (no marker newer than active-run.json) or of the first call of a session. A file that
    does not exist after the call is skipped.
  - Writes the command did not make: after an interpreter run, any file changed since this
    hook's previous call in the session (an IDE save, a cache or test output git does not
    ignore) warns, in the effects wording above. Every agent of a session in the tree
    shares one marker per root, so a parallel worker's write can be reported to another
    agent's call, or dated past by that call and missed by the worker that made it.
  - Any malformed scope file — invalid JSON, or no `allow` array — disarms the whole
    call, not just its own card: a partial union would warn about paths a card it could
    not parse had actually allowed.
  - A Write/Edit to an absolute path outside the project root: skipped on purpose, as a
    Bash target there always was. The run's own card index under the root is not
    exempt, so updating its status column still warns unless a card lists it.

fd 3 = the caller's real stderr, saved before the block so the two fail-open
warnings below (D7: missing jq / a malformed scope file) reach stderr — the block's
`2>/dev/null` is there only to silence incidental jq/grep noise and would eat a
plain `>&2` warning. (Honest limitation law: .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws".)
```
