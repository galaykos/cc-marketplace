#!/usr/bin/env bash
# Interactive multi-select over a numbered rows file — the unbounded
# alternative to AskUserQuestion's 4x4 option cap. Run BY THE USER via the
# `!` prefix (needs a real TTY); the model then reads the PICKED line from
# the conversation. Usage:
#   ! bash <path>/pick.sh rows.txt
# rows.txt: one row per line, "<number><TAB><label>".
#
# Both branches take the same three token kinds — row numbers, `N-M` ranges,
# and label NAMES. fzf filters by typing, so the numbered prompt resolves a
# name itself rather than rejecting it: case-insensitive, an exact hit on the
# label's leading name field wins outright, else a substring hit, and a name
# matching several rows is reported and skipped rather than guessed at.
#
# CONTRACT: every path past the two invocation errors prints exactly one
# `PICKED: <numbers>` line and exits 0. An abort is an EMPTY pick, not a
# failure — fzf ESC (130), fzf no-match (1) and Ctrl-D at the prompt each
# print a bare `PICKED:`, because the calling skill parses that line and has
# no contract for a bare non-zero exit; under `set -e` + `pipefail` all three
# used to kill the script before it printed anything. A rejected token goes to
# stderr and never aborts the pick. A missing ROWS_FILE and an unopenable TTY
# are real errors and still exit 1.
#
# PICK_TTY overrides the device the numbered prompt reads from — the seam that
# lets the harness drive the parser headless. Standing: gate — plugin-scout's
# scripts/__tests__/pick.test.sh covers both copies of this script (kept
# byte-identical by pc_pick_parity) and runs on every PR.
set -euo pipefail

ROWS_FILE="${1:-}"
if [ -z "$ROWS_FILE" ] || [ ! -f "$ROWS_FILE" ]; then
  echo "usage: pick.sh ROWS_FILE (lines: '<number><TAB><label>')" >&2
  exit 1
fi
TTY_IN="${PICK_TTY:-/dev/tty}"
if ! (exec 3<"$TTY_IN") 2>/dev/null; then
  echo "pick.sh needs a real TTY — run it yourself with the ! prefix:" >&2
  echo "  ! bash $0 $ROWS_FILE" >&2
  exit 1
fi

# Typed input is split on whitespace; noglob keeps a token like `*` a token
# instead of letting it expand to whatever is in the current directory.
set -f
NL='
'
# Read the rows ONCE: the valid-number set, and the row count a range clamps
# to. `1-1000` against a 20-row file used to build 1000 tokens and run 1000
# `cut | grep` pipelines.
ROWNUMS="$NL$(cut -f1 "$ROWS_FILE")$NL"
MAX=$(awk 'END { print NR }' "$ROWS_FILE")

# Row numbers whose label matches $1. Exact-name hits suppress substring hits,
# so `react` picks `react` and not also `react-native`.
match_rows() {
  awk -v pat="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" '
    { num = $0; sub(/\t.*$/, "", num)
      lbl = $0; sub(/^[^\t]*\t/, "", lbl); lbl = tolower(lbl)
      name = lbl; sub(/[ \t].*$/, "", name)
      if (name == pat) exact = exact num "\n"
      else if (index(lbl, pat)) part = part num "\n" }
    END { printf "%s", (exact != "" ? exact : part) }
  ' "$ROWS_FILE" | tr '\n' ' ' | sed 's/ *$//'
}

if command -v fzf >/dev/null 2>&1; then
  # ESC exits 130 and no-match exits 1; `pipefail` would turn either into a
  # dead script, so the whole pipeline is caught and read as an empty pick.
  picked=$(fzf --multi --layout=reverse --prompt='pick (TAB to toggle, ENTER to confirm)> ' <"$ROWS_FILE" | cut -f1 | tr '\n' ' ' || true)
else
  cat "$ROWS_FILE"
  printf 'Pick numbers, names or ranges (space/comma separated, e.g. 1 4-7 code-review): '
  input=""
  read -r input <"$TTY_IN" || true   # Ctrl-D is an empty pick, not a crash
  # The prompt above ends without a newline. A terminal echoes the user's
  # ENTER and closes the line; nothing else does, and then PICKED: would be
  # appended to the prompt line where no `^PICKED:` parse can see it.
  printf '\n'
  picked=""
  for tok in $(printf '%s' "$input" | tr ',' ' '); do
    case "$tok" in
      *[!0-9]*)
        case "$tok" in
          *[!0-9-]*)   # a name: anything that is not digits-and-hyphens
            matches=$(match_rows "$tok")
            case "$matches" in
              '')    echo "skip: no row matching '$tok'" >&2 ;;
              *' '*) echo "skip ambiguous: '$tok' matches rows $matches" >&2 ;;
              *)     picked="$picked $matches" ;;
            esac ;;
          *-*-*) echo "skip bad range: $tok" >&2 ;;
          *)     # N-M — validate each operand on its own; concatenating them
                 # let `-2` and `2-` through into a raw bash error.
            start="${tok%%-*}"; end="${tok##*-}"
            case "$start" in ''|*[!0-9]*) echo "skip bad range: $tok" >&2; continue ;; esac
            case "$end"   in ''|*[!0-9]*) echo "skip bad range: $tok" >&2; continue ;; esac
            start=$((10#$start)); end=$((10#$end))   # 08 is not octal here
            if [ "$end" -gt "$MAX" ]; then end="$MAX"; fi
            if [ "$start" -gt "$end" ]; then echo "skip bad range: $tok" >&2; continue; fi
            i="$start"; while [ "$i" -le "$end" ]; do picked="$picked $i"; i=$((i+1)); done ;;
        esac ;;
      *) picked="$picked $tok" ;;
    esac
  done
fi

valid=""
for n in $picked; do
  case "$ROWNUMS" in
    *"$NL$n$NL"*) valid="$valid $n" ;;
    *) echo "skip: no row $n" >&2 ;;
  esac
done
sorted=""
if [ -n "$valid" ]; then
  # shellcheck disable=SC2086
  sorted=$(printf '%s\n' $valid | sort -n -u | tr '\n' ' ' | sed 's/ *$//')
fi
printf 'PICKED:%s\n' "${sorted:+ $sorted}"
