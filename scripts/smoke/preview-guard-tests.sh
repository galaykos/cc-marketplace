#!/usr/bin/env bash
# Smoke: the Artifact preview-guard (taskmaster + ui-ux twins).
#
# Guards two things:
#   1. TWIN PARITY — the two copies must be identical save their single
#      `# TWIN:` pointer line (each names the other). The file contract says
#      "change one, change both"; nothing else enforces it, so this does.
#   2. TIER BEHAVIOR — each guard fires the exact decision + message per tier:
#        STRONG (a mockup basename)   -> ask, the mockup rule
#        WEAK   (any other .html)     -> ask, the remote-publish confirmation
#        NONE   (not .html)           -> silent (no output)
#
# bash 3.2 compatible. Accumulates failures, one exit at the end.
set -u
cd "$(dirname "$0")/../.." || exit 1

T=plugins/taskmaster/hooks/preview-guard.sh
U=plugins/ui-ux/hooks/preview-guard.sh
fail=0
note() { echo "FAIL: $1" >&2; fail=1; }

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not present"; exit 0; }
[ -f "$T" ] || { echo "FAIL: missing $T" >&2; exit 1; }
[ -f "$U" ] || { echo "FAIL: missing $U" >&2; exit 1; }

# A clean cwd with NO taskmaster-docs/mockups docroot anywhere above it, so a
# plain .html stays WEAK (a mockups docroot would promote it to STRONG).
WORK=$(mktemp -d) || exit 1
trap 'rm -rf "$WORK"' EXIT INT TERM HUP
mkdir -p "$WORK/scratchpad"

# (1) Twin parity — identical after dropping the single TWIN-pointer line.
if ! diff <(grep -v '^# TWIN:' "$T") <(grep -v '^# TWIN:' "$U") >/dev/null 2>&1; then
  note "twins diverge beyond the TWIN-pointer line (change one, change both)"
fi
grep -q '^# TWIN: plugins/ui-ux/' "$T"      || note "$T missing/incorrect TWIN pointer to ui-ux"
grep -q '^# TWIN: plugins/taskmaster/' "$U" || note "$U missing/incorrect TWIN pointer to taskmaster"

run() { # guard-file file_path cwd -> stdout
  printf '{"tool_input":{"file_path":"%s"},"cwd":"%s"}' "$2" "$3" | bash "$1"
}

for G in "$T" "$U"; do
  # STRONG — a per-purpose mockup basename (independent of docroot).
  out=$(run "$G" "$WORK/current.html" "$WORK")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "$G STRONG: expected ask"
  printf '%s' "$out" | grep -q 'mockup or theme preview'    || note "$G STRONG: wrong message"

  # WEAK — a plain report .html with no mockups docroot: the overstep shape.
  out=$(run "$G" "$WORK/scratchpad/saas-bets.html" "$WORK")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"'          || note "$G WEAK: expected ask (a note is ignorable)"
  printf '%s' "$out" | grep -q 'Keep this on localhost, not a remote host' || note "$G WEAK: wrong message"

  # NONE — not .html (a markdown report is not a mockup): silent.
  out=$(run "$G" "$WORK/report.md" "$WORK")
  [ -z "$out" ] || note "$G NONE: expected silence, got output"
done

if [ "$fail" -eq 0 ]; then echo "preview-guard smoke: PASS"; else echo "preview-guard smoke: FAIL"; fi
exit "$fail"
