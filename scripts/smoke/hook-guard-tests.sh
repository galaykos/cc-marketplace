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

# ---- MONOTONIC PRECEDENCE (spec §4.4, card C5) -------------------------------
# These assertions REPLACE the old per-prompt-budget block, which asserted that the
# same prompt produced DIFFERENT output depending on invocation order and recorded
# both as PASS. That was the only assertion in this repo certifying nondeterminism:
# whichever hook the scheduler happened to run first won, and the hooks' own comments
# admitted it ("Which one wins is scheduling order").
#
# What is asserted now: among hooks eligible THIS TURN, the best rank speaks in BOTH
# orders, and a worse-ranked sibling yields when the better one claimed first. What is
# deliberately NOT asserted: exactly one line. A worse-ranked hook that reads before
# its better-ranked peer claims will also print — bounded at one line per eligible
# hook, stated in the template header. Asserting single-voice would require a settle
# window and latency on every prompt.
#
# Ranks are trigger specificity: approaches 30 (build-vs-buy on a solved capability)
# outranks taskmaster 90 (clarify, which matches nearly every work-shaped prompt).
# This inverts the retired budgetExempt privilege on purpose.
AD="$ROOT/plugins/api-docs-first/hooks/remind.sh"
TM="$ROOT/plugins/taskmaster/hooks/remind.sh"
AP="$ROOT/plugins/approaches/hooks/remind.sh"
if [ -f "$TM" ] && [ -f "$AP" ]; then
  PR='implement a rate limiter for our billing api'
  PJ="$WORK/prec"; mkdir -p "$PJ"
  rk_fire() { printf '{"prompt":"%s","session_id":"prec-1","cwd":"%s"}' "$PR" "$PJ" \
      | CLAUDE_PLUGIN_ROOT="$1" TMPDIR="$2" "$BASH_BIN" "$1/hooks/remind.sh" 2>/dev/null; }

  OA="$(mktemp -d "$WORK/oa.XXXXXX")"
  oa_ap=$(rk_fire "$ROOT/plugins/approaches" "$OA"); oa_tm=$(rk_fire "$ROOT/plugins/taskmaster" "$OA")
  OB="$(mktemp -d "$WORK/ob.XXXXXX")"
  ob_tm=$(rk_fire "$ROOT/plugins/taskmaster" "$OB"); ob_ap=$(rk_fire "$ROOT/plugins/approaches" "$OB")

  [ -n "$oa_ap" ] && pass "precedence: best rank speaks, advisory-first order" \
    || fail "precedence: best rank speaks, advisory-first order" "approaches (rank 30) was silent"
  [ -n "$ob_ap" ] && pass "precedence: best rank speaks, directive-first order (same winner both orders)" \
    || fail "precedence: best rank speaks, directive-first order" "approaches (rank 30) was silent"
  [ -z "$oa_tm" ] && pass "precedence: worse rank YIELDS when the better one claimed first" \
    || fail "precedence: worse rank yields" "taskmaster (rank 90) spoke over approaches (rank 30): $oa_tm"

  # The cross-plugin clarify-gate signal must survive the budgetExempt retirement,
  # including on the turn where taskmaster yielded. It is the sole producer for
  # taskmaster/hooks/clarify-gate.sh, which is a PreToolUse DENY gate when the user
  # sets CC_CLARIFY_GATE=block — losing it silently would disarm that gate forever.
  if ls -d "$OA"/cc-workprompt-* >/dev/null 2>&1; then
    pass "precedence: cc-workprompt still produced on a turn where the directive yielded"
  else
    fail "precedence: cc-workprompt still produced when the directive yielded" \
         "clarify-gate lost its only producer whenever a sibling outranks taskmaster"
  fi

  # THE MISSION VERB (S3d): suppression alone would starve whichever voice ranks
  # last forever, because these directives are orthogonal concerns rather than
  # substitutes. The marker key carries the phase, so advancing the arc opens a
  # fresh claim namespace and the deferred voice gets its turn.
  PJ2="$WORK/prec2"; mkdir -p "$PJ2/.claude"
  TT="$(mktemp -d "$WORK/tt.XXXXXX")"
  printf '{"phase":"decide","owner":"x","session_id":"prec-1","started_at":"z"}' > "$PJ2/.claude/cc-phase.json"
  d_ap=$(printf '{"prompt":"%s","session_id":"prec-1","cwd":"%s"}' "$PR" "$PJ2" \
      | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/approaches" TMPDIR="$TT" "$BASH_BIN" "$AP" 2>/dev/null)
  printf '{"phase":"understand","owner":"x","session_id":"prec-1","started_at":"z"}' > "$PJ2/.claude/cc-phase.json"
  d_tm=$(printf '{"prompt":"%s","session_id":"prec-1","cwd":"%s"}' "$PR" "$PJ2" \
      | CLAUDE_PLUGIN_ROOT="$ROOT/plugins/taskmaster" TMPDIR="$TT" "$BASH_BIN" "$TM" 2>/dev/null)
  [ -n "$d_ap" ] && pass "turn-taking: the phase's own voice speaks" \
    || fail "turn-taking: the phase's own voice speaks" "approaches silent at phase=decide"
  [ -n "$d_tm" ] && pass "turn-taking: a deferred voice RESURFACES when its phase arrives (S3d)" \
    || fail "turn-taking: a deferred voice resurfaces when its phase arrives" \
            "taskmaster still gagged by the previous phase's claim — suppression without turns"

  # Flat markers must be reclaimable by the SHIPPED sweep. A nested layout breaks it:
  # rmdir cannot remove a non-empty directory and -maxdepth 1 never descends, so every
  # (sid,prompt) pair would leak a marker forever and each leak is a permanent gag.
  SW="$(mktemp -d "$WORK/sw.XXXXXX")"; mkdir "$SW/cc-remind-999-rank-10" "$SW/cc-workprompt-999"
  find "$SW" -maxdepth 1 \( -name 'cc-remind-*' -o -name 'cc-workprompt-*' \) -type d -exec rmdir {} + 2>/dev/null
  [ -z "$(ls -A "$SW")" ] && pass "precedence: flat markers are reclaimed by the existing sweep" \
    || fail "precedence: flat markers are reclaimed by the existing sweep" "leaked: $(ls "$SW")"

  # No privileged plugin: process-suite ships reminder hooks and no taskmaster.
  if [ -f "$AD" ]; then
    NA="$(mktemp -d "$WORK/na.XXXXXX")"; na1=$(rk_fire "$ROOT/plugins/approaches" "$NA")
    NB="$(mktemp -d "$WORK/nb.XXXXXX")"; nb1=$(rk_fire "$ROOT/plugins/approaches" "$NB")
    { [ -n "$na1" ] && [ -n "$nb1" ]; } \
      && pass "precedence: resolves with no taskmaster installed (S4, the process-suite shape)" \
      || fail "precedence: resolves with no taskmaster installed" "a1=[$na1] b1=[$nb1]"
  fi
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

# ---- PHASE SENTINEL (spec §4.3 / card C4) -----------------------------------
# The reader contract in full. Every branch below except "out of phase" must let
# the hook SPEAK: the sentinel only ever narrows, so a missing, foreign, stale or
# malformed one leaves today's behaviour untouched. The out-of-phase case is S9 —
# the live defect this work started from, where taskmaster's "before the first
# code edit" directive fires on turn 40 of a registered execution run.
#
# Why staleness is asserted on BOTH sides: a sentinel that never expires mutes the
# channel in every future session of that project with no symptom, which is worse
# than the defect it fixes. The precedent it replaces says so itself —
# completion-gate.sh:71, "Nothing clears it".
TM="$ROOT/plugins/taskmaster/hooks/remind.sh"
FT="$ROOT/plugins/fresh-take/hooks/remind.sh"
if [ -f "$TM" ] && [ -f "$FT" ]; then
  PP='implement a stripe billing integration'
  ph_dir() { PD="$WORK/phase-$1"; mkdir -p "$PD/.claude"; }
  ph_write() { printf '%s' "$2" > "$PD/.claude/cc-phase.json"; }
  ph_fire() { # $1 plugin dir, $2 hook, $3 prompt
    printf '{"prompt":"%s","session_id":"ph-A","cwd":"%s"}' "$3" "$PD" \
      | CLAUDE_PLUGIN_ROOT="$1" TMPDIR="$(mktemp -d "$WORK/tmp.XXXXXX")" "$BASH_BIN" "$2" 2>/dev/null
  }
  ph_expect() { # $1 label, $2 speak|silent, $3 output
    local got=silent; [ -n "$3" ] && got=speak
    if [ "$got" = "$2" ]; then pass "phase: $1"; else fail "phase: $1" "wanted $2, got $got"; fi
  }

  ph_dir absent
  ph_expect "no sentinel -> speaks (status quo preserved)" speak "$(ph_fire "$ROOT/plugins/taskmaster" "$TM" "$PP")"

  ph_dir inphase
  ph_write x '{"phase":"understand","owner":"taskmaster:task","session_id":"ph-A","started_at":"z"}'
  ph_expect "in phase -> speaks" speak "$(ph_fire "$ROOT/plugins/taskmaster" "$TM" "$PP")"

  ph_dir outphase
  ph_write x '{"phase":"build","owner":"task-runner:run","session_id":"ph-A","started_at":"z"}'
  ph_expect "OUT of phase -> stands down (S9)" silent "$(ph_fire "$ROOT/plugins/taskmaster" "$TM" "$PP")"

  ph_dir foreign
  ph_write x '{"phase":"build","owner":"task-runner:run","session_id":"OTHER-SESSION","started_at":"z"}'
  ph_expect "foreign session_id -> ignored, speaks" speak "$(ph_fire "$ROOT/plugins/taskmaster" "$TM" "$PP")"

  ph_dir malformed
  ph_write x '{"phase":"build","session_id":"ph-A"'
  ph_expect "malformed sentinel -> fail open, speaks" speak "$(ph_fire "$ROOT/plugins/taskmaster" "$TM" "$PP")"

  ph_dir stale
  ph_write x '{"phase":"build","owner":"x","session_id":"ph-A","started_at":"z"}'
  touch -t 200001010000 "$PD/.claude/cc-phase.json"
  ph_expect "stale sentinel -> speaks" speak "$(ph_fire "$ROOT/plugins/taskmaster" "$TM" "$PP")"
  if [ -f "$PD/.claude/cc-phase.json" ]; then
    fail "phase: stale sentinel is unlinked" "an expired sentinel survived the read"
  else
    pass "phase: stale sentinel is unlinked"
  fi

  ph_dir anylane
  ph_write x '{"phase":"build","owner":"x","session_id":"ph-A","started_at":"z"}'
  ph_expect "lane=any is a guard -> never stands down" speak \
    "$(ph_fire "$ROOT/plugins/fresh-take" "$FT" 'rm -rf node_modules')"
fi

# ---- THE ARC ACTUALLY ADVANCES ----------------------------------------------
# Drives the REAL reminder hooks against phases REAL commands write, and asserts a
# phase-owning voice still gets its turn. The first cut of the guard compared the
# lane and the sentinel for string equality, and the two vocabularies are disjoint —
# commands write shape/build/ship, advisories declared understand/decide — so `want =
# have` was unreachable and ANY sentinel muted every phase-owning hook, leaving only
# `any` lanes. That is a global mute wearing the name turn-taking, and the earlier
# fixtures could not see it because they fed `understand` and `decide`, values nothing
# in the tree ever writes. Fixtures must use values the shipped writers actually emit.
ARC_PL="$ROOT/plugins"
if [ -d "$ARC_PL/taskmaster/hooks" ] && [ -d "$ARC_PL/fresh-take/hooks" ]; then
  ARC_P='implement a rate limiter for our billing api, the docs integration is still failing, rm -rf node_modules'
  arc_speaks() { # $1 phase ("" = no sentinel) -> space-joined plugin names that spoke
    local ph="$1" d out spoke=""
    d="$(mktemp -d "$WORK/arc.XXXXXX")"; mkdir -p "$d/.claude"
    [ -n "$ph" ] && printf '{"phase":"%s","owner":"x","session_id":"ARC","started_at":"z"}' "$ph" \
      > "$d/.claude/cc-phase.json"
    for pl in taskmaster approaches api-docs-first debugging fresh-take; do
      [ -f "$ARC_PL/$pl/hooks/remind.sh" ] || continue
      out=$(printf '{"prompt":"%s","session_id":"ARC","cwd":"%s"}' "$ARC_P" "$d" \
        | CLAUDE_PLUGIN_ROOT="$ARC_PL/$pl" TMPDIR="$(mktemp -d "$WORK/at.XXXXXX")" \
          "$BASH_BIN" "$ARC_PL/$pl/hooks/remind.sh" 2>/dev/null)
      [ -n "$out" ] && spoke="$spoke $pl"
    done
    printf '%s' "$spoke"
  }

  arc_none=$(arc_speaks "")
  arc_build=$(arc_speaks build)
  arc_ship=$(arc_speaks ship)

  case "$arc_none" in *taskmaster*) pass "arc: no sentinel leaves every voice eligible" ;;
    *) fail "arc: no sentinel leaves every voice eligible" "taskmaster silent with no sentinel: [$arc_none]" ;; esac

  # The defect this guard exists to kill: clarify-the-requirements on turn 40 of a build.
  case "$arc_build" in *taskmaster*) fail "arc: phase=build mutes the clarify directive" "taskmaster spoke at build: [$arc_build]" ;;
    *) pass "arc: phase=build mutes the clarify directive" ;; esac

  # And the half that proves it is turn-taking rather than a global mute.
  case "$arc_build" in *api-docs-first*) pass "arc: phase=build still lets a build-phase voice speak" ;;
    *) fail "arc: phase=build still lets a build-phase voice speak" "nothing but guards spoke at build: [$arc_build] — the arc is a mute, not a rota" ;; esac

  case "$arc_ship" in *fresh-take*) pass "arc: an any-lane guard speaks at every phase" ;;
    *) fail "arc: an any-lane guard speaks at every phase" "guards silent at ship: [$arc_ship]" ;; esac

  if [ "$arc_none" = "$arc_build" ]; then
    fail "arc: advancing the phase changes who speaks" "identical at no-sentinel and build: [$arc_build]"
  else
    pass "arc: advancing the phase changes who speaks"
  fi
fi

if [ "$rc" -eq 0 ]; then
  printf '\nAll %d reminder hooks passed guard cases (slash / empty / no-jq); %d boost hooks passed trigger cases.\n' "$found" "$boost_found"
else
  printf '\nSome guard-case asserts FAILED.\n'
fi
exit $rc
