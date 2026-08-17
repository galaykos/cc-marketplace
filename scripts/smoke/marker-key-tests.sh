#!/usr/bin/env bash
# Smoke tests for pc_marker_key in scripts/lib/plugin-checks.sh — the check that a
# context key reaching a filesystem path is hashed first — plus the validate.sh wiring.
#
# THE GATE IS DEMONSTRATED FAILING ON PURPOSE, for the reason lanes-tests.sh states: a
# gate nobody has watched fail is indistinguishable from one that returns 0
# unconditionally. This one has a stronger reason still — it exists because three shipped
# hooks had the defect while four local scripts and 18 harnesses were green, so "the
# suite passes" was exactly the signal that failed.
#
# WHY THIS IS NOT pc_context_key's JOB: that check gates the READ (does the hook mention
# transcript_path). It is a string-presence test, so a hook that hashes the value and one
# that pastes it into a filename pass it identically. The rule here — hash before it
# becomes a path — is carried by nothing else.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
. "$ROOT/scripts/lib/plugin-checks.sh" || exit 2

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; rc=1; }

plug() { # $1 name, $2 script body — a minimal plugin tree pc_marker_key will walk
  mkdir -p "$TMP/$1/hooks"
  printf '{"hooks":{"PostToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/h.sh"}]}]}}\n' \
    > "$TMP/$1/hooks/hooks.json"
  printf '%s\n' "$2" > "$TMP/$1/hooks/h.sh"
}

# The shipped defect, verbatim in shape: an absolute path interpolated into a marker name.
plug offender 'sid=$(printf "%s" "$input" | jq -r ".transcript_path // .session_id // empty")
marker="$cwd/.claude/x/blocked-$sid-$key"
: > "$marker"'

# The two shipped hooks that got it right (conventions.sh:59, budget.sh:64).
plug hashed 'sid=$(printf "%s" "$input" | jq -r ".transcript_path // .session_id // empty")
key=$(printf "%s" "$sid" | cksum | cut -d" " -f1)
seen="${TMPDIR:-/tmp}/cc-x-$key"
mkdir "$seen" || exit 0'

# Raw in a path, but the nested parents ARE created — security/hooks/write-scan.sh's shape.
plug dirnamed 'sid=$(printf "%s" "$input" | jq -r ".transcript_path // .session_id // empty")
lock="${TMPDIR:-/tmp}/cc-y/${sid}/f"
mkdir -p "$(dirname "$lock")"
: > "$lock"'

# A deliberate exception, declared.
plug blessed '# marker-key-ok: per-transcript tree is intentional and created elsewhere
sid=$(printf "%s" "$input" | jq -r ".transcript_path // .session_id // empty")
state="$cwd/.claude/z/s-$sid"'

# Slash-stripping expansion instead of a hash.
plug stripped 'sid=$(printf "%s" "$input" | jq -r ".transcript_path // .session_id // empty")
flat="${sid//\//_}"
state="$cwd/.claude/z/s-$flat"'

out="$(pc_marker_key "$TMP")"; gate_rc=$?

case "$out" in *offender:h.sh*) pass "flags a raw context key interpolated into a marker path" ;;
  *) fail "flags a raw context key interpolated into a marker path" "got: ${out:-<none>}" ;; esac
[ "$gate_rc" -eq 1 ] && pass "returns 1 when an offender exists" \
  || fail "returns 1 when an offender exists" "got exit $gate_rc"
# Patterns are qualified with `:h.sh` because the finding string itself contains the word
# "unhashed" — a bare *hashed* glob matches the offender line and reports a false failure.
case "$out" in *"hashed:h.sh"*) fail "no false positive on the cksum pattern" "flagged: $out" ;;
  *) pass "no false positive on the cksum pattern" ;; esac
case "$out" in *"dirnamed:h.sh"*) fail "no false positive when mkdir -p \$(dirname) creates the parents" "flagged: $out" ;;
  *) pass "no false positive when mkdir -p \$(dirname) creates the parents" ;; esac
case "$out" in *"blessed:h.sh"*) fail "# marker-key-ok: exempts the script" "flagged: $out" ;;
  *) pass "# marker-key-ok: exempts the script" ;; esac
case "$out" in *"stripped:h.sh"*) fail "no false positive on \${var//\\/} slash-stripping" "flagged: $out" ;;
  *) pass "no false positive on \${var//\\/} slash-stripping" ;; esac

# A tree with no offenders must return 0 and print nothing, or the gate cannot be wired.
rm -rf "$TMP/offender"
clean_out="$(pc_marker_key "$TMP")"; clean_rc=$?
if [ -z "$clean_out" ] && [ "$clean_rc" -eq 0 ]; then pass "silent and exit 0 on a clean tree"
else fail "silent and exit 0 on a clean tree" "exit $clean_rc, out: $clean_out"; fi

