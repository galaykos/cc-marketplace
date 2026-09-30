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

fire_bash() { # command
  python3 - "$1" <<'PY' | "${BASH:-bash}" "$HOOK" 2>/dev/null
import json,sys,os
print(json.dumps({"session_id":"pt","cwd":os.environ.get("T",""),"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))
PY
}
bash_denies() { # name command
  out=$(fire_bash "$2")
  case "$out" in *'"permissionDecision":"deny"'*) ok "$1" ;; *) bad "$1" "expected deny, got: ${out:-<silent>}" ;; esac
}
bash_allows() {
  out=$(fire_bash "$2")
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

# An iterator/stream adapter named skip is not a test skip. These languages are
# deliberately covered (*Test.java, *_test.rs), so an unanchored pattern denied
# ordinary code in them — the regression a branch review caught before merge.
printf 'class UserTest {}\n' > "$T/UserTest.java"
printf 'fn t(){}\n'          > "$T/parser_test.rs"
printf 'def test_a(): pass\n' > "$T/test_seq.py"
allows "java stream().skip(1) is not a test skip" Edit \
  "{\"file_path\":\"$T/UserTest.java\",\"old_string\":\"zz\",\"new_string\":\"var rest = list.stream().skip(1).toList();\"}"
allows "rust iter().skip(2) is not a test skip" Edit \
  "{\"file_path\":\"$T/parser_test.rs\",\"old_string\":\"zz\",\"new_string\":\"items.iter().skip(2).collect()\"}"
allows "python itertools islice-style .skip is not a test skip" Edit \
  "{\"file_path\":\"$T/test_seq.py\",\"old_string\":\"zz\",\"new_string\":\"rows = cursor.skip(10).limit(5)\"}"
# but the anchored spellings still deny, including a chained one
denies "it.each([...]).skip still denies" Edit \
  "{\"file_path\":\"$T/a.test.ts\",\"old_string\":\"zz\",\"new_string\":\"it.each([1]).skip('a',()=>{});\"}"
denies "describe.skip still denies" Edit \
  "{\"file_path\":\"$T/a.test.ts\",\"old_string\":\"zz\",\"new_string\":\"describe.skip('g',()=>{});\"}"

# RSpec and minitest call without parentheses, so every Ruby arm that required a `(`
# waved these through while the header claimed Ruby coverage (panel 2026-09-22, SW 4).
printf 'RSpec.describe Calc do\n  it "adds" do\n    expect(Calc.new.add(1,1)).to eq(2)\n  end\nend\n' > "$T/calc_spec.rb"
denies "RSpec paren-less xit" Edit \
  "{\"file_path\":\"$T/calc_spec.rb\",\"old_string\":\"it \\\"adds\\\" do\",\"new_string\":\"xit \\\"adds\\\" do\"}"
denies "RSpec paren-less xdescribe" Edit \
  "{\"file_path\":\"$T/calc_spec.rb\",\"old_string\":\"zz\",\"new_string\":\"xdescribe \\\"Calc\\\" do\"}"
denies "RSpec pending with a quoted reason" Edit \
  "{\"file_path\":\"$T/calc_spec.rb\",\"old_string\":\"zz\",\"new_string\":\"    pending \\\"not implemented\\\"\"}"
denies "bare skip with a quoted reason (RSpec/bats)" Edit \
  "{\"file_path\":\"$T/calc_spec.rb\",\"old_string\":\"zz\",\"new_string\":\"    skip \\\"needs db\\\"\"}"
# The quote is what separates a skip declaration from an ordinary method call, and the
# same-line reason escape must still work on the paren-less form.
allows "items.skip 2 is not a test skip" Edit \
  "{\"file_path\":\"$T/calc_spec.rb\",\"old_string\":\"zz\",\"new_string\":\"    rest = items.skip 2\"}"
allows "a paren-less skip WITH a same-line reason" Edit \
  "{\"file_path\":\"$T/calc_spec.rb\",\"old_string\":\"zz\",\"new_string\":\"    skip \\\"needs db\\\" # skip: fixture DB missing, see #99\"}"

# The escape hatch must work when the same hunk carries an OLD unreasoned marker
# through unchanged: only the ADDED marker is judged.
printf "it.skip('b',()=>{});\n" > "$T/pre.test.ts"
allows "a reasoned NEW skip beside an unchanged unreasoned one" Edit \
  "{\"file_path\":\"$T/pre.test.ts\",\"old_string\":\"it.skip('b',()=>{});\",\"new_string\":\"it.skip('a',()=>{}) // skip: flaky #42\nit.skip('b',()=>{});\"}"

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
[ -z "$out" ] && ok "bash: rm of a test dir is not a write (command-guard's)" || bad "bash: rm of a test dir is not a write (command-guard's)" "$out"

# --- Bash writes: judged as a Write of the target, old text = the file on disk -------
mkf
bash_denies "bash: heredoc overwrite adding it.skip denies" \
  $'cat > a.test.ts <<\'EOF\'\nit.skip(\'a\',()=>{});\nit(\'b\',()=>{});\nEOF'  # skip: the fixture this case must deny
mkf
bash_denies "bash: echo append adding .only denies" \
  "echo \"it.only('c',()=>{});\" >> a.test.ts"  # skip: the fixture this case must deny
mkf
bash_denies "bash: heredoc emptying a test file denies" \
  $'cat > a.test.ts <<\'EOF\'\n// rewrite\nEOF'
mkf
bash_allows "bash: append of a reasoned skip is allowed" \
  "echo \"it.skip('c',()=>{}); // skip: flaky on CI\" >> a.test.ts"
mkf
bash_allows "bash: non-write command is allowed" \
  "npx vitest run a.test.ts"
mkf
bash_allows "bash: heredoc into a command that writes no file is allowed" \
  $'node - <<\'EOF\'\nit.skip(\'a\')\nEOF'  # skip: fixture fed to a command that writes no file
mkf
bash_allows "production file: heredoc skip into a non-test file is allowed" \
  $'cat > src/app.ts <<\'EOF\'\nit.skip(\'x\')\nEOF'  # skip: fixture written to a non-test path
mkf
bash_allows "sequence: clear then append in one command is judged on the result" \
  $'echo "// generated" > a.test.ts && cat >> a.test.ts <<\'EOF\'\nit(\'a\',()=>{});\nEOF'
mkf
bash_allows "tee -a: append of a comment is allowed" \
  "echo '// note' | tee -a a.test.ts"
mkf
bash_allows "tee -i -a: append of a comment is allowed" \
  "echo '// note' | tee -i -a a.test.ts"
mkdir -p "$T/tests" && printf "it.skip('b',()=>{});\nit('c',()=>{});\n" > "$T/tests/kept.test.ts"  # skip: pre-existing marker fixture
mkf
bash_denies "cd in body: a heredoc body line starting with cd does not silence the guard" \
  $'cat > a.test.ts <<\'EOF\'\ncd /tmp\nit.skip(\'a\',()=>{});\nit(\'b\',()=>{});\nEOF'  # skip: the fixture this case must deny
bash_allows "cd: a kept marker under an in-command cd is not read as new" \
  $'cd tests && cat > kept.test.ts <<\'EOF\'\nit.skip(\'b\',()=>{});\nit(\'c\',()=>{});\nit(\'d\',()=>{});\nEOF'  # skip: kept marker fixture

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
