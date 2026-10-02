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
#   3. THE CEILING IS ABSOLUTE AND THE SIBLING TEST SURVIVES IT. A file with no
#      tracked siblings is judged against the ceiling; a file under the ceiling but
#      2x its lean siblings still fires; `COMMENT_DISCIPLINE_CEILING_TENTHS=0`
#      restores the sibling-only behaviour; and the PreToolUse lane denies a whole
#      Write over the ceiling exactly once per file.
#
# Scratch git repos throughout; never the live repo, never real .claude state.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/code-review/hooks/density.sh"
SCAN="$ROOT/plugins/code-review/hooks/scan.sh"
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

lean() { # $1 path — ~0.1:1, a repo that comments almost nothing
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 30); do
      [ $((i % 10)) -eq 0 ] && echo "    // why $i: the upstream API returns a bare id here, not an object"
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}
mid() { # $1 path — 0.4:1 in tenths, at the ceiling but not over it; 4x a lean house
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 40); do
      [ $((i % 2)) -eq 0 ] && echo "    // why $i: the upstream API returns a bare id here, not an object"
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}

fire() { # $1 cwd, $2 file, $3 session
  jq -n --arg fp "$2" --arg cwd "$1" --arg s "$3" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",session_id:$s,cwd:$cwd,tool_input:{file_path:$fp}}' \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
pre() { # $1 cwd, $2 file, $3 session, $4 content-file -> raw stdout
  jq -n --arg fp "$2" --arg cwd "$1" --arg s "$3" --rawfile c "$4" \
    '{hook_event_name:"PreToolUse",tool_name:"Write",session_id:$s,cwd:$cwd,tool_input:{file_path:$fp,content:$c}}' \
    | bash "$HOOK" 2>/dev/null
}

# ---- 1. dense file against COMMITTED house style ------------------------------
R="$TMP/r1"; mkdir -p "$R/app/Svc"
for n in A B C D; do house "$R/app/Svc/$n.php"; done
git -C "$R" init -q; git -C "$R" add -A
git -C "$R" -c user.email=t@t -c user.name=t commit -qm base
mkdir -p "$R/app/Svc/New/Deep"; dense "$R/app/Svc/New/Deep/Fat.php"
expect "dense file vs committed house style fires" "$(fire "$R" "$R/app/Svc/New/Deep/Fat.php" s1)" "comment-to-code"
expect "  …and the walk-up found the tracked baseline" "$(fire "$R" "$R/app/Svc/New/Deep/Fat.php" s1b)" "its siblings run"

# ---- 2. a house-style file: over the ceiling, matching its siblings ------------
# The 1:1 house style is what the observed run's repo looked like; the marketplace's
# default says that is too much, so the ceiling names itself, and switching the
# ceiling off restores the sibling-only verdict (silent).
house "$R/app/Svc/New/Deep/Normal.php"
expect "house-style file is over the ceiling (limit named)" \
  "$(fire "$R" "$R/app/Svc/New/Deep/Normal.php" s2)" "the limit here is 0.4:1"
expect "house-style file is silent with the ceiling off" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 fire "$R" "$R/app/Svc/New/Deep/Normal.php" s2b)" ""
expect "house-style file is silent under a 1:1 project override" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=10 fire "$R" "$R/app/Svc/New/Deep/Normal.php" s2c)" ""

# ---- 2b. the sibling test survives the ceiling: under 0.4, 3x a lean house -----
RL="$TMP/rl"; mkdir -p "$RL/app/Svc"
for n in A B C D; do lean "$RL/app/Svc/$n.php"; done
git -C "$RL" init -q; git -C "$RL" add -A
git -C "$RL" -c user.email=t@t -c user.name=t commit -qm base
mid "$RL/app/Svc/Mid.php"
expect "at the ceiling but 4x lean siblings still fires (floor 0.3)" \
  "$(fire "$RL" "$RL/app/Svc/Mid.php" s2d)" "the limit here is 0.3:1"
lean "$RL/app/Svc/Lean.php"
expect "lean file in a lean repo is silent" "$(fire "$RL" "$RL/app/Svc/Lean.php" s2e)" ""

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

