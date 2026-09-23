#!/usr/bin/env bash
# Fixture tests for phase-sentinel.sh — the script writer of .claude/cc-phase.json
# (AR 11 of the 2026-09-22 specialist panel: four prose writers, no script writer).
#
# THE LOAD-BEARING CASE IS THE TYPO. Everything else here is bookkeeping; the reason
# this script exists at all is that a misspelled phase scores 0 in the reader's
# ordering table and every phase guard proceeds — which is byte-identical to having no
# sentinel, with nothing printed anywhere. So "write refuses an unknown phase" is the
# case that would make the script worth keeping if every other one were deleted.
#
# The second load-bearing case is the round trip through a REAL reader: this harness
# does not assert the JSON looks right, it drives taskmaster's own remind.sh (which
# carries the shared phase-guard block) against a sentinel this script wrote, and
# asserts the hook stands down. A writer whose output its reader cannot parse would
# pass every shape assertion and fail the only thing that matters.
set -u
here=$(cd "$(dirname "$0")" && pwd)
S="$here/../phase-sentinel.sh"
PLUGIN_ROOT=$(cd "$here/../.." && pwd)
[ -x "$S" ] || { printf 'FAIL: phase-sentinel.sh not executable at %s\n' "$S"; exit 1; }

pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s — %s\n' "$1" "$2"; fail=$((fail+1)); }

run() { # run <cwd> <args...> -> sets RC, OUT (stderr+stdout)
  local wd="$1"; shift
  OUT=$("$S" "$@" --cwd "$wd" 2>&1); RC=$?
}

P="$T/proj"; mkdir -p "$P"
SENT="$P/.claude/cc-phase.json"

# ---- 1. write: the file lands, with every key the readers use ----------------------
run "$P" write build --owner task-runner:run --session S1
[ "$RC" = 0 ] || bad "write build exits 0" "rc=$RC ($OUT)"
[ "$RC" = 0 ] && ok "write build exits 0"
if [ -f "$SENT" ]; then ok "write creates .claude/cc-phase.json"; else bad "write creates the sentinel" "absent"; fi

if command -v jq >/dev/null 2>&1; then
  for k in phase owner session_id started_at; do
    v=$(jq -r --arg k "$k" '.[$k] // empty' "$SENT" 2>/dev/null)
    if [ -n "$v" ]; then ok "sentinel carries .$k"; else bad "sentinel carries .$k" "missing or unparseable"; fi
  done
  [ "$(jq -r .phase "$SENT")" = build ] && ok "phase is what was asked for" || bad "phase" "got $(jq -r .phase "$SENT")"
else
  printf 'SKIP: jq absent — key assertions skipped\n'
fi

# ---- 2. THE TYPO CASE. An unknown phase is a refusal, never a written file ---------
rm -f "$SENT"
run "$P" write buidl --owner taskmaster:task --session S1
if [ "$RC" = 3 ] && [ ! -e "$SENT" ]; then ok "unknown phase -> usage error(3), nothing written"
else bad "unknown phase refused" "rc=$RC sentinel-exists=$([ -e "$SENT" ] && echo yes || echo no)"; fi
case "$OUT" in *"unknown phase"*) ok "the refusal names the problem" ;; *) bad "refusal message" "$OUT" ;; esac

# every phase in the arc is accepted, so the check cannot drift into rejecting a real one
for ph in understand shape decide plan build verify review ship; do
  run "$P" write "$ph" --owner x:y --session S1
  [ "$RC" = 0 ] || { bad "phase '$ph' accepted" "rc=$RC"; continue; }
done
ok "all eight arc phases accepted"

# ---- 3. --owner is required; a sentinel with no owner tells the capsule nothing ----
rm -f "$SENT"
run "$P" write build --session S1
if [ "$RC" = 3 ] && [ ! -e "$SENT" ]; then ok "missing --owner -> usage error(3), nothing written"
else bad "missing --owner refused" "rc=$RC"; fi

# ---- 4. --session omitted: writes anyway, but SAYS what was given up ---------------
run "$P" write build --owner task-runner:run
[ "$RC" = 0 ] && [ -f "$SENT" ] && ok "no --session still writes" || bad "no --session writes" "rc=$RC"
case "$OUT" in *"every session"*) ok "omitting --session warns about the cost" ;; *) bad "session warning" "$OUT" ;; esac

# ---- 5. clear removes it, and clearing nothing is success not an error -------------
run "$P" clear
[ "$RC" = 0 ] && [ ! -e "$SENT" ] && ok "clear removes the sentinel" || bad "clear" "rc=$RC"
run "$P" clear
[ "$RC" = 0 ] && ok "clear on an absent sentinel is still success" || bad "idempotent clear" "rc=$RC"

# ---- 6. a cwd that is not a directory is refused, never created --------------------
run "$T/does-not-exist" write build --owner a:b
[ "$RC" = 3 ] && [ ! -e "$T/does-not-exist" ] && ok "non-directory --cwd refused, nothing created" \
  || bad "non-directory --cwd" "rc=$RC"

# ---- 7. usage surface: no args prints usage and exits 3 ---------------------------
OUT=$("$S" 2>&1); RC=$?
[ "$RC" = 3 ] && ok "no subcommand -> usage(3)" || bad "no subcommand" "rc=$RC"
OUT=$("$S" frobnicate 2>&1); RC=$?
[ "$RC" = 3 ] && ok "unknown subcommand -> usage(3)" || bad "unknown subcommand" "rc=$RC"

# ---- 8. ROUND TRIP through a real reader. taskmaster:remind owns phase `shape`
# (lane.tsv), so a sentinel at `build` must silence it and one at `understand` must not.
H="$PLUGIN_ROOT/hooks/remind.sh"
if command -v jq >/dev/null 2>&1 && [ -f "$H" ]; then
  fire() {
    printf '{"hook_event_name":"UserPromptSubmit","prompt":"build a login page","cwd":"%s","session_id":"S1"}' "$P" \
      | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$H" 2>/dev/null
  }
  "$S" clear --cwd "$P" >/dev/null 2>&1
  [ -n "$(fire)" ] && ok "reader speaks with no sentinel (the case the guard must not break)" \
    || bad "reader speaks with no sentinel" "silent — fixture or trigger drifted, later cases are vacuous"
  "$S" write build --owner task-runner:run --session S1 --cwd "$P" >/dev/null 2>&1
  [ -z "$(fire)" ] && ok "a script-written 'build' sentinel makes the shape-phase reader stand down" \
    || bad "reader stands down at a later phase" "it spoke"
  "$S" write understand --owner taskmaster:task --session S1 --cwd "$P" >/dev/null 2>&1
  [ -n "$(fire)" ] && ok "an 'understand' sentinel leaves the shape-phase reader eligible" \
    || bad "reader eligible at an earlier phase" "it stood down"
  "$S" clear --cwd "$P" >/dev/null 2>&1
else
  printf 'SKIP: jq or remind.sh absent — reader round trip skipped\n'
fi

printf -- '---- phase-sentinel: %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
