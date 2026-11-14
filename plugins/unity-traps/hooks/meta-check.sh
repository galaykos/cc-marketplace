#!/bin/bash
# PostToolUse/PostToolUseFailure, a Bash call whose mv, cp, rm, rsync, ln, git mv|rm, find -delete or shutil/os/fs/File call names an Assets/ path or runs with cwd inside Assets/, or a Write/Edit of an Assets/*.meta: runs check_unity_project.py on the Unity project above it and adds errors anywhere plus warnings on the touched paths, each once per context.
# Misses: a path in a variable, a relative path after an in-command cd (warnings filtered out), a move by a tool it does not name (make, an IDE), findings past MAX_SHOWN, projects past MAX_PROJECTS, a run past CHECK_TIMEOUT, api-* name findings (not move damage); a verb in a heredoc body triggers a run. Warn-only, fail-open. Off: CC_UNITY_META_CHECK=off, or /config.
# Why, limits, history: rationale/derivations/plugin-unity-traps.md § plugins/unity-traps/hooks/meta-check.sh

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

# A command word that moves, copies or deletes a path: shell tools, git, find -delete, and the
# interpreter calls an agent reaches for (Python shutil/os/pathlib, Node fs, .NET File/Directory).
# A copy into Assets/ should arrive without a .meta, so missing-meta is news only after a move or rename.
MOVES='(^|[;&|({[:space:]])(mv|git[[:space:]]+mv)[[:space:]]|shutil\.move|os\.(rename|replace)|\.(rename|replace|renameSync)\(|(File|Directory)\.Move'
VERBS='(^|[;&|({[:space:]])(mv|cp|rm|rmdir|rsync|ln|install|unlink)[[:space:]]|(^|[;&|({[:space:]])git[[:space:]]+(mv|rm)[[:space:]]|[[:space:]]-delete([[:space:];&|)]|$)|shutil\.(move|copy|copy2|copyfile|copytree|rmtree)|os\.(rename|replace|remove|unlink|rmdir)|\.(rename|replace|unlink|rmSync|renameSync|copyFileSync|cpSync)\(|(File|Directory)\.(Move|Copy|Delete)'

