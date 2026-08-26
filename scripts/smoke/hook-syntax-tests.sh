#!/usr/bin/env bash
# scripts/smoke/hook-syntax-tests.sh
#
# Runs `bash -n` (parse-only, no execution) over every shell script the repo
# ships — plugin hooks plus all repo scripts — so a syntax error can never reach
# a live hook or a CI gate unnoticed. FILE SET: `git ls-files '*.sh'` — every
# tracked shell script, enumerated rather than globbed.
#
# WHY ENUMERATED. This read four globs until 2026-08-26
# (plugins/*/hooks/*.sh scripts/*.sh scripts/smoke/*.sh scripts/lib/*.sh) while
# its header claimed "every shell script the repo ships". That was 76 of 142
# tracked scripts; the 67 it missed included 15 awk users under
# plugins/*/scripts/. The gawk-ism check below was added to "close the class" of
# a silent BSD-awk bug — and could not fire on the largest population where the
# class recurs. A glob list must be re-widened every time a directory is added;
# `git ls-files` cannot fall out of date, which is the point.
# scripts/lib/*.sh is sourced by validate.sh / authoring-guard.sh and would
# escape a narrower glob, so it is checked explicitly. Exits non-zero if any
# script fails to parse.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT" || exit 2

rc=0
checked=0
for f in $(git ls-files '*.sh' 2>/dev/null || find plugins scripts -name '*.sh' -type f); do
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

# ---- gawk-only constructs -------------------------------------------------
# `bash -n` cannot see this class and neither can a reader who knows gawk: a gawk
# extension inside an awk program is silently IGNORED by the BSD awk that ships on
# darwin, so the script runs, exits 0, and enforces less than it says.
#
# Found the hard way on 2026-08-25: pc_false_standing used `BEGIN { IGNORECASE=1 }`,
# which made its matching case-SENSITIVE on this machine. Every test passed, because
# every test happened to use lowercase. CI runs ubuntu (gawk) and development runs
# darwin (BSD awk), so the two disagree about what the gate enforces.
#
# Deliberately narrow: constructs that fail SILENTLY. gensub/asort/strtonum error
# out loudly on BSD awk and are caught by any run, so they are not listed here —
# only the ones that quietly do nothing.
printf '\n== gawk-only constructs that fail silently on BSD awk\n'
gawkisms=0
for f in $(git ls-files '*.sh' 2>/dev/null || find plugins scripts -name '*.sh' -type f); do
  [ -f "$f" ] || continue
  # strip comment lines first: this file and plugin-checks.sh both DISCUSS
  # IGNORECASE in prose explaining why not to use it.
  if sed 's/#.*//' "$f" | grep -qE '\bIGNORECASE\b|\bPROCINFO\b|\bBEGINFILE\b|\bENDFILE\b'; then
    printf 'FAIL  %s uses a gawk-only construct that BSD awk ignores silently\n' "$f"
    sed 's/#.*//' "$f" | grep -nE '\bIGNORECASE\b|\bPROCINFO\b|\bBEGINFILE\b|\bENDFILE\b' | head -3
    gawkisms=1; rc=1
  fi
done
[ "$gawkisms" -eq 0 ] && printf 'PASS  no silent gawk-only constructs in %d scripts\n' "$checked"

if [ "$rc" -eq 0 ]; then
  printf '\nAll %d shell scripts parsed cleanly (bash -n) and use no silent gawk-isms.\n' "$checked"
else
  printf '\nSome shell scripts FAILED.\n'
fi
exit $rc