# ---- 7. too few tracked siblings -> the ceiling judges, never a guessed baseline -
R3="$TMP/r3"; mkdir -p "$R3/app"; git -C "$R3" init -q
dense "$R3/app/Only.php"
expect "no tracked baseline: the ceiling applies" "$(fire "$R3" "$R3/app/Only.php" s7)" "no committed siblings"
expect "no tracked baseline, ceiling off: silent" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 fire "$R3" "$R3/app/Only.php" s7b)" ""
lean "$R3/app/Lean.php"
expect "no tracked baseline, lean file: silent" "$(fire "$R3" "$R3/app/Lean.php" s7c)" ""

# ---- 7b. PreToolUse lane: a whole Write over the ceiling is denied ONCE per file -
R4="$TMP/r4"; mkdir -p "$R4/app"; git -C "$R4" init -q
dense "$TMP/dense.txt"; house "$TMP/house.txt"; lean "$TMP/lean.txt"
denied() { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; }
out=$(pre "$R4" "$R4/app/Fat.php" p1 "$TMP/dense.txt")
denied "$out" && echo "PASS: PreToolUse denies a dense Write" || { echo "FAIL: PreToolUse denies a dense Write — got: ${out:-<silent>}"; rc=1; }
expect "  …and the reason names the ceiling" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')" "the ceiling is 0.4:1"
# The bound is TWO denies, not one (2026-09-15): a sibling PreToolUse hook denying the
# same call blocks the write too, so a one-shot spent on attempt 1 left the next write
# of that file unchecked. Attempt 2 denies; attempt 3 is silent, which bounds the session.
out=$(pre "$R4" "$R4/app/Fat.php" p1 "$TMP/dense.txt")
denied "$out" && echo "PASS: bound is TWO denies: the same file again still denies" || { echo "FAIL: second dense Write should deny — got: ${out:-<silent>}"; rc=1; }
expect "bound is TWO denies: the same file a third time is allowed" "$(pre "$R4" "$R4/app/Fat.php" p1 "$TMP/dense.txt")" ""
out=$(pre "$R4" "$R4/app/Other.php" p1 "$TMP/house.txt")
denied "$out" && echo "PASS: the bound is per FILE: a 1:1 Write to a new file still denies" || { echo "FAIL: per-file bound — got: ${out:-<silent>}"; rc=1; }
expect "lean Write is allowed" "$(pre "$R4" "$R4/app/Lean.php" p1 "$TMP/lean.txt")" ""
expect "ceiling off: dense Write is allowed" "$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 pre "$R4" "$R4/app/Fat2.php" p2 "$TMP/dense.txt")" ""
out=$(jq -n --arg fp "$R4/app/Fat3.php" --arg cwd "$R4" --rawfile c "$TMP/dense.txt" \
  '{hook_event_name:"PreToolUse",tool_name:"Edit",session_id:"p3",cwd:$cwd,tool_input:{file_path:$fp,new_string:$c}}' | bash "$HOOK" 2>/dev/null)
expect "PreToolUse ignores an Edit (a fragment has no file ratio)" "$out" ""
printf '// @generated by tool — do not edit\n%s' "$(cat "$TMP/dense.txt")" > "$TMP/gen.txt"
expect "generated header exempts the Write" "$(pre "$R4" "$R4/app/Gen.php" p4 "$TMP/gen.txt")" ""
head -20 "$TMP/dense.txt" > "$TMP/short.txt"
expect "short file is below the floor, allowed" "$(pre "$R4" "$R4/app/Short.php" p5 "$TMP/short.txt")" ""
out=$(jq -n --arg fp "$R4/app/Fat4.php" --rawfile c "$TMP/dense.txt" \
  '{hook_event_name:"PreToolUse",tool_name:"Write",session_id:"p6",tool_input:{file_path:$fp,content:$c}}' | bash "$HOOK" 2>/dev/null)
expect "missing cwd withholds the deny (bound cannot be recorded)" "$out" ""

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

# ---- 10. PATH SCOPING AND THE GENERATED PROBE (paths.sh) ------------------------
# Non-git roots: the marketplace test is a file at the state root, here the payload cwd.
PI="$TMP/inst"; PM="$TMP/mkt"; mkdir -p "$PI" "$PM/.claude-plugin"; : > "$PM/.claude-plugin/marketplace.json"
DENY='"permissionDecision":"deny"'
expect "paths: installer src/templates/EmailTemplate.tsx is judged" \
  "$(pre "$PI" "$PI/src/templates/EmailTemplate.tsx" q1 "$TMP/dense.txt")" "$DENY"
