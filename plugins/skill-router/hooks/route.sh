#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH, where `env bash` itself exits 127.
# PostToolUse router. Given the edited file, match rules.tsv and inject one
# directive to load the relevant skill — high-confidence path/ext matches fire
# inline once per signal per session; low-confidence content matches accumulate
# into the session-state digest. All inline nudges for one edit are delivered as
# a SINGLE {"hookSpecificOutput":{"hookEventName":"PostToolUse",
# "additionalContext":...}} envelope — the one non-blocking channel the
# executing model actually receives; plain stdout with exit 0 never reaches it
# (same channel doctrine as task-runner/hooks/scope.sh and
# comment-discipline/hooks/scan.sh). Fail-open: any error, or a
# missing jq, exits silently and never blocks the edit.
# Honest limitations: (1) state writes are read-modify-write with no lock —
# two concurrent invocations in one session can drop a pending_low entry
# (tool calls are serialized in practice; not worth a lock). (2) `fired`
# dedup is per SESSION while delivery is per CONTEXT — a fresh subagent
# context can be silently deduped by a nudge the main context already got.
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

  # Sibling plugins directory, for the installed-plugin filter. Resolved by
  # hooks/plugins-dir.sh, which handles both the flat and the versioned-cache
  # layouts — see that file's header for why dirname alone silently disabled this
  # hook on every real install. Empty when it cannot be determined, and empty
  # means fire anyway (bias to surface). A missing lib lands on the same default.
  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$(dirname "$0")/plugins-dir.sh" 2>/dev/null
  command -v pr_resolve_plugins_dir >/dev/null 2>&1 && pr_resolve_plugins_dir

  state_dir="$cwd/.claude/skill-router"
  state_file="$state_dir/fired-$session_id.json"
  fired=""
  [ -r "$state_file" ] && fired=$(jq -r '.fired[]? // empty' "$state_file" 2>/dev/null)

  base=$(basename "$file_path")

  plugin_installed() { # $1 owning_plugin — fire-if-uncertain
    command -v pr_plugin_installed >/dev/null 2>&1 || return 0
    pr_plugin_installed "$1"
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

  marker_ok() { # $1 stack_marker — 0 = fire, 1 = suppress. `||`-separated
    # alternatives, each `[!]<manifest>~<ERE>`, tried in order: the FIRST
    # decisive alternative wins — its grep verdict (exit 0 fire / exit 1
    # suppress, after `!` inversion) is final, so an authoritative source
    # (installed node_modules version) listed first overrides a looser declared
    # range behind it. Indecisive alternatives — absent/unreadable manifest,
    # missing `~`, empty side, grep exit >= 2 — are skipped. No decisive
    # alternative at all fires: an undetectable stack keeps today's behavior.
    local list="$1" alt m neg manifest regex mcontent rc
    [ -z "$list" ] || [ "$list" = "-" ] && return 0
    while [ -n "$list" ]; do
      alt="${list%%||*}"
      if [ "$alt" = "$list" ]; then list=""; else list="${list#*||}"; fi
      m="$alt"; neg=0
      case "$m" in '!'*) neg=1; m="${m#!}" ;; esac
      manifest="${m%%~*}"
      regex="${m#*~}"
      [ "$manifest" = "$m" ] && continue
      [ -n "$manifest" ] && [ -n "$regex" ] || continue
      [ -f "$cwd/$manifest" ] && [ -r "$cwd/$manifest" ] || continue
      mcontent=$(head -c 65536 "$cwd/$manifest" 2>/dev/null) || continue
      printf '%s' "$mcontent" | grep -qE "$regex" 2>/dev/null
      rc=$?
      [ "$rc" -ge 2 ] && continue
      [ "$neg" -eq 1 ] && rc=$((1 - rc))
      return "$rc"
    done
    return 0
  }

  nudges=""
  emit_nudge() { # $1 skill, $2 owning_plugin — accumulates; delivered once below.
    # When the SKILL.md is locatable, name its path: a subagent context has no
    # Skill tool, so "load the skill" is only actionable there as a Read.
    # Under a versioned cache the SKILL.md sits one level below the plugin dir, so
    # the path comes from pr_plugin_root rather than a join onto the plugins root.
    local sp="" proot=""
    command -v pr_plugin_root >/dev/null 2>&1 && proot=$(pr_plugin_root "$2")
    [ -n "$proot" ] && [ -f "$proot/skills/$1/SKILL.md" ] && sp=" — Read $proot/skills/$1/SKILL.md"
    nudges="${nudges}$(printf '[skill-router] This edit touches %s — load the `%s` skill (%s plugin) and review your change against it before continuing.%s' "$base" "$1" "$2" "$sp")"$'\n'
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
    conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
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

  # ---- deliver: ONE envelope per invocation, before state persistence so an
  # unwritable state dir cannot swallow a nudge the model should have seen ----
  if [ -n "$nudges" ]; then
    jq -cn --arg ctx "${nudges%$'\n'}" \
      '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
  fi

  # ---- low-confidence pass: accumulate content matches (no inline output) ----
  target="$cwd/$file_path"
  case "$file_path" in /*) target="$file_path" ;; esac
  content=""
  [ -r "$target" ] && content=$(head -c 65536 "$target" 2>/dev/null)
  pending_adds=""
  if [ -n "$content" ]; then
    while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
      case "$stype" in ''|'#'*) continue ;; esac
      conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
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
