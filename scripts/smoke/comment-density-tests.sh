#!/usr/bin/env bash
# Smoke tests for comment-discipline/hooks/density.sh (comment VOLUME) and the shared
# worktree path scoping in hooks/paths.sh that both file guards now use.
#
# The two properties worth defending, because getting either wrong makes the hook
# useless in the exact situation it was written for:
#
#   1. THE BASELINE IS PRE-EXISTING CODE. A fan-out writing many uniformly dense files
#      into a new subtree must not compute its baseline from its own output. Asserted
#      both ways: dense-file-vs-committed-house-style fires, and the same dense file
#      surrounded only by its own untracked siblings must ALSO fire.
#   2. WORKTREE PATHS ARE IN SCOPE. This marketplace places worktrees at
#      `.claude/worktrees/<branch>`, and the `*/.claude/*` exemption was silently
#      excluding every file a track run wrote.
#
# Scratch git repos throughout; never the live repo, never real .claude state.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/comment-discipline/hooks/density.sh"
SCAN="$ROOT/plugins/comment-discipline/hooks/scan.sh"
command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not available";  exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
export HOME="$TMP/home"   # keep the ledger out of the real ~/.claude

expect() { # $1 label, $2 out, $3 must-contain ('' = must be silent)
  local label="$1" out="$2" want="$3" ok=1
  if [ -n "$want" ]; then case "$out" in *"$want"*) ;; *) ok=0 ;; esac
  else [ -n "$out" ] && ok=0; fi
  if [ "$ok" -eq 1 ]; then echo "PASS: $label"; else echo "FAIL: $label — got: ${out:-<silent>}"; rc=1; fi
}

# ---- generators: N lines of body at a chosen comment:code ratio ----------------
house() { # $1 path — ~1:1, the house style
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 30); do
      echo "    // why $i: the upstream API returns a bare id here, not an object"
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}
dense() { # $1 path — ~5:1, the shape the observed run produced
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 30); do
      for j in 1 2 3 4 5; do echo "    // reasoning line $j for member $i, restating the design decision at length"; done
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}

