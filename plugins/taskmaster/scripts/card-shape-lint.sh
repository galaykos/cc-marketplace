#!/usr/bin/env bash
# card-shape-lint.sh — author-time STRUCTURAL lint for a role-tagged task card.
#
# WHY. A card's sections used to be bold labels that named CONTENT (Why, Context,
# Out of scope). The role-tagged shape (task-cards `references/card-shape.md`)
# names the author's DECISION about each sentence — <goal>, <facts>, <must>,
# <must-not>, <proof> — and hangs the decision's evidence on attributes: a
# forbidden file carries the reason it is forbidden, an interface names its
# consumer, a file to edit names the line. Those attributes are what a bold label
# could never demand, and a rule nothing demands is a rule that is skipped when the
# author is in a hurry. Measured 2026-09-23 (8 fresh-model runs, 4 per shape): the
# READING side showed zero delta between the two shapes — the gain is entirely at
# authoring time, and this lint is what turns the authoring rules from `recorded`
# into `gate`.
#
# WHAT IT CATCHES (each -> exit 2, one `card-shape: <reason>` line on stderr per
# finding, every finding reported before exiting):
#   no-shape             : neither a <card> wrapper nor a legacy **Verify:** line
#   missing-section      : one of <goal> <facts> <must> <proof> <depends-on> <agent> absent
#   verify-count         : not exactly one <verify> element
#   verify-multiline     : <verify> opens and closes on different lines (the teeth lint
#                          and the runner read it as ONE line — a wrapped one is unread)
#   no-criterion         : <proof> carries no <criterion>
#   file-mode            : a <file> in <facts> without mode="edit" or mode="create"
#   file-line            : a <file mode="edit"> without line="<n>"
#   must-not-reason      : an element inside <must-not> without a non-empty reason="…"
#   interface-consumer   : an <interface> without consumer="…"
#   skill-name           : a <skill> without name="…"
#   agent-vocabulary     : <agent> value outside the closed list in
#                          skills/task-cards/references/agent-tags.md (read at run time,
#                          never copied here; unreadable list -> this ONE check is skipped
#                          with a NOTE, the rest still run)
#
# WHAT IT DOES NOT CATCH (stated, not hidden): whether a <criterion> describes
# behaviour rather than the diff, whether a reason="…" is true, whether the
# <change> is the right change. Those stay agent-graded in task-cards. It also does
# not grade the <verify> text — that is verify-teeth-lint.sh — nor the <skill>
# names against the touched files — that is skills-stamp-lint.sh. A UI card's
# <walk> line is optional and unchecked: present or absent, no finding.
#
# LEGACY SHAPE. A card with no <card> wrapper but a **Verify:** line is the bold-label
# shape task-cards emitted before taskmaster 0.45.0. It passes with a NOTE on stderr
# and exit 0: in-flight card sets keep executing. task-cards emits only the tagged
# shape; the acceptance here is for cards already written, not a second template.
#
# CLI:
#   card-shape-lint.sh --card <card.md>
# Exit codes:
#   0  shape OK (or legacy shape, NOTE printed)
#   2  one or more findings (each on stderr)
#   3  usage error
set -euo pipefail

_cardlint_target=""
. "$(dirname "$0")/card-lint-record.sh" 2>/dev/null || true
record_run() {
  [ -n "$_cardlint_target" ] || return 0
  command -v cardlint_write >/dev/null 2>&1 || return 0
  cardlint_write card-shape "$_cardlint_target" "$1"
}

PROG=card-shape
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

