#!/usr/bin/env bash
# review-skip.sh — record a card whose reviewer pass did not run.
#
# Usage:
#   review-skip.sh --card <id> --reason "<why>" [--record-dir <dir>]
#   review-skip.sh --card <id> --exempt <leaf|no-reviewer-installed> [--record-dir <dir>]
#
# TWO KINDS, DELIBERATELY NAMED DIFFERENTLY:
#   --reason  a DISCRETIONARY skip — a judgment call made mid-run (context pressure,
#             time, "it looked trivial"). Writes rv-skip-<card>.json. The PreToolUse
#             consent hook asks the user before this record exists, and the completion
#             gate refuses a clean stop whose final report does not disclose it.
#   --exempt  a DESIGN carve-out — a parallel-group/track leaf gets no reviewer pass by
#             the routing rules, and a reviewer plugin that is not installed cannot run.
#             Writes rv-exempt-<card>.json. Routine, never prompts, still counted.
#
# The reason is MODEL-AUTHORED and this script cannot check it. What it does buy: the
# reason is echoed to stderr the moment the skip happens, so it lands in the transcript
# at the point of decision instead of being reconstructed later — the disclosure the
# original incident never made. Standing: recorded.
#
# Default --record-dir is <repo-root>/.claude/task-runner/rv, where the observer hook and
# the completion gate look.
set -euo pipefail

PROG=review-skip
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

CARD=""; REASON=""; EXEMPT="";
# Anchored at the repo ROOT, not the shell's cwd: a `cd sub && ...` invocation wrote the
# record where the completion gate never looks, so the count came up short and blocked
# the run.
ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIR="$ROOT_DIR/.claude/task-runner/rv"
while [ $# -gt 0 ]; do
  case "$1" in
    --card) [ $# -ge 2 ] || usage "--card needs an argument"; CARD="$2"; shift 2 ;;
    --reason) [ $# -ge 2 ] || usage "--reason needs an argument"; REASON="$2"; shift 2 ;;
    --exempt) [ $# -ge 2 ] || usage "--exempt needs an argument"; EXEMPT="$2"; shift 2 ;;
    --record-dir) [ $# -ge 2 ] || usage "--record-dir needs an argument"; DIR="$2"; shift 2 ;;
    -h | --help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done

[ -n "$CARD" ] || usage "need --card <id>"
case "$CARD" in *[!a-zA-Z0-9._-]*) usage "--card carries path characters: $CARD" ;; esac
[ -n "$REASON" ] || [ -n "$EXEMPT" ] || usage "need --reason \"<why>\" or --exempt <kind>"
[ -z "$REASON" ] || [ -z "$EXEMPT" ] || usage "--reason and --exempt are mutually exclusive"

case "$EXEMPT" in
  "" | leaf | no-reviewer-installed) ;;
  *) usage "--exempt takes leaf or no-reviewer-installed, got: $EXEMPT" ;;
esac

mkdir -p "$DIR" 2>/dev/null || { printf '%s: cannot create %s\n' "$PROG" "$DIR" >&2; exit 5; }

# Strips control characters as well as escaping: a newline in --reason wrote a record
# that is not valid JSON, which nothing reads back today but breaks the first tool that does.
esc() { printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

if [ -n "$EXEMPT" ]; then
  printf '{"card":"%s","exempt":"%s"}\n' "$CARD" "$EXEMPT" > "$DIR/rv-exempt-$CARD.json"
  printf '%s: card %s exempt from the reviewer pass (%s) — recorded.\n' "$PROG" "$CARD" "$EXEMPT" >&2
  echo "exempt-recorded"
  exit 0
fi

printf '{"card":"%s","skipped":true,"reason":"%s"}\n' "$CARD" "$(esc "$REASON")" > "$DIR/rv-skip-$CARD.json"
# Loud on purpose: this line is the mid-run disclosure. A skip the user only learns
# about when they ask is the failure this whole mechanism exists to prevent.
printf '%s: REVIEWER PASS SKIPPED for card %s — %s\n' "$PROG" "$CARD" "$REASON" >&2
printf '%s: this must appear under Skipped: in the completion report; the gate checks.\n' "$PROG" >&2
echo "skip-recorded"
