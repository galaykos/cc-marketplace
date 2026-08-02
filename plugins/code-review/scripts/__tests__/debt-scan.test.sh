#!/usr/bin/env bash
# Fixtures for plugins/code-review/scripts/debt-scan.sh. Run by CI via the
# plugins/*/scripts/__tests__/*.test.sh glob.
#
# The ratchet, not the count, is what these lock. A scanner that reports numbers
# is a report; a scanner that fails when a number goes UP and offers an explicit
# way to accept the rise is a gate. Both halves are asserted, plus the
# no-baseline case — silently passing without a baseline would make the gate a
# no-op on every repo that never ran --update-baseline, which is all of them on
# day one.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
SCAN=plugins/code-review/scripts/debt-scan.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/src"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

expect() { # label want_rc args...
  local label="$1" want="$2"; shift 2
  bash "$SCAN" "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $label (rc=$got)"
  else echo "FAIL: $label — want rc=$want, got $got"; rc=1; fi
}

cat > "$FX/src/a.ts" <<'EOF'
// TODO: fix later
// eslint-disable-next-line no-console
console.log(1)
it.skip('broken', () => {})
/** @deprecated use b() */
export function a() {}
if (flags.newCheckout === true) {}
EOF

# --check with no baseline must NOT pass — a ratchet with nothing to compare
# against is not a ratchet, and exiting 0 there would make it invisible.
expect "check with no baseline exits 3" 3 --dir "$FX" --baseline "$FX/none.json" --check

expect "update-baseline succeeds" 0 --dir "$FX" --baseline "$FX/base.json" --update-baseline

# all five categories must be present and non-zero for the seeded fixture
for k in suppressions skipped_tests bare_markers deprecated_refs feature_flags; do
  v=$(jq -r --arg k "$k" '.[$k] // "missing"' "$FX/base.json")
  if [ "$v" != "missing" ] && [ "$v" -gt 0 ] 2>/dev/null; then
    echo "PASS: category $k detected ($v)"
  else
    echo "FAIL: category $k not detected (got $v)"; rc=1
  fi
done

expect "unchanged tree passes --check" 0 --dir "$FX" --baseline "$FX/base.json" --check

echo '// FIXME: another one' >> "$FX/src/a.ts"
expect "growth fails --check" 2 --dir "$FX" --baseline "$FX/base.json" --check

expect "update-baseline accepts the growth" 0 --dir "$FX" --baseline "$FX/base.json" --update-baseline
expect "accepted growth then passes" 0 --dir "$FX" --baseline "$FX/base.json" --check

# Paying debt down must never fail the build — a ratchet that punishes improvement
# is a ratchet nobody runs twice.
: > "$FX/src/a.ts"
expect "removing debt passes --check" 0 --dir "$FX" --baseline "$FX/base.json" --check

# Vendored trees are somebody else's debt; counting them makes the number move on
# a dependency update, which is exactly the noise a ratchet cannot tolerate.
mkdir -p "$FX/node_modules/pkg"
printf '// TODO vendored\n// @ts-ignore\n' > "$FX/node_modules/pkg/index.ts"
expect "node_modules excluded" 0 --dir "$FX" --baseline "$FX/base.json" --check

expect "missing directory exits 3" 3 --dir "$FX/nope" --check

[ "$rc" -eq 0 ] && echo "All debt-scan fixtures passed."
exit "$rc"
