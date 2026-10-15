#!/usr/bin/env bash
# Fixtures for plugins/database/hooks/guard.sh — the PreToolUse destructive-data
# guard. Run by CI via the plugins/*/scripts/__tests__/*.test.sh glob.
#
# The hook returns permissionDecision "ask" (never a deny) so a legitimate
# down-migration is possible; these fixtures assert WHICH writes earn the prompt
# and, just as importantly, which do not. A guard that asks on every write is
# trained away in a day.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
HOOK=plugins/database/hooks/guard.sh
rc=0

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

payload() { jq -nc --arg f "$1" --arg c "$2" '{tool_name:"Edit",tool_input:{file_path:$f,new_string:$c}}'; }
bpayload() { jq -nc --arg c "$1" '{tool_name:"Bash",cwd:"/tmp",tool_input:{command:$c}}'; }
mpayload() { jq -nc --arg f "$1" --arg a "$2" --arg b "$3" '{tool_name:"MultiEdit",tool_input:{file_path:$f,edits:[{old_string:"a",new_string:$a},{old_string:"b",new_string:$b}]}}'; }

# want=ask | allow
check() {
  local label="$1" want="$2" file="$3" content="$4" out got
  out=$(payload "$file" "$content" | bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"ask"'; then got=ask; else got=allow; fi
  if [ "$got" = "$want" ]; then
    echo "PASS: $label ($got)"
  else
    echo "FAIL: $label — want $want, got $got"; rc=1
  fi
}

check_bash() {
  local label="$1" want="$2" cmd="$3" out got
  out=$(bpayload "$cmd" | bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"ask"'; then got=ask; else got=allow; fi
  if [ "$got" = "$want" ]; then
    echo "PASS: $label ($got)"
  else
    echo "FAIL: $label — want $want, got $got"; rc=1
  fi
}

check_multi() {
  local label="$1" want="$2" out got
  out=$(mpayload "$3" "$4" "$5" | bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"ask"'; then got=ask; else got=allow; fi
  if [ "$got" = "$want" ]; then
    echo "PASS: $label ($got)"
  else
    echo "FAIL: $label — want $want, got $got"; rc=1
  fi
}

# --- relational hazards (pre-existing behaviour, locked here for the first time)
check "DROP TABLE"                    ask   db/migrate.sql   'DROP TABLE users;'
check "TRUNCATE"                      ask   db/migrate.sql   'TRUNCATE TABLE sessions;'
# 0.11.4: Tailwind's `truncate` class asked as SQL. Uppercase TRUNCATE, or any-case
# `truncate table`, still asks; lowercase `truncate users` without TABLE is the residual.
check "TRUNCATE without TABLE"        ask   db/migrate.sql   'TRUNCATE users;'
check "lowercase truncate table"      ask   db/migrate.sql   'truncate table users'
check "Tailwind truncate class"       allow src/Card.tsx     '<p className="truncate text-xs">{title}</p>'
check "Tailwind truncate table-cell"  allow src/Cell.tsx     '<td className="truncate table-cell">{v}</td>'
# `truncate table` in any case skips a line carrying a class list; the uppercase branch does not.
check "className truncate table"      allow src/Grid.tsx     '<div className="truncate table w-full">{v}</div>'
check "Vue :class truncate table"     allow src/Grid.vue     "<div :class=\"['truncate table w-full']\">"
check "cn() truncate table"           allow src/Grid.tsx     'const c = cn("truncate table w-full", active && "font-bold")'
check "class string outside a helper" ask   src/Grid.tsx     'const c = "truncate table w-full"'
check "lowercase truncate table, .sql" ask  db/cleanup.sql   'truncate table users;'
check "DELETE with no WHERE"          ask   db/migrate.sql   'DELETE FROM orders;'
check "DELETE with WHERE"             allow db/migrate.sql   'DELETE FROM orders WHERE id = 1;'
# 0.8.3: Laravel's schema builder spells DROP TABLE without the keywords.
check "Schema::dropIfExists (Laravel)" ask   database/migrations/2026_01_01_000000_x.php "Schema::dropIfExists('users');"
check "Schema::drop (Laravel)"         ask   database/migrations/2026_01_01_000000_x.php "Schema::drop('users');"
check "Schema::table add index"        allow database/migrations/2026_01_01_000000_x.php "Schema::table('users', fn (\$t) => \$t->index('email'));"
check "Schema::dropColumns is not a table drop" allow database/migrations/2026_01_01_000000_x.php "Schema::table('users', fn (\$t) => \$t->dropColumn('legacy'));"
# 0.11.4: every new create-table migration asked, because its down() drops the table. The
# rollback method is cut from its opener to the next method; up() and helpers are still judged.
MIG=database/migrations/2026_01_01_000000_create_widgets_table.php
up_create=$'    public function up(): void\n    {\n        Schema::create(\'widgets\', function (Blueprint $table) {\n            $table->id();\n        });\n    }\n'
check "create migration, dropIfExists in down()" allow "$MIG" \
  $'<?php\nreturn new class extends Migration\n{\n'"$up_create"$'\n    public function down(): void\n    {\n        Schema::dropIfExists(\'widgets\');\n    }\n};'
check "drop in up() still asks"                  ask   "$MIG" \
  $'<?php\nreturn new class extends Migration\n{\n    public function up(): void\n    {\n        Schema::dropIfExists(\'old_widgets\');\n    }\n\n    public function down(): void\n    {\n        Schema::create(\'old_widgets\', fn ($t) => $t->id());\n    }\n};'
check "drop in a helper after down() still asks" ask   "$MIG" \
  $'<?php\nreturn new class extends Migration\n{\n'"$up_create"$'\n    public function down(): void\n    {\n        Schema::dropIfExists(\'widgets\');\n    }\n\n    private function purge(): void\n    {\n        Schema::drop(\'widget_cache\');\n    }\n};'
check "down() opener outside migrations/ is not cut" ask src/Elevator.php \
  $'public function down(): void\n{\n    Schema::dropIfExists(\'floors\');\n}'
check "rails def down drop_table"               allow db/migrate/003_create_widgets.rb \
  $'class CreateWidgets < ActiveRecord::Migration[7.1]\n  def up\n    create_table :widgets\n  end\n\n  def down\n    drop_table :widgets\n  end\nend'
check "alembic downgrade drop_table"            allow alembic/versions/0004_widgets.py \
  $'def upgrade():\n    op.create_table("widgets", sa.Column("id", sa.Integer))\n\n\ndef downgrade():\n    op.drop_table("widgets")'
check "alembic drop_table in upgrade still asks" ask  alembic/versions/0005_widgets.py \
  $'def upgrade():\n    op.drop_table("old_widgets")\n\n\ndef downgrade():\n    pass'
# The PHP opener must lead its line, and each MultiEdit edit is cut on its own: a comment,
# a string or an earlier edit naming down() must not hide a drop in up().
check "comment naming down() in up() cuts nothing" ask "$MIG" \
  $'    public function up(): void\n    {\n        // reverse lives in function down() below\n        Schema::dropIfExists(\'legacy\');\n    }'
check "string naming down() in up() cuts nothing"  ask "$MIG" \
  $'    public function up(): void\n    {\n        $this->info(\'see function down() for the reverse\');\n        Schema::dropIfExists(\'legacy\');\n    }'
check_multi "multiedit: down() in edit 1 does not cut edit 2's drop" ask "$MIG" \
  $'    public function down(): void\n    {\n        Schema::create(\'users\', fn ($t) => $t->id());\n    }' \
  $'        Schema::drop(\'users\');'
check_multi "multiedit: a drop in an edit's own down() is still cut" allow "$MIG" \
  $'    public function down(): void\n    {\n        Schema::dropIfExists(\'widgets\');\n    }' \
  $'            $table->string(\'name\');'
# 0.10.0: the DSL row was case-sensitive, required a `(`, and knew no Django
# operation — so Rails, GORM and Django wrote a table drop in silence. Both
# directions: a config key that merely SPELLS one of the names is not a migration.
check "rails drop_table :symbol"      ask   db/migrate/001_x.rb 'drop_table :users'
check "django DeleteModel"            ask   app/migrations/0002_x.py 'migrations.DeleteModel(name="Order")'
check "django RemoveField"            ask   app/migrations/0003_x.py 'migrations.RemoveField(model_name="order", name="legacy")'
check "gorm DropTable"                ask   db/migrate.go       'db.Migrator().DropTable(&User{})'
check "TS interface dropAll flag"     allow src/types.ts        'export interface Opts { dropAll: boolean }'
check "config key dropTable"          allow config/knex.yml     '  dropTable: false'
check "rails add_column"              allow db/migrate/002_x.rb 'add_column :users, :email, :string'
check "CREATE INDEX, no CONCURRENTLY" ask   db/migrate.sql   'CREATE INDEX idx_a ON t (a);'
check "CREATE INDEX CONCURRENTLY"     allow db/migrate.sql   'CREATE INDEX CONCURRENTLY idx_a ON t (a);'

# --- NoSQL analogues. The relational branches are structurally blind to these:
#     an empty-filter deleteMany IS a DELETE with no WHERE, in another dialect.
check "deleteMany empty filter"       ask   src/repo.ts      'await col.deleteMany({})'
check "updateMany empty filter"       ask   src/repo.ts      'await col.updateMany({}, { $set: { x: 1 } })'
check "deleteMany WITH a filter"      allow src/repo.ts      'await col.deleteMany({ tenantId })'
# Prisma's delete-everything call takes NO argument, so the empty-object requirement
# missed the commonest shape. Scoped to deleteMany: `el.remove()` is a DOM call.
check "bare deleteMany()"             ask   src/repo.ts      'await prisma.user.deleteMany()'
check "DOM element.remove()"          allow src/ui.ts        'el.remove()'
check "collection drop()"             ask   src/repo.ts      'await col.drop()'
check "dropDatabase()"                ask   src/repo.ts      'await db.dropDatabase()'
check "ordinary find()"               allow src/repo.ts      'await col.find({ id })'

# Scan is a REQUEST-PATH hazard, not a hazard per se — a backfill script scanning
# the table is the correct tool. The path discriminates; assert both directions,
# or the rule reads as "never Scan", which is wrong and gets ignored.
check "ScanCommand on a request path" ask   src/routes/l.ts  'const r = await ddb.send(new ScanCommand({ TableName: t }))'
check "ScanCommand in scripts/"       allow scripts/back.ts  'const r = await ddb.send(new ScanCommand({ TableName: t }))'
check "ScanCommand in a test"         allow src/a.test.ts    'const r = await ddb.send(new ScanCommand({ TableName: t }))'

# --- doc surfaces execute nothing
check "markdown quoting a drop"       allow docs/runbook.md  'await col.deleteMany({})'
check "markdown quoting SQL"          allow docs/runbook.md  'DROP TABLE users;'

# --- 0.10.2: Bash writes. A statement written to a file asks like a Write; one fed to
#     a command that writes no file is command-guard's and stays silent here.
check_bash "bash: heredoc DROP TABLE into a .sql file asks" ask \
  "$(printf '%s\n' "cat > db/migrate.sql <<'SQL'" 'DROP TABLE users;' 'SQL')"
check_bash "bash: echo appending an unqualified DELETE asks" ask \
  "echo 'DELETE FROM orders;' >> db/seed.sql"
check_bash "bash: non-write command is silent" allow \
  'git status && ls db'
check_bash "bash: heredoc into psql writes no file and is silent" allow \
  "$(printf '%s\n' "psql \"\$DATABASE_URL\" <<'SQL'" 'DROP TABLE users;' 'SQL')"
# The case above exits before any chunk is read; this one passes the cheap exit.
check_bash "bash: psql heredoc beside a file write is still not scanned" allow \
  "$(printf '%s\n' "psql \"\$DATABASE_URL\" <<'SQL'" 'DROP TABLE users;' 'SQL' 'echo done > status.log')"
check_bash "bash: heredoc into a markdown file is a doc surface" allow \
  "$(printf '%s\n' "cat > notes.md <<'EOF'" 'DROP TABLE users;' 'EOF')"
check_bash "logged psql: SQL fed to psql whose output is logged is not scanned" allow \
  "$(printf '%s\n' "psql \"\$DATABASE_URL\" <<'SQL' > migrate.log" 'DROP TABLE users;' 'SQL')"
