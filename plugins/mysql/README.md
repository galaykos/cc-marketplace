# mysql

MySQL 8.0+ best practices: InnoDB clustered-PK design, utf8mb4 and collations,
strict `sql_mode`, online DDL and metadata locks, gap locking, JSON limits, and
`EXPLAIN ANALYZE` — with version leverage across 8.0 to 8.4 LTS.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install mysql@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/mysql:review [files-or-diff]` | Review MySQL schemas, queries, and migrations against the skill, pinned to the engine version (`SELECT VERSION();`, image tags, or service tier) |

## Example

```bash
/mysql:review db/migrations/2026_add_orders_index.sql
/mysql:review         # reviews the current diff
```

Advice is version-aware: 8.0 is the floor and 8.4 is the LTS line with changed
defaults (e.g. `mysql_native_password` disabled) — features are suggested at or
below the resolved version, and MariaDB is flagged as not-MySQL.

## Pairs well with

- **sql** — the engine-agnostic rules underneath this MySQL-specific layer
- **mariadb** — the diverged cousin; same protocol, different engine
- **database** — schema, indexing, and query-optimization workflows
