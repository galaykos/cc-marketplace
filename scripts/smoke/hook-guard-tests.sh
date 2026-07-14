#!/usr/bin/env bash
# scripts/smoke/hook-guard-tests.sh
#
# Feeds the three guard-case stdin shapes to every plugins/*/hooks/remind.sh and asserts
# each stays SILENT and exits 0:
#   1. slash-command prompt  — a "/…" prompt is a slash command that manages its own flow
#   2. empty / missing prompt — nothing to react to
#   3. no jq on PATH          — fail-open: a broken/absent jq must never block or speak
# The no-jq case runs the hook with a PATH stripped of jq (a clean bin of coreutils
# symlinks) so it exercises genuine absence — matching both the legacy `|| exit 0` guard
# and the regenerated `command -v jq || exit 0` guard. Companion to (and does NOT touch)
# scripts/smoke/guard-tests.sh, which covers the authoring-guard.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${CHASSIS_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
BASH_BIN="$(command -v bash)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "${2:-}"; rc=1; }

# clean bin: coreutils the hooks may need, jq deliberately excluded
NOJQ="$WORK/nojq-bin"; mkdir -p "$NOJQ"
for u in cat grep sed awk tr head cut env sh expr dirname basename printf; do
  p="$(command -v "$u" 2>/dev/null)" && ln -s "$p" "$NOJQ/$u" 2>/dev/null
done
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  printf 'hook-guard-tests: could not build a jq-free PATH; aborting\n' >&2; exit 2
fi

assert_silent() { # desc  hook  json  [path-override]
  local desc="$1" hook="$2" json="$3" pth="${4:-}" out rc_
  if [ -n "$pth" ]; then
    out="$(printf '%s' "$json" | PATH="$pth" "$BASH_BIN" "$hook" 2>/dev/null)"; rc_=$?
  else
    out="$(printf '%s' "$json" | "$BASH_BIN" "$hook" 2>/dev/null)"; rc_=$?
  fi
  if [ "$rc_" -ne 0 ]; then fail "$desc" "exit $rc_ (want 0)"; return; fi
  if [ -n "$out" ]; then fail "$desc" "wanted silence, spoke: $out"; return; fi
  pass "$desc"
}

# a keyword-dense prompt: WOULD trigger a reminder if jq worked, so no-jq proves fail-open
LOUD='{"prompt":"adspower scrape build create api endpoint webhook fingerprint camoufox kameleo puppeteer playwright facebook"}'

found=0
for hook in "$ROOT"/plugins/*/hooks/remind.sh; do
  [ -f "$hook" ] || continue
  found=$((found+1))
  rel="${hook#$ROOT/}"
  assert_silent "$rel [slash]"          "$hook" '{"prompt":"/plan the work"}'
  assert_silent "$rel [empty]"          "$hook" '{"prompt":""}'
  assert_silent "$rel [missing-prompt]" "$hook" '{}'
  assert_silent "$rel [no-jq]"          "$hook" "$LOUD" "$NOJQ"
done

if [ "$found" -eq 0 ]; then
  printf 'hook-guard-tests: no plugins/*/hooks/remind.sh found under %s\n' "$ROOT" >&2
  exit 2
fi

if [ "$rc" -eq 0 ]; then
  printf '\nAll %d reminder hooks passed guard cases (slash / empty / no-jq).\n' "$found"
else
  printf '\nSome guard-case asserts FAILED.\n'
fi
exit $rc
