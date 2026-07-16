#!/usr/bin/env bash
# behavioral-gate.sh — B1 completion gate: classify + own-tests + empty-detect + zero-check.
#
# Deepest root cause this closes: the repo completion gate is a *static* linter — no
# stage ever RUNS the produced artifact's own tests, so a code-producing run that
# ships zero runnable check sails through green. This gate:
#   (a) CLASSIFY   the touched files -> languages -> a real test runner.
#   (b) OWN-TESTS  run that runner non-interactively, under a hard timeout, applying
#                  per-runner EMPTY-DETECTION.
#   (c) ZERO-CHECK a needs-coverage run that ships no runnable own-test FAILs.
#   (d) HONEST report to stderr of what ran / was skipped / the verdict label.
#
# Per-runner empty-detection recipe: references/runners.md — the table there mirrors
# the EMPTY-DETECT logic below; THIS SCRIPT is the source of truth.
#
# Exit contract:
#   0  covered  OR honest  no-executable-surface
#   2  fail:     empty-suite | no-behavioral-coverage | unverifiable-suite (fail-closed)
#   3  usage
#
# SAFETY: this gate RUNS code (the artifact's own tests). It runs each runner in the
# current working directory and writes NOTHING into that tree (runner output is
# captured to a mktemp file OUTSIDE it). Invoke it from a disposable checkout / temp
# fixture so a misbehaving suite cannot mutate a live repo — the test harness does
# exactly that and asserts `git status --porcelain` is byte-identical before/after.

set -euo pipefail

PROG=behavioral-gate
log()   { printf '%s: %s\n' "$PROG" "$*" >&2; }
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

TIMEOUT_SECS="${BEHAVIORAL_GATE_TIMEOUT:-60}"

# ---- portable hard-timeout wrapper -----------------------------------------
# Prefers coreutils `timeout`/`gtimeout`; falls back to a perl alarm+fork (rc 124 on
# timeout, GNU-compatible); last resort runs uncapped with a logged warning.
run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout  >/dev/null 2>&1; then timeout  "$secs" "$@"; return $?; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@"; return $?; fi
  if command -v perl >/dev/null 2>&1; then
    perl -e '
      my $s = shift @ARGV;
      my $pid = fork();
      defined $pid or exit 127;
      if ($pid == 0) { exec @ARGV or exit 127; }
      local $SIG{ALRM} = sub { kill "TERM", $pid; sleep 1; kill "KILL", $pid; exit 124; };
      alarm $s; waitpid($pid, 0); my $st = $?; alarm 0;
      exit($st & 127 ? 128 + ($st & 127) : $st >> 8);
    ' "$secs" "$@"; return $?
  fi
  log "no timeout facility (timeout/gtimeout/perl) — running WITHOUT a hard cap"
  "$@"; return $?
}

# ---- arg parse: --changed accepts a space/newline list OR repeated flag -----
CHANGED=()
add_changed() {
  local raw="$1" tok _o="$IFS"
  set -f; IFS=$' \t\n'
  for tok in $raw; do [ -n "$tok" ] && CHANGED+=("$tok"); done
  IFS="$_o"; set +f
}
while [ $# -gt 0 ]; do
  case "$1" in
    --changed)   shift; [ $# -gt 0 ] || usage "--changed requires a value"; add_changed "$1"; shift ;;
    --changed=*) add_changed "${1#--changed=}"; shift ;;
    -h|--help)   printf 'usage: %s --changed <file-or-list> [--changed <more>]\n' "$PROG" >&2; exit 3 ;;
    --*)         usage "unknown flag: $1" ;;
    *)           add_changed "$1"; shift ;;
  esac
done
[ "${#CHANGED[@]}" -gt 0 ] || usage "no --changed files given (want --changed <file-or-list>)"

