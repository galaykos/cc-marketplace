---
description: Write a Conventional Commits message from the actual staged diff — imperative subject under 50 chars, body only when the why is not obvious. Writes the message; committing stays the user's call.
argument-hint: "[--amend | extra context]"
---

# /terse:commit

Invoke the `terse-commit` skill.

1. Read the real change: `git diff --cached --stat` then `git diff --cached`. If
   nothing is staged, read `git diff` and say that the message describes unstaged
   work.
2. Read `git log -20 --oneline` for the repo's own type, scope and capitalization
   conventions. They outrank this skill's defaults.
3. Draft the message per the skill. `$ARGUMENTS` may carry `--amend` (target the
   last commit's message instead) or free-text context — a ticket, the why, a
   constraint the diff cannot show.
4. Output the message in a fenced block, ready to paste. Nothing else — no
   explanation of the choices unless something in the diff forced an unusual call.

Do not run `git commit` unless the user asked for the commit itself. Writing the
message and making the commit are separate acts, and only one of them was requested.

Never add AI attribution, and never claim the diff does something you did not
verify by reading it.
