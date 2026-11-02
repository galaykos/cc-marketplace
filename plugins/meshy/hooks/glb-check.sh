#!/bin/bash
# PreToolUse marks, PostToolUse/PostToolUseFailure measures: a .glb/.gltf a Write/Edit names, or one whose ctime moved during a Bash call naming glb/gltf/meshy or a Meshy MCP download, runs through inspect_glb.py at 15,000 triangles and 2,048 px; a broken budget, required extension, missing file or unreadable model is added once per context.
# Misses: a Bash call that lands a model without naming glb/gltf/meshy (unzip, a script), files outside the project root or past MAX_FILES, a call whose PreToolUse did not run, a run past CHECK_TIMEOUT; reads too much: a parallel call's model lands in this call's window. Warn-only, fail-open. Off: CC_GLB_CHECK=off, or /config.
# Why, limits, history: rationale/derivations/plugin-meshy.md § plugins/meshy/hooks/glb-check.sh

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

{
  [ "$(cc_option CC_GLB_CHECK on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  MAX_TRIS=15000      # the budget the meshy README and skill use as their example
  MAX_TEXTURE=2048    # px, longest image side
  MAX_FILES=4         # models measured per call
  CHECK_TIMEOUT=20    # seconds for one inspect_glb.py run; hooks.json allows 30

  event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  sroot=$(cc_state_root "$cwd") || exit 0
  dir=$(cc_plugin_state "$sroot" meshy)

  # A call that can land a model without naming its path (curl -o, a download script, Meshy's MCP
  # download) is bracketed: PreToolUse drops a marker named for the tool_use_id, PostToolUse lists
  # the .glb/.gltf files whose ctime moved after it. ctime, not mtime: mv and cp -p keep the mtime.
  call=$(printf '%s' "$input" | jq -r '.tool_use_id // empty' 2>/dev/null)
  mark=""
  [ -n "$call" ] && mark="$dir/glb-call-$(printf '%s' "$call" | cksum | cut -d' ' -f1)"
  bracketed=0
  case "$tool" in
    Bash) printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null | grep -qiE 'glb|gltf|meshy' && bracketed=1 ;;
    mcp__*) case "$tool" in *[Dd]ownload*) bracketed=1 ;; esac ;;
  esac

  if [ "$event" = "PreToolUse" ]; then
    [ "$bracketed" = 1 ] && [ -n "$mark" ] || exit 0
    mkdir -p "$dir" 2>/dev/null || exit 0
    [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
    find "$dir" -maxdepth 1 -name 'glb-call-*' -mmin +120 -delete 2>/dev/null
    : > "$mark" 2>/dev/null
    exit 0
  fi
  case "$event" in PostToolUse|PostToolUseFailure) ;; *) exit 0 ;; esac

  files=""
  case "$tool" in
    Write|Edit|MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      case "$fp" in /*) ;; *) fp="$cwd/$fp" ;; esac
      case "$fp" in *.glb|*.gltf|*.GLB|*.GLTF) [ -f "$fp" ] && files="$fp"$'\n' ;; esac
      ;;
    *)
      [ -n "$mark" ] && [ -f "$mark" ] || exit 0
      saved=$(printf '%s' "$input" | jq -r '.tool_input.save_to // empty' 2>/dev/null)
      case "$saved" in /*.glb|/*.gltf) [ -f "$saved" ] && files="$saved"$'\n' ;; esac
      files="$files$(find "$sroot" \( -name .git -o -name node_modules -o -name Library -o -name Temp -o -name .venv -o -name .claude \) -prune \
        -o -type f \( -iname '*.glb' -o -iname '*.gltf' \) -cnewer "$mark" -print 2>/dev/null | head -n "$MAX_FILES")"
      rm -f "$mark" 2>/dev/null
      ;;
  esac
  files=$(printf '%s\n' "$files" | awk 'NF && !seen[$0]++' | head -n "$MAX_FILES")
  [ -n "$files" ] || exit 0

  # Keyed on the context, hashed: a subagent shares its parent's session_id, and a raw path as a filename names parents that never exist.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  # Unwritable state means silence: a report that cannot be recorded as said would repeat on every call.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  find "$dir" -maxdepth 1 -name 'glb-seen-*' -mmin +1440 -delete 2>/dev/null
  seen="$dir/glb-seen-$ctx"

  to=""
  command -v timeout >/dev/null 2>&1 && to="timeout $CHECK_TIMEOUT"
  checker="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/scripts/inspect_glb.py"
  [ -f "$checker" ] || exit 0
  json=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 $to python3 "$checker" --max-tris "$MAX_TRIS" --max-texture "$MAX_TEXTURE" --json 2>/dev/null)
  rows=$(printf '%s' "$json" | jq -r '.files[]?
    | if .error then "\(.path)\tunreadable as glTF 2.0: \(.error)"
      elif ((.failures // []) | length) > 0 then "\(.path)\t\(.failures | join("; "))"
      else empty end' 2>/dev/null)
  [ -n "$rows" ] || exit 0

  shown=""; n=0
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    f="${r%%$'\t'*}"
    key=$(printf '%s|%s|%s' "$r" "$(wc -c < "$f" 2>/dev/null)" "$ctx" | cksum | cut -d' ' -f1)
    grep -qxF "$key" "$seen" 2>/dev/null && continue
    printf '%s\n' "$key" >> "$seen" 2>/dev/null || exit 0
    shown="$shown- ${f#"$sroot"/}: ${r#*$'\t'}"$'\n'; n=$((n + 1))
  done <<< "$rows"
  [ "$n" -gt 0 ] || exit 0

  msg="meshy: inspect_glb.py on the model(s) this $tool call wrote, against $MAX_TRIS triangles and $MAX_TEXTURE px textures:"$'\n'"$shown"
  msg="${msg}Over budget: remesh with a target_polycount (Meshy charges per remesh) or decimate in Blender, and resize the textures; do not import it as is. Unreadable: the download is incomplete or not glTF, so fetch it again from the task, never by creating a new task. A different budget for this asset is the user's call: rerun python3 \"$checker\" <file> --max-tris N --max-texture PX."
  jq -cn --arg e "$event" --arg c "$msg" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
} 2>/dev/null
exit 0
