#!/usr/bin/env bash
# Fixture tests for brief-lint.sh — a leaning brief must be rejected, a
# facts-only brief must pass, and the known residual must stay documented.
set -u
LINT="$(cd "$(dirname "$0")/.." && pwd)/brief-lint.sh"
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

check "clean facts-only brief passes" 0 "clean" <<'EOF'
Moment type: stuck-debug
Problem statement: POST /api/orders returns 500. Log line:
  TypeError: Cannot read properties of undefined (reading 'total') at OrderService.js:42
History: attempt 1 added a null check at OrderService.js:40 — same error.
  attempt 2 changed the serializer at OrderResource.php:18 — error moved to line 44.
Relevant paths: app/Services/OrderService.js, app/Http/Resources/OrderResource.php
EOF

check "hypothesis phrasing is rejected" 1 "leaning phrasing" <<'EOF'
Moment type: stuck-debug
Problem statement: POST /api/orders returns 500.
I think the cache layer is stale. My hypothesis is the serializer runs twice.
Relevant paths: app/Services/OrderService.js
EOF

check "probability hedging is rejected" 1 "leaning phrasing" <<'EOF'
Problem statement: build fails on CI only.
It is probably the node version. Check the lockfile first.
EOF

check "the-bug-is phrasing is rejected" 1 "leaning phrasing" <<'EOF'
Problem statement: intermittent test failure in OrderTest.
The bug is in the transaction rollback handling.
EOF

check "confirm-that framing is rejected" 1 "leaning phrasing" <<'EOF'
Problem statement: migration hangs on the orders table.
Please confirm that the lock ordering is wrong.
EOF

check "attempts as facts are not leaning" 0 "clean" <<'EOF'
Moment type: irreversible
Problem statement: about to drop column orders.legacy_total; 3 queries in
  app/Reports reference it per grep output below.
History: the exact action queued: ALTER TABLE orders DROP COLUMN legacy_total;
Relevant paths: database/migrations/2026_08_12_drop_legacy_total.php
EOF

echo "brief-lint tests: $pass passed, $fail failed"
exit $((fail > 0))