{
  [ "$(cc_option CC_UNITY_META_CHECK on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  MAX_TOUCHED=16      # path tokens read from one command
  MAX_PROJECTS=2      # Unity projects checked per call
  MAX_SHOWN=6         # findings printed per call; the rest are counted
  CHECK_TIMEOUT=20    # seconds per checker run (0.74 s on a 40,201-file project); hooks.json allows 45

  checker="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/scripts/check_unity_project.py"
  [ -f "$checker" ] || exit 0

  event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null)
  case "$event" in PostToolUse|PostToolUseFailure) ;; *) exit 0 ;; esac
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

  touched=""; moved=0
  case "$tool" in
    Bash)
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      # A shell already inside Assets/ names no Assets path: cwd itself is the touched path then.
      incwd=0
      case "$cwd" in */Assets|*/Assets/*) incwd=1 ;; esac
      case "$cmd" in *Assets*) ;; *) [ "$incwd" = 1 ] || exit 0 ;; esac
      printf '%s\n' "$cmd" | grep -qE "$VERBS" || exit 0
      printf '%s\n' "$cmd" | grep -qE "$MOVES" && moved=1
      [ "$incwd" = 1 ] && touched="$cwd"$'\n'
      while IFS= read -r t; do
        [ -n "$t" ] || continue
        case "$t" in /*) ;; *) t="$cwd/$t" ;; esac
        touched="$touched$t"$'\n'
      done < <(printf '%s\n' "$cmd" | grep -oE "[^'\"[:space:],()=;&|<>]*Assets(/[^'\"[:space:],()=;&|<>*?]*)?" | head -n "$MAX_TOUCHED")
      ;;
    Write|Edit|MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      case "$fp" in */Assets/*.meta) ;; *) exit 0 ;; esac
      case "$fp" in /*) ;; *) fp="$cwd/$fp" ;; esac
      touched="$fp"$'\n'
      ;;
    *) exit 0 ;;
  esac
  [ -n "$touched" ] || exit 0

  find_project() {
    local d="$1" i=0
    while [ -n "$d" ] && [ "$i" -lt 12 ]; do
      [ -f "$d/ProjectSettings/ProjectVersion.txt" ] && { printf '%s\n' "$d"; return 0; }
      [ "$d" = "/" ] && return 1
      d=$(dirname -- "$d"); i=$((i + 1))
    done
    return 1
  }
  projects=""
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    p=$(find_project "$(dirname -- "$t")") || continue
    case $'\n'"$projects" in *$'\n'"$p"$'\n'*) ;; *) projects="$projects$p"$'\n' ;; esac
  done <<< "$touched"
  [ -n "$projects" ] || { p=$(find_project "$cwd") && projects="$p"$'\n'; }
  [ -n "$projects" ] || exit 0

  # Keyed on the context, hashed: a subagent shares its parent's session_id, and a raw path as a filename names parents that never exist.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  sroot=$(cc_state_root "$cwd") || exit 0
  dir=$(cc_plugin_state "$sroot" unity-traps)
  # Unwritable state means silence: a finding that cannot be recorded as said would repeat on every move.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  find "$dir" -maxdepth 1 -name 'meta-seen-*' -mmin +1440 -delete 2>/dev/null
  seen="$dir/meta-seen-$ctx"

  to=""
  command -v timeout >/dev/null 2>&1 && to="timeout $CHECK_TIMEOUT"
  shown=""; nshown=0; more=0; nproj=0; where=""
  while IFS= read -r proj; do
    [ -n "$proj" ] || continue
    nproj=$((nproj + 1)); [ "$nproj" -le "$MAX_PROJECTS" ] || break
    json=$($to python3 "$checker" "$proj" --json --max-issues 0 2>/dev/null)
    [ $? -le 1 ] || continue                     # 2: not a project or usage; 124: timed out
    rels=$(while IFS= read -r t; do case "$t" in "$proj"/*) printf '%s\n' "${t#"$proj"/}" ;; esac; done <<< "$touched")
    # Errors anywhere; warnings only on a touched path, its .meta, or below a touched folder. API names are not move damage.
    lines=$(printf '%s' "$json" | jq -r --arg rels "$rels" --argjson moved "$moved" '
      ($rels | split("\n") | map(select(length > 0) | sub("/+$"; ""))) as $t
      | def hit($f): any($t[]; . as $p | $f == $p or $f == ($p + ".meta") or ($f | startswith($p + "/")) or ($f | sub("\\.meta$"; "")) == $p);
        def row($lvl): "\($lvl) \(.code) \(.file)\(if .line then ":\(.line)" else "" end): \(.message)\t  fix: \(.fix)";
        (.errors[]? | select(.code | startswith("api-") | not) | row("ERROR")),
        (.warnings[]? | select(hit(.file) and ($moved == 1 or .code != "missing-meta") and (.code | startswith("api-") | not)) | row("WARNING"))' 2>/dev/null)
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      key=$(printf '%s|%s' "$proj" "${l%%$'\t'*}" | cksum | cut -d' ' -f1)
      grep -qxF "$key" "$seen" 2>/dev/null && continue
      if [ "$nshown" -lt "$MAX_SHOWN" ]; then
        printf '%s\n' "$key" >> "$seen" 2>/dev/null || exit 0
        shown="$shown${l%%$'\t'*}"$'\n'"${l#*$'\t'}"$'\n'; nshown=$((nshown + 1))
        case $'\n'"$where" in *$'\n'"$proj"$'\n'*) ;; *) where="$where$proj"$'\n' ;; esac
      else
        more=$((more + 1))
      fi
    done <<< "$lines"
  done <<< "$projects"
  [ "$nshown" -gt 0 ] || exit 0

  first=$(printf '%s' "$where" | head -n 1)
  msg="unity-traps: check_unity_project.py after this $tool call, in $first — $nshown new finding(s) (errors anywhere, warnings on the paths it touched):"$'\n'"$shown"
  [ "$more" -gt 0 ] && msg="$msg(+$more more: python3 \"$checker\" \"$first\")"$'\n'
  msg="${msg}An asset and its .meta move, copy and delete together; a copy needs its own GUID (drop the copied .meta and let Unity reimport). Fix these before building on the move."
  jq -cn --arg e "$event" --arg c "$msg" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
} 2>/dev/null
exit 0