# The shipped tree must be clean — this is the regression guard for the three real fixes.
ship_out="$(pc_marker_key plugins)"
if [ -z "$ship_out" ]; then pass "the shipped plugins/ tree has no unhashed marker key"
else fail "the shipped plugins/ tree has no unhashed marker key" "$ship_out"; fi

# Wiring: an unreported gate is not a gate.
if grep -q 'pc_marker_key' "$ROOT/scripts/validate.sh"; then
  pass "validate.sh calls pc_marker_key"
else
  fail "validate.sh calls pc_marker_key" "no call found — the check would never run"
fi

# ---- pc_harness_payload: the CONDITION, not another instance -----------------------------
# pc_marker_key fails a hook that misuses the key. This one fails the TEST that would have
# noticed — a harness sending only session_id grades the fallback branch, which is the sole
# reason three broken hooks shipped behind a green suite.
HP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$HP"' EXIT
mkdir -p "$HP/scripts/smoke" "$HP/plugins/keyed/hooks" "$HP/plugins/keyless/hooks"
printf 'sid=$(jq -r ".transcript_path // .session_id")\nk=$(printf "%%s" "$sid" | cksum)\n' \
  > "$HP/plugins/keyed/hooks/h.sh"
printf 'sid=$(jq -r ".session_id")\n' > "$HP/plugins/keyless/hooks/h.sh"

# Offender: exercises a context-keyed hook, sends session_id only.
printf '#!/usr/bin/env bash\nHOOK=plugins/keyed/hooks/h.sh\njq -n %s{session_id:"s1",hook_event_name:"PostToolUse"}%s | bash "$HOOK"\n' "'" "'" \
  > "$HP/scripts/smoke/bad-tests.sh"
# Compliant: same hook, sends a path-shaped transcript_path too.
printf '#!/usr/bin/env bash\nHOOK=plugins/keyed/hooks/h.sh\njq -n %s{session_id:"s1",transcript_path:"/U/x/a.jsonl"}%s | bash "$HOOK"\n' "'" "'" \
  > "$HP/scripts/smoke/good-tests.sh"
# Out of scope: the hook it exercises never reads the key, so the field would be ceremony.
printf '#!/usr/bin/env bash\nHOOK=plugins/keyless/hooks/h.sh\njq -n %s{session_id:"s1"}%s | bash "$HOOK"\n' "'" "'" \
  > "$HP/scripts/smoke/keyless-tests.sh"
# Blessed: deliberately pins the no-transcript_path fallback.
printf '#!/usr/bin/env bash\n# harness-payload-ok: this file exists to pin the fallback branch\nHOOK=plugins/keyed/hooks/h.sh\njq -n %s{session_id:"s1"}%s | bash "$HOOK"\n' "'" "'" \
  > "$HP/scripts/smoke/blessed-tests.sh"

hp_out="$(pc_harness_payload "$HP")"; hp_rc=$?
case "$hp_out" in *bad-tests.sh*) pass "flags a harness that grades only the fallback branch" ;;
  *) fail "flags a harness that grades only the fallback branch" "got: ${hp_out:-<none>}" ;; esac
[ "$hp_rc" -eq 1 ] && pass "pc_harness_payload returns 1 on an offender" \
  || fail "pc_harness_payload returns 1 on an offender" "got exit $hp_rc"
case "$hp_out" in *good-tests.sh*) fail "no false positive on a compliant harness" "flagged: $hp_out" ;;
  *) pass "no false positive on a compliant harness" ;; esac
case "$hp_out" in *keyless-tests.sh*) fail "hook without a context key is out of scope" "flagged: $hp_out" ;;
  *) pass "hook without a context key is out of scope" ;; esac
case "$hp_out" in *blessed-tests.sh*) fail "# harness-payload-ok: exempts the harness" "flagged: $hp_out" ;;
  *) pass "# harness-payload-ok: exempts the harness" ;; esac

ship_hp="$(pc_harness_payload "$ROOT")"
if [ -z "$ship_hp" ]; then pass "the shipped harnesses all exercise the real payload"
else fail "the shipped harnesses all exercise the real payload" "$ship_hp"; fi

if grep -q 'pc_harness_payload' "$ROOT/scripts/validate.sh"; then
  pass "validate.sh calls pc_harness_payload"
else
  fail "validate.sh calls pc_harness_payload" "no call found — the check would never run"
fi

printf '\n'
[ "$rc" -eq 0 ] && printf 'marker-key-tests: all cases passed\n' \
               || printf 'marker-key-tests: FAILURES above\n'
exit "$rc"
