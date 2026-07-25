#!/usr/bin/env bash
# done-gate — a Stop hook that refuses a "done" claim while the repo gates fail.
#
# WHY: CLAUDE.md is advisory. Across a long session an agent reliably verifies
# the axes it was last burned on and quietly skips the rest, then reports
# completion. The four scripts below are this repo's actual definition of "not
# broken"; this hook makes claiming done without them impossible rather than
# merely discouraged.
#
# NARROW BY DESIGN — it stays silent unless BOTH hold:
#   1. the turn actually claims completion, and
#   2. plugin files changed in the working tree, and
#   3. a gate genuinely fails.
# Conversational turns, research turns, and read-only turns never trigger it.
#
# DISABLE: remove the Stop entry from .claude/settings.json, or
#          export CRAFT_DONE_GATE=off

set -uo pipefail
[ "${CRAFT_DONE_GATE:-on}" = "off" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

payload=$(cat 2>/dev/null || true)

# Never re-enter: if this hook already blocked once this turn, let it through so
# a genuine disagreement cannot become a loop.
if printf '%s' "$payload" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# 1. Does the turn claim completion?
claims_done=$(printf '%s' "$payload" | tr '[:upper:]' '[:lower:]' | grep -cE \
  'all (four )?gates green|gates? (are )?green|loop [0-9]+ — done|work is (now )?complete|everything (is )?done|ready to (commit|ship|merge)')
[ "$claims_done" -eq 0 ] && exit 0

# 2. Did plugin files actually change? Docs-only and demo-only turns are exempt.
if git diff --quiet -- plugins 2>/dev/null && git diff --cached --quiet -- plugins 2>/dev/null; then
  exit 0
fi

# 3. Run the gates.
fails=""
run() { bash "scripts/$1" >/dev/null 2>&1 || fails="$fails $1"; }
run validate.sh
run context-budget.sh
bash scripts/generate.sh --check   >/dev/null 2>&1 || fails="$fails generate.sh --check"
bash scripts/check-version-bumps.sh master >/dev/null 2>&1 || fails="$fails check-version-bumps.sh"

[ -z "$fails" ] && exit 0

cat >&2 <<EOF
{"decision":"block","reason":"Completion claimed while repo gates fail:$fails. Fix these and re-run all four (validate.sh, check-version-bumps.sh master, context-budget.sh, generate.sh --check) before reporting done. If the failure is expected and accepted, say so explicitly instead of reporting a clean result."}
EOF
exit 2
