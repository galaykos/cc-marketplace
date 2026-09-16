#!/usr/bin/env bash
# Author-time tests for all-plugins.sh — the install-every-leaf mechanism behind
# /all-plugins:install and :uninstall. Picked up by the CI step globbing
# plugins/*/scripts/__tests__/*.test.sh.
#
# WHAT IS ASSERTED. The script's whole contract is the sequence of `claude plugin`
# calls it makes and its exit code, so every case reads both: a shim `claude` on
# PATH answers the two read commands from fixtures and appends every mutating call
# to a log. Asserted: only leaves are touched (never a bundle), in sorted order, at
# the requested scope; installed/disabled/absent each take their own branch;
# projectPath must match this project (an entry for another project is NOT
# installed here); one failing plugin never stops the walk and still exits 1;
# `uninstall` keeps all-plugins unless --self, and with --self removes it LAST;
# --dry-run and list mutate nothing; every usage and prerequisite error exits 2
# with the fix on stderr; and `main "$@"` is the script's last line, which is what
# makes self-uninstall safe.
#
# WHAT IS NOT COVERED. Nothing here runs the real CLI: whether `claude plugin
# install` accepts these flags on the installed version, what `--json` actually
# returns, and whether a project-scope install lands in .claude/settings.json are
# the host's behaviour, and this harness proves only that the script drives it as
# the contract says. A real-CLI drift shows up as a FAIL line at runtime, not here.
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SCRIPT="$ROOT/plugins/all-plugins/scripts/all-plugins.sh"
MK_NAME="cc-plugins-marketplace"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -x "$SCRIPT" ] || { echo "FAIL: script not executable at $SCRIPT"; exit 1; }

pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
BIN="$WS/bin"; MK="$WS/mk"; PROJ="$WS/proj"
mkdir -p "$BIN" "$MK/.claude-plugin" "$PROJ/sub"
git -C "$PROJ" init -q 2>/dev/null || true
PROJ_PHYS="$(cd "$PROJ" && pwd -P)"

# ---- the fixture marketplace: three leaves, one bundle, deliberately unsorted ----------
for p in beta some-suite all-plugins alpha; do
  mkdir -p "$MK/plugins/$p/.claude-plugin"
  printf '{"name":"%s","version":"1.0.0"}\n' "$p" > "$MK/plugins/$p/.claude-plugin/plugin.json"
done
jq -n '{name:"some-suite",version:"1.0.0",dependencies:["alpha","beta"]}' > "$MK/plugins/some-suite/.claude-plugin/plugin.json"
jq -n '{name:"cc-plugins-marketplace",plugins:[
  {name:"beta",source:"./plugins/beta"},
  {name:"some-suite",source:"./plugins/some-suite"},
  {name:"all-plugins",source:"./plugins/all-plugins"},
  {name:"alpha",source:"./plugins/alpha"}]}' > "$MK/.claude-plugin/marketplace.json"

MARKETS="$WS/marketplaces.json"; MARKETS_NONE="$WS/marketplaces-none.json"
jq -n --arg loc "$MK" '[{name:"other",source:"github",repo:"x/y",installLocation:"/nowhere"},
                        {name:"cc-plugins-marketplace",source:"github",repo:"galaykos/cc-marketplace",installLocation:$loc}]' > "$MARKETS"
jq -n '[{name:"other",source:"github",repo:"x/y",installLocation:"/nowhere"}]' > "$MARKETS_NONE"

# ---- the shim: canned JSON for the two reads, a log line for everything else ----------
cat > "$BIN/claude" <<'SH'
#!/usr/bin/env bash
case "$*" in
  "plugin marketplace list --json") cat "$SHIM_MARKETPLACES" ;;
  "plugin list --json") cat "$SHIM_INSTALLED" ;;
  *)
    printf '%s\n' "$*" >> "$SHIM_LOG"
    name="${3%%@*}"
    if [ "${SHIM_FAIL:-}" = "$name" ]; then printf 'Error: %s refused by shim\n' "$name" >&2; exit 1; fi
    printf 'Installed %s\n' "$name" ;;
esac
SH
chmod +x "$BIN/claude"

INSTALLED="$WS/installed.json"; LOG="$WS/calls.log"
export SHIM_MARKETPLACES="$MARKETS" SHIM_INSTALLED="$INSTALLED" SHIM_LOG="$LOG"

