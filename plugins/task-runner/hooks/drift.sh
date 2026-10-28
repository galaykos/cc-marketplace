#!/bin/bash
# PostToolUse on Edit/Write/MultiEdit with no registered run: asks once per request when 12+ files (p90 of measured edit-turns) were edited since the last typed message and at least half go unnamed in it; new-directory files and breadth words ("rename", "everywhere") exempt.
# Misses: depth inside a named file, a fan-out's total, a request built over several messages, wide phrasings off the word list; advisory. CC_REMIND=off or CC_DRIFT=off, else /config cc_remind / cc_drift; fails open.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/hooks/drift.sh

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
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  [ "$(cc_option CC_DRIFT on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  # `-d`, not just `-n`: the mkdir below would recreate a project directory the user deleted; no directory means no state to keep.
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  # Nothing in .claude/task-runner/ belongs in a commit: the first hook to see the directory makes it ignore itself.
  tr_dir="$root/.claude/task-runner"
  if [ -d "$tr_dir" ] && [ ! -e "$tr_dir/.gitignore" ]; then printf '*\n' > "$tr_dir/.gitignore" 2>/dev/null; fi

  # A registered run, not a scope file, hands the turn to scope.sh: a leftover scope.json would mute both hooks.
  [ -r "$root/.claude/task-runner/active-run.json" ] && exit 0

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  [ -n "$tp" ] && [ -r "$tp" ] || exit 0            # no transcript → nothing to compare against

  # The threshold is the p90 of 169 measured edit-turns; re-derive it from your own transcripts before changing it.
  DRIFT_FLOOR=12          # p90 of 169 measured edit-turns; see the header
  UNNAMED_RATIO=2         # at least half the files unnamed in the ask (1/N where N=2)

  # Transcript lines are JSON objects, not JSON-encoded strings: `fromjson` would discard every one and silence the hook.
  tail_json=$(tail -n 900 "$tp" 2>/dev/null)
  [ -n "$tail_json" ] || exit 0

  ask=$(printf '%s\n' "$tail_json" | jq -rs '
      (map(select(.type=="user" and (.message.content|type=="string"))) | last | .message.content) // ""
    ' 2>/dev/null)
  [ -n "$ask" ] || exit 0

  # One slurp emits both lists: "F <path>" for each file edited since the request, "C <path>" for each it created.
  since=$(printf '%s\n' "$tail_json" | jq -rs '
      (map(.type=="user" and (.message.content|type=="string")) | rindex(true)) as $i
      | (if $i == null then [] else .[$i+1:] end)
      | (map(.message.content // [] | if type=="array" then .[] else empty end
            | select(.type=="tool_use")
            | select(.name=="Edit" or .name=="Write" or .name=="MultiEdit")
            | .input.file_path // empty)
         | unique | .[] | "F " + .),
        (map(.toolUseResult | select(type=="object" and .type=="create") | .filePath // empty) | .[] | "C " + .)
    ' 2>/dev/null)
  files=$(printf '%s\n' "$since" | sed -n 's/^F //p')
  count=$(printf '%s\n' "$files" | grep -c . 2>/dev/null)
  [ "${count:-0}" -ge "$DRIFT_FLOOR" ] || exit 0

  # Files in a directory holding only files this request created are the ask's new feature, not strays.
  created=$( { printf '%s\n' "$since" | sed -n 's/^C //p'
    printf '%s' "$input" | jq -r 'select(.tool_response.type? == "create") | .tool_input.file_path // empty' 2>/dev/null
  } | grep . | sort -u)
  if [ -n "$created" ]; then
    nc=$(printf '%s\n' "$created" | grep -c .)
    kept=""; newdirs=""; olddirs=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      d=$(dirname "$f")
      if printf '%s\n' "$created" | grep -qxF -- "$f"; then
        case "$d/" in "$root"/?*/) ;; *) olddirs="$olddirs$d
" ;; esac
        if ! printf '%s' "$newdirs$olddirs" | grep -qxF -- "$d"; then
          listed=$(find "$d" -type f 2>/dev/null | head -n $((nc + 1)))
          if [ -n "$listed" ] && [ -z "$(printf '%s\n' "$listed" | grep -vxF -- "$created")" ]; then newdirs="$newdirs$d
"; else olddirs="$olddirs$d
"; fi
        fi
        printf '%s' "$newdirs" | grep -qxF -- "$d" && continue
      fi
      kept="$kept$f
"
    done <<EOF
$files
EOF
    files=$kept
    count=$(printf '%s' "$files" | grep -c . 2>/dev/null)
    [ "${count:-0}" -ge "$DRIFT_FLOOR" ] || exit 0
  fi

  printf '%s' "$ask" | grep -qiE '\b(everywhere|every file|all (the )?(files|of them)|across the|entire|whole (repo|codebase|project)|rename|migrate|sweep|bulk|each of|throughout|codebase-wide|repo-wide)\b' && exit 0

  unnamed=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    b=$(basename "$f")
    printf '%s' "$ask" | grep -qF "$b" || unnamed=$((unnamed + 1))
  done <<EOF
$files
EOF
  [ $((unnamed * UNNAMED_RATIO)) -ge "$count" ] || exit 0

  # One question per user message, keyed on transcript and ask, hashed: a raw path in a filename names parents that never exist.
  ctx=$(printf '%s%s' "$tp" "$ask" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  dir="$root/.claude/task-runner"
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  marker="$dir/drift-$ctx"
  [ -e "$marker" ] && exit 0
  : > "$marker" 2>/dev/null || exit 0

  msg=$(printf 'task-runner: %s files edited since the request, %s of them not named in it. Breadth is not wrongness — a wide change can be exactly right. The question is whether each of those files was asked for, implied by what was asked, or picked up on the way past. If some were picked up, say so now rather than at the end. (Advisory: counts breadth only, never depth — an unasked refactor inside a named file is invisible to this. CC_DRIFT=off silences it.)' \
    "$count" "$unnamed")
  jq -cn --arg ctx "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
