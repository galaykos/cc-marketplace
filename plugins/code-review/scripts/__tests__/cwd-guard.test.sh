#!/usr/bin/env bash
# Fixtures for TWO properties shared by the three state-writing hooks in this plugin
# (verbosity.sh, density.sh, scan.sh), which share one state address.
#
# 1. A payload `cwd` that no longer exists must not be rebuilt. A session outlives its
#    directories — `git worktree remove`, `rm -rf`, a branch switch that deletes a generated
#    tree — and each hook ran `mkdir -p` on its state dir under that cwd, which recreates
#    every missing parent: a deleted project came back three levels deep in a live repo,
#    holding nothing but hook state. The trend audit named it (H6), the 2026-09-22 panel
#    found it still open (AR 1), so the fix ships with the probe that reproduces it.
#
# 2. A payload `cwd` in a SUBDIRECTORY must put state at the project root. The payload cwd
#    is the shell's cwd and follows the model's `cd` — not "where the session STARTED", as
#    these hooks' headers said until 0.23.0. Measured 2026-09-25
#    (rationale/2026-09-25-session-plugin-usage-review.md, finding 2): app/Enums, then
#    app/Models, then the repo root in one session; verbosity.sh's "once per session"
#    warning fired three times and each directory kept its own `.claude/`. The cases below
#    replay that walk and assert one warning, one deny budget, and no subdirectory state.
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
# This session exports CLAUDE_PROJECT_DIR (the marketplace repo), and verbosity.sh and
# density.sh append to a ledger under $HOME once they get far enough — keep both out.
unset CLAUDE_PROJECT_DIR CC_REMIND CC_COMMENT_GUARD
export HOME="$FX/home"; mkdir -p "$HOME"

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

# ---- property 2: a subdirectory cwd writes state at the repo root ---------------------
command -v git >/dev/null 2>&1 || { echo "SKIP: git not found — subdirectory cases"; exit "$rc"; }
R="$FX/repo"
mkdir -p "$R/app/Enums" "$R/app/Models" "$R/src"
git -C "$R" init -q
cp "$FX/real/a.ts" "$R/src/a.ts"

# Over verbosity.sh's threshold: 80 assistant records, each 700 chars of text and one tool
# call, so the cumulative ratio is 700 against a threshold of 600.
python3 - "$FX/verbose.jsonl" <<'PY'
import json, sys
with open(sys.argv[1], "w") as fh:
    for _ in range(80):
        fh.write(json.dumps({"type": "assistant", "message": {"role": "assistant", "content": [
            {"type": "text", "text": "y" * 700},
            {"type": "tool_use", "id": "t", "name": "Bash", "input": {}}]}}) + "\n")
PY
verbose() { # cwd -> additionalContext
  jq -nc --arg c "$1" --arg t "$FX/verbose.jsonl" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",cwd:$c,session_id:"walk",transcript_path:$t,tool_input:{command:"ls"}}' \
    | bash plugins/code-review/hooks/verbosity.sh 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
w1=$(verbose "$R/app/Enums"); w2=$(verbose "$R/app/Models"); w3=$(verbose "$R")
if [ -n "$w1" ] && [ -z "$w2" ] && [ -z "$w3" ]; then
  echo "PASS: verbosity.sh warns once across app/Enums → app/Models → root"
else
  echo "FAIL: verbosity.sh across three cwds — got [${w1:+warn}] [${w2:+warn}] [${w3:+warn}], want [warn] [] []"; rc=1
fi

# 60 code lines: past density.sh's size floors, so it records the file in its state.
for i in $(seq 1 60); do printf 'export const v%s = %s\n' "$i" "$i"; done > "$R/src/big.ts"
density() { # cwd
  jq -nc --arg c "$1" --arg f "$R/src/big.ts" --arg t "/t/density-walk.jsonl" \
    '{hook_event_name:"PostToolUse",tool_name:"Edit",cwd:$c,session_id:"walk",transcript_path:$t,tool_input:{file_path:$f}}' \
    | bash plugins/code-review/hooks/density.sh >/dev/null 2>&1
}
density "$R/app/Enums"
dstate="$R/.claude/comment-discipline/density-$(printf '%s' /t/density-walk.jsonl | cksum | cut -d' ' -f1)"
grep -qF "file $R/src/big.ts" "$dstate" 2>/dev/null && echo "PASS: density.sh keeps its state at the repo root" \
  || { echo "FAIL: density.sh wrote no state at the repo root"; rc=1; }

deny() { # cwd -> 1 when denied
  python3 - "$1" "$FX/real/a.ts" "$R/src/b.ts" <<'PY' | bash plugins/code-review/hooks/scan.sh 2>/dev/null | grep -c '"permissionDecision":"deny"'
import json, sys
print(json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Write", "cwd": sys.argv[1],
                  "session_id": "walk", "transcript_path": "/t/scan-walk.jsonl",
                  "tool_input": {"file_path": sys.argv[3], "content": open(sys.argv[2]).read()}}))
PY
}
d1=$(deny "$R/app/Enums"); d2=$(deny "$R/app/Enums"); d3=$(deny "$R/app/Models")
if [ "$d1" = 1 ] && [ "$d2" = 1 ] && [ "$d3" = 0 ]; then
  echo "PASS: scan.sh spends ONE deny budget across a cd (2 denies, then through)"
else
  echo "FAIL: scan.sh deny budget across a cd — got $d1 $d2 $d3, want 1 1 0"; rc=1
fi

strays=$(find "$R/app" "$R/src" -name .claude 2>/dev/null)
[ -z "$strays" ] && echo "PASS: no .claude/ in any subdirectory" \
  || { echo "FAIL: stray state dirs: $strays"; rc=1; }

printf '\n'
[ "$rc" -eq 0 ] && echo "cwd-guard.test: all cases passed" || echo "cwd-guard.test: FAILURES above"
exit "$rc"
