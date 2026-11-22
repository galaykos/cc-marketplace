#!/usr/bin/env bash
# Tests plugins/stack-scan/hooks/install-guard.sh: the verdict table (deny, ask, and the nearest
# commands that must stay silent), the PreToolUse JSON it prints, and its fail-open paths.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GUARD="$here/../../hooks/install-guard.sh"
BASH_BIN="$(command -v bash)"

[ -x "$GUARD" ] || { printf 'FAIL: %s missing or not executable\n' "$GUARD"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
expect() { local got; got=$("$BASH_BIN" "$GUARD" --check "$2"); [ "$got" = "$1" ] && ok || bad "want $1, got $got" "$2"; }

printf '== verdicts\n'
expect deny "npx -y skills add o/r --skill 'X' -y -g"
expect deny "npx skills add o/r --global"
expect deny "npx -y skills add o/r --skill '*' -y"
expect deny "npx skills add o/r --all"
expect deny "bunx skills add o/r -g"
expect deny "pnpm dlx skills add o/r --all"
expect deny "cd /x && npx -y skills@latest add o/r -gy"
expect deny "npx skills install o/r -g"
expect deny "bash -c 'npx skills add o/r -g'"
expect deny "bash <<'EOF'
npx skills add o/r -g
EOF"
expect deny "npx skills add o/r --skill=*"
expect deny "/usr/bin/npx skills add o/r -g"
expect deny "FOO=1 sudo npx skills add o/r -g"
expect allow "npx -y skills add o/r --skill 'Plugin Structure' -y"
expect allow "npx -y skills add o/r -l"
expect allow "npx -y skills ls -g"
expect allow "echo \"never pass npx skills add -g\""
expect allow "grep -rn \"skills add -g\" plugins/"
expect allow "cat > notes.md <<'EOF'
npx skills add o/r -g
EOF"
expect allow "npm install -g typescript"
expect allow "npx skills add o/r --agent '*' --skill 'X'"
expect ask "claude plugin install foo@m"
expect ask "claude plugin i foo@m"
expect ask "claude plugins uninstall foo"
expect ask "claude plugin enable foo"
expect ask "claude plugin disable --all"
expect allow "claude plugin install foo@m --scope local"
expect allow "claude plugin install foo@m -s project"
expect allow "claude plugin install foo@m --scope=user"
expect allow "claude plugin list"
expect allow "claude plugin marketplace add x/y"
expect allow "claude plugin install --help"
expect allow "echo claude plugin install foo"
expect ask "npm audit fix --force"
expect ask "npm audit fix -f"
expect ask "cd app && npm audit fix --force --omit=dev"
expect allow "npm audit fix"
expect allow "npm audit --json"
expect allow "npm install --force"
expect deny "claude plugin install x; npx skills add o/r -g"
expect allow "git commit -m \"chore: npx skills add -g is denied now\""

expect deny "env FOO=1 npx skills add o/r --global"
expect deny "eval 'npx skills add o/r --all'"
expect ask "timeout 60 claude plugin install foo@m"
expect allow "claude plugin install foo@m -sproject"

printf '== hook protocol\n'
payload() { jq -cn --arg t "$1" --arg c "$2" '{session_id:"s1",transcript_path:"/tmp/t.jsonl",cwd:"/tmp",hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$c}}'; }
out=$(payload Bash 'npx -y skills add o/r --skill "*" -y' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && ok || bad "deny path must exit 0, got $rc" "$out"
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "expected a PreToolUse deny" "$out"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] && ok || bad "output must be one line" "$out"
printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -qF -- "--skill '*'" && ok || bad "deny reason must name the flag" "$out"
out=$(payload Bash 'claude plugin install foo@cc-plugins-marketplace' | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1 && ok || bad "expected an ask" "$out"
printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -qF 'user scope' && ok || bad "install ask must name the user-scope default" "$out"
out=$(payload Bash 'claude plugin disable foo' | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -qF 'auto-detects' && ok || bad "disable ask must name the auto-detected default" "$out"
out=$(payload mcp__ide__run_in_terminal 'npm audit fix --force' | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1 && ok || bad "an MCP terminal tool is classified too" "$out"
out=$(payload Bash 'npx -y skills add o/r --skill "X" -y' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "an allowed install must be silent" "rc=$rc out=$out"

printf '== fail-open\n'
out=$(printf 'not json' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "malformed input: silent exit 0" "rc=$rc out=$out"
out=$(printf '' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "empty input: silent exit 0" "rc=$rc out=$out"
out=$(payload Bash 'npx skills add o/r -g' | PATH=/nonexistent "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "no jq on PATH: silent exit 0" "rc=$rc out=$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
