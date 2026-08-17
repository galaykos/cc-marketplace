#!/usr/bin/env bash
# Fixture tests for hooks/palette-default.sh. Picked up by the shared CI step globbing
# plugins/*/scripts/__tests__/*.test.sh.
#
# The FIRST fixture is the real regression this hook was written for: on 2026-08-17 a
# control/treatment run shipped 23 indigo utilities across 5 Blade views of a Laravel
# build, with every gate in this marketplace green, because craft-layer's equivalent gate
# runs only inside a craft run. If that fixture ever stops firing, the hook has lost the
# only failure it is known to catch.
#
# The silence cases carry equal weight. An advisory that fires on a deliberate palette is
# noise, and a reader who learns to skip it has lost the signal too.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/palette-default.sh"
[ -f "$HOOK" ] || { echo "FAIL: hook not found at $HOOK"; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; rc=1; }

# Each call gets a fresh cwd so the one-shot never masks an unrelated case. The payload
# carries a path-shaped transcript_path — the shape the host actually sends, which is what
# pc_harness_payload exists to require after three hooks shipped broken without it.
fire() { # $1 file  [$2 cwd]
  local cwd="${2:-$(mktemp -d "$TMP/cwd.XXXXXX")}"
  python3 -c 'import json,sys
print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Write","cwd":sys.argv[1],
 "session_id":"11111111-2222-3333-4444-555555555555",
 "transcript_path":"/Users/x/.claude/projects/-Users-x-p/abcdef01-2345.jsonl",
 "tool_input":{"file_path":sys.argv[2]}}))' "$cwd" "$1" \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
mk() { mkdir -p "$(dirname "$TMP/$1")"; cat > "$TMP/$1"; printf '%s' "$TMP/$1"; }

# ---- 1. THE OBSERVED REGRESSION -----------------------------------------------------
f=$(mk views/login.blade.php <<'PHP'
<div class="mx-auto max-w-md">
  <input class="border-indigo-500 focus:ring-indigo-200">
  <button class="bg-indigo-600 text-white">Sign in</button>
</div>
PHP
)
out=$(fire "$f")
case "$out" in *category-default*indigo*) pass "flags the Blade regression that shipped past every gate" ;;
  *) fail "flags the Blade regression that shipped past every gate" "got: ${out:-<silent>}" ;; esac

# ---- 2. the same default arriving as a literal swatch --------------------------------
f=$(mk src/Hero.tsx <<'TSX'
export const Hero = () => <h1 className="bg-[#6366f1] text-white">Ship faster</h1>
TSX
)
case "$(fire "$f")" in *category-default*) pass "flags the default swatch as a hex literal" ;;
  *) fail "flags the default swatch as a hex literal" "got silence" ;; esac

# ---- 3. SILENCE: a palette someone actually chose -------------------------------------
f=$(mk src/Chosen.tsx <<'TSX'
export const C = () => <div className="bg-amber-700 text-stone-50 border-stone-400" />
TSX
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on a deliberate non-default palette" \
  || fail "silent on a deliberate non-default palette" "flagged: $out"

# ---- 4. SILENCE: a neighbouring hue OUTSIDE the default band ---------------------------
# blue-500 (~259.8 oklch) and fuchsia-500 (~322.1) sit outside craft-layer's 275-315 band.
# Flagging them would make the family list taste rather than a derivation.
f=$(mk src/Blue.tsx <<'TSX'
export const B = () => <div className="bg-blue-500 text-fuchsia-400" />
TSX
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on hues outside the default band" \
  || fail "silent on hues outside the default band" "flagged: $out"

# ---- 5. SILENCE: not a UI file ---------------------------------------------------------
f=$(mk src/config.ts <<'TS'
export const theme = { accent: 'indigo-500' }
TS
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on a non-UI path" \
  || fail "silent on a non-UI path" "flagged: $out"

# ---- 6. the one-shot bound, on the real payload shape ----------------------------------
one="$(mktemp -d "$TMP/one.XXXXXX")"
a=$(fire "$TMP/views/login.blade.php" "$one")
b=$(fire "$TMP/src/Hero.tsx" "$one")
if [ -n "$a" ] && [ -z "$b" ]; then pass "one nudge per context, not per file"
else fail "one nudge per context, not per file" "first='${a:0:30}' second='${b:0:30}'"; fi
if [ -n "$(find "$one/.claude/ui-ux" -name 'palette-*' -type f 2>/dev/null)" ]
then pass "the state file lands on disk (key hashed, not a raw path)"
else fail "the state file lands on disk (key hashed, not a raw path)" "none under $one"; fi

# ---- 7. FAIL-OPEN and off switches ------------------------------------------------------
printf '' | bash "$HOOK" >/dev/null 2>&1 && pass "empty stdin exits 0" || fail "empty stdin exits 0" "non-zero"
printf 'not json' | bash "$HOOK" >/dev/null 2>&1 && pass "malformed stdin exits 0" || fail "malformed stdin exits 0" "non-zero"
off=$(CC_PALETTE=off bash -c 'cat | bash "$0"' "$HOOK" <<<'{"tool_name":"Write"}' 2>/dev/null)
[ -z "$off" ] && pass "CC_PALETTE=off silences it" || fail "CC_PALETTE=off silences it" "got: $off"

printf '\n'
[ "$rc" -eq 0 ] && printf 'palette-default.test: all cases passed\n' || printf 'palette-default.test: FAILURES above\n'
exit "$rc"
