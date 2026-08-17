#!/usr/bin/env bash
# Author-time harness for plugins/testing/hooks/test-shape.sh. Picked up by the shared CI
# step globbing plugins/*/scripts/__tests__/*.test.sh.
#
# THE HOOK IS DEMONSTRATED FIRING AND STAYING SILENT ON PURPOSE. An advisory that only
# ever fires is noise a reader learns to skip, so the silence cases carry as much weight
# as the findings: a suite that earns its place, a skipped block, a `describe` wrapper, and
# a non-test file must all produce nothing.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/testing/hooks/test-shape.sh"
[ -f "$HOOK" ] || { echo "FAIL: hook not found at $HOOK"; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; rc=1; }

# Each call gets its own cwd so the per-file/per-context bounds never mask a case.
fire() { # $1 file — absolute
  local cwd; cwd="$(mktemp -d "$TMP/cwd.XXXXXX")"
  python3 -c 'import json,sys
print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Write","cwd":sys.argv[1],
 "session_id":"11111111-2222-3333-4444-555555555555",
 "transcript_path":"/Users/x/.claude/projects/-Users-x-p/abcdef01-2345-6789.jsonl",
 "tool_input":{"file_path":sys.argv[2]}}))' "$cwd" "$1" \
    | bash "$HOOK" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
mk() { mkdir -p "$(dirname "$TMP/$1")"; cat > "$TMP/$1"; printf '%s' "$TMP/$1"; }

# ---- 1. assertion-free block -----------------------------------------------------------
f=$(mk tests/HollowTest.php <<'PHP'
<?php
class HollowTest extends TestCase {
    public function test_it_can_be_instantiated(): void { new Invoice(1); }
    public function test_real(): void { $this->assertSame(2, (new Calc())->add(1,1)); }
}
PHP
)
out=$(fire "$f")
case "$out" in *"L3"*"no assertion"*) pass "flags an assertion-free PHP block" ;;
  *) fail "flags an assertion-free PHP block" "got: ${out:-<silent>}" ;; esac
case "$out" in *"L4"*) fail "does not flag the block that asserts" "flagged L4: $out" ;;
  *) pass "does not flag the block that asserts" ;; esac

# ---- 2. near-duplicate group reports ONCE, not N times ---------------------------------
f=$(mk tests/DupTest.php <<'PHP'
<?php
class DupTest extends TestCase {
    public function test_adds_1(): void { $this->assertSame(2, (new Calc())->add(1,1)); }
    public function test_adds_2(): void { $this->assertSame(4, (new Calc())->add(2,2)); }
    public function test_adds_3(): void { $this->assertSame(6, (new Calc())->add(3,3)); }
    public function test_adds_4(): void { $this->assertSame(8, (new Calc())->add(4,4)); }
}
PHP
)
out=$(fire "$f")
case "$out" in *"4 near-identical blocks"*) pass "groups 4 literal-only variants into one finding" ;;
  *) fail "groups 4 literal-only variants into one finding" "got: ${out:-<silent>}" ;; esac
n=$(printf '%s\n' "$out" | grep -c 'near-identical' || true)
[ "$n" -eq 1 ] && pass "the duplicate group is reported exactly once" \
  || fail "the duplicate group is reported exactly once" "reported $n times"

# ---- 3. reflection into a non-public member ---------------------------------------------
f=$(mk tests/PrivTest.php <<'PHP'
<?php
class PrivTest extends TestCase {
    public function test_norm(): void {
        $m = new ReflectionMethod(Calc::class, "norm");
        $m->setAccessible(true);
        $this->assertSame(1, $m->invoke(new Calc(), 1));
    }
}
PHP
)
case "$(fire "$f")" in *"non-public member"*) pass "flags a reflection reach into a private member" ;;
  *) fail "flags a reflection reach into a private member" "got silence" ;; esac

# ---- 4. SILENCE: a suite that earns its place -------------------------------------------
f=$(mk src/good.test.ts <<'TS'
import { describe, it, expect } from 'vitest'
describe('money', () => {
  it('rejects a negative amount', () => { expect(() => charge(-1)).toThrow() })
  it('puts the remainder on the first bucket', () => { expect(split(10, 3)).toEqual([4, 3, 3]) })
})
TS
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on a suite that earns its place" \
  || fail "silent on a suite that earns its place" "flagged: $out"

# A `describe`/`context` wrapper has no assertion BY CONSTRUCTION. Before this case existed
# the hook flagged every correctly written Vitest file on its outermost line.
case "$out" in *"L2"*) fail "does not flag the describe wrapper" "flagged the group opener" ;;
  *) pass "does not flag the describe wrapper" ;; esac

# ---- 5. SILENCE: explicitly skipped and assertion-free-by-declaration -------------------
f=$(mk src/skipped.test.ts <<'TS'
import { it, expect } from 'vitest'
it.skip('adds later', () => { add(9, 9) })
it.todo('handles currency')
it('adds', () => { expect(add(1, 1)).toBe(2) })
TS
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on it.skip / it.todo" \
  || fail "silent on it.skip / it.todo" "flagged: $out"

# ---- 6. SILENCE: not a test file ---------------------------------------------------------
f=$(mk src/plain.ts <<'TS'
export const add = (a: number, b: number) => a + b
TS
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on a non-test path" \
  || fail "silent on a non-test path" "flagged: $out"

# ---- 7. the per-file bound: the same file twice in one context reports once --------------
f=$(mk tests/BoundTest.php <<'PHP'
<?php
class BoundTest extends TestCase {
    public function test_hollow(): void { new Invoice(1); }
}
PHP
)
cwd="$(mktemp -d "$TMP/bcwd.XXXXXX")"
twice() {
  python3 -c 'import json,sys
print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Write","cwd":sys.argv[1],
 "session_id":"1","transcript_path":"/Users/x/.claude/projects/-p/f.jsonl",
 "tool_input":{"file_path":sys.argv[2]}}))' "$cwd" "$f" | bash "$HOOK" 2>/dev/null
}
first=$(twice); second=$(twice)
if [ -n "$first" ] && [ -z "$second" ]; then pass "the same file is reported once per context"
else fail "the same file is reported once per context" "first='${first:0:40}' second='${second:0:40}'"; fi
if [ -n "$(find "$cwd/.claude/testing" -name 'shape-*' -type f 2>/dev/null)" ]
then pass "the state file lands on disk (the key is hashed, not a raw path)"
else fail "the state file lands on disk (the key is hashed, not a raw path)" "none under $cwd"; fi

# ---- 8. FAIL-OPEN ------------------------------------------------------------------------
printf '' | bash "$HOOK" >/dev/null 2>&1 && pass "empty stdin exits 0" || fail "empty stdin exits 0" "non-zero"
printf 'not json' | bash "$HOOK" >/dev/null 2>&1 && pass "malformed stdin exits 0" || fail "malformed stdin exits 0" "non-zero"
CC_TEST_SHAPE=off bash -c 'printf "{}" | bash "$0"' "$HOOK" >/dev/null 2>&1 \
  && pass "CC_TEST_SHAPE=off exits 0" || fail "CC_TEST_SHAPE=off exits 0" "non-zero"

printf '\n'
[ "$rc" -eq 0 ] && printf 'test-shape.test: all cases passed\n' || printf 'test-shape.test: FAILURES above\n'
exit "$rc"
