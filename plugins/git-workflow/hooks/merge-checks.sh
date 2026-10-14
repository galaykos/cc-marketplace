#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a broken PATH.
#
# PreToolUse readiness check on `gh pr merge`. Before the merge runs it reads the pull
# request's checks (`gh pr checks`, killed after CHECKS_TIMEOUT seconds) and returns
# permissionDecision "ask" when any check is pending, failing or cancelled, naming those
# checks and the off-switch. All green, no checks reported, or any error: silent, and the
# merge proceeds.
#
# The failure it exists for: a session ran `gh pr merge` while CI was still running, CI
# then failed on the merged commit, and the user had asked to wait for every check first.
# Nothing in the finish protocol reads CI state at the moment of the merge; the command
# is the one place that moment is visible.
#
# Tiering (ask, never deny): a pending or red check is usually a reason to wait, but a
# known-flaky or non-required check is a legitimate merge, and only the user knows which.
# The ask names the checks so that call takes one glance. In a headless run nobody answers
# an ask, so the merge does not happen there, which is the outcome this hook wants.
#
# A NETWORK READ IN A HOOK, against the house rule of no network calls: CI state lives only
# on GitHub, with no local stand-in. It is bounded (one `gh pr checks` per command, killed
# at CHECKS_TIMEOUT, well inside the hooks.json timeout), and every outcome that is not a
# parsed pending/failing row is silence: no gh, not logged in, no network, a timeout, no PR
# for the branch, no checks reported.
#
# WHAT IT READS: `gh pr merge` at a command position (after `;` `&&` `|` `(` `$(` or a
# wrapper such as `sudo`, `env`, `bash -c "…"`; the prefix list is no-ai-trailer.sh's),
# outside heredoc bodies. The PR is the first positional argument (number, `#n`, URL or
# branch; never a redirection or a quoted value), else the current branch's; `-R/--repo`
# and a `GH_REPO=`/`GH_HOST=` prefix are passed through; gh runs in the payload's cwd.
# Silent on purpose: `--help`, `--disable-auto`, and `--auto`, which hands the wait to
# GitHub (and is what the ask suggests).
#
# WHAT IT DOES NOT CATCH, stated: a PR or repo held in a variable or a substitution
# (`gh pr merge "$n"`); any `gh pr merge` after the first in one command; flags between
# `pr` and `merge`; a merge through the API, the web UI or a push to the base branch;
# non-required checks that `--auto` does not wait for. A `cd` inside the command does not
# move where gh runs, so `cd ../other && gh pr merge 3` reads PR 3 of the session's repo,
# and an `export GH_REPO=…` before it is not read; the ask names the PR, so a wrong one shows.
#
# CC_MERGE_CHECKS=off disables it for the session, and the ask message says so.
# CC_MERGE_CHECKS unset: the /config option cc_merge_checks decides.
# Fail-open: missing jq or gh, unparseable input, any internal error allows the merge.

set -u

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

CHECKS_TIMEOUT=5
MAX_NAMES=5

# Command position, the same anchor and wrapper tokens as no-ai-trailer.sh's GIT_WRITE_RE,
# so the two guards agree on what runs. The tail stops at the next command delimiter
# outside a quoted span. A span counts only where a word, a `=` or a one-letter flag opens
# it; any other quote closes a wrapper's string (`bash -c "gh pr merge 12"`) and ends it.
MERGE_Q='("[^"]*"|'"'"'[^'"'"']*'"'"')'
MERGE_C='([^[:space:];&|`()"'"'"']|[<>]&|&>)'
MERGE_RE='(^|[;&|`()]|\$\()[[:space:]]*(([a-z_][a-z0-9_]*=[^[:space:]]*|bash|sh|zsh|dash|ksh|eval|exec|command|sudo|doas|env|nohup|timeout|nice|time|xargs|then|do|else|elif|if|while|until|-[-a-z0-9]*|[0-9]+|"|'"'"')[[:space:]]*)*([^[:space:]]*/)?gh[[:space:]]+pr[[:space:]]+merge'"([[:space:]]+(-[a-z]$MERGE_Q|$MERGE_Q|$MERGE_C)($MERGE_C|=$MERGE_Q)*)*"

# A heredoc body is text, not a command: drop it before matching. Same awk as
# testing/hooks/protect-tests.sh's in-command `cd` test.
strip_bodies() {
  printf '%s\n' "$1" | awk '
    inh { if ($0 ~ ("^[\t]*" term "[ \t]*$")) inh = 0; next }
    { print; l = $0; gsub(/<<</, "", l); o = "<<-?[ \t]*[\"\047\\\\]?"
      if (match(l, o "[A-Za-z_][A-Za-z0-9_]*")) { term = substr(l, RSTART, RLENGTH); sub(o, "", term); inh = 1 } }'
}

