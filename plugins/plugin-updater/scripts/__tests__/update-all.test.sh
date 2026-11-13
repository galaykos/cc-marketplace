#!/usr/bin/env bash
# Harness for update-all.sh and session-start.sh: a shim `claude` logs every call; asserted are which installs get `claude plugin update` (the current folder and user scope by default, every folder under --all), from which folder, one at a time, never -y, the summary, exit codes, the lock, and the detached session-start run.
# Not covered: the real CLI's JSON (the shim answers from fixtures), how it resolves a folder to an install, and the host's handling of a hook's detached child.
# Why, limits, history: rationale/derivations/plugin-plugin-updater.md § plugins/plugin-updater/scripts/__tests__/update-all.test.sh
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SCRIPT="$ROOT/plugins/plugin-updater/scripts/update-all.sh"
HOOK="$ROOT/plugins/plugin-updater/hooks/session-start.sh"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; exit 0; }
[ -x "$SCRIPT" ] && [ -x "$HOOK" ] || { echo "FAIL: script or hook not executable"; exit 1; }

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }
has()   { if grep -qF -- "$2" <<<"$3"; then ok "$1"; else bad "$1" "missing: $2"$'\n'"$3"; fi; }
lacks() { if grep -qF -- "$2" <<<"$3"; then bad "$1" "unexpected: $2"; else ok "$1"; fi; }
eq()    { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "want [$2] got [$3]"; fi; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
H="$T/home"; P="$T/cfg/plugins"; MK="$P/marketplaces/mk"; BIN="$T/bin"
mkdir -p "$H" "$BIN" "$MK/.claude-plugin" "$T/proj1/sub" "$T/proj2" "$T/wt" "$T/none"
printf 'gitdir: %s/main/.git/worktrees/wt\n' "$T" > "$T/wt/.git"
for pv in alpha:2.0.0 beta:1.5.0 both:1.0.0 cmdp:2.0.0 mism:2.0.0; do
  mkdir -p "$MK/plugins/${pv%%:*}/.claude-plugin"
  printf '{"name":"%s","version":"%s"}\n' "${pv%%:*}" "${pv#*:}" > "$MK/plugins/${pv%%:*}/.claude-plugin/plugin.json"
done
cat > "$MK/.claude-plugin/marketplace.json" <<'EOF'
{"name":"mk","metadata":{"pluginRoot":"./plugins"},"renames":{"gone":null},"plugins":[
 {"name":"alpha","source":"./plugins/alpha"},
 {"name":"beta","source":"beta"},
 {"name":"gamma","source":{"source":"github","repo":"x/y"},"version":"3.0.0"},
 {"name":"delta","source":{"source":"github","repo":"x/z"}},
 {"name":"both","source":"./plugins/both","version":"9.9.9"},
 {"name":"cmdp","source":"./plugins/cmdp"},
 {"name":"mism","source":"./plugins/mism"}]}
EOF
printf '{"mk":{"installLocation":"%s"}}\n' "$MK" > "$P/known_marketplaces.json"

# id version scope projectPath — one install per row; "-" is no projectPath.
rows="alpha@mk 1.0.0 user -
alpha@mk 2.0.0 local $T/proj1
alpha@mk 1.0.0 local $T/gone
alpha@mk 1.0.0 local $T/wt
alpha@mk 1.0.0 managed -
beta@mk 1.0.0 local $T/proj1
gamma@mk 3.0.0 project $T/proj2
delta@mk abc123 local $T/proj1
gone@mk 0.1.0 local $T/proj1
both@mk 1.0.0 local $T/proj2
cmdp@mk 1.0.0 local $T/proj2
mism@mk 1.0.0 local $T/proj2"
ROWS="$rows" python3 -I - "$T/list.json" "$P/installed_plugins.json" <<'PY'
import json, os, sys
lst, inst = [], {}
for line in os.environ["ROWS"].splitlines():
    pid, ver, scope, pp = line.split()
    e = {"id": pid, "version": ver, "scope": scope}
    if pp != "-":
        e["projectPath"] = pp
    lst.append(e)
    inst.setdefault(pid, []).append({k: v for k, v in e.items() if k != "id"})
json.dump(lst, open(sys.argv[1], "w"))
json.dump({"version": 2, "plugins": inst}, open(sys.argv[2], "w"))
PY

cat > "$BIN/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\t%s\n' "$PWD" "$*" >> "$FAKE_LOG"
case "$1 $2" in
  "plugin list") cat "$FAKE_LIST"; exit 0 ;;
  "plugin marketplace") sleep "${FAKE_SLOW:-0}"; exit 0 ;;
  "plugin update") ;;
  *) exit 9 ;;
