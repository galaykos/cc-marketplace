#!/usr/bin/env bash
# Harness for hooks/shape-guard.sh: denies implementation writes while brainstorm's shape sentinel is live.
# The load-bearing cases are the round trip (a sentinel written by the real phase-sentinel.sh is honoured) and the
# neighbours that must stay silent: taskmaster:task's own shape sentinel, the design doc, and the preview scratch.
set -u
unset CLAUDE_PROJECT_DIR
here=$(cd "$(dirname "$0")" && pwd)
H="$here/../../hooks/shape-guard.sh"
S="$here/../phase-sentinel.sh"
[ -x "$H" ] || { printf 'FAIL: shape-guard.sh not executable\n'; exit 1; }

pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
R="$T/repo"; mkdir -p "$R/src" "$R/.cc-artifacts/taskmaster/specs" "$R/taskmaster-docs/specs" "$R/routes"; git -C "$R" init -q
R=$(cd "$R" && pwd)

ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

# payload <tool> <tool_input json> [session]
payload() {
  jq -cn --arg t "$1" --argjson i "$2" --arg s "${3:-sess-A}" --arg c "$R" \
    '{session_id:$s, transcript_path:("/home/u/.claude/projects/x/" + $s + ".jsonl"), cwd:$c,
      hook_event_name:"PreToolUse", tool_name:$t, tool_input:$i}'
}
run() { payload "$@" | bash "$H"; }
denies() { # name tool input [session]
  local name=$1; shift
  out=$(run "$@")
  if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then ok "$name"; else bad "$name (got: $out)"; fi
}
silent() {
  local name=$1; shift
  out=$(run "$@")
  if [ -z "$out" ]; then ok "$name"; else bad "$name (got: $out)"; fi
}
sentinel() { # owner session — this session's own file, as phase-sentinel.sh lays it out
  mkdir -p "$R/.cc-artifacts/cc-phase"
  printf '{"phase":"shape","owner":"%s","session_id":"%s"}\n' "$1" "$2" > "$R/.cc-artifacts/cc-phase/$2.json"
}
mkdir -p "$R/.claude"
W() { jq -cn --arg p "$1" '{file_path:$p, content:"x"}'; }

silent "no sentinel: write passes" Write "$(W "$R/src/app.ts")"

bash "$S" write shape --owner taskmaster:brainstorm --session sess-A --cwd "$R" 2>/dev/null
denies "round trip: real writer's sentinel denies src write" Write "$(W "$R/src/app.ts")"
silent "design doc under .cc-artifacts/taskmaster passes" Write "$(W "$R/.cc-artifacts/taskmaster/specs/2026-11-07-x-design.md")"
silent "an older project's design doc under taskmaster-docs passes" Write "$(W "$R/taskmaster-docs/specs/2026-11-07-x-design.md")"
denies "a .. path out of .cc-artifacts denies" Write "$(W "$R/.cc-artifacts/taskmaster/../../src/app.ts")"
silent "a ./ segment inside .cc-artifacts passes" Write "$(W "$R/.cc-artifacts/taskmaster/specs/./x.md")"
silent "another plugin's artifact under .cc-artifacts passes" Write "$(W "$R/.cc-artifacts/approaches/deliberated.json")"
silent "a path under .claude passes" Write "$(W "$R/.claude/settings.local.json")"
silent "outside the project root passes" Write "$(W "$T/elsewhere.txt")"
denies "relative path resolved against cwd denies" Write "$(W "src/rel.ts")"
silent "another session's sentinel is not ours" Write "$(W "$R/src/app.ts")" sess-B
silent "preview scratch file passes" Write "$(W "$R/src/__design-preview__/main.tsx")"
silent "edit carrying the preview marker passes" Edit "$(jq -cn --arg p "$R/routes/web.php" '{file_path:$p, old_string:"a", new_string:"require __DIR__.\"/__design-preview__.php\"; // __design-preview__"}')"
denies "edit without the marker denies" Edit "$(jq -cn --arg p "$R/routes/web.php" '{file_path:$p, old_string:"a", new_string:"Route::get(\"/x\")"}')"
silent "MultiEdit with the marker passes" MultiEdit "$(jq -cn --arg p "$R/routes/web.php" '{file_path:$p, edits:[{old_string:"a", new_string:"// __design-preview__"}]}')"
denies "MultiEdit without the marker denies" MultiEdit "$(jq -cn --arg p "$R/src/a.ts" '{file_path:$p, edits:[{old_string:"a", new_string:"b"}]}')"

