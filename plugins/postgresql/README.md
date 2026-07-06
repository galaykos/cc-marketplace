# postgresql

PostgreSQL 14+ best practices: MVCC and vacuum reality, rich native types
(`timestamptz`, `jsonb`, `uuid`, `numeric`), the index arsenal (partial,
expression, covering, GIN, BRIN, `CONCURRENTLY`), lock-aware migrations,
`ON CONFLICT`/`RETURNING`, and connection pooling.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install postgresql@cc-plugins-marketplace
```

## Commands

| Command | What it does |
|---------|--------------|
| `/postgresql:review [files-or-diff]` | Review Postgres schemas, queries, and migrations against the skill, pinned to the engine version (`SELECT version();`, image tags, or service tier) |

## Example

```bash
/postgresql:review db/migrations/2026_add_orders_index.sql
/postgresql:review         # reviews the current diff
```

Advice is version-aware: 14 is the floor and guidance extends through 17/18 —
features are suggested at or below the resolved version.

## Pairs well with

- **sql** — the engine-agnostic rules underneath this Postgres-specific layer
- **mysql / mariadb** — sibling engine plugins for cross-database work
- **database** — schema, indexing, and query-optimization workflows
