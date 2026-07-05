---
description: Review mariadb code against mariadb-best-practices
argument-hint: [files-or-diff]
---

Review the SQL, schema, and migration code in $ARGUMENTS (or the current diff if no
argument) against the mariadb-best-practices skill from this plugin. Invoke the skill
first. Before reporting, determine the engine and version actually in use — `SELECT version()` output when a connection exists, docker-compose/CI image tags, or migration tool config — and pin every finding to it: nothing the version already solves, nothing above it. When uncertain about an API or behavior, verify against the official docs for the pinned version — https://mariadb.com/kb — instead of answering from memory. Report findings as `path:line — problem — fix`, ordered by severity.
Skip formatting nits unless they change behavior.

When findings exist, offer the next step as a selectable choice (AskUserQuestion):
"Apply the fixes now (Recommended)" / "Skip — report only". Print bare
instructions only in headless runs.
