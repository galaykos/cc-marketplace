#!/bin/bash
# PreToolUse marks, PostToolUse/PostToolUseFailure checks: a sprite-sheet JSON holding "frames" (a PNG stands for its same-stem JSON) or a .tmx/.tmj/.ldtk map that a Write/Edit names, or whose ctime moved during a Bash call naming a sheet tool or extension, runs through check_sprite_sheet.py or check_tilemaps.py; findings are added once per context.
# Misses: .tsx/.tsj/.ldtkl and sheets whose JSON stem differs from the PNG, files outside the project root or past MAX_FILES, a call whose PreToolUse did not run, a run past CHECK_TIMEOUT; reads too much: a parallel call's file lands in this call's window. Warn-only, fail-open. Off: CC_PIXEL_CHECK=off, or /config.
# Why, limits, history: rationale/derivations/plugin-pixel-art.md § plugins/pixel-art/hooks/sheet-check.sh

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
  [ "$(cc_option CC_PIXEL_CHECK on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  MAX_FILES=6         # sheets and maps checked per call
  MAX_SHOWN=6         # findings printed per call; the rest are counted
  CHECK_TIMEOUT=10    # seconds per checker run; hooks.json allows 30

  event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  # Every Bash call fires PreToolUse: the command test runs before git, cksum or any state path.
  if [ "$event" = "PreToolUse" ]; then
    [ "$tool" = "Bash" ] || exit 0
    printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null \
      | grep -qiE 'aseprite|libresprite|texturepacker|tiled|ldtk|sprite|sheet|\.(png|json|tmx|tmj|ldtk)' || exit 0
  fi
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  sroot=$(cc_state_root "$cwd") || exit 0
  dir=$(cc_plugin_state "$sroot" pixel-art)

  # A Bash call can write a sheet without naming it (aseprite -b --sheet, a packer, a script), so it is
  # bracketed: PreToolUse drops a marker named for the tool_use_id, PostToolUse lists the sheet and map
  # files whose ctime moved after it. ctime, not mtime: mv and cp -p keep the mtime.
  call=$(printf '%s' "$input" | jq -r '.tool_use_id // empty' 2>/dev/null)
  mark=""
  [ -n "$call" ] && mark="$dir/sheet-call-$(printf '%s' "$call" | cksum | cut -d' ' -f1)"

  if [ "$event" = "PreToolUse" ]; then
    [ -n "$mark" ] || exit 0
    mkdir -p "$dir" 2>/dev/null || exit 0
    [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
    find "$dir" -maxdepth 1 -name 'sheet-call-*' -mmin +120 -delete 2>/dev/null
    : > "$mark" 2>/dev/null
    exit 0
  fi
  case "$event" in PostToolUse|PostToolUseFailure) ;; *) exit 0 ;; esac

  changed=""
  case "$tool" in
    Write|Edit|MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      case "$fp" in /*) ;; *) fp="$cwd/$fp" ;; esac
      changed="$fp"$'\n'
      ;;
    Bash)
      [ -n "$mark" ] && [ -f "$mark" ] || exit 0
      changed=$(find "$sroot" \( -name .git -o -name node_modules -o -name Library -o -name .venv -o -name .claude \) -prune \
        -o -type f \( -name '*.json' -o -name '*.png' -o -name '*.tmx' -o -name '*.tmj' -o -name '*.ldtk' \) -cnewer "$mark" -print 2>/dev/null | head -n 64)
      rm -f "$mark" 2>/dev/null
      ;;
    *) exit 0 ;;
  esac

  # A sheet is a JSON holding "frames" (a PNG stands for the same-stem JSON beside it); a map is .tmx, .tmj or .ldtk.
  jobs=""
  is_sheet() { [ -f "$1" ] && grep -q '"frames"' "$1" 2>/dev/null; }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    j=""
    case "$f" in
      *.tmx|*.tmj|*.ldtk) [ -f "$f" ] && j="map"$'\t'"$f" ;;
      *.json) is_sheet "$f" && j="sheet"$'\t'"$f" ;;
      *.png) is_sheet "${f%.png}.json" && j="sheet"$'\t'"${f%.png}.json" ;;
    esac
    [ -n "$j" ] || continue
    case $'\n'"$jobs" in *$'\n'"$j"$'\n'*) ;; *) jobs="$jobs$j"$'\n' ;; esac
  done <<< "$changed"
  jobs=$(printf '%s' "$jobs" | head -n "$MAX_FILES")
  [ -n "$jobs" ] || exit 0

  # Keyed on the context, hashed: a subagent shares its parent's session_id, and a raw path as a filename names parents that never exist.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  # Unwritable state means silence: a finding that cannot be recorded as said would repeat on every export.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  find "$dir" -maxdepth 1 -name 'sheet-seen-*' -mmin +1440 -delete 2>/dev/null
  seen="$dir/sheet-seen-$ctx"

  here="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/scripts"
  to=""
  command -v timeout >/dev/null 2>&1 && to="timeout $CHECK_TIMEOUT"
  shown=""; nshown=0; more=0; used=""
  while IFS=$'\t' read -r kind f; do
    [ -n "$f" ] || continue
    if [ "$kind" = "map" ]; then script="check_tilemaps.py"; else script="check_sprite_sheet.py"; fi
    out=$($to python3 "$here/$script" "$f" --max-issues 0 2>/dev/null)
    [ $? -le 1 ] || continue                     # 2: not a sheet or map after all; 124: timed out
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      key=$(printf '%s|%s|%s' "$f" "$l" "$(wc -c < "$f" 2>/dev/null)" | cksum | cut -d' ' -f1)
      grep -qxF "$key" "$seen" 2>/dev/null && continue
      if [ "$nshown" -lt "$MAX_SHOWN" ]; then
        printf '%s\n' "$key" >> "$seen" 2>/dev/null || exit 0
        shown="$shown${f#"$sroot"/}: ${l%% *} ${l#*: }"$'\n'; nshown=$((nshown + 1))
        case "$used" in *"$script"*) ;; *) used="$used${used:+, }$script" ;; esac
      else
        more=$((more + 1))
      fi
    done < <(printf '%s\n' "$out" | grep -E '^(ERROR|WARNING) ')
  done <<< "$jobs"
  [ "$nshown" -gt 0 ] || exit 0

  msg="pixel-art: $used on the sprite sheet or map file(s) this $tool call changed:"$'\n'"$shown"
  [ "$more" -gt 0 ] && msg="$msg(+$more more: python3 \"$here/<script>\" <file>)"$'\n'
  msg="${msg}An ERROR loads broken in the engine (frames outside the image, tags past the frames array, a missing tileset, wrong layer length); fix the export or the file before wiring it in. A WARNING is drift worth a look."
  jq -cn --arg e "$event" --arg c "$msg" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
} 2>/dev/null
exit 0
