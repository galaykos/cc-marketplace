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

# 3b) PATH BOUNDARY: an allow entry must not admit a sibling that merely shares
#     its text prefix. Before the boundary fix a raw startswith allowed all three.
printf '{"allow":["src/util.ts","app/Models"],"task":"card 07"}' > "$SCOPE"
run_case "sibling extension not admitted (util.ts vs util.tsx)" \
  "$(stdin_for "$CWD/src/util.tsx")" 0 envelope "src/util.tsx"
run_case "prefix sibling dir not admitted (Models vs ModelsBackup)" \
  "$(stdin_for "$CWD/app/ModelsBackup/X.php")" 0 envelope "app/ModelsBackup/X.php"
run_case "exact file entry still allowed" \
  "$(stdin_for "$CWD/src/util.ts")" 0 silent
run_case "dir entry without trailing slash still allows its children" \
  "$(stdin_for "$CWD/app/Models/Order.php")" 0 silent

# restore the fixture the later cases expect
printf '{"allow":["src/allowed.js","lib/"],"task":"card 07"}' > "$SCOPE"

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

# 10) state hygiene (0.34.4): the run's state dir ignores itself once any hook sees it.
if [ "$(cat "$CWD/.claude/task-runner/.gitignore" 2>/dev/null)" = "*" ]; then
  printf 'PASS: .claude/task-runner/ ignores itself\n'; pass=$((pass+1))
else
  printf 'FAIL: .claude/task-runner/.gitignore missing or not "*"\n'; fail=$((fail+1))
fi

# 11) PER-CARD SCOPE FILES (SW 8 of the 2026-09-22 panel). routing.md writes one
#     scope-<cardId>.json per delegated/tracked card; until 0.38.0 this hook read only
#     the fixed scope.json, so the delegated path — the one the plugin sells — had no
#     mechanical tripwire at all. These cases fail against that logic: with NO
#     scope.json present, the old hook was silent on every path.
rm -f "$SCOPE"
printf '{"allow":["src/card-a.js"],"task":"card 01"}' > "$CWD/.claude/task-runner/scope-01.json"
printf '{"allow":["src/card-b.js"],"task":"card 02"}' > "$CWD/.claude/task-runner/scope-02.json"

run_case "per-card scope only: out-of-union edit -> envelope naming both cards" \
  "$(stdin_for "$CWD/src/stray.js")" 0 envelope "src/stray.js" "card 01, card 02"
run_case "per-card scope only: card 01's file -> silent" \
  "$(stdin_for "$CWD/src/card-a.js")" 0 silent
run_case "per-card scope only: card 02's file -> silent (union, not first-file-wins)" \
  "$(stdin_for "$CWD/src/card-b.js")" 0 silent
run_case "edit to a scope-<cardId>.json itself -> silent" \
  "$(stdin_for "$CWD/.claude/task-runner/scope-01.json")" 0 silent

# 12) inline scope.json joins the SAME union rather than replacing it.
printf '{"allow":["src/inline.js"],"task":"inline"}' > "$SCOPE"
run_case "inline + per-card: inline file -> silent" \
  "$(stdin_for "$CWD/src/inline.js")" 0 silent
run_case "inline + per-card: card file still silent" \
  "$(stdin_for "$CWD/src/card-a.js")" 0 silent
run_case "inline + per-card: stray still warns" \
  "$(stdin_for "$CWD/src/stray.js")" 0 envelope "src/stray.js"

# 13) one malformed member disarms the whole call (stated in the header): a partial
#     union would warn about a path the file it could not parse had allowed.
printf 'not json' > "$CWD/.claude/task-runner/scope-03.json"
run_case "one malformed scope file -> whole call not enforced, stdout silent" \
  "$(stdin_for "$CWD/src/stray.js")" 0 silent
set +e
err=$(printf '%s' "$(stdin_for "$CWD/src/stray.js")" | bash "$HOOK" 2>&1 >/dev/null); set +e
case "$err" in *"scope-03.json is malformed"*)
  printf 'PASS: malformed member named on stderr\n'; pass=$((pass+1)) ;;
  *) printf 'FAIL: malformed member not named on stderr: <%s>\n' "$err"; fail=$((fail+1)) ;;
esac
rm -f "$CWD/.claude/task-runner/scope-03.json" "$CWD/.claude/task-runner/scope-01.json" \
      "$CWD/.claude/task-runner/scope-02.json"

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
