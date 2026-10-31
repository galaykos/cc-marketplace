# Changelog

All notable changes to the `database` plugin. Entries start at 0.8.3; earlier
releases were not recorded here and are not reconstructed.

## 0.11.8 — 2026-10-31

### Fixed
- **A `CREATE INDEX` on MySQL or MariaDB no longer asks for `CONCURRENTLY`.** Every `CREATE INDEX`
  outside a SQLite project asked, labelled "(PostgreSQL; other engines lock regardless)", and advised
  `CREATE INDEX CONCURRENTLY`, which is a syntax error on MySQL and MariaDB, where InnoDB builds a
  secondary index online by default. The guard now reads the engine from the nearest directory, between
  the target's and the project root, holding wrangler's `d1_databases`, a Prisma `provider`, a
  `drizzle.config.*` `dialect`, a compose `image:` line, or `DB_CONNECTION` in `.env`/`.env.example`
  (mysql, mariadb, pgsql; `sqlite` there is still no evidence). SQLite, MySQL and MariaDB: silent.
  PostgreSQL: the same ask and advice as before, labelled "(PostgreSQL)". No engine, or two in that
  directory: the ask names both forms, `CONCURRENTLY` for PostgreSQL and `ALGORITHM=INPLACE LOCK=NONE`
  for MySQL/MariaDB, with Galera's TOI stall. Residual: a Galera cluster's TOI stall on an online build
  is not asked. Harness cases "engine: …" and the two CREATE INDEX "lock reason" cases in
  `guard.test.sh` pin it; nine of them fail against 0.11.7.

## 0.11.7 — 2026-10-28

### Changed
- **Comments cut to what a reader needs; behaviour unchanged.** `hooks/guard.sh` (shared-block comments): each keeps a header saying what it does and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/, which an install does not contain.

## 0.11.6 — 2026-10-28

### Changed
- **Hook comments cut to what a reader needs; behaviour unchanged.** `hooks/guard.sh`: each keeps a header saying what it catches and misses, and one line per trap the code cannot show; the history moved to the marketplace repository's rationale/derivations/plugin-database.md, which an install does not contain. Every hook parses to the same code as before (comments ignored).

## 0.11.5 — 2026-10-26

### Changed
- **The destructive-SQL ask is shorter; which writes ask is unchanged.** It names what the
  change adds, what to confirm (a backup or tested rollback, only the rows you mean, or the
  non-blocking form for a locking change), the file, and `CC_DB_GUARD=off`. Gate:
  `guard.test.sh` pins both texts.

## 0.11.4 — 2026-10-14