# The quote character a word opens and does not close, else nothing.
open_quote() {
  case "$1" in
    \"*) case "${1#?}" in *\") ;; *) printf '"' ;; esac ;;
    \'*) case "${1#?}" in *\') ;; *) printf "'" ;; esac ;;
  esac
}

# Sets sel and repo from the words after `gh pr merge`, gh_repo and gh_host from a
# GH_REPO=/GH_HOST= prefix. Returns 1 when the call passes silently: help, --auto,
# --disable-auto, or a PR, repo or host this cannot resolve.
parse_merge() {
  local w a t r i=0 n skip=""
  read -r -a w <<< "$1"
  n=${#w[@]}
  while [ "$i" -lt "$n" ]; do
    t=${w[$i]##*[\"\'\(/\`\;\&\|]}
    [ "$t" = gh ] && [ "${w[$((i + 1))]:-}" = pr ] && [ "${w[$((i + 2))]:-}" = merge ] && break
    t=${w[$i]#"${w[$i]%%[!\"\'\(\`\;\&\|\$]*}"}
    case "$t" in
      GH_REPO=*) gh_repo=${t#GH_REPO=} ;;
      GH_HOST=*) gh_host=${t#GH_HOST=} ;;
    esac
    i=$((i + 1))
  done
  [ "$i" -lt "$n" ] || return 1
  i=$((i + 3))
  while [ "$i" -lt "$n" ]; do
    a=${w[$i]}; i=$((i + 1))
    if [ -n "$skip" ]; then
      case "$a" in *"$skip") skip="" ;; esac
      continue
    fi
    # A redirection is no argument; after a bare operator the target is the next word.
    r=${a#"${a%%[!0-9]*}"}
    case "$r" in
      '<'|'>'|'>>'|'<>'|'<<'|'<<-'|'<<<'|'>&'|'<&'|'&>'|'&>>') i=$((i + 1)); continue ;;
      [\<\>]*|'&>'*) continue ;;
    esac
    case "$a" in
      -h|--help|--auto|--disable-auto) return 1 ;;
      -R|--repo) repo=${w[$i]:-}; i=$((i + 1)) ;;
      --repo=*) repo=${a#--repo=} ;;
      -R?*) repo=${a#-R} ;;
      -b|--body|-F|--body-file|-t|--subject|-A|--author-email|--match-head-commit)
        skip=$(open_quote "${w[$i]:-}"); i=$((i + 1)) ;;
      --*=*) skip=$(open_quote "${a#*=}") ;;
      -[btFA]?*) skip=$(open_quote "${a#-?}") ;;
      -*) ;;
      *) [ -n "$sel" ] || sel=$a ;;
    esac
  done
  sel=${sel//[\"\']/}; repo=${repo//[\"\']/}
  gh_repo=${gh_repo//[\"\']/}; gh_host=${gh_host//[\"\']/}
  case "$sel" in *[!A-Za-z0-9._/:#-]*) return 1 ;; esac
  case "$repo$gh_repo" in *[!A-Za-z0-9._/:-]*) return 1 ;; esac
  case "$gh_host" in *[!A-Za-z0-9._:-]*) return 1 ;; esac
  return 0
}

# gh pr checks in <dir>, stdout only, killed after CHECKS_TIMEOUT seconds (status 1).
# A polling watchdog rather than timeout(1), which macOS does not ship.
run_checks() {
  local dir=$1 out pid i=0
  shift
  out=$(mktemp 2>/dev/null) || return 1
  ( cd "$dir" 2>/dev/null || exit 1
    [ -z "$gh_repo" ] || export GH_REPO="$gh_repo"
    [ -z "$gh_host" ] || export GH_HOST="$gh_host"
    exec gh pr checks "$@" ) > "$out" 2>/dev/null < /dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge $((CHECKS_TIMEOUT * 10)) ]; then
      kill "$pid" 2>/dev/null; rm -f "$out"; return 1
    fi
    sleep 0.1; i=$((i + 1))
  done
  cat "$out" 2>/dev/null; rm -f "$out"
  return 0
}

# Names of the checks whose bucket (gh's non-TTY second column) matches, comma-joined,
# at most MAX_NAMES of them.
names() {
  printf '%s\n' "$1" | awk -F'\t' -v re="$2" -v m="$MAX_NAMES" '
    $2 ~ re { n++; if (n <= m) s = s (s == "" ? "" : ", ") $1 }
    END { if (n > m) s = s " +" (n - m) " more"; printf "%s", s }'
}

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  [ "$(cc_option CC_MERGE_CHECKS on)" = off ] && exit 0
  local input cmd m dir rows failing pending pr reason
  sel=""; repo=""; gh_repo=""; gh_host=""
  input=$(cat 2>/dev/null) || exit 0
  case "$input" in *merge*) ;; *) exit 0 ;; esac
  cmd=$(printf '%s' "$input" | jq -r '
    [ .tool_input.command // empty,
      .tool_input.script // empty,
      .tool_input.cmd // empty ] | map(select(. != "")) | join(" ; ")' 2>/dev/null) || exit 0
  [ -n "$cmd" ] || exit 0
  m=$(strip_bodies "$cmd" | tr '\n' ';' | grep -oiE "$MERGE_RE" | head -n 1)
  [ -n "$m" ] || exit 0
  parse_merge "$m" || exit 0
  command -v gh >/dev/null 2>&1 || exit 0
  dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$dir" ] && [ -d "$dir" ] || dir=$PWD
  rows=$(run_checks "$dir" ${sel:+"$sel"} ${repo:+-R "$repo"}) || exit 0
  failing=$(names "$rows" '^(fail|cancel)$')
  pending=$(names "$rows" '^pending$')
  [ -n "$failing" ] || [ -n "$pending" ] || exit 0
  pr="the current branch's pull request"
  [ -n "$sel" ] && pr="PR $sel"
  reason="git-workflow: $pr is not green on CI —"
  [ -n "$failing" ] && reason="$reason failing: $failing;"
  [ -n "$pending" ] && reason="$reason still running: $pending;"
  reason="$reason merging now ships a commit CI has not passed. Approve to merge anyway (a known-flaky or non-required check), or deny and wait: gh pr checks${sel:+ $sel} --watch, or merge with --auto so GitHub merges once the required checks pass. CC_MERGE_CHECKS=off disables this check for the session."
  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
}

main
exit 0
