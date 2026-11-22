#!/bin/bash
# PostToolUse, a Write/Edit/MultiEdit of an Assets/**/*.cs under the nearest folder holding Assets/ and ProjectSettings/: runs check_unity_project.py on that project and adds that file's api-* findings (a C# name the project's Unity or Cinemachine version deprecated or removed), each rule once per file per context, at most MAX_SHOWN.
# Misses: a Bash write, a name under an #if UNITY_*/CINEMACHINE guard, an alias or a call through a variable, a project with no readable ProjectVersion.txt or Cinemachine version (no finding for that owner), a .cs outside Assets/, a run past CHECK_TIMEOUT. Warn-only, fail-open. Off: CC_UNITY_API_CHECK=off, or /config.
# Why, limits, history: rationale/derivations/plugin-unity-traps.md § plugins/unity-traps/hooks/api-check.sh

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
  [ "$(cc_option CC_UNITY_API_CHECK on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  MAX_SHOWN=5         # findings printed per call; the rest are counted
  MAX_DEPTH=32        # folders walked up from the edited file looking for the project
  CHECK_TIMEOUT=20    # seconds per checker run (0.74 s on a 40,201-file project); hooks.json allows 30

  checker="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/scripts/check_unity_project.py"
  [ -f "$checker" ] || exit 0

  [ "$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)" = "PostToolUse" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac
  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  case "$fp" in *.cs) ;; *) exit 0 ;; esac
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  case "$fp" in /*) ;; *) fp="$cwd/$fp" ;; esac
  [ -f "$fp" ] || exit 0

  proj=""; d=$(dirname -- "$fp"); i=0
  while [ "$i" -lt "$MAX_DEPTH" ]; do
    [ -d "$d/Assets" ] && [ -d "$d/ProjectSettings" ] && { proj="$d"; break; }
    [ "$d" = "/" ] && break
    d=$(dirname -- "$d"); i=$((i + 1))
  done
  [ -n "$proj" ] || exit 0
  rel="${fp#"$proj"/}"
  case "$rel" in Assets/*) ;; *) exit 0 ;; esac

  # Keyed on the context, hashed: a subagent shares its parent's session_id, and a raw path as a filename names parents that never exist.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  sroot=$(cc_state_root "$cwd") || exit 0
  dir=$(cc_plugin_state "$sroot" unity-traps)
  # Unwritable state means silence: a finding that cannot be recorded as said would repeat on every edit.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  find "$dir" -maxdepth 1 -name 'api-seen-*' -mmin +1440 -delete 2>/dev/null
  seen="$dir/api-seen-$ctx"

  to=""
  command -v timeout >/dev/null 2>&1 && to="timeout $CHECK_TIMEOUT"
  json=$($to python3 -I "$checker" "$proj" --json --max-issues 0 2>/dev/null)
  [ $? -le 1 ] || exit 0                         # 2: not a project or usage; 124: timed out
  # The key is the rule (its fix names the replacement and the page), not the line or the use count, which change on every edit.
  lines=$(printf '%s' "$json" | jq -r --arg rel "$rel" '
    def clean: gsub("[[:cntrl:]]"; " ");
    def row($lvl): "\(.code)|\(.file)|\(.fix)\t" + ("\($lvl) \(.code) \(.file)\(if .line then ":\(.line)" else "" end): \(.message)" | clean)[0:300] + "\t  fix: " + (.fix | clean)[0:300];
    (.errors[]? | select(.file == $rel and (.code | startswith("api-"))) | row("ERROR")),
    (.warnings[]? | select(.file == $rel and (.code | startswith("api-"))) | row("WARNING"))' 2>/dev/null)

  shown=""; nshown=0; more=0
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    key=$(printf '%s|%s' "$proj" "${l%%$'\t'*}" | cksum | cut -d' ' -f1); l="${l#*$'\t'}"
    grep -qxF "$key" "$seen" 2>/dev/null && continue
    printf '%s\n' "$key" >> "$seen" 2>/dev/null || exit 0
    if [ "$nshown" -lt "$MAX_SHOWN" ]; then
      shown="$shown${l%%$'\t'*}"$'\n'"${l#*$'\t'}"$'\n'; nshown=$((nshown + 1))
    else
      more=$((more + 1))
    fi
  done <<< "$lines"
  [ "$nshown" -gt 0 ] || exit 0

  msg="unity-traps: check_unity_project.py after this $tool of $rel, in $proj — $nshown new C# name finding(s) in this file:"$'\n'"$shown"
  [ "$more" -gt 0 ] && msg="$msg(+$more more, not repeated: python3 \"$checker\" \"$proj\")"$'\n'
  msg="${msg}api-removed no longer compiles on this project's version; api-deprecated still compiles with an obsolete warning, so a green build does not clear it. Use the replacement the fix names."
  jq -cn --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
} 2>/dev/null
exit 0