### Fixed
- **Tailwind's `truncate` class no longer asks as SQL.** The TRUNCATE rule matched
  `truncate <word>` in any case, so a component line such as `className="truncate text-xs"`
  drew the destructive-SQL ask, repeatedly, in background workers and auto mode with nobody
  to answer it. The rule now fires on an uppercase `TRUNCATE <x>`, or on `truncate table` in
  any case followed by a table name, so the Tailwind pair `truncate table-cell` stays silent
  too. The any-case form also skips a line carrying a class list (`class=`, `className=`,
  `:class=`, `class:`, `clsx(`, `cn(`, `cva(`, `` tw` ``), so `className="truncate table w-full"`
  stays silent; an uppercase `TRUNCATE` still asks on such a line. Residual: a lowercase
  `truncate users` without `TABLE` is no longer asked, and a class string built outside an
  attribute or helper (`const c = "truncate table w-full"`) still asks. Harness cases
  "Tailwind truncate class", "Tailwind truncate table-cell", "className truncate table",
  "Vue :class truncate table", "cn() truncate table", "class string outside a helper",
  "TRUNCATE without TABLE", "lowercase truncate table" and "lowercase truncate table, .sql"
  in `guard.test.sh` pin it; the first fails against 0.11.3.
- **A new create-table migration no longer asks because its `down()` drops the table.** The
  rollback method is the escape this guard's own header grants, yet `Schema::dropIfExists` in
  `down()` drew the destructive-SQL ask on every new migration; sessions stalled 969 s and
  1,454 s on an ask nobody was there to answer. The rollback method is now cut before the text
  is judged, from its opener to the next method: `function down(` in a PHP file under
  `migrations/` (Laravel, Doctrine), `def down` under `db/migrate/` (Rails) and `def downgrade(`
  in `alembic/versions/` or `migrations/versions/` (Alembic), on a Write, an Edit and a Bash
  heredoc alike. A drop in `up()`, or in a helper method declared after `down()`, still asks.
  An opener counts only where it leads its line (PHP's may follow `public`, `protected`,
  `private`, `static` or `final`), so a comment or string in `up()` naming `function down()`
  cuts nothing; and a MultiEdit's edits are cut one by one, so a `down()` added by one edit
  does not hide a drop another edit puts in `up()`.
  Residual: a Knex, TypeORM or Sequelize rollback still asks (their `down` is spelled several
  ways with no line marking where it ends), an Edit or MultiEdit edit whose new text sits
  inside `down()` without the opener still asks, and code sharing a line with the `down()`
  opener is skipped.
  Harness cases "create migration, dropIfExists in down()", "drop in up() still asks", "drop
  in a helper after down() still asks", "down() opener outside migrations/ is not cut", "rails
  def down drop_table", "alembic downgrade drop_table", "alembic drop_table in upgrade still
  asks", "comment naming down() in up() cuts nothing", "string naming down() in up() cuts
  nothing", "multiedit: down() in edit 1 does not cut edit 2's drop", "multiedit: a drop in an
  edit's own down() is still cut" and "bash: create migration written by heredoc, drop only in
  down()" pin it; the five that expect silence fail against the hook before this change.
- **Scratch outside the project no longer asks** (2026-10-15). Scratch probes under `/tmp`
  and a test fake outside the repository drew the ask, because only documentation surfaces
  were exempt. A target under neither `CLAUDE_PROJECT_DIR` nor the payload cwd's root (its git
  toplevel, else `CLAUDE_PROJECT_DIR` when the cwd is under it, else the cwd), or under
  `$TMPDIR` (default `/tmp`) while the root holding it is not there, is now skipped on a Write,
  an Edit and a Bash heredoc alike. `CLAUDE_PROJECT_DIR` counts because the cwd follows the
  shell's `cd`: with the shell in a sibling repo, a `DROP TABLE` migration written into the
  project was skipped on this version's first cut. The rule is the shared
  `templates/blocks/write-scope.md`, which security's `write-scan` carries byte-for-byte. Both
  sides are compared symlink-resolved, and a path not created yet by its nearest existing
  directory. The check runs only for a target that would ask, so a write with no hit costs
  what it did. Residual: a sibling repo or worktree written by absolute path from outside both
  roots is skipped too, and a payload with no cwd and no `CLAUDE_PROJECT_DIR` keeps only the
  temp-dir rule.
- **No CONCURRENTLY ask on SQLite** (2026-10-15). SQLite (Cloudflare D1, Turso) has no
  `CREATE INDEX CONCURRENTLY`, so the lock-hazard ask gave advice that cannot be followed.
  The guard read no project config before. For a `CREATE INDEX` that would ask, it now reads,
  from the target's directory up to the root holding it, wrangler's `d1_databases`, a Prisma
  `provider = "sqlite"` and a `drizzle.config.*` dialect `sqlite` or `turso`; when one names
  SQLite there is no ask. Laravel's `.env` is not read: `DB_CONNECTION=sqlite` is Laravel 11+'s
  default local config, so a PostgreSQL-in-production app lost the ask on this version's first
  cut. A data-loss statement still asks. Residual: with no cwd and no `CLAUDE_PROJECT_DIR`
  nothing is detected; Laravel's `.env`, Rails' `database.yml`, Django settings and a DSN in
  code are not read; a project whose config names SQLite while the migration targets another
  engine is not asked.
  Harness: 23 `guard.test.sh` cases (`scope:` and `sqlite:`); the nine that expect silence fail
  against the hook before this change, and the fourteen that still ask (a target in the
  project, a new dir in it, no cwd outside `$TMPDIR`, a project that lives in `$TMPDIR`, a Bash
  heredoc into the project, `DROP TABLE` on D1, Prisma on PostgreSQL, Laravel on `pgsql` and
  on `sqlite`, a monorepo sibling without the config, a migration into the project and a write
  into the cwd's repo with the shell in a sibling repo) pass on both; of those, the
  sibling-repo migration and Laravel's `sqlite` `.env` were silent on this version's first cut.

## 0.11.3 — 2026-10-04

- **Hook comments cut to contract and limits; behaviour unchanged.** The shared blocks in `hooks/guard.sh` keep each function's contract and limits in a few lines; the derivations and history moved to the marketplace repository's `rationale/`. The hook parses to the same code as before, compared by bash's own parser with comments ignored.
- The `database-engineer` agent's code-shape rule adds required call order to the docblock facts a signature cannot state (units, ownership, what throws). Its effect on what the agent writes is unmeasured.

## 0.11.2 — 2026-10-01

- The shared Bash-write parsers end a command at a lone `&`. Text a command writes after a backgrounded one is now read (`sleep 1 & echo "<text>" > f` was skipped), and a heredoc body is no longer judged as the content of a file a later command on the same line writes (in `cat <<EOF & echo done > log.txt` the body was attributed to `log.txt`). The destructive-SQL guard carries both updated blocks.
- Not read: text in a command that a `&` inside `$(( ))` or `${ }` ends early.

## 0.11.1 — 2026-10-01

- The destructive-SQL guard carries the updated shared Bash-write parser: the shared `cc_bash_write_targets` block now returns every file a `sed -i` / `perl -i` command edits instead of its last word, never a trailing redirect (`sed -i … tsconfig.json 2>/dev/null` used to yield `2>/dev/null`), and recognises GNU `--in-place[=SUF]` and BSD `-I`.
- What the guard judges on Bash is unchanged: heredoc bodies and `echo`/`printf` text. The result of a `sed -i` edit is still not read.

## 0.11.0 — 2026-09-30

- **Off-switches are now `/config` options:** `cc_db_guard`, under `/config` (or `/plugin configure database`), each with today's default. The environment variable (`CC_DB_GUARD`) still overrides its option. An interactive `/plugin install` now shows a Configure dialog for these options; it is optional — Esc keeps the defaults.

## 0.10.2 — 2026-09-29

### Fixed
- **The destructive-SQL guard was blind to files written through Bash.** Its matcher was
  `Write|Edit|MultiEdit`, so `cat > db/migrations/0003.sql <<'SQL'` carrying a `DROP TABLE`
  was never read, while the same text through Write asked. The matcher now includes
  `Bash`: a heredoc body or echo/printf text whose pipeline writes a file is judged by the
  same patterns as a Write (now one `judge_sql` function both paths call), with the same
  doc-surface exemption applied to the written path, and the ask names that file. The
  shared `cc_bash_write_targets` and `cc_bash_write_chunks` blocks are pasted verbatim.
- **Boundary:** SQL fed to a SQL client is not scanned, whether the client writes no file
  (`psql <<EOF`, `mysql -e`) or its output is logged (`psql <<EOF > run.log`) — it stays
  `command-guard`'s, the `yields_to` edge in `lane.tsv`, so one `psql` call never asks
  twice. A relative Bash target is joined to the payload `cwd` before the doc-surface and
  script-path tests, so it is classified as a Write of the same file would be.
- **Not caught on Bash**, named in the hook header: interpreter writes (python `open()`,
  php `file_put_contents`), `cp`/`mv`/`install` of a file already holding the statement,
  `sed -i`/`perl -i` substitution text, a relative target after an in-command `cd`, a
  doc surface listed first in a multi-target `tee`, `{ …; } > f` groups, a path held in a
  variable, here-strings, printf format
  substitution, a quoted string or `\` continuation spanning lines, and a second heredoc
  opened on one line.
- Latency, non-write Bash: 17.4 ms median, 18.7 ms max (20 runs).

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
