# db-suite

Meta-bundle: the database category in one install — engine-agnostic SQL
discipline, MySQL, MariaDB, and PostgreSQL best practices, and the database
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
- **mysql** — MySQL 8.0+ specifics: InnoDB clustered-PK design, strict
  sql_mode, online DDL, gap locks, plus `/mysql:review`
- **mariadb** — MariaDB 10.6+ divergences from MySQL: RETURNING, sequences,
  system-versioned tables, Galera awareness, plus `/mariadb:review`
- **postgresql** — PostgreSQL 14+ reality: MVCC/vacuum, the index arsenal,
  lock-aware migrations, ON CONFLICT/RETURNING, plus `/postgresql:review`
- **database** — engine-agnostic schema/migration/indexing design, the
  database-engineer worker, a destructive-statement PreToolUse guard, plus
  `/database:review`

| Command | What it does |
|---------|--------------|
| `/db-suite:uninstall` | Uninstall the bundle AND prune every plugin it auto-installed — one step, no orphans; manually installed plugins are never touched |

## Pairs well with

- **laravel** — Eloquent, migration, and query review on the framework side
- **performance** — query hotspots and cache correctness beyond the schema
- **dev-env** — docker-compose for running the databases locally
