# database hooks: the comment text moved out of the code (2026-10-28)

The text below was moved verbatim on 2026-10-28 from the hooks named in the `##` headings, with only each comment's `# ` leader (and the indentation before it) removed. Each `###` block is a comment block, or a contiguous part of a header, as it stood; the file kept a short summary in its place (a header of at most three lines, a one-line trap), or nothing where the code already says it. A pointer by name was left in each file's header, `# Why, limits, history: rationale/derivations/plugin-database.md § <path>`. Standing: `recorded` — no gate reads this file, and its dates, measurements, line citations and file names are as they stood on the day it moved.

## plugins/database/hooks/guard.sh

### Header

```text
Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
PreToolUse destructive-SQL guard — the name its ask message and the README use. On a
Write/Edit that introduces one of the shapes below it returns permissionDecision
"ask", so the user confirms a backup or a tested rollback exists first. It does NOT
hard-deny: a down-migration legitimately drops, and a deny that fires on the
legitimate case is a deny that gets turned off.

WHAT IT MATCHES, in priority order (the first hit wins the message; relational data
loss outranks a lock hazard, which outranks the NoSQL analogues):
  1. DATA LOSS — DROP TABLE/DATABASE/SCHEMA, TRUNCATE (uppercase, or any-case
     `truncate table`; a lowercase `truncate users` is missed), an unqualified DELETE/UPDATE
     with no WHERE on the line; Laravel's `Schema::drop*(`; and the LISTED drop
     spellings of the other migration DSLs, matched case-insensitively and followed
     by `(` or a Ruby symbol `:` — `dropTable`, `dropTableIfExists`, `drop_table`,
     `dropSchema`, `drop_schema`, `dropAll`, `drop_all`, plus Django's `DeleteModel`,
     `RemoveField` and `DeleteField` (Prisma, Drizzle, TypeORM, Doctrine, Knex,
     Alembic, Rails, GORM, Django). Plus the NoSQL twins: `deleteMany` / `updateMany`
     / `remove` with an EMPTY filter `({})`, a bare `deleteMany()` (Prisma's
     delete-everything call takes no argument at all), and `.drop()` /
     `.dropCollection()` / `.dropDatabase()` / `.dropIndexes()` called with no
     arguments.
  2. LOCK HAZARD — `CREATE [UNIQUE] INDEX` with no `CONCURRENTLY`, a table-rewriting
     `ALTER` (column TYPE change or `SET NOT NULL`), and a DynamoDB `Scan` whose path
     does not look like a script (`script`, `migration`, `seed`, `backfill`, `bin/`,
     `tools/`, `__tests__`, `.test.`, `.spec.`). Same ask tier, a different message:
     these do not lose data, they hold a lock or read the whole table per request.

WHAT IT DOES NOT MATCH, stated because the README tiers this an ask:
  - A migration's rollback method: `function down(` in a PHP file under migrations/, `def down`
    under db/migrate/, Alembic's `def downgrade(` — skipped up to the next method (judge_sql says why).
  - A RENAME of a column or table. The expand→migrate→contract rule for that lives
    in `sql-best-practices` § Migrations and is agent-graded; no regex here reads it.
  - Documentation surfaces. `.md`, `.mdx`, `.markdown`, `.txt`, `.rst` and anything
    under `taskmaster-docs/` exit early: a card or spec that QUOTES a migration
    executes nothing, and gating them would storm one permission prompt per card and
    stall a headless run that has nobody to answer "ask".
  - A drop spelled outside the list above — the alternation is literal, not "every
    DSL". `drop_table 'users'` with a quoted string instead of a Ruby symbol, a name
    built at runtime, or an ORM that spells it some third way, passes silently.
  - A destructive statement run through Bash with no file written (`psql <<EOF`,
    `mysql -e`, `sqlite3 db 'DROP …'`), or fed to a SQL client whose output is logged
    (`psql <<EOF > run.log`, `… | psql > out.log`) — that stays `command-guard`'s
    territory, which is why this row yields to it in lane.tsv.
  - BASH WRITES (0.10.2): heredoc bodies and echo/printf arguments whose pipeline writes
    a file are scanned like a Write (cc_bash_write_chunks + cc_bash_write_targets), with
    the same doc-surface exemption applied to the written path (a relative target is
    joined to the payload cwd first, as a Write's path is absolute). NOT caught:
    interpreter writes (python open(), php file_put_contents), cp/mv/install of a file
    already holding the statement, `sed -i`/`perl -i` substitution text, `{ …; } > f`
    groups, a path held in a variable, a relative target after an in-command `cd`, a
    doc surface listed first in a multi-target `tee` (only a writer's first target is
    classified), a here-string, printf format substitution, a quoted string or `\`
    continuation spanning lines, and a second heredoc opened on one line.
  - Single-line matching: a DELETE whose WHERE sits on the next line still asks
    (false positive, accepted), and a filter built across lines never does.
  - Scratch (0.11.4): a target under neither CLAUDE_PROJECT_DIR nor the payload cwd's root, or
    under $TMPDIR (default /tmp) while the root holding it is not (the write-scope block).
  - A CREATE INDEX without CONCURRENTLY in a project whose config names SQLite (D1 via
    wrangler, Prisma, Drizzle; sqlite_project lists what it reads).

CC_DB_GUARD=off disables it for the session, and the ask message says so.
CC_DB_GUARD unset: the /config option cc_db_guard decides.
Fail-open: any error or missing jq allows the write.
```

### The off-switch

```text
OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
uninstalling the plugin. Every other guard in the marketplace ships one,
and a global install makes "turn it off here" a real need.
```

### Scratch targets: scope_init and out_of_scope

```text
Scratch is not the project: CREATE INDEX probes under /tmp and a test fake outside the repo asked in real sessions.
security's write-scan skips the same targets (the write-scope block). Computed only for a target that would ask.
```

### sqlite_project

```text
SQLite has no CREATE INDEX CONCURRENTLY, so that advice is wrong there. The guard read no project config before; this reads,
only for a CREATE INDEX that would ask, from the target's directory up to the root holding it (cc_scope_root): wrangler's
d1_databases (D1 is SQLite), a Prisma provider "sqlite", a drizzle.config.* dialect sqlite or turso. Laravel's .env is not
read: DB_CONNECTION=sqlite is Laravel 11+'s default local config, whatever production runs.
Residual: no root, no detection; another config (Rails database.yml, Django settings, a DSN in code) is not read; a project
whose config names SQLite while the migration targets another engine is not asked.
```

### db_engine (2026-10-31, database 0.11.8; replaced sqlite_project)

```text
Every CREATE INDEX outside a SQLite project asked for CONCURRENTLY, labelled "(PostgreSQL; other engines lock regardless)".
On MySQL and MariaDB that is wrong twice: CONCURRENTLY is not in their CREATE INDEX grammar, and InnoDB creates a secondary
index in place with concurrent DML permitted, by default. Sources read 2026-10-31: MySQL 8.4 and 9.7 "Online DDL Operations"
(Creating or adding a secondary index: In Place Yes, Permits Concurrent DML Yes; "The table remains available for read and
write operations while the index is being created"); MySQL 8.4 CREATE INDEX syntax ([algorithm_option | lock_option] ...);
MariaDB "InnoDB Online DDL Operations with the INPLACE Alter Algorithm" (a plain index: INPLACE, not rebuilt, LOCK=NONE
supported) and "InnoDB Online DDL Overview" (no ALGORITHM/LOCK means the most efficient algorithm and least restrictive lock;
an explicit INPLACE or NONE the operation cannot honour raises an error); MariaDB Galera "Performing Schema Upgrades" (TOI,
the default, blocks the entire cluster and stops write transactions on every node during the change).
db_engine keeps sqlite_project's walk and its sources, adds the other families' values there, a compose image: line and
DB_CONNECTION in .env, then .env.example (mysql, mariadb, pgsql; sqlite stays no evidence). The nearest directory holding any
evidence decides; two families in it, or none up to the root, is unknown, and the unknown ask names both engines' forms.
Residual: a FULLTEXT or SPATIAL index (LOCK=SHARED on InnoDB) was never matched; a Galera cluster's TOI stall on an online build
is not asked, since no config read here says Galera; an image name that merely contains an engine (prom/mysqld-exporter)
counts; the MariaDB page does not name UNIQUE indexes, which are treated as plain ones.
```

### judge_sql: the rollback-method cut

```text
A migration's rollback method drops what its up() made, yet the ask fired on it: every new
create-table migration asked because its down() drops the table, and sessions stalled 969 s and
1,454 s on an ask nobody was there to answer. That method is cut before judging, from its opener
to the next method, so a drop in up() or in a helper still asks. Covered: PHP under migrations/
(Laravel, Doctrine) `function down(`, Rails db/migrate `def down`, Alembic `def downgrade(`.
Each opener must lead its line, so a comment or string naming it cuts nothing, and the cut
restarts at a \036 line: MultiEdit's edits land apart, so one edit's down() is not another's.
Residual: an Edit or MultiEdit edit whose new text sits inside down() without the opener still
asks, a Knex, TypeORM or Sequelize rollback still asks, and code sharing a line with the down()
opener is skipped.
```

### judge_sql: what a rollback may drop (2026-11-08, database 0.11.10)

```text
Retro 2026-11-05 #19 (session 24d655d6, 10-29): the ask fired on the down() of a new
create-table migration. Its message read "this change introduces", the wording before
0.11.5, so that session ran 0.11.4 or older; on 0.11.9 the same migration was already
silent. What 0.11.9 got wrong in the other direction: the cut dropped EVERY rollback,
so a down() destroying a table the migration never made, `Schema::table('users', …)`
in up() and `Schema::dropIfExists('users')` in down(), passed in silence. Reproduced
on 0.11.9 for Laravel, Rails and Alembic.

A create migration is defined by what up() (the text outside the rollback) creates:
`Schema::create(<arg>`, `createTable(<arg>` (Doctrine's $schema), `create_table <tok>`
(Rails, Alembic's op.create_table, newlines folded so autogenerate's multi-line call
counts) and `CREATE TABLE [IF NOT EXISTS] <name>` (DB::statement, addSql, execute).
The rollback is still cut from judging, but rollback_drops reads its drops first, in
the shapes the drop rules already match: Schema::drop(IfExists)(<arg>,
dropTable(IfExists)(<arg>, drop_table(<tok> / drop_table :<tok>, DROP TABLE [IF EXISTS]
<a>[, <b>…]. A drop naming no created table asks, and so does any drop with no single
name (dropAllTables, dropDatabase, DROP DATABASE/SCHEMA, dropAll, drop_all).

Names compare as written, lowercased, with quotes, backslashes, brackets, spaces and
a Ruby symbol's `:` removed, so `$tableNames['roles']` in up() matches the same
expression in down() without evaluating it. An argument is cut at its first `,` or
`)`, the same way on both sides, so `config('x.y')` matches itself.

An Edit's new_string is a fragment, usually the down() alone: the target file on disk
(PreToolUse, so before the edit) supplies what up() creates. A Write and a Bash write
carry the whole file. Busybox awk ends a bracket expression at `\]`, so nm() puts `]`
first; that one case failed under busybox before the change.

Review fixes, same day, each reproduced by running the hook first. The cut skipped its
opener line, so a one-line rollback, `public function down(): void {
Schema::dropIfExists('users'); }`, Rails' `def down; drop_table :users; end`, Alembic's
`def downgrade(): op.drop_table("user")`, was read by nothing; the opener line now belongs
to the rollback. The cut also hid down() from every other rule, so
`DB::statement('TRUNCATE TABLE users')` there was silent; now only the drop rules (DROP
TABLE/DATABASE/SCHEMA, Schema::drop*, the DSL drops) read the text with the rollback cut
out, and every other rule reads it whole. A create that may never run counted as made:
`CREATE TABLE IF NOT EXISTS`, `if_not_exists` on a create_table line (Rails, Alembic), a
create of a name tested by hasTable(, table_exists? or has_table(, and a create in a
comment (`//` or `#` led by a blank, `;`, `{` or `}`, `/* … */`, a `*`-led docblock line);
none counts now. For an Edit or MultiEdit the file on disk is read with the call's own
replacements applied (each old_string replaced once, every one under replace_all, done in
jq with split/join so no character is a pattern), so a MultiEdit turning
Schema::create('users') into Schema::table('users') leaves no create behind. A jq without
--rawfile (older than 1.6) reads the file unedited, the behaviour before the fix.

Residual: schema-qualified on one side only (`public.users` vs `users`) asks; a
bracket-quoted SQL Server name (`[dbo].[users]`) asks; a create through
Schema::connection(...)->create pairs with a drop no rule reads either. A create in a
Python docstring, in a block comment whose lines are not `*`-led, or after a SQL `--`
still counts, and so does Alembic's `if_not_exists=True` on a line of its own. A name
tested anywhere in up() is dropped from the creates, so an unconditional create beside
an unrelated test of the same name asks. Comments are stripped on the create side only:
a drop commented out inside down() still asks.
```

### judge_sql: SQL contexts (2026-11-08, database 0.11.10)

```text
Retro 2026-11-05 #19 (session 86fd417d): three React/TSX writes (app-logo.tsx,
team-switcher.tsx, user-dropdown-menu.tsx from Laravel's React starter kit) asked
"this change introduces TRUNCATE" and the run idled 20 min. Re-tested: the
starter-kit class lists (`className="mb-0.5 truncate leading-tight …"`) ask on the
guard before 0.11.4 with that exact message and are silent on 0.11.9. The nearest
shapes that still asked on 0.11.9, all in .ts/.tsx: an enum member `TRUNCATE = "…"`,
button text `TRUNCATE the log view`, "Drop table rows here", "Delete from favorites",
"Update your account and set a new password", a link titled "Create index page",
a `// TODO: drop table …` comment, and `/TRUNCATE (\w+)/.exec(line)`.

So the SQL-keyword rules (DROP TABLE/DATABASE/SCHEMA, TRUNCATE, DELETE/UPDATE without
WHERE, CREATE INDEX, the rewriting ALTER) read the whole text only in a SQL context:
a .sql/.pgsql/.psql/.ddl file, or a path under migrations/, migration/, db/migrate/
or alembic/. Anywhere else they read sql_spans: from a raw-query opener (query(,
execute(, exec(, raw(, statement(, unprepared(, prepare(, addSql(, $executeRaw`,
sql`, DB::select|insert|update|delete( and the driver variants) or a line naming a
SQL client (psql, mysql, mariadb, sqlite3, sqlcmd, clickhouse-client) to where its
parentheses and quotes close, across lines, with a heredoc it opens (<<SQL, <<<SQL,
<<~SQL) to its terminator. `//` and a whitespace-led `#` end a line's scan, so an
apostrophe in a comment does not hold the span open. The opener must not follow a
word character, so useQuery( is no opener; RegExp .exec( opens one, which closes on
its own line. The migration-DSL rows and the NoSQL rows keep reading the whole text:
they match calls, not words a sentence can contain.

Trade, pinned in the harness: SQL built in a variable and passed later
(`const q = "TRUNCATE TABLE x"; await pool.query(q)`) asked before and is now silent.
Review fix, same day: the call list missed common driver APIs, each asking on 0.11.9
and silent on the first cut: Doctrine DBAL 3's executeStatement(, Python sqlite3's
executescript(, node-sqlite3's db.run(", PHP's mysqli_query( and pg_query(, peewee's
execute_sql(, diesel's sql_query(, postgres.js's sql.unsafe(, JPA's createNativeQuery(,
and the clients pgcli, duckdb and `wrangler d1 execute`. Added, with any `*_query(` name;
`.run(` only with a string literal opening its argument, since `scope.run(() => {…})`
would hold the span open across a callback full of UI text. The span also started at
the opener, so SQL earlier on its line was dropped: `em.createQuery("DELETE FROM t")
.executeUpdate()`, `echo "DROP TABLE x;" | psql`. A client line, and a call chained on a
call result (`)` then `.`, `?.` or `->` before the name), now print from the line start;
any other opener prints from itself, so `/TRUNCATE (\w+)/.exec(line)` stays silent.

Residual: a raw-call opener whose parenthesis never closes runs the span to the end
of the edit; a regex literal holding a quote inside a span; a UI file under a
migrations/ directory is read as SQL; a Ruby heredoc after `execute(<<~SQL)`, whose
body follows the closed call; Java's jdbcTemplate.update( and C#'s CommandText;
pg_query_params(, mycli, litecli, usql and any other call or client off the list;
db.run(sql) with the statement in a variable or on the next line; SQL on the line
above a chained opener that leads its own line; UI text naming a client (`mysql `)
reads its whole line as SQL.
```

### judge_sql: Laravel's Schema::drop*

```text
Laravel's schema builder spells the same statement without the SQL keywords:
`Schema::dropIfExists('users')` in a migration's up() IS `DROP TABLE users`. The
rule above was blind to it, so the one migration shape an agent writes most in a
Laravel repo was the one this guard never asked about. Same ask tier; a drop inside
down() is cut above, since a rollback legitimately drops.
```

### judge_sql: the other migration DSLs

```text
Every other migration DSL spells the same statement its own way, and until 2026-09-14
this guard recognised exactly one of them — so a Prisma, Drizzle, TypeORM, Doctrine,
Knex or Alembic repo got the SQL-keyword rule only, which their DSLs never emit.
Shapes, one per tool: Prisma/Drizzle/Knex/Alembic all spell a drop as a call whose
name contains `dropTable`/`drop_table`/`dropSchema`/`drop_all`; TypeORM and Doctrine
write `dropTable(` / `->dropTable(` in a migration class. Ask tier and escape are
identical to the Laravel row: a down()/rollback legitimately drops.

Three things this row got wrong until 2026-09-22, each silencing a whole ecosystem:
it was case-SENSITIVE, so GORM's `Migrator().DropTable(` never matched; it required
a `(`, so Rails' `drop_table :users` never matched; and it listed no Django
operation, so `migrations.DeleteModel`/`RemoveField` never matched. `-i`, a second
argument form, and the three Django names fix all three. The symbol form REQUIRES a
space before the `:` and an identifier after it (`drop_table :users`): a bare `[(:]`
also matched `dropAll: boolean` in a TS interface and `dropTable: false` in a config
file, both measured, neither a migration. A quoted-string argument
(`drop_table 'users'`) still passes — stated in the header.
```

### judge_sql: TRUNCATE

```text
TRUNCATE was matched case-insensitively with TABLE optional until 2026-10-14, so
Tailwind's `truncate` class (`className="truncate text-xs"`) asked as SQL in real
sessions, most of them background workers or auto mode with nobody to answer. Now it
fires on an UPPERCASE `TRUNCATE <x>`, or on `truncate table` in any case. `table` must be
followed by whitespace and a name, so Tailwind's `truncate table-cell` stays silent, and the
any-case form skips a line carrying a class list (`className="truncate table w-full"`).
Residual: a lowercase `truncate users` without TABLE passes silently, and a class string
built outside an attribute or helper (`const c = "truncate table w-full"`) still asks.
Since 0.11.10 that second residual is gone: outside a SQL context only raw-query spans
are read (see "judge_sql: SQL contexts").
```

### judge_sql: lock hazards

```text
Lock-hazard detection (same warn/ask lane): schema changes that take a long-held
lock on a large table. Only checked if no destructive hit already fired (data loss wins).
```

### judge_sql: the NoSQL analogues

```text
NoSQL analogues of the same two hazards, same warn/ask lane. The relational
branches above are blind to them by construction: an unfiltered deleteMany({})
is the exact shape of a DELETE with no WHERE, and a Scan on a request path is
the read-side twin of a full-table sweep — it is O(table) per request, gets
slower as data grows, and passes every test written against a small fixture.
Only checked when nothing above fired; relational data loss wins the message.
```

### judge_sql: an empty filter, and bare deleteMany()

```text
deleteMany / updateMany / remove with an EMPTY filter, and .drop() outright.
Prisma spells delete-everything as `deleteMany()` with NO argument, so the
empty-object requirement made the commonest shape the one this never asked about.
The bare-parens alternative is scoped to `deleteMany` alone on purpose: extending
it to `remove` would fire on every DOM `element.remove()`.
```

### The Bash branch: a chunk fed to a SQL client (sqlcli)

```text
A chunk whose writer names no file (`psql <<SQL`), or whose text feeds a SQL client
even when that client's output is logged (`psql <<SQL > run.log`), executes the SQL:
command-guard's lane, so one statement never asks twice.
```

### The Bash branch: classifying the absolute path

```text
Classify the path a Write would carry (absolute), so the doc-surface and script-path
tests agree with the Write path; the message keeps the target as spelled.
```

### The Write branch: documentation surfaces

```text
Documentation surfaces execute nothing — a taskmaster card, README, or spec that
QUOTES a migration is prose, not SQL about to run. Gating them would storm a
permission prompt per card and, under a headless / ultra-goal run with no one to
answer "ask", stall the whole hands-off pipeline. Exempt only unambiguous doc
surfaces; .sql, code files, and migration paths still gate.
```
