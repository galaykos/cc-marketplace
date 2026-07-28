#!/usr/bin/env bash
# Smoke tests for the code-architecture evidence-gate Stop hook.
#
# The hook reads the Stop payload's transcript_path (session JSONL) and blocks a
# turn that (1) claims completion in its assistant tail, (2) edited files, and
# (3) executed nothing after the last edit. These cases drive the hook with
# synthetic transcripts + canned Stop-hook stdin JSON and assert rc + stderr —
# both block mode (default) and the warn/off downgrades, plus every fail-open
# and escape path the header promises.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/code-architecture/hooks/evidence-gate.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
CWD="$WS/proj"; mkdir -p "$CWD"
MARKER="$CWD/.claude/evidence-gate-last"

# Transcript builders: one JSONL line per entry.
text_entry() { jq -cn --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
tool_entry() { # tool names as args
  jq -cn '$ARGS.positional | {type:"assistant",message:{content:[.[] | {type:"tool_use",name:.}]}}' --args "$@"
}

payload() { jq -cn --arg tp "$1" --arg cwd "$CWD" '{transcript_path:$tp,cwd:$cwd,stop_hook_active:false}'; }

# check <desc> <env> <transcript-file> <exp_rc> <exp_substr|__NONE__>
# Marker cleared per case; check_keep preserves it (tests the one-shot bound).
check() { rm -f "$MARKER"; check_keep "$@"; }
check_keep() {
  local desc="$1" envv="$2" tfile="$3" exp_rc="$4" exp_sub="$5" err rc ok=1
  err=$(payload "$tfile" | env $envv bash "$HOOK" 2>&1 >/dev/null); rc=$?
  [ "$rc" -eq "$exp_rc" ] || ok=0
  if [ "$exp_sub" != "__NONE__" ]; then
    printf '%s' "$err" | grep -qF "$exp_sub" || ok=0
  else
    [ -z "$err" ] || ok=0
  fi
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s want %s; stderr=%s)\n' "$desc" "$rc" "$exp_rc" "$err"; fi
}

BLOCK_SUB='no command ran after the last edit'

# 1. Naked claim: edit, no exec after, completion prose -> block.
T1="$WS/t1.jsonl"
{ tool_entry Read Edit; text_entry "All done — the fix is implemented."; } > "$T1"
check "naked claim blocks (exit 2)"                 "" "$T1" 2 "$BLOCK_SUB"

# 2. One-shot: same final text again with marker kept -> allow.
check_keep "same claim re-stop passes (one-shot marker)" "" "$T1" 0 "__NONE__"

# 3. Evidence: exec AFTER last edit -> allow.
T3="$WS/t3.jsonl"
{ tool_entry Edit; tool_entry Bash; text_entry "Done — tests pass."; } > "$T3"
check "post-edit execution passes"                  "" "$T3" 0 "__NONE__"

# 4. Ordering matters: exec BEFORE the last edit only -> still a naked claim.
T4="$WS/t4.jsonl"
{ tool_entry Bash; tool_entry Edit; text_entry "Fixed."; } > "$T4"
check "exec before last edit still blocks"          "" "$T4" 2 "$BLOCK_SUB"

# 5. No edits at all: pure Q&A turn claiming 'done' -> allow.
T5="$WS/t5.jsonl"
{ tool_entry Read; text_entry "Explanation complete — the migration is done by the framework."; } > "$T5"
check "no file mutation passes"                     "" "$T5" 0 "__NONE__"

# 6. Honesty escape: names what is unverified -> allow.
T6="$WS/t6.jsonl"
{ tool_entry Edit; text_entry "Implemented, but not tested yet — run npm test to verify."; } > "$T6"
check "honest 'not tested' prose passes"            "" "$T6" 0 "__NONE__"

# 7. Silence: no claim words at all -> allow (documented residual).
T7="$WS/t7.jsonl"
{ tool_entry Edit; text_entry "I updated the config file and the router."; } > "$T7"
check "claimless turn passes (silence residual)"    "" "$T7" 0 "__NONE__"

