#!/usr/bin/env bash
# Tests for spec-ledger-lint.sh — the converged-ledger author-time gate.
# Same harness shape as verify-teeth-lint.test.sh: explicit exit codes,
# PASS/FAIL per case, exit 0 only if every case passes.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lint="$here/../spec-ledger-lint.sh"

[ -x "$lint" ] || { printf 'FAIL: lint not executable at %s\n' "$lint"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pass=0
fail=0

# run_case <desc> <expected_rc> <expected_stderr_substr> -- <lint args...>
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

mk() { printf '%s\n' "$2" > "$tmp/$1"; }

# 1) converged ledger: all rows CLEAR/ASSUMED -> pass
mk good.md '# Spec
## Ambiguity ledger (final)
| # | Question | Resolution | Status | Source |
|---|----------|------------|--------|--------|
| 1 | Auth method | Session-based | CLEAR | config/auth.php:14 |
| 2 | Who can delete | Owner only | ASSUMED | default, round 2 |
## Goal
Do the thing.'
run_case "converged ledger passes" 0 "" --spec "$tmp/good.md"

# 2) open UNKNOWN row -> blocked
mk unknown.md '# Spec
## Ambiguity ledger (final)
| # | Question | Resolution | Status | Source |
|---|----------|------------|--------|--------|
| 1 | Auth method | Session-based | CLEAR | config/auth.php:14 |
| 3 | Bulk-action UX | ? | UNKNOWN | — |
## Goal
Do the thing.'
run_case "open UNKNOWN row blocked" 2 "open-unknown" --spec "$tmp/unknown.md"

# 3) no ledger section at all -> blocked
mk noledger.md '# Spec
## Goal
Do the thing.
## Success criteria
- it works'
run_case "missing ledger section blocked" 2 "no-ledger" --spec "$tmp/noledger.md"

# 4) ledger section with no data rows -> blocked
mk empty.md '# Spec
## Ambiguity ledger (final)
| # | Question | Resolution | Status | Source |
|---|----------|------------|--------|--------|
## Goal
Do.'
run_case "empty ledger blocked" 2 "empty-ledger" --spec "$tmp/empty.md"

# 5) row with no status token at all -> blocked (status column dropped)
mk nostatus.md '# Spec
## Ambiguity ledger (final)
| # | Question | Resolution |
|---|----------|------------|
| 1 | Auth method | Session-based |
## Goal
Do.'
run_case "row without status blocked" 2 "no-status" --spec "$tmp/nostatus.md"

# 6) UNKNOWN as lowercase prose in a question cell does NOT trip the gate
mk prose.md '# Spec
## Ambiguity ledger (final)
| # | Question | Resolution | Status | Source |
|---|----------|------------|--------|--------|
| 1 | Handle unknown hosts? | Reject with 422 | CLEAR | user, round 1 |
## Goal
Do.'
run_case "lowercase unknown in prose passes" 0 "" --spec "$tmp/prose.md"

# 7) ledger heading variants: bare "## Ambiguity ledger" (no "(final)") accepted
mk bare.md '# Spec
## Ambiguity ledger
| # | Question | Resolution | Status | Source |
|---|----------|------------|--------|--------|
| 1 | Auth | Session | CLEAR | code |
## Goal
Do.'
run_case "bare heading accepted" 0 "" --spec "$tmp/bare.md"

# 8) usage errors
run_case "missing --spec is usage error" 3 "usage error" --line "x"
run_case "nonexistent file is usage error" 3 "not found" --spec "$tmp/nope.md"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
