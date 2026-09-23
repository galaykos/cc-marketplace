#!/usr/bin/env bash
# Fixtures for ONE property shared by all three state-writing hooks in this plugin:
# a payload `cwd` that no longer exists must not be rebuilt.
#
# WHY A HARNESS AND NOT A COMMENT. The payload's cwd is where the session STARTED, and a
# session outlives the directory — `git worktree remove`, `rm -rf`, a branch switch that
# deletes a generated tree. Each hook then ran `mkdir -p "$cwd/.claude/comment-discipline"`,
# which recreates every missing parent: a deleted project came back three levels deep in a
# live repo, holding nothing but hook state. The trend audit named it (H6), the 2026-09-22
# panel found it still open (AR 1), so the fix ships with the probe that reproduces it.
#
# WHAT THIS DOES NOT CATCH: a cwd that exists but is the wrong checkout (a stale session
# left in a sibling clone). Nothing in the payload distinguishes those, so the state lands
# in the wrong repo and no check here can see it.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not found"; exit 0; }

GONE="$FX/work/acme/design-studio"

# A transcript long enough for verbosity.sh to get past its cheap path, and a file with a
# comment ratio high enough for density.sh and scan.sh to reach their state writes.
python3 - "$FX/transcript.jsonl" <<'PY'
import json, sys
with open(sys.argv[1], "w") as fh:
    for _ in range(80):
        fh.write(json.dumps({"type": "assistant", "message": {"role": "assistant",
                 "content": [{"type": "text", "text": "x" * 40}]}}) + "\n")
PY
mkdir -p "$FX/real"
cat > "$FX/real/a.ts" <<'TS'
// Set the counter to zero
let counter = 0
// Increment the counter
counter = counter + 1
// Return the counter
export function getCounter() { return counter }
// ============ SECTION: helpers ============
// Add a and b
export function add(a: number, b: number) { return a + b }
TS

probe() { # hook event file_path
  mkdir -p "$GONE"; rm -rf "$FX/work"
  python3 - "$2" "$GONE" "$FX/transcript.jsonl" "$3" <<'PY' | bash "$1" >/dev/null 2>&1
import json, sys
print(json.dumps({"hook_event_name": sys.argv[1], "tool_name": "Write", "cwd": sys.argv[2],
                  "session_id": "cwdguard", "transcript_path": sys.argv[3],
                  "tool_input": {"file_path": sys.argv[4], "content": open(sys.argv[4]).read()}}))
PY
  if [ -d "$FX/work" ]; then
    echo "FAIL: $(basename "$1") rebuilt a deleted cwd"; rc=1
  else
    echo "PASS: $(basename "$1") leaves a deleted cwd deleted"
  fi
}

probe plugins/code-review/hooks/verbosity.sh PostToolUse "$FX/real/a.ts"
probe plugins/code-review/hooks/density.sh   PostToolUse "$FX/real/a.ts"
probe plugins/code-review/hooks/scan.sh      PreToolUse  "$FX/real/a.ts"

# The guard must not cost the hooks their normal behaviour: with a cwd that DOES exist,
# scan.sh still reaches its deny lane and still records the bound it denies under.
mkdir -p "$FX/live"
out=$(python3 - "$FX/live" "$FX/real/a.ts" <<'PY' | bash plugins/code-review/hooks/scan.sh 2>/dev/null
import json, sys
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Write", "cwd": sys.argv[1],
                  "session_id": "cwdguard-live", "transcript_path": "/t/live.jsonl",
                  "tool_input": {"file_path": sys.argv[1] + "/src/a.ts",
                                 "content": open(sys.argv[2]).read()}}))
PY
)
case "$out" in
  *'"permissionDecision":"deny"'*) echo "PASS: an existing cwd still reaches the deny lane" ;;
  *) echo "FAIL: an existing cwd no longer reaches the deny lane: ${out:-<silent>}"; rc=1 ;;
esac
[ -d "$FX/live/.claude/comment-discipline" ] \
  && echo "PASS: the bound is still recorded under an existing cwd" \
  || { echo "FAIL: the bound was not recorded under an existing cwd"; rc=1; }

printf '\n'
[ "$rc" -eq 0 ] && echo "cwd-guard.test: all cases passed" || echo "cwd-guard.test: FAILURES above"
exit "$rc"
