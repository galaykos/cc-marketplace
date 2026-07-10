#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH, where `env bash` itself exits 127.
# PostToolUse router. Given the edited file, match rules.tsv and inject one
# directive to load the relevant skill — high-confidence path/ext matches fire
# inline once per signal per session; low-confidence content matches accumulate
# into the session-state digest for SessionEnd. Fail-open: any error, or a
# missing jq, exits silently and never blocks the edit.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$file_path" ] || exit 0
  [ -n "$session_id" ] || exit 0
  [ -n "$cwd" ] || exit 0

  rules="${PLUGIN_ROOT}/rules.tsv"
  [ -f "$rules" ] || exit 0

  # Sibling plugins directory, for the installed-plugin filter. Empty when
  # PLUGIN_ROOT is unset — in that case we fire anyway (bias to surface).
  plugins_dir=""
  [ -n "${PLUGIN_ROOT:-}" ] && plugins_dir="$(dirname "$PLUGIN_ROOT")"

  state_dir="$cwd/.claude/skill-router"
  state_file="$state_dir/fired-$session_id.json"
  fired=""
  [ -r "$state_file" ] && fired=$(jq -r '.fired[]? // empty' "$state_file" 2>/dev/null)

  base=$(basename "$file_path")

  plugin_installed() { # $1 owning_plugin — fire-if-uncertain
    [ -z "$plugins_dir" ] && return 0
    [ -d "$plugins_dir/$1" ] && return 0
    return 1
  }
  already_fired() { printf '%s\n' "$fired" | grep -qxF "$1"; }

  match_glob() { # $1 pattern
    local pat="$1"
    case "$pat" in
      '**/'*'/**')
        local mid="${pat#**/}"; mid="${mid%/**}"
        case "/$file_path" in *"/$mid/"*) return 0 ;; esac
        return 1 ;;
      *)
        case "$base" in $pat) return 0 ;; esac
        return 1 ;;
    esac
  }

  emit_nudge() { # $1 skill, $2 owning_plugin
    if [ "$1" = "ui-ux-stack" ]; then
      printf '[skill-router] This edit touches %s — load the ui-ux best-practice skill for this stack (shadcn/tailwind/bootstrap/css3/…) and review your change against it before continuing.\n' "$base"
    else
      printf '[skill-router] This edit touches %s — load the `%s` skill (%s plugin) and review your change against it before continuing.\n' "$base" "$1" "$2"
    fi
  }

  # ---- high-confidence pass: first surviving, not-yet-fired match nudges ----
  fired_now=""
  while IFS=$'\t' read -r stype pattern skill plugin conf || [ -n "$stype" ]; do
    case "$stype" in ''|'#'*) continue ;; esac
    [ "$stype" = glob ] && [ "$conf" = high ] || continue
    match_glob "$pattern" || continue
    plugin_installed "$plugin" || continue
    already_fired "$skill" && continue
    emit_nudge "$skill" "$plugin"
    fired_now="$skill"
    break
  done < "$rules"

  # ---- low-confidence pass: accumulate content matches (no inline output) ----
  target="$cwd/$file_path"
  case "$file_path" in /*) target="$file_path" ;; esac
  content=""
  [ -r "$target" ] && content=$(head -c 65536 "$target" 2>/dev/null)
  pending_adds=""
  if [ -n "$content" ]; then
    while IFS=$'\t' read -r stype pattern skill plugin conf || [ -n "$stype" ]; do
      case "$stype" in ''|'#'*) continue ;; esac
      [ "$stype" = content ] || continue
      plugin_installed "$plugin" || continue
      if printf '%s' "$content" | grep -qE "$pattern" 2>/dev/null; then
        pending_adds="${pending_adds}${skill}"$'\n'
      fi
    done < "$rules"
  fi

  # ---- persist state only if something changed ----
  if [ -n "$fired_now" ] || [ -n "$pending_adds" ]; then
    mkdir -p "$state_dir" 2>/dev/null || exit 0
    json='{"fired":[],"pending_low":[]}'
    if [ -r "$state_file" ]; then
      existing=$(cat "$state_file" 2>/dev/null)
      printf '%s' "$existing" | jq empty 2>/dev/null && json="$existing"
    fi
    if [ -n "$fired_now" ]; then
      json=$(printf '%s' "$json" | jq --arg s "$fired_now" \
        'if (.fired | index($s) | not) then .fired += [$s] else . end' 2>/dev/null) || exit 0
    fi
    if [ -n "$pending_adds" ]; then
      while IFS= read -r pskill; do
        [ -n "$pskill" ] || continue
        json=$(printf '%s' "$json" | jq --arg sk "$pskill" --arg f "$file_path" \
          'if (.pending_low | any(.skill==$sk and .file==$f)) then . else .pending_low += [{skill:$sk,file:$f}] end' 2>/dev/null) || break
      done <<EOF
$pending_adds
EOF
    fi
    printf '%s\n' "$json" > "$state_file" 2>/dev/null || exit 0
  fi
} 2>/dev/null
exit 0
