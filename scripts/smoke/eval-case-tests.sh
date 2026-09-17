#!/usr/bin/env bash
# Fixtures for scripts/eval-cases.sh — the gate that a shipped eval suite LOADS.
#
# The case that matters is the FIRST one: a suite directory that resolves to zero cases.
# That is not hypothetical here — `resilience` and `web-dev` were in exactly that state
# for weeks while looking maintained, and the only reason anybody found out was a manual
# run. Every other assertion below is a narrower version of the same failure: the suite
# is present, and the runner gets nothing out of it.
#
# The gate is run against a SYNTHETIC tree, not the repo's own plugins, so a fixture
# cannot be satisfied by a real suite happening to be correct.
set -u
cd "$(dirname "$0")/../.." || exit 1
GATE=$(pwd)/scripts/eval-cases.sh
rc=0; pass=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

ok()  { pass=$((pass+1)); printf 'PASS: %s\n' "$1"; }
bad() { printf 'FAIL: %s\n      %s\n' "$1" "$2"; rc=1; }

# Drive the gate over a synthetic plugins/ tree.
# Run the COPY inside the fixture tree: the gate resolves its root from its own
# path, so invoking the repo's copy would silently check the repo's real plugins/
# and every assertion below would pass for the wrong reason. It did, once.
run_gate() { bash "$T/scripts/eval-cases.sh" 2>&1; }

good_case() { mkdir -p "$1"; cat > "$1/case.yaml" <<YAML
schema_version: "1.0"
name: $(basename "$1")
execution:
  max_turns: 25
  prompt: |
    Review this.
runs: 3
graders:
  - type: llm
    name: g
    criteria: |
      PASS if it says anything.
YAML
}

mkdir -p "$T/scripts" && cp scripts/eval-cases.sh "$T/scripts/"

expect_fail() { # label needle
  out=$(run_gate); st=$?
  if [ "$st" -eq 0 ]; then bad "$1" "gate passed; it must fail"; return; fi
  case "$out" in *"$2"*) ok "$1" ;; *) bad "$1" "no match for '$2' in: $out" ;; esac
}

# --- the baseline: a well-formed suite passes ---------------------------------
good_case "$T/plugins/alpha/evals/one"
out=$(run_gate); st=$?
[ "$st" -eq 0 ] && ok "a well-formed suite passes" || bad "a well-formed suite passes" "$out"

# --- THE bug: a suite directory that loads zero cases -------------------------
mkdir -p "$T/plugins/beta/evals"
expect_fail "an evals/ dir with no case.yaml fails (the 2026-09-14 bug)" "loads ZERO cases"
rm -rf "$T/plugins/beta"

# --- the prompt.md + graders/*.md shape -----------------------------------------
# Valid on the runner (measured 2026-09-16, CLI 2.1.273); what killed the two 09-14
# suites was a grader with no frontmatter, so THAT is what fails here — never the shape.
prompt_case() { mkdir -p "$1/graders"; printf 'Say hello.\n' > "$1/prompt.md"; }
prompt_case "$T/plugins/beta/evals/p"
printf -- '---\ntype: regex\npattern: hello\n---\n' > "$T/plugins/beta/evals/p/graders/x.md"
out=$(run_gate); st=$?
[ "$st" -eq 0 ] && ok "a prompt.md case with a typed grader passes" || bad "a prompt.md case with a typed grader passes" "$out"

printf 'PASS if the answer says hello.\n' > "$T/plugins/beta/evals/p/graders/x.md"
expect_fail "a grader with no type: frontmatter fails (the 2026-09-14 rejection)" "no type: frontmatter (the 2026-09-14 rejection, not a dead shape)"

# The frontmatter is read as YAML, the way the runner reads it: a quoted, commented,
# BOM-prefixed or CRLF `type:` is a type. The awk line this replaced rejected all four
# with the no-frontmatter message, naming the wrong root cause.
printf -- '\xef\xbb\xbf---\r\ntype: "regex"  # quoted\r\npattern: hello\r\n---\r\n' > "$T/plugins/beta/evals/p/graders/x.md"
out=$(run_gate); st=$?
[ "$st" -eq 0 ] && ok "a quoted, commented, BOM+CRLF grader type passes" || bad "a quoted, commented, BOM+CRLF grader type passes" "$out"

printf -- '---\ntype: ""\n---\n' > "$T/plugins/beta/evals/p/graders/x.md"
expect_fail "a grader with an empty type: fails" "no type: frontmatter (the 2026-09-14 rejection, not a dead shape)"

printf -- '---\ntype: regex\npattern: hello\n' > "$T/plugins/beta/evals/p/graders/x.md"
expect_fail "a grader whose frontmatter never closes fails" "never closed"

