#!/bin/bash
# contract-check.sh — PostToolUse on Edit|Write|MultiEdit: when the project declares a design contract (.cc-artifacts/design-kit/design-system/contract.json), names lines a UI edit ADDED that build a surface by hand (rounded + border on a div) instead of the contract's component, use a raw Tailwind palette class, or an arbitrary hex/px value; advisory, always exits 0. Off: CC_REMIND=off or CC_DESIGN_CONTRACT=off.
# Misses: a class split across lines or built at runtime (`bg-${tone}-500`), a surface built with other utilities (shadow + padding, no border), CSS/SCSS files, writes made through Bash, and every line that existed before the edit (old debt is left alone on purpose).
# Why, limits, history: rationale/derivations/plugin-ui-ux.md § plugins/ui-ux/hooks/contract-check.sh

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

# Added lines only: an Edit's new_string lines its old_string lacks; a Write's lines git sees added since HEAD (all of an untracked file).
added_lines() {
  case "$tool" in
    Edit) jq -r '.tool_input.old_string // ""' <<<"$input" > "$tmp/old"; jq -r '.tool_input.new_string // ""' <<<"$input" > "$tmp/new" ;;
    MultiEdit) jq -r '[.tool_input.edits[]?.old_string // ""] | join("\n")' <<<"$input" > "$tmp/old"
               jq -r '[.tool_input.edits[]?.new_string // ""] | join("\n")' <<<"$input" > "$tmp/new" ;;
    Write)
      : > "$tmp/old"
      if git -C "$root" ls-files --error-unmatch -- "$fp" >/dev/null 2>&1; then
        git -C "$root" diff --no-color -U0 HEAD -- "$fp" 2>/dev/null | grep '^+' | grep -v '^+++' | cut -c2- > "$tmp/new"
      else
        cp -- "$fp" "$tmp/new"
      fi ;;
  esac
  grep -vxF -f "$tmp/old" "$tmp/new" 2>/dev/null || { [ -s "$tmp/old" ] || cat "$tmp/new"; }
}

{
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  [ "$(cc_option CC_DESIGN_CONTRACT on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0
  tool=$(jq -r '.tool_name // empty' <<<"$input" 2>/dev/null)
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac
  fp=$(jq -r '.tool_input.file_path // empty' <<<"$input" 2>/dev/null)
  [ -n "$fp" ] && [ -f "$fp" ] && [ -r "$fp" ] || exit 0
  case "$fp" in
    *.test.*|*.spec.*|*/__tests__/*|*/tests/*|*/stories/*|*.stories.*) exit 0 ;;
    *.tsx|*.jsx|*.vue|*.svelte|*.astro|*.html|*.blade.php) ;;
    *) exit 0 ;;
  esac

  cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  contract="$root/.cc-artifacts/design-kit/design-system/contract.json"
  [ -f "$contract" ] || contract="$root/design-system/contract.json"
  [ -f "$contract" ] && jq -e 'type == "object"' "$contract" >/dev/null 2>&1 || exit 0

  case "$fp" in "$root"/*) rel="${fp#"$root"/}" ;; *) exit 0 ;; esac
  under() { local p; while IFS= read -r p; do [ -n "$p" ] && case "$rel" in "${p%/}"/*|"$p") return 0 ;; esac; done; return 1; }
  jq -r '.primitives[]? // empty' "$contract" | under && exit 0
  if jq -e '(.scope // []) | length > 0' "$contract" >/dev/null 2>&1; then
    jq -r '.scope[]' "$contract" | under || exit 0
  fi
  shell_file=no; jq -r '.shell.owner[]? // empty' "$contract" | under && shell_file=yes
  surface=$(jq -r '.surface.component // empty' "$contract")
  import=$(jq -r '.surface.import // empty' "$contract")

  tmp=$(mktemp -d) || exit 0
  trap 'rm -rf "$tmp"' EXIT
  added_lines > "$tmp/added"
  [ -s "$tmp/added" ] || exit 0

  hits=""
  hit() { hits="${hits}  - \`$(printf '%s' "$1" | sed -E 's/^[[:space:]]+//' | cut -c1-90)\` → $2"$'\n'; }
  while IFS= read -r l; do
    if [ "$shell_file" = no ] && [ -n "$surface" ] && printf '%s' "$l" | grep -Eq '<(div|section|article|aside|li)\b' \
       && printf '%s' "$l" | grep -Eq '\brounded(-[a-z0-9]+)?\b' && printf '%s' "$l" | grep -Eq '\bborder\b'; then
      hit "$l" "a hand-built surface: use <$surface>${import:+ from $import}"
    elif printf '%s' "$l" | grep -Eq '\b(bg|text|border|ring|outline|fill|stroke|from|via|to|divide|shadow|decoration|accent|caret|placeholder)-(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-[0-9]{2,3}\b'; then
      hit "$l" "a raw palette class: use the theme's semantic token (bg-primary, text-muted-foreground, border-border …)"
    elif printf '%s' "$l" | grep -Eq '[a-z]-\[(#[0-9a-fA-F]{3,8}|[0-9.]+(px|rem)|rgba?\(|hsla?\(|oklch\()'; then
      hit "$l" "an arbitrary value: use a token or the spacing/type scale"
    fi
  done < "$tmp/added"
  [ -n "$hits" ] || exit 0

  n=$(printf '%s' "$hits" | grep -c .)
  shown=$(printf '%s' "$hits" | head -5)
  more=""; [ "$n" -gt 5 ] && more=$'\n'"  +$((n - 5)) more"
  msg=$(printf "ui-ux: %s adds %s line(s) the project's design contract (%s) rules out:\n%s%s\nFix them in this change unless the contract is wrong; then say so and update it. CC_DESIGN_CONTRACT=off turns this off." \
    "$rel" "$n" "${contract#"$root"/}" "$shown" "$more")
  jq -cn --arg ctx "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
} 2>/dev/null
exit 0
