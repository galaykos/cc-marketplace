#!/usr/bin/env bash
# UserPromptSubmit: capture the declared task intent, rotate state per session, and emit a
# short conditional nudge. Fail-open: never block a prompt; any error or a missing jq exits 0.
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
  ledger="$dir/ledger.jsonl"
  attest="$dir/attest.json"

  # Rotate on session change — independent of whether an intent was ever seeded. A prior
  # session that starts with a slash command seeds no intent yet still logs actions; gating
  # rotation on intent.json let that stale ledger bleed into the next session. A dedicated
  # session marker makes rotation fire on any session change, so each session starts clean.
  sidmark="$dir/session"
  if [ -n "$sid" ]; then
    prev=$(cat "$sidmark" 2>/dev/null)
    if [ -n "$prev" ] && [ "$prev" != "$sid" ]; then
      : > "$ledger" 2>/dev/null
      rm -f "$attest" "$intent" 2>/dev/null
    fi
    printf '%s' "$sid" > "$sidmark" 2>/dev/null
  fi

  # Disabled-visible: state exists but is corrupt — say so, never fail silently.
  if [ -f "$intent" ] && ! jq empty "$intent" 2>/dev/null; then
    printf 'intent-guard: DISABLED (intent.json unreadable) — attestation is OFF until it is fixed or removed.\n'
    exit 0
  fi

  # Seed a provisional intent from a free-text first prompt; leave slash-command (carded) starts
  # for the skill to seed from the active 00-INDEX.
  if [ ! -f "$intent" ]; then
    case "$prompt" in
      /*|"") : ;;
      *)
        jq -cn --arg s "$sid" --arg i "$prompt" \
          '{session_id:$s,intent:$i,source:"prompt",criteria:[],declared_at_seq:0}' \
          > "$intent" 2>/dev/null
        printf 'intent-guard: task intent captured for this session; each action will be attested against it. Refine with /intent-guard:intent, inspect with /intent-guard:status.\n'
        exit 0
        ;;
    esac
  fi

  if [ ! -f "$intent" ]; then
    printf 'intent-guard: no task intent declared yet — run /intent-guard:intent "<task>" so mid-run actions can be attested (or the intent-attestation skill will seed it from the active 00-INDEX).\n'
    exit 0
  fi

  # Conditional nudge: only when work is pending.
  maxseq=$(grep -c '"kind":"action"' "$ledger" 2>/dev/null || echo 0)
  through=0; drift=0
  if [ -f "$attest" ] && jq empty "$attest" 2>/dev/null; then
    through=$(jq -r '(.through_seq // 0)' "$attest" 2>/dev/null)
    drift=$(jq -r '[.attestations[]? | select(.verdict=="drift" and (.accepted!=true))] | length' "$attest" 2>/dev/null)
  fi
  [ "$through" -gt "$maxseq" ] 2>/dev/null && through=$maxseq
  unatt=$(( maxseq - through ))
  if [ "$unatt" -gt 0 ] 2>/dev/null || [ "$drift" -gt 0 ] 2>/dev/null; then
    printf 'intent-guard: %s action(s) unattested, %s open drift vs your declared intent — attest each in .claude/intent-guard/attest.json (Write tool) before finishing.\n' "$unatt" "$drift"
  fi
} 2>/dev/null
exit 0
