# database

Relational databases in one plugin: the engine-agnostic **sql-best-practices** skill,
the **mariadb-best-practices** dialect skill (loaded only for MariaDB, with the engine
detected first — review runs through `/code-review:review`; the plugin's own
review entry was retired on 2026-09-14), a `database-engineer`
worker that applies schema, migration, indexing and pooling work through the
project's migration tooling, and a PreToolUse guard that asks for confirmation before
a destructive statement lands.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install database@cc-plugins-marketplace
```

## Review

```bash
/code-review:review database/migrations/2026_08_21_add_status.php
/code-review:review db/migrations/2026_add_orders_index.sql
/code-review:review                 # reviews the current diff
```

`/code-review:review` (the code-review plugin) detects the engine and version (never
from a `.sql` file alone), reviews statements, schemas and migrations against
`sql-best-practices`, and adds `mariadb-best-practices` when the engine is MariaDB —
severity-sorted one-line findings with fixes, routed to `database-engineer` on apply.

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
confirmation when it introduces data loss or a lock hazard:

| Tier | Shapes | Standing |
|---|---|---|
| data loss | `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, an unqualified `DELETE`/`UPDATE` with no `WHERE`; Laravel's `Schema::drop*(`; the same statement as spelled by Prisma, Drizzle, TypeORM, Doctrine, Knex and Alembic (`dropTable`, `drop_table`, `dropSchema`, `drop_all`, …); and the NoSQL twins — `deleteMany`/`updateMany`/`remove` with an empty filter, `.drop()`/`.dropCollection()`/`.dropDatabase()` | **ask** — `permissionDecision: "ask"`, fixtures in `scripts/__tests__/guard.test.sh` |
| lock hazard | `CREATE INDEX` without `CONCURRENTLY`, a table-rewriting `ALTER` (column TYPE change, `SET NOT NULL`), a DynamoDB `Scan` on a path that is not a script/migration/seed/test | **ask** — same tier, different message |
| everything else in `sql-best-practices` | expand→migrate→contract ordering, index choice, pool sizing, rollback notes | **agent-graded** — a reviewer applies them; no script does |

It asks, never hard-denies (down-migrations legitimately drop), and fails open on
any error. `CC_DB_GUARD=off` disables it for the session, and the ask message says
so. Two things it deliberately does not reach: a **rename** of a column or table
(that rule is `sql-best-practices` § Migrations, agent-graded), and documentation —
`.md`, `.mdx`, `.markdown`, `.txt`, `.rst` and anything under `taskmaster-docs/`
exit early, because a card that quotes a migration executes nothing and an
unanswerable `ask` stalls a headless run. A destructive statement typed at a shell
rather than written to a file is `command-guard`'s territory, which is the
`yields_to` edge in `lane.tsv`.

## Agent

`database-engineer` (worker, can edit) — detects the engine and version, reads the
existing schema and migration history, implements through the project's migration
tooling, and verifies against a local database when one is available. Destructive
operations need a confirmed backup or recovery path, or it stops and asks.

## Pairs well with

- **laravel** — the Eloquent side of the same queries
- **devops** — `/devops:init` spins up the local database services these reviews run against
- **resilience** — `/resilience:review --concern performance` measures a slow query before this plugin reshapes it
