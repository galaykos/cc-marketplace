#!/usr/bin/env bash
# Fixture tests for dispatch-lint.sh — the four string-checkable prompt-contract
# elements must each be detected present and missing.
set -u
LINT="$(cd "$(dirname "$0")/.." && pwd)/dispatch-lint.sh"
pass=0; fail=0

check() { # check <name> <expected-exit> <expect-grep-or-empty>
  local name="$1" want="$2" grepfor="$3" out rc
  out=$(bash "$LINT" /dev/stdin 2>&1); rc=$?
  if [[ $rc -ne $want ]]; then
    echo "FAIL $name: exit $rc, wanted $want"; echo "$out" | sed 's/^/    /'; fail=$((fail+1)); return
  fi
  if [[ -n "$grepfor" ]] && ! grep -q "$grepfor" <<<"$out"; then
    echo "FAIL $name: output missing '$grepfor'"; echo "$out" | sed 's/^/    /'; fail=$((fail+1)); return
  fi
  pass=$((pass+1))
}

check "full contract passes" 0 "" <<'EOF'
Fix the null-total bug in /Users/dev/app/src/services/OrderService.js.
Do not modify tests or any other file — only edit that one file.
Return at most 5 lines: file:line — what changed — verify output tail.
Your final message is data for the orchestrator, not prose for a human.
EOF

check "no absolute path is flagged" 1 "missing absolute path" <<'EOF'
Fix the parser in src/parse.py. Do not modify tests or any other file.
Return at most 5 lines, one line each.
Your final message is data for the orchestrator, not prose for a human.
EOF

check "no scope lock is flagged" 1 "missing scope lock" <<'EOF'
Fix the parser in /Users/dev/app/src/parse.py.
Return at most 5 lines, one line each.
Your final message is data for the orchestrator, not prose for a human.
EOF

check "no return shape is flagged" 1 "missing return shape" <<'EOF'
Fix the parser in /Users/dev/app/src/parse.py. Do not modify any other file.
Your final message is data for the orchestrator, not prose for a human.
EOF

check "no closing data instruction is flagged" 1 "missing closing data instruction" <<'EOF'
Fix the parser in /Users/dev/app/src/parse.py. Do not modify any other file.
Return at most 5 lines, one line each.
EOF

check "bare 'fix the parser' fails all four" 1 "missing absolute path" <<'EOF'
Fix the parser.
EOF

echo "dispatch-lint tests: $pass passed, $fail failed"
exit $((fail > 0))