entry() { # entry <name> <scope> <enabled> [projectPath]
  jq -cn --arg id "$1@$MK_NAME" --arg s "$2" --argjson e "$3" --arg p "${4:-}" \
    '{id:$id,version:"1.0.0",scope:$s,enabled:$e,installPath:"/cache/x"} + (if $p != "" then {projectPath:$p} else {} end)'
}
installed() { printf '%s\n' "$@" | jq -s '.' > "$INSTALLED"; }   # installed [entry...]

OUT=""; ERR=""; RC=0; CALLS=""
run() { # run [cwd=PROJ] -- args...   (SHIM_FAIL is read from the environment)
  local cwd="$PROJ"
  if [ "${1:-}" != "--" ]; then cwd="$1"; shift; fi
  shift
  : > "$LOG"
  OUT=$(cd "$cwd" && PATH="$BIN:$PATH" bash "$SCRIPT" "$@" 2>"$WS/err"); RC=$?
  ERR=$(cat "$WS/err"); CALLS=$(cat "$LOG")
}
has()     { case "$1" in *"$2"*) return 0 ;; *) return 1 ;; esac; }
rc_is()   { if [ "$RC" -eq "$2" ]; then ok "$1"; else bad "$1" "rc=$RC want $2; stderr: ${ERR:-<none>}"; fi; }
out_has() { if has "$OUT" "$2"; then ok "$1"; else bad "$1" "stdout missing '$2' — got: $OUT"; fi; }
out_not() { if has "$OUT" "$2"; then bad "$1" "stdout should not contain '$2' — got: $OUT"; else ok "$1"; fi; }
err_has() { if has "$ERR" "$2"; then ok "$1"; else bad "$1" "stderr missing '$2' — got: ${ERR:-<none>}"; fi; }
calls_are() { # calls_are <label> <expected log, newline-separated>
  if [ "$CALLS" = "$2" ]; then ok "$1"; else bad "$1" "calls were:"$'\n'"${CALLS:-<none>}"$'\n'"      want:"$'\n'"$2"; fi
}

# ---- 1. fresh install: leaves only, sorted, at -s local ---------------------------------
installed
run -- install
rc_is "fresh install exits 0" 0
calls_are "installs every leaf in sorted order, never the bundle" \
"plugin install all-plugins@$MK_NAME -s local
plugin install alpha@$MK_NAME -s local
plugin install beta@$MK_NAME -s local"
out_has "summary counts a fresh install" "installed 3, enabled 0, skipped 0, failed 0 of 3 leaves at scope local"
out_has "reload hint after an install" "Run /reload-plugins — nothing installed this run is active until you do."
out_not "the bundle is not even listed" "some-suite"

# ---- 2. mixed state: skip the installed, enable the disabled, install the absent --------
installed "$(entry alpha local true "$PROJ")" "$(entry beta local false "$PROJ")"
run -- install
rc_is "mixed install exits 0" 0
calls_are "enable for disabled, install for absent, nothing for installed" \
"plugin install all-plugins@$MK_NAME -s local
plugin enable beta@$MK_NAME -s local"
out_has "installed row says skip" "skip (installed)"
out_has "enabled row says enabled" "enabled"
out_has "mixed summary" "installed 1, enabled 1, skipped 1, failed 0 of 3 leaves at scope local"

# ---- 3. idempotent: the second run is all skips and says nothing about reloading --------
installed "$(entry alpha local true "$PROJ")" "$(entry beta local true "$PROJ")" "$(entry all-plugins local true "$PROJ")"
run -- install
rc_is "all-installed run exits 0" 0
calls_are "all-installed run makes no calls" ""
out_has "all-installed summary" "installed 0, enabled 0, skipped 3, failed 0 of 3 leaves at scope local"
out_not "no reload hint when nothing changed" "/reload-plugins"

# ---- 4. scope propagates; user scope ignores projectPath ---------------------------------
installed
run -- install --scope project
calls_are "--scope project reaches -s project" \
"plugin install all-plugins@$MK_NAME -s project
plugin install alpha@$MK_NAME -s project
plugin install beta@$MK_NAME -s project"
installed "$(entry alpha user true)" "$(entry beta user false)"
run -- install --scope user
calls_are "--scope user: no projectPath needed, -s user on every call" \
"plugin install all-plugins@$MK_NAME -s user
plugin enable beta@$MK_NAME -s user"
run -- install --scope=user
calls_are "--scope=user form is accepted" \
"plugin install all-plugins@$MK_NAME -s user
plugin enable beta@$MK_NAME -s user"

