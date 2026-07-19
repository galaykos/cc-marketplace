---
description: Finish a development branch — verify the full suite, show state evidence, ask merge/PR/keep/discard, execute the choice with cleanup
argument-hint: [branch]
---

Finish the development branch $ARGUMENTS (or the current branch if no argument
is given) using the branch-completion skill from this plugin. Invoke the skill
first. If a branch was named and is not checked out, switch to it (or its
worktree) before doing anything else.

Run the project's full check suite as the gate — a red suite stops here with
the failures reported; no destination options for broken work. On green, gather
the state evidence the skill specifies (diffstat against the base, ahead/behind
counts, commit list, suite output tail) and present it, then use
AskUserQuestion. The default branch is PR-only: when the branch's base is the
repo's default branch (resolve it via `git symbolic-ref refs/remotes/origin/HEAD`,
falling back to whichever of main/master exists), drop "merge locally" and offer
three options — push and open a PR, keep the branch open, discard the work. When
the base is a non-default branch, offer all four (merge locally added). If HEAD
IS the default branch with commits ahead (no feature branch), do not offer a
destination — stop and route the user to move the commits onto a new branch and
open a PR. If a PR is impossible (base is the default branch but no remote or
`gh`), stop rather than local-merging onto the default. Execute the chosen
protocol from the skill end to end, including post-merge re-verification,
worktree removal, and branch deletion where the protocol calls for them —
discard only after the user types the branch name back.

Headless fallback: if AskUserQuestion is unavailable or the session is
non-interactive, report the verification result, the state evidence, and the
applicable options with the exact commands each would run — omitting any
local-merge or push onto the default branch (PR-only) — and take no destructive
action: no merge, no push, no branch deletion, no worktree removal.
