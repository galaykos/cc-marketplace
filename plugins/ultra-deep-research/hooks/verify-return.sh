#!/bin/bash
# verify-return.sh — SubagentStop on this plugin's researcher and verifier: blocks (exit 2, reason on stderr) a return that cites a URL the agent never fetched (sources-check.sh), or a verifier verdict block that fails verdict-lint.sh; at most twice per agent, then lets it stop. Fails open.
# Misses: whether a fetched page supports its quote, a return with no url:/FETCH: line, and a third bad return from the same agent.
# Why, limits, history: rationale/derivations/plugin-ultra-deep-research.md § plugins/ultra-deep-research/hooks/verify-return.sh
reason=""
{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  type=$(printf '%s' "$input" | jq -r '.agent_type // empty')
  case "$type" in ultra-deep-research:researcher | ultra-deep-research:verifier) ;; *) exit 0 ;; esac
  msg=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty')
  tp=$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty')
  id=$(printf '%s' "$input" | jq -r '.agent_id // .agent_transcript_path // empty')
  [ -n "$msg" ] && [ -n "$id" ] || exit 0
  here=$(cd "$(dirname "$0")/.." && pwd)
  problems=""
  if [ "$type" = ultra-deep-research:verifier ]; then
    lint=$(printf '%s\n' "$msg" | bash "$here/scripts/verdict-lint.sh" 2>&1); rc=$?
    [ "$rc" = 1 ] && problems="$lint"
  fi
  if [ -n "$tp" ] && [ -r "$tp" ]; then
    src=$(printf '%s\n' "$msg" | bash "$here/scripts/sources-check.sh" --transcript "$tp"); rc=$?
    [ "$rc" = 1 ] && problems="${problems:+$problems
}$src"
  fi
  [ -n "$problems" ] || exit 0
  count_file="${TMPDIR:-/tmp}/cc-udr-return-$(printf '%s' "$id" | cksum | cut -d' ' -f1)"
  n=$(cat "$count_file" || echo 0)
  case "$n" in '' | *[!0-9]*) n=0 ;; esac
  [ "$n" -lt 2 ] || exit 0
  echo $((n + 1)) > "$count_file" || exit 0
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-udr-return-*' -mmin +1440 -delete
  reason="[ultra-deep-research] Your return does not hold yet. Fix it before stopping: fetch each page you cite with WebFetch, or drop the claim or mark it unverifiable-this-session; keep each verdict block in the documented format.
$problems"
} 2>/dev/null
[ -n "$reason" ] || exit 0
printf '%s\n' "$reason" >&2
exit 2
