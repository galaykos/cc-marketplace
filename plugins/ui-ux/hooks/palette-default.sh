#!/bin/bash
# palette-default.sh (PostToolUse on Edit|Write|MultiEdit; payload on stdin) — names the indigo/violet/purple default accent once per
#   transcript and project when a written UI file carries it as a Tailwind class or a default swatch hex. Advisory: it always exits 0.
# Off: CC_REMIND=off silences every advisory nudge in this marketplace; CC_PALETTE=off only this one.
# CC_REMIND / CC_PALETTE unset: the /config options cc_remind / cc_palette decide.
# Misses: a composition (three equal cards, a ribbon on the middle one, a centred hero); a class name built at runtime (`bg-${tone}-500`)
#   or passed as a prop value (`color="indigo"`); an in-band hex that is not a default swatch. The file is already written: it informs the next edit.
# State: per project under CLAUDE_PLUGIN_DATA (cc_plugin_state); <root>/.claude/ui-ux/ is only the fallback.
# Why, limits, history: rationale/derivations/plugin-ui-ux.md § plugins/ui-ux/hooks/palette-default.sh

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
  [ "$(cc_option CC_PALETTE on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  [ -n "$fp" ] && [ -f "$fp" ] && [ -r "$fp" ] || exit 0
  case "$fp" in
    *.tsx|*.jsx|*.vue|*.svelte|*.astro|*.html|*.blade.php|*.css|*.scss) ;;
    *) exit 0 ;;
  esac

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0

  # Derived, not chosen: the families whose oklch hues sit in craft-layer's 275-315 default band; re-derive if the band moves.
  named=$(grep -oE '\b(bg|text|from|via|to|border|ring|shadow|decoration|outline|fill|stroke|accent|caret|divide)-(indigo|violet|purple)-[0-9]{2,3}\b' "$fp" 2>/dev/null | sort -u)
  # Swatch values, not a hue range: sRGB puts indigo-500 at 238.7 degrees, far below the oklch band these swatches sit in.
  hexes=$(grep -ioE '#(6366f1|818cf8|4f46e5|8b5cf6|a78bfa|7c3aed|a855f7|c084fc|9333ea)\b' "$fp" 2>/dev/null | sort -u)
  [ -n "$named$hexes" ] || exit 0

  dir=$(cc_plugin_state "$root" ui-ux)
  state="$dir/palette-$ctx"
  # A bound that cannot be recorded is not a bound: unwritable state means silence.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  [ -e "$state" ] && exit 0
  : > "$state" 2>/dev/null || exit 0
  [ -e "$state" ] || exit 0

  sample=$(printf '%s\n%s' "$named" "$hexes" | grep -v '^$' | head -4 | tr '\n' ' ')
  count=$(printf '%s\n%s' "$named" "$hexes" | grep -c . 2>/dev/null)
  msg=$(printf 'ui-ux: %s uses the category-default accent (%s— %s distinct). Indigo/violet/purple is what a generated UI reaches for when no palette was chosen; if it WAS chosen, it is fine and this says so once per session. Otherwise pick a hue the product argues for and put it in the theme tokens, not in class strings. Deeper: the design-tokens and shadcn-theming skills.' \
    "${fp##*/}" "$sample" "$count")
  jq -cn --arg ctx "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
