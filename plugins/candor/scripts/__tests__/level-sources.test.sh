#!/usr/bin/env bash
# Author-time tests for candor/scripts/level.sh — the resolver behind the statusline badge,
# measure.sh, /candor:level and /candor:check — against the hooks' order: CC_TERSE, the level
# file, the cc_terse /config option, off; an invalid winner is off, never a fall-through.
#
# A level set only through the option used to be active (the hooks read it) but reported as
# unset by every one of those readers. Picked up by the CI step that globs
# plugins/*/scripts/__tests__/*.test.sh.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
S="$ROOT/plugins/candor/scripts"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$S/level.sh" ] || { echo "FAIL: $S/level.sh not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
# Never the runner's real ~/.claude or managed settings: a level or saved option there would
# decide every case.
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

# ---- level.sh: one layer at a time, then the order between them ----------------
fixture '' '';        eq "nothing set"                            "$(level)" "off off"
fixture '' full;      eq "option in user settings only"           "$(level)" "full option"
fixture lite full;    eq "level file beats the option"            "$(level)" "lite file"
fixture lite full;    eq "CC_TERSE beats file and option"         "$(level CC_TERSE=ultra)" "ultra env"
fixture '' '';        eq "CLAUDE_PLUGIN_OPTION_CC_TERSE alone"    "$(level CLAUDE_PLUGIN_OPTION_CC_TERSE=full)" "full option"
fixture '' bogus;     eq "invalid option is off"                  "$(level)" "off option"
fixture full '';      eq "invalid CC_TERSE is off, file unused"   "$(level CC_TERSE=bogus)" "off env"

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

# ---- statusline.sh -------------------------------------------------------------
fixture '' full;  eq "badge shows an option-only level"  "$(badge)" "$(printf '\033[2;36m[TERSE:FULL]\033[0m')"
fixture '' full;  eq "badge: CC_TERSE beats the option"  "$(badge CC_TERSE=ultra)" "$(printf '\033[2;36m[TERSE:ULTRA]\033[0m')"
fixture '' '';    eq "badge silent when off"             "$(badge)" ""
fixture '' full; printf 'lite\n' > "$TMP/elsewhere"; ln -s "$TMP/elsewhere" "$CLAUDE_CONFIG_DIR/terse-mode"
eq "badge refuses a symlinked level file" "$(badge)" ""

# ---- measure.sh reports the level level.sh resolves --------------------------
printf '%s\n' '{"type":"assistant","message":{"id":"m1","content":[{"type":"text","text":"done"}]}}' > "$TMP/t.jsonl"
for c in "|" "|full" "lite|full" "|bogus" "full|:CC_TERSE=ultra" "|:CLAUDE_PLUGIN_OPTION_CC_TERSE=lite" "full|:CC_TERSE=bogus"; do
  spec=${c%%:*}; var=""; case "$c" in *:*) var=${c#*:} ;; esac
  fixture "${spec%%|*}" "${spec#*|}"
  set -- ${var:+"$var"}
  want=$(level "$@"); want=${want%% *}
  got=$(env "$@" bash "$S/measure.sh" --session-file "$TMP/t.jsonl" 2>&1 | sed -n 's/^level *: \([^ ]*\) .*/\1/p')
  eq "measure.sh level matches level.sh [$c]" "$got" "$want"
done

exit $rc
