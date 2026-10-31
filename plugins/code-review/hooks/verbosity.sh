#!/bin/bash
# PostToolUse, main thread only: warns once per session when assistant text per tool call, cumulative over the transcript, passes THRESHOLD; every scan goes to a local ledger.
# Misses: prose the user asked for counts too; a session that tightens up stays flagged; THRESHOLD is calibrated on one machine; no transcript_path, no check. Off: CC_REMIND.
# Why, limits, history: rationale/derivations/plugin-code-review.md § plugins/code-review/hooks/verbosity.sh

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
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0

  input=$(cat)
  # Warn-only hook, so the marketplace-wide advisory switch silences it outright.
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null) || exit 0
  [ -n "$tp" ] && [ -r "$tp" ] || exit 0

  # Subagents are exempt: their final text is their return value. Match the path, not the content.
  case "$tp" in */subagents/*) exit 0 ;; esac

  # -d, not just -n: a session outlives its directory. State lives at the state root, an address shared with density.sh and scan.sh.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0

  # Cheap path first, since this runs after every tool call; state "<lines at last scan> <warned 0|1>" allows one scan per RESCAN_EVERY lines.
  MIN_LINES=60
  RESCAN_EVERY=150
  THRESHOLD=600
  MIN_TOOL_CALLS=8

  lines=$(wc -l < "$tp" 2>/dev/null | tr -d ' ')
  case "$lines" in ''|*[!0-9]*) exit 0 ;; esac
  [ "$lines" -ge "$MIN_LINES" ] || exit 0

  # Resolved here, after the line-count exit, so a short session never pays the git call.
  root=$(cc_state_root "$cwd") || exit 0
  dir=$(cc_plugin_state "$root" comment-discipline)
  state="$dir/verbosity-$sid"

  # Both bounds live in the state file, so an unwritable state dir means this hook does nothing at all.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself

  last=0
  if [ -r "$state" ]; then
    read -r last warned _ < "$state" 2>/dev/null || exit 0
    [ "${warned:-0}" = "1" ] && exit 0
    case "$last" in ''|*[!0-9]*) last=0 ;; esac
    [ "$((lines - last))" -ge "$RESCAN_EVERY" ] || exit 0
  fi

  # EXPENSIVE PATH: one jq pass emitting "<text-chars> <tool-calls>".
  read -r chars calls <<EOF
$(jq -rs '
    [ .[]
      | select(type == "object" and .type == "assistant")
      | (.message.content // [])[]?
      | select(type == "object")
    ] as $c
    | [ ($c | map(select(.type == "text") | (.text // "" | length)) | add // 0),
        ($c | map(select(.type == "tool_use")) | length) ]
    | @tsv' "$tp" 2>/dev/null)
EOF
  case "${chars:-}${calls:-}" in ''|*[!0-9]*) chars=""; calls="" ;; esac
  [ -n "$chars" ] && [ -n "$calls" ] || exit 0
  [ "$calls" -ge "$MIN_TOOL_CALLS" ] || { printf '%s 0\n' "$lines" > "$state" 2>/dev/null; exit 0; }

  ratio=$((chars / calls))

  # Ledger: every scan, machine-local, capped at 1 MB; nothing reads it back automatically.
  ledger="${HOME:-/tmp}/.claude/comment-discipline/verbosity-ledger.jsonl"
  if [ "$(wc -c < "$ledger" 2>/dev/null || echo 0)" -lt 1048576 ]; then
    mkdir -p "${ledger%/*}" 2>/dev/null &&
      jq -cn --arg s "$sid" --argjson c "$chars" --argjson t "$calls" \
             --argjson r "$ratio" --argjson th "$THRESHOLD" --argjson l "$lines" \
        '{session:$s,chars:$c,calls:$t,ratio:$r,threshold:$th,lines:$l,warned:($r>$th)}' \
        >> "$ledger" 2>/dev/null
  fi

  if [ "$ratio" -le "$THRESHOLD" ]; then
    printf '%s 0\n' "$lines" > "$state" 2>/dev/null
    exit 0
  fi

  printf '%s 1\n' "$lines" > "$state" 2>/dev/null

  msg=$(printf 'comment-discipline: this session has emitted ~%s characters of prose per tool call (threshold %s; p95 of measured sessions is ~389). Keep what the user needs to follow the work — what you found, what changed, what you need from them — and drop preamble and closing summaries that restate the diff. Shown once per session.' "$ratio" "$THRESHOLD")

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null \
    || exit 0
  exit 0
} 2>/dev/null
exit 0
