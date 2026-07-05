---
name: postgresql-best-practices
description: Use when writing or reviewing PostgreSQL 14+ schemas, queries, or migrations — MVCC/vacuum reality, rich native types (timestamptz, jsonb, uuid, numeric), the index arsenal (partial, expression, covering, GIN, BRIN, CONCURRENTLY), lock-aware zero-downtime migrations, ON CONFLICT and RETURNING, connection pooling, version leverage through 17/18. Generic SQL rules live in the sql plugin.
---

## MVCC and vacuum reality

- Every UPDATE/DELETE leaves a dead tuple; autovacuum reclaims them. A
  long-running transaction (or idle-in-transaction session) pins the xmin horizon
  and blocks cleanup for the WHOLE cluster — bloat and slowdowns follow. Kill
  idle-in-transaction with `idle_in_transaction_session_timeout`.
- HOT updates keep index entries stable but only when no indexed column changed —
  do not index high-churn columns you never filter by.
- Batch big write jobs and commit between batches; a million-row UPDATE in one
  transaction is bloat plus replication lag plus lock time.

## Use the types — they are the point

- `timestamptz` ALWAYS over `timestamp` — it stores the UTC instant; bare
  timestamp stores a wall-clock guess that breaks on the first timezone bug.
- `text` over `varchar(n)` — length limits belong in CHECK constraints when they
  are real business rules, not folklore column sizing.
- `numeric` for money (never float); `uuid` as a real type, not CHAR(36);
  `jsonb` (never `json`) for documents; arrays and range/multirange types where
  the domain is genuinely set/range shaped; domains for reusable constraints.
- Enums for closed sets that almost never change; a reference table once they do.

## The index arsenal

- B-tree is the default; the wins come from the rest:
  - **Partial**: `WHERE status = 'pending'` hot-subset indexes — small, fast,
    and they encode the query's intent.
  - **Expression**: `(lower(email))` — index the expression you actually query.
  - **Covering**: `INCLUDE (col)` for index-only scans on hot reads.
  - **GIN**: jsonb containment, arrays, full-text; **BRIN**: huge append-only
    tables ordered by time — kilobytes instead of gigabytes.
- `CREATE INDEX CONCURRENTLY` on live tables — and know it can fail leaving an
  INVALID index: check and drop/rebuild on failure. (Same for DROP CONCURRENTLY.)
- Composite order and FK-indexing rules from the sql plugin apply unchanged —
  Postgres does not index FKs automatically.

## Lock-aware migrations

Migrations run under `lock_timeout` (e.g. 2s) and retry — a blocked ALTER on a
hot table queues EVERYTHING behind its ACCESS EXCLUSIVE request:

- Adding a nullable column (or with a constant default, 11+) is instant; type
  changes and most NOT NULLs rewrite the table.
- Add constraints in two steps: `ADD CONSTRAINT ... NOT VALID` (instant), then
  `VALIDATE CONSTRAINT` (concurrent, no exclusive lock).
- NOT NULL without rewrite: add a `CHECK (col IS NOT NULL) NOT VALID`, validate,
  then `SET NOT NULL` (12+ uses the validated check as proof).
- New enum values need their own committed transaction before use (pre-12
  restrictions; still safest pattern).

## Write patterns

- Upsert with `INSERT ... ON CONFLICT (key) DO UPDATE`; use `MERGE` (15+) when
  the logic has more branches than upsert covers.
- `RETURNING` on INSERT/UPDATE/DELETE kills the write-then-select round trip.
- `SELECT ... FOR UPDATE SKIP LOCKED` is the canonical job-queue pattern.
- Serialization failures (`40001`) and deadlocks under SERIALIZABLE/REPEATABLE
  READ are retryable by design — wrap in idempotent retry.

## Plans and statistics

- `EXPLAIN (ANALYZE, BUFFERS)` or it did not happen: actual rows vs. estimated
  rows drifting by orders of magnitude means stale or insufficient statistics —
  `ANALYZE` after bulk loads, raise per-column statistics targets, or add
  extended statistics (`CREATE STATISTICS`) for correlated columns.
- `pg_stat_statements` is the triage list — optimize the queries it ranks, not
  the ones that look ugly.

## Connections are processes

- Every connection is a backend process; hundreds of idle connections are real
  memory and scheduler cost. An app-side pool plus PgBouncer (transaction mode)
  is the default architecture — and transaction pooling forbids session state
  (SET, advisory locks, prepared statements need care).

## Version leverage (advise at or below the floor)

- **14** — multirange types; `query_id` unifying pg_stat_statements tracing.
- **15** — `MERGE`; `security_invoker` views (fixes view-permission surprises).
- **16** — `pg_stat_io` for real I/O attribution; faster aggregates/sorting.
- **17** — `JSON_TABLE` (SQL-standard JSON-to-rows); incremental backup;
  big VACUUM memory improvements.
- **18** — `uuidv7()` in core: time-ordered UUIDs end the random-PK index-bloat
  tradeoff — prefer it for new UUID PKs; asynchronous I/O subsystem; `RETURNING
  OLD/NEW` in DML.

Detect the version from `SELECT version();`, docker-compose/CI image tags, or the
managed-service tier before advising; nothing above the floor, no pre-floor
workarounds below it.

## Review checklist

- timestamptz, text, numeric, uuid, jsonb — no timestamp/varchar(n)/float-money.
- FKs indexed; hot predicates match a partial/expression index; CONCURRENTLY for
  every index on a live table.
- Migrations: lock_timeout set, NOT VALID + VALIDATE pattern, no table rewrites
  hidden in innocent-looking ALTERs.
- No idle-in-transaction paths; big writes batched.
- Plans verified with EXPLAIN (ANALYZE, BUFFERS), not asserted.
