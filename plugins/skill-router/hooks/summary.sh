#!/bin/bash
# summary.sh — SessionEnd, fails open: appends what the router surfaced in this context to $HOME/.claude/skill-router/<root-slug>/surfaced.jsonl,
#   prints the signals no prompt flushed (transcript residue: no model turn follows) and removes the context's state file.
# Off: CC_SURFACED_LOG=off skips the ledger append; unset, the /config option cc_surfaced_log decides.
# Misses: a context whose payload cwd no longer exists keeps its state file, orphaned.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/summary.sh

# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

# Shared block templates/blocks/plugin-state.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/plugin-state.md
# cc_plugin_state <root> <name> prints the plugin's own state dir for <root>, a cc_state_root result:
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.claude/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.claude/%s\n' "$1" "$2"
  fi
  return 0
}

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  # ctx_src and the root key the state file exactly as route.sh does; session_id is only a field the ledger records.
  ctx_src=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null) || exit 0
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$ctx_src" ] || exit 0
  [ -n "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  ctx=$(printf '%s' "$ctx_src" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  state_file="$(cc_plugin_state "$root" skill-router)/fired-$ctx.json"
  [ -r "$state_file" ] || exit 0

  line=$(jq -r '
    [ (.pending_low // [])[] | select(.flushed != true) ]
    | group_by(.skill)
    | map(.[0].skill + " (" + (length | tostring) + " file" + (if length == 1 then "" else "s" end) + ")")
    | join(", ")
  ' "$state_file" 2>/dev/null) || { rm -f "$state_file" 2>/dev/null; exit 0; }

  [ -n "$line" ] && printf '[skill-router] Low-confidence signals seen this session — consider: %s.\n' "$line"

  case "$(cc_option CC_SURFACED_LOG on)" in
    off) : ;;
    *)
      # Slugged by the project root, not the payload cwd: one project keeps one ledger wherever the model cd-ed.
      slug=$(printf '%s' "$root" | tr -c '[:alnum:]' '-' 2>/dev/null) || slug=""
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
            # exact number the turn-cost --skills queue ranks skills by. Measured before
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