fire() { # $1 cwd, $2 file, $3 session
  jq -n --arg fp "$2" --arg cwd "$1" --arg s "$3" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",session_id:$s,cwd:$cwd,tool_input:{file_path:$fp}}' \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}

# ---- 1. dense file against COMMITTED house style ------------------------------
R="$TMP/r1"; mkdir -p "$R/app/Svc"
for n in A B C D; do house "$R/app/Svc/$n.php"; done
git -C "$R" init -q; git -C "$R" add -A
git -C "$R" -c user.email=t@t -c user.name=t commit -qm base
mkdir -p "$R/app/Svc/New/Deep"; dense "$R/app/Svc/New/Deep/Fat.php"
expect "dense file vs committed house style fires" "$(fire "$R" "$R/app/Svc/New/Deep/Fat.php" s1)" "comment-to-code"
expect "  …and the walk-up found the tracked baseline" "$(fire "$R" "$R/app/Svc/New/Deep/Fat.php" s1b)" "its siblings run"

# ---- 2. a house-style file in the same repo stays silent -----------------------
house "$R/app/Svc/New/Deep/Normal.php"
expect "house-style file is silent" "$(fire "$R" "$R/app/Svc/New/Deep/Normal.php" s2)" ""

# ---- 3. THE REGRESSION THAT MATTERS: the run must not become its own baseline --
# Same dense file, but now every sibling in the new subtree is equally dense and
# untracked. Drawing the baseline from the working tree would find no outlier.
R2="$TMP/r2"; mkdir -p "$R2/app/Svc"
for n in A B C D; do house "$R2/app/Svc/$n.php"; done
git -C "$R2" init -q; git -C "$R2" add -A
git -C "$R2" -c user.email=t@t -c user.name=t commit -qm base
mkdir -p "$R2/app/Svc/New"; for n in F1 F2 F3 F4 F5; do dense "$R2/app/Svc/New/$n.php"; done
expect "uniformly dense NEW subtree still fires (baseline is tracked code)" \
  "$(fire "$R2" "$R2/app/Svc/New/F3.php" s3)" "comment-to-code"

# ---- 4. files this session already wrote are excluded from the baseline --------
S=s4
fire "$R2" "$R2/app/Svc/New/F1.php" "$S" >/dev/null
fire "$R2" "$R2/app/Svc/New/F2.php" "$S" >/dev/null
expect "a third dense file in the same session still fires" \
  "$(fire "$R2" "$R2/app/Svc/New/F4.php" "$S")" "comment-to-code"

# ---- 5. bounded: at most 3 warnings per session --------------------------------
expect "4th dense file in one session is silent (MAX_WARN)" \
  "$(fire "$R2" "$R2/app/Svc/New/F5.php" "$S")" ""

# ---- 6. same file twice in a session warns once --------------------------------
S6=s6
fire "$R2" "$R2/app/Svc/New/F1.php" "$S6" >/dev/null
expect "same file re-written in one session does not re-warn" \
  "$(fire "$R2" "$R2/app/Svc/New/F1.php" "$S6")" ""

# ---- 6b. THE SAME TWO BOUNDS, ON THE PAYLOAD THE HOST ACTUALLY SENDS ------------
# Cases 5 and 6 send session_id and nothing else, so they only ever exercised the
# FALLBACK branch of `.transcript_path // .session_id`. With transcript_path present —
# which is the normal case — the key is an absolute PATH, `density-$sid` named a nested
# file whose parents are never created, every state write failed, and MAX_WARN plus the
# per-file dedup both disengaged: the hook warned on every edit forever. Both bounds
# above stayed green throughout. Re-assert them with the real payload shape.
fire_tp() { # $1 cwd, $2 file — session_id AND a path-shaped transcript_path
  jq -n --arg fp "$2" --arg cwd "$1" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",
      session_id:"11111111-2222-3333-4444-555555555555",
      transcript_path:"/Users/x/.claude/projects/-Users-x-proj/abcdef01-2345-6789.jsonl",
      cwd:$cwd,tool_input:{file_path:$fp}}' \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
R2B="$TMP/r2b"; mkdir -p "$R2B/app/Svc"
for n in A B C D; do house "$R2B/app/Svc/$n.php"; done
git -C "$R2B" init -q; git -C "$R2B" add -A
git -C "$R2B" -c user.email=t@t -c user.name=t commit -qm base
mkdir -p "$R2B/app/Svc/New"; for n in G1 G2 G3 G4 G5; do dense "$R2B/app/Svc/New/$n.php"; done
expect "transcript_path: first dense file fires" \
  "$(fire_tp "$R2B" "$R2B/app/Svc/New/G1.php")" "comment-to-code"
expect "transcript_path: same file re-written does not re-warn (per-file dedup)" \
  "$(fire_tp "$R2B" "$R2B/app/Svc/New/G1.php")" ""
fire_tp "$R2B" "$R2B/app/Svc/New/G2.php" >/dev/null
fire_tp "$R2B" "$R2B/app/Svc/New/G3.php" >/dev/null
expect "transcript_path: 4th dense file is silent (MAX_WARN engages)" \
  "$(fire_tp "$R2B" "$R2B/app/Svc/New/G4.php")" ""
if [ -n "$(find "$R2B/.claude/comment-discipline" -name 'density-*' -type f 2>/dev/null)" ]
then echo "PASS: transcript_path: the state file actually landed on disk"
else echo "FAIL: transcript_path: the state file actually landed on disk — none under $R2B"; rc=1; fi

# ---- 7. too few tracked siblings -> silent, never a guess -----------------------
R3="$TMP/r3"; mkdir -p "$R3/app"; git -C "$R3" init -q
dense "$R3/app/Only.php"
expect "no tracked baseline at all is silent" "$(fire "$R3" "$R3/app/Only.php" s7)" ""

# ---- 8. WORKTREE SCOPING (paths.sh), both hooks ---------------------------------
WT="$R/.claude/worktrees/feature-x"; mkdir -p "$WT/app/Svc/New" "$WT/.claude"
cp -R "$R/app/Svc/A.php" "$R/app/Svc/B.php" "$R/app/Svc/C.php" "$R/app/Svc/D.php" "$WT/app/Svc/"
git -C "$WT" init -q; git -C "$WT" add -A
git -C "$WT" -c user.email=t@t -c user.name=t commit -qm base
dense "$WT/app/Svc/New/Fat.php"
expect "density: file inside .claude/worktrees IS measured" \
  "$(fire "$WT" "$WT/app/Svc/New/Fat.php" s8)" "comment-to-code"

NOISY='// increment the counter
$counter++;'
scan() { # $1 path
  jq -n --arg fp "$1" --arg c "$WT" --arg x "$NOISY" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",session_id:"s9",cwd:$c,tool_input:{file_path:$fp,content:$x}}' \
    | bash "$SCAN" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
expect "scan: file inside .claude/worktrees IS scanned" "$(scan "$WT/app/Svc/New/w.php")" "comment-discipline:"
expect "scan: .claude/ INSIDE a worktree is still exempt" "$(scan "$WT/.claude/w.php")" ""
expect "scan: .claude/ in the main tree is still exempt"  "$(scan "$R/.claude/w.php")"  ""
expect "scan: vendored path is still exempt" "$(scan "$WT/vendor/x/w.php")" ""

# ---- 9. fail-open: no paths.sh, and a missing file ------------------------------
NOLIB="$TMP/nolib"; mkdir -p "$NOLIB"
cp "$HOOK" "$SCAN" "$NOLIB/"
out=$(jq -n --arg fp "$R2/app/Svc/New/F1.php" --arg cwd "$R2" \
  '{hook_event_name:"PostToolUse",tool_name:"Write",session_id:"s10",cwd:$cwd,tool_input:{file_path:$fp}}' \
  | bash "$NOLIB/density.sh" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && echo "PASS: density exits 0 without paths.sh" || { echo "FAIL: density exit $e without paths.sh"; rc=1; }
out=$(printf '{"hook_event_name":"PostToolUse","tool_name":"Write","session_id":"s11","cwd":"%s","tool_input":{"file_path":"%s/nope.php"}}' "$R2" "$R2" \
  | bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && echo "PASS: missing file is silent, exit 0" || { echo "FAIL: missing file (exit $e, out '$out')"; rc=1; }
out=$(printf '' | bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && echo "PASS: empty stdin exits 0" || { echo "FAIL: empty stdin exit $e"; rc=1; }

[ "$rc" -eq 0 ] && echo "comment-density-tests: all assertions passed"
exit "$rc"
