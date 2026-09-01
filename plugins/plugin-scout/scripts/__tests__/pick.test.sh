#!/usr/bin/env bash
# Fixture tests for scripts/pick.sh — the TTY multi-select both scout plugins ship.
# pc_pick_parity keeps the two copies byte-identical, so this one harness covers both.
# Picked up by the shared CI step globbing plugins/*/scripts/__tests__/*.test.sh.
#
# WHY THIS FILE EXISTS. The picker's entire contract with the calling skill is ONE
# parseable `PICKED:` line, and three separate paths broke it. Each was measured
# against the pre-fix script on 2026-08-28, not inferred:
#   - fzf ESC exits 130, fzf no-match exits 1, and Ctrl-D at the prompt fails `read`.
#     Under `set -e` + `pipefail` each killed the script before the final echo, so an
#     abort produced no line at all and the skill had nothing to parse.
#   - the range guard concatenated its operands (`case "$start$end"`), so an empty one
#     slipped through: `-2` and `2-` leaked a raw `[: : integer expression expected`,
#     `3-1` was a silent no-op, and `1-3-2` was silently reinterpreted as `1 2` — a
#     WRONG pick reported as a clean success, the worst of the four.
#   - `laravel` is a filter the fzf branch accepts by typing and the numbered branch
#     rejected as `skip bad token`, so which input was legal depended on whether the
#     user happened to have fzf installed.
# Cases 4-7 and 15-16 are those regressions; the rest guard the fix from over-reaching
# (a name must not be GUESSED when ambiguous, a range must not silently drop rows).
#
# HEADLESS BY CONSTRUCTION. PICK_TTY substitutes a file for /dev/tty, and PATH is a
# sandbox of symlinks holding exactly what pick.sh calls — so `command -v fzf` sees
# only the stub installed here. Without that, a developer machine with fzf on PATH
# would take the fzf branch every time and never execute the parser at all.
set -u

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PICK="$ROOT/scripts/pick.sh"
[ -f "$PICK" ] || { echo "FAIL: pick.sh not found at $PICK"; exit 2; }
grep -q 'PICK_TTY' "$PICK" || { echo "FAIL: pick.sh no longer honours PICK_TTY — this harness cannot drive it, and a green run would mean nothing"; exit 2; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; rc=1; }

BIN="$TMP/bin"; FZFBIN="$TMP/fzfbin"; mkdir -p "$BIN" "$FZFBIN"
# Wider than pick.sh currently calls: a sandbox that is exactly today's call list turns
# tomorrow's added utility into "command not found" on every case at once, which reads
# as 28 broken assertions rather than one missing symlink.
for c in bash cut awk sort sed tr cat grep head wc; do
  p="$(command -v "$c")" || { echo "FAIL: $c is not on PATH"; exit 2; }
  ln -s "$p" "$BIN/$c"
done
cat > "$FZFBIN/fzf" <<'SH'
#!/bin/sh
# stub fzf: drain the rows it would display, replay a canned selection, exit FZF_RC.
cat >/dev/null
[ -n "${FZF_OUT:-}" ] && [ -f "$FZF_OUT" ] && cat "$FZF_OUT"
exit "${FZF_RC:-0}"
SH
chmod +x "$FZFBIN/fzf"

ROWS="$TMP/rows.txt"
{ printf '1\tcode-review — review the diff\n'
  printf '2\tlaravel — Laravel 12 patterns\n'
  printf '3\treact-native — RN patterns\n'
  printf '4\treact — React 19 patterns\n'
  printf '5\ttesting — test shape\n'; } > "$ROWS"

