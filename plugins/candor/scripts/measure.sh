#!/bin/bash
# measure.sh [--session-file PATH] [--last N] [--tokens] [--all] [--since Nd|Nh] — report-only: per turn-final message (text and no tool_use,
#   by message id), prose lines (non-blank, unfenced, not `|`-led, one per 100 columns) against the terse budget. Exits 0; 2 on a usage error.
# Misses: an answer cannot be told from a work-done report, so every message is graded against the larger budget, a requested long reply too.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/measure.sh
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

# Claude Code names the transcript directory after the cwd with separators flattened; two spellings are tried, as in candor-scan.sh.
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

read -r level _ <<< "$("${BASH:-bash}" "$(dirname "$0")/level.sh" 2>/dev/null)"
case "$level" in
  lite | wenyan-lite) budget=18 ;;
  full | wenyan-full) budget=12 ;;
  ultra | wenyan-ultra) budget=6 ;;
  *) level="off"; budget=12 ;; # measure against `full` when no level is set
esac

# One row per turn-final message: "<prose-lines> <chars>".
# The @@MSG sentinel is printable on purpose: a control character works but makes this script unreadable to git and to an editor.
rows_for() {
  toolids=$(jq -rR 'fromjson? // empty
    | select(type == "object" and .type == "assistant")
    | select(((.message.content // []) | map(select(type == "object" and .type == "tool_use")) | length) > 0)
    | .message.id // empty' "$1" 2>/dev/null | sort -u)

  jq -rR 'fromjson? // empty
    | select(type == "object" and .type == "assistant")
    | (.message.id // "noid") as $id
    | ((.message.content // []) | map(select(type == "object" and .type == "text") | .text) | join("\n")) as $t
    | select($t != "")
    | "@@MSG " + $id + "\n" + $t' "$1" 2>/dev/null |
    TERSE_TOOLIDS="$toolids" awk '
      # via the environment, not -v: a -v value cannot carry newlines on BSD awk
      BEGIN { k = split(ENVIRON["TERSE_TOOLIDS"], a, "\n"); for (i = 1; i <= k; i++) if (a[i] != "") S[a[i]] = 1 }
      /^@@MSG / {
        id = substr($0, 7)
        if (id != cur) {
          if (have && !S[cur]) print n, chars
          have = 1; n = 0; chars = 0; fence = 0; cur = id
        }
        next
      }
      { chars += length($0) + 1
        if ($0 ~ /^[[:space:]]*```/) { fence = !fence; next }
        if (fence) next
        if ($0 ~ /^[[:space:]]*$/) next
        if ($0 ~ /^[[:space:]]*\|/) next
        n += int((length($0) + 99) / 100) }
      END { if (have && !S[cur]) print n, chars }'
}

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

# Deliberately no "tokens saved" or dollar figure: savings need the same session run without the mode, and a price table goes stale.
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