expect "paths: installer wp-content/plugins/shop/hooks/cart.php is judged" \
  "$(pre "$PI" "$PI/wp-content/plugins/shop/hooks/cart.php" q2 "$TMP/dense.txt")" "$DENY"
expect "paths: marketplace templates/x.js is exempt" \
  "$(pre "$PM" "$PM/templates/x.js" q3 "$TMP/dense.txt")" ""
expect "paths: marketplace plugins/x/hooks/h.php is exempt" \
  "$(pre "$PM" "$PM/plugins/x/hooks/h.php" q4 "$TMP/dense.txt")" ""
expect "paths: migrations are judged in an installer root" \
  "$(pre "$PI" "$PI/database/migrations/2026_10_01_create_users.php" q5 "$TMP/dense.txt")" "$DENY"
expect "paths: migrations are judged in a marketplace root" \
  "$(pre "$PM" "$PM/database/migrations/2026_10_01_create_users.php" q6 "$TMP/dense.txt")" "$DENY"
expect "paths: build/app.js at the root is exempt" \
  "$(pre "$PI" "$PI/build/app.js" q7 "$TMP/dense.txt")" ""
expect "paths: packages/build/index.ts is judged" \
  "$(pre "$PI" "$PI/packages/build/index.ts" q8 "$TMP/dense.txt")" "$DENY"
expect "paths: build/ inside a worktree is exempt" \
  "$(pre "$PI" "$PI/.claude/worktrees/b/build/x.js" q9 "$TMP/dense.txt")" ""

out=$(HOOK="$NOLIB/density.sh" pre "$PI" "$PI/app/NoLib.php" q10 "$TMP/dense.txt"); e=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && echo "PASS: paths: a dense Write with paths.sh absent exits 0, silent" \
  || { echo "FAIL: paths: a dense Write with paths.sh absent (exit $e, out '$out')"; rc=1; }
expect "paths: missing cwd on PostToolUse stays silent" "$(fire "$TMP/gone" "$R3/app/Only.php" q11)" ""

gen() { # $1 session and file stem, $2 header -> pre() output for the header above a dense body
  { printf '%s\n' "$2"; cat "$TMP/dense.txt"; } > "$TMP/gen-$1.txt"
  pre "$PI" "$PI/app/$1.php" "$1" "$TMP/gen-$1.txt"
}
expect "paths: generated marker: a sentence that mentions a generator is judged" \
  "$(gen g1 '// This is not generated by a tool')" "$DENY"
expect "paths: generated marker: @generated exempts" "$(gen g2 '// @generated by tool — do not edit')" ""
expect "paths: generated marker: Code generated by … DO NOT EDIT exempts" \
  "$(gen g3 '// Code generated by protoc. DO NOT EDIT.')" ""
expect "paths: generated marker: <auto-generated> exempts" "$(gen g4 '// <auto-generated>')" ""
expect "paths: generated marker: a docblock line This file was auto-generated exempts" "$(gen g5 '/**
 * This file was auto-generated by openapi-typescript.
 */')" ""
expect "paths: generated marker: This file was automatically generated exempts" \
  "$(gen g6 '// This file was automatically generated by json-schema-to-typescript.')" ""
expect "paths: generated marker: GENERATED CODE - DO NOT MODIFY exempts" \
  "$(gen g7 '// GENERATED CODE - DO NOT MODIFY BY HAND')" ""

# cwd != root: the cases above post from the root itself, so a hook handing the classifier
# the payload cwd would pass them all.
PG="$TMP/gitroot"; mkdir -p "$PG/packages"; git -C "$PG" init -q
expect "probe: from cwd <root>/packages, packages/build/index.ts is judged against the git root" \
  "$(pre "$PG/packages" "$PG/packages/build/index.ts" qg1 "$TMP/dense.txt")" "$DENY"

# ---- 11. BASH LANE: heredocs before the write, targets on disk after it ----------
BW="$TMP/bw"; mkdir -p "$BW/src"
for i in $(seq 1 20); do
  printf '// why %s: one\n// why %s: two\n// why %s: three\nfunction f%s() { return %s; }\n' "$i" "$i" "$i" "$i" "$i"
