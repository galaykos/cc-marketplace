#!/usr/bin/env bash
# Tests for announce.sh (SessionStart cold-session run announcement).
#
# Each case is a branch a one-character edit could remove while the happy path stays
# green: the silence that keeps the always-on context budget at zero for a project with
# no run, the matcher guard that leaves compaction to skill-router, the card-count
# parse, the off switch, and fail-open on a malformed payload. Fixtures live under a
# mktemp -d workspace; the hook is driven with canned SessionStart stdin JSON and
# judged on rc + the additionalContext string.
set -u
unset CLAUDE_PROJECT_DIR   # the hook's state-root resolver reads it; fixtures must not inherit it

here=$(cd "$(dirname "$0")" && pwd)
HOOK="$here/../../hooks/announce.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

rc=0
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT

fire() { # <cwd> [source] -> additionalContext (empty when silent)
  printf '{"hook_event_name":"SessionStart","source":"%s","cwd":"%s"}' "${2:-startup}" "$1" \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: ${2:-<none>} want: ${3:-<none>}"; rc=1; fi; }
has() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "PASS: $1"; else echo "FAIL: $1 — missing '$3' in: ${2:-<none>}"; rc=1; fi; }

BARE="$WS/bare"; mkdir -p "$BARE"
check "1 no active-run.json: silent (the always-on budget stays 0)" "$(fire "$BARE")" ""

RUN="$WS/run"; mkdir -p "$RUN/.claude/task-runner" "$RUN/tasks/demo"
printf '{"slug":"2026-09-22-demo","branch":"feat/orders","index_path":"tasks/demo/00-INDEX.md"}\n' \
  > "$RUN/.claude/task-runner/active-run.json"
printf '{"phase":"build","owner":"task-runner:run"}\n' > "$RUN/.claude/cc-phase.json"
cat > "$RUN/tasks/demo/00-INDEX.md" <<'EOF'
| card | title | status |
|---|---|---|
| 01 | a | done |
| 02 | b | in progress |
| 03 | c | parked — blocked on an API key |
| 04 | d |  |
EOF
line=$(fire "$RUN")
check "2 a registered run announces exactly one line" "$(printf '%s' "$line" | grep -c .)" "1"
has "3 the line names the slug" "$line" '`2026-09-22-demo`'
has "4 the line names the branch" "$line" 'branch `feat/orders`'
has "5 done and parked cards are closed, the rest remain" "$line" '2 of 4 cards still open'
has "6 the declared arc phase is named" "$line" 'arc phase `build`'

check "7 source=compact is skill-router's lane, not this one" "$(fire "$RUN" compact)" ""
check "8 source=resume announces" "$(printf '%s' "$(fire "$RUN" resume)" | grep -c .)" "1"

rm -f "$RUN/.claude/cc-phase.json"
printf '{"slug":"plain"}\n' > "$RUN/.claude/task-runner/active-run.json"
line=$(fire "$RUN")
check "9 a run with no index still announces" "$(printf '%s' "$line" | grep -c .)" "1"
if printf '%s' "$line" | grep -q 'cards still open'; then echo "FAIL: 10 no index means no invented card count"; rc=1; else echo "PASS: 10 no index means no invented card count"; fi

check "11 CC_REMIND=off is silent" \
  "$(printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$RUN" | CC_REMIND=off bash "$HOOK" 2>/dev/null)" ""

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "12 malformed payload fails open" "$out" "rc=0"

# 13-15) STATE ROOT (0.41.0). The payload cwd follows the model's `cd`; the run is
#        registered at the project root. Before, a session opened in a subdirectory
#        looked for app/Models/.claude/task-runner/active-run.json and said nothing.
git init -q "$RUN" 2>/dev/null
mkdir -p "$RUN/app/Models"
printf '{"slug":"2026-09-22-demo","branch":"feat/orders","index_path":"tasks/demo/00-INDEX.md"}\n' \
  > "$RUN/.claude/task-runner/active-run.json"
line=$(fire "$RUN/app/Models")
has "13 subdirectory cwd: the root's run is announced" "$line" '`2026-09-22-demo`'
has "14 subdirectory cwd: the root-relative index still resolves" "$line" '2 of 4 cards still open'
check "15 subdirectory cwd: no .claude/ created there" "$([ -e "$RUN/app/Models/.claude" ] && echo yes)" ""

exit $rc
