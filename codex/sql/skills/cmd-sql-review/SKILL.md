---
name: cmd-sql-review
description: "Use when the user asks to review sql code against sql-best-practices."
---

_This skill wraps the `/sql:review` command; pass the command's input as the skill's argument (`$ARGUMENTS`)._


Review the SQL, schema, and migration code in $ARGUMENTS (or the current diff if no
argument) against the sql-best-practices skill from this plugin. Invoke the skill
first. Keep findings engine-agnostic; defer engine-specific rules to the mysql/mariadb/postgresql plugins when the engine is identifiable. Report findings as `path:line — problem — fix`, ordered by severity.
Skip formatting nits unless they change behavior.

When the engine is identified and its dialect plugin is installed, offer as a
selectable choice (AskUserQuestion): "Run the engine-specific review now
(Recommended)" / "Skip — engine-agnostic findings only". When findings exist
and no engine handoff applies, offer: "Apply the fixes now (Recommended)" /
"Skip — report only".
