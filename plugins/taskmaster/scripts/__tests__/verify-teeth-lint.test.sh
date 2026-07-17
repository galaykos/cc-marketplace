#!/usr/bin/env bash
# Tests for verify-teeth-lint.sh — the B3(a) author-time denylist lint.
# Each case captures the exit code explicitly and prints PASS/FAIL. The script
# exits 0 only if every case passes.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lint="$here/../verify-teeth-lint.sh"

[ -x "$lint" ] || { printf 'FAIL: lint not executable at %s\n' "$lint"; exit 1; }

pass=0
fail=0

# run_case <desc> <expected_rc> <expected_stderr_substr> -- <lint args...>
# Empty expected_stderr_substr means "do not check output".
run_case() {
  desc="$1"; exp_rc="$2"; exp_sub="$3"; shift 3
  set +e
  out=$("$lint" "$@" 2>&1)
  rc=$?
  set -e
  ok=1
  [ "$rc" = "$exp_rc" ] || ok=0
  if [ -n "$exp_sub" ]; then
    printf '%s' "$out" | grep -q -- "$exp_sub" || ok=0
  fi
  if [ "$ok" = 1 ]; then
    printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (rc=%s want=%s; out=<%s> want-substr=<%s>)\n' \
      "$desc" "$rc" "$exp_rc" "$out" "$exp_sub"
    fail=$((fail + 1))
  fi
}

# --- Required minimum cases (from the card) ---
run_case "existence-only: test -f"        2 "existence-only"  --line 'test -f out.js'
run_case "bare-suite-pass: npm test"      2 "bare-suite-pass" --line 'npm test'
run_case "require-only: node -e require"  2 "require-only"    --line 'node -e "require(\"./x\")"'
run_case "strong: jest -t + asserts"      0 ""                --line 'jest -t "rejects bad host" asserts throw'

# --- Additional coverage for every weak form and a strong runner line ---
run_case "strong: pytest -k + asserts"    0 ""                --line 'pytest -k reject_malicious_host asserts 422'
run_case "always-true: || true"           2 "always-true"     --line 'curl -s localhost:3000/health || true'
# --- Fix 3: always-true tails that evaded the old '([[:space:]]|$)' boundary ---
run_case "always-true: || true; (semicolon)" 2 "always-true"  --line 'npm test || true;'
run_case "always-true: cmd || true) (paren)" 2 "always-true"  --line 'cmd || true)'
run_case "always-true: (cmd || true) full"   2 "always-true"  --line '(cmd || true)'
run_case "always-true: || : (no-op builtin)" 2 "always-true"  --line 'cmd || :'
run_case "always-true: bash -c quoted || true" 2 "always-true" --line 'bash -c "npm test || true"'
run_case "strong: colon in url not always-true" 0 ""          --line 'curl -s http://localhost:3000/api | grep -q ready'
run_case "compile-only: tsc --noEmit"     2 "compile-only"    --line 'tsc --noEmit'
run_case "import-only: python -c import"   2 "import-only"     --line 'python -c "import app"'
run_case "existence-only: ls whole check" 2 "existence-only"  --line 'ls dist/'
# --- Fix 1: existence-only via `test -d` and the `[ -f ]` bracket form ---
run_case "existence-only: test -d dir"    2 "existence-only"  --line 'test -d dist'
run_case "existence-only: [ -f ] bracket" 2 "existence-only"  --line '[ -f out.js ]'
run_case "existence-only: [ -d ] bracket" 2 "existence-only"  --line '[ -d dist ]'
run_case "strong: [ -f ] && grep guarded" 0 ""                --line '[ -f out.js ] && grep -q ready out.js'
# --- Fix 2: `.toString`/ordinary methods must NOT count as an assertion, so a bare
#     require(...).toString() is still require-only; real jest matchers still count. ---
run_case "require-only: require().toString()" 2 "require-only" --line 'node -e "require(\"./x\").toString()"'
run_case "strong: require().toBeTruthy() matcher" 0 ""        --line 'node -e "require(\"./x\").val.toBeTruthy()"'
run_case "usage: no args"                 3 "usage"

# --- --card extraction: weak and strong Verify lines from a markdown card ---
tmp_weak=$(mktemp)
tmp_strong=$(mktemp)
trap 'rm -f "$tmp_weak" "$tmp_strong"' EXIT
printf '# Card 07\n\n- **Goal:** ship it\n- **Verify:** `npm test`\n' > "$tmp_weak"
printf -- '- **Verify:** `pytest -k reject_bad_host asserts 422`\n' > "$tmp_strong"
run_case "card: extracts weak Verify line"   2 "bare-suite-pass" --card "$tmp_weak"
run_case "card: extracts strong Verify line" 0 ""                --card "$tmp_strong"

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