card=""
while [ $# -gt 0 ]; do
  case "$1" in
    --card) [ $# -ge 2 ] || usage "--card needs an argument"; card="$2"; shift 2 ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done
[ -n "$card" ] || usage "need --card <file>"
[ -f "$card" ] || usage "card file not found: $card"
_cardlint_target="$card"

findings=0
finding() { findings=$((findings + 1)); printf '%s: %s\n' "$PROG" "$1" >&2; }

if ! grep -Eq '^<card( |>)' "$card"; then
  if grep -Eq '\*\*Verify:\*\*' "$card"; then
    printf '%s: NOTE legacy bold-label card (no <card> wrapper) — accepted; task-cards emits the role-tagged shape since taskmaster 0.45.0\n' "$PROG" >&2
    record_run pass
    exit 0
  fi
  finding "no-shape: neither a <card> wrapper nor a legacy **Verify:** line"
  record_run block
  exit 2
fi

# block <name> : the lines between <name> and </name>, exclusive of both tags.
block() { sed -n "/^<$1[ >]/,/^<\/$1>/p" "$card" | sed '1d;$d'; }

for sec in goal facts must proof depends-on agent; do
  grep -Eq "^<$sec( |>)" "$card" || finding "missing-section: <$sec>"
done

n=$(grep -c '<verify>' "$card" || true)
if [ "$n" -ne 1 ]; then
  finding "verify-count: expected exactly one <verify>, found $n"
elif ! grep -Eq '<verify>.*</verify>' "$card"; then
  finding "verify-multiline: <verify> must open and close on one line — the teeth lint and the runner read a single line"
fi

if grep -Eq '^<proof( |>)' "$card" && ! block proof | grep -q '<criterion>'; then
  finding "no-criterion: <proof> carries no <criterion>"
fi

while IFS= read -r l; do
  case "$l" in
    "<file "*)
      if ! printf '%s' "$l" | grep -Eq 'mode="(edit|create)"'; then
        finding "file-mode: <file> in <facts> needs mode=\"edit\" or mode=\"create\" — $l"
      elif printf '%s' "$l" | grep -q 'mode="edit"' && ! printf '%s' "$l" | grep -Eq 'line="[0-9]+"'; then
        finding "file-line: <file mode=\"edit\"> needs line=\"<n>\" — the executor trusts the card, not its memory — $l"
      fi ;;
  esac
done < <(block facts)

while IFS= read -r l; do
  case "$l" in
    "<"[a-z]*)
      printf '%s' "$l" | grep -Eq 'reason="[^"]+"' \
        || finding "must-not-reason: every element in <must-not> carries a non-empty reason=\"…\" — $l" ;;
  esac
done < <(block must-not)

while IFS= read -r l; do
  printf '%s' "$l" | grep -Eq 'consumer="[^"]+"' \
    || finding "interface-consumer: <interface> names who reads it, consumer=\"…\" — $l"
done < <(grep -E '^<interface([ />]|$)' "$card" || true)

while IFS= read -r l; do
  printf '%s' "$l" | grep -Eq 'name="[^"]+"' \
    || finding "skill-name: <skill> needs name=\"…\" — $l"
done < <(grep -E '^<skill([ />]|$)' "$card" || true)

vocab_file="$(dirname "$0")/../skills/task-cards/references/agent-tags.md"
agent=$(grep -Eo '<agent>[^<]*</agent>' "$card" | head -1 | sed -e 's/<agent>//' -e 's/<\/agent>//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' || true)
if [ -n "$agent" ]; then
  if [ -r "$vocab_file" ]; then
    vocab=$(sed -n '/^## Closed vocabulary/,/^## /p' "$vocab_file" | sed -n '/^```$/,/^```$/p' | grep -v '^```' | tr -s ' \n' '\n' | sed '/^$/d')
    printf '%s\n' "$vocab" | grep -qx -- "$agent" \
      || finding "agent-vocabulary: <agent>$agent</agent> is not in the closed list ($(printf '%s' "$vocab" | tr '\n' ' ' | sed 's/ $//'))"
  else
    printf '%s: NOTE agent vocabulary list unreadable at %s — <agent> value not checked\n' "$PROG" "$vocab_file" >&2
  fi
fi

if [ "$findings" -gt 0 ]; then
  record_run block
  exit 2
fi
record_run pass
exit 0
