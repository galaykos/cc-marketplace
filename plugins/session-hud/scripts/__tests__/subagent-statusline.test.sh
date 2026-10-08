#!/usr/bin/env bash
# subagent-statusline.test.sh — asserts scripts/subagent-statusline.sh's rows (type, model, effort, context use, age, label; the
#   completed and failed marks; the width cut), that unreadable input and the three off sources leave every row default, and that a
#   malformed task is skipped. HOME and CLAUDE_CONFIG_DIR are sandboxed so the runner's saved options decide nothing.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
S="$ROOT/plugins/session-hud/scripts/subagent-statusline.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
[ -f "$S" ] || { echo "FAIL: $S not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" CLAUDE_CONFIG_DIR="$TMP/cfg"
mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR"
unset CC_HUD_SUBAGENTS CLAUDE_PLUGIN_OPTION_CC_HUD_SUBAGENTS
rc=0

NOW=$(( $(date +%s) * 1000 ))
task() { # task <id> <extra json fields>
  printf '{"id":"%s","type":"local_agent","status":"running","description":"List files","label":"Reading README.md","tokenCount":12345,"tokenSamples":[],"cwd":"/w"%s}' "$1" "$2"
}
input() { printf '{"columns":%s,"session_id":"s","tasks":[%s]}' "$1" "$2"; }
rows() { env "$@" bash "$S" 2>&1; }
eq() { # eq <label> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — want '$3', got '${2:-<empty>}'"; rc=1; fi
}

FULL="$(task t1 ",\"agentType\":\"Explore\",\"model\":\"claude-haiku-4-5-20251001\",\"effort\":\"low\",\"contextWindowSize\":200000,\"startTime\":$((NOW - 65000))")"
eq "full row" "$(input 120 "$FULL" | rows)" \
  '{"id":"t1","content":"Explore · haiku-4-5 · low · 12.3k 6% · 1m05s · Reading README.md"}'

NAMED="$(task t2 ",\"name\":\"rev\",\"agentType\":\"code-reviewer\",\"status\":\"completed\",\"tokenCount\":900,\"startTime\":$((NOW - 5000))")"
eq "named, completed, no model or window" "$(input 120 "$NAMED" | rows)" \
  '{"id":"t2","content":"✓ @rev · code-reviewer · 900 · 5s · Reading README.md"}'

FAILED="$(task t3 ",\"agentType\":\"Plan\",\"status\":\"failed\",\"startTime\":$((NOW - 3725000))")"
eq "failed mark and an hour-long age" "$(input 120 "$FAILED" | rows)" \
  '{"id":"t3","content":"✗ Plan · 12.3k · 1h02m · Reading README.md"}'

eq "cut to the row width" "$(input 20 "$FULL" | rows | jq -r .content)" 'Explore · haiku-4-5 '

eq "malformed task skipped, good one kept" "$(input 120 "{\"bad\":1},$NAMED" | rows | jq -r .id)" 't2'
eq "unreadable input prints nothing" "$(printf 'not json' | rows)" ''
eq "CC_HUD_SUBAGENTS=off prints nothing" "$(input 120 "$FULL" | rows CC_HUD_SUBAGENTS=off)" ''
eq "plugin option off prints nothing" "$(input 120 "$FULL" | rows CLAUDE_PLUGIN_OPTION_CC_HUD_SUBAGENTS=false)" ''

printf '{"pluginConfigs":{"other@x":{"options":{"cc_hud_subagents":false}},"session-hud@cc-plugins-marketplace":{"options":{"cc_hud_subagents":false}}}}' \
  > "$CLAUDE_CONFIG_DIR/settings.json"
eq "saved option off prints nothing" "$(input 120 "$FULL" | rows)" ''
eq "CC_HUD_SUBAGENTS=on beats a saved off" "$(input 120 "$FULL" | rows CC_HUD_SUBAGENTS=on | jq -r .id)" 't1'

exit $rc
