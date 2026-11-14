#!/usr/bin/env bash
# Harness for mark-deliberated.sh. Load-bearing: a marker it writes is read back by the real compact-recovery hook,
# and check tells "this task, fresh" from another task, an expired marker and no marker.
set -u
unset CLAUDE_PROJECT_DIR
here=$(cd "$(dirname "$0")" && pwd)
M="$here/../mark-deliberated.sh"
CR="$here/../../hooks/compact-recovery.sh"
[ -x "$M" ] || { printf 'FAIL: mark-deliberated.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }
R="$T/proj"; mkdir -p "$R/sub"; git -C "$R" init -q
MK="$R/.cc-artifacts/approaches/deliberated.json"

bash "$M" check --task cache-rewrite --cwd "$R" >/dev/null 2>&1; [ $? = 1 ] && ok "no marker: check exits 1" || bad "no marker"
bash "$M" write --task cache-rewrite --shape "read-through cache" --why "one writer" --kill-trigger "two writers appear" --cwd "$R/sub" >/dev/null 2>&1 \
  && [ -f "$MK" ] && ok "write from a subdirectory lands at the project root" || bad "write location"
jq -e '.task == "cache-rewrite" and .by == "approach-deliberation" and (.at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T")) and .shape == "read-through cache" and .kill_trigger == "two writers appear"' "$MK" >/dev/null \
  && ok "marker carries task, by, at and the optional pick fields" || bad "marker fields: $(cat "$MK")"
bash "$M" check --task cache-rewrite --cwd "$R" >/dev/null 2>&1; [ $? = 0 ] && ok "same task: check exits 0" || bad "same task"
bash "$M" check --task other-task --cwd "$R" >/dev/null 2>&1; [ $? = 1 ] && ok "another task: check exits 1" || bad "other task"

out=$(jq -cn --arg c "$R/sub" '{session_id:"s", cwd:$c, hook_event_name:"SessionStart", source:"compact"}' | CLAUDE_PLUGIN_ROOT="$here/../.." bash "$CR")
printf '%s' "$out" | grep -q 'task "cache-rewrite", decided by approach-deliberation at ' && ok "round trip: compact-recovery reads the written marker" || bad "round trip (got: $out)"

touch -d '3 hours ago' "$MK"
bash "$M" check --task cache-rewrite --cwd "$R" >/dev/null 2>&1; [ $? = 1 ] && ok "expired marker: check exits 1" || bad "expired"

bash "$M" write --task "Not A Slug" --cwd "$R" >/dev/null 2>&1; [ $? = 3 ] && ok "a non-slug task is a usage error" || bad "slug"
bash "$M" write --task 'x"; rm -rf /' --cwd "$R" >/dev/null 2>&1; [ $? = 3 ] && ok "quotes in the task are refused" || bad "quote"
bash "$M" erase --task x >/dev/null 2>&1; [ $? = 3 ] && ok "an unknown subcommand is a usage error" || bad "subcommand"

# Plugins before 2026-11-14 wrote the marker under .claude/approaches/: copied over once, the old dir left as it was.
O="$T/old"; mkdir -p "$O/.claude/approaches"; git -C "$O" init -q
printf '{"task":"old-task","by":"approach-deliberation","at":"2026-11-13T00:00:00Z"}\n' > "$O/.claude/approaches/deliberated.json"
before=$(cksum < "$O/.claude/approaches/deliberated.json")
bash "$M" check --task old-task --cwd "$O" >/dev/null 2>&1; [ $? = 0 ] && ok "old path: a fresh marker only under .claude/approaches/ is read" || bad "old path: check reads the old marker"
[ -f "$O/.cc-artifacts/approaches/deliberated.json" ] && ok "old path: the old dir is copied to .cc-artifacts/approaches/" || bad "old path: copied over"
bash "$M" write --task new-task --cwd "$O" >/dev/null 2>&1
[ "$(jq -r .task "$O/.cc-artifacts/approaches/deliberated.json")" = new-task ] && ok "old path: write lands under .cc-artifacts/approaches/" || bad "old path: write location"
[ "$(cksum < "$O/.claude/approaches/deliberated.json")" = "$before" ] && ok "old path: the .claude/approaches/ marker is untouched" || bad "old path: old marker changed"
bash "$M" check --task old-task --cwd "$O" >/dev/null 2>&1; [ $? = 1 ] && ok "old path: once copied, the old marker is never read again" || bad "old path: old marker read after the copy"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
