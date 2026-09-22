#!/usr/bin/env bash
# Drives hooks/unread-pick.sh: silent without decisions, one line with an unread pick,
# silent once consumed, silent past the decide phase, off-switch honoured.
set -euo pipefail
here="$(cd "$(dirname "$0")/../.." && pwd)"; hook="$here/hooks/unread-pick.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
payload() { printf '{"cwd":"%s","prompt":"x"}' "$tmp"; }
[ -z "$(payload | bash "$hook")" ] || { echo "FAIL: spoke with no decisions"; exit 1; }
mkdir -p "$tmp/.design-kit"
printf '{"ts":"t","board":"2026-09-22-deal.html","picked":2,"knobs":{},"text":{},"prompt":"p","consumed":false}\n' > "$tmp/.design-kit/decisions.jsonl"
out="$(payload | bash "$hook")"
case "$out" in "design-kit: 2026-09-22-deal.html has an unread pick — artboard 2."*) ;; *) echo "FAIL: line: $out"; exit 1 ;; esac
[ "$(printf '%s' "$out" | wc -l | tr -d ' ')" = 0 ] || { echo "FAIL: more than one line"; exit 1; }
[ -z "$(payload | CC_REMIND=off bash "$hook")" ] || { echo "FAIL: CC_REMIND=off ignored"; exit 1; }
mkdir -p "$tmp/.claude"; printf '{"phase":"build"}' > "$tmp/.claude/cc-phase.json"
[ -z "$(payload | bash "$hook")" ] || { echo "FAIL: spoke during build phase"; exit 1; }
printf '{"phase":"decide"}' > "$tmp/.claude/cc-phase.json"
[ -n "$(payload | bash "$hook")" ] || { echo "FAIL: silent during decide phase"; exit 1; }
printf '{"ts":"t","board":"2026-09-22-deal.html","picked":2,"knobs":{},"text":{},"prompt":"p","consumed":true}\n' > "$tmp/.design-kit/decisions.jsonl"
[ -z "$(payload | bash "$hook")" ] || { echo "FAIL: spoke after consume"; exit 1; }
echo "PASS unread-pick.test.sh"