# ---- 5. projectPath: another project's entry is not this project's -----------------------
installed "$(entry alpha local true "/somewhere/else")" "$(entry beta local true "$PROJ")"
run -- install
calls_are "an entry for a different projectPath does not count as installed" \
"plugin install all-plugins@$MK_NAME -s local
plugin install alpha@$MK_NAME -s local"
# The CLI records the project root; the user may run this from a subdirectory.
installed "$(entry alpha local true "$PROJ_PHYS")" "$(entry beta local true "$PROJ_PHYS")" "$(entry all-plugins local true "$PROJ_PHYS")"
run "$PROJ/sub" -- install
calls_are "projectPath equal to the git toplevel counts from a subdirectory" ""
# An entry at another scope is not this scope's, even in this project.
installed "$(entry alpha project true "$PROJ")"
run -- install
if has "$CALLS" "plugin install alpha@"; then ok "a project-scope entry does not satisfy a local-scope install"
else bad "a project-scope entry does not satisfy a local-scope install" "calls: $CALLS"; fi

# ---- 6. one failure: the walk continues, the line names it, exit 1 -----------------------
installed
SHIM_FAIL=beta run -- install
rc_is "a failing plugin exits 1" 1
calls_are "the other leaves are still attempted after a failure" \
"plugin install all-plugins@$MK_NAME -s local
plugin install alpha@$MK_NAME -s local
plugin install beta@$MK_NAME -s local"
out_has "FAIL row names the plugin and the stderr line" "FAIL (Error: beta refused by shim)"
out_has "summary counts the failure" "installed 2, enabled 0, skipped 0, failed 1 of 3 leaves at scope local"
err_has "failures are repeated on stderr at the end" "beta: Error: beta refused by shim"

# ---- 7. uninstall: all-plugins kept unless --self, and last with it ----------------------
installed "$(entry alpha local true "$PROJ")" "$(entry beta local false "$PROJ")" "$(entry all-plugins local true "$PROJ")"
run -- uninstall
rc_is "uninstall exits 0" 0
calls_are "uninstall without --self never touches all-plugins" \
"plugin uninstall alpha@$MK_NAME -s local
plugin uninstall beta@$MK_NAME -s local"
out_has "uninstall summary excludes all-plugins from the count" "uninstalled 2, skipped 0, failed 0 of 2 leaves at scope local"
out_has "keep line names the exact removal command" "all-plugins itself kept; remove it with: claude plugin uninstall all-plugins@$MK_NAME -s local"
run -- uninstall --self
rc_is "uninstall --self exits 0" 0
calls_are "--self uninstalls all-plugins LAST" \
"plugin uninstall alpha@$MK_NAME -s local
plugin uninstall beta@$MK_NAME -s local
plugin uninstall all-plugins@$MK_NAME -s local"
out_not "no keep line under --self" "itself kept"
installed
run -- uninstall
rc_is "uninstall with nothing installed exits 0" 0
calls_are "nothing installed: no calls" ""
out_has "not-installed rows say so" "skip (not installed)"
out_not "no keep line when all-plugins is not installed" "itself kept"
installed "$(entry alpha local true "$PROJ")" "$(entry beta local true "$PROJ")"
SHIM_FAIL=alpha run -- uninstall
rc_is "a failing uninstall exits 1" 1
calls_are "the walk continues past a failed uninstall" \
"plugin uninstall alpha@$MK_NAME -s local
plugin uninstall beta@$MK_NAME -s local"
out_has "uninstall summary counts the failure" "uninstalled 1, skipped 0, failed 1 of 2 leaves at scope local"

