---
description: Review a diff, branch, or path for correctness bugs, code smells, and convention drift — severity-sorted one-line findings.
---

Review the code change in $ARGUMENTS. Resolve scope in this order:

1. If $ARGUMENTS names a path, PR number, or branch — review that.
2. Else if staged changes exist (`git diff --cached --stat`) — review staged.
3. Else review the working tree against the default branch
   (`git diff $(git merge-base HEAD origin/HEAD 2>/dev/null || echo HEAD~1)`).
4. Nothing to review — say so and stop.

Triage before the deep read: a trivial, single-file, or purely mechanical change
earns a one-line verdict — state it and stop. Take the full pass below when the change
touches correctness-sensitive code (auth, data, migrations, concurrency), OR spans
more than 5 files, OR exceeds 300 changed lines (a NEW file counts its full length as
changed).

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
  /code-architecture:yagni or the architecture-reviewer agent; security-deep
  issues → /security:review; stack-idiom detail → the matching per-framework
  review command when that plugin is installed.

Before the verdict, state the coverage: `Checked: …` and `Not checked: … (why)` so it
is explicit what was covered, what was clean, and what was skipped — not only what
broke. Then run one adversarial self-refute pass over every `blocker` finding; if a
finding does not survive it, drop or downgrade it with a note.

Close with a one-line verdict: merge-ready, merge-after-blockers, or rework.

After the verdict, if findings exist, offer the next step as a selectable choice
(AskUserQuestion): "Fix all findings" / "Fix blockers only" / "Report only". On an
apply pick, apply the chosen findings rather than making the user retype them.
Headless: verdict only.
