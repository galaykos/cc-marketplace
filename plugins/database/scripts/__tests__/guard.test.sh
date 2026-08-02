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

# --- relational hazards (pre-existing behaviour, locked here for the first time)
check "DROP TABLE"                    ask   db/migrate.sql   'DROP TABLE users;'
check "TRUNCATE"                      ask   db/migrate.sql   'TRUNCATE TABLE sessions;'
check "DELETE with no WHERE"          ask   db/migrate.sql   'DELETE FROM orders;'
check "DELETE with WHERE"             allow db/migrate.sql   'DELETE FROM orders WHERE id = 1;'
check "CREATE INDEX, no CONCURRENTLY" ask   db/migrate.sql   'CREATE INDEX idx_a ON t (a);'
check "CREATE INDEX CONCURRENTLY"     allow db/migrate.sql   'CREATE INDEX CONCURRENTLY idx_a ON t (a);'

# --- NoSQL analogues. The relational branches are structurally blind to these:
#     an empty-filter deleteMany IS a DELETE with no WHERE, in another dialect.
check "deleteMany empty filter"       ask   src/repo.ts      'await col.deleteMany({})'
check "updateMany empty filter"       ask   src/repo.ts      'await col.updateMany({}, { $set: { x: 1 } })'
check "deleteMany WITH a filter"      allow src/repo.ts      'await col.deleteMany({ tenantId })'
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

# --- fail-open contract
if printf 'not json' | bash "$HOOK" >/dev/null 2>&1; then
  echo "PASS: garbage input exits 0 (fail-open)"
else
  echo "FAIL: garbage input did not exit 0"; rc=1
fi

[ "$rc" -eq 0 ] && echo "All database guard fixtures passed."
exit "$rc"
