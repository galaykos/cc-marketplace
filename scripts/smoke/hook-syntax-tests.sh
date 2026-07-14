#!/usr/bin/env bash
# scripts/smoke/hook-syntax-tests.sh
#
# Runs `bash -n` (parse-only, no execution) over every shell script the repo
# ships — plugin hooks plus all repo scripts — so a syntax error can never reach
# a live hook or a CI gate unnoticed. Globs:
#   plugins/*/hooks/*.sh   scripts/*.sh   scripts/smoke/*.sh   scripts/lib/*.sh
# scripts/lib/*.sh is sourced by validate.sh / authoring-guard.sh and would
# escape a narrower glob, so it is checked explicitly. Exits non-zero if any
# script fails to parse.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT" || exit 2

rc=0
checked=0
for f in plugins/*/hooks/*.sh scripts/*.sh scripts/smoke/*.sh scripts/lib/*.sh; do
  [ -f "$f" ] || continue
  checked=$((checked + 1))
  if msg=$(bash -n "$f" 2>&1); then
    printf 'PASS  %s\n' "$f"
  else
    printf 'FAIL  %s\n      %s\n' "$f" "$msg"
    rc=1
  fi
done

if [ "$checked" -eq 0 ]; then
  printf 'hook-syntax-tests: no shell scripts matched the globs under %s\n' "$ROOT" >&2
  exit 2
fi

if [ "$rc" -eq 0 ]; then
  printf '\nAll %d shell scripts parsed cleanly (bash -n).\n' "$checked"
else
  printf '\nSome shell scripts FAILED bash -n.\n'
fi
exit $rc