esac
[ -t 0 ] && echo "TTY-STDIN" >> "$FAKE_LOG"
mkdir "$T/lock" 2>/dev/null || echo "PARALLEL" >> "$FAKE_LOG"
sleep 0.05; rmdir "$T/lock" 2>/dev/null
case "$3" in
  alpha@mk) echo '{"outcome":"ok","updateOutcome":"updated","oldVersion":"1.0.0","newVersion":"2.0.0"}' ;;
  beta@mk)  echo 'progress noise'; echo '{"outcome":"ok","updateOutcome":"updated","oldVersion":"1.0.0","newVersion":"1.5.0"}' ;;
  delta@mk) echo '{"outcome":"ok","updateOutcome":"up_to_date","oldVersion":"abc123","newVersion":"abc123"}' ;;
  gone@mk)  echo '{"outcome":"failed","failureCode":"not_found","message":"Plugin \"gone\" not found"}'; exit 1 ;;
  cmdp@mk)  echo '{"outcome":"failed","failureCode":"command_changed","message":"install command changed","shownCommand":{"sha256":"ab"}}'; exit 1 ;;
  mism@mk)  echo '{"outcome":"ok","updateOutcome":"up_to_date","oldVersion":"2.0.0","newVersion":"2.0.0"}' ;;
  *) echo "unexpected update $3" >&2; exit 3 ;;
esac
EOF
chmod +x "$BIN/claude"

D="$T/data"
clean_env=(env -u CC_PLUGIN_UPDATER_AUTO -u CC_PLUGIN_UPDATER_INTERVAL -u CC_PLUGIN_UPDATER_HINT
  -u CLAUDE_PLUGIN_OPTION_CC_PLUGIN_UPDATER_AUTO -u CLAUDE_PLUGIN_OPTION_CC_PLUGIN_UPDATER_INTERVAL
  -u CLAUDE_PLUGIN_OPTION_CC_PLUGIN_UPDATER_HINT
  HOME="$H" CLAUDE_CONFIG_DIR="$T/cfg" CLAUDE_PLUGIN_DATA="$D" FAKE_LOG="$T/log" T="$T" PATH="$BIN:$PATH")
