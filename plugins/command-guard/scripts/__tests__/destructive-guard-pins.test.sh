#!/usr/bin/env bash
# destructive-guard-pins.test.sh — pins the paths of hooks/destructive-guard.sh's family helpers that destructive-guard.test.sh does not reach.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GUARD="$here/../../hooks/destructive-guard.sh"
BASH_BIN="$(command -v bash)"

[ -x "$GUARD" ] || { printf 'FAIL: %s is missing or not executable\n' "$GUARD"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
unset CLAUDE_DESTRUCTIVE_GUARD CLAUDE_PLUGIN_OPTION_CLAUDE_DESTRUCTIVE_GUARD GUARD_SQL_CTX
export HOME="$WS/home" CLAUDE_PROJECT_DIR="$WS"
mkdir -p "$HOME"
pass=0; fail=0

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

check_out() { "$BASH_BIN" "$GUARD" --check "$1" 2>/dev/null; }

# check_is <label> <exit> <first line> <second-line prefix or ""> <command>
check_is() {
  local out rc l1 l2
  out=$(check_out "$5"); rc=$?
  l1=$(printf '%s\n' "$out" | sed -n 1p); l2=$(printf '%s\n' "$out" | sed -n 2p)
  if [ "$rc" = "$2" ] && [ "$l1" = "$3" ] && { [ -z "$4" ] || [ "${l2#"$4"}" != "$l2" ]; }; then ok
  else bad "$1" "rc=$rc out=$out"; fi
}

tool_json() { jq -cn --arg t "$1" --argjson i "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i}'; }

decision() { # payload [env-assignments...] -> deny | ask | silent
  local json="$1" out; shift
  out=$(cd "$WS" && printf '%s' "$json" | env "$@" "$BASH_BIN" "$GUARD" 2>/dev/null)
  [ -n "$out" ] || { echo silent; return 0; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "unparsed"'
}

decision_is() { # label want payload [env...]
  local label="$1" want="$2" got; shift 2
  got=$(decision "$@")
  [ "$got" = "$want" ] && ok || bad "$label" "want $want, got $got"
}

ALLOW_FILE=/p/.claude/destructive-guard-allow

printf '== strip_git_global_options\n'
check_is 'git --no-pager and a spaced --work-tree are stripped before the table' 1 \
  'ASK    git reset --hard ' '' 'git --no-pager --work-tree /x reset --hard'
check_is 'an unknown git global option stays, so the table never sees the subcommand' 0 \
  'ALLOW git --exec-path=/x reset --hard' '' 'git --exec-path=/x reset --hard'

printf '== match_rule_table\n'
check_is 'an uppercase rule matches the case-preserved segment: git branch -D asks' 1 \
  'ASK    git branch -D feature/old ' '' 'git branch -D feature/old'
check_is 'an uppercase rule is case-sensitive: git branch -d is allowed' 0 \
  'ALLOW git branch -d feature/old' '' 'git branch -d feature/old'
check_is 'a lowercase rule reports the lowercased segment' 2 \
  'DENY   php artisan migrate:fresh ' '' 'php artisan MIGRATE:FRESH'
check_is 'an ask in an earlier segment does not stop the scan: a later rails db:drop still denies' 2 \
  'DENY   rails db:drop ' '' 'git reset --hard && rails db:drop'

printf '== check_cli\n'
check_is '--check prints ALLOW and the command, exit 0' 0 'ALLOW npm run build' '' 'npm run build'
check_is '--check prints ASK, the match and an indented reason, exit 1' 1 \
  'ASK    git reset --hard ' '      command-guard: this command discards every uncommitted change' 'git reset --hard'
check_is '--check prints DENY, the match and an indented reason, exit 2' 2 \
  'DENY   php artisan migrate:fresh ' '      BLOCKED by command-guard — this command drops every table' 'php artisan migrate:fresh'

printf '== guard_file_write\n'
decision_is 'MultiEdit on the allow-file is denied' deny \
  "$(tool_json MultiEdit "$(jq -cn --arg f "$ALLOW_FILE" '{file_path:$f}')")"
decision_is 'an apply_patch whose patch key names the allow-file is denied' deny \
  "$(tool_json mcp__x__apply_patch '{"patch":"*** Update File: .claude/destructive-guard-allow\n+x"}')"
decision_is 'the allow-file Write deny holds under CLAUDE_DESTRUCTIVE_GUARD=ask' deny \
  "$(tool_json Write "$(jq -cn --arg f "$ALLOW_FILE" '{file_path:$f,content:"x"}')")" CLAUDE_DESTRUCTIVE_GUARD=ask
printf 'APP_KEY=base64:abc\n' > "$WS/.env"
decision_is 'a Write over an existing .env still asks under CLAUDE_DESTRUCTIVE_GUARD=ask' ask \
  "$(tool_json Write '{"file_path":".env","content":"A=1"}')" CLAUDE_DESTRUCTIVE_GUARD=ask
rm -f "$WS/.env"

printf '== guard_command\n'
decision_is 'the cmd field of an MCP run_command tool is classified' deny \
  "$(tool_json mcp__x__run_command '{"cmd":"php artisan migrate:fresh"}')"
decision_is 'the script field is classified beside the command field' deny \
  "$(tool_json Bash '{"command":"echo ok","script":"php artisan migrate:fresh"}')"
decision_is 'an execute_sql_query tool is SQL by its name, with no query or sql field' deny \
  "$(tool_json mcp__db__execute_sql_query '{"script":"DROP DATABASE prod"}')"
decision_is 'an sql field makes a run_command payload SQL' deny \
  "$(tool_json mcp__x__run_command '{"sql":"DROP TABLE users"}')"
decision_is 'a shell_command tool is guarded' deny \
  "$(tool_json mcp__x__shell_command '{"command":"php artisan migrate:fresh"}')"
decision_is 'a run_in_terminal tool is guarded' deny \
  "$(tool_json mcp__x__run_in_terminal '{"command":"php artisan migrate:fresh"}')"
decision_is 'GUARD_SQL_CTX in the hook environment does not turn SQL rules on' silent \
  "$(tool_json Bash '{"command":"DROP TABLE users"}')" GUARD_SQL_CTX=1

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
