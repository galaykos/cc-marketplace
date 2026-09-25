# Changelog

All notable changes to the `database` plugin. Entries start at 0.8.3; earlier
releases were not recorded here and are not reconstructed.

## 0.10.1 — 2026-09-25

### Changed
- `hooks/hooks.json` quotes `${CLAUDE_PLUGIN_ROOT}` in every hook command. Claude Code 2.1.282's `plugin validate --strict` rejects the unquoted form (an install path with a space splits into several words); the marketplace's CI pin moved to 2.1.282 with it.

## 0.10.0 — 2026-09-22

### Fixed
- **The migration-DSL drop row was blind to Rails, GORM and Django**, while the hook's
  own header claimed "every other migration DSL". Three causes, each silencing a whole
  ecosystem: the match was case-SENSITIVE, so GORM's `Migrator().DropTable(` never fired;
  it required a `(`, so Rails' `drop_table :users` never fired; and it listed no Django
  operation, so `migrations.DeleteModel`/`RemoveField`/`DeleteField` never fired. The row
  is now case-insensitive, accepts the Ruby symbol argument form, and carries the three
  Django names. The symbol form requires a space before the `:` and an identifier after
  it — a bare `[(:]` also matched `dropAll: boolean` in a TS interface and
  `dropTable: false` in a config file, both measured, neither a migration.
- **Prisma's `deleteMany()` takes no argument**, so requiring an empty object `({})` made
  the commonest delete-everything shape the one this never asked about. A bare
  `deleteMany()` now asks; the bare-parens form is scoped to `deleteMany` alone, because
  extending it to `remove` would fire on every DOM `element.remove()`.
- The header's coverage claim is now a literal list with its own residual: a drop spelled
  outside that list — `drop_table 'users'` with a quoted string, a name built at runtime —
  passes silently.
- `README.md` said an unanswerable `ask` "stalls a headless run". It does not: with no
  interactive prompt, `ask` is **auto-denied**. Corrected, with the standing named.

### Changed
- Fixtures for all of the above, both directions, in `scripts/__tests__/guard.test.sh`.

## 0.9.3 — 2026-09-22

### Fixed
- `agents/database-engineer.md` rendered its two-skill `bestpractices-skill` list as one
  skill name ("the `sql-best-practices,mariadb-best-practices` skill"); the rubric line
  now names each listed skill in order. Template fixed in the same change.

### Added
- `sql-best-practices` carries three worked bad/good pairs again — sargable predicates,
  NULL three-valued logic, keyset pagination. The 2026-08-27 cap raise to 200 lines was
  justified by restoring these and never did; body is 185 lines.

## 0.9.2

### Fixed
- **The guard's own documentation described a guard three releases out of date.** Its
  header, the README section and the `lane.tsv` trigger all named only
  `DROP`/`TRUNCATE`/unqualified `DELETE`-`UPDATE`, so nothing told a reader that it
  also asks on a Prisma/Drizzle/TypeORM/Doctrine/Knex/Alembic drop (0.9.0), on a
  lock-taking `CREATE INDEX` or table-rewriting `ALTER`, or on the NoSQL twins
  (`deleteMany({})`, `.dropDatabase()`, an off-script DynamoDB `Scan`) — and the
  `lane.tsv` trigger additionally claimed a **column/table RENAME**, which this guard
  has never matched and which stays agent-graded in `sql-best-practices`.
- **The README never named the off-switch.** `CC_DB_GUARD=off` shipped in 0.9.1 and was
  reachable only from the ask message. It is now in the README, with the
  documentation-surface exemption (`.md`, `.txt`, `taskmaster-docs/`) and the
  `command-guard` boundary that `lane.tsv` already encoded.

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
