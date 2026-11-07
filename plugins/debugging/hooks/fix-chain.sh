#!/bin/bash
# fix-chain.sh — UserPromptSubmit: one advisory line when this session has made two or more fix commits (subject fix/fixes/fixed/hotfix/bugfix, or a merged *fix* branch) that touch a common file; again at four. Fails open; CC_REMIND=off silences it.
# Misses: fixes not committed, fix commits with another subject, a chain across sessions, and another session committing in the same repo during this one (counted as ours).
# Why, limits, history: rationale/derivations/plugin-debugging.md § plugins/debugging/hooks/fix-chain.sh

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
{
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || exit 0
  input=$(cat)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  key=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -n "$key" ] || exit 0
  git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  dir="${TMPDIR:-/tmp}/cc-fixchain-$(printf '%s' "$key" | cksum | cut -d' ' -f1)"
  if [ ! -f "$dir/start" ]; then
    find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-fixchain-*' -type d -mmin +1440 -exec rm -rf {} + 2>/dev/null
    mkdir -p "$dir" && date +%s > "$dir/start"
    exit 0
  fi
  start=$(cat "$dir/start")
  case "$start" in '' | *[!0-9]*) exit 0 ;; esac
  fixes=$(git -C "$cwd" log --since="@$start" --format='%H%x09%s' 2>/dev/null \
    | grep -iE $'\t((hot|bug)?fix(es|ed)?\\b|Merge pull request .* from [^ ]*fix)' | cut -f1)
  n=$(printf '%s\n' "$fixes" | grep -c .)
  [ "$n" -ge 2 ] || exit 0
  shared=$(for c in $fixes; do git -C "$cwd" show --format= --name-only "$c" 2>/dev/null | sort -u; done | sort | uniq -d | head -n 1)
  [ -n "$shared" ] || exit 0
  level=2; [ "$n" -ge 4 ] && level=4
  mkdir "$dir/fired-$level" 2>/dev/null || exit 0
  printf 'debugging: %s fix commits this session touch %s, and each fix exposed the next failure: the diagnosis is likely wrong, not the fix. Reproduce the original symptom and test one hypothesis before another fix (/debugging:debug).\n' "$n" "$shared"
} 2>/dev/null
exit 0
