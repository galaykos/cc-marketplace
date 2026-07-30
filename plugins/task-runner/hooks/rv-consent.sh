#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
#
# PreToolUse consent gate — a DISCRETIONARY skip of a card's reviewer pass must be
# approved by the human before it is recorded, not disclosed afterwards.
#
# WHY HERE. PreToolUse is the only hook event that can put a question to the user
# (`permissionDecision: "ask"`); a Stop hook can refuse a stop but cannot ask, and
# AskUserQuestion is model-initiated so nothing can force it. A hook cannot see an
# ABSENCE — no event fires for a review that never happened — but it can see the one
# action a gated skip must take: writing the skip record. So the record write is the
# chokepoint, and the completion gate is what makes writing it unavoidable.
#
# WHAT IT ASKS ABOUT: rv-skip-* only. rv-seen-* (a real dispatch, observed) and
# rv-exempt-* (the two DESIGN carve-outs — a parallel-group/track leaf, and a
# reviewer plugin that is not installed) are routine and never prompt. Prompting on
# routine records would train the reflex this gate exists to prevent.
#
# HONEST LIMIT: under auto-accept, bypassPermissions, or a headless run there is no
# human and no prompt — the ask degrades to allow. In those modes consent is
# structurally impossible and disclosure-plus-gate is the ceiling: the record still
# gets written, the reason still lands in the transcript, and completion-gate.sh
# still refuses a clean stop whose report does not carry it.
#
# FAIL-OPEN: missing jq, unreadable input, any error → exit 0 (allow, no prompt).
{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Write | Edit | MultiEdit | Bash) ;; *) exit 0 ;; esac

  # TWO WAYS a discretionary skip reaches disk, and the sanctioned one does not
  # mention the filename at all: `review-skip.sh --card X --reason "..."` writes
  # rv-skip-X.json itself. Matching only the record name missed the primary path
  # entirely — the gate would have prompted on nothing in normal use.
  blob=$(printf '%s' "$input" | jq -r '.tool_input // {} | tostring' 2>/dev/null)
  discretionary=0
  printf '%s' "$blob" | grep -q 'rv-skip-' && discretionary=1
  if printf '%s' "$blob" | grep -q 'review-skip\.sh' &&
     printf '%s' "$blob" | grep -q -- '--reason'; then
    discretionary=1
  fi
  # An exemption is a design carve-out, never a judgment call: it must not prompt,
  # even when the same command mentions the record directory.
  printf '%s' "$blob" | grep -q -- '--exempt' && discretionary=0
  [ "$discretionary" -eq 1 ] || exit 0

  # `tostring` renders the command with its inner quotes backslash-escaped, so the
  # reason reads as --reason \"...\". Match against a de-escaped copy; the prompt
  # shown to the user is the one place this hook must get the text right.
  flat=$(printf '%s' "$blob" | sed 's/\\//g')

  card=$(printf '%s' "$flat" | grep -oE -- '--card *"?[a-zA-Z0-9._-]{1,64}' | head -1 |
    sed -E 's/^--card *"?//')
  if [ -z "$card" ]; then
    card=$(printf '%s' "$flat" | grep -oE 'rv-skip-[a-zA-Z0-9._-]{1,64}' | head -1 |
      sed -E 's/^rv-skip-//; s/\.json$//')
  fi
  [ -n "$card" ] || card="(unnamed)"

  # {1,200}, not {1,300}: BSD grep rejects an interval above 255 with "maximum
  # repetition exceeds 255" — on stderr, which this hook sends to /dev/null, so the
  # reason silently came back empty and every prompt read "no reason given".
  reason=$(printf '%s' "$flat" | grep -oE -- '--reason *"[^"]{1,200}"' | head -1 |
    sed -E 's/^--reason *"//; s/"$//' | cut -c1-300)
  [ -n "$reason" ] || reason="no reason given in the command"

  msg=$(printf 'Skipping the reviewer pass for card %s. Reason: %s\n\nApproving records the skip and lets the run continue; the completion report must still disclose it. Denying means the reviewer pass runs.' "$card" "$reason")

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