done > "$TMP/d6020.txt"   # 60 comment lines, 20 code
SUFFIX=' Written by a Bash command:'
bash_hook() { # $1 event, $2 cwd, $3 session, $4 command -> raw stdout
  jq -n --arg e "$1" --arg cwd "$2" --arg s "$3" --arg c "$4" \
    '{hook_event_name:$e,tool_name:"Bash",session_id:$s,cwd:$cwd,tool_input:{command:$c}}' \
    | bash "$HOOK" 2>/dev/null
}
heredoc() { # $1 writer, $2 body file (default d6020.txt), $3 terminator (default EOF)
  printf "%s <<'%s'\n%s\n%s\n" "$1" "${3:-EOF}" "$(cat "${2:-$TMP/d6020.txt}")" "${3:-EOF}"
}
reason_of() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null; }
verdict() { # $1 status of the test before it, $2 label, $3 detail
  if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2 — $3"; rc=1; fi
}

w_reason=$(reason_of "$(pre "$BW" "$BW/src/Fat.js" bw1 "$TMP/d6020.txt")")
b_reason=$(reason_of "$(bash_hook PreToolUse "$BW" bb1 "$(heredoc 'cat > src/Fat.js')")")
case "$w_reason" in *"(60 comment lines, 20 code)"*) [ "$b_reason" = "$w_reason$SUFFIX Fat.js." ] ;; *) false ;; esac
verdict $? "bash: a truncating cat heredoc of 60 comment / 20 code lines is denied with the Write reason plus the file suffix" \
  "write=[$w_reason] bash=[$b_reason]"
D2="$TMP/bw2"; mkdir -p "$D2/src"
out=$(bash_hook PreToolUse "$D2" bb2 "$(heredoc 'cat >> src/Fat.js')")
[ -z "$out" ] && [ ! -e "$D2/.claude" ]
verdict $? "bash: the same text appended with >> is not denied pre-write and leaves no state dir" \
  "out=[$out] state=[$(ls -A "$D2/.claude" 2>/dev/null)]"
expect "bash: tee -a is an append, not denied pre-write" \
  "$(bash_hook PreToolUse "$BW" bb3 "$(heredoc 'tee -a src/Fat.js')")" ""
expect "bash: a heredoc fed to a writer that is not cat or tee is silent" \
  "$(bash_hook PreToolUse "$BW" bb4 "$(heredoc 'python3 - > src/Fat.js')")" ""
expect "bash: a command that writes nothing is silent on PreToolUse" \
  "$(bash_hook PreToolUse "$BW" bb5 'ls -la && git status')" ""

D6="$TMP/bw6"; mkdir -p "$D6/src"; cp "$TMP/d6020.txt" "$D6/src/Disk.js"
w_warn=$(fire "$D6" "$D6/src/Disk.js" bw6)
b_warn=$(bash_hook PostToolUse "$D6" bb6 "echo '// tail' >> src/Disk.js" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
[ -n "$w_warn" ] && [ "$b_warn" = "$w_warn$SUFFIX Disk.js." ]
verdict $? "bash: PostToolUse warns for a target on disk with the Write warning plus the file suffix" \
  "write=[$w_warn] bash=[$b_warn]"

D7="$TMP/bw7"; mkdir -p "$D7/src"; for k in 1 2 3 4; do mid "$D7/src/T$k.php"; done
bash_hook PostToolUse "$D7" bb7 \
  'echo 1 >> src/T1.php; echo 2 >> src/T2.php; echo 3 >> src/T3.php; echo 4 >> src/T4.php' >/dev/null
st=$(cat "$D7"/.claude/comment-discipline/density-* 2>/dev/null)
case "$st" in *"/src/T3.php"*) case "$st" in *"/src/T4.php"*) false ;; *) true ;; esac ;; *) false ;; esac
verdict $? "bash: PostToolUse measures three targets: the 4th target's name is absent from the state file" "state=[$st]"

D8="$TMP/bw8"; mkdir -p "$D8/src"
{ echo '// Code generated by protoc. DO NOT EDIT.'; cat "$TMP/d6020.txt"; } > "$D8/src/api.js"
expect "bash: a generated marker on disk silences the PostToolUse warning" \
  "$(bash_hook PostToolUse "$D8" bb8 'protoc --js_out=. api.proto > src/api.js')" ""
