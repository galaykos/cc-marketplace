#!/usr/bin/env bash
# Flake hunter. Runs a test suite N times across two axes — fixed order and
# randomized order — then set-diffs the per-run results to CLASSIFY each flake,
# not merely detect it.
#
# WHY CLASSIFY. Handed an intermittently red suite, the ordinary move is to re-run
# the one failing test alone, see green, and report "flaky, probably timing". That
# is a guess, and the wrong guess about half the time. The plugin's own
# testing-best-practices already lists the root causes and their fixes; what has
# never existed is the evidence that selects BETWEEN them. Three distinguishable
# shapes, and each implies a different fix:
#
#   order-dependent   fails under shuffle, passes in fixed order
#                     → shared state between tests; fix per-test isolation
#   non-deterministic fails in FIXED order across different seeds/runs
#                     → clock, network, concurrency; freeze time, stub the network
#   leaky             passes alone, fails in the full suite
#                     → a neighbour leaves global state behind
#
#   flake-hunt.sh --cmd "<test command>" [--runs N] [--shuffle "<flag>"]
#                 [--baseline FILE] [--update-baseline]
#
# Exit: 0 no flakes (or none new vs baseline) · 2 flake detected · 3 cannot run
#
# HONEST LIMITATIONS. It observes; it does not diagnose. A test that fails on every
# run is BROKEN, not flaky, and is reported as such rather than counted. N=5 finds
# a 1-in-3 flake reliably and a 1-in-50 flake almost never — absence of a finding
# at N=5 is not evidence of a stable suite, and the report says so. Test-name
# extraction is regex over the runner's output: it recognises the common shapes
# (vitest/jest, pytest, go test, phpunit/pest) and falls back to whole-run
# pass/fail, which still detects flakiness but cannot name the test.
set -u
PROG=${0##*/}

cmd="" ; runs=5 ; shuffle="" ; baseline="" ; update=0
while [ $# -gt 0 ]; do
  case "$1" in
    --cmd) cmd="${2:-}"; shift 2 ;;
    --runs) runs="${2:-5}"; shift 2 ;;
    --shuffle) shuffle="${2:-}"; shift 2 ;;
    --baseline) baseline="${2:-}"; shift 2 ;;
    --update-baseline) update=1; shift ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) printf '%s: unknown argument %s\n' "$PROG" "$1" >&2; exit 3 ;;
  esac
done

[ -n "$cmd" ] || { printf '%s: --cmd "<test command>" is required\n' "$PROG" >&2; exit 3; }
printf '%s' "$runs" | grep -qE '^[0-9]+$' || { printf '%s: --runs must be an integer\n' "$PROG" >&2; exit 3; }
[ "$runs" -ge 2 ] || { printf '%s: --runs must be at least 2 — one run cannot show variance\n' "$PROG" >&2; exit 3; }

WORK=$(mktemp -d) || exit 3
trap 'rm -rf "$WORK"' EXIT

# Failed test names from a run's output. Deliberately several shapes: the point is
# to name the test when possible, not to support one runner.
extract_failures() { # file -> names, one per line
  {
    grep -oE '^[[:space:]]*(FAIL|✕|×|✗)[[:space:]]+.*' "$1" 2>/dev/null | sed -E 's/^[[:space:]]*(FAIL|✕|×|✗)[[:space:]]+//'
    grep -oE '^FAILED [^ ]+' "$1" 2>/dev/null | sed 's/^FAILED //'          # pytest
    grep -oE '^--- FAIL: [^ ]+' "$1" 2>/dev/null | sed 's/^--- FAIL: //'    # go test
    grep -oE '^[0-9]+\) [^ ].*' "$1" 2>/dev/null | sed -E 's/^[0-9]+\) //'  # phpunit
  } | sed 's/[[:space:]]*$//' | sort -u
}

run_once() { # label extra-args outfile -> writes rc to <outfile>.rc
  local label="$1" extra="$2" out="$3"
  # shellcheck disable=SC2086
  ( eval "$cmd $extra" ) > "$out" 2>&1
  printf '%s' "$?" > "$out.rc"
  printf '  %-22s rc=%s  failures=%s\n' "$label" "$(cat "$out.rc")" "$(extract_failures "$out" | wc -l | tr -d ' ')"
}

printf 'flake-hunt: %s run(s) fixed order' "$runs"
[ -n "$shuffle" ] && printf ' + %s run(s) shuffled (%s)' "$runs" "$shuffle"
printf '\ncommand: %s\n\n' "$cmd"

