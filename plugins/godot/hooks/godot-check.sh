#!/bin/bash
# PostToolUse, a Write/Edit/MultiEdit of a .tscn, .tres or .gd under the nearest project.godot: runs check_godot_project.py on that project and adds its errors anywhere plus warnings in the edited file, each once per context, at most MAX_SHOWN.
# Misses: an edit made by Bash or the Godot editor, a file in a hidden folder, findings past MAX_SHOWN (counted once, never repeated), a run past CHECK_TIMEOUT, whatever the checker misses. Warn-only, fail-open. Off: CC_GODOT_CHECK=off, or /config.
# Why, limits, history: rationale/derivations/plugin-godot.md § plugins/godot/hooks/godot-check.sh

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
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.cc-artifacts/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.cc-artifacts/%s\n' "$1" "$2"
  fi
  return 0
}

{
  [ "$(cc_option CC_GODOT_CHECK on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  MAX_SHOWN=5         # findings printed per call; the rest are counted
  MAX_DEPTH=32        # folders walked up from the edited file looking for project.godot
  CHECK_TIMEOUT=10    # seconds per checker run (0.48 s on a 6,001-file project); hooks.json allows 20

  checker="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/scripts/check_godot_project.py"
  [ -f "$checker" ] || exit 0

  [ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" = "PostToolUse" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac
  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  case "$fp" in *.tscn|*.tres|*.gd) ;; *) exit 0 ;; esac
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  case "$fp" in /*) ;; *) fp="$cwd/$fp" ;; esac
  [ -f "$fp" ] || exit 0

  proj=""; d=$(dirname -- "$fp"); i=0
  while [ "$i" -lt "$MAX_DEPTH" ]; do
    [ -f "$d/project.godot" ] && { proj="$d"; break; }
    [ "$d" = "/" ] && break
    d=$(dirname -- "$d"); i=$((i + 1))
  done
  [ -n "$proj" ] || exit 0
  rel="${fp#"$proj"/}"
  # Godot does not scan hidden folders (.godot/ among them), and neither does the checker.
  case "/$rel" in */.*/*) exit 0 ;; esac

  # Keyed on the context, hashed: a subagent shares its parent's session_id, and a raw path as a filename names parents that never exist.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  sroot=$(cc_state_root "$cwd") || exit 0
  dir=$(cc_plugin_state "$sroot" godot)
  # Unwritable state means silence: a finding that cannot be recorded as said would repeat on every edit.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  find "$dir" -maxdepth 1 -name 'check-seen-*' -mmin +1440 -delete 2>/dev/null
  seen="$dir/check-seen-$ctx"

  to=""
  command -v timeout >/dev/null 2>&1 && to="timeout $CHECK_TIMEOUT"
  json=$($to python3 -I "$checker" "$proj" --json --max-issues 0 2>/dev/null)
  [ $? -le 1 ] || exit 0                         # 2: not a project or usage; 124: timed out
  # Messages quote project files: control characters go and each line is capped, so a scene cannot add lines or a long payload.
  lines=$(printf '%s' "$json" | jq -r --arg rel "$rel" '
    def clean: gsub("[[:cntrl:]]"; " ");
    def row($lvl): ("\($lvl) \(.code) \(.file)\(if .line then ":\(.line)" else "" end): \(.message)" | clean)[0:300] + "\t  fix: " + (.fix | clean)[0:212];
    (.errors[]? | select(.file == $rel) | row("ERROR")), (.warnings[]? | select(.file == $rel) | row("WARNING")),
    (.errors[]? | select(.file != $rel) | row("ERROR"))' 2>/dev/null)

  shown=""; nshown=0; more=0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    key=$(printf '%s|%s' "$proj" "${l%%$'\t'*}" | cksum | cut -d' ' -f1)
    grep -qxF "$key" "$seen" 2>/dev/null && continue
    printf '%s\n' "$key" >> "$seen" 2>/dev/null || exit 0
    if [ "$nshown" -lt "$MAX_SHOWN" ]; then
      shown="$shown${l%%$'\t'*}"$'\n'"${l#*$'\t'}"$'\n'; nshown=$((nshown + 1))
    else
      more=$((more + 1))
    fi
  done <<< "$lines"
  [ "$nshown" -gt 0 ] || exit 0

  msg="godot: check_godot_project.py after this $tool of $rel, in $proj — $nshown new finding(s) (errors anywhere, warnings in this file):"$'\n'"$shown"
  [ "$more" -gt 0 ] && msg="$msg(+$more more, not repeated: python3 \"$checker\" \"$proj\")"$'\n'
  msg="${msg}Godot fails to load a scene with a broken res:// path, uid, resource id or node path; fix these before building on the edit."
  jq -cn --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
} 2>/dev/null
exit 0