expect "bash: a command that writes nothing is silent on PostToolUse" \
  "$(bash_hook PostToolUse "$BW" bb9 'ls -la && git status')" ""

w1=$(pre "$BW" "$BW/src/S1.js" sb1 "$TMP/d6020.txt"); w2=$(pre "$BW" "$BW/src/S1.js" sb1 "$TMP/d6020.txt")
b3=$(bash_hook PreToolUse "$BW" sb1 "$(heredoc 'cat > src/S1.js')")
denied "$w1" && denied "$w2" && [ -z "$b3" ]
verdict $? "bash: two Write denies spend the budget of a relative heredoc to that file" \
  "write1=[$w1] write2=[$w2] bash=[$b3] (want deny, deny, silence)"
b1=$(bash_hook PreToolUse "$BW" sb2 "$(heredoc 'cat > src/S2.js')"); b2=$(bash_hook PreToolUse "$BW" sb2 "$(heredoc 'cat > src/S2.js')")
w3=$(pre "$BW" "$BW/src/S2.js" sb2 "$TMP/d6020.txt")
denied "$b1" && denied "$b2" && [ -z "$w3" ]
verdict $? "bash: two heredoc denies spend the budget of a Write to that file" \
  "bash1=[$b1] bash2=[$b2] write=[$w3] (want deny, deny, silence)"

# A payload piped to the script cannot prove the matcher, so this one reads the manifest.
jq -e '[.hooks[][] | select(any(.hooks[]; .command | test("/(scan|density)\\.sh")))
        | .matcher // "" | test("(^|\\|)Bash(\\||$)")] | length > 0 and all' \
  "$ROOT/plugins/code-review/hooks/hooks.json" >/dev/null 2>&1
verdict $? "wiring: every hooks.json entry that runs scan.sh or density.sh matches Bash" \
  "$(jq -c '[.hooks[][] | {matcher, run: [.hooks[].command]}]' "$ROOT/plugins/code-review/hooks/hooks.json" 2>&1)"

# ---- 12. BASH LANE: more than one chunk or target in a command --------------------
DM="$TMP/bwm"; mkdir -p "$DM/src"
one_json() { [ "$(printf '%s' "$1" | jq -s 'length' 2>/dev/null)" = 1 ]; }
names() { case "$(reason_of "$1")" in *"$SUFFIX $2.") ;; *) false ;; esac; } # $1 hook output, $2 file the suffix must name
for i in $(seq 1 30); do echo "function g$i() { return $i; }"; done > "$TMP/thin.txt"
{ for i in $(seq 1 40); do echo "// why $i: the upstream API returns a bare id here"; done
  for i in $(seq 1 15); do echo "function h$i() { return $i; }"; done; } > "$TMP/top.txt"   # 40 comment, 15 code
for i in $(seq 1 200); do echo "function t$i() { return $i; }"; done > "$TMP/tail.txt"

out=$(bash_hook PreToolUse "$DM" m1 "$(heredoc 'cat > src/thin.js' "$TMP/thin.txt"; heredoc 'cat > src/fat.js')")
one_json "$out" && denied "$out" && names "$out" fat.js
verdict $? "multi: a thin first heredoc and a dense second draw one deny naming the second file" "out=[$out]"

D9="$TMP/bw9"; mkdir -p "$D9/src"; cp "$TMP/d6020.txt" "$D9/src/c.js"; cp "$TMP/d6020.txt" "$D9/src/d.js"
out=$(bash_hook PostToolUse "$D9" m2 'echo x >> src/c.js; echo y >> src/d.js')
rows=$(cat "$D9"/.claude/comment-discipline/density-* 2>/dev/null | grep -c '^warn ')
one_json "$out" && [ "$rows" = 1 ]
verdict $? "multi: two over-limit targets on disk draw one JSON object and one warn row in the state file" \
  "warn rows=$rows out=[$out]"

# The dense file sits where the target would resolve if the cd were ignored.
DC="$TMP/bwc"; mkdir -p "$DC/src"; cp "$TMP/d6020.txt" "$DC/x.js"
out=$(bash_hook PostToolUse "$DC" m3 'cd src && echo y >> x.js')
[ -z "$out" ] && ! grep -q 'x\.js' "$DC"/.claude/comment-discipline/density-* 2>/dev/null
verdict $? "multi: a relative target after an in-command cd is not measured on the disk lane" "out=[$out]"

