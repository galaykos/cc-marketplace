# database

Database design and implementation, engine-agnostic: schema normalization,
expand→contract migrations, indexing, query shape, and connection-pool
discipline. Ships the `database-design` skill, a `/database:review` command, a
`database-engineer` worker agent, and a PreToolUse guard that asks for
confirmation before a destructive statement lands. Dialect statement audits are
deferred to the sql/mysql/mariadb/postgresql plugins.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install database@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/database:review [path-migration-or-schema]` | Review schema, migrations, indexes, and pooling against database-design (engine-agnostic) |

## Example

```bash
/database:review migrations/2026_07_add_orders_table.sql
/database:review         # reviews the current diff
```

The review detects the engine and version first (configs, DSNs, compose files,
manifests — never assumed from a `.sql` file), then applies the
`database-design` checklist and reports one finding per line, severity-sorted,
with a coverage inventory. Implementation work — new tables, migrations,
indexes, query rewrites — goes to the `database-engineer` agent, which works
through the project's migration tooling rather than raw ad-hoc DDL.

## Destructive-SQL guard

A PreToolUse hook on Write/Edit inspects new file content and pauses for your
confirmation when it introduces `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, or an
unqualified `DELETE`/`UPDATE` with no `WHERE` — and, in the same warn lane,
lock hazards like `CREATE INDEX` without `CONCURRENTLY` or a table-rewriting
`ALTER`. It asks, never hard-denies (down-migrations legitimately drop), and
fails open on any error.

## Pairs well with

- **sql** — dialect-agnostic SQL statement review the design floor defers to
- **postgresql** — PostgreSQL-specific statement and migration audits
- **mysql** — MySQL-specific statement audits for the same schema work
- **dev-env** — spins up the local database services these reviews run against
