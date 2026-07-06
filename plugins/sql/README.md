# sql

Engine-agnostic SQL best practices: sargable predicates, join correctness,
composite index logic, NULL three-valued traps, transaction and isolation
discipline, constraints as truth, keyset pagination, additive migrations, and
parameterized queries.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install sql@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/sql:review [files-or-diff]` | Review queries and migrations against the engine-agnostic skill; engine-specific rules live in the mysql/mariadb/postgresql plugins |

## Example

```bash
/sql:review db/migrations/2026_add_orders_index.sql
/sql:review         # reviews the current diff
```

## Pairs well with

- **postgresql / mysql / mariadb** — engine-specific rules on top of these generic ones
- **database** — schema, indexing, and query-optimization workflows
