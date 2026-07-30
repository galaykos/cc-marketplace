#!/bin/bash
# Absolute-path shebang: same fail-open reasoning as the hooks.
#
# Measures the one number this plugin exists to move: prose lines in turn-final
# messages. Report-only — it never edits, never blocks, and exits 0 on every path
# except a usage error.
#
# WHAT COUNTS AS TURN-FINAL: an assistant message carrying text and NO tool_use
# block. Mid-turn narration rides along with the tool call that follows it, so it
# lands in a message that has both; the messages isolated by this filter are the
# ones a user actually reads at the end of a turn. Heuristic, and stated as one.
#
# WHAT COUNTS AS A PROSE LINE: a non-blank line that is not inside a fenced code
# block and does not start with `|`. Tables, code and trees are free by contract,
# so they are free here too — otherwise the metric would punish the format the
# contract asks for.
#
# Lines are counted at RENDERED width, 100 columns per line: a 300-character
# paragraph is 3, not 1. Counting source lines instead was the first version of
# this script, and on real transcripts it scored a 2,708-character message as
# "11 lines, ok" — one wrapped paragraph per source line is the obvious way to
# satisfy a line budget while changing nothing the reader sees.
#
# NOT A DUPLICATE of comment-discipline's verbosity hook. That one measures
# characters of assistant text per tool call, cumulatively, and warns once per
# session while work is happening. This measures prose lines per turn-final
# message against the active terse budget, after the fact, only when asked.
#
# LIMITATION: it cannot tell an answer from a work-done report, so it grades every
# message against the larger of the two budgets. A long reply the user explicitly
# asked for counts against the numbers exactly like an unrequested one.
usage() {
  printf 'usage: measure.sh [--session-file PATH] [--last N] [--tokens] [--all] [--since Nd|Nh]\n' >&2
  exit 2
}

tp=""; last=10; tokens=0; across=0; since=""
while [ $# -gt 0 ]; do
  case "$1" in
    --session-file) tp="${2:-}"; shift 2 || usage ;;
    --last) last="${2:-10}"; shift 2 || usage ;;
    --tokens) tokens=1; shift ;;
    --all) across=1; shift ;;
    --since) since="${2:-}"; across=1; shift 2 || usage ;;
    -h | --help) usage ;;
    *) usage ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "measure.sh: jq not found"; exit 0; }

# Locate this project's transcript directory. Claude Code names it after the cwd
# with separators flattened; two flattening variants are tried before giving up,
# because guessing wrong silently would measure someone else's sessions.
base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
dir=""
for slug in "$(pwd | tr '/.' '--')" "$(pwd | tr '/._' '---')"; do
  [ -d "$base/$slug" ] && { dir="$base/$slug"; break; }
done

if [ -z "$tp" ] && [ "$across" -eq 0 ]; then
  [ -n "$dir" ] && tp=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)
  if [ -z "$tp" ] || [ ! -r "$tp" ]; then
    echo "measure.sh: no readable transcript found — pass --session-file PATH"
    exit 0
  fi
fi

level="${CC_TERSE:-}"
state="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode"
if [ -z "$level" ] && [ -r "$state" ]; then read -r level _ < "$state" 2>/dev/null; fi
case "$level" in
  lite | wenyan-lite) budget=18 ;;
  full | wenyan-full) budget=12 ;;
  ultra | wenyan-ultra) budget=6 ;;
  *) level="off"; budget=12 ;; # measure against `full` when no level is set
esac