# ---- 8. --dry-run and list mutate nothing ------------------------------------------------
installed "$(entry beta local false "$PROJ")"
run -- install --dry-run
rc_is "dry-run install exits 0" 0
calls_are "dry-run install makes no calls" ""
out_has "dry-run prints the install it would run" "DRY  claude plugin install alpha@$MK_NAME -s local"
out_has "dry-run prints the enable it would run" "DRY  claude plugin enable beta@$MK_NAME -s local"
out_not "dry-run does not claim a reload is needed" "/reload-plugins"
installed "$(entry alpha local true "$PROJ")" "$(entry all-plugins local true "$PROJ")"
run -- uninstall --dry-run --self
calls_are "dry-run uninstall --self makes no calls" ""
out_has "dry-run prints the self-uninstall it would run" "DRY  claude plugin uninstall all-plugins@$MK_NAME -s local"
installed "$(entry alpha local true "$PROJ")" "$(entry beta local false "$PROJ")"
run -- list
rc_is "list exits 0" 0
calls_are "list makes no calls" ""
out_has "list: installed" "alpha        installed  (local)"
out_has "list: disabled"  "beta         disabled   (local)"
out_has "list: absent"    "all-plugins  absent     (local)"
out_has "list summary" "installed 1, disabled 1, absent 1 of 3 leaves at scope local"

# ---- 9. usage and prerequisites: exit 2, fix on stderr -----------------------------------
run -- install --scope global
rc_is "bad scope exits 2" 2
err_has "bad scope names the valid ones" "local, project or user"
run -- frobnicate
rc_is "unknown subcommand exits 2" 2
run --
rc_is "no subcommand exits 2" 2
err_has "no subcommand prints usage" "usage: all-plugins.sh"
run -- install --bogus
rc_is "unknown flag exits 2" 2
SHIM_MARKETPLACES="$MARKETS_NONE" run -- install
rc_is "unregistered marketplace exits 2" 2
err_has "unregistered marketplace names the add command" "claude plugin marketplace add galaykos/cc-marketplace"
calls_are "unregistered marketplace makes no calls" ""
run -- list --marketplace other
rc_is "--marketplace selects by name (other is registered, its clone dir is missing)" 2
err_has "a registered marketplace with no clone names the update command" "claude plugin marketplace update other"
run -- list --marketplace nope
rc_is "an unregistered non-default marketplace exits 2" 2
err_has "a non-default marketplace gets the generic add shape" "claude plugin marketplace add <owner/repo of nope>"
# A sandbox PATH: bash and the shim only, so `command -v` sees exactly what we put there.
SAND="$WS/sand"; mkdir -p "$SAND"; ln -s "$(command -v bash)" "$SAND/bash"
OUT=$(cd "$PROJ" && PATH="$SAND" bash "$SCRIPT" install 2>"$WS/err"); RC=$?; ERR=$(cat "$WS/err")
rc_is "no claude on PATH exits 2" 2
err_has "no claude names the fix" "'claude' is not on PATH"
ln -s "$BIN/claude" "$SAND/claude"
OUT=$(cd "$PROJ" && PATH="$SAND" bash "$SCRIPT" install 2>"$WS/err"); RC=$?; ERR=$(cat "$WS/err")
rc_is "no jq on PATH exits 2" 2
err_has "no jq names the fix" "'jq' is not on PATH"
# Unreadable manifest: root reads anything, so skip rather than assert a falsehood.
chmod 000 "$MK/.claude-plugin/marketplace.json"
if [ -r "$MK/.claude-plugin/marketplace.json" ]; then
  printf 'SKIP  unreadable marketplace.json (running as root)\n'
else
  run -- list
  rc_is "unreadable marketplace.json exits 2" 2
  err_has "unreadable marketplace.json names the update command" "claude plugin marketplace update $MK_NAME"
fi
chmod 644 "$MK/.claude-plugin/marketplace.json"

# ---- 10. the structural property that makes --self safe ---------------------------------
if [ "$(tail -n 1 "$SCRIPT")" = 'main "$@"' ]; then ok 'main "$@" is the last line of the script'
else bad 'main "$@" is the last line of the script' "got: $(tail -n 1 "$SCRIPT")"; fi
if ! grep -qE '(^|[^-])-y( |$)|--yes' "$SCRIPT"; then ok "the script never passes -y"
else bad "the script never passes -y" "$(grep -nE '(^|[^-])-y( |$)|--yes' "$SCRIPT")"; fi

if command -v shellcheck >/dev/null 2>&1; then
  if sc=$(shellcheck "$SCRIPT" 2>&1); then ok "shellcheck clean"; else bad "shellcheck clean" "$sc"; fi
else
  printf 'SKIP  shellcheck not installed\n'
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
