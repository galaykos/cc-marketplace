---
name: command-commit
description: "Write a Conventional Commits message from the actual staged diff — imperative subject under 50 chars, body only when the why is not obvious. Writes the message; committing stays the user's call."
---

Read [the Codex execution contract](../../references/codex.md) before using helpers or delegating.

# terse:command-commit

Invoke the `terse-commit` skill.

## Context (preloaded — no exploration turn needed)

- Branch: !`git branch --show-current`
- Staged files: !`git diff --cached --stat`
- Unstaged files: !`git diff --stat`
- Recent subjects (the repo's own type, scope and capitalization conventions — they outrank the skill's defaults): !`git log -20 --oneline`

## Steps

1. Read the real change: `git diff --cached`. If the staged stat above is empty,
   read `git diff` and say that the message describes unstaged work.
2. Draft the message per the skill. `the user-supplied arguments` may carry `--amend` (target the
   last commit's message instead) or free-text context — a ticket, the why, a
   constraint the diff cannot show.
3. Output the message in a fenced block, ready to paste. Nothing else — no
   explanation of the choices unless something in the diff forced an unusual call.

Do not run `git commit` unless the user asked for the commit itself. Writing the
message and making the commit are separate acts, and only one of them was requested;
`allowed-tools` above is the read-only git set, so a commit from this command needs
the user's own permission prompt.

Never add AI attribution, and never claim the diff does something you did not
verify by reading it.
