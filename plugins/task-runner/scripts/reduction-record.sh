#!/usr/bin/env bash
# reduction-record.sh — record a declared reduction in what a run promised to do.
#
# Usage:
#   reduction-record.sh --kind <kind> --id <ref> --reason "<why>" [--record-dir <dir>]
#
#   kinds: redteam    the N=3 refuter panel ran degraded (inline single-agent fallback)
#          dispatch   a planned fan-out narrowed, or a tracks run downgraded to serial
#          suite      the full-suite pass was narrowed to a subset
#          coverage   a coverage or verification step was not run in full
#          other      anything else the run promised and did not fully deliver
#
# THE POINT. Every one of these is legitimate sometimes. None of them is legitimate
# silently: the failure this exists to prevent is the one that already happened —
# reviewers dropped on 7 of 8 cards to save context, reported as "all 8 done", found
# only because the user asked afterwards.
#
# So a reduction leaves three traces: this record (which completion-gate.sh counts and
# whose existence makes the closing report's disclosure mandatory), the reason echoed
# to stderr at the moment of the decision so it lands in the transcript where it
# happened, and — in an interactive session — a permission prompt from
# hooks/rv-consent.sh before the record exists at all.
#
# The reviewer pass has its own recorder (review-skip.sh) because it is counted per
# card against cards_done; this one covers the reductions that are not per-card.
#
# Standing: recorded. The reason is model-authored and nothing here can check it. What
# is mechanical is that the reduction cannot be invisible.
set -euo pipefail

PROG=reduction-record
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

KIND=""; ID=""; REASON="";
# Anchored at the repo ROOT, not the shell's cwd: a `cd sub && ...` invocation wrote the
# record where the completion gate never looks, so the count came up short and blocked
# the run.
ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIR="$ROOT_DIR/.claude/task-runner/reductions"
while [ $# -gt 0 ]; do
  case "$1" in
    --kind) [ $# -ge 2 ] || usage "--kind needs an argument"; KIND="$2"; shift 2 ;;
    --id) [ $# -ge 2 ] || usage "--id needs an argument"; ID="$2"; shift 2 ;;
    --reason) [ $# -ge 2 ] || usage "--reason needs an argument"; REASON="$2"; shift 2 ;;
    --record-dir) [ $# -ge 2 ] || usage "--record-dir needs an argument"; DIR="$2"; shift 2 ;;
    -h | --help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done

case "$KIND" in
  redteam | dispatch | suite | coverage | other) ;;
  "") usage "need --kind <redteam|dispatch|suite|coverage|other>" ;;
  *) usage "unknown --kind: $KIND" ;;
esac
[ -n "$ID" ] || usage "need --id <ref> (a card, a milestone, a commit, a scope name)"
case "$ID" in *[!a-zA-Z0-9._-]*) usage "--id carries path characters: $ID" ;; esac
[ -n "$REASON" ] || usage "need --reason \"<why>\" — a reduction with no stated reason is the thing this refuses to allow"

mkdir -p "$DIR" 2>/dev/null || { printf '%s: cannot create %s\n' "$PROG" "$DIR" >&2; exit 5; }

# Strips control characters as well as escaping: a newline in --reason wrote a record
# that is not valid JSON, which nothing reads back today but breaks the first tool that does.
esc=$(printf '%s' "$REASON" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g')
printf '{"kind":"%s","id":"%s","reduced":true,"reason":"%s"}\n' "$KIND" "$ID" "$esc" > "$DIR/$KIND-$ID.json"

# Loud on purpose: this line is the mid-run disclosure.
printf '%s: REDUCED (%s) %s — %s\n' "$PROG" "$KIND" "$ID" "$REASON" >&2
printf '%s: the completion report must name this reduction; the gate checks that it does.\n' "$PROG" >&2
echo "reduction-recorded"
