#!/usr/bin/env bash
# Fixture tests for scan.sh — a synthetic project proves the table rows, the
# red flags, and the not-covered honesty line.
set -u
SCAN="$(cd "$(dirname "$0")/.." && pwd)/scan.sh"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

expect() { # expect <name> <grep>
  if grep -q "$2" <<<"$OUT"; then pass=$((pass+1));
  else echo "FAIL $1: missing '$2'"; fail=$((fail+1)); fi
}

# Fixture 1: node project, two lockfiles, engines floor above any real node, go.mod.
mkdir -p "$T/a"
cat > "$T/a/package.json" <<'EOF'
{ "engines": { "node": ">=99" },
  "dependencies": { "react": "^19.0.0", "vite": "^8.0.0" } }
EOF
touch "$T/a/package-lock.json" "$T/a/yarn.lock" "$T/a/go.mod"
printf 'FROM node:latest\n' > "$T/a/Dockerfile"
OUT=$(bash "$SCAN" "$T/a")
expect "node row"        "node runtime"
expect "engines floor"   "below the engines floor"
expect "multi-lock flag" "MULTIPLE js lockfiles"
expect "react row"       "| react | ^19.0.0 |"
expect "unpinned image"  "unpinned image"
expect "not-covered"     "go.mod present — ecosystem not covered"

# Fixture 2: php project, no lock.
mkdir -p "$T/b"
cat > "$T/b/composer.json" <<'EOF'
{ "require": { "php": "^8.3", "laravel/framework": "^12.0" } }
EOF
OUT=$(bash "$SCAN" "$T/b")
expect "php row"       "php runtime"
expect "laravel row"   "laravel/framework"
expect "no-lock flag"  "NO composer.lock"

# Fixture 3: empty dir — still a report, exit 0, no flags beyond none-line.
mkdir -p "$T/c"
OUT=$(bash "$SCAN" "$T/c"); rc=$?
if [[ $rc -eq 0 ]]; then pass=$((pass+1)); else echo "FAIL empty rc=$rc"; fail=$((fail+1)); fi
expect "none line" "none detected by the mechanical pass"

echo "stack-scan tests: $pass passed, $fail failed"
exit $((fail > 0))
