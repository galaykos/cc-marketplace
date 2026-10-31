#!/usr/bin/env bash
# level-sources.test.sh — asserts scripts/level.sh's order (CC_TERSE, the level file, the cc_terse option, off; an invalid winner is off) and its
#   settings reads, and that statusline.sh and measure.sh report the level level.sh resolves; HOME and both settings paths sandboxed.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/__tests__/level-sources.test.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
S="$ROOT/plugins/candor/scripts"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$S/level.sh" ] || { echo "FAIL: $S/level.sh not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
# Never the runner's real ~/.claude or managed settings: a level or option saved there would decide every case.
export HOME="$TMP/home" CLAUDE_CONFIG_DIR="$TMP/cfg" CANDOR_MANAGED_SETTINGS="$TMP/managed-settings.json"
mkdir -p "$HOME"
unset CC_TERSE CLAUDE_PLUGIN_OPTION_CC_TERSE

fixture() { # fixture <level-file word|''> <saved cc_terse|''>
  rm -rf "$CLAUDE_CONFIG_DIR" "$CANDOR_MANAGED_SETTINGS"; mkdir -p "$CLAUDE_CONFIG_DIR"
  [ -z "$1" ] || printf '%s\n' "$1" > "$CLAUDE_CONFIG_DIR/terse-mode"
  [ -z "$2" ] || jq -n --arg v "$2" \
    '{pluginConfigs:{"other@x":{options:{cc_terse:"ultra"}},"candor@cc-plugins-marketplace":{options:{cc_terse:$v}}}}' \
    > "$CLAUDE_CONFIG_DIR/settings.json"
  return 0
}
level() { env "$@" bash "$S/level.sh" 2>&1; }
badge() { env "$@" bash "$S/statusline.sh" 2>&1; }
plain() { printf '%s' "$1" | tr -d '\033' | sed 's/\[[0-9;]*m//g'; }
eq() { # eq <label> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS: $1 → $(plain "$2")"
  else echo "FAIL: $1 — want '$(plain "$3")', got '$(plain "${2:-<empty>}")'"; rc=1; fi
}

fixture '' '';        eq "nothing set"                            "$(level)" "off off"
fixture '' full;      eq "option in user settings only"           "$(level)" "full option"
fixture lite full;    eq "level file beats the option"            "$(level)" "lite file"
fixture lite full;    eq "CC_TERSE beats file and option"         "$(level CC_TERSE=ultra)" "ultra env"
fixture '' '';        eq "CLAUDE_PLUGIN_OPTION_CC_TERSE alone"    "$(level CLAUDE_PLUGIN_OPTION_CC_TERSE=full)" "full option"
fixture '' bogus;     eq "invalid option is off"                  "$(level)" "off option"
fixture full '';      eq "invalid CC_TERSE is off, file unused"   "$(level CC_TERSE=bogus)" "off env"
fixture newcomer '';  eq "a reader name adds its length level"    "$(level)" "newcomer file lite"
fixture '' expert;    eq "a reader name from the option"          "$(level)" "expert option full"
fixture lite '';      eq "a reader name in CC_TERSE beats the file" "$(level CC_TERSE=on-call)" "on-call env ultra"
fixture newbie '';    eq "an unknown name is off"                 "$(level)" "off file"
fixture on-call '';   eq "--sources shows the name and its length level" "$(bash "$S/level.sh" --sources 2>&1 | sed -n '2p;4p')" \
  "$(printf 'level file (%s/terse-mode): on-call\nactive: on-call file ultra' "$CLAUDE_CONFIG_DIR")"

fixture '' ''; printf '{"pluginConfigs": {' > "$CLAUDE_CONFIG_DIR/settings.json"
eq "malformed settings: off, nothing on stderr" "$(level)" "off off"

fixture '' ''
jq -n '{pluginConfigs:{"candor@m":{options:{cc_terse:"full"}}}}' > "$TMP/real-settings.json"
ln -s "$TMP/real-settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
eq "symlinked settings file is not read" "$(level)" "off off"
eq "--sources names the unread symlink" "$(bash "$S/level.sh" --sources 2>&1 | sed -n 3p)" \
  "cc_terse option ($CLAUDE_CONFIG_DIR/settings.json not read (symlink)): unset"

fixture '' lite
jq -n '{pluginConfigs:{"candor@corp":{options:{cc_terse:"full"}}}}' > "$CANDOR_MANAGED_SETTINGS"
eq "managed settings beat user settings" "$(level)" "full option"

fixture lite full
want=$(printf 'CC_TERSE: ultra\nlevel file (%s/terse-mode): lite\ncc_terse option (%s/settings.json): full\nactive: ultra env' \
  "$CLAUDE_CONFIG_DIR" "$CLAUDE_CONFIG_DIR")
