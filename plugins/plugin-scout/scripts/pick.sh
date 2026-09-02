#!/usr/bin/env bash
# Interactive multi-select over a numbered rows file — the unbounded
# alternative to AskUserQuestion's 4x4 option cap. Run BY THE USER via the
# `!` prefix (needs a real TTY); the model then reads the PICKED line from
# the conversation. Usage:
#   ! bash <path>/pick.sh rows.txt
# rows.txt: one row per line, "<number><TAB><label>".
#
# The two branches select differently and only the numbered one parses tokens.
# fzf selects rows directly — typing filters the list, so there is nothing to
# parse and no `N-M` range to expand. The numbered prompt takes row numbers,
# `N-M` ranges, and label NAMES; it resolves a name itself rather than
# rejecting it, because rejecting one would make a `laravel` that fzf accepts
# by typing depend on whether the user happens to have fzf installed. Name
# matching is case-insensitive, an exact hit on the label's leading name field
# wins outright, else a substring hit, and a name matching several rows is
# reported and skipped rather than guessed at.
#
# CONTRACT: every path past the three invocation errors prints exactly one
# `PICKED: <numbers>` line and exits 0. An abort is an EMPTY pick, not a
# failure — fzf ESC (130), fzf no-match (1) and Ctrl-D at the prompt each
# print a bare `PICKED:`, because the calling skill parses that line and has
# no contract for a bare non-zero exit; under `set -e` + `pipefail` all three
# used to kill the script before it printed anything. A rejected token goes to
# stderr and never aborts the pick. A missing or unreadable ROWS_FILE and an
# unopenable TTY are real errors and still exit 1 — readability is checked here
# because `-f` alone let an unreadable file reach `cut`, which failed under
# `set -e` and leaked a raw `Permission denied` in place of the usage line.
#
# PICK_TTY overrides the device the numbered prompt reads from — the seam that
# lets the harness drive the parser headless. Standing: gate — plugin-scout's
# scripts/__tests__/pick.test.sh covers both copies of this script (kept
# byte-identical by pc_pick_parity) and runs on every PR.
set -euo pipefail

ROWS_FILE="${1:-}"
if [ -z "$ROWS_FILE" ] || [ ! -f "$ROWS_FILE" ] || [ ! -r "$ROWS_FILE" ]; then
  echo "usage: pick.sh ROWS_FILE (lines: '<number><TAB><label>')" >&2
  exit 1
fi
TTY_IN="${PICK_TTY:-/dev/tty}"
if ! (exec 3<"$TTY_IN") 2>/dev/null; then
  echo "pick.sh needs a real TTY — run it yourself with the ! prefix:" >&2
  # Single-quoted: this line exists to be pasted verbatim, and an unquoted
  # path with a space in it pastes as two arguments.
  echo "  ! bash '$0' '$ROWS_FILE'" >&2
  exit 1
fi

# Typed input is split on whitespace; noglob keeps a token like `*` a token
# instead of letting it expand to whatever is in the current directory.
set -f
NL='
'
# Read the rows ONCE: the valid-number set, and the highest row NUMBER a range
# clamps to. `1-1000` against a 20-row file used to build 1000 tokens and run
# 1000 `cut | grep` pipelines.
#
# The ceiling is the highest number, NOT the line count. Report numbers are
# stable across a run while installed rows are filtered out of the picker
# (references/picker.md), so the rows file is sparse whenever anything is
# already installed — which is every run after the first. Clamping to the line
# count made `1-8` over rows 1,2,5,8 pick `1 2`: rows 5 and 8 exist, were
# asked for, and were dropped in silence while the diagnostics blamed rows 3
# and 4, which do not exist.
ROWNUMS="$NL$(cut -f1 "$ROWS_FILE")$NL"
MAX=$(awk -F'\t' '{ if ($1 + 0 > m) m = $1 + 0 } END { print m + 0 }' "$ROWS_FILE")

# Leading zeros: `08` is a row number, not octal, and the digit-length guard
# below must not read `007` as three digits. Parameter expansion rather than
# `sed`, so the cost is one subshell per range operand and no extra process.
strip0() {
  local v="$1"
  while [ "${#v}" -gt 1 ] && [ "${v#0}" != "$v" ]; do v="${v#0}"; done
  printf '%s' "$v"
}

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
            start=$(strip0 "$start"); end=$(strip0 "$end")
            # `$(( ))` wraps mod 2^64 without a word, so a 20-digit operand came
            # back as a small in-range number and the clamp below never fired —
            # a wrong pick reported as a clean success. No row number needs ten
            # digits; refuse them before any arithmetic touches them.
            if [ "${#start}" -gt 9 ] || [ "${#end}" -gt 9 ]; then
              echo "skip bad range: $tok" >&2; continue
            fi
            if [ "$end" -gt "$MAX" ]; then end="$MAX"; fi
            if [ "$start" -gt "$end" ]; then echo "skip bad range: $tok" >&2; continue; fi
            # Emit only numbers the file actually carries: a gap in a sparse
            # rows file is a filtered-out row, not a token to complain about.
            i="$start"
            while [ "$i" -le "$end" ]; do
              case "$ROWNUMS" in *"$NL$i$NL"*) picked="$picked $i" ;; esac
              i=$((i+1))
            done ;;
        esac ;;
      *) picked="$picked $(strip0 "$tok")" ;;   # `01` is row 1, as it is in `01-02`
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
