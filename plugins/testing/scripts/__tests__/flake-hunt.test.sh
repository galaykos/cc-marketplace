#!/usr/bin/env bash
# Fixtures for plugins/testing/scripts/flake-hunt.sh.
#
# The classification is the deliverable, so it is what these lock. Detection alone
# would be satisfied by "something failed sometimes", which is the guess the script
# exists to replace. The three classes imply three different fixes; a scanner that
# merged them would be worse than the guess, because it would look authoritative.
#
# The fake runner is deterministic per case rather than random, so a fixture can
# never flake about flakes.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
S=plugins/testing/scripts/flake-hunt.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

# A runner whose behaviour is driven by a counter file, so run K is predictable.
cat > "$FX/runner.sh" <<'EOF'
#!/bin/bash
c="$1"; shift
n=$(cat "$c" 2>/dev/null || echo 0); n=$((n+1)); printf '%s' "$n" > "$c"
[ -n "${ALWAYS_RED:-}" ] && echo "FAIL  always_red"
# fails on even-numbered runs only: intermittent in FIXED order
[ -n "${SOMETIMES:-}" ] && [ $((n % 2)) -eq 0 ] && echo "FAIL  sometimes_red"
# fails only when the shuffle flag set SHUFFLE=1
[ -n "${SHUFFLE:-}" ] && echo "FAIL  order_dependent"
exit 0
EOF
chmod +x "$FX/runner.sh"

run() { : > "$FX/c"; bash "$S" --cmd "ALWAYS_RED=${1:-} SOMETIMES=${2:-} bash $FX/runner.sh $FX/c" "${@:3}"; }

# --- classification ---------------------------------------------------------
out=$(run 1 1 --runs 6 2>&1)
if printf '%s' "$out" | grep -A2 'BROKEN' | grep -q 'always_red'; then
  echo "PASS: always-failing test classified BROKEN, not flaky"
else echo "FAIL: always-failing test not classified BROKEN"; rc=1; fi

if printf '%s' "$out" | grep -A2 'NON-DETERMINISTIC' | grep -q 'sometimes_red'; then
  echo "PASS: intermittent test classified NON-DETERMINISTIC"
else echo "FAIL: intermittent test not classified NON-DETERMINISTIC"; rc=1; fi

# A broken test must NOT be counted as a flake — that is the whole distinction.
if printf '%s' "$out" | grep -A2 'NON-DETERMINISTIC' | grep -q 'always_red'; then
  echo "FAIL: broken test leaked into the flake class"; rc=1
else echo "PASS: broken test kept out of the flake class"; fi

# --- order dependence needs the shuffle axis --------------------------------
: > "$FX/c"
out=$(bash "$S" --cmd "bash $FX/runner.sh $FX/c" --runs 4 --shuffle "; SHUFFLE=1 bash $FX/runner.sh $FX/c" 2>&1)
if printf '%s' "$out" | grep -A2 'ORDER-DEPENDENT' | grep -q 'order_dependent'; then
  echo "PASS: shuffle-only failure classified ORDER-DEPENDENT"
else echo "FAIL: shuffle-only failure not classified ORDER-DEPENDENT"; rc=1; fi

# Omitting --shuffle must SAY so. A clean run that silently never tested the
# commonest flake class is a false assurance, which is worse than no run.
: > "$FX/c"
out=$(bash "$S" --cmd "bash $FX/runner.sh $FX/c" --runs 3 2>&1)
if printf '%s' "$out" | grep -q 'ORDER-DEPENDENCE was not tested'; then
  echo "PASS: missing --shuffle is disclosed"
else echo "FAIL: missing --shuffle not disclosed"; rc=1; fi

# The N caveat must always print — 'no flakes at N=5' is not 'stable'.
if printf '%s' "$out" | grep -q '1-in-50 flake almost never'; then
  echo "PASS: sample-size caveat printed on a clean run"
else echo "FAIL: sample-size caveat missing"; rc=1; fi

# --- exit codes -------------------------------------------------------------
ec() { local label="$1" want="$2"; shift 2; "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $label (rc=$got)"
  else echo "FAIL: $label — want rc=$want, got $got"; rc=1; fi; }

: > "$FX/c"
ec "clean suite exits 0" 0 bash "$S" --cmd "bash $FX/runner.sh $FX/c" --runs 3
: > "$FX/c"
ec "flake exits 2" 2 bash "$S" --cmd "SOMETIMES=1 bash $FX/runner.sh $FX/c" --runs 6
ec "missing --cmd is a usage error" 3 bash "$S" --runs 3
ec "--runs 1 is a usage error" 3 bash "$S" --cmd "true" --runs 1
ec "non-integer --runs is a usage error" 3 bash "$S" --cmd "true" --runs abc

