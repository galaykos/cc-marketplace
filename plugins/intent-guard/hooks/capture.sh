#!/usr/bin/env bash
# UserPromptSubmit: capture the declared task intent, record the session-base commit once per
# session, rotate state on session change, and emit at most one continuous drift reminder.
# Warn-only: never holds a prompt. Fail-open: any error or a missing jq/git exits 0.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0

  dir="$cwd/.claude/intent-guard"
  mkdir -p "$dir" 2>/dev/null || exit 0
  intent="$dir/intent.json"
  base="$dir/base"
  turnlog="$dir/turn.log"

  # Rotate on session change — independent of whether an intent was ever seeded. A prior
  # session that starts with a slash command seeds no intent yet still logs actions; gating
  # rotation on intent.json let that stale state bleed into the next session. A dedicated
  # session marker makes rotation fire on any session change, so each session starts clean.
  sidmark="$dir/session"
  if [ -n "$sid" ]; then
    prev=$(cat "$sidmark" 2>/dev/null)
    if [ -n "$prev" ] && [ "$prev" != "$sid" ]; then
      : > "$turnlog" 2>/dev/null
      rm -f "$intent" "$base" 2>/dev/null
    fi
    printf '%s' "$sid" > "$sidmark" 2>/dev/null
  fi

  # Record the session-base commit once per session (HEAD at first prompt) so a later done-review
  # can diff against it and still see work already committed mid-turn. Fail-open: if this is not
  # a git repo (or git is absent), skip the marker — the skill falls back to the touched list.
  if [ ! -f "$base" ] && command -v git >/dev/null 2>&1; then
    sha=$(git -C "$cwd" rev-parse HEAD 2>/dev/null)
    [ -n "$sha" ] && printf '%s' "$sha" > "$base" 2>/dev/null
  fi

  # Disabled-visible: state exists but is corrupt — say so, never fail silently.
  if [ -f "$intent" ] && ! jq empty "$intent" 2>/dev/null; then
    printf 'intent-guard: DISABLED (intent.json unreadable) — drift review is OFF until it is fixed or removed.\n'
    exit 0
  fi

  # Seed a provisional intent from a free-text first prompt; leave slash-command (carded) starts
  # for the skill to seed from the active 00-INDEX.
  if [ ! -f "$intent" ]; then
    case "$prompt" in
      /*|"") : ;;
      *)
        jq -cn --arg s "$sid" --arg i "$prompt" \
          '{session_id:$s,intent:$i,source:"prompt",criteria:[]}' \
          > "$intent" 2>/dev/null
        printf 'intent-guard: task intent captured for this session. Refine with /intent-guard:intent, inspect with /intent-guard:status.\n'
        exit 0
        ;;
    esac
  fi

  # Continuous drift reminder: exactly one line, only when an intent exists AND the prior turn
  # touched files (turn.log non-empty). Primes the cooperative done-review with one lean line,
  # not a per-prompt or per-action nudge stream.
  if [ -f "$intent" ] && [ -s "$turnlog" ]; then
    x=$(jq -r '.intent // "the declared task"' "$intent" 2>/dev/null)
    printf 'intent-guard: intent «%s» — before you declare this done, review your diff for drift / corner-cutting (run the `drift-review` skill).\n' "$x"
  fi
} 2>/dev/null
exit 0