OUT=""; ERR=""; RC=0
run() { # $1 typed input; a newline is appended, as pressing ENTER does
  printf '%s\n' "$1" > "$TMP/in"
  OUT=$(PICK_TTY="$TMP/in" PATH="$BIN" bash "$PICK" "$ROWS" 2>"$TMP/err"); RC=$?
  ERR=$(cat "$TMP/err")
}
run_fzf() { # $1 fzf exit code, [$2 file of rows fzf "selected"]
  OUT=$(FZF_RC="$1" FZF_OUT="${2:-}" PICK_TTY=/dev/null PATH="$FZFBIN:$BIN" \
        bash "$PICK" "$ROWS" 2>"$TMP/err" </dev/null); RC=$?
  ERR=$(cat "$TMP/err")
}
# Every case asserts the SAME three things, because they are the contract: exit 0,
# exactly one PICKED line, and its exact content. A second line, or a line merged
# into the un-terminated prompt, is unparseable even when the numbers are right.
assert() { # $1 label, $2 want PICKED line, [$3 want stderr substring]
  local n got
  n=$(printf '%s\n' "$OUT" | grep -c '^PICKED:')
  got=$(printf '%s\n' "$OUT" | grep '^PICKED:')
  if [ "$RC" -ne 0 ]; then
    fail "$1" "exit $RC, want 0 — an abort is an empty pick, not an error. stderr: ${ERR:-<none>}"; return
  fi
  if [ "$n" != "1" ]; then fail "$1" "$n lines matching ^PICKED:, want exactly 1"; return; fi
  if [ "$got" != "$2" ]; then fail "$1" "want '$2', got '$got'"; return; fi
  if [ -n "${3:-}" ]; then
    case "$ERR" in *"$3"*) ;; *) fail "$1" "stderr missing '$3' — got: ${ERR:-<none>}"; return ;; esac
  fi
  pass "$1"
}
expect() { run "$2"; assert "$1" "$3" "${4:-}"; }

# ---- 1-3. the ordinary cases the picker exists for ----------------------------------
expect "numbers"                  "1 3"        "PICKED: 1 3"
expect "comma separated"          "1,3"        "PICKED: 1 3"
[ -z "$ERR" ] || { fail "a valid pick says nothing on stderr" "got: $ERR"; }
expect "a range"                  "2-4"        "PICKED: 2 3 4"
expect "sorted and deduped"       "3 1 3 2-2"  "PICKED: 1 2 3"

# ---- 4-7. THE FOUR MALFORMED RANGES ---------------------------------------------------
# All four were accepted before. 1-3-2 is the one that mattered: it did not fail, it
# picked the WRONG rows, so nothing downstream could tell it had been misread.
expect "empty start operand"      "-2"         "PICKED:" "skip bad range: -2"
expect "empty end operand"        "2-"         "PICKED:" "skip bad range: 2-"
expect "reversed range"           "3-1"        "PICKED:" "skip bad range: 3-1"
expect "multi-hyphen range"       "1-3-2"      "PICKED:" "skip bad range: 1-3-2"
# The empty-operand forms leaked bash's own diagnostic into the user's terminal.
run "-2"
case "$ERR" in *"integer expression expected"*)
  fail "no raw bash error escapes to the user" "got: $ERR" ;;
  *) pass "no raw bash error escapes to the user" ;;
esac

# ---- 8-9. a range is clamped, not expanded --------------------------------------------
# 1-1000 built a thousand tokens and ran a thousand cut|grep pipelines to reject 995.
expect "range clamped to the highest row number" "1-1000" "PICKED: 1 2 3 4 5"
expect "range starting past the end"    "9-20"   "PICKED:" "skip bad range: 9-20"
# A 20-digit operand wrapped mod 2^64 into a small in-range number, so the clamp never
# fired and the range picked rows nobody typed — the 1-3-2 failure through another door.
expect "operand too long to be a row"   "1-18446744073709551620" "PICKED:" "skip bad range:"
# `01` was a row number inside a range (`10#`) and an unknown row on its own.
expect "leading zeros mean the same in both forms" "01 02-03" "PICKED: 1 2 3"

# ---- 9b. THE SPARSE ROWS FILE -----------------------------------------------------------
# The regression the contiguous fixture above cannot see. picker.md numbers rows stably
# across the run and filters installed ones out of the pick list, so the rows file has
# gaps whenever anything is installed — every run after the first. The clamp read the
# LINE COUNT as the ceiling, so `1-8` over rows 1,2,5,8 returned `1 2`: two requested,
# existing rows dropped silently, with the diagnostics blaming rows that do not exist.
SPARSE="$TMP/sparse.txt"
{ printf '1\talpha — first\n'; printf '2\tbeta — second\n'
  printf '5\tgamma — third\n'; printf '8\tdelta — fourth\n'; } > "$SPARSE"
run_sparse() { printf '%s\n' "$1" > "$TMP/in"
  OUT=$(PICK_TTY="$TMP/in" PATH="$BIN" bash "$PICK" "$SPARSE" 2>"$TMP/err"); RC=$?
  ERR=$(cat "$TMP/err"); }