expect "multi: a truncating heredoc followed by an append to the same file is not denied pre-write" \
  "$(bash_hook PreToolUse "$DM" m4 "$(heredoc 'cat > src/a.js' "$TMP/top.txt" A; heredoc 'cat >> src/a.js' "$TMP/tail.txt" B)")" ""

out=$(bash_hook PreToolUse "$DM" m5 "$(heredoc 'tee src/T.js')")
one_json "$out" && denied "$out" && names "$out" T.js
verdict $? "multi: a truncating tee heredoc is denied" "out=[$out]"

out=$(HOOK="$NOLIB/density.sh" bash_hook PreToolUse "$D6" m6 "$(heredoc 'cat > src/Disk.js')"); e=$?
out2=$(HOOK="$NOLIB/density.sh" bash_hook PostToolUse "$D6" m6 "$(heredoc 'cat > src/Disk.js')"); e2=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && [ "$e2" -eq 0 ] && [ -z "$out2" ]
verdict $? "multi: with paths.sh absent a dense cat heredoc exits 0 with no output on both events" \
  "PreToolUse exit $e [$out] PostToolUse exit $e2 [$out2]"

# ---- 13. RED-TEAM: a wrong file and a false deny on the Bash lane -------------------
DR="$TMP/rt"; mkdir -p "$DR/src" "$DR/sub"; cp "$TMP/d6020.txt" "$DR/big.js"
expect "redteam: with a dense big.js in the payload cwd, a heredoc to big.js after \`if cd sub; then\` draws no warning" \
  "$(bash_hook PostToolUse "$DR" rt1 'if cd sub; then
cat > big.js <<EOF
const a = 1;
EOF
fi')" ""
expect "redteam: a dense truncating heredoc followed by cat src/body.js >> src/qb.js is not denied pre-write" \
  "$(bash_hook PreToolUse "$DR" rt2 "$(heredoc 'cat > src/qb.js')
cat src/body.js >> src/qb.js")" ""
expect "redteam: a dense heredoc under cat <<EOF | tee src/h.js -a is not denied" \
  "$(bash_hook PreToolUse "$DR" rt3 "$(printf "cat <<'EOF' | tee src/h.js -a\n%s\nEOF" "$(cat "$TMP/d6020.txt")")")" ""
expect "redteam: a dense heredoc under cat src/other.js > src/a.js is not denied" \
  "$(bash_hook PreToolUse "$DR" rt4 "$(heredoc 'cat src/other.js > src/a.js')")" ""
b1=$(bash_hook PreToolUse "$DR" rt5 "$(heredoc 'cat > src/f.js')"); b2=$(bash_hook PreToolUse "$DR" rt5 "$(heredoc 'cat > src/f.js')")
b3=$(bash_hook PreToolUse "$DR" rt5 "$(heredoc 'cat > src//f.js')")
denied "$b1" && denied "$b2" && [ -z "$b3" ]
verdict $? "redteam: after two denies on src/f.js a dense heredoc to src//f.js passes" \
  "bash1=[$b1] bash2=[$b2] bash3=[$b3] (want deny, deny, silence)"

# ---- 14. RE-TEST: counting a command's writes once ----------------------------------
many=$(for i in $(seq 1 120); do printf "cat > src/f%s.js <<'EOF'\nconst a%s = 1;\nEOF\n" "$i" "$i"; done)
t0=$SECONDS; out=$(bash_hook PreToolUse "$DR" rq1 "$many"); took=$((SECONDS - t0))
[ "$took" -le 5 ] && [ -z "$out" ]
verdict $? "retest: 120 one-line heredocs to distinct files return within 5 s" "took $took s, out=[$out]"
out=$(bash_hook PreToolUse "$DR" rq2 "$(heredoc 'cat > src/x.js')
echo x > src/other.js")
denied "$out" && names "$out" x.js
verdict $? "retest: a dense truncating heredoc is still denied when a different file is also written" "out=[$out]"

[ "$rc" -eq 0 ] && echo "comment-density-tests: all assertions passed"
exit "$rc"
