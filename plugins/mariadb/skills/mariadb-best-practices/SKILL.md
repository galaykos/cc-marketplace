---
name: mariadb-best-practices
description: Use when writing or reviewing MariaDB 10.6+ schemas, queries, or migrations — MariaDB-vs-MySQL divergences, RETURNING clauses, sequences, system-versioned tables, native UUID type, uca1400 collations, JSON-as-LONGTEXT reality, Galera multi-master awareness. Generic SQL rules live in the sql plugin; MySQL-specific rules in the mysql plugin.
---

## MariaDB is not MySQL

Same wire protocol, diverged engines since 5.5 — the most common MariaDB bug in
review is advice copied from MySQL 8 docs. Verify with `SELECT VERSION();`
(returns e.g. `11.4.x-MariaDB`), or image tags in docker-compose/CI. Feature-gate
by MARIADB version numbers only; MySQL 8.0 feature lists do not map. Notable
divergences to catch:

- No `utf8mb4_0900_*` collations — those are MySQL-only. MariaDB's modern
  equivalents are the `uca1400` family (10.10+); before that, `utf8mb4_unicode_ci`.
- JSON is an alias for LONGTEXT with functions, not a binary type — no MySQL-style
  binary JSON storage or multi-valued indexes; index JSON paths via generated
  columns, and guard shape with `CHECK (JSON_VALID(col))`.
- Optimizer, EXPLAIN output, and histogram handling differ — tune against
  MariaDB's own `ANALYZE FORMAT=JSON`, not MySQL plan folklore.

## Version floors that matter

Pin advice to the installed version; the useful floors:

- **10.3** — sequences (`CREATE SEQUENCE`, `NEXTVAL`) replace roll-your-own
  counter tables; system-versioned tables (`WITH SYSTEM VERSIONING`) give
  audit/history for free — query the past with `FOR SYSTEM_TIME AS OF`.
- **10.5** — `INSERT ... RETURNING` and `DELETE ... RETURNING`: fetch generated
  ids or removed rows in one round trip instead of insert-then-select.
- **10.6 (LTS baseline)** — `JSON_TABLE`; ignored indexes (test removal safely).
- **10.7** — native `UUID` type: stores compactly, sorts sanely — use it instead
  of `CHAR(36)`; `INET4`/`INET6` types for addresses.
- **10.8** — descending index support: `ORDER BY a ASC, b DESC` can finally be
  served by one index; before that, mixed-direction sorts filesort.
- **10.10+ / 11.x** — uca1400 collations as the modern default; 11.x continues
  optimizer changes — re-verify hot plans after major upgrades.
- **10.11 and 11.4** — the LTS anchors; pick an LTS floor for new deployments
  and feature-gate against it, not against whatever the newest release added.

## InnoDB fundamentals still apply

- Clustered PK: rows stored in PK order, secondary indexes carry the PK — keep
  PKs short and insert-ordered. With 10.7+, the native UUID type plus UUIDv7-style
  generation (or sequences) avoids the random-PK page-split tax.
- Index every FK; join columns must match type AND collation — mixing an old
  `utf8mb4_general_ci` table with a new uca1400 one silently kills join indexes.
- `ALTER TABLE` supports instant/inplace algorithms for many operations — state
  `ALGORITHM=INSTANT`/`INPLACE` explicitly in migrations so a fallback to a
  copying ALTER fails loudly instead of locking a hot table silently.

## Strictness and modes

- Keep `STRICT_TRANS_TABLES` and `ONLY_FULL_GROUP_BY` in sql_mode; without them
  MariaDB truncates silently and picks arbitrary GROUP BY rows.
- `sql_mode=ORACLE` exists for migrations off Oracle — do not enable it on a
  fresh project; it changes semantics broadly (empty string vs NULL, etc.).

## System-versioned tables in practice

- Ideal for audit requirements: `ALTER TABLE ... ADD SYSTEM VERSIONING` and the
  engine maintains history on every write.
- History rows live in the same table by default — partition them
  (`PARTITION BY SYSTEM_TIME`) so current-data scans do not pay for history.
- Excluded columns (`WITHOUT SYSTEM VERSIONING`) for high-churn noise fields keep
  history meaningful and small.

## Galera awareness (when clustered)

- Multi-master means optimistic certification: two nodes writing the same rows
  produce deadlock-style certification failures — treat them as retryable, keep
  transactions small, and route hot-row writers to one node.
- Large transactions are amplified across the cluster; batch backfills in small
  chunks. Schema changes need a strategy (rolling vs. total-order) chosen, not
  defaulted.

## Time, charset, replication

- Same UTC discipline as any engine: store UTC, convert at the edge; TIMESTAMP
  carries 2038 and session-zone conversion caveats, DATETIME stores literally.
- Declare `DATETIME(6)` where ordering or dedup needs sub-second precision —
  default precision silently truncates to whole seconds.
- `utf8mb4` everywhere; bare `utf8` is the same 3-byte trap as MySQL's.
- GTID replication is the baseline; replicas lag — read-your-own-write flows read
  the primary.

## Plans over folklore

- `ANALYZE FORMAT=JSON` (MariaDB's actual-execution EXPLAIN) on every query you
  claim is fast: check access type, rows examined vs. returned, and whether the
  chosen index matches the composite-order logic from the sql plugin.
- After major-version upgrades (10.x → 11.x), re-check the top hot queries; the
  optimizer changes are real and plans move.

## Review checklist

- Version detected and MariaDB-confirmed; no MySQL-only features or collations.
- RETURNING used instead of insert-then-select round trips (10.5+).
- Sequences over counter tables (10.3+); native UUID over CHAR(36) (10.7+).
- JSON columns have `CHECK (JSON_VALID(...))` and generated-column indexes for
  hot paths.
- Migrations state ALGORITHM explicitly; Galera deployments batch writes and
  treat certification failures as retries.
- Performance claims carry `ANALYZE FORMAT=JSON` evidence — rows examined vs.
  returned, and the index actually chosen.