# 8. warn mode: prints, never blocks.
check "warn mode prints without blocking"           "CC_EVIDENCE_GATE=warn" "$T1" 0 "$BLOCK_SUB"

# 9. off mode: silent allow.
check "off mode is silent"                          "CC_EVIDENCE_GATE=off" "$T1" 0 "__NONE__"

# 10. stop_hook_active true -> allow (no re-entry).
rm -f "$MARKER"
err=$(jq -cn --arg tp "$T1" --arg cwd "$CWD" '{transcript_path:$tp,cwd:$cwd,stop_hook_active:true}' \
      | bash "$HOOK" 2>&1 >/dev/null); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$err" ]; then pass=$((pass+1)); printf 'PASS  stop_hook_active passes\n'
else fail=$((fail+1)); printf 'FAIL  stop_hook_active (rc=%s stderr=%s)\n' "$rc" "$err"; fi

# 11. Missing transcript -> fail open.
check "missing transcript fails open"               "" "$WS/nope.jsonl" 0 "__NONE__"

# 12. Subagent counts as execution (Agent after edit) -> allow.
T12="$WS/t12.jsonl"
{ tool_entry Edit; tool_entry Agent; text_entry "Done — the reviewer confirmed it."; } > "$T12"
check "Agent tool after edit passes"                "" "$T12" 0 "__NONE__"

# --- ACK phrase-scoping (13-19) -------------------------------------------
# A failure named as the thing that was FIXED is part of the claim, not an
# acknowledgement. Bare failure nouns used to escape the gate; 13-15 are the
# regression cases, 16-19 guard the honest reports that must still pass.

# 13. The fixed-a-failure claim: 'failing' as the OBJECT of the fix -> block.
T13="$WS/t13.jsonl"
{ tool_entry Edit; text_entry "Fixed the failing test — should work now."; } > "$T13"
check "'fixed the failing test' blocks"             "" "$T13" 2 "$BLOCK_SUB"

# 14. Past-tense failure noun in a completion claim -> block.
T14="$WS/t14.jsonl"
{ tool_entry Edit; text_entry "Fixed it. The old failure is gone."; } > "$T14"
check "'the old failure is gone' blocks"            "" "$T14" 2 "$BLOCK_SUB"

# 15. Failure named as resolved, plural -> block.
T15="$WS/t15.jsonl"
{ tool_entry Edit; text_entry "Implemented — that resolves the two failed assertions."; } > "$T15"
check "'resolves the failed assertions' blocks"     "" "$T15" 2 "$BLOCK_SUB"

# 16. Honest: the check itself is the subject and still red -> allow.
T16="$WS/t16.jsonl"
{ tool_entry Edit; text_entry "Implemented, but two tests still fail — output above."; } > "$T16"
check "'tests still fail' passes"                   "" "$T16" 0 "__NONE__"

# 17. Honest: build named as the failing subject -> allow.
T17="$WS/t17.jsonl"
{ tool_entry Edit; text_entry "Done with the refactor; the build failed on the type check."; } > "$T17"
check "'the build failed' passes"                   "" "$T17" 0 "__NONE__"

# 18. Honest: failure carries its cause -> allow.
T18="$WS/t18.jsonl"
{ tool_entry Edit; text_entry "Implemented. It fails with ENOENT when the cache dir is absent."; } > "$T18"
check "'fails with <cause>' passes"                 "" "$T18" 0 "__NONE__"

# 19. Honest: bare 'still failing' with no subject -> allow.
T19="$WS/t19.jsonl"
{ tool_entry Edit; text_entry "Fix applied. Still failing."; } > "$T19"
check "bare 'still failing' passes"                 "" "$T19" 0 "__NONE__"

# 20. No regression from the ACK tightening: a failure word plus real post-edit
# execution must still pass on the EVIDENCE path, not on the escape path. If the
# tightening ever over-reaches, this is the case that stays green while 13-15 flip.
T20="$WS/t20.jsonl"
{ tool_entry Edit; tool_entry Bash; text_entry "Fixed the failing test — suite is green, output above."; } > "$T20"
check "failure word + post-edit execution passes"   "" "$T20" 0 "__NONE__"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