sentinel taskmaster:task sess-A
silent "taskmaster:task's shape sentinel is not guarded" Write "$(W "$R/src/app.ts")"

# Two sessions in one repo: B's brainstorm guards B only, and B's clear never lifts A's guard.
bash "$S" clear --session sess-A --cwd "$R" 2>/dev/null
bash "$S" write shape --owner taskmaster:brainstorm --session sess-B --cwd "$R" 2>/dev/null
silent "two sessions: B's shape sentinel does not guard A" Write "$(W "$R/src/app.ts")" sess-A
denies "two sessions: B's shape sentinel guards B" Write "$(W "$R/src/app.ts")" sess-B
bash "$S" write shape --owner taskmaster:brainstorm --session sess-A --cwd "$R" 2>/dev/null
bash "$S" clear --session sess-B --cwd "$R" 2>/dev/null
denies "two sessions: B's clear leaves A's guard up" Write "$(W "$R/src/app.ts")" sess-A
silent "two sessions: B's clear lifts B's guard" Write "$(W "$R/src/app.ts")" sess-B

bash "$S" clear --session sess-A --cwd "$R" 2>/dev/null
printf '{"phase":"shape","owner":"taskmaster:brainstorm"}\n' > "$R/.claude/cc-phase.json"
silent "a legacy repo-wide sentinel naming no session guards no session" Write "$(W "$R/src/app.ts")" sess-B
rm -f "$R/.claude/cc-phase.json"

printf '{"phase":"build","owner":"taskmaster:brainstorm","session_id":"sess-A"}\n' > "$R/.cc-artifacts/cc-phase/sess-A.json"
silent "a later phase does not guard" Write "$(W "$R/src/app.ts")"

sentinel taskmaster:brainstorm sess-A
touch -d '3 hours ago' "$R/.cc-artifacts/cc-phase/sess-A.json"
silent "a sentinel past the 120-minute TTL is ignored" Write "$(W "$R/src/app.ts")"

sentinel taskmaster:brainstorm sess-A
out=$(printf 'not json' | bash "$H"); rc=$?
if [ -z "$out" ] && [ "$rc" = 0 ]; then ok "malformed payload fails open"; else bad "malformed payload (rc=$rc out=$out)"; fi

bash "$S" clear --session sess-A --cwd "$R" 2>/dev/null
silent "cleared sentinel: write passes" Write "$(W "$R/src/app.ts")"

# Plugins before 2026-11-14 wrote the sentinel under .claude/cc-phase/: honoured while the new path has none.
mkdir -p "$R/.claude/cc-phase"
printf '{"phase":"shape","owner":"taskmaster:brainstorm","session_id":"sess-O"}\n' > "$R/.claude/cc-phase/sess-O.json"
denies "a shape sentinel only under .claude/cc-phase guards its session" Write "$(W "$R/src/app.ts")" sess-O
printf '{"phase":"build","owner":"taskmaster:brainstorm","session_id":"sess-O"}\n' > "$R/.cc-artifacts/cc-phase/sess-O.json"
silent "the new path's sentinel wins over the old one" Write "$(W "$R/src/app.ts")" sess-O
bash "$S" clear --session sess-O --cwd "$R" 2>/dev/null
silent "clear lifts a guard held by the old path's sentinel" Write "$(W "$R/src/app.ts")" sess-O

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
