#!/usr/bin/env bash
# Tests plugins/git-workflow/hooks/no-ai-trailer.sh.
#
# Picked up by the repo's "Plugin author-time lint + harness tests" CI step,
# which globs plugins/*/scripts/__tests__/*.test.sh.
#
# Three sections:
#   1. CLASSIFICATION — commands that must be denied, and the ALLOW rows that
#      matter more: a guard that fires on `git log | grep co-authored` or on a
#      human co-author trailer gets switched off, and then it guards nothing.
#   2. HOOK PROTOCOL — real PreToolUse stdin for Bash and Write/Edit, the
#      deny JSON shape, the CLAUDE_AI_TRAILER=allow switch.
#   3. FAIL-OPEN — no jq, malformed JSON, empty input: silent, exit 0.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GUARD="$here/../../hooks/no-ai-trailer.sh"
BASH_BIN="$(command -v bash)"

[ -f "$GUARD" ] || { printf 'FAIL: guard not found at %s\n' "$GUARD"; exit 1; }
[ -x "$GUARD" ] || { printf 'FAIL: %s is not executable\n' "$GUARD"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

tier_of() { "$BASH_BIN" "$GUARD" --check "$1" >/dev/null 2>&1; case $? in 0) echo allow ;; 2) echo deny ;; *) echo error ;; esac; }
expect() { local want="$1" cmd="$2" got; got=$(tier_of "$cmd"); [ "$got" = "$want" ] && ok || bad "want $want, got $got" "$cmd"; }

TRAILER='Co-Authored-By: Claude <noreply@anthropic.com>'
GEN='🤖 Generated with [Claude Code](https://claude.com/claude-code)'

printf '== classification: deny\n'
expect deny "git commit -m \"feat: x

$TRAILER\""                                              # the shape observed on 2.1.266 with attribution.commit=""
expect deny "git commit -m \"feat: x\" -m \"$TRAILER\""
expect deny "git commit --amend -m \"fix: y

$GEN\""
expect deny "git commit --trailer 'Co-authored-by: Claude Opus <noreply@anthropic.com>' -m x"
expect deny "git -c user.name=x commit -F- <<EOF
feat: y

$GEN

$TRAILER
EOF"
expect deny "git commit -m \"\$(cat <<'EOF'
feat: z

co-authored-by: claude <noreply@anthropic.com>
EOF
)\""
expect deny "git merge --no-ff topic -m \"merge topic

$TRAILER\""
expect deny "git tag -a v1 -m \"v1

$TRAILER\""
expect deny "gh pr create --title t --body \"$GEN\""
expect deny "gh pr merge 12 --squash --body \"$TRAILER\""
expect deny "cd /repo && git add -A && git commit -m \"x

$TRAILER\""
expect deny "git commit -m 'x' -m 'Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>'"

printf '== classification: allow\n'
expect allow 'git commit -m "fix: drop the co-authored-by trailer from the release script"'
expect allow 'git log --format=%B | grep -i "co-authored-by: claude"'
expect allow 'grep -rn "Co-Authored-By: Claude" plugins/'
expect allow 'git commit -m "docs: credit" --trailer "Co-authored-by: Jane Doe <jane@example.com>"'
expect allow 'git commit -m "feat: add claude api client"'
expect allow 'git commit -m "chore: regenerate with claude-code chassis"'
expect allow 'git push origin HEAD'
expect allow 'gh pr view 12 --json body'
expect allow 'echo "Co-Authored-By: Claude" > /tmp/scratch.txt'
expect allow ''

printf '== hook protocol\n'
payload() { # tool_name command
  jq -cn --arg t "$1" --arg c "$2" '{session_id:"s1",transcript_path:"/tmp/t.jsonl",hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$c}}'
}
out=$(payload Bash "git commit -m \"x

$TRAILER\"" | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && ok || bad "deny path must exit 0, got $rc" "Bash deny"
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "expected permissionDecision deny" "$out"
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null 2>&1 && ok || bad "expected hookEventName PreToolUse" "$out"
printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -q 'Co-Authored-By' && ok || bad "reason must name the trailer" "$out"

out=$(payload Bash 'git commit -m "fix: y"' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "clean commit must be silent" "rc=$rc out=$out"

out=$(payload mcp__phpstorm__execute_terminal_command "git commit -m \"x

$TRAILER\"" | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "MCP terminal tool must be classified too" "$out"

out=$(jq -cn --arg c "$TRAILER" '{session_id:"s1",transcript_path:"/tmp/t.jsonl",hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:"/repo/.git/COMMIT_EDITMSG",content:("x\n\n"+$c)}}' | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "Write into COMMIT_EDITMSG must be denied" "$out"

out=$(jq -cn --arg c "$TRAILER" '{tool_name:"Edit",tool_input:{file_path:"/repo/.git/MERGE_MSG",old_string:"x",new_string:$c}}' | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "Edit into MERGE_MSG must be denied" "$out"

out=$(jq -cn --arg c "$TRAILER" '{tool_name:"Write",tool_input:{file_path:"/repo/docs/history.md",content:$c}}' | "$BASH_BIN" "$GUARD")
[ -z "$out" ] && ok || bad "a doc mentioning the trailer is not a git message file" "$out"

out=$(payload Bash "git commit -m \"x

$TRAILER\"" | CLAUDE_AI_TRAILER=allow "$BASH_BIN" "$GUARD")
[ -z "$out" ] && ok || bad "CLAUDE_AI_TRAILER=allow must disable the guard" "$out"

printf '== fail-open\n'
out=$(printf 'not json' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "malformed input must be silent exit 0" "rc=$rc out=$out"
out=$(printf '' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "empty input must be silent exit 0" "rc=$rc out=$out"
out=$(payload Bash "git commit -m \"$TRAILER\"" | PATH=/nonexistent "$BASH_BIN" "$GUARD" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "no jq on PATH must be silent exit 0" "rc=$rc out=$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
