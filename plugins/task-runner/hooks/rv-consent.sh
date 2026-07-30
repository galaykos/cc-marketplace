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
# WHAT IT ASKS ABOUT: a DISCRETIONARY reduction — a reviewer pass skipped
# (review-skip.sh --reason) or any other promise narrowed (reduction-record.sh: a
# degraded red-team panel, a downgraded fan-out, a narrowed suite). rv-seen-* (a real
# dispatch, observed) and rv-exempt-* (the DESIGN carve-outs — a parallel-group/track
# leaf, a reviewer plugin that is not installed) are routine and never prompt.
# Prompting on routine records would train the reflex this gate exists to prevent.
#
# HONEST LIMIT: what happens under auto-accept, bypassPermissions, or a headless `-p`
# run is NOT verified here — an unanswerable permission request may be denied rather
# than allowed, which would refuse the record write itself. Either way consent is
# structurally impossible without a human, so the ceiling in those modes is
# disclosure-plus-gate: the reason still lands in the transcript via the recorder's
# stderr, and completion-gate.sh still refuses a clean stop whose report omits it. A
# denial is bounded — the completion gate blocks at most once per HEAD — but do not
# read this comment as a claim that the prompt silently passes headless.
#
# FAIL-OPEN: missing jq, unreadable input, any error → exit 0 (allow, no prompt).
{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Write | Edit | MultiEdit | Bash) ;; *) exit 0 ;; esac

  # ONLY INSIDE A REGISTERED RUN. Without this the hook prompted in every session of
  # every repo with the plugin installed — on `grep -r rv-skip- .`, on deleting a stale
  # record, on editing this plugin's own scripts. A permission prompt that fires on
  # reading about a skip trains exactly the click-through reflex it exists to prevent.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -r "$cwd/.claude/task-runner/active-run.json" ] || exit 0

  # TWO WAYS a discretionary skip reaches disk, and the sanctioned one does not
  # mention the filename at all: `review-skip.sh --card X --reason "..."` writes
  # rv-skip-X.json itself. Matching only the record name missed the primary path
  # entirely — the gate would have prompted on nothing in normal use.
  blob=$(printf '%s' "$input" | jq -r '.tool_input // {} | tostring' 2>/dev/null)
  discretionary=0
  # A record being WRITTEN, not merely mentioned. `grep -r rv-skip- .` and `rm` of an old
  # record both name the path without creating one; only a write or a recorder invocation
  # with a reason is the act that needs consent.
  case "$tool" in
    Write | Edit | MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      case "$fp" in *rv-skip-*.json | */reductions/*.json) discretionary=1 ;; esac
      ;;
    Bash)
      cmdline=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      if printf '%s' "$cmdline" | grep -qE '(review-skip|reduction-record)\.sh' &&
         printf '%s' "$cmdline" | grep -q -- '--reason'; then
        discretionary=1
      fi
      # A shell redirect straight into a record file is the same act by another route.
      printf '%s' "$cmdline" | grep -qE '>[[:space:]]*[^|]*rv-skip-[a-zA-Z0-9._-]+\.json' && discretionary=1
      ;;
  esac
  # An exemption is a design carve-out, never a judgment call: it must not prompt,
  # even when the same command mentions the record directory.
  printf '%s' "$blob" | grep -q -- '--exempt' && discretionary=0
  [ "$discretionary" -eq 1 ] || exit 0

  # `tostring` renders the command with its inner quotes backslash-escaped, so the
  # reason reads as --reason \"...\". Match against a de-escaped copy; the prompt
  # shown to the user is the one place this hook must get the text right.
  # Unescape only the quote escapes `tostring` added; a blanket backslash strip mangled
  # legitimate ones (a Windows path, a regex) inside the reason shown to the user.
  flat=$(printf '%s' "$blob" | sed 's/\\"/"/g')

  card=$(printf '%s' "$flat" | grep -oE -- '--(card|id) *"?[a-zA-Z0-9._-]{1,64}' | head -1 |
    sed -E 's/^--(card|id) *"?//')
  if [ -z "$card" ]; then
    card=$(printf '%s' "$flat" | grep -oE 'rv-skip-[a-zA-Z0-9._-]{1,64}' | head -1 |
      sed -E 's/^rv-skip-//; s/\.json$//')
  fi
  [ -n "$card" ] || card="(unnamed)"

  # {1,200}, not {1,300}: BSD grep rejects an interval above 255 with "maximum
  # repetition exceeds 255" — on stderr, which this hook sends to /dev/null, so the
  # reason silently came back empty and every prompt read "no reason given".
  reason=$(printf '%s' "$flat" | grep -oE -- "--reason *\"[^\"]{1,200}\"|--reason *'[^']{1,200}'" | head -1 |
    sed -E "s/^--reason *[\"']//; s/[\"']$//" | cut -c1-300)
  [ -n "$reason" ] || reason="no reason given in the command"

  what="the reviewer pass for card"
  printf '%s' "$flat" | grep -q 'reduction-record\.sh' && what="a declared step for"
  msg=$(printf 'Reducing %s %s. Reason: %s\n\nApproving records the reduction and lets the run continue; the completion report must still disclose it. Denying means the full step runs.' "$what" "$card" "$reason")

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
