---
name: mysql-best-practices
description: Use when writing or reviewing MySQL 8.0+ schemas, queries, or migrations — InnoDB clustered-PK design, utf8mb4 and collations, strict sql_mode, online DDL and metadata locks, gap locking, JSON usage limits, version leverage 8.0 to 8.4 LTS. Generic SQL rules live in the sql plugin; MariaDB is NOT MySQL — see the mariadb plugin.
---

## Know the version first

`SELECT VERSION();` when a connection exists; otherwise docker-compose/CI image
tags, or the managed-service tier in infra config. Confirm it is MySQL and not
MariaDB — same wire protocol, diverged engines; MySQL 8.x advice misapplies.
Pin advice to the version: 8.0 is the floor here; 8.4 is the LTS line with
changed defaults (`mysql_native_password` disabled — plan auth plugin migration);
5.7-era advice (query cache tuning, utf8 tricks) is dead — the query cache was
removed in 8.0.

## InnoDB and primary key design

- InnoDB only; any other storage engine needs a written justification.
- The PK IS the table (clustered index): rows are stored in PK order, and every
  secondary index carries the PK as its pointer. Consequences:
  - Keep PKs short — a fat composite PK bloats every secondary index.
  - Random PKs (UUIDv4 strings) cause page splits and cache misses; use
    AUTO_INCREMENT, or store UUIDs as `BINARY(16)` via `UUID_TO_BIN(uuid, 1)`
    (the swap flag makes them insert-ordered).
- Access-pattern-first: the query that must be fastest defines the clustered
  order; everything else gets a secondary index.

## Charset and collation

- `utf8mb4` everywhere; MySQL's `utf8` is a 3-byte lie that rejects emoji and
  astral-plane characters. Default collation `utf8mb4_0900_ai_ci` (8.0+).
- Collation mismatches between joined columns force per-row conversion and kill
  indexes — one charset/collation pair per schema unless a column can prove
  otherwise.

## sql_mode stays strict

- Keep `STRICT_TRANS_TABLES` and `ONLY_FULL_GROUP_BY` on (8.0 defaults). Turning
  them off converts errors into silent truncation and arbitrary-row GROUP BY
  results. Fix the query, not the mode.

## Version leverage (advise at or below the floor)

- **8.0** — CTEs and window functions (kill derived-table pyramids and
  self-joins); `EXPLAIN ANALYZE` (8.0.18) shows actual rows/timing, not
  estimates; enforced `CHECK` constraints (8.0.16); functional and invisible
  indexes (test index removal safely by making it invisible first);
  `ALTER TABLE ... ALGORITHM=INSTANT` for adding columns; multi-valued indexes
  over JSON arrays; `SELECT ... FOR UPDATE SKIP LOCKED` for job queues.
- **8.4 LTS** — deprecations land: `mysql_native_password` off by default,
  replication terminology and defaults updated. Target 8.4 for new deployments;
  audit auth plugins and replication options when upgrading.

## Locking realities

- Default isolation REPEATABLE READ uses gap locks — range predicates in
  transactions lock the gaps between rows; contention bugs often trace here.
  READ COMMITTED is a legitimate choice for OLTP if the app tolerates it.
- DDL takes metadata locks: one long-running SELECT blocks the ALTER, which then
  blocks everything after it. Check `performance_schema.metadata_locks`, keep
  transactions short, and set `lock_wait_timeout` low in migrations.
- Online DDL first: `ALGORITHM=INSTANT` (column add and more in 8.0.29+), else
  `INPLACE`; when neither applies on a big hot table, use gh-ost or pt-osc
  rather than locking for the rewrite.

## JSON discipline

- JSON columns are for genuinely schemaless payloads; the moment a JSON path is
  in a WHERE clause on a hot query, promote it to a generated column with a real
  index (`col JSON, extracted VARCHAR(64) AS (col->>'$.key') STORED, KEY(...)`)
  or a multi-valued index for arrays.
- `JSON_TABLE` (8.0) turns JSON into rows for set-based processing — better than
  app-side loops over blobs.

## Time and replication

- `TIMESTAMP` converts to/from session time zone and ends in 2038; `DATETIME`
  stores what you wrote. Pick one convention: store UTC in DATETIME (or
  TIMESTAMP with all sessions pinned UTC) and convert at the display edge.
- `DATETIME`/`TIMESTAMP` default to second precision — declare `DATETIME(6)`
  where ordering or dedup needs microseconds; bare columns silently truncate.
- Row-based replication with GTIDs is the baseline. Read replicas lag: any
  read-your-own-write flow must read the primary or wait for the GTID.
- `CREATE TABLE ... AS SELECT` breaks under GTID replication — ship explicit
  schema plus `INSERT ... SELECT` instead.

## EXPLAIN before trusting

- `EXPLAIN FORMAT=TREE` / `EXPLAIN ANALYZE` on every query you claim is fast:
  check access type (avoid full scans on hot paths), key used, and rows examined
  vs. rows returned — a 10,000:1 ratio is a missing index or a wrong one.
- `performance_schema` + `sys` schema (e.g. `sys.statements_with_full_table_scans`)
  find the queries worth fixing; optimizing without them is guessing.
- On deadlocks, read `SHOW ENGINE INNODB STATUS` (LATEST DETECTED DEADLOCK
  section) before adding retry loops — the fix is usually consistent lock
  ordering or a missing index, not more retries.

## Review checklist

- PK short and insert-ordered; no random-UUID string PKs.
- Every FK indexed; join columns same type AND collation.
- utf8mb4 everywhere; no bare `utf8`.
- Strict sql_mode assumed; no queries that need it off.
- Migrations state their ALGORITHM and fall back to gh-ost/pt-osc, never a
  blocking rewrite on a hot table.
- No feature above the detected version; no 5.7 folklore below it.
