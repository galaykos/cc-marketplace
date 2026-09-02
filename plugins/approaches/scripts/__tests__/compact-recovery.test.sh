#!/usr/bin/env bash
# Fixtures for plugins/approaches/hooks/compact-recovery.sh.
#
# WHY THIS EXISTS. The hook's whole claim is a cost/benefit trade: it recovers a
# decision the model lost to compaction, and it costs NOTHING the rest of the time.
# Both halves are silently breakable. If the `compact` source check regressed, the
# hook would fire on every startup and resume — a permanent tax on every session in
# every project, and every gate in this repo would stay green while it happened,
# because `context-budget.sh` probes SessionStart with source=startup and would keep
# reading zero. So the load-bearing assertion is NOT "it speaks on compact"; it is
# "it is SILENT on the four sources that are not compaction".
#
# The second load-bearing assertion is that it never invents a decision. Announcing
# a deliberation that did not happen is worse than saying nothing: it would tell the
# model to skip a deliberation it actually owes.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
H=plugins/approaches/hooks/compact-recovery.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

mkdir -p "$FX/proj/.claude/approaches"
printf '{"task":"widget-rewrite","by":"approach-deliberation","at":"2026-08-31T00:00:00Z"}\n' \
  > "$FX/proj/.claude/approaches/deliberated.json"

fire() { # source cwd -> stdout
  jq -nc --arg s "$1" --arg c "$2" \
    '{session_id:"s1",transcript_path:"/t/x.jsonl",cwd:$c,hook_event_name:"SessionStart",source:$s}' \
  | bash "$H" 2>/dev/null
}

# --- 1. SILENT on every non-compaction source (the cost claim) --------------------
for src in startup resume clear fork; do
  out=$(fire "$src" "$FX/proj")
  if [ -z "$out" ]; then echo "PASS: silent on source=$src"
  else echo "FAIL: spoke on source=$src ($out)"; rc=1; fi
done

# --- 2. speaks on compaction (the benefit claim) ----------------------------------
out=$(fire compact "$FX/proj")
if [ -n "$out" ]; then echo "PASS: fires on source=compact"
else echo "FAIL: silent on source=compact"; rc=1; fi

# --- 3. carries the marker's task AND the instruction, not just a pointer ---------
for want in "widget-rewrite" "already settled" "deliberated.json"; do
  case "$out" in
    *"$want"*) echo "PASS: message carries '$want'" ;;
    *) echo "FAIL: message missing '$want'"; rc=1 ;;
  esac
done

# --- 4. names the escape hatch, so a stale marker cannot trap a NEW task ----------
case "$out" in
  *DIFFERENT*) echo "PASS: states the marker may not apply to the task in hand" ;;
  *) echo "FAIL: no escape hatch for a stale marker"; rc=1 ;;
esac

# --- 5. never invents a decision when no marker exists ----------------------------
mkdir -p "$FX/bare/.claude"
out=$(fire compact "$FX/bare")
if [ -z "$out" ]; then echo "PASS: silent when no deliberation marker exists"
else echo "FAIL: announced a decision that never happened ($out)"; rc=1; fi

# --- 6. fail-open on garbage: never wedge a session start -------------------------
out=$(printf 'not json' | bash "$H" 2>&1); s=$?
if [ $s -eq 0 ] && [ -z "$out" ]; then echo "PASS: fail-open on malformed input"
else echo "FAIL: exit=$s output='$out'"; rc=1; fi

out=$(fire compact "/nonexistent/path/xyz"); s=$?
if [ $s -eq 0 ] && [ -z "$out" ]; then echo "PASS: fail-open on a cwd that does not exist"
else echo "FAIL: exit=$s output='$out'"; rc=1; fi

exit $rc
