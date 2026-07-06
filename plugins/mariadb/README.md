# mariadb

MariaDB 10.6+ best practices: MariaDB-vs-MySQL divergences, `RETURNING`,
sequences, system-versioned tables, the native UUID type, uca1400 collations,
the JSON-as-LONGTEXT reality, and Galera multi-master awareness.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install mariadb@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/mariadb:review [files-or-diff]` | Review MariaDB schemas, queries, and migrations against the skill, pinned to the engine version (`SELECT VERSION();` returns e.g. `11.4.x-MariaDB`, or image tags) |

## Example

```bash
/mariadb:review db/migrations/2026_add_orders_index.sql
/mariadb:review         # reviews the current diff
```

Advice is version-aware: features gate by MariaDB version numbers only (MySQL 8.0
feature lists do not map), and copied-from-MySQL advice is the most common bug it
catches.

## Pairs well with

- **sql** — the engine-agnostic rules underneath this MariaDB-specific layer
- **mysql** — the diverged cousin; same protocol, different engine
- **database** — schema, indexing, and query-optimization workflows
