#!/usr/bin/env bash
# Fixture tests for hooks/protect-tests.sh — the fake-green guard.
# Asserts the deny shapes, every allow path, and the fail-open contract.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/protect-tests.sh"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

ok()   { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

# payload builder: tool, json tool_input
fire() {
  python3 - "$1" "$2" <<'PY' | "${BASH:-bash}" "$HOOK" 2>/dev/null
import json,sys,os
print(json.dumps({"session_id":"pt","cwd":os.environ.get("T",""),"tool_name":sys.argv[1],"tool_input":json.loads(sys.argv[2])}))
PY
}
export T

denies() { # name tool json
  out=$(fire "$2" "$3")
  case "$out" in *'"permissionDecision":"deny"'*) ok "$1" ;; *) bad "$1" "expected deny, got: ${out:-<silent>}" ;; esac
}
allows() {
  out=$(fire "$2" "$3")
  case "$out" in *deny*) bad "$1" "expected allow, got a deny" ;; *) ok "$1" ;; esac
}

mkf() { printf "it('a',()=>{expect(1).toBe(1)});\nit('b',()=>{expect(2).toBe(2)});\n" > "$T/a.test.ts"; }
mkf

# --- deny shapes -------------------------------------------------------------
denies "adds .skip with no reason" Edit \
  "{\"file_path\":\"$T/a.test.ts\",\"old_string\":\"it('a'\",\"new_string\":\"it.skip('a'\"}"
denies "adds .only (shrinks the suite to one case)" Edit \
  "{\"file_path\":\"$T/a.test.ts\",\"old_string\":\"it('a'\",\"new_string\":\"it.only('a'\"}"
denies "adds xit" Write \
  "{\"file_path\":\"$T/a.test.ts\",\"content\":\"xit('a',()=>{});\"}"
denies "empties a file that held tests" Write \
  "{\"file_path\":\"$T/a.test.ts\",\"content\":\"// TODO: rewrite\"}"
denies "pytest skip marker" Write \
  "{\"file_path\":\"$T/test_x.py\",\"content\":\"@pytest.mark.skip\\ndef test_a(): pass\\n\"}"
denies "phpunit markTestSkipped" Write \
  "{\"file_path\":\"$T/UserTest.php\",\"content\":\"public function testA(){ \$this->markTestSkipped(); }\"}"
denies "go t.Skip" Write \
  "{\"file_path\":\"$T/x_test.go\",\"content\":\"func TestA(t *testing.T){ t.Skip() }\"}"
denies "MCP create_new_file carrying a skip" mcp__phpstorm__create_new_file \
  "{\"pathInProject\":\"$T/b.test.ts\",\"text\":\"it.skip('a',()=>{});\"}"

# --- allow paths -------------------------------------------------------------
mkf
allows "a skip WITH a same-line reason" Edit \
  "{\"file_path\":\"$T/a.test.ts\",\"old_string\":\"it('a'\",\"new_string\":\"it.skip('a') // skip: flaky on CI, see #1421\"}"
allows "editing an already-skipped test" Edit \
  "{\"file_path\":\"$T/a.test.ts\",\"old_string\":\"it.skip('x',()=>{})\",\"new_string\":\"it.skip('x',()=>{const a=1;})\"}"
allows "an ordinary assertion change" Edit \
  "{\"file_path\":\"$T/a.test.ts\",\"old_string\":\"toBe(1)\",\"new_string\":\"toBe(2)\"}"
allows "a skip in a PRODUCTION file" Edit \
  "{\"file_path\":\"$T/src/app.ts\",\"old_string\":\"a\",\"new_string\":\"it.skip('x')\"}"
allows "a rewrite that keeps its tests" Write \
  "{\"file_path\":\"$T/a.test.ts\",\"content\":\"it('a',()=>{expect(1).toBe(1)});\"}"
allows "a brand-new test file with no skip" Write \
  "{\"file_path\":\"$T/new.test.ts\",\"content\":\"it('a',()=>{});\"}"

# CC_PROTECT_TESTS=off
out_off=$(python3 - <<PY | CC_PROTECT_TESTS=off "${BASH:-bash}" "$HOOK" 2>/dev/null
import json
print(json.dumps({"session_id":"pt","cwd":"$T","tool_name":"Edit","tool_input":{"file_path":"$T/a.test.ts","old_string":"it('a'","new_string":"it.skip('a'"}}))
PY
)
[ -z "$out_off" ] && ok "CC_PROTECT_TESTS=off silences it" || bad "CC_PROTECT_TESTS=off silences it" "still spoke: $out_off"

# --- fail-open contract ------------------------------------------------------
out=$(printf 'not json at all' | "${BASH:-bash}" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc out=$out"
out=$(printf '{}' | "${BASH:-bash}" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on empty payload" || bad "fail-open on empty payload" "rc=$rc out=$out"
out=$(fire Bash "{\"command\":\"rm -rf tests\"}")
[ -z "$out" ] && ok "silent on a tool it does not match" || bad "silent on a tool it does not match" "$out"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
