#!/usr/bin/env bash
# Smoke: the Artifact preview-guard (taskmaster + ui-ux twins).
#
# Guards two things:
#   1. TWIN PARITY — the two copies must be identical save their single
#      `# TWIN:` pointer line (each names the other). The file contract says
#      "change one, change both"; nothing else enforces it, so this does.
#   2. TIER BEHAVIOR — each guard fires the exact decision + message per tier:
#        STRONG (a mockup basename)   -> ask, the mockup rule, EVERY time
#        WEAK   (any other .html)     -> ask, the remote-publish confirmation,
#                                        ONCE PER SESSION (unbounded when the
#                                        input carries no session_id)
#        NONE   (not .html)           -> silent (no output)
#      The weak bound is the anti-noise contract: every Artifact .html is a
#      remote publish, so without it the tier asks forever on a convention.
#      Asserted here because nothing else can tell a quiet guard from a
#      wrongly-silenced one.
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

# TMPDIR is redirected into $WORK so the session markers the weak bound writes
# land in the trap-cleaned dir — and so a developer's live session markers can
# neither silence a case here nor be clobbered by one.
run() { # guard-file file_path cwd [session_id] -> stdout
  if [ -n "${4:-}" ]; then
    printf '{"tool_input":{"file_path":"%s"},"cwd":"%s","session_id":"%s"}' "$2" "$3" "$4"
  else
    printf '{"tool_input":{"file_path":"%s"},"cwd":"%s"}' "$2" "$3"
  fi | TMPDIR="$WORK" bash "$1"
}

for G in "$T" "$U"; do
  # Distinct per-guard session ids: the twins share a marker by design (see the
  # twin-dedupe case below), so reusing one id here would silence the second.
  gh=$(printf '%s' "$G" | cksum | cut -d' ' -f1)

  # STRONG — a per-purpose mockup basename (independent of docroot).
  out=$(run "$G" "$WORK/current.html" "$WORK")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "$G STRONG: expected ask"
  printf '%s' "$out" | grep -q 'mockup or theme preview'    || note "$G STRONG: wrong message"

  # WEAK — a plain report .html with no mockups docroot: the overstep shape.
  out=$(run "$G" "$WORK/scratchpad/saas-bets.html" "$WORK")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"'          || note "$G WEAK: expected ask (a note is ignorable)"
  printf '%s' "$out" | grep -q 'Keep this on localhost, not a remote host' || note "$G WEAK: wrong message"

  # WEAK with no session_id stays unbounded — the bound cannot be recorded, and
  # an ask that cannot wedge a session fails toward the question.
  out=$(run "$G" "$WORK/scratchpad/saas-bets.html" "$WORK")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "$G WEAK unbounded fallback: expected ask again with no session_id"

  # WEAK is bounded once per SESSION, not per page: a second, different .html
  # in the same session is silent.
  out=$(run "$G" "$WORK/scratchpad/one.html" "$WORK" "weak-$gh")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "$G WEAK bound: first plain .html of a session must ask"
  out=$(run "$G" "$WORK/scratchpad/two.html" "$WORK" "weak-$gh")
  [ -z "$out" ] || note "$G WEAK bound: second plain .html of the session must be silent"

  # STRONG is NOT bounded — blast radius, not convention: it asks every time,
  # and it must not consume the session's one weak ask.
  out=$(run "$G" "$WORK/current.html" "$WORK" "strong-$gh")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "$G STRONG: expected ask (1st in session)"
  out=$(run "$G" "$WORK/theme.html" "$WORK" "strong-$gh")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "$G STRONG: must stay unbounded within a session"
  out=$(run "$G" "$WORK/scratchpad/after-strong.html" "$WORK" "strong-$gh")
  printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "$G STRONG must not consume the weak bound"

  # NONE — not .html (a markdown report is not a mockup): silent.
  out=$(run "$G" "$WORK/report.md" "$WORK")
  [ -z "$out" ] || note "$G NONE: expected silence, got output"
done

# (3) Twin dedupe — both copies installed, same session, same page: the shared
# marker leaves exactly one asker instead of two identical lines in one prompt.
out=$(run "$T" "$WORK/scratchpad/dup.html" "$WORK" "twin-dedupe")
printf '%s' "$out" | grep -q '"permissionDecision":"ask"' || note "twin dedupe: the first copy to fire must ask"
out=$(run "$U" "$WORK/scratchpad/dup.html" "$WORK" "twin-dedupe")
[ -z "$out" ] || note "twin dedupe: the second copy must be silent on the same session"

if [ "$fail" -eq 0 ]; then echo "preview-guard smoke: PASS"; else echo "preview-guard smoke: FAIL"; fi
exit "$fail"
