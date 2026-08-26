---
name: sql-best-practices
description: Use when writing or reviewing SQL on any engine, statement or schema — sargable predicates, join correctness, composite indexes, NULL three-valued traps, isolation, keyset pagination, parameterized queries, plus the design floor: normalization, expand-migrate-contract migrations with a rollback path, index choice from observed queries, and connection-pool sizing. MariaDB-specific rules → mariadb; measuring a slow query → performance.
---

## Sargable predicates

An index is used only when the column stands alone on its side of the comparison:

- `WHERE YEAR(created_at) = 2026` scans; `WHERE created_at >= '2026-01-01' AND
  created_at < '2027-01-01'` seeks. Rewrite functions-on-columns as ranges.
- Implicit casts are hidden functions: comparing a string column to a number (or a
  differing collation/charset on join keys) forces per-row conversion and kills the
  index. Match types at the schema, not in the query.
- Leading wildcards (`LIKE '%term'`) cannot seek; if you need contains-search, that
  is a full-text/trigram problem, not a LIKE problem.

## Join correctness

- Explicit `JOIN ... ON` always; a comma-join with a WHERE is a cartesian accident
  waiting for a missing predicate.
- A filter on the right table of a LEFT JOIN belongs in ON, not WHERE — in WHERE it
  silently converts the join to INNER (NULLs fail the predicate).
- Row-count fan-out: joining a one-to-many multiplies rows; a `DISTINCT` or
  `GROUP BY` added "to fix duplicates" usually hides a fan-out bug. Aggregate the
  many-side in a subquery/CTE first, then join one-to-one.
- `EXISTS (SELECT 1 ...)` over `IN (subquery)` when the subquery can return NULLs
  or many rows; over a join when you only need presence, not columns.

## NULL: three-valued logic

- `NOT IN (subquery)` returns zero rows if the subquery yields a single NULL — the
  classic silent bug. Use `NOT EXISTS`.
- `col != 'x'` excludes NULLs too; say `col IS NULL OR col != 'x'` when you mean it.
- Aggregates ignore NULLs (`COUNT(col)` vs `COUNT(*)` differ); `CONCAT`/arithmetic
  with NULL yields NULL. `COALESCE` at the edge, not sprinkled everywhere.
- Prefer `IS [NOT] DISTINCT FROM` (or the engine's equivalent) for null-safe
  comparison instead of `OR` gymnastics.

## Indexing logic

- Composite order: equality columns first, then the one range/sort column; columns
  after the range member are only covering, not seeking.
- The optimizer reads left-to-right: an index on `(a, b)` serves `WHERE a=?` and
  `WHERE a=? AND b=?`, not `WHERE b=?`.
- Covering indexes (all selected columns in the index) skip the table lookup —
  worth it for hot queries, not for every query: each index taxes every write.
- Index every foreign key; deletes/updates on the parent otherwise scan the child.
- Low-selectivity columns (status with 3 values) rarely deserve their own index;
  they belong as the equality prefix of a composite one.

## Aggregation and windows

- Every non-aggregated selected column belongs in GROUP BY — engines that allow
  otherwise are choosing an arbitrary row for you.
- WHERE filters rows before grouping, HAVING filters groups after; putting a row
  predicate in HAVING makes the engine aggregate rows you were about to discard.
- Window functions replace self-joins for running totals, ranks, and
  latest-row-per-group (`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) = 1`).

## Transactions

- Keep transactions short and free of network/user waits; a held transaction holds
  locks (and on MVCC engines blocks cleanup).
- Know your isolation level and its failure mode: deadlocks and serialization
  failures are retryable by design — wrap the transaction in an idempotent retry,
  do not "fix" them by lowering isolation blindly.
- One logical change per transaction: exactly the rows that must commit or roll
  back together, nothing more.

## Constraints declare truth

- NOT NULL, UNIQUE, FK, CHECK belong in the schema even when the app validates —
  the app validates requests, the constraint defends the data against every writer
  (background jobs, migrations, the next service, a psql session).
- Uniqueness enforced only in application code is a race condition; the unique
  index is the lock.

## Pagination

- OFFSET reads and throws away every skipped row — page 1000 costs 1000 pages.
  Use keyset pagination: `WHERE (created_at, id) < (?, ?) ORDER BY created_at
  DESC, id DESC LIMIT ?`, with an index matching the sort. Include a unique
  tiebreaker column or rows straddle page boundaries.

## Migrations

- Additive first: add nullable column → backfill in batches → add constraint.
  Never write-and-constrain in one irreversible step on a live table.
- Destructive operations (drop column/table) ship one release after the last
  reader disappeared, never in the same deploy.
- Batch backfills (bounded UPDATE ... LIMIT loops or ranged by PK); one giant
  UPDATE locks the table and bloats logs/undo.
- Every migration states its rollback path, even when that path is "irreversible —
  requires restore from backup". A migration with no rollback answer is not ready,
  and a destructive one without a confirmed backup is not runnable.
- Go through the project's migration tool (Alembic, Flyway, Prisma, Rails, Knex,
  golang-migrate). Raw ad-hoc DDL where a migration system exists is a bug.

> Worked example — rename `users.name` to `full_name` with zero downtime:
> **expand** (add `full_name` nullable, deploy; old code still writes `name`) →
> **migrate** (backfill, dual-write both in app code) → **contract** (switch reads,
> stop writing `name`, drop it a deploy later). A one-step `RENAME COLUMN` breaks
> every running old instance the instant it lands.

## Schema design

- Normalized by default — third normal form until a *measured* read pattern says
  otherwise. Denormalization carries a written justification naming the query it
  speeds and the number it improved; a duplicated column is a consistency bug you
  have chosen to maintain forever.
- One meaning per column. No nullable-boolean-as-tristate, no comma-joined lists,
  no `status` that means five things by convention.
- Detect engine AND version before writing any DDL — configs, DSNs, compose files,
  manifests. A `.sql` file alone proves no dialect.
- Index choice is a design decision driven by queries you have SEEN. An index on
  the wrong column is write cost with no read benefit, and removing a "redundant"
  one without checking what reads it is how a report query falls to a full scan.

## Connection pooling

- Size the pool from the workload and the server's ceiling, never a copied default:
  `pool_size × app_instances ≤ db_max_connections − headroom`. A 20-connection pool
  across 8 pods is 160 connections against a Postgres defaulting to 100 — over the
  cliff before load. Leave headroom for migrations, admin sessions, replicas.
- Too large starves the database, too small serializes the app; both look like
  "the database is slow".

## Parameterization

- Bind every value; never interpolate. Identifiers (ORDER BY column, table names)
  cannot be bound — allowlist them against a fixed set.
- LIKE patterns are values too: bind the pattern, escape `%`/`_` in user input.

## Before optimizing

Run the engine's EXPLAIN and read the actual plan — row estimates, join order,
index used. Guessing at indexes from the query text alone adds write cost without
evidence; the plan is the evidence.
