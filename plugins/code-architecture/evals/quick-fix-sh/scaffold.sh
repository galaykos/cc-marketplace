#!/bin/bash
# scaffold.sh — writes, in the case's sandbox cwd, a Bash library whose semver_gt compares versions as text, so two existing checks fail,
#   and commits it so the run's whole diff is `git diff`. Writes only the files below.
set -e
mkdir -p lib tests
cat > Makefile <<'MK'
test:
	bash tests/run.sh
MK
cat > lib/semver.sh <<'SH'
# semver_valid V — succeeds when V is MAJOR.MINOR.PATCH
semver_valid() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# semver_gt A B — succeeds when version A is newer than version B
semver_gt() {
  local a="$1" b="$2"
  [[ "$a" != "$b" ]] && [[ "$(printf '%s\n%s\n' "$a" "$b" | sort | tail -n 1)" == "$a" ]]
}
SH
cat > tests/run.sh <<'SH'
#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
. lib/semver.sh

failed=0
ok() { echo "ok - $1"; }
not_ok() { echo "not ok - $1"; failed=$((failed + 1)); }
expect_newer() { if semver_gt "$1" "$2"; then ok "$1 is newer than $2"; else not_ok "$1 is newer than $2"; fi; }
expect_not_newer() { if semver_gt "$1" "$2"; then not_ok "$1 is not newer than $2"; else ok "$1 is not newer than $2"; fi; }

expect_newer 2.0.0 1.9.9
expect_newer 1.2.4 1.2.3
expect_newer 1.10.0 1.9.0
expect_not_newer 1.9.0 1.10.0
expect_not_newer 1.2.3 1.2.3
if semver_valid 1.2.3 && ! semver_valid 1.2; then ok "validates MAJOR.MINOR.PATCH"; else not_ok "validates MAJOR.MINOR.PATCH"; fi

echo "$failed failed"
[ "$failed" -eq 0 ]
SH
chmod +x tests/run.sh
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.invalid commit -qm 'semver helpers'
