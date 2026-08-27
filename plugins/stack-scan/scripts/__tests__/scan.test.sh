#!/usr/bin/env bash
# Fixture tests for scan.sh — a synthetic project proves the table rows, the
# red flags, and the not-covered honesty line.
#
# WHY THE STUBBED node. The engines-floor branch (scan.sh: the `inst == v*` guard)
# only runs when `node -v` SUCCEEDS inside the fixture. Version managers that
# honour package.json engines — lerd, volta, fnm with auto-switch — exit 1 there
# instead, because the fixture asks for a node that is not installed:
#
#   $ cd <fixture>; node -v
#   error: Requested version v99.x.x is not currently installed   # rc=1
#
# `inst` then reads "not installed", the guard is false, and the assertion this
# test exists to make silently never runs. GitHub Actions' setup-node lays down a
# plain binary with no shim, so CI stayed green while the check was dead on every
# developer machine using a shim. The fixture now OWNS its runtime: a stub `node`
# on PATH makes both directions deterministic everywhere.
set -u
SCAN="$(cd "$(dirname "$0")/.." && pwd)/scan.sh"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# stub_node <version> — a `node` on PATH that reports exactly <version>, with no
# opinion about package.json. Echoed so the caller can prepend it to PATH.
stub_node() {
  local dir="$T/stub-$1"
  mkdir -p "$dir"
  printf '#!/bin/sh\necho %s\n' "$1" > "$dir/node"
  chmod +x "$dir/node"
  printf '%s' "$dir"
}

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
OUT=$(PATH="$(stub_node v18.0.0):$PATH" bash "$SCAN" "$T/a")
expect "node row"        "node runtime"
expect "engines floor"   "below the engines floor"
expect "floor names both" "node v18.0.0 is below the engines floor"
expect "multi-lock flag" "MULTIPLE js lockfiles"
expect "react row"       "| react | ^19.0.0 |"
expect "unpinned image"  "unpinned image"
expect "not-covered"     "go.mod present — ecosystem not covered"

# Fixture 1b: NEGATIVE CONTROL — same project, an installed node that SATISFIES
# the floor. Without this the suite cannot tell "the flag fires correctly" from
# "the flag fires always"; the bug this fixture set shipped with was the mirror
# case, a branch that never fired at all.
refute() { # refute <name> <grep>
  if grep -q "$2" <<<"$OUT"; then echo "FAIL $1: unexpected '$2'"; fail=$((fail+1));
  else pass=$((pass+1)); fi
}
OUT=$(PATH="$(stub_node v99.1.0):$PATH" bash "$SCAN" "$T/a")
expect "control: node row"    "| node runtime | >=99 | v99.1.0 |"
refute "control: no floor flag" "below the engines floor"
refute "control: no red flag for node" "node v99.1.0 is below"

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
