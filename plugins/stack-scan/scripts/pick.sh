#!/usr/bin/env bash
# pick.sh ROWS_FILE — multi-select over "<number><TAB><label>" rows, run BY THE USER (`! bash <path>/pick.sh rows.txt`, a real TTY; PICK_TTY overrides the device): fzf when installed, else a numbered prompt taking numbers, `N-M` ranges and label names. Prints exactly one `PICKED: <numbers>` line and exits 0 past the invocation errors (an abort is an empty pick; a rejected token goes to stderr); a missing or unreadable ROWS_FILE or no TTY exits 1.
# Misses: a name matching several rows (reported and skipped, never guessed; an exact name beats a substring); ranges and names under fzf, where typing filters the list instead; a range operand of ten digits or more (refused).
# Why, limits, history: rationale/derivations/plugin-stack-scan.md § plugins/stack-scan/scripts/pick.sh
set -euo pipefail

ROWS_FILE="${1:-}"
if [ -z "$ROWS_FILE" ] || [ ! -f "$ROWS_FILE" ] || [ ! -r "$ROWS_FILE" ]; then
  echo "usage: pick.sh ROWS_FILE (lines: '<number><TAB><label>')" >&2
  exit 1
fi
TTY_IN="${PICK_TTY:-/dev/tty}"
if ! (exec 3<"$TTY_IN") 2>/dev/null; then
  echo "pick.sh needs a real TTY — run it yourself with the ! prefix:" >&2
  # Single-quoted: the line is pasted verbatim, and an unquoted path with a space pastes as two arguments.
  echo "  ! bash '$0' '$ROWS_FILE'" >&2
  exit 1
fi

# noglob: a typed `*` stays a token instead of expanding to the current directory's files.
set -f
NL='
'
# A range clamps to the highest row NUMBER, not the line count: installed rows are filtered out, so the file is sparse.
ROWNUMS="$NL$(cut -f1 "$ROWS_FILE")$NL"
MAX=$(awk -F'\t' '{ if ($1 + 0 > m) m = $1 + 0 } END { print m + 0 }' "$ROWS_FILE")

# `08` is a row number, not octal, and the digit-length guard must not read `007` as three digits.
strip0() {
  local v="$1"
  while [ "${#v}" -gt 1 ] && [ "${v#0}" != "$v" ]; do v="${v#0}"; done
  printf '%s' "$v"
}

# Row numbers whose label matches $1; exact-name hits suppress substring hits (`react` does not also pick `react-native`).
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
  # ESC exits 130 and no-match 1; under pipefail either would kill the script, so both read as an empty pick.
  picked=$(fzf --multi --layout=reverse --prompt='pick (TAB to toggle, ENTER to confirm)> ' <"$ROWS_FILE" | cut -f1 | tr '\n' ' ' || true)
else
  cat "$ROWS_FILE"
  printf 'Pick numbers, names or ranges (space/comma separated, e.g. 1 4-7 code-review): '
  input=""
  read -r input <"$TTY_IN" || true   # Ctrl-D is an empty pick, not a crash
  # Off a terminal nothing closes the prompt line, and PICKED: would land where no `^PICKED:` parse sees it.
  printf '\n'
  picked=""
  # Label names are accepted: rejecting them would make `laravel` work or fail depending on whether fzf is installed.
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
            # `$(( ))` wraps mod 2^64 silently: an operand of ten digits or more is refused before any arithmetic.
            if [ "${#start}" -gt 9 ] || [ "${#end}" -gt 9 ]; then
              echo "skip bad range: $tok" >&2; continue
            fi
            if [ "$end" -gt "$MAX" ]; then end="$MAX"; fi
            if [ "$start" -gt "$end" ]; then echo "skip bad range: $tok" >&2; continue; fi
            # A gap in a sparse rows file is a filtered-out row, not a token to complain about.
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
