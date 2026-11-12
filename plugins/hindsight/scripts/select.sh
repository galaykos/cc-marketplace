#!/usr/bin/env bash
# select.sh [--top N|all] [--since DAYS] [--all-projects] [project-cwd] — ranks the unmined transcripts /hindsight:harvest mines: ledger rows by 3×friction + 2×errors + turns, then transcripts with no row, newest first. `--mark <transcript>...` sets mined:true. Exit 0 always.
# Misses: a session that was quiet and wrong (the score counts tool errors, not bad answers); a transcript the host already deleted (dropped, counted on stderr); a row collect.sh appends while --mark rewrites the ledger; what a fork said after its fork point when the longer copy outranks it.
# Why, limits, history: rationale/derivations/plugin-hindsight.md § plugins/hindsight/scripts/select.sh
set -u
command -v jq >/dev/null 2>&1 || { echo "select: jq required" >&2; exit 0; }
[ -n "${HOME:-}" ] || { echo "select: no HOME" >&2; exit 0; }
H="$HOME/.claude/hindsight"
P="$HOME/.claude/projects"

top=5; since=""; all=0; cwd=""; mark=0
while [ $# -gt 0 ]; do
  case "$1" in
    --top)          top="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --since)        since="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    --all-projects) all=1; shift ;;
    --mark)         mark=1; shift; break ;;
    *)              cwd="$1"; shift ;;
  esac
done
case "$top" in all) ;; ''|*[!0-9]*) echo "select: --top takes a number or 'all'" >&2; exit 0 ;; esac
case "$since" in *[!0-9]*) echo "select: --since takes a number of days" >&2; exit 0 ;; esac

# A forked session copies its parent's transcript up to the fork point, so both files open with the same first message.
convo() { local u; u=$(grep -m1 -o '"uuid":"[^"]*"' "$1" 2>/dev/null); printf '%s' "${u:-$1}" | cksum | cut -d' ' -f1; }

if [ "$mark" = 1 ]; then
  n=0
  # Marking a session marks its forks too, or the fork is offered next time with the same findings in it.
  list=$(mktemp) || exit 0
  for path in "$@"; do
    printf '%s\n' "$path"
    case "$path" in */subagents/*) continue ;; esac
    [ -f "$path" ] || continue
    key=$(convo "$path")
    for sib in "$(dirname "$path")"/*.jsonl; do
      [ "$sib" != "$path" ] && [ -f "$sib" ] && [ "$(convo "$sib")" = "$key" ] && printf '%s\n' "$sib"
    done
  done | sort -u >"$list"
  while IFS= read -r path; do
    rel="${path#"$P"/}"
    [ "$rel" != "$path" ] || { echo "select: not under $P, not marked: $path" >&2; continue; }
    slug="${rel%%/*}"
    dir="$H/$slug"; ledger="$dir/ledger.jsonl"
    mkdir -p "$dir" 2>/dev/null || continue
    if [ -f "$ledger" ] && grep -qF "$path" "$ledger" 2>/dev/null; then
      # Raw lines in, raw lines out: a line that is not a JSON object passes through untouched.
      tmp=$(mktemp "$dir/ledger.XXXXXX") || continue
      if jq -R -r --arg p "$path" '
          . as $l | (fromjson? // null) as $o
          | if ($o | type) == "object"
            then ($o | if .transcript_path == $p then .mined = true else . end | tojson)
            else $l end' <"$ledger" >"$tmp" 2>/dev/null; then
        mv "$tmp" "$ledger" && n=$((n + 1))
      else
        rm -f "$tmp"
      fi
    else
      base=$(basename "$path" .jsonl)
      case "$path" in
        */subagents/agent-*.jsonl)
          sid=$(basename "$(dirname "$(dirname "$path")")")
          jq -c -n --arg s "$sid" --arg a "$base" --arg p "$path" \
            '{v: 1, kind: "agent", session_id: $s, agent_id: $a, transcript_path: $p, mined: true}' ;;
        *)
          jq -c -n --arg s "$base" --arg p "$path" \
            '{v: 1, session_id: $s, transcript_path: $p, mined: true}' ;;
      esac >>"$ledger" 2>/dev/null && n=$((n + 1))
    fi
  done <"$list"
  rm -f "$list"
  echo "select: marked $n transcript(s) mined"
  exit 0
fi

if [ "$all" = 1 ]; then
  slugs=$( { ls -1 "$H" 2>/dev/null; ls -1 "$P" 2>/dev/null; } | sort -u)
