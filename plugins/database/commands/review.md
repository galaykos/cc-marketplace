---
description: Review schema, migrations, indexes, and pooling against database-design (engine-agnostic)
argument-hint: [path-migration-or-schema]
---

Review the target's database design — schema shape, migrations, indexing, query
shape, and connection/transaction configuration. You audit the design, not run DDL.

1. Determine scope from $ARGUMENTS — a migration file or directory, a schema
   definition, an ORM model dir, or a diff. If empty, locate the migration history and
   schema in the repo and review recent changes. Detect the engine and version first
   (configs, DSNs, compose, manifests) — never assume a dialect.

2. Invoke the `database-design` skill from this plugin and apply its checklist:
   schema (normalization justified, constraints in the DB not just the app, one
   meaning per column), migrations (expand→migrate→contract, a stated rollback path,
   no destructive step without a confirmed backup), indexing (query-driven, correct
   composite order, nothing removed unchecked), query shape (sargable, no N+1, keyset
   over OFFSET), and connections/transactions (pool size vs the server ceiling, short
   boundaries off the I/O path).

3. Output findings one line each:
   path:line — severity — problem — fix
   Order by severity: critical, high, medium, low. A destructive migration without a
   rollback/backup path is always critical.

4. Defer, do not duplicate: dialect-specific statement audits → `/sql:review` and the
   matching `/mysql:review`, `/mariadb:review`, `/postgresql:review`; query
   performance measurement → `/performance:review`.

5. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   "Have the database-engineer apply the fixes now (Recommended)" / "Report only". On
   apply, dispatch the `database-engineer` worker with the finding list. In headless or
   non-interactive runs, report only.
