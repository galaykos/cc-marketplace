#!/usr/bin/env bash
# Tests for scope.sh (PostToolUse scope-lock tripwire).
#
# The hook's warn channel is the PostToolUse stdout JSON envelope
# ({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}})
# with exit 0 — the one non-blocking channel the executing model receives. Plain
# text on stdout never reaches it, which is the fault these cases lock against
# regressing. Every fixture lives under a mktemp -d workspace; the hook is driven
# with canned PostToolUse stdin JSON and judged on rc + stdout + stderr.
set -u

here=$(cd "$(dirname "$0")" && pwd)
HOOK="$here/../../hooks/scope.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT

CWD="$WS/repo"; mkdir -p "$CWD/.claude/task-runner"
SCOPE="$CWD/.claude/task-runner/scope.json"

stdin_for() { # <file_path> -> canned PostToolUse stdin
  jq -cn --arg cwd "$CWD" --arg f "$1" \
    '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}}'
}

# run_case <desc> <stdin> <exp_rc> <stdout: envelope|silent> [ctx-substr...]
# envelope: stdout must parse as the PostToolUse envelope and additionalContext
#           must contain every listed substring.
# silent:   stdout must be empty (fail-open / in-scope paths emit no envelope).
run_case() {
  local desc="$1" json="$2" exp_rc="$3" mode="$4"; shift 4
  local out rc ok=1 reason="" ctx sub
  set +e
  out=$(printf '%s' "$json" | bash "$HOOK" 2>/dev/null); rc=$?
  set +e
  [ "$rc" = "$exp_rc" ] || { ok=0; reason="rc=$rc want=$exp_rc"; }
  if [ "$mode" = envelope ]; then
    if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
      ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
      [ -n "$ctx" ] || { ok=0; reason="$reason; additionalContext empty"; }
      for sub in "$@"; do
        case "$ctx" in *"$sub"*) ;; *) ok=0; reason="$reason; ctx missing <$sub>";; esac
      done
    else
      ok=0; reason="$reason; stdout is not the PostToolUse envelope: <$out>"
    fi
  else
    [ -z "$out" ] || { ok=0; reason="$reason; expected silent stdout, got <$out>"; }
  fi
  if [ "$ok" = 1 ]; then printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"; pass=$((pass+1))
  else printf 'FAIL: %s (%s)\n' "$desc" "$reason"; fail=$((fail+1)); fi
}

# 1) out-of-scope edit -> envelope on stdout with additionalContext naming the
#    file, the task, and the scope-creep instruction; exit 0 (never blocking).
printf '{"allow":["src/allowed.js","lib/"],"task":"card 07"}' > "$SCOPE"
run_case "out-of-scope edit -> additionalContext envelope" \
  "$(stdin_for "$CWD/other/file.js")" 0 envelope \
  "other/file.js" "card 07" "scope creep"

# 2) in-scope edit (exact allow entry) -> no envelope, exit 0
run_case "in-scope exact match -> silent" \
  "$(stdin_for "$CWD/src/allowed.js")" 0 silent

# 3) in-scope edit (directory-prefix allow entry) -> no envelope, exit 0
run_case "in-scope dir-prefix match -> silent" \
  "$(stdin_for "$CWD/lib/deep/nested.js")" 0 silent

# 4) editing scope.json itself is never in scope but always ignored
run_case "edit to scope.json itself -> silent" \
  "$(stdin_for "$CWD/.claude/task-runner/scope.json")" 0 silent

# 5) fail-open: no scope file declared -> no-op even for a wild edit
rm -f "$SCOPE"
run_case "missing scope file -> silent exit 0" \
  "$(stdin_for "$CWD/anywhere/at/all.js")" 0 silent

# 6) fail-open: malformed scope.json -> exit 0, NO envelope; the operator warning
#    goes to real stderr (fd 3), not into the model's context
printf '{not valid json' > "$SCOPE"
set +e
err=$(printf '%s' "$(stdin_for "$CWD/other/file.js")" | bash "$HOOK" 2>&1 1>/dev/null); erc=$?
set +e
if [ "$erc" = 0 ] && printf '%s' "$err" | grep -q "malformed"; then
  printf 'PASS: malformed scope.json -> exit 0, stderr warning (rc=%s)\n' "$erc"; pass=$((pass+1))
else
  printf 'FAIL: malformed scope.json (rc=%s err=<%s>)\n' "$erc" "$err"; fail=$((fail+1))
fi
run_case "malformed scope.json -> stdout stays silent" \
  "$(stdin_for "$CWD/other/file.js")" 0 silent
printf '{"allow":["src/allowed.js"],"task":"card 07"}' > "$SCOPE"

# 7) fail-open: malformed stdin -> exit 0, silent
run_case "malformed stdin -> silent exit 0" 'not json{{{' 0 silent

# 8) fail-open: stdin missing cwd/file_path fields -> exit 0, silent
run_case "stdin without cwd/file_path -> silent exit 0" '{}' 0 silent

# 9) fail-open: jq absent (empty PATH dir) -> exit 0, stdout silent.
#    The hook is exec'd directly: its absolute-path shebang (#!/bin/bash) is the
#    very thing that keeps it runnable under a stripped PATH.
EMPTYBIN="$WS/emptybin"; mkdir -p "$EMPTYBIN"
set +e
out=$(printf '%s' "$(stdin_for "$CWD/other/file.js")" | env PATH="$EMPTYBIN" "$HOOK" 2>/dev/null); jrc=$?
set +e
if [ "$jrc" = 0 ] && [ -z "$out" ]; then
  printf 'PASS: jq missing -> silent stdout, exit 0 (rc=%s)\n' "$jrc"; pass=$((pass+1))
else
  printf 'FAIL: jq missing (rc=%s stdout=<%s>)\n' "$jrc" "$out"; fail=$((fail+1))
fi

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