else
  slugs=$(printf '%s' "${cwd:-$PWD}" | tr -c '[:alnum:]' '-')
fi

mtime() { stat -c '%Y' "$1" 2>/dev/null || stat -f '%m' "$1" 2>/dev/null || echo 0; }

work=$(mktemp -d) || exit 0
trap 'rm -rf "$work"' EXIT
: >"$work/ranked"; : >"$work/known"; : >"$work/fallback"
gone=0

while IFS= read -r slug; do
  [ -n "$slug" ] || continue
  ledger="$H/$slug/ledger.jsonl"
  if [ -f "$ledger" ]; then
    jq -n -R -r '[inputs | fromjson? // empty | select(type == "object") | .transcript_path | select(type == "string")] | unique[]' \
      <"$ledger" >>"$work/known" 2>/dev/null
    # One candidate per transcript: a resumed session writes a second row for the same file, and the last one is the full count.
    jq -n -R -r --arg d "$since" '
        (if $d == "" then "" else (now - ($d | tonumber) * 86400 | todate) end) as $cut
        | [inputs | fromjson? // empty | select(type == "object") | select((.transcript_path | type) == "string")]
        | group_by(.transcript_path)[]
        | select(any(.[]; .mined == true) | not)
        | .[-1]
        | select($cut == "" or ((.ts_end // "") >= $cut))
        | [((.friction_events // 0) * 3 + (.errors // 0) * 2 + (.turns // 0)),
           (.kind // "session"), (.agent_type // "-"), (.ts_end // "-"), .transcript_path]
        | @tsv' <"$ledger" 2>/dev/null \
      | while IFS=$'\t' read -r score kind atype ts path; do
          [ -f "$path" ] || { echo gone >>"$work/gone"; continue; }
          printf '%s\t%s\t%s\t%s\t%s\n' "$score" "$kind" "$atype" "$ts" "$path"
        done >>"$work/ranked"
  fi
  [ -d "$P/$slug" ] || continue
  if [ -n "$since" ]; then
    find "$P/$slug" -maxdepth 3 -type f -name '*.jsonl' -mtime "-$since" 2>/dev/null
  else
    find "$P/$slug" -maxdepth 3 -type f -name '*.jsonl' 2>/dev/null
  fi | while IFS= read -r path; do
    case "$path" in
      "$P/$slug"/*/subagents/agent-*.jsonl)
        kind=agent
        atype=$(jq -r '.agentType // empty' "${path%.jsonl}.meta.json" 2>/dev/null)
        atype="${atype:-unknown}" ;;
      "$P/$slug"/*/*) continue ;;
      *) kind=session; atype="-" ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$(mtime "$path")" "$kind" "$atype" "$path"
  done >>"$work/fallback"
done <<EOF
$slugs
EOF

[ -f "$work/gone" ] && gone=$(wc -l <"$work/gone" | tr -d ' ')

{
  sort -t "$(printf '\t')" -k1,1nr "$work/ranked"
  sort -t "$(printf '\t')" -k1,1nr "$work/fallback" \
    | while IFS=$'\t' read -r _ kind atype path; do
        grep -qxF "$path" "$work/known" 2>/dev/null && continue
        printf -- '-\t%s\t%s\t-\t%s\n' "$kind" "$atype" "$path"
      done
} >"$work/out"

# Highest-ranked file of a conversation stays; its forks fold into it.
: >"$work/seen"; : >"$work/folded"
while IFS=$'\t' read -r score kind atype ts path; do
  if [ "$kind" = session ]; then
    key=$(convo "$path")
    if grep -qx "$key" "$work/seen"; then echo fork >>"$work/forks"; continue; fi
    echo "$key" >>"$work/seen"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$score" "$kind" "$atype" "$ts" "$path"
done <"$work/out" >"$work/folded"
mv "$work/folded" "$work/out"
forks=0; [ -f "$work/forks" ] && forks=$(wc -l <"$work/forks" | tr -d ' ')

total=$(wc -l <"$work/out" | tr -d ' ')
printf 'score\tkind\tagent_type\tts_end\ttranscript\n'
if [ "$top" = all ]; then cat "$work/out"; else head -n "$top" "$work/out"; fi
echo "select: $total unmined candidate(s), top $top shown, $gone dropped (transcript gone), $forks fork(s) folded into their conversation" >&2
exit 0