rm -rf "$T/plugins/beta/evals/p/graders"
expect_fail "a prompt.md with no graders/ fails" "graders: Required"
rm -rf "$T/plugins/beta"

# --- prompt.md + graders/*.md + a context-only case.yaml (both files) ----------------
# The runner's usage line admits the combination; until 2026-09-17 the case.yaml branch
# held the sibling to execution.prompt/graders it has no reason to carry.
prompt_case "$T/plugins/beta/evals/p"
printf -- '---\ntype: regex\npattern: hello\n---\n' > "$T/plugins/beta/evals/p/graders/x.md"
printf 'schema_version: "1.0"\nname: p\nruns: 2\nexecution:\n  max_turns: 10\n' > "$T/plugins/beta/evals/p/case.yaml"
out=$(run_gate); st=$?
[ "$st" -eq 0 ] && ok "prompt.md + graders + a context-only case.yaml passes" || bad "prompt.md + graders + a context-only case.yaml passes" "$out"

printf 'runs: 2\n' > "$T/plugins/beta/evals/p/case.yaml"
expect_fail "a context-only case.yaml still needs name" "no \`name\`"
rm -rf "$T/plugins/beta"

# --- only the top level of a case is a case -------------------------------------------
# A prompt.md under resources/ is a fixture the case reads; the recursive find this
# replaced counted it as a second case and failed it for having no graders/.
good_case "$T/plugins/beta/evals/x"
mkdir -p "$T/plugins/beta/evals/x/resources" && printf 'fixture\n' > "$T/plugins/beta/evals/x/resources/prompt.md"
out=$(run_gate); st=$?
case "$st:$out" in
  0:*"OK: 2 eval case(s) across 2 suite(s) load"*) ok "a resources/prompt.md beside a valid case is ignored and the case counts once" ;;
  *) bad "a resources/prompt.md beside a valid case is ignored and the case counts once" "$out" ;;
esac
rm -rf "$T/plugins/beta"

# --- a case directory holding neither file -------------------------------------
good_case "$T/plugins/beta/evals/c"; mkdir -p "$T/plugins/beta/evals/empty"
expect_fail "a case dir with neither case.yaml nor prompt.md fails" "holds neither case.yaml nor prompt.md"
rm -rf "$T/plugins/beta"

# --- per-case schema ----------------------------------------------------------
good_case "$T/plugins/beta/evals/c"
python3 - "$T/plugins/beta/evals/c/case.yaml" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
open(p,'w').write(re.sub(r'graders:.*', '', s, flags=re.S))
PY
expect_fail "a case with no graders fails" "loaded 0 cases on 2026-09-14"

good_case "$T/plugins/beta/evals/c"
printf 'graders: []\n' >> "$T/plugins/beta/evals/c/case.yaml"
expect_fail "an empty graders list fails" "non-empty list"

good_case "$T/plugins/beta/evals/c"
python3 - "$T/plugins/beta/evals/c/case.yaml" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read().replace("  - type: llm\n","  - name: nope\n")
open(p,'w').write(s)
PY
expect_fail "a grader with no type fails" "has no \`type\`"

good_case "$T/plugins/beta/evals/c"
python3 - "$T/plugins/beta/evals/c/case.yaml" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
open(p,'w').write(s.split("    criteria:")[0]+"    criteria: \"\"\n")
PY
expect_fail "an llm grader with empty criteria fails" "empty \`criteria\`"

good_case "$T/plugins/beta/evals/c"
python3 - "$T/plugins/beta/evals/c/case.yaml" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read().replace("  prompt: |\n    Review this.\n","  prompt: \"\"\n")
open(p,'w').write(s)
PY
expect_fail "an empty prompt fails" "\`execution.prompt\` is empty"

good_case "$T/plugins/beta/evals/c"
python3 - "$T/plugins/beta/evals/c/case.yaml" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read().replace("name: c","name: mismatched")
open(p,'w').write(s)
PY
expect_fail "a name that does not match its directory fails" "does not match its directory"

good_case "$T/plugins/beta/evals/c"
python3 - "$T/plugins/beta/evals/c/case.yaml" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read().replace("runs: 3","runs: 0")
open(p,'w').write(s)
PY
expect_fail "runs: 0 fails" "positive integer"

good_case "$T/plugins/beta/evals/c"
printf 'this: [is not\n' >> "$T/plugins/beta/evals/c/case.yaml"
expect_fail "malformed YAML fails" "is not valid YAML"

printf '\n%s assertion(s) passed\n' "$pass"
exit "$rc"
