---
name: cmd-code-review-review
description: "Use when the user asks to review a diff, branch, or path for correctness bugs, code smells, and convention drift — severity-sorted one-line findings."
---

_This skill wraps the `/code-review:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Review the code change in $ARGUMENTS. Resolve scope in this order:

1. If $ARGUMENTS names a path, PR number, or branch — review that.
2. Else if staged changes exist (`git diff --cached --stat`) — review staged.
3. Else review the working tree against the default branch
   (`git diff $(git merge-base HEAD origin/HEAD 2>/dev/null || echo HEAD~1)`).
4. Nothing to review — say so and stop.

Then:

1. Read every changed hunk plus enough surrounding code to judge behavior —
   never review a hunk in isolation when it calls or is called by nearby code.
2. Correctness pass: logic errors, off-by-one, null/undefined paths, error
   handling gaps, race conditions, resource leaks, wrong boundary conditions.
3. Smell pass: apply the code-smells skill catalog to the changed code only —
   pre-existing smells outside the diff get one summary note, not findings.
4. Convention pass: naming, structure, and idiom drift versus the surrounding
   file and the project's stated conventions (CLAUDE.md, linters, existing code).

Output rules:

- One line per finding: `path:line — severity — problem — fix`.
  Severities: `blocker` (wrong behavior/data loss), `major` (bug-prone or
  misleading), `minor` (smell/convention). Sort by severity, blockers first.
- No praise, no restating the diff, no findings on unchanged lines.
- Defer instead of duplicating: structural/YAGNI concerns → recommend
  the `cmd-code-architecture-yagni` skill or the architecture-reviewer agent; security-deep
  issues → the `cmd-security-review` skill; stack-idiom detail → the matching per-framework
  review command when that plugin is installed.
- Close with a one-line verdict: merge-ready, merge-after-blockers, or rework.

After the verdict, if blocker or major findings exist, ask via
AskUserQuestion: "Fix the blockers now (Recommended)" / "Skip — review
only". Headless: verdict only.
