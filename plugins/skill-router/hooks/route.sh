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

  rules="${CLAUDE_PLUGIN_ROOT}/rules.tsv"
  [ -f "$rules" ] || exit 0

  # Sibling plugins directory, for the installed-plugin filter. Empty when
  # CLAUDE_PLUGIN_ROOT is unset — in that case we fire anyway (bias to surface).
  plugins_dir=""
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && plugins_dir="$(dirname "$CLAUDE_PLUGIN_ROOT")"

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

  marker_ok() { # $1 stack_marker — 0 = fire, 1 = suppress. Fail-open: absent
    # manifest, missing `~`, empty regex, or a grep error (exit >= 2) all fire;
    # only a clean no-match (exit 1) suppresses. `!` inverts the 0/1 verdict only.
    local m="$1" neg=0 manifest regex mcontent rc
    [ -z "$m" ] || [ "$m" = "-" ] && return 0
    case "$m" in '!'*) neg=1; m="${m#!}" ;; esac
    manifest="${m%%~*}"
    regex="${m#*~}"
    [ "$manifest" = "$m" ] && return 0
    [ -n "$manifest" ] && [ -n "$regex" ] || return 0
    [ -f "$cwd/$manifest" ] && [ -r "$cwd/$manifest" ] || return 0
    mcontent=$(head -c 65536 "$cwd/$manifest" 2>/dev/null) || return 0
    printf '%s' "$mcontent" | grep -qE "$regex" 2>/dev/null
    rc=$?
    [ "$rc" -ge 2 ] && return 0
    if [ "$neg" -eq 1 ]; then rc=$((1 - rc)); fi
    return "$rc"
  }

  emit_nudge() { # $1 skill, $2 owning_plugin
    printf '[skill-router] This edit touches %s — load the `%s` skill (%s plugin) and review your change against it before continuing.\n' "$base" "$1" "$2"
  }

  # ---- high-confidence pass: EVERY surviving, not-yet-fired match nudges ----
  # All relevant skills for THIS edit fire (e.g. a11y alongside ui-ux, and the
  # stack skill, on a single .tsx) — no break after the first. Session dedup via
  # `fired` still prevents re-nudging the same skill on later edits; emitted_now
  # dedups two rules that map to one skill within this single edit.
  fired_now=""
  emitted_now=""
  while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
    case "$stype" in ''|'#'*) continue ;; esac
    [ "$stype" = glob ] && [ "$conf" = high ] || continue
    match_glob "$pattern" || continue
    plugin_installed "$plugin" || continue
    marker_ok "$marker" || continue
    already_fired "$skill" && continue
    printf '%s\n' "$emitted_now" | grep -qxF "$skill" && continue
    emit_nudge "$skill" "$plugin"
    emitted_now="${emitted_now}${skill}"$'\n'
    fired_now="${fired_now}${skill}"$'\n'
  done < "$rules"

  # ---- low-confidence pass: accumulate content matches (no inline output) ----
  target="$cwd/$file_path"
  case "$file_path" in /*) target="$file_path" ;; esac
  content=""
  [ -r "$target" ] && content=$(head -c 65536 "$target" 2>/dev/null)
  pending_adds=""
  if [ -n "$content" ]; then
    while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
      case "$stype" in ''|'#'*) continue ;; esac
      [ "$stype" = content ] || continue
      plugin_installed "$plugin" || continue
      marker_ok "$marker" || continue
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
      while IFS= read -r fskill; do
        [ -n "$fskill" ] || continue
        json=$(printf '%s' "$json" | jq --arg s "$fskill" \
          'if (.fired | index($s) | not) then .fired += [$s] else . end' 2>/dev/null) || exit 0
      done <<EOF_FIRED
$fired_now
EOF_FIRED
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