eq "--sources names every layer and the winner" "$(CC_TERSE=ultra bash "$S/level.sh" --sources 2>&1)" "$want"

# --sources asks `claude plugin configure` from an installed path only. The stub replays the two shapes measured on the real CLI:
# 2.1.300's JSON (.inputs.cc_terse, "" when unset) and 2.1.284's `error: unknown command 'configure'` with exit 1.
INST="$TMP/plugins/cache/mkt/candor/1.0/scripts"; mkdir -p "$INST" "$TMP/bin"; cp "$S/level.sh" "$INST/level.sh"
cat > "$TMP/bin/claude" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_LOG"
[ -n "${STUB_OLD:-}" ] && { echo "error: unknown command 'configure'" >&2; exit 1; }
printf '{"pluginId":"%s","inputs":{"cc_terse":"%s"}}\n' "$4" "$STUB_VALUE"
STUB
chmod +x "$TMP/bin/claude"
host() { env PATH="$TMP/bin:$PATH" STUB_LOG="$TMP/stub.log" "$@"; }
fixture '' full; : > "$TMP/stub.log"
eq "--sources prefers the host's resolved option" "$(host STUB_VALUE=ultra bash "$INST/level.sh" --sources | sed -n '3p;4p')" \
  "$(printf "cc_terse option (claude plugin configure candor@mkt: user, managed and drop-ins; not this session's --settings): ultra\nactive: ultra option")"
eq "configure is asked for the installed id" "$(cat "$TMP/stub.log")" "plugin configure candor@mkt --json"
eq "an option the host reports unset is unset" "$(host STUB_VALUE= bash "$INST/level.sh" --sources | sed -n 4p)" "active: off off"
fixture '' full
eq "CLI without configure (<2.1.285): settings file read" "$(host STUB_OLD=1 bash "$INST/level.sh" --sources 2>&1 | sed -n '3p;4p')" \
  "$(printf 'cc_terse option (%s/settings.json): full\nactive: full option' "$CLAUDE_CONFIG_DIR")"
: > "$TMP/stub.log"
eq "badge path never asks the host" "$(host STUB_VALUE=ultra bash "$INST/level.sh")" "full option"
eq "a checkout path never asks the host" "$(host STUB_VALUE=ultra bash "$S/level.sh" --sources | sed -n 4p)" "active: full option"
eq "neither call reached the stub" "$(cat "$TMP/stub.log")" ""

fixture '' full;  eq "badge shows an option-only level"  "$(badge)" "$(printf '\033[2;36m[TERSE:FULL]\033[0m')"
fixture '' full;  eq "badge: CC_TERSE beats the option"  "$(badge CC_TERSE=ultra)" "$(printf '\033[2;36m[TERSE:ULTRA]\033[0m')"
fixture '' '';    eq "badge silent when off"             "$(badge)" ""
fixture newcomer ''; eq "badge shows a reader name and its length level" "$(badge)" "$(printf '\033[2;36m[TERSE:NEWCOMER/LITE]\033[0m')"
fixture '' on-call;  eq "badge: a reader name from the option" "$(badge)" "$(printf '\033[2;36m[TERSE:ON-CALL/ULTRA]\033[0m')"
fixture newbie '';   eq "badge silent for an unknown name"     "$(badge)" ""
fixture '' full; printf 'lite\n' > "$TMP/elsewhere"; ln -s "$TMP/elsewhere" "$CLAUDE_CONFIG_DIR/terse-mode"
eq "badge refuses a symlinked level file" "$(badge)" ""

printf '%s\n' '{"type":"assistant","message":{"id":"m1","content":[{"type":"text","text":"done"}]}}' > "$TMP/t.jsonl"
for c in "|" "|full" "lite|full" "|bogus" "full|:CC_TERSE=ultra" "|:CLAUDE_PLUGIN_OPTION_CC_TERSE=lite" "full|:CC_TERSE=bogus" \
         "newcomer|" "|expert" "full|:CC_TERSE=on-call"; do
  spec=${c%%:*}; var=""; case "$c" in *:*) var=${c#*:} ;; esac
  fixture "${spec%%|*}" "${spec#*|}"
  set -- ${var:+"$var"}
  want=$(level "$@"); want=${want%% *}
  got=$(env "$@" bash "$S/measure.sh" --session-file "$TMP/t.jsonl" 2>&1 | sed -n 's/^level *: \([^ ]*\) .*/\1/p')
  eq "measure.sh level matches level.sh [$c]" "$got" "$want"
done
for c in newcomer:18 expert:12 on-call:6; do
  fixture "${c%%:*}" ''
  eq "measure.sh grades ${c%%:*} against its length level's ceiling" \
    "$(bash "$S/measure.sh" --session-file "$TMP/t.jsonl" 2>&1 | sed -n 's/^level *: //p')" "${c%%:*} (ceiling ${c#*:} prose lines)"
done

exit $rc
