---
name: cmd-git-workflow-finish
description: "Use when the user asks to finish a development branch — verify the full suite, show state evidence, ask merge/PR/keep/discard, execute the choice with cleanup."
---

_This skill wraps the `/git-workflow:finish` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Finish the development branch $ARGUMENTS (or the current branch if no argument
is given) using the branch-completion skill from this plugin. Invoke the skill
first. If a branch was named and is not checked out, switch to it (or its
worktree) before doing anything else.

Run the project's full check suite as the gate — a red suite stops here with
the failures reported; no destination options for broken work. On green, gather
the state evidence the skill specifies (diffstat against the base, ahead/behind
counts, commit list, suite output tail) and present it, then use
AskUserQuestion with exactly four options: merge locally, push and open a PR,
keep the branch open, discard the work. Execute the chosen protocol from the
skill end to end, including post-merge re-verification, worktree removal, and
branch deletion where the protocol calls for them — discard only after the
user types the branch name back.

Headless fallback: if AskUserQuestion is unavailable or the session is
non-interactive, report the verification result, the state evidence, and the
four options with the exact commands each would run — and take no destructive
action: no merge, no push, no branch deletion, no worktree removal.