# One row per turn-final message: "<prose-lines> <chars>".
rows_for() {
  jq -rR 'fromjson? // empty
    | select(type == "object" and .type == "assistant")
    | (.message.content // []) as $c
    | select(($c | map(select(type == "object" and .type == "tool_use")) | length) == 0)
    | ($c | map(select(type == "object" and .type == "text") | .text) | join("\n")) as $t
    | select($t != "")
    | "\u0001MSG\n" + $t' "$1" 2>/dev/null |
    awk '
      /^\001MSG$/ { if (have) print n, chars; have=1; n=0; chars=0; fence=0; next }
      { chars += length($0) + 1
        if ($0 ~ /^[[:space:]]*```/) { fence = !fence; next }
        if (fence) next
        if ($0 ~ /^[[:space:]]*$/) next
        if ($0 ~ /^[[:space:]]*\|/) next
        n += int((length($0) + 99) / 100) }
      END { if (have) print n, chars }'
}

# ---- cross-session mode ------------------------------------------------------
# Aggregates every transcript for THIS project, newest first, optionally limited
# by age. No history file is kept: the transcripts are already the record, and a
# second ledger would be one more thing to go stale.
if [ "$across" -eq 1 ]; then
  [ -n "$dir" ] || { echo "measure.sh: no transcript directory for $(pwd)"; exit 0; }
  find_args=""
  case "$since" in
    "") ;;
    *d) find_args="-mtime -${since%d}" ;;
    *h) find_args="-mmin -$(( ${since%h} * 60 ))" ;;
    *) echo "measure.sh: --since takes Nd or Nh (e.g. 7d, 24h), got: $since"; exit 2 ;;
  esac
  printf 'project    : %s\n' "$dir"
  printf 'level      : %s (ceiling %s prose lines)%s\n\n' "$level" "$budget" \
    "${since:+, sessions newer than $since}"
  # shellcheck disable=SC2086 — find_args is a controlled, space-separated pair
  find "$dir" -maxdepth 1 -name '*.jsonl' $find_args 2>/dev/null | while read -r f; do
    r=$(rows_for "$f")
    [ -n "$r" ] || continue
    printf '%s\n' "$r" | awk -v b="$budget" -v f="$(basename "$f" .jsonl)" '
      { n++; tot+=$1; if ($1>max) max=$1; if ($1>b) over++ }
      END { printf "  %-40s %4d msgs  mean %5.1f  max %3d  over %3d (%2.0f%%)\n",
                   substr(f,1,40), n, tot/n, max, over, (over*100)/n }'
  done
  exit 0
fi

# ---- single-session mode -----------------------------------------------------
rows=$(rows_for "$tp")
[ -n "$rows" ] || { echo "measure.sh: no turn-final assistant messages in $tp"; exit 0; }

printf 'transcript : %s\n' "$tp"
printf 'level      : %s (ceiling %s prose lines)\n\n' "$level" "$budget"

printf '%s\n' "$rows" | awk -v b="$budget" -v last="$last" '
  { n[NR]=$1; c[NR]=$2; tot+=$1; totc+=$2; if ($1>max) max=$1; if ($1>b) over++ }
  END {
    printf "turn-final messages : %d\n", NR
    printf "prose lines         : mean %.1f, max %d, over ceiling %d (%.0f%%)\n", tot/NR, max, over, (over*100)/NR
    printf "chars               : mean %.0f\n\n", totc/NR
    start = NR - last + 1; if (start < 1) start = 1
    printf "last %d:\n", NR - start + 1
    for (i = start; i <= NR; i++)
      printf "  #%-3d %3d lines %6d chars %s\n", i, n[i], c[i], (n[i] > b ? "OVER" : "ok")
  }'

# --tokens: real usage off the transcript, never an estimate. There is deliberately
# no "tokens saved" and no dollar figure — savings would need the same session run
# without the mode, which does not exist, and a hardcoded price table goes stale
# the week a tier changes. Reporting either as a measurement is the thing this
# plugin's own contract forbids.
if [ "$tokens" -eq 1 ]; then
  printf '\ntokens (from transcript usage fields, this session only):\n'
  jq -rR 'fromjson? // empty
    | select(type == "object" and .type == "assistant")
    | .message.usage // empty
    | [ (.output_tokens // 0), (.input_tokens // 0),
        (.cache_read_input_tokens // 0), (.cache_creation_input_tokens // 0) ]
    | @tsv' "$tp" 2>/dev/null |
    awk -F'\t' '
      { out+=$1; inp+=$2; cr+=$3; cc+=$4; n++ }
      END {
        if (!n) { print "  no usage fields in this transcript"; exit }
        printf "  assistant turns   : %d\n", n
        printf "  output            : %d tokens (mean %.0f/turn)\n", out, out/n
        printf "  input, fresh      : %d\n", inp
        printf "  input, cache read : %d\n", cr
        printf "  input, cache write: %d\n", cc
        printf "  note: output tokens include tool-call arguments, not just prose.\n"
      }'
fi
exit 0
