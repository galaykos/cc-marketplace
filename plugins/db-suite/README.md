# db-suite

Meta-bundle: the database category in one install — engine-agnostic SQL
discipline, MariaDB best practices, and the database
worker agent. Uninstalls cleanly: `/db-suite:uninstall` removes the bundle and
prunes the plugins it auto-installed.

## Install

```bash
/plugin marketplace add galaykos/cc-marketplace
/plugin install db-suite@cc-plugins-marketplace
```

## What's included

- **sql** — engine-agnostic SQL discipline: sargable predicates, join
  correctness, NULL logic, safe migrations, plus `/sql:review`
- **mariadb** — MariaDB 10.6+ divergences from MySQL: RETURNING, sequences,
  system-versioned tables, Galera awareness, plus `/mariadb:review`
- **database** — the database-engineer worker that applies
  schema/migration/indexing work, plus a destructive-statement PreToolUse
  guard; reviewing rides `/sql:review`

| Command | What it does |
|---------|--------------|
| `/db-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **laravel** — Eloquent, migration, and query review on the framework side
- **performance** — query hotspots and cache correctness beyond the schema
- **dev-env** — docker-compose for running the databases locally
