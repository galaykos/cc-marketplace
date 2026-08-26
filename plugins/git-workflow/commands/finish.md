---
description: Finish a development branch — full-suite verify with state evidence, then merge/PR/keep/discard with cleanup.
argument-hint: [branch]
---

Finish the development branch $ARGUMENTS (or the current branch if no argument
is given) using the branch-completion skill from this plugin. Invoke the skill
first. If a branch was named and is not checked out, switch to it (or its
worktree) before doing anything else.

Write the arc phase sentinel `.claude/cc-phase.json` first —
`{"phase":"ship","owner":"git-workflow:finish","session_id":"<this session id>",`
`"started_at":"<ISO-8601 UTC>"}` — so prompt-channel reminder hooks that own an
earlier phase stand down while the branch is being finished; a clarify-the-
requirements nudge on a merge decision is noise. **Remove it before this command
returns, on every path including discard and the red-suite stop below.** A TTL
bounds a leaked sentinel, but the clear is this command's responsibility.

Run the project's full check suite as the gate — a red suite stops here with
the failures reported; no destination options for broken work.

On green, before offering any destination, run the review passes that exist in
this installation — each only if its plugin is installed, none of them fatal on
absence, all of them named in the report so a skip is visible:

- `/code-review:review` on the branch diff — correctness, smells, convention drift.
- `code-architecture:drift-review` on the whole diff — did the work stray from what
  was actually asked, are there weakened tests, left-in stubs, skipped criteria.
- `/secret-scanning:scan` on the diff — a credential reaching a PR is the one
  finding that cannot be fixed by a later commit.

A green suite is evidence the code RUNS, not that it should merge; without this
step those three are named nowhere in the path between finishing work and
shipping it. Any `critical` finding drops "merge locally" and "push and open a
PR" from the offered set until it is resolved, or the user explicitly waives it
on the record — record the waiver text in the report, not just the choice.

Then gather the state evidence the skill specifies (diffstat against the base,
ahead/behind counts, commit list, suite output tail), present it together with
the review results, and use AskUserQuestion. Which destinations to offer — and
the default-branch-is-PR-only rule that removes "merge locally" when the base is
the default branch — comes from the skill's destination protocol: apply it from
there, do not re-derive it here. Execute the chosen protocol from the skill end
to end, including post-merge re-verification, worktree removal, and branch
deletion where the protocol calls for them — discard only after the user types
the branch name back.

Headless fallback: if AskUserQuestion is unavailable or the session is
non-interactive, report the verification result, the state evidence, and the
applicable options with the exact commands each would run — omitting any
local-merge or push onto the default branch (PR-only) — and take no destructive
action: no merge, no push, no branch deletion, no worktree removal.
