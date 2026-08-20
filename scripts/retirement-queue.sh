#!/usr/bin/env bash
# Retirement queue: rank shipped skills by evidence that they are NOT used, so a
# removal argument can be made from data instead of from taste.
#
# WHY THIS EXISTS. Every removal this marketplace has ever made was argued from
# description tokens and trigger-phrase overlap, because no artifact recorded which
# skills ever fired. The doctrine's own loop (rationale/stack-skill-baselines.md)
# has produced eight removals, all on one day in July 2026, and nothing since —
# while the surface it governs kept growing to 126 skills. Not because the doctrine
# stopped being right, but because a control/treatment run per skill is expensive
# and nothing said which ones were worth spending it on.
#
# Two local ledgers now exist, both written on 2026-08-02:
#   $HOME/.claude/skill-router/<slug>/surfaced.jsonl  — what the router OFFERED
#   $HOME/.claude/hindsight/<slug>/skills.jsonl       — what was actually INVOKED
# This reads them, joins against the shipped skill list, and prints a queue.
#
#   retirement-queue.sh [--sessions N] [--slug SLUG] [--all-projects]
#
# Exit is ALWAYS 0. This ranks candidates for a human to judge; it never fails a
# build and it never proposes a deletion by itself.
#
# WHAT THE NUMBERS DO AND DO NOT MEAN — read before quoting any of them:
#   - Zero invocations proves nobody used it HERE, on this machine, in the sessions
#     recorded. It is not evidence about anyone else's projects, and a stack skill
#     for a stack this machine does not use SHOULD read zero. That is correct
#     behaviour, not a finding.
#   - Non-zero invocation proves it fired, never that it helped. A skill invoked
#     200 times can still be restating what the model already knew; only a
#     control/treatment run settles that. This is the denominator, not the verdict.
#   - The sample is small until the ledgers have been collecting for a while. A
#     queue built from six sessions is noise wearing a table.
set -u
sessions_min=0
slug=""
all=0
while [ $# -gt 0 ]; do
  case "$1" in
    --sessions) sessions_min="${2:-0}"; shift 2 ;;
    --slug) slug="${2:-}"; shift 2 ;;
    --all-projects) all=1; shift ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) printf 'retirement-queue: unknown argument %s\n' "$1" >&2; exit 0 ;;
  esac
done

cd "$(dirname "$0")/.." || exit 0
command -v jq >/dev/null 2>&1 || { echo "retirement-queue: jq required"; exit 0; }

[ -n "$slug" ] || slug=$(printf '%s' "$PWD" | tr -c '[:alnum:]' '-')
SR_DIR="$HOME/.claude/skill-router"
HS_DIR="$HOME/.claude/hindsight"

collect() { # dir file -> concatenated jsonl
  local d="$1" f="$2"
  if [ "$all" -eq 1 ]; then
    find "$d" -name "$f" -type f 2>/dev/null -exec cat {} +
  else
    cat "$d/$slug/$f" 2>/dev/null
  fi
}

surfaced=$(collect "$SR_DIR" surfaced.jsonl)
invoked=$(collect "$HS_DIR" skills.jsonl)

# grep -c prints 0 AND exits 1 on no match, so `|| echo 0` would append a SECOND
# zero and every later arithmetic test would see "0\n0" and abort.
n_sessions=$(printf '%s' "$surfaced" | grep -c . 2>/dev/null); n_sessions=${n_sessions:-0}
n_invocations=$(printf '%s' "$invoked" | grep -c . 2>/dev/null); n_invocations=${n_invocations:-0}

if [ "${n_sessions:-0}" -eq 0 ] && [ "${n_invocations:-0}" -eq 0 ]; then
  cat <<EOF
retirement-queue: no telemetry yet for slug '$slug'.

Both ledgers are written by hooks that began collecting on 2026-08-02:
  skill-router/hooks/summary.sh  -> $SR_DIR/<slug>/surfaced.jsonl   (SessionEnd)
  hindsight/hooks/skill-use.sh   -> $HS_DIR/<slug>/skills.jsonl     (PostToolUse Skill)

