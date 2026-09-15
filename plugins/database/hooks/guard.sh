#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
# PreToolUse destructive-SQL guard — the name its ask message and the README use. On a
# Write/Edit that introduces one of the shapes below it returns permissionDecision
# "ask", so the user confirms a backup or a tested rollback exists first. It does NOT
# hard-deny: a down-migration legitimately drops, and a deny that fires on the
# legitimate case is a deny that gets turned off.
#
# WHAT IT MATCHES, in priority order (the first hit wins the message; relational data
# loss outranks a lock hazard, which outranks the NoSQL analogues):
#   1. DATA LOSS — DROP TABLE/DATABASE/SCHEMA, TRUNCATE, an unqualified DELETE/UPDATE
#      with no WHERE on the line; Laravel's `Schema::drop*(`; and the same statement
#      as spelled by every other migration DSL (`dropTable`, `dropTableIfExists`,
#      `drop_table`, `dropSchema`, `drop_schema`, `dropAll`, `drop_all`) — Prisma,
#      Drizzle, TypeORM, Doctrine, Knex, Alembic. Plus the NoSQL twins: `deleteMany`
#      / `updateMany` / `remove` with an EMPTY filter `({})`, and `.drop()` /
#      `.dropCollection()` / `.dropDatabase()` / `.dropIndexes()` called with no
#      arguments.
#   2. LOCK HAZARD — `CREATE [UNIQUE] INDEX` with no `CONCURRENTLY`, a table-rewriting
#      `ALTER` (column TYPE change or `SET NOT NULL`), and a DynamoDB `Scan` whose path
#      does not look like a script (`script`, `migration`, `seed`, `backfill`, `bin/`,
#      `tools/`, `__tests__`, `.test.`, `.spec.`). Same ask tier, a different message:
#      these do not lose data, they hold a lock or read the whole table per request.
#
# WHAT IT DOES NOT MATCH, stated because the README tiers this an ask:
#   - A RENAME of a column or table. The expand→migrate→contract rule for that lives
#     in `sql-best-practices` § Migrations and is agent-graded; no regex here reads it.
#   - Documentation surfaces. `.md`, `.mdx`, `.markdown`, `.txt`, `.rst` and anything
#     under `taskmaster-docs/` exit early: a card or spec that QUOTES a migration
#     executes nothing, and gating them would storm one permission prompt per card and
#     stall a headless run that has nobody to answer "ask".
#   - A destructive statement run through Bash rather than written to a file — that is
#     `command-guard`'s territory, which is why this row yields to it in lane.tsv.
#   - Single-line matching: a DELETE whose WHERE sits on the next line still asks
#     (false positive, accepted), and a filter built across lines never does.
#
# CC_DB_GUARD=off disables it for the session, and the ask message says so.
# Fail-open: any error or missing jq allows the write.
{
  input=$(cat)
  # OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
  # uninstalling the plugin. Every other guard in the marketplace ships one,
  # and a global install makes "turn it off here" a real need.
  [ "${CC_DB_GUARD:-on}" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  text=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$text" ] || exit 0
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

  # Documentation surfaces execute nothing — a taskmaster card, README, or spec that
  # QUOTES a migration is prose, not SQL about to run. Gating them would storm a
  # permission prompt per card and, under a headless / ultra-goal run with no one to
  # answer "ask", stall the whole hands-off pipeline. Exempt only unambiguous doc
  # surfaces; .sql, code files, and migration paths still gate.
  flc=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
  case "$flc" in
    *.md|*.mdx|*.markdown|*.txt|*.rst|*/taskmaster-docs/*) exit 0 ;;
  esac

  hit=""
  [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '\bdrop[[:space:]]+(table|database|schema)\b' && hit="DROP TABLE/DATABASE/SCHEMA"
  # Laravel's schema builder spells the same statement without the SQL keywords:
  # `Schema::dropIfExists('users')` in a migration's up() IS `DROP TABLE users`. The
  # rule above was blind to it, so the one migration shape an agent writes most in a
  # Laravel repo was the one this guard never asked about. Same ask tier, same escape
  # (a down() legitimately drops).
  [ -z "$hit" ] && printf '%s' "$text" | grep -qE 'Schema::(drop|dropIfExists|dropAllTables|dropAllViews|dropDatabase|dropDatabaseIfExists)[[:space:]]*\(' && hit="a Schema::drop* call (Laravel's DROP TABLE)"
  # Every other migration DSL spells the same statement its own way, and until 2026-09-14
  # this guard recognised exactly one of them — so a Prisma, Drizzle, TypeORM, Doctrine,
  # Knex or Alembic repo got the SQL-keyword rule only, which their DSLs never emit.
  # Shapes, one per tool: Prisma/Drizzle/Knex/Alembic all spell a drop as a call whose
  # name contains `dropTable`/`drop_table`/`dropSchema`/`drop_all`; TypeORM and Doctrine
  # write `dropTable(` / `->dropTable(` in a migration class. Ask tier and escape are
  # identical to the Laravel row: a down()/rollback legitimately drops.
  [ -z "$hit" ] && printf '%s' "$text" | grep -qE '(\.|->|\b)(dropTable|dropTableIfExists|drop_table|dropSchema|drop_schema|dropAll|drop_all)[[:space:]]*\(' && hit="a drop-table call in a migration DSL (Prisma/Drizzle/TypeORM/Doctrine/Knex/Alembic)"
  [ -z "$hit" ] && printf '%s' "$text" | grep -qiE '\btruncate[[:space:]]+(table[[:space:]]+)?[^;]' && hit="TRUNCATE"
  # unqualified DELETE/UPDATE: a line with DELETE FROM or UPDATE … SET and no WHERE on it
  if [ -z "$hit" ]; then
    if printf '%s' "$text" | grep -iE '\b(delete[[:space:]]+from|update[[:space:]]+[^;]+[[:space:]]set)\b' \
         | grep -ivE '\bwhere\b' | grep -qiE '(delete[[:space:]]+from|update)'; then
      hit="an unqualified DELETE/UPDATE (no WHERE)"
    fi
  fi
  # Lock-hazard detection (same warn/ask lane): schema changes that take a long-held
  # lock on a large table. Only checked if no destructive hit already fired (data loss wins).
  lockhit=""
  if [ -z "$hit" ]; then
    # CREATE [UNIQUE] INDEX without CONCURRENTLY: a CREATE INDEX line carrying no CONCURRENTLY.
    if printf '%s' "$text" | grep -iE '\bcreate[[:space:]]+(unique[[:space:]]+)?index\b' \
         | grep -qivE '\bconcurrently\b'; then
      lockhit="a CREATE INDEX without CONCURRENTLY (PostgreSQL; other engines lock regardless)"
    fi
    # Table-rewriting ALTERs: a column TYPE change or adding a NOT NULL constraint.
    [ -z "$lockhit" ] && printf '%s' "$text" | grep -qiE '\balter[[:space:]]+table\b[^;]*\balter\b[^;]*\btype\b|\balter[[:space:]]+table\b[^;]*\bset[[:space:]]+not[[:space:]]+null\b' && lockhit="a table-rewriting ALTER (column TYPE change or SET NOT NULL)"
  fi

  # NoSQL analogues of the same two hazards, same warn/ask lane. The relational
  # branches above are blind to them by construction: an unfiltered deleteMany({})
  # is the exact shape of a DELETE with no WHERE, and a Scan on a request path is
  # the read-side twin of a full-table sweep — it is O(table) per request, gets
  # slower as data grows, and passes every test written against a small fixture.
  # Only checked when nothing above fired; relational data loss wins the message.
  if [ -z "$hit" ] && [ -z "$lockhit" ]; then
    # deleteMany / updateMany / remove with an EMPTY filter, and .drop() outright.
    if printf '%s' "$text" | grep -qE '\b(deleteMany|updateMany|remove)\([[:space:]]*\{[[:space:]]*\}'; then
      hit="an unfiltered deleteMany/updateMany/remove (empty filter matches every document)"
    elif printf '%s' "$text" | grep -qE '\.drop(Collection|Database|Indexes)?\([[:space:]]*\)'; then
      hit="a collection/database drop"
    # DynamoDB Scan outside a script/migration path: full-table read per request.
    elif printf '%s' "$text" | grep -qE '\b(ScanCommand|\.scan\()' \
      && ! printf '%s' "$flc" | grep -qE '(script|migration|seed|backfill|bin/|tools/|__tests__|\.test\.|\.spec\.)'; then
      lockhit="a DynamoDB Scan outside a script path (reads the whole table per request; derive a key schema or a GSI from the access pattern instead)"
    fi
  fi

  [ -n "$hit" ] || [ -n "$lockhit" ] || exit 0

  if [ -n "$hit" ]; then
    reason="destructive-SQL guard: this change introduces ${hit}. Confirm a backup or a tested rollback path exists before applying it, and that the statement is scoped as intended (an unqualified DELETE/UPDATE rewrites every row). Proceed only if that is verified."
  else
    reason="destructive-SQL guard: this change introduces ${lockhit}. On a large table this holds a lock that blocks concurrent reads/writes for the whole operation; prefer the non-blocking path (CREATE INDEX CONCURRENTLY; for a type change or NOT NULL, backfill then validate in a separate step, or add-column-and-copy). Proceed only if the table is small or a maintenance window is planned."
  fi
  [ -n "$file" ] && reason="$reason (file: $file)"
  # Name the escape in the message that blocks you.
  reason="$reason CC_DB_GUARD=off disables this guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
