#!/usr/bin/env bash
# done-gate — a Stop hook that refuses to let a turn end quietly on a red gate.
#
# WHY: CLAUDE.md is advisory. Across a long session an agent reliably verifies
# the axes it was last burned on and quietly skips the rest. The gates below are
# the four cheapest of CI's 18 blocking steps — passing them is necessary, not
# sufficient (see CLAUDE.md, "Every enforcement surface, by tier").
#
# TRIGGER — all THREE must hold:
#   1. plugin files changed in the working tree or index, and
#   2. the turn did NOT acknowledge a failing/in-progress state, and
#   3. a gate genuinely fails.
#
# The original version asked "did the turn claim completion?" and matched a
# completion-phrasing regex. That penalised clear reporting and was evaded by
# saying nothing: end the turn without the word "done" and a red gate shipped
# silently. The test is inverted — saying "validate.sh is failing", "still in
# progress", "halting with evidence", "blocked on X" passes; ending on a red gate
# having said none of it does not.
#
# The prose comes from the TRANSCRIPT, not the payload. A Stop payload carries
# only session_id / transcript_path / cwd / hook_event_name / stop_hook_active —
# no assistant text. Grepping the payload would make the escape unreachable and
# every dirty+red stop an unfixable block.
#
# LIMITATION (honest scope). This converts "stop silently while a gate is red"
# into "stop having said so, or be blocked". Residuals, all accepted:
#   - It does not prove the acknowledgment is truthful; prose mentioning failure
#     for another reason satisfies the escape.
#   - It cannot tell a mid-work pause from a final claim. A Stop hook sees one
#     turn, not intent; the acknowledgment escape is what keeps ordinary work
#     unblocked, and an honest turn always carries it.
#   - The trigger reads the working tree and index; only the version-bump gate
#     consults committed history.
#   - It fires on "plugins are dirty", not "this turn dirtied plugins", so the
#     first stop in an already-dirty session is judged even if the turn was
#     read-only. The state marker below means it says so once, not repeatedly.
#
# FAIL-OPEN on every missing tool or unreadable input, matching the sibling hooks
# (task-runner/hooks/completion-gate.sh, hindsight/hooks/collect.sh).
#
# A Stop hook can reach the model two ways: stdout {"decision":"block",…} with
# exit 0, or exit 2 with the reason on stderr. This uses exit 2. Exit 0 with no
# JSON prints into a turn that has already ended and cannot prevent anything.
#
# DISABLE: remove the Stop entry from .claude/settings.json, or
#          export CRAFT_DONE_GATE=off

set -uo pipefail
[ "${CRAFT_DONE_GATE:-on}" = "off" ] && exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

payload=$(cat 2>/dev/null || true)

# Never re-enter within a turn.
if printf '%s' "$payload" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

# 1. STATE (cheap): did plugin files change? Docs-only, research and read-only
# sessions never reach the gates.
if git diff --quiet -- plugins 2>/dev/null && git diff --cached --quiet -- plugins 2>/dev/null; then
  exit 0
fi

# 2. ACKNOWLEDGMENT (cheap, and evaluated BEFORE the gates so an honest turn
# never pays ~20s of validate.sh + sandboxed SessionStart hooks).
# Whole-word matching via grep -w: BSD grep has no \b, and an unanchored `red`
# matches the tail of required/registered/triggered/covered — 1390 occurrences
# under plugins/ in this repo, which would reopen the evasion in new spelling.
ACK='fail|fails|failing|failed|failure|not green|red gate|in progress|still working|wip|not done|incomplete|halt|halting|halted|blocked|parked|known issue|cannot verify'
tp=$(printf '%s' "$payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -n "$tp" ] && [ -r "$tp" ] && command -v jq >/dev/null 2>&1; then
  said=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' \
           "$tp" 2>/dev/null | tail -40)
  # Unreadable/empty transcript → fail open (treat as acknowledged).
  [ -z "$said" ] && exit 0
  printf '%s' "$said" | grep -qiwE "$ACK" && exit 0
else
  exit 0
fi

# 3. GATES (expensive — only reached by a silent turn on dirty plugins).
fails=""
# Cheapest first, so a common failure is named without paying for the rest.
# NOTE: generate.sh is invoked with --check ONLY. Running it bare would REWRITE
# every chassis-generated file as a side effect of a Stop hook.
gate() { # $1 label  $2.. command
  local label="$1"; shift
  "$@" >/dev/null 2>&1 || fails="${fails:+$fails, }$label"
}
gate "generate.sh --check" bash scripts/generate.sh --check
gate "context-budget.sh"   bash scripts/context-budget.sh
gate "validate.sh"         bash scripts/validate.sh

# check-version-bumps.sh reads COMMITTED history while this hook fires on an
# UNCOMMITTED tree — different questions. Run it only when there IS committed
# history to judge, against the same base ref that script would pick itself;
# otherwise it reports OK regardless and adds a gate that cannot report.
base=""
if   git rev-parse --verify -q origin/master >/dev/null 2>&1; then base=origin/master
elif git rev-parse --verify -q master        >/dev/null 2>&1; then base=master
fi
ran_bumps=0
if [ -n "$base" ] && ! git diff --quiet "$base"...HEAD -- plugins 2>/dev/null; then
  ran_bumps=1
  bash scripts/check-version-bumps.sh "$base" >/dev/null 2>&1 \
    || fails="${fails:+$fails, }check-version-bumps.sh $base"
fi

[ -z "$fails" ] && exit 0

# 4. LOOP GUARD. stop_hook_active is not trusted alone — the sibling Stop hook
# refuses to assume it too. The old trigger was prose the next turn could simply
# not repeat; this one is repo state a mid-work turn cannot clear, so an unset
# flag would mean an unbreakable stop-loop. Block once per distinct state.
marker=".claude/done-gate-last"
state=$(printf '%s|%s' "$(git status --porcelain -- plugins 2>/dev/null)" "$fails" \
        | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || echo "$fails"))
if [ -r "$marker" ] && [ "$(cat "$marker" 2>/dev/null)" = "$state" ]; then
  exit 0
fi
mkdir -p .claude 2>/dev/null && printf '%s' "$state" > "$marker" 2>/dev/null

remedy="validate.sh, context-budget.sh, generate.sh --check"
[ "$ran_bumps" -eq 1 ] && remedy="$remedy, check-version-bumps.sh $base"

cat >&2 <<EOF
{"decision":"block","reason":"This turn is ending with plugin changes in the working tree and failing gates: $fails — and said nothing about it. Either fix them ($remedy), or state plainly what is failing and why that is acceptable right now. Silence on a red gate is the one thing this hook exists to stop."}
EOF
exit 2
