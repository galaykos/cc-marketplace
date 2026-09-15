#!/usr/bin/env bash
# Fixture tests for hooks/config-guard.sh — the guard on the agent's own guardrails.
# Asserts every ask path, every allow path, the self-exemption, and fail-open.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/config-guard.sh"
BASH_BIN="${BASH:-bash}"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

fire() { # path [tool]
  python3 -c "
import json,sys
print(json.dumps({'session_id':'cg','cwd':sys.argv[2],'tool_name':sys.argv[3],
  'tool_input':{'file_path':sys.argv[1],'old_string':'a','new_string':'b'}}))
" "$1" "$T" "${2:-Edit}" | "$BASH_BIN" "$HOOK" 2>/dev/null
}
asks()   { out=$(fire "$1"); case "$out" in *'"permissionDecision":"ask"'*) ok "$2" ;; *) bad "$2" "expected ask, got: ${out:-<silent>}" ;; esac; }
allows() { out=$(fire "$1"); [ -z "$out" ] && ok "$2" || bad "$2" "expected silence, got: $out"; }

mkdir -p "$T/.claude" "$T/hooks" "$T/plugins/x/.claude-plugin" "$T/src"
for f in .claude/settings.json .claude/settings.local.json hooks/hooks.json .eslintrc.json \
         tsconfig.json .rubocop.yml phpstan.neon .golangci.yml pytest.ini biome.json \
         plugins/x/.claude-plugin/plugin.json hooks/guard.sh src/app.ts README.md; do
  printf '{}\n' > "$T/$f"
done

# --- ask paths ---------------------------------------------------------------
asks "$T/.claude/settings.json"        "settings.json asks"
asks "$T/.claude/settings.local.json"  "settings.local.json asks"
asks "$T/hooks/hooks.json"             "a hooks manifest asks"
asks "$T/hooks/guard.sh"               "a hook script asks"
asks "$T/plugins/x/.claude-plugin/plugin.json" "a plugin manifest asks"
asks "$T/.eslintrc.json"               "eslint config asks"
asks "$T/tsconfig.json"                "tsconfig asks"
asks "$T/.rubocop.yml"                 "rubocop config asks"
asks "$T/phpstan.neon"                 "phpstan config asks"
asks "$T/.golangci.yml"                "golangci config asks"
asks "$T/pytest.ini"                   "pytest config asks"
asks "$T/biome.json"                   "biome config asks"

# --- allow paths -------------------------------------------------------------
allows "$T/src/app.ts"      "ordinary source is silent"
allows "$T/README.md"       "a README is silent"
allows "$T/.prettierrc"     "an unlisted config is silent (the list is literal)"
allows "$T/.claude/settings.json.new" "a path that only resembles a target is silent"

# creating a config is not relaxing one
rm -f "$T/.flake8"
allows "$T/.flake8" "a config that does not exist yet is silent (nothing to weaken)"

# --- self-exemption ----------------------------------------------------------
printf '{}\n' > "$T/.claude-plugin-marker-absent"
mkdir -p "$T/.claude-plugin" && printf '{"plugins":[]}\n' > "$T/.claude-plugin/marketplace.json"
out=$(fire "$T/.claude/settings.json")
[ -z "$out" ] && ok "silent inside a marketplace repo (it edits these files as its product)" \
  || bad "silent inside a marketplace repo" "asked anyway: $out"
rm -rf "$T/.claude-plugin"

# --- off switch --------------------------------------------------------------
out=$(python3 -c "
import json
print(json.dumps({'session_id':'cg','cwd':'$T','tool_name':'Edit','tool_input':{'file_path':'$T/.claude/settings.json','old_string':'a','new_string':'b'}}))
" | CC_CONFIG_GUARD=off "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "CC_CONFIG_GUARD=off silences it" || bad "CC_CONFIG_GUARD=off silences it" "$out"

# --- fail-open ---------------------------------------------------------------
out=$(printf 'garbage' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc"
out=$(fire "$T/.claude/settings.json" Bash)
[ -z "$out" ] && ok "silent on a tool it does not match" || bad "silent on a tool it does not match" "$out"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
