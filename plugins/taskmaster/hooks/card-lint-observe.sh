#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): fail-open must hold under a
# stripped or broken PATH, like every other hook in this plugin.
#
# card-lint-observe.sh — PostToolUse observer that says out loud when a card set
# reached EXECUTION unlinted.
#
# THE GAP IT CLOSES. taskmaster ships three author-time linters — verify-teeth,
# skills-stamp, spec-ledger. Each is a gate WHEN IT RUNS, and until now nothing
# observed that any of them ran: a card set could reach the runner with none of them
# invoked and every check in this marketplace green. The linters now append a run
# record beside each card (scripts/card-lint-record.sh); this reads them back at the
# only moment the omission is still cheap to fix — the first write of the run.
#
# IT WARNS. It never blocks and never denies a tool call: card authoring is
# reversible, and the decision behind this path was teeth in a shipped hook, not a
# new blocking gate. Standing: `agent-graded` at best — the message reaches the model
# as additionalContext and the model chooses what to do with it.
#
# WHY PostToolUse AND NOT Stop. Stop reaches the model only by BLOCKING (exit 2);
# an exit-0 Stop hook prints into a turn that has already ended, so a warn-only Stop
# hook would be a message nobody acts on (task-runner/hooks/completion-gate.sh:11-14
# states the same constraint from the blocking side). PostToolUse is also the only
# event that runs inside SUBAGENTS, which is where a fanned-out card is actually
# implemented.
#
# THE CONTEXT KEY. The one-shot ("already warned about this set here") is keyed on
# transcript_path, never session_id: a subagent shares its parent's session_id, so a
# session-keyed marker would dedupe the worker against a warning it never saw — the
# whole point of using this event. transcript_path is an ABSOLUTE PATH, so it is
# hashed with cksum before it reaches a filename; interpolated raw it would name a
# file under directories that do not exist and the bound would silently stop
# existing. (pc_context_key / pc_marker_key, scripts/lib/plugin-checks.sh.)
#
# TRIGGER. `.claude/task-runner/active-run.json` carrying an `index_path` — the
# registration task-runner/commands/run.md step 1 writes for a taskmaster-index run.
# That file existing IS the handoff: cards have been handed to an executor.
#
# HONEST LIMITATIONS, all four real:
#   1. Keyed off the run REGISTERING itself, exactly like the completion gate. A
#      card set executed without `/task-runner:run` is never observed at all.
#   2. It reports MISSING records only. A card whose recorded verdict was `block`
#      is not re-warned — the linter already blocked at author time, and the
#      accepted contract here is "has a record" (a fixed card is re-linted and
#      keeps both rows).
#   3. A record proves invocation, not honesty: it can be written by hand, and
#      nothing re-reads the card. This closes forgetting, not evasion.
#   4. spec-ledger records are written but NOT graded here — the spec is one file
#      per set, named in the index in prose, and inferring it from text would be
#      guessing. Cards are what this counts.
#
# Off switches: CC_CARDLINT=off (this hook) or CC_REMIND=off (every reminder in the
# marketplace). Fail-open on missing jq, malformed input, or an unwritable TMPDIR.
{
  case "${CC_CARDLINT:-on}" in off) exit 0 ;; esac
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0

  # HANDOFF, cheapest test first: this is a per-edit hook and the overwhelming case
  # is a session with no registered run, which must cost one stat and stop.
  sentinel="$cwd/.claude/task-runner/active-run.json"
  [ -r "$sentinel" ] || exit 0
  index=$(jq -r '.index_path // empty' "$sentinel" 2>/dev/null) || exit 0
  [ -n "$index" ] || exit 0                      # a non-index run has no card set
  case "$index" in /*) ;; *) index="$cwd/$index" ;; esac
  [ -r "$index" ] || exit 0

  # Shared identity with the writers. CLAUDE_PLUGIN_ROOT when installed; the
  # relative path is what makes the harness able to drive this file directly.
  . "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/card-lint-record.sh" 2>/dev/null || exit 0
  command -v cardlint_has >/dev/null 2>&1 || exit 0

  set_dir=$(dirname "$index")
  total=0; miss_n=0; named=""
  for card in "$set_dir"/[0-9][0-9]-*.md; do
    [ -f "$card" ] || continue
    base=$(basename "$card")
    case "$base" in 00-*) continue ;; esac      # the index is not a card
    total=$((total + 1))
    [ "$total" -gt 60 ] && break                # bounded: this runs inside the turn
    gaps=""
    cardlint_has verify-teeth "$card" || gaps="verify-teeth"
    cardlint_has skills-stamp "$card" || gaps="${gaps:+$gaps+}skills-stamp"
    [ -n "$gaps" ] || continue
    miss_n=$((miss_n + 1))
    # Name the first few and count the rest: a 20-card set must not paste 20 lines
    # into the turn to make one point.
    [ "$miss_n" -le 4 ] && named="${named:+$named; }$base ($gaps)"
  done
  [ "$miss_n" -gt 0 ] || exit 0                  # every card has a record — silent

  # ONE SHOT per transcript per card set. The key mixes the index path so a second
  # run against a different set in one transcript still gets its warning.
  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  key=$(printf '%s|%s' "${tp:-no-transcript}" "$index" | cksum | cut -d' ' -f1)
  marker="${TMPDIR:-/tmp}/cc-cardlint-warned-$key"
  # A bound that cannot be recorded means no warning at all — the same rule
  # comment-discipline/hooks/scan.sh applies to its deny, for the same reason:
  # a message with no working one-shot repeats on every edit of the run.
  mkdir "$marker" 2>/dev/null || exit 0
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-cardlint-warned-*' -type d -mmin +1440 \
    -exec rmdir {} + 2>/dev/null

  [ "$miss_n" -gt 4 ] && named="$named; +$((miss_n - 4)) more"
  msg=$(printf '[taskmaster] card-lint: %s of %s card(s) in %s reached this run with no recorded lint — %s. Per card, before executing it: verify-teeth-lint.sh --card <card> (blocks a toothless Verify line) and skills-stamp-lint.sh --card <card> (blocks a framework card stamped "none"), both in the taskmaster plugin scripts/ dir. Warning only, nothing is blocked.' \
    "$miss_n" "$total" "$(basename "$set_dir")" "$named")
  jq -cn --arg r "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$r}}'
} 2>/dev/null
exit 0
