#!/usr/bin/env bash
# A guard: ALLOW the known-good value, DENY everything else. exit 0 = allow, 1 = deny.
#
# DEFECT (surfaced by negative-control): the paired Verify only ever exercises the
# ALLOW path (`guard.sh good` -> ALLOW). The deny decision lives BELOW the allow
# short-circuit, so disabling it (negative-control's --auto flips the `>=` guard,
# making the tool fail open) never changes the allow-path output. A verify with no
# teeth for the deny path therefore stays green against the disabled guard — vacuous.
set -euo pipefail
val="${1:-}"

case "$val" in
  good) echo "ALLOW"; exit 0 ;;
esac

# --- deny path (never exercised by the allow-only verify) ---
blocked=1
if (( blocked >= 1 )); then
  echo "DENY"; exit 1
fi
echo "ALLOW"; exit 0