# --- baseline ratchet: a KNOWN flake must not fail the build twice -----------
: > "$FX/c"
bash "$S" --cmd "SOMETIMES=1 bash $FX/runner.sh $FX/c" --runs 6 --baseline "$FX/flakes.txt" --update-baseline >/dev/null 2>&1
if grep -q 'sometimes_red' "$FX/flakes.txt" 2>/dev/null; then
  echo "PASS: baseline records the known flake"
else echo "FAIL: baseline did not record the flake"; rc=1; fi
: > "$FX/c"
ec "known flake passes against baseline" 0 bash "$S" --cmd "SOMETIMES=1 bash $FX/runner.sh $FX/c" --runs 6 --baseline "$FX/flakes.txt"

# --- replayable seed: the runner's own seed flag, printed on failure, replayed by --seed ---
# This runner logs its arguments and fails under any shuffle, so every shuffled run fails.
cat > "$FX/seedrunner.sh" <<'EOF'
#!/bin/bash
log="$1"; shift
printf '%s\n' "$*" >> "$log"
case " $* " in *" --randomize "*|*"--order-by=random"*|*"-p randomly"*|*"-shuffle="*|*"--sequence.shuffle"*) echo "FAIL  order_dependent" ;; esac
exit 0
EOF
: > "$FX/seedlog"
out=$(bash "$S" --cmd "bash $FX/seedrunner.sh $FX/seedlog" --runs 2 --shuffle "--randomize" 2>&1)
first=$(sed -n 's/^--randomize --seed=\([0-9][0-9]*\)$/\1/p' "$FX/seedlog" | head -1)
if [ -n "$first" ] && printf '%s' "$out" | grep -q "shuffled #1 .*seed=$first"; then
  echo "PASS: each shuffled run gets a seed through the runner's flag, and the run line shows it"
else echo "FAIL: shuffled run seed not passed or not shown"; rc=1; fi
if printf '%s' "$out" | grep -A1 'replay a failing shuffled order' | grep -q -- "--seed $first"; then
  echo "PASS: a failing shuffled run prints its replay command"
else echo "FAIL: no replay line for the failing seed"; rc=1; fi

: > "$FX/seedlog"
out=$(bash "$S" --cmd "bash $FX/seedrunner.sh $FX/seedlog" --runs 3 --shuffle "--randomize" --seed 12345 2>&1)
# Fixed-order runs log an empty line; only the shuffled ones carry flags.
if [ "$(grep . "$FX/seedlog" | sort -u)" = "--randomize --seed=12345" ] && [ "$(grep -c . "$FX/seedlog")" = 3 ]; then
  echo "PASS: --seed 12345 replays that seed in every shuffled run"
else echo "FAIL: --seed did not replay the seed: $(grep . "$FX/seedlog" | sort -u | tr '\n' '|')"; rc=1; fi

for pair in "--order-by=random|--order-by=random --random-order-seed=12345" \
            "-p randomly|-p randomly --randomly-seed=12345" \
            "-shuffle=on|-shuffle=12345" \
            "--sequence.shuffle|--sequence.shuffle --sequence.seed=12345"; do
  flag=${pair%%|*}; want=${pair#*|}; : > "$FX/seedlog"
  bash "$S" --cmd "bash $FX/seedrunner.sh $FX/seedlog" --runs 2 --shuffle "$flag" --seed 12345 >/dev/null 2>&1
  if [ "$(grep . "$FX/seedlog" | sort -u)" = "$want" ]; then echo "PASS: --shuffle \"$flag\" replays as \"$want\""
  else echo "FAIL: --shuffle \"$flag\" sent \"$(grep . "$FX/seedlog" | sort -u | tr '\n' '|')\", want \"$want\""; rc=1; fi
done

# Nearest silent input: a shuffle flag flake-hunt does not know keeps its old behaviour, no seed claimed.
: > "$FX/c"
out=$(bash "$S" --cmd "bash $FX/runner.sh $FX/c" --runs 2 --shuffle "; true" 2>&1)
if printf '%s' "$out" | grep -qE 'seed=|replay a failing'; then
  echo "FAIL: an unknown shuffle flag was given a seed"; rc=1
else echo "PASS: an unknown shuffle flag runs verbatim, with no seed claimed"; fi

ec "--seed without --shuffle is a usage error" 3 bash "$S" --cmd "true" --seed 5
ec "a non-integer --seed is a usage error" 3 bash "$S" --cmd "true" --shuffle "--randomize" --seed abc
ec "--seed with an unknown shuffle flag is a usage error" 3 bash "$S" --cmd "true" --shuffle "--mystery" --seed 5

[ "$rc" -eq 0 ] && echo "All flake-hunt fixtures passed."
exit "$rc"
