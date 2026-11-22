#!/usr/bin/env bash
# accept-guard.test.sh — asserts hooks/accept-guard.sh denies claude plugin update/install with -y, --yes or --accept-command in every
#   spelling it reads, stays silent on the flagless command and on text that only names it, fails open, and runs as hooks.json starts it.
# Why, limits, history: rationale/derivations/plugin-plugin-updater.md § plugins/plugin-updater/scripts/__tests__/accept-guard.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/accept-guard.sh"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
pass=0; fail=0
ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

payload() { jq -cn --arg c "$1" '{session_id:"s",transcript_path:"/tmp/t.jsonl",cwd:"/tmp",permission_mode:"default",hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
verdict() { local out; out=$(payload "$1" | bash "$HOOK" 2>/dev/null); [ -n "$out" ] || { echo silent; return; }; printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "unparsed"'; }
expect() { local got; got=$(verdict "$2"); [ "$got" = "$1" ] && ok "$1: $2" || bad "$1: $2" "got $got"; }

for c in 'claude plugin update foo@m -y' 'claude plugin update foo@m --scope user --yes' \
  'claude plugin install foo@m --accept-command abc123' 'claude plugin install foo@m --accept-command=abc' \
  'claude plugins i foo@m -y' 'claude plugin update foo -ys user' 'cd /x && claude plugin update foo -y' \
  'bash -c "claude plugin update foo -y"' 'sudo -u bob claude plugin update foo -y' 'CLAUDE_CONFIG_DIR=/x claude plugin update foo -y' \
  '/usr/local/bin/claude plugin update foo "-y"' 'npx @anthropic-ai/claude-code plugin update foo -y' \
  "eval 'claude plugin update foo -y'" 'ls | xargs claude plugin update -y' \
  $'echo hi # a comment\nclaude plugin update foo -y' $'bash <<\'EOF\'\nclaude plugin update foo -y\nEOF' \
  $'cat <<EOF | sh\nclaude plugin install foo --yes\nEOF'; do
  expect deny "$c"
done
# The nearest neighbours: the flagless command the script itself runs, other subcommands, and text that only names the flag.
for c in 'claude plugin update foo@m' 'claude plugin update foo --json --scope project' 'claude plugin install foo -s user' \
  'claude plugin marketplace update m' 'claude plugin list --json' 'claude plugin update --help' 'claude plugin update foo -- -y' \
  'git commit -m "never run claude plugin update -y"' 'echo "claude plugin update foo -y"' 'grep -rn "claude plugin update" . -y' \
  $'cat > notes.md <<\'EOF\'\nclaude plugin update foo -y\nEOF' 'yarn install -y' 'git status && ls' 'bash ./update.sh -y'; do
  expect silent "$c"
done

r=$(payload 'claude plugin update foo -y' | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')
case "$r" in *'Do not retry it in another form'*'without the flag'*) ok "the deny says not to retry and to hand the command over" ;;
  *) bad "the deny says not to retry and to hand the command over" "$r" ;; esac
n=$(payload 'claude plugin update foo -y' | bash "$HOOK" 2>/dev/null | wc -l | tr -d ' ')
[ "$n" = 1 ] && ok "the deny is one line" || bad "the deny is one line" "$n lines"

out=$(printf 'garbage' | bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc out=$out"
out=$(payload "claude plugin update foo 'unbalanced -y" | bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on an unbalanced quote" || bad "fail-open on an unbalanced quote" "rc=$rc out=$out"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"; for b in bash cat jq; do ln -s "$(command -v "$b")" "$T/bin/$b"; done
out=$(payload 'claude plugin update foo -y' | PATH="$T/bin" bash "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "no python3 on PATH: silent" || bad "no python3 on PATH: silent" "rc=$rc out=$out"

# The entry as the host runs it: /bin/sh -c with the plugin root in the environment.
HJ="$(dirname "$HOOK")/hooks.json"; n=0
while IFS= read -r c; do
  n=$((n+1))
  d=$(payload 'claude plugin update foo -y' | CLAUDE_PLUGIN_ROOT="$(dirname "$(dirname "$HOOK")")" /bin/sh -c "$c" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision // empty')
  [ "$d" = deny ] && ok "hooks.json runs accept-guard.sh and it denies" || bad "hooks.json runs accept-guard.sh and it denies" "got '${d:-<silent>}' from $c"
done < <(jq -r '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | test("accept-guard\\.sh")) | .command' "$HJ" 2>/dev/null)
[ "$n" -gt 0 ] || bad "hooks.json registers accept-guard.sh on Bash" "no entry in $HJ"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
