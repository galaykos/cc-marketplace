#!/usr/bin/env bash
# Tests for rv-observe.sh (PostToolUse dispatch observer) and rv-consent.sh (PreToolUse
# consent ask) from a payload cwd INSIDE the project — the state-root cases. Their gate
# behaviour (counts, disclosure) is exercised with candor's gate in
# scripts/smoke/completion-gate-hook-tests.sh; this harness covers only where they look.
#
# Why: the payload cwd follows the model's `cd` (rationale/2026-09-25-session-plugin-usage-
# review.md, finding 2). Both hooks read the run sentinel at `$cwd/.claude/...`, so after a
# `cd app/Models` the observer recorded no reviewer dispatch and the consent ask went silent.
set -u
unset CLAUDE_PROJECT_DIR   # the hooks' state-root resolver reads it; fixtures must not inherit it

here=$(cd "$(dirname "$0")" && pwd)
OBS="$here/../../hooks/rv-observe.sh"
CONSENT="$here/../../hooks/rv-consent.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hooks fail open without it)"; exit 0; }

rc=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1 — $2"; rc=1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT

REPO="$WS/repo"; SUB="$REPO/app/Models"; mkdir -p "$SUB" "$REPO/.claude/task-runner"
git init -q "$REPO" 2>/dev/null
SENT="$REPO/.claude/task-runner/active-run.json"
printf '{"slug":"t"}' > "$SENT"

# 1) the observer, fired from a subdirectory, records at the ROOT
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Agent", tool_input:{prompt:"RV-CARD: 05\nreview the diff"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ -f "$REPO/.claude/task-runner/rv/rv-seen-05.json" ] \
  && ok "rv-observe from a subdirectory records at the repo root" \
  || bad "rv-observe from a subdirectory records at the repo root" "no rv-seen-05.json under $REPO/.claude"
[ ! -e "$SUB/.claude" ] && [ ! -e "$REPO/app/.claude" ] \
  && ok "rv-observe creates no .claude/ in the subdirectory" \
  || bad "rv-observe creates no .claude/ in the subdirectory" "found one under $REPO/app"

# 2) the consent ask, fired from a subdirectory, sees the root's registered run
out=$(jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash review-skip.sh --card 03 --reason \"ctx pressure\""}}' \
  | bash "$CONSENT" 2>/dev/null)
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1 \
  && ok "rv-consent from a subdirectory asks inside the root's run" \
  || bad "rv-consent from a subdirectory asks inside the root's run" "out=<$out>"

# 3) no registered run → both silent, nothing written
rm -f "$SENT"
jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Agent", tool_input:{prompt:"RV-CARD: 06"}}' \
  | bash "$OBS" >/dev/null 2>&1
[ ! -e "$REPO/.claude/task-runner/rv/rv-seen-06.json" ] \
  && ok "rv-observe records nothing outside a registered run" \
  || bad "rv-observe records nothing outside a registered run" "rv-seen-06.json written"
out=$(jq -cn --arg cwd "$SUB" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:"bash review-skip.sh --card 03 --reason \"x\""}}' \
  | bash "$CONSENT" 2>/dev/null)
[ -z "$out" ] && ok "rv-consent silent outside a registered run" || bad "rv-consent silent outside a registered run" "out=<$out>"

# 4) fail-open on a cwd that no longer exists
for h in "$OBS" "$CONSENT"; do
  printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"x"}}' "$WS/gone" | bash "$h" >/dev/null 2>&1
  [ $? = 0 ] && ok "$(basename "$h") exits 0 on a deleted cwd" || bad "$(basename "$h") exits 0 on a deleted cwd" "non-zero"
done
[ ! -e "$WS/gone" ] && ok "a deleted cwd is not recreated" || bad "a deleted cwd is not recreated" "$WS/gone exists"

exit $rc
