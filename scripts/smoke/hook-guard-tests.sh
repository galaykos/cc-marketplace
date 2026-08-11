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
#
# Second section: the three BOOST hooks (taskmaster ultra.sh, orchestration
# ultra-assess.sh, craft-layer ultra-craft.sh). Same guard question, opposite default —
# a boost hook must SPEAK on a real invocation and stay silent on a pasted banner. The
# regression it pins: the self-echo guard was `ultra-?[a-z]+ +active`, which also matched
# Claude Code's own `ultracode` / `ultrathink` vocabulary, so a prompt opening
# "ultracode active — now ultra-task X" silently suppressed the boost.
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
# Misfire regression fixtures (live transcripts, 2026-07-27): keyword-dense text that
# is NOT a request for the work — every reminder hook must stay silent on each.
NOTIF='{"prompt":"[SYSTEM NOTIFICATION - NOT USER INPUT] task-notification: agent finished, mentions sdk endpoint webhook oauth build create refactor migrate still failing"}'
META='{"prompt":"we should delete the puppeteer plugin and fix the keyword trigger of the reminder hook, it fires on oauth session cache endpoint refactor still failing mentions"}'
QUOTE='{"prompt":"UserPromptSubmit hook success: build-vs-buy: weigh take vs wrap vs write — why did that fire on my oauth session endpoint refactor prompt?"}'

found=0
for hook in "$ROOT"/plugins/*/hooks/remind.sh; do
  [ -f "$hook" ] || continue
  found=$((found+1))
  rel="${hook#$ROOT/}"
  assert_silent "$rel [slash]"          "$hook" '{"prompt":"/plan the work"}'
  assert_silent "$rel [empty]"          "$hook" '{"prompt":""}'
  assert_silent "$rel [missing-prompt]" "$hook" '{}'
  assert_silent "$rel [no-jq]"          "$hook" "$LOUD" "$NOJQ"
  assert_silent "$rel [notification-paste]" "$hook" "$NOTIF"
  assert_silent "$rel [meta-request]"       "$hook" "$META"
  assert_silent "$rel [quoted-hook-output]" "$hook" "$QUOTE"
done

# ---- per-prompt budget: advisory hooks share a lottery; taskmaster is a
# PRIORITY DIRECTIVE (budgetExempt) — it always speaks AND claims the marker so
# advisory siblings yield to it, in either scheduling order. Sandboxed TMPDIR
# so markers never leak between runs.
AD="$ROOT/plugins/api-docs-first/hooks/remind.sh"
TM="$ROOT/plugins/taskmaster/hooks/remind.sh"
if [ -f "$AD" ] && [ -f "$TM" ]; then
  BUDGET_TMP="$WORK/budget-tmp"; mkdir -p "$BUDGET_TMP"
  FIRE='{"prompt":"build a stripe webhook endpoint integration for our billing service"}'
  out1="$(printf '%s' "$FIRE" | TMPDIR="$BUDGET_TMP" "$BASH_BIN" "$AD" 2>/dev/null)"
  out2="$(printf '%s' "$FIRE" | TMPDIR="$BUDGET_TMP" "$BASH_BIN" "$TM" 2>/dev/null)"
  if [ -n "$out1" ]; then pass "budget: advisory hook speaks when first"; else fail "budget: advisory hook speaks when first" "api-docs-first stayed silent on a real integration prompt"; fi
  if [ -n "$out2" ]; then pass "budget: taskmaster directive exempt from the lottery"; else fail "budget: taskmaster directive exempt from the lottery" "taskmaster yielded to a claimed marker despite budgetExempt"; fi
  # reversed order: taskmaster first claims the marker, advisory sibling yields
  BUDGET_TMP2="$WORK/budget-tmp2"; mkdir -p "$BUDGET_TMP2"
  out3="$(printf '%s' "$FIRE" | TMPDIR="$BUDGET_TMP2" "$BASH_BIN" "$TM" 2>/dev/null)"
  out4="$(printf '%s' "$FIRE" | TMPDIR="$BUDGET_TMP2" "$BASH_BIN" "$AD" 2>/dev/null)"
  if [ -n "$out3" ]; then pass "budget: taskmaster fires alone in a fresh sandbox"; else fail "budget: taskmaster fires alone in a fresh sandbox" "taskmaster silent with no marker present"; fi
  if [ -z "$out4" ]; then pass "budget: advisory sibling yields to the directive's marker"; else fail "budget: advisory sibling yields to the directive's marker" "api-docs-first spoke despite taskmaster's claimed marker: $out4"; fi
fi

if [ "$found" -eq 0 ]; then
  printf 'hook-guard-tests: no plugins/*/hooks/remind.sh found under %s\n' "$ROOT" >&2
  exit 2