check_bash "walk: a markdown chunk does not exempt a later .sql chunk" ask \
  "$(printf '%s\n' "cat > notes.md <<'EOF'" 'plain notes' 'EOF' "cat > db/x.sql <<'SQL'" 'DROP TABLE users;' 'SQL')"
check_bash "bash: create migration written by heredoc, drop only in down()" allow \
  "$(printf '%s\n' "cat > database/migrations/2026_01_01_000000_create_widgets_table.php <<'PHP'" '<?php' 'return new class extends Migration {' "    public function up(): void { Schema::create('widgets', fn (\$t) => \$t->id()); }" '    public function down(): void' '    {' "        Schema::dropIfExists('widgets');" '    }' '};' 'PHP')"
check_bash "relative doc: a relative taskmaster-docs target is a doc surface" allow \
  "$(printf '%s\n' "cat > taskmaster-docs/specs/seed.sql <<'SQL'" 'DROP TABLE users;' 'SQL')"

# --- 0.11.4: scratch is not the project, and SQLite gets no CONCURRENTLY ask. Fixture projects sit
#     in $WS (no git: the root is the payload cwd) and the hook's TMPDIR is $WS/tmp, so the
#     out-of-root rule and the temp-dir rule can each be shown alone.
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
unset CLAUDE_PROJECT_DIR
mkdir -p "$WS/tmp/probe" "$WS/proj/db" "$WS/elsewhere" "$WS/tmp/inproj/db"
check_at() { # label want file content cwd [tool]
  local out got
  out=$(jq -nc --arg t "${6:-Write}" --arg f "$3" --arg c "$4" --arg d "$5" \
          '{tool_name:$t,cwd:$d,tool_input:({file_path:$f,content:$c} + (if $t == "Bash" then {command:$c} else {} end))}' \
        | TMPDIR="$WS/tmp" bash "$HOOK" 2>/dev/null)
  if printf '%s' "$out" | grep -q '"permissionDecision":"ask"'; then got=ask; else got=allow; fi
  if [ "$got" = "$2" ]; then echo "PASS: $1 ($got)"; else echo "FAIL: $1 — want $2, got $got"; rc=1; fi
}
check_at "scope: a target under TMPDIR, project elsewhere"   allow "$WS/tmp/probe/x.php"    'DROP TABLE users;' "$WS/proj"
check_at "scope: a TMPDIR target, no payload cwd"            allow "$WS/tmp/probe/x.php"    'DROP TABLE users;' ""
check_at "scope: a TMPDIR dir not created yet"               allow "$WS/tmp/new/dir/x.sql"  'CREATE INDEX idx_a ON t (a);' "$WS/proj"
check_at "scope: a target outside the project root"         allow "$WS/elsewhere/Fake.php" 'DELETE FROM orders;' "$WS/proj"
check_at "scope: a target in the project still asks"         ask   "$WS/proj/db/x.sql"      'DROP TABLE users;' "$WS/proj"
check_at "scope: a new dir in the project still asks"        ask   "$WS/proj/db/new/x.sql"  'DROP TABLE users;' "$WS/proj"
check_at "scope: no payload cwd, outside TMPDIR still asks"  ask   "$WS/proj/db/x.sql"      'DROP TABLE users;' ""
check_at "scope: a project living in TMPDIR is still judged" ask   "$WS/tmp/inproj/db/x.sql" 'DROP TABLE users;' "$WS/tmp/inproj"
check_at "scope: bash heredoc into a TMPDIR probe"           allow "" "$(printf '%s\n' "cat > $WS/tmp/probe/m.php <<'EOF'" 'DROP TABLE users;' 'EOF')" "$WS/proj" Bash
check_at "scope: bash heredoc into the project still asks"   ask   "" "$(printf '%s\n' "cat > db/m.sql <<'EOF'" 'DROP TABLE users;' 'EOF')" "$WS/proj" Bash
mkdir -p "$WS/d1/migrations" "$WS/pr/prisma" "$WS/pg/prisma" "$WS/lv" "$WS/lvpg" "$WS/dz" "$WS/mono/apps/api" "$WS/mono/apps/web"
printf 'name = "app"\n\n[[d1_databases]]\nbinding = "DB"\n' > "$WS/d1/wrangler.toml"
printf 'datasource db {\n  provider = "sqlite"\n}\n' > "$WS/pr/prisma/schema.prisma"
printf 'datasource db {\n  provider = "postgresql"\n}\n' > "$WS/pg/prisma/schema.prisma"
printf 'APP_NAME=x\nDB_CONNECTION=sqlite\n' > "$WS/lv/.env"
printf 'APP_NAME=x\nDB_CONNECTION=pgsql\n' > "$WS/lvpg/.env"
printf 'export default defineConfig({ dialect: "turso" });\n' > "$WS/dz/drizzle.config.ts"
printf '{ "d1_databases": [{ "binding": "DB" }] }\n' > "$WS/mono/apps/api/wrangler.jsonc"
IDX='CREATE INDEX idx_a ON t (a);'
check_at "sqlite: D1 (wrangler d1_databases), CREATE INDEX"  allow "$WS/d1/migrations/0001_init.sql" "$IDX" "$WS/d1"
check_at "sqlite: D1 still asks on DROP TABLE"               ask   "$WS/d1/migrations/0002_drop.sql" 'DROP TABLE users;' "$WS/d1"
check_at "sqlite: Prisma provider sqlite"                    allow "$WS/pr/prisma/migrations/1/migration.sql" "$IDX" "$WS/pr"
check_at "sqlite: Prisma provider postgresql still asks"     ask   "$WS/pg/prisma/migrations/1/migration.sql" "$IDX" "$WS/pg"
check_at "sqlite: Laravel .env DB_CONNECTION=sqlite"         allow "$WS/lv/database/migrations/x.php" "DB::statement('$IDX');" "$WS/lv"
check_at "sqlite: Laravel .env DB_CONNECTION=pgsql still asks" ask "$WS/lvpg/database/migrations/x.php" "DB::statement('$IDX');" "$WS/lvpg"
check_at "sqlite: drizzle.config dialect turso"              allow "$WS/dz/drizzle/0000_x.sql" "$IDX" "$WS/dz"
check_at "sqlite: a package's own wrangler config (monorepo)" allow "$WS/mono/apps/api/migrations/0001.sql" "$IDX" "$WS/mono"
check_at "sqlite: its sibling package still asks"            ask   "$WS/mono/apps/web/db/0001.sql" "$IDX" "$WS/mono"

# --- fail-open contract
if printf 'not json' | bash "$HOOK" >/dev/null 2>&1; then
  echo "PASS: garbage input exits 0 (fail-open)"
else
  echo "FAIL: garbage input did not exit 0"; rc=1
fi

[ "$rc" -eq 0 ] && echo "All database guard fixtures passed."
exit "$rc"
