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

# ---- 5b. SILENCE: assertion dialects that carry no `expect` --------------------------
# An adversarial audit on 2026-08-18 found the vocabulary flagged chai should-style and
# ava/tape as assertion-free — entire correct dialects reported as proving nothing, while
# the hook's LIMITATION admitted only the narrower project-helper case.
f=$(mk src/chai.spec.js <<'JS'
describe('user', () => {
  it('has a name', () => { user.name.should.equal('Ann') })
  it('is active', () => { user.active.should.be.true })
})
JS
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on chai should-style assertions" \
  || fail "silent on chai should-style assertions" "flagged: $out"

f=$(mk src/ava.test.js <<'JS'
test('adds', t => { t.is(add(1, 2), 3) })
test('rejects null', t => { t.throws(() => add(null)) })
JS
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on ava/tape assertions" \
  || fail "silent on ava/tape assertions" "flagged: $out"

# ---- 5c. the three dialects the PATH GLOB admits and the OPENER SET did not --------------
# `*_test.py`, `*_test.go` and `*_spec.rb` were in the glob at :82 while is_opener() matched
# only JS and PHP, so all three found zero blocks and the hook was silent — the same output
# a clean file produces (panel 2026-09-22, SW 4). One assertion-free block each: each file
# must report exactly the hollow block and leave the asserting one alone.
f=$(mk tests/calc_test.py <<'PY'
def test_it_can_be_instantiated():
    Calc()

def test_adds():
    assert Calc().add(1, 1) == 2
PY
)
out=$(fire "$f")
case "$out" in *"L1"*"no assertion"*) pass "flags an assertion-free pytest block" ;;
  *) fail "flags an assertion-free pytest block" "got: ${out:-<silent>}" ;; esac
case "$out" in *"L4"*) fail "pytest bare assert counts as an assertion" "flagged L4: $out" ;;
  *) pass "pytest bare assert counts as an assertion" ;; esac

f=$(mk tests/calc_test.go <<'GO'
package calc

import "testing"

func TestItCanBeInstantiated(t *testing.T) {
	New()
}

func TestAdds(t *testing.T) {
	if New().Add(1, 1) != 2 {
		t.Fatalf("bad")
	}
}
GO
)
out=$(fire "$f")
case "$out" in *"L5"*"no assertion"*) pass "flags an assertion-free Go block" ;;
  *) fail "flags an assertion-free Go block" "got: ${out:-<silent>}" ;; esac
case "$out" in *"L9"*) fail "Go t.Fatalf counts as an assertion" "flagged L9: $out" ;;
  *) pass "Go t.Fatalf counts as an assertion" ;; esac

f=$(mk tests/calc_spec.rb <<'RB'
RSpec.describe Calc do
  it "can be instantiated" do
    Calc.new
  end

  it "adds" do
    expect(Calc.new.add(1, 1)).to eq(2)
  end
end
RB
)
out=$(fire "$f")
case "$out" in *"L2"*"no assertion"*) pass "flags an assertion-free RSpec block" ;;
  *) fail "flags an assertion-free RSpec block" "got: ${out:-<silent>}" ;; esac
case "$out" in *"L6"*) fail "the RSpec block that asserts is left alone" "flagged L6: $out" ;;
  *) pass "the RSpec block that asserts is left alone" ;; esac

# ---- 5d. SILENCE: the same three dialects' DECLARED skips and their other assertion forms -
# Widening the opener set makes every declared skip in these languages a candidate finding,
# and in Python, Go and Ruby the declaration sits in the BODY or on the decorator line above,
# not on the opener line where the JS spelling lives. The `skip:` comments inside these
# heredocs are the sibling guard's documented same-line-reason escape: protect-tests.sh
# reads this harness as a test file and denies the fixture text without them.
f=$(mk tests/skips_test.py <<'PY'
import pytest

@pytest.mark.skip(reason="not ready")  # skip: harness fixture, not a real suite
def test_later():
    Calc()

def test_inline_skip():
    pytest.skip("env missing")

def test_adds():
    assert Calc().add(1, 1) == 2
PY
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on pytest decorator and inline skips" \
  || fail "silent on pytest decorator and inline skips" "flagged: $out"

f=$(mk tests/skips_test.go <<'GO'
package calc

import (
	"os"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestMain(m *testing.M) {
	os.Exit(m.Run())
}

func TestLater(t *testing.T) {
	t.Skip("needs docker")  // skip: harness fixture, not a real suite
}

func TestReq(t *testing.T) {
	require.Equal(t, 2, New().Add(1, 1))
}
GO
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on Go TestMain, t.Skip and testify require" \
  || fail "silent on Go TestMain, t.Skip and testify require" "flagged: $out"

f=$(mk tests/skips_spec.rb <<'RB'
RSpec.describe Calc do
  context "when new" do
    xit "is instantiable" do  # skip: harness fixture, not a real suite
      Calc.new
    end

    it "is later" do
      pending "not implemented"  # skip: harness fixture, not a real suite
    end

    it { is_expected.to be_valid }

    it "raises" do
      expect { Calc.new(-1) }.to raise_error(ArgumentError)
    end

    it "adds" do
      Calc.new.add(1, 1).should eq(2)
    end
  end
end
RB
)
out=$(fire "$f"); [ -z "$out" ] && pass "silent on RSpec xit/pending and its paren-less assertion forms" \
  || fail "silent on RSpec xit/pending and its paren-less assertion forms" "flagged: $out"

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
if [ "$(cat "$cwd/.claude/testing/.gitignore" 2>/dev/null)" = "*" ]; then pass "the state dir ignores itself"
else fail "the state dir ignores itself" ".claude/testing/.gitignore missing or not '*'"; fi

# ---- 7b. a payload cwd that no longer exists must not be rebuilt -------------------------
# A session outlives the directory it started in, and `mkdir -p` was happy to recreate a
# deleted project tree three levels deep just to hold this hook's state (panel 2026-09-22,
# AR 1 — the same class resurrected a deleted design-studio in a live repo).
gone="$TMP/work/acme/design-studio"
mkdir -p "$gone"; rm -rf "$TMP/work"
python3 -c 'import json,sys
print(json.dumps({"hook_event_name":"PostToolUse","tool_name":"Write","cwd":sys.argv[1],
 "session_id":"g","transcript_path":"/t/g.jsonl","tool_input":{"file_path":sys.argv[2]}}))' \
  "$gone" "$f" | bash "$HOOK" >/dev/null 2>&1
[ -d "$TMP/work" ] && fail "a deleted cwd is not recreated" "rebuilt $TMP/work" \
  || pass "a deleted cwd is not recreated"

# ---- 8. FAIL-OPEN ------------------------------------------------------------------------
printf '' | bash "$HOOK" >/dev/null 2>&1 && pass "empty stdin exits 0" || fail "empty stdin exits 0" "non-zero"
printf 'not json' | bash "$HOOK" >/dev/null 2>&1 && pass "malformed stdin exits 0" || fail "malformed stdin exits 0" "non-zero"
CC_TEST_SHAPE=off bash -c 'printf "{}" | bash "$0"' "$HOOK" >/dev/null 2>&1 \
  && pass "CC_TEST_SHAPE=off exits 0" || fail "CC_TEST_SHAPE=off exits 0" "non-zero"

printf '\n'
[ "$rc" -eq 0 ] && printf 'test-shape.test: all cases passed\n' || printf 'test-shape.test: FAILURES above\n'
exit "$rc"
