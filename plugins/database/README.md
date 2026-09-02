# database

Relational databases in one plugin: the engine-agnostic **sql-best-practices** skill,
the **mariadb-best-practices** dialect skill, one `/database:review` that detects the
engine first and loads the dialect skill only for MariaDB, a `database-engineer`
worker that applies schema, migration, indexing and pooling work through the
project's migration tooling, and a PreToolUse guard that asks for confirmation before
a destructive statement lands.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install database@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/database:review [files-or-diff]` | Detect the engine and version (never from a `.sql` file alone), review statements, schemas and migrations against `sql-best-practices`, and add `mariadb-best-practices` when the engine is MariaDB — severity-sorted one-line findings with fixes, routed to `database-engineer` on apply |

```bash
/database:review database/migrations/2026_08_21_add_status.php
/database:review db/migrations/2026_add_orders_index.sql
/database:review                 # reviews the current diff
```

## Skills

| Skill | Reach for it when |
|---|---|
| `sql-best-practices` | Any statement on any engine — sargable predicates, join correctness, composite index logic, NULL three-valued traps, transaction and isolation discipline, constraints as truth, keyset pagination, expand → migrate → contract migrations with a rollback path, parameterized queries, pool sizing |
| `mariadb-best-practices` | MariaDB 10.6+ specifically — the not-MySQL divergences, `RETURNING`, sequences, system-versioned tables, the native UUID type, uca1400 collations, JSON-as-LONGTEXT, Galera multi-master awareness (`references/galera.md`) |

Other engines (MySQL, PostgreSQL) have no dialect skill here: their version-idiom
maps measured zero against a blind control (`rationale/measured-zero-shapes.md`), so
they get the engine-agnostic pass with dialect concerns named as such. MariaDB survives
because its rules diverge from what the model assumes is MySQL.

## Destructive-SQL guard

A PreToolUse hook on Write/Edit inspects new file content and pauses for your
confirmation when it introduces `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, or an
unqualified `DELETE`/`UPDATE` with no `WHERE` — and, in the same warn lane,
lock hazards like `CREATE INDEX` without `CONCURRENTLY` or a table-rewriting
`ALTER`. It asks, never hard-denies (down-migrations legitimately drop), and
fails open on any error.

## Agent

`database-engineer` (worker, can edit) — detects the engine and version, reads the
existing schema and migration history, implements through the project's migration
tooling, and verifies against a local database when one is available. Destructive
operations need a confirmed backup or recovery path, or it stops and asks.

## Pairs well with

- **laravel** — the Eloquent side of the same queries
- **devops** — `/devops:init` spins up the local database services these reviews run against
- **performance** — measuring a slow query before this plugin reshapes it
