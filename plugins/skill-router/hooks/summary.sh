#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
# SessionEnd ledger + cleanup. The model-visible surfacing of low-confidence
# signals happens in route-prompt.sh's next-prompt flush — SessionEnd is an
# event after which no model turn exists, so the digest line printed here is
# transcript residue covering only entries the flush never surfaced. The real
# jobs are the surfaced.jsonl ledger append and removing the state file.
# Fail-open: any error exits silently.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$session_id" ] || exit 0
  [ -n "$cwd" ] || exit 0

  state_file="$cwd/.claude/skill-router/fired-$session_id.json"
  [ -r "$state_file" ] || exit 0

  line=$(jq -r '
    [ (.pending_low // [])[] | select(.flushed != true) ]
    | group_by(.skill)
    | map(.[0].skill + " (" + (length | tostring) + " file" + (if length == 1 then "" else "s" end) + ")")
    | join(", ")
  ' "$state_file" 2>/dev/null) || { rm -f "$state_file" 2>/dev/null; exit 0; }

  [ -n "$line" ] && printf '[skill-router] Low-confidence signals seen this session — consider: %s.\n' "$line"

  # SURFACED LEDGER. Before the state file goes, append what this session's
  # router actually surfaced to a machine-local JSONL. This file is the only
  # record anywhere that a routing rule did anything: until it existed, every
  # argument this marketplace made about a plugin's worth was made from token
  # counts and trigger-phrase overlap, because there was no denominator. A rule
  # that surfaced nothing across N sessions is the cheapest possible retirement
  # argument, and that sentence was unwriteable while this line was `rm -f` alone.
  #
  # It records what the router OFFERED, not what the model loaded — hence
  # `surfaced`, never `usage`. Nothing reads it automatically; /hindsight:harvest
  # reports it on demand, matching hindsight's collect → harvest → apply contract.
  # Machine-local ($HOME, never the project tree), same slug rule as
  # hindsight/hooks/collect.sh, fail-silent, and skipped entirely when
  # CC_SURFACED_LOG=off.
  case "${CC_SURFACED_LOG:-on}" in
    off) : ;;
    *)
      slug=$(printf '%s' "$cwd" | tr -c '[:alnum:]' '-' 2>/dev/null) || slug=""
      if [ -n "$slug" ] && [ -n "${HOME:-}" ]; then
        dir="$HOME/.claude/skill-router/$slug"
        if mkdir -p "$dir" 2>/dev/null; then
          jq -c --arg sid "$session_id" '{
            v: 1,
            ts: (now | todate),
            session_id: $sid,
            fired: ((.fired // []) | unique),
            # SPLIT ON `flushed`, not one bucket. route-prompt.sh marks an entry
            # flushed only when it actually printed the digest to the model, so
            # collapsing both states into `pending_low` made "accumulated but
            # never shown" indistinguishable from "surfaced" — and that is the
            # exact number retirement-queue.sh ranks skills by. Measured before
            # this fix: four skills read 47 pending_low across 17 local sessions
            # with 0 fired, and nothing could say whether any reached the model.
            # `pending_low` is kept as the union so an older reader keeps working.
            pending_low: ((.pending_low // []) | map(.skill) | unique),
            pending_low_flushed: ((.pending_low // []) | map(select(.flushed == true) | .skill) | unique),
            pending_low_unflushed: ((.pending_low // []) | map(select(.flushed != true) | .skill) | unique)
          }' "$state_file" >> "$dir/surfaced.jsonl" 2>/dev/null
        fi
      fi ;;
  esac

  rm -f "$state_file" 2>/dev/null
} 2>/dev/null
exit 0