Nothing to rank until sessions accumulate. That is the expected state on day one,
and an empty file is NOT evidence that nothing is used — check the files exist
before drawing any conclusion. Try --all-projects to pool every project on this
machine.
EOF
  exit 0
fi

printf 'retirement-queue: %s session record(s), %s invocation(s)%s\n\n' \
  "${n_sessions:-0}" "${n_invocations:-0}" \
  "$([ "$all" -eq 1 ] && printf ' across all projects' || printf " for slug '$slug'")"

if [ "${n_sessions:-0}" -lt "${sessions_min:-0}" ]; then
  printf 'Below the --sessions %s threshold you asked for. Reporting anyway, but a\n' "$sessions_min"
  printf 'queue built from %s sessions is noise wearing a table.\n\n' "${n_sessions:-0}"
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
for d in plugins/*/skills/*/; do
  [ -f "$d/SKILL.md" ] || continue
  plug=$(printf '%s' "$d" | cut -d/ -f2)
  name=$(basename "$d")
  printf '%s\t%s\n' "$name" "$plug"
done | sort -u > "$TMP/skills"

printf '%s' "$invoked" | jq -r '.skill // empty' 2>/dev/null \
  | sed 's/^.*://' | sort | uniq -c | awk '{print $2"\t"$1}' | sort > "$TMP/inv"
# SURFACED means the model saw it. `fired` is an inline nudge; `pending_low_flushed`
# is a low-confidence signal route-prompt.sh actually printed on a later prompt.
# A bare `pending_low` entry is neither — it accumulated and may never have been
# shown, so counting it as surfaced overstated exactly the skills this queue is
# for. Older ledger lines carry no split field: they fall back to `pending_low`,
# which keeps the historical count readable rather than silently zeroing it.
printf '%s' "$surfaced" | jq -r '
    (.fired // [])[],
    (if has("pending_low_flushed") then (.pending_low_flushed // [])[] else (.pending_low // [])[] end)
  ' 2>/dev/null \
  | sort | uniq -c | awk '{print $2"\t"$1}' | sort > "$TMP/srf"

printf '%-34s %-22s %10s %10s\n' "skill" "plugin" "surfaced" "invoked"
# Rows to a file first: piping the loop into `sort` would run it in a subshell and
# the `never` counter would never survive it — the same subshell trap that made the
# context-budget dynamic meter measure zero.
: > "$TMP/rows"
while IFS=$'\t' read -r name plug; do
  sc=$(awk -F'\t' -v n="$name" '$1==n {print $2}' "$TMP/srf"); sc=${sc:-0}
  ic=$(awk -F'\t' -v n="$name" '$1==n {print $2}' "$TMP/inv"); ic=${ic:-0}
  printf '%s\t%s\t%s\t%s\n' "$name" "$plug" "$sc" "$ic" >> "$TMP/rows"
done < "$TMP/skills"
never=$(awk -F'\t' '$3==0 && $4==0' "$TMP/rows" | wc -l | tr -d ' ')
sort -t$'\t' -k3,3n -k4,4n "$TMP/rows" \
  | awk -F'\t' '{printf "%-34s %-22s %10s %10s\n", $1, $2, $3, $4}'

total=$(wc -l < "$TMP/skills" | tr -d ' ')
cat <<EOF

$never of $total shipped skills have neither surfaced nor been invoked in this sample.

WHAT TO DO WITH THAT, in order:
  1. Ask whether the skill's stack is even present here. A Laravel skill reading
     zero in a Go repo is the system working, not a candidate.
  2. For a survivor that SHOULD have fired and did not, the defect is usually
     ROUTING, not the skill — check plugins/skill-router/rules.tsv. 102 of 126
     skills have no routing row at all, so "never surfaced" mostly measures the
     router's coverage, not the skill's worth.
  3. Only then does a skill enter the control/treatment queue. Run the host
     skill-creator eval loop and record the verdict; the doctrine and the shapes
     that already measured zero are in rationale/stack-skill-baselines.md and
     rationale/measured-zero-shapes.md.

This is a queue, not a verdict. Nothing here is evidence that a skill is useless —
only evidence about where it is worth spending a measurement.
EOF
exit 0
