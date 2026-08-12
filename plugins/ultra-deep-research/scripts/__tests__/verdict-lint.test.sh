#!/usr/bin/env bash
# Fixture tests for verdict-lint.sh — each case is a verdict block the lint
# must accept or reject for the stated reason.
set -u
LINT="$(cd "$(dirname "$0")/.." && pwd)/verdict-lint.sh"
pass=0; fail=0

check() { # check <name> <expected-exit> <expect-grep-or-empty> <<'EOF' ... EOF
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

check "confirmed with quote+timestamp+corroboration passes" 0 "" <<'EOF'
CLAIM: PostgreSQL 18 ships core uuidv7()
VERDICT: confirmed
FETCH: https://www.postgresql.org/about/news/x — retrieved 2026-08-12T10:00Z — "adds a uuidv7() function"
REASON: release announcement states it directly
CORROBORATION: https://xata.io/blog/postgres-18-features (independent Tier-2)
COUNTER_EVIDENCE: none found
CONFIDENCE: High
EOF

check "confirmed without corroboration is rejected" 1 "impossible combination" <<'EOF'
CLAIM: Vapor mode is stable in Vue 3.6
VERDICT: confirmed
FETCH: https://blog.example.com — retrieved 2026-08-12 — "Vapor is stable"
REASON: one blog says so
CORROBORATION: none found
COUNTER_EVIDENCE: none found
CONFIDENCE: Medium
EOF

check "confirmed without verbatim quote is rejected" 1 "verbatim quote" <<'EOF'
CLAIM: Fastify 4 support ended June 2025
VERDICT: confirmed
FETCH: https://fastify.dev — retrieved 2026-08-12 — the page said support ended
REASON: paraphrased from the page
CORROBORATION: https://eol.wiki/fastify/
COUNTER_EVIDENCE: none found
CONFIDENCE: High
EOF

check "confirmed without retrieval timestamp is rejected" 1 "retrieval timestamp" <<'EOF'
CLAIM: Express 4 EOL target is 2026-10-01
VERDICT: confirmed
FETCH: https://endoflife.date/express — "no sooner than October 1, 2026"
REASON: EOL page states the target
CORROBORATION: https://www.herodevs.com/blog-posts/express
COUNTER_EVIDENCE: none found
CONFIDENCE: High
EOF

check "refuted needs no corroboration" 0 "" <<'EOF'
CLAIM: Nuxt 5 is generally available
VERDICT: refuted
FETCH: https://github.com/nuxt/nuxt/releases — retrieved 2026-08-12 — "v4.5.2"
REASON: latest release is 4.5.2; no 5.x tag exists
CORROBORATION: none found
COUNTER_EVIDENCE: release page itself
CONFIDENCE: High
EOF

check "unverifiable with reason passes" 0 "" <<'EOF'
CLAIM: internal benchmark shows 3x
VERDICT: unverifiable-this-session (paywalled after one retry)
FETCH: paywalled after one retry
REASON: cannot read the source
CORROBORATION: none found
COUNTER_EVIDENCE: none found
CONFIDENCE: Low
EOF

check "invalid verdict value is rejected" 1 "invalid VERDICT" <<'EOF'
CLAIM: something
VERDICT: plausible
FETCH: https://example.com — retrieved now — "quote"
CORROBORATION: https://example.org
EOF

check "empty input exits 2" 2 "no CLAIM block" < /dev/null

check "two blocks, one bad, names block 2" 1 "block 2" <<'EOF'
CLAIM: good claim
VERDICT: refuted
FETCH: https://a.example — retrieved 2026-08-12 — "nope"
REASON: page contradicts
CORROBORATION: none found
CLAIM: bad claim
VERDICT: confirmed
FETCH: https://b.example — retrieved 2026-08-12 — "yes"
REASON: supported
CORROBORATION: n/a
EOF

echo "verdict-lint tests: $pass passed, $fail failed"
exit $((fail > 0))