run() { : > "$T/log"; out=$(cd "${CWD:-$T/proj1}" && "${clean_env[@]}" FAKE_LIST="${LIST:-$T/list.json}" bash "$SCRIPT" "$@" 2>&1); rc=$?; log=$(cat "$T/log"); }
updates() { grep -c $'\tplugin update ' <<<"$log"; }
state() { python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print(" ".join(f"{k}={d.get(k)}" for k in sys.argv[2:]))' "$D/last-run.json" "$@" 2>/dev/null; }

run --dry-run --all
eq  "dry-run: exit 0" 0 "$rc"
eq  "dry-run: no plugin update call" 0 "$(updates)"
has "dry-run: refreshes the marketplaces" $'\tplugin marketplace update' "$log"
has "dry-run: says it changed nothing" "Dry run: nothing was updated." "$out"
has "dry-run: six installs need a call" 'Would run `claude plugin update` for 6 install(s)' "$out"
has "pluginRoot bare source resolves (beta 1.0.0 -> 1.5.0)" "beta@mk  $T/proj1 (local)  1.0.0 → 1.5.0" "$out"
lacks "plugin.json wins over the entry's version (both is current)" "both@mk" "$out"
has "entry version for a remote source (gamma current)" "3 current" "$out"
has "renames null reads as removed" "0.1.0: removed from the marketplace" "$out"
has "remote source with no entry version reads as unreadable" "abc123: remote source, its version is not readable locally" "$out"
has "missing folder skipped as orphaned" "$T/gone  orphaned entry: folder no longer exists" "$out"
has "linked worktree skipped" "$T/wt  linked git worktree" "$out"
has "managed scope skipped" "managed scope is set by policy" "$out"
eq  "dry-run: writes no run state" "" "$(ls "$D" 2>/dev/null)"

run --dry-run --no-refresh
lacks "--no-refresh: no marketplace update" "marketplace update" "$log"
has "default: names the folder it covers" "Folder: $T/proj1, and user scope." "$out"
has "default: the folder's three and the user install" 'Would run `claude plugin update` for 4 install(s)' "$out"
lacks "default: another folder's installs are not listed" "$T/proj2" "$out"
lacks "default: another folder's orphaned entry is not listed" "$T/gone" "$out"
has "default: managed scope still listed as skipped" "managed scope is set by policy" "$out"

run --no-refresh
eq  "default run: four update calls" 4 "$(updates)"
lacks "default run: no call from another folder" "$T/proj2"$'\t' "$log"
has "default run: user scope is updated" "$H"$'\tplugin update alpha@mk --scope user --json' "$log"
eq  "default run: state names the folder" "folder=$T/proj1" "$(state folder)"
CWD="$T/proj1/sub" run --no-refresh
has "default run from a subfolder: the enclosing project folder" "$T/proj1"$'\tplugin update beta@mk --scope local --json' "$log"
CWD="$T/none" run --no-refresh
eq  "default run from a folder with no installs: only the user install" 1 "$(updates)"
CWD="$T/wt" run --no-refresh
eq  "default run from a linked worktree: only the user install" 1 "$(updates)"
has "default run from a linked worktree: its install is skipped" "$T/wt  linked git worktree" "$out"

run --all
eq  "run: exit 1 on a failure or a changed command" 1 "$rc"
eq  "run: one update call per needed install" 6 "$(updates)"
lacks "run: never -y" " -y" "$log"
lacks "run: never --accept-command" "--accept-command" "$log"
lacks "run: stdin is never a terminal" "TTY-STDIN" "$log"
lacks "run: one update at a time" "PARALLEL" "$log"
has "run: user scope runs from home" "$H"$'\tplugin update alpha@mk --scope user --json' "$log"
has "run: local scope runs from its project folder" "$T/proj1"$'\tplugin update beta@mk --scope local --json' "$log"
lacks "run: no call for a missing folder" "$T/gone"$'\t' "$log"
lacks "run: no call for a worktree" "$T/wt"$'\t' "$log"
has "summary: updated" "updated          2" "$out"
has "summary: already current" "already current  4" "$out"
has "summary: skipped" "skipped          3" "$out"
has "summary: failed" "failed           2" "$out"
has "summary: need you" "need you         1" "$out"
has "removed plugin: uninstall hint" "uninstall it: cd $T/proj1 && claude plugin uninstall gone@mk --scope local" "$out"
has "up_to_date for another install is a failure" "the CLI checked another install of mism@mk" "$out"
has "changed command is left to the person" "cd $T/proj2 && claude plugin update cmdp@mk --scope local" "$out"
has "restart reminder" "Restart running Claude Code sessions" "$out"
eq  "run: state records the counts, reported (a foreground run)" "completed=True reported=True updated=2 failed=2 needs_you=1 orphaned=1 worktree=1" \
    "$(state completed reported updated failed needs_you orphaned worktree)"
eq  "run: lock released" "" "$(ls "$D/run.lock" 2>/dev/null)"

run --all --plugin beta --no-refresh
eq "--plugin: only beta" "$T/proj1"$'\tplugin update beta@mk --scope local --json' "$(grep $'\tplugin update ' <<<"$log")"
eq "--plugin: exit 0 when all succeed" 0 "$rc"
run --all --scope user --no-refresh
eq "--scope user: only the user install" 1 "$(updates)"
run --project "$T/proj2" --no-refresh
eq "--project: only that folder's two" 2 "$(updates)"
run --scope bogus
eq "bad flag: exit 2" 2 "$rc"
printf 'not json' > "$T/bad.json"; LIST="$T/bad.json" run --no-refresh
eq "unreadable plugin list: exit 2" 2 "$rc"
eq "unreadable plugin list: state says not completed" "completed=False rc=2" "$(state completed rc)"

mkdir -p "$D/run.lock"; echo $$ > "$D/run.lock/pid"; touch -d '-5 minutes' "$D/run.lock"
run --all --no-refresh
eq  "live lock: a second run exits 2" 2 "$rc"
has "live lock: says a run is in progress" "another update run is in progress (pid $$" "$out"
eq  "live lock: no update call" 0 "$(updates)"
sh -c 'exit 0' & dead=$!; wait "$dead"; echo "$dead" > "$D/run.lock/pid"; touch -d '-5 minutes' "$D/run.lock"
run --all --no-refresh
eq  "dead pid lock: taken over, the run proceeds" 1 "$rc"

rm -rf "$D"
hook() { : > "$T/log"; out=$(printf '{"source":"startup","cwd":"%s"}' "${CWD:-$T/proj1}" | "${clean_env[@]}" "$@" bash "$HOOK"); rc=$?; log=$(cat "$T/log"); }
settle() { for _ in $(seq 1 200); do [ -f "$D/last-run.json" ] && [ ! -d "$D/run.lock" ] && return 0; sleep 0.1; done; return 1; }

hook CC_PLUGIN_UPDATER_AUTO=off
eq  "check-only: one line counting the folder's and the user's updatable installs" '{"systemMessage": "2 plugin installs outdated (2 plugins): run /plugin-updater:update-plugins (--dry-run lists them)."}' "$out"
CWD="$T/proj2" hook CC_PLUGIN_UPDATER_AUTO=off
has "check-only: another folder counts its own" "3 plugin installs outdated (3 plugins)" "$out"
eq  "check-only: never calls the CLI" "" "$log"
hook CLAUDE_PLUGIN_OPTION_CC_PLUGIN_UPDATER_AUTO=false
has "check-only through the plugin option (false)" "2 plugin installs outdated" "$out"
hook CC_PLUGIN_UPDATER_AUTO=off CC_PLUGIN_UPDATER_HINT=off
eq  "check-only off switch is silent" "" "$out"

t0=$(date +%s%N); hook FAKE_SLOW=3 FAKE_LIST="$T/list.json"; t1=$(date +%s%N)
eq  "auto: first session prints nothing" "" "$out"
if [ $(( (t1 - t0) / 1000000 )) -lt 2000 ]; then ok "auto: hook returns before the 3 s refresh ends"; else bad "auto: hook blocked $(( (t1 - t0) / 1000000 )) ms"; fi
if settle; then ok "auto: background run finished and released the lock"; else bad "auto: background run did not finish"; fi
log=$(cat "$T/log")
eq  "auto: background run made the folder's four update calls" 4 "$(updates)"
lacks "auto: background run made no call from another folder" "$T/proj2"$'\t' "$log"
lacks "auto: background run never passes -y" " -y" "$log"
eq  "auto: state unreported, background" "completed=True reported=False background=True" "$(state completed reported background)"
has "auto: log holds the summary" "Summary" "$(cat "$D/last-run.log")"
hook FAKE_LIST="$T/list.json"
eq  "auto: next session reports the run once" '{"systemMessage": "plugin-updater, background run in '"$T"'/proj1: updated 2, failed 1. /plugin-updater:update-plugins --last shows the log. Restart running sessions to load the updates."}' "$out"
sleep 0.3
eq  "auto: not due, no new run" "" "$(cat "$T/log")"
hook FAKE_LIST="$T/list.json"
eq  "auto: third session is silent" "" "$out"
CWD="$T/proj2" hook FAKE_LIST="$T/list.json"
settle; sleep 0.2
eq  "auto: another folder is due on its own clock" 3 "$(grep -c $'\tplugin update ' "$T/log")"
has "auto: that run stayed in its folder" "$T/proj2"$'\tplugin update cmdp@mk --scope local --json' "$(cat "$T/log")"
hook FAKE_LIST="$T/list.json"; sleep 0.3
lacks "auto: the first folder is still not due" "plugin update" "$(cat "$T/log")"
hook FAKE_LIST="$T/list.json" CC_PLUGIN_UPDATER_INTERVAL=0
settle; sleep 0.2
eq  "auto: interval 0 starts a run every session" 4 "$(grep -c $'\tplugin update ' "$T/log")"
run --last
has "--last prints the background log" "Summary" "$out"
mkdir -p "$D/run.lock"; echo $$ > "$D/run.lock/pid"
hook FAKE_LIST="$T/list.json" CC_PLUGIN_UPDATER_INTERVAL=0
sleep 0.3
eq  "auto: a held lock starts no second run" "" "$(cat "$T/log")"
rm -rf "$D/run.lock"

cp "$P/installed_plugins.json" "$T/keep.json"; printf '{broken' > "$P/installed_plugins.json"
hook CC_PLUGIN_UPDATER_AUTO=off
eq  "check-only: broken JSON is silent" "" "$out"
eq  "check-only: broken JSON exits 0" 0 "$rc"
printf '{"version":2,"plugins":{"alpha@mk":[{"scope":"user","version":"2.0.0"}]}}' > "$P/installed_plugins.json"
hook CC_PLUGIN_UPDATER_AUTO=off
eq  "check-only: nothing outdated is silent" "" "$out"
cp "$T/keep.json" "$P/installed_plugins.json"
printf '{broken' > "$D/last-run.json"
hook FAKE_LIST="$T/list.json"
eq  "auto: broken state file exits 0" 0 "$rc"
settle

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
