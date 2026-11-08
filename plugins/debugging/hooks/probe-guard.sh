#!/bin/bash
# probe-guard.sh — PreToolUse on Bash: a `git commit` at a command position whose staged diff (with -a or --all, the diff against HEAD) adds a line holding `[DEBUG-` gets an ask, never a deny, naming the files and lines. Off: CC_PROBE_GUARD=off (unset: /config option cc_probe_guard). Fails open: no jq or git, not a repository, or any error is silent.
# Misses: a commit run through a variable, alias, script or another tool; pathspec, --only and --include content outside the index; a marker already in the commit --amend rewrites; a `cd` or `git -C` into another repository; another marker spelling. Asks on purpose for a doc line quoting the marker.
# Why, limits, history: rationale/derivations/plugin-debugging.md § plugins/debugging/hooks/probe-guard.sh

set -u

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

MARKER='[DEBUG-'
MAX_NAMES=5
# git-workflow's no-ai-trailer.sh GIT_WRITE_RE anchor and wrapper tokens with the verb commit only, plus a `-C <dir>` or `-c <key>=<value>` pair.
COMMIT_RE='(^|[;&|`()]|\$\()[[:space:]]*(([a-z_][a-z0-9_]*=[^[:space:]]*|bash|sh|zsh|dash|ksh|eval|exec|command|sudo|doas|env|nohup|timeout|nice|time|xargs|then|do|else|elif|if|while|until|-[-a-z0-9]*|[0-9]+|"|'"'"')[[:space:]]*)*([^[:space:]]*/)?git([[:space:]]+(-[Cc][[:space:]]+[^-[:space:]][^[:space:]]*|-[^[:space:]]*|[/.~][^[:space:]]*|[^[:space:]]*=[^[:space:]]*))*[[:space:]]+commit([[:space:]]|$)'

# 0 when the commit's own options hold -a or --all; quoted values are dropped first, and a cluster stops at an option that takes a value.
commits_all() {
  local args t f c
  args=$(printf '%s' "${1#*commit}" | sed -E "s/\"[^\"]*\"//g; s/'[^']*'//g")
  read -r -a args <<< "$args"
  for t in ${args[@]+"${args[@]}"}; do
    case "$t" in
      --) return 1 ;;
      --all) return 0 ;;
      --*) ;;
      -?*)
        f=${t#-}
        while [ -n "$f" ]; do
          c=${f:0:1}; f=${f:1}
          case "$c" in a) return 0 ;; [mFcCt]) break ;; esac
        done ;;
    esac
  done
  return 1
}

main() {
  command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || exit 0
  [ "$(cc_option CC_PROBE_GUARD on)" = off ] && exit 0
  local input cmd m dir range hits n where reason
  input=$(cat 2>/dev/null) || exit 0
  case "$input" in *commit*) ;; *) exit 0 ;; esac
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
  [ -n "$cmd" ] || exit 0
  m=$(printf '%s' "$cmd" | tr '\n' ';' | grep -oiE "$COMMIT_RE[^;&|]*" | head -n 1)
  [ -n "$m" ] || exit 0
  dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$dir" ] && [ -d "$dir" ] || exit 0
  export GIT_OPTIONAL_LOCKS=0
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  range=--cached
  commits_all "$m" && git -C "$dir" rev-parse -q --verify HEAD >/dev/null 2>&1 && range=HEAD
  hits=$(git -C "$dir" -c core.quotePath=true -c core.fsmonitor=false -c diff.relative=false \
      diff "$range" --no-color --no-ext-diff --no-textconv -U0 --src-prefix=a/ --dst-prefix=b/ -G'\[DEBUG-' 2>/dev/null \
    | LC_ALL=C awk -v mk="$MARKER" -v max="$MAX_NAMES" '
        /^diff --git / { h = 0; next }
        !h && /^\+\+\+ / { f = substr($0, 5); sub(/^b\//, "", f); next }
        /^@@ / { h = 1; split($3, p, ","); ln = substr(p[1], 2) + 0; next }
        h && /^\+/ { if (index($0, mk)) { n++; if (n <= max) s = s (s == "" ? "" : ", ") f ":" ln }; ln++ }
        END { if (n > max) s = s " (+" (n - max) " more)"; if (n) printf "%d\t%s", n, s }')
  [ -n "$hits" ] || exit 0
  n=${hits%%$'\t'*}; where=${hits#*$'\t'}
  reason="debugging: this commit adds $n line(s) tagged $MARKER, the systematic-debugging probe marker: $where. Remove the probes and re-stage, or approve to commit them on purpose. CC_PROBE_GUARD=off turns this check off."
  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
}

main
exit 0