fi

# ---- boost hooks: fire on an invocation, stay silent on a pasted banner ---------
# One row per case: hook path | want (speak|silent) | prompt.
assert_boost() { # desc  hook  want  prompt
  local desc="$1" hook="$2" want="$3" prompt="$4" out rc_
  out="$(printf '%s' "$prompt" | jq -Rs '{prompt:.}' | "$BASH_BIN" "$hook" 2>/dev/null)"; rc_=$?
  if [ "$rc_" -ne 0 ]; then fail "$desc" "exit $rc_ (want 0 — boost hooks fail open)"; return; fi
  case "$want" in
    speak)  [ -n "$out" ] && pass "$desc" || fail "$desc" "wanted a directive, got silence" ;;
    silent) [ -z "$out" ] && pass "$desc" || fail "$desc" "wanted silence, spoke: ${out:0:60}…" ;;
  esac
}

boost_found=0
for spec in \
  "taskmaster/hooks/ultra.sh|ultra-task|ULTRA-TASK ACTIVE" \
  "taskmaster/hooks/ultra.sh|ultra-goal|ULTRA-GOAL ACTIVE" \
  "orchestration/hooks/ultra-assess.sh|ultra-assess|ULTRA-ASSESS ACTIVE" \
  "craft-layer/hooks/ultra-craft.sh|ultra-craft|ULTRA-CRAFT ACTIVE"
do
  rel="${spec%%|*}"; rest="${spec#*|}"; tok="${rest%%|*}"; banner="${rest#*|}"
  hook="$ROOT/plugins/$rel"
  [ -f "$hook" ] || continue
  boost_found=$((boost_found+1))
  assert_boost "$rel [$tok invocation]"        "$hook" speak  "$tok build the thing"
  # REGRESSION: harness vocabulary in the same prompt must not eat the boost.
  assert_boost "$rel [$tok after ultracode]"   "$hook" speak  "ultracode active — now $tok build the thing"
  assert_boost "$rel [$tok after ultrathink]"  "$hook" speak  "ultrathink active, $tok build the thing"
  # Still refuses its own banner echoed back, and a negated mention.
  assert_boost "$rel [own banner pasted]"      "$hook" silent "$banner (model=auto, effort=xhigh) — $tok"
  assert_boost "$rel [negated]"                "$hook" silent "do not use $tok for this one"
  assert_boost "$rel [slash prompt]"           "$hook" silent "/taskmaster:task $tok build the thing"
  assert_boost "$rel [harness word alone]"     "$hook" silent "ultracode ultrathink refactor the auth module"
done

if [ "$boost_found" -eq 0 ]; then
  printf 'hook-guard-tests: no boost hooks found under %s/plugins\n' "$ROOT" >&2
  exit 2
fi

if [ "$rc" -eq 0 ]; then
  printf '\nAll %d reminder hooks passed guard cases (slash / empty / no-jq); %d boost hooks passed trigger cases.\n' "$found" "$boost_found"
else
  printf '\nSome guard-case asserts FAILED.\n'
fi
exit $rc
