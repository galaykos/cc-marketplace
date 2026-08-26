# database

Database design and implementation, engine-agnostic: schema normalization,
expand→contract migrations, indexing, query shape, and connection-pool
discipline. Ships a `database-engineer` worker agent and a PreToolUse guard
that asks for confirmation before a destructive statement lands. Reviewing is
`/sql:review`'s job — install the sql plugin alongside; dialect statement
audits are the mariadb plugin's.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install database@cc-plugins-marketplace
```

## Example

```bash
/sql:review migrations/2026_07_add_orders_table.sql   # the review path (sql plugin)
```

Reviews live in the sql plugin: `/sql:review` detects the engine and version
first (configs, DSNs, compose files, manifests — never assumed from a `.sql`
file), then applies the `sql-best-practices` checklist. Implementation work —
new tables, migrations, indexes, query rewrites — goes to this plugin's
`database-engineer` agent, which works through the project's migration tooling
rather than raw ad-hoc DDL.

## Destructive-SQL guard

A PreToolUse hook on Write/Edit inspects new file content and pauses for your
confirmation when it introduces `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, or an
unqualified `DELETE`/`UPDATE` with no `WHERE` — and, in the same warn lane,
lock hazards like `CREATE INDEX` without `CONCURRENTLY` or a table-rewriting
`ALTER`. It asks, never hard-denies (down-migrations legitimately drop), and
fails open on any error.

## Pairs well with

- **sql** — dialect-agnostic SQL statement review the design floor defers to
- **mariadb** — MariaDB-specific statement and migration audits
- **dev-env** — spins up the local database services these reviews run against