run_sparse "1-8";  assert "a range spans gaps in a sparse rows file" "PICKED: 1 2 5 8"
[ -z "$ERR" ] || fail "a gap is not a rejected token" "stderr should be silent, got: $ERR"
run_sparse "3-7";  assert "a range covering only gaps picks nothing" "PICKED: 5"
run_sparse "5 8";  assert "sparse rows still pick by number" "PICKED: 5 8"
run_sparse "1-99"; assert "clamp uses the highest number, not the count" "PICKED: 1 2 5 8"

# ---- 10-14. names: the input the two branches disagreed about --------------------------
expect "a name resolves to its row"   "laravel"      "PICKED: 2"
expect "name matching is case-blind"  "LARAVEL"      "PICKED: 2"
expect "a hyphenated name is a name, not a range" "react-native" "PICKED: 3"
# `react` is a substring of `react-native`; the exact leading-name hit must win outright
# or the commonest name in a table would be permanently unpickable as ambiguous.
expect "exact name beats substring"   "react"        "PICKED: 4"
expect "ambiguity is refused, not guessed" "patterns" "PICKED:" "skip ambiguous: 'patterns' matches rows 2 3 4"
expect "unknown name"                 "zzz"          "PICKED:" "skip: no row matching 'zzz'"
expect "out-of-range number"          "9"            "PICKED:" "skip: no row 9"
expect "a typed glob stays a token"   "*"            "PICKED:" "skip: no row matching '*'"

# ---- 15. the abort paths: empty input, and EOF without one ------------------------------
expect "empty input"                  ""             "PICKED:"
OUT=$(PICK_TTY=/dev/null PATH="$BIN" bash "$PICK" "$ROWS" 2>"$TMP/err"); RC=$?
ERR=$(cat "$TMP/err"); assert "Ctrl-D at the prompt" "PICKED:"
# EOF on a line that was typed but never ENTERed: read fails AND assigns.
printf '1 3' > "$TMP/in2"
OUT=$(PICK_TTY="$TMP/in2" PATH="$BIN" bash "$PICK" "$ROWS" 2>"$TMP/err"); RC=$?
ERR=$(cat "$TMP/err"); assert "EOF keeps what was already typed" "PICKED: 1 3"

# ---- 16. the fzf branch: both of its non-zero exits are empty picks, not failures -------
SEL="$TMP/sel"; { printf '2\tlaravel — Laravel 12 patterns\n'; printf '4\treact — React 19 patterns\n'; } > "$SEL"
run_fzf 0 "$SEL";  assert "fzf selection"          "PICKED: 2 4"
run_fzf 130 "";    assert "fzf ESC (exit 130)"     "PICKED:"
run_fzf 1 "";      assert "fzf no match (exit 1)"  "PICKED:"

# ---- 17. and the two REAL errors still exit non-zero ------------------------------------
# An empty pick and a broken invocation must not look alike: the first is an answer.
err_case() { # $1 label, $2 want stderr substring; runs "$@" from index 3
  local label="$1" want="$2"; shift 2
  local o e
  o=$("$@" 2>&1); e=$?
  if [ "$e" -eq 0 ]; then fail "$label" "exit 0, want non-zero"; return; fi
  case "$o" in *"$want"*) ;; *) fail "$label" "stderr missing '$want' — got: $o"; return ;; esac
  case "$o" in *PICKED:*) fail "$label" "printed a PICKED line on an error path: $o"; return ;; esac
  pass "$label"
}
err_case "no argument"        "usage: pick.sh"   env PATH="$BIN" bash "$PICK"
err_case "missing rows file"  "usage: pick.sh"   env PATH="$BIN" bash "$PICK" "$TMP/nope.txt"
err_case "no usable TTY"      "needs a real TTY" env PATH="$BIN" PICK_TTY="$TMP/no/such/dev" bash "$PICK" "$ROWS"
# `-f` alone passed an unreadable file to `cut`, which died under `set -e` and printed
# bash's own diagnostic instead of the usage line. Root can read anything, so skip there
# rather than assert something the environment makes false.
NOREAD="$TMP/noread.txt"; cp "$ROWS" "$NOREAD"; chmod 000 "$NOREAD"
if [ -r "$NOREAD" ]; then
  printf 'SKIP  unreadable rows file (running as root — chmod 000 is still readable)\n'
else
  err_case "unreadable rows file" "usage: pick.sh" env PATH="$BIN" bash "$PICK" "$NOREAD"
fi
chmod 644 "$NOREAD"

printf '\n'
[ "$rc" -eq 0 ] && printf 'pick.test: all cases passed\n' || printf 'pick.test: FAILURES above\n'
exit "$rc"
