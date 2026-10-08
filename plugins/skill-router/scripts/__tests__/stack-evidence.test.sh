#!/usr/bin/env bash
# stack-evidence.test.sh — runs hooks/stack-evidence.sh, which the listing mod (hooks/listing.ts) calls, against the real
#   hooks/prime.sh on scratch directories: every sr_repo_skills row as a D line, the rows whose evidence holds as E lines,
#   exit 0 whatever the last row tested, and exit 3 for a prime.sh with no sr_repo_skills. The mod's own tests stub this run.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
H="$ROOT/plugins/skill-router/hooks"
[ -f "$H/stack-evidence.sh" ] || { echo "FAIL: $H/stack-evidence.sh not found"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
eq() { # eq <label> <got> <want>
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — want '$3', got '${2:-<empty>}'"; rc=1; fi
}
run() { bash "$H/stack-evidence.sh" "$@"; }

mkdir -p "$TMP/empty" "$TMP/laravel"
printf '{"require":{"laravel/framework":"^12.0"}}\n' > "$TMP/laravel/composer.json"

out="$(run "$H/prime.sh" "$TMP/empty")"; status=$?
eq "empty repo exits 0" "$status" "0"
eq "every row is listed as a D line" "$(printf '%s\n' "$out" | grep -c '^D laravel:laravel-best-practices$')" "1"
eq "no stack row holds in an empty repo" "$(printf '%s\n' "$out" | grep -c '^E laravel:laravel-best-practices$')" "0"

out="$(run "$H/prime.sh" "$TMP/laravel")"; status=$?
eq "laravel repo exits 0" "$status" "0"
eq "a laravel/framework requirement holds the laravel row" "$(printf '%s\n' "$out" | grep -c '^E laravel:laravel-best-practices$')" "1"

cat > "$TMP/last-row-fails.sh" <<'SH'
sr_repo_skills() { SR_ROOT="$1"; [ -f "$SR_ROOT/nope" ] && add laravel-best-practices laravel; }
SH
run "$TMP/last-row-fails.sh" "$TMP/empty" >/dev/null; eq "a last row whose test fails still exits 0" "$?" "0"

printf 'true\n' > "$TMP/no-function.sh"
run "$TMP/no-function.sh" "$TMP/empty" >/dev/null; eq "a prime.sh without sr_repo_skills exits 3" "$?" "3"

exit $rc
