#!/usr/bin/env bash
# Interactive multi-select over a numbered rows file — the unbounded
# alternative to AskUserQuestion's 4x4 option cap. Run BY THE USER via the
# `!` prefix (needs a real TTY); the model then reads the PICKED line from
# the conversation. Usage:
#   ! bash <path>/pick.sh rows.txt
# rows.txt: one row per line, "<number><TAB><label>".
set -euo pipefail

ROWS_FILE="${1:-}"
if [ -z "$ROWS_FILE" ] || [ ! -f "$ROWS_FILE" ]; then
  echo "usage: pick.sh ROWS_FILE (lines: '<number><TAB><label>')" >&2
  exit 1
fi
if ! (exec 3</dev/tty) 2>/dev/null; then
  echo "pick.sh needs a real TTY — run it yourself with the ! prefix:" >&2
  echo "  ! bash $0 $ROWS_FILE" >&2
  exit 1
fi

if command -v fzf >/dev/null 2>&1; then
  picked=$(fzf --multi --layout=reverse --prompt='pick (TAB to toggle, ENTER to confirm)> ' <"$ROWS_FILE" | cut -f1 | tr '\n' ' ')
else
  cat "$ROWS_FILE"
  printf 'Pick numbers (space/comma separated, ranges like 3-7): '
  read -r input </dev/tty
  picked=""
  for tok in $(printf '%s' "$input" | tr ',' ' '); do
    case "$tok" in
      *-*) start="${tok%%-*}"; end="${tok##*-}"
           case "$start$end" in *[!0-9]*) echo "skip bad token: $tok" >&2; continue;; esac
           i="$start"; while [ "$i" -le "$end" ]; do picked="$picked $i"; i=$((i+1)); done ;;
      ''|*[!0-9]*) [ -n "$tok" ] && echo "skip bad token: $tok" >&2 ;;
      *) picked="$picked $tok" ;;
    esac
  done
fi

valid=""
for n in $picked; do
  if cut -f1 "$ROWS_FILE" | grep -qx "$n"; then valid="$valid $n"; else echo "skip: no row $n" >&2; fi
done
# shellcheck disable=SC2086
echo "PICKED: $(printf '%s\n' $valid | sort -n -u | tr '\n' ' ' | sed 's/ *$//')"
