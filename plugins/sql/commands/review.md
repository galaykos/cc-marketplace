---
description: Review sql code against sql-best-practices
argument-hint: [files-or-diff]
---

Review the SQL, schema, and migration code in $ARGUMENTS (or the current diff if no
argument) against the sql-best-practices skill from this plugin. Invoke the skill
first. Keep findings engine-agnostic; defer engine-specific rules to the mysql/mariadb/postgresql plugins when the engine is identifiable. Report findings as `path:line — problem — fix`, ordered by severity.
Skip formatting nits unless they change behavior.
