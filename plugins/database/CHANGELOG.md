# Changelog

All notable changes to the `database` plugin. Entries start at 0.8.3; earlier
releases were not recorded here and are not reconstructed.

## 0.9.1

### Fixed
- **The destructive-schema guard now has an off-switch**, `CC_DB_GUARD=off`. It previously had none, which matters most under a hands-off run where an unanswered `ask` stalls.

## 0.9.0

### Added
- **The guard recognises migration DSLs other than Laravel's.** It knew SQL keywords and
  `Schema::drop*`, which meant a Prisma, Drizzle, TypeORM, Doctrine, Knex or Alembic
  repo — every JS/TS and Python project this plugin claims to serve — got no ask on a
  drop, because none of those tools emits the SQL this guard was reading. `dropTable`,
  `dropTableIfExists`, `drop_table`, `dropSchema`, `drop_schema`, `dropAll` and
  `drop_all` now fire the same ask, with the same escape: a `down()` legitimately drops.
## 0.8.3

### Fixed
- **The destructive-SQL guard was blind to Laravel's `Schema::drop*`.**
  `Schema::dropIfExists('users')` in a migration's `up()` is `DROP TABLE users`
  spelled without the keywords, and the guard matched keywords only — so the one
  migration shape an agent writes most in a Laravel repo was the one it never asked
  about. `Schema::drop`, `dropIfExists`, `dropAllTables`, `dropAllViews`,
  `dropDatabase` and `dropDatabaseIfExists` now draw the same `ask` as `DROP TABLE`;
  `Schema::table(...)->dropColumn(...)` does not (a column, not a table). Four
  harness cases.
