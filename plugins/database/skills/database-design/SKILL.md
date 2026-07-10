---
name: database-design
description: Use when designing or reviewing relational schema, migrations, indexes, query shape, connection pooling, or transaction boundaries — engine-agnostic database discipline. Dialect-specific statement audits belong to the sql/mysql/mariadb/postgresql review skills; this is the cross-engine design floor.
---

# Database design

Engine-agnostic discipline for the parts of the database that outlive any one query:
the schema, how it migrates, what it indexes, and how connections and transactions are
shaped. Detect the engine and version before writing any SQL — read configs, DSNs,
compose files, dependency manifests. A `.sql` file alone proves no dialect.

## Schema

- **Normalized by default.** Third normal form until a *measured* read pattern says
  otherwise; any denormalization carries a written justification (the query it speeds,
  the number it improved), never a hunch. A duplicated column is a consistency bug you
  have chosen to maintain forever.
- **Constraints in the database, not just the app.** `NOT NULL`, foreign keys, unique
  and check constraints are the last line that holds when a second writer, a migration,
  or a bug bypasses the application. The app validating is not the data being valid.
- **One meaning per column.** No nullable-boolean-as-tristate, no comma-joined lists,
  no "status" that means five different things by convention.

## Migrations

- **Expand → migrate data → contract**, never a single destructive step. Add the new
  column/table, backfill, switch reads, *then* drop the old — each deployable on its
  own so a rollback at any point is safe.
- **Every migration states its rollback path**, even when that path is "irreversible —
  requires restore from backup", said explicitly. A migration with no rollback answer
  is not ready.
- **No destructive change without a confirmed backup** and an explicit backfill. DROP,
  TRUNCATE, and mass DELETE/UPDATE are called out loudly, not slipped into a routine
  migration.
- Go through the project's migration tool (Alembic, Flyway, Prisma, Rails, Knex,
  golang-migrate). Raw ad-hoc DDL when a migration system exists is a bug.

> Worked example — rename `users.name` to `full_name` with zero downtime:
> 1. **Expand** — add `full_name`, nullable; deploy. Old code still writes `name`.
> 2. **Migrate** — backfill `full_name` from `name`; dual-write both in app code.
> 3. **Contract** — switch reads to `full_name`, stop writing `name`, then drop
>    `name` in a later deploy. A one-step `RENAME COLUMN` breaks every running old
>    instance the instant it lands.

## Indexing

- **Driven by real query patterns you have seen**, not speculation. An index on the
  wrong column is write-cost with no read-benefit; profile the query, read the plan.
- **Composite column order** matches predicate selectivity and sort needs — the
  leftmost columns are the ones filtered on equality, then ranges, then sort.
- **Remove nothing without checking what reads it.** A "redundant" index may be the
  only thing keeping a report query off a full scan.
- Every foreign key that is filtered or joined on wants an index; the constraint does
  not create one on its own in every engine.

## Query shape

- **Sargable predicates** — no functions wrapping an indexed column
  (`WHERE lower(email) = …` defeats the index on `email`); compute the other side.
- **No N+1 loops** — batch or join instead of a query per row; count queries per
  request, not per iteration.
- **Keyset pagination over `OFFSET`** for large result sets — `OFFSET 100000` scans
  and discards 100000 rows every page.

## Connections and transactions

- **Pool size derived from workload and the database's connection limit**, not a
  copied default. Too large starves the database; too small serializes the app. The
  pool ceiling times the app-instance count must stay under the server's `max
  connections`.
- **Explicit transaction boundaries** — state what is atomic and why. A transaction
  held open across a network call or a slow computation holds locks that block
  everyone; keep them short and off the critical I/O path.

> Sizing sanity check: `pool_size × app_instances ≤ db_max_connections − headroom`.
> A 20-connection pool across 8 app pods is 160 connections; a Postgres defaulting to
> `max_connections = 100` is already over the cliff before load. Size the pool to the
> database's real ceiling and the app's actual concurrency, then leave headroom for
> migrations, admin sessions, and replicas.

## Reviewing an existing schema

- Constraints present in the DB, not just the app; every FK filtered/joined is indexed.
- Migrations reversible or explicitly flagged irreversible-with-backup.
- No sargability-defeating predicates on hot queries; no `OFFSET` deep pagination.
- Pool size reconciled against the server's connection ceiling.

## Defer rule

- Dialect-specific statement audits → `/sql:review` (engine-agnostic floor) and the
  matching `/mysql:review`, `/mariadb:review`, `/postgresql:review`.
- Query *performance* measurement (plans, p95, N+1 counts as numbers) →
  `performance-tuning`.
- Applying a migration set → the `database-engineer` worker or the shared
  `task-executor`.

## Anti-patterns

- **App-only constraints** — validation in code, none in the schema; invalid data one
  bypass away.
- **Destructive migration in one step** — DROP without expand/contract, no rollback.
- **Speculative indexes** — indexing columns no query filters on; write cost for
  nothing.
- **`OFFSET` deep-pagination** — linear scan per page on large tables.
- **Default pool size** — copied from a tutorial, unrelated to this database's limits.
- **Long transaction across I/O** — locks held over a network call, blocking writers.
