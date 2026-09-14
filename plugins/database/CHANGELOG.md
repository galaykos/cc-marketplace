# Changelog

All notable changes to the `database` plugin. Entries start at 0.8.3; earlier
releases were not recorded here and are not reconstructed.

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