printf 'fixed order:\n'
for i in $(seq 1 "$runs"); do run_once "fixed #$i" "" "$WORK/fixed.$i"; done

if [ -n "$shuffle" ]; then
  printf '\nrandomized order:\n'
  for i in $(seq 1 "$runs"); do run_once "shuffled #$i" "$shuffle" "$WORK/shuf.$i"; done
fi

# --- classify ---------------------------------------------------------------
cat "$WORK"/fixed.*[0-9] 2>/dev/null >/dev/null
fixed_fail_union=$(for i in $(seq 1 "$runs"); do extract_failures "$WORK/fixed.$i"; done | sort -u)
fixed_fail_inter=$(for i in $(seq 1 "$runs"); do extract_failures "$WORK/fixed.$i"; done | sort | uniq -c \
  | awk -v n="$runs" '$1==n {sub(/^ *[0-9]+ /,""); print}')
shuf_fail_union=""
if [ -n "$shuffle" ]; then
  shuf_fail_union=$(for i in $(seq 1 "$runs"); do extract_failures "$WORK/shuf.$i"; done | sort -u)
fi

# broken = failed in EVERY fixed run. Not a flake; reporting it as one sends the
# reader hunting for nondeterminism in a test that is simply red.
broken="$fixed_fail_inter"
nondet=$(comm -23 <(printf '%s\n' "$fixed_fail_union" | sed '/^$/d') <(printf '%s\n' "$broken" | sed '/^$/d'))
order_dep=""
if [ -n "$shuffle" ]; then
  order_dep=$(comm -13 <(printf '%s\n' "$fixed_fail_union" | sed '/^$/d') <(printf '%s\n' "$shuf_fail_union" | sed '/^$/d'))
fi

printf '\n--- classification ---\n'
emit() { # label fix names
  local names; names=$(printf '%s\n' "$3" | sed '/^$/d')
  [ -n "$names" ] || return 0
  printf '\n%s\n  fix lane: %s\n' "$1" "$2"
  printf '%s\n' "$names" | sed 's/^/    /'
}
emit "BROKEN (failed in every fixed run — not flaky)" \
     "read the failure; this test is red, not intermittent" "$broken"
emit "NON-DETERMINISTIC (fails in fixed order, not every time)" \
     "clock, network or concurrency — freeze time, stub the network, remove sleeps" "$nondet"
emit "ORDER-DEPENDENT (only fails under shuffle)" \
     "shared state between tests — isolate per-test fixtures, reset globals in teardown" "$order_dep"

flaky=$(printf '%s\n%s\n' "$nondet" "$order_dep" | sed '/^$/d' | sort -u)
count=$(printf '%s\n' "$flaky" | sed '/^$/d' | wc -l | tr -d ' ')

if [ -z "$shuffle" ]; then
  printf '\nnote: no --shuffle flag given, so ORDER-DEPENDENCE was not tested — the\n'
  printf '      single most common flake class is invisible in this run. Pass your\n'
  printf '      runner'"'"'s randomize flag, e.g. --shuffle "--sequence.shuffle" (vitest),\n'
  printf '      "-p no:randomly" inverted (pytest), "-shuffle=on" (go test).\n'
fi
printf '\nnote: %s runs per axis. A 1-in-3 flake shows up reliably at this N; a\n' "$runs"
printf '      1-in-50 flake almost never does. No finding is not a stable suite.\n'

# --- baseline ratchet -------------------------------------------------------
if [ -n "$baseline" ]; then
  if [ "$update" -eq 1 ]; then
    printf '%s\n' "$flaky" | sed '/^$/d' | sort -u > "$baseline"
    printf '\nbaseline written: %s (%s known flake(s))\n' "$baseline" "$count"
    exit 0
  fi
  if [ -f "$baseline" ]; then
    newly=$(comm -13 <(sort -u "$baseline") <(printf '%s\n' "$flaky" | sed '/^$/d' | sort -u))
    if [ -n "$newly" ]; then
      printf '\nNEW flake(s) not in the baseline:\n'; printf '%s\n' "$newly" | sed 's/^/    /'
      exit 2
    fi
    printf '\nno NEW flakes vs %s\n' "$baseline"
    exit 0
  fi
fi

[ "$count" -gt 0 ] && exit 2
printf '\nno flakes detected.\n'
exit 0