# ---- (a) CLASSIFY: touched files -> language flags --------------------------
HAS_PY=0; HAS_JS=0; HAS_GO=0; HAS_DOC=0; HAS_OPAQUE=0
for f in "${CHANGED[@]}"; do
  base="${f##*/}"; ext="${base##*.}"; [ "$ext" = "$base" ] && ext=""
  case "$ext" in
    py)                        HAS_PY=1 ;;
    js|mjs|cjs|jsx|ts|tsx)     HAS_JS=1 ;;
    go)                        HAS_GO=1 ;;
    md|json|txt|yml|yaml|sh)   HAS_DOC=1 ;;   # .sh treated as doc/non-exec surface
    *)                         HAS_OPAQUE=1 ;;
  esac
done
log "classify: py=$HAS_PY js=$HAS_JS go=$HAS_GO doc=$HAS_DOC opaque=$HAS_OPAQUE (files=${#CHANGED[@]})"

runners=()
[ "$HAS_PY" = 1 ] && runners+=("py")
[ "$HAS_JS" = 1 ] && runners+=("js")
[ "$HAS_GO" = 1 ] && runners+=("go")

if [ "${#runners[@]}" -eq 0 ]; then
  if [ "$HAS_OPAQUE" = 1 ]; then
    log "needs behavioral coverage but NO test runner resolves for the touched types"
    log "VERDICT: no-behavioral-coverage"
    exit 2
  fi
  log "only non-executable/doc types touched (.md/.json/.txt/.yml/.yaml/.sh); no runner resolvable"
  log "VERDICT: no-executable-surface (honest lint-only; nothing to run)"
  exit 0
fi

# ---- ZERO-CHECK helpers: is a runnable own-test statically present? ---------
py_has_tests() { find . -type f \( -name 'test_*.py' -o -name '*_test.py' \) 2>/dev/null | grep -q .; }
js_has_tests() {
  find . -type d -name node_modules -prune -o -type f \
    \( -name '*.test.js' -o -name '*.test.mjs' -o -name '*.test.cjs' -o -name '*.test.ts' \
       -o -name '*.spec.js' -o -name '*-test.js' -o -name '*_test.js' \) -print 2>/dev/null | grep -q .
}
go_has_tests() { find . -type f -name '*_test.go' 2>/dev/null | grep -q .; }

pkg_test_script() {
  [ -f package.json ] || { printf ''; return 0; }
  if command -v jq >/dev/null 2>&1; then
    jq -r '.scripts.test // empty' package.json 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    node -e 'try{const p=require("./package.json");process.stdout.write((p.scripts&&p.scripts.test)||"")}catch(e){}' 2>/dev/null
  else
    printf ''
  fi
}

# ---- run a runner, capture combined output + exit code (no tree writes) -----
CAP=""; RUN_RC=0
run_capture() {
  local tmp; tmp=$(mktemp)
  set +e
  run_with_timeout "$TIMEOUT_SECS" "$@" >"$tmp" 2>&1
  RUN_RC=$?
  set -e
  CAP=$(cat "$tmp"); rm -f "$tmp"
}

# ---- (b)+(c) per-runner verdict: covered | empty-suite | no-behavioral-coverage | unverifiable-suite
verdict_py() {
  if ! py_has_tests; then
    log "pytest: no test_*.py / *_test.py present — no runnable own-test"; printf 'no-behavioral-coverage\n'; return
  fi
  if ! command -v pytest >/dev/null 2>&1; then
    log "pytest: tests present but 'pytest' not installed — cannot verify (fail-closed)"; printf 'unverifiable-suite\n'; return
  fi
  log "pytest: running 'pytest -q -p no:cacheprovider' (timeout ${TIMEOUT_SECS}s)"
  run_capture pytest -q -p no:cacheprovider
  log "pytest: exit=$RUN_RC"
  case "$RUN_RC" in
    5)   printf 'empty-suite\n' ;;                                             # exit 5 = no tests collected
    124) log "pytest: TIMED OUT"; printf 'unverifiable-suite\n' ;;
    0)   printf 'covered\n' ;;                                                 # >=1 test collected & passed
    1)   log "pytest: suite RED (>=1 test failed) — coverage present"; printf 'covered\n' ;;
    *)   log "pytest: abnormal exit $RUN_RC — cannot confirm a suite ran (fail-closed)"; printf 'unverifiable-suite\n' ;;
  esac
}

verdict_js() {
  local script; script=$(pkg_test_script)
  if [ -n "$script" ]; then verdict_pkg "$script"; return; fi
  if ! js_has_tests; then
    log "node --test: no *.test.* / *_test.* present — no runnable own-test"; printf 'no-behavioral-coverage\n'; return
  fi
  if ! command -v node >/dev/null 2>&1; then
    log "node --test: tests present but 'node' not installed (fail-closed)"; printf 'unverifiable-suite\n'; return
  fi
  log "node --test: running (auto-discovery, timeout ${TIMEOUT_SECS}s)"
  run_capture node --test
  log "node --test: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "node --test: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  # Node 24 counts each discovered file as a test; a genuine empty run reports 'tests 0'.
  if printf '%s\n' "$CAP" | grep -Eq 'tests[[:space:]]+0([^0-9]|$)'; then printf 'empty-suite\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eq 'tests[[:space:]]+[1-9][0-9]*'; then printf 'covered\n'; return; fi
  log "node --test: no parseable 'tests N' summary (exit=$RUN_RC) — cannot confirm (fail-closed)"
  printf 'unverifiable-suite\n'
}

verdict_pkg() {
  local script="$1"
  case "$script" in
    *--passWithNoTests*) log "WARNING: test script carries --passWithNoTests; empty suites are masked green" ;;
  esac
  log "package.json test script: [$script] — running via 'sh -c' (timeout ${TIMEOUT_SECS}s)"
  run_capture sh -c "$script"
  log "package.json test: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "package.json test: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eiq \
      'tests[[:space:]]+[1-9]|[1-9][0-9]*[[:space:]]+passing|Tests:[[:space:]].*[1-9].*(passed|total)|[1-9][0-9]*[[:space:]]+passed'; then
    printf 'covered\n'; return
  fi
  if printf '%s\n' "$CAP" | grep -Eiq 'No tests found|tests[[:space:]]+0([^0-9]|$)|0[[:space:]]+total|0[[:space:]]+passing'; then
    printf 'empty-suite\n'; return
  fi
  log "package.json test: no parseable test count in output — refusing to assume coverage (fail-closed)"
  printf 'unverifiable-suite\n'
}

verdict_go() {
  if ! go_has_tests; then
    log "go test: no *_test.go present — no runnable own-test"; printf 'no-behavioral-coverage\n'; return
  fi
  if ! command -v go >/dev/null 2>&1; then
    log "go test: tests present but 'go' not installed (fail-closed)"; printf 'unverifiable-suite\n'; return
  fi
  log "go test: running 'go test ./...' (timeout ${TIMEOUT_SECS}s)"
  run_capture go test ./...
  log "go test: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "go test: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eq 'no test files'; then printf 'empty-suite\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eq '^(ok|PASS|FAIL|---)'; then printf 'covered\n'; return; fi
  log "go test: no parseable result — fail-closed"; printf 'unverifiable-suite\n'
}

verdicts=()
for r in "${runners[@]}"; do
  case "$r" in
    py) v=$(verdict_py) ;;
    js) v=$(verdict_js) ;;
    go) v=$(verdict_go) ;;
  esac
  verdicts+=("$r=$v")
  if [ "$v" = covered ]; then log "runner[$r]: covered"; else log "runner[$r]: FAIL ($v)"; fi
done

# --- entrypoint smoke extension point (card 07) -----------------------------
# Own-tests + zero-check above establish that a runnable behavioral suite EXISTS and
# is NON-EMPTY. Card 07 hooks in HERE: after that guarantee, build/run the produced
# entrypoint (CLI / handler / server) against a smoke input and assert it boots —
# catching artifacts whose unit suite is green but whose wired entrypoint never runs.
# Intentionally NOT implemented in this card; this is the documented hand-off seam.
# ----------------------------------------------------------------------------

FINAL=""
for e in "${verdicts[@]}"; do
  val="${e#*=}"
  [ "$val" = covered ] && continue
  FINAL="$val"; break
done
if [ -n "$FINAL" ]; then
  log "VERDICT: $FINAL (runners: ${verdicts[*]})"
  exit 2
fi
log "VERDICT: covered (runners: ${verdicts[*]})"
exit 0
