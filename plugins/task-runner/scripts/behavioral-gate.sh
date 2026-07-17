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
#              | entrypoint-error (crash-on-invoke) | dead-affordance (flag is a no-op)
#   3  usage
#
# SAFETY: this gate RUNS code (the artifact's own tests) IN the current working
# directory — a misbehaving suite CAN write into cwd (runner cache dirs, coverage
# files, test-created artifacts). The gate does NOT sandbox those writes; only its
# own capture of runner output goes to a mktemp file OUTSIDE the tree. Tree isolation
# is the CALLER's responsibility: invoke from a disposable checkout / temp fixture.
# The dogfood harness does exactly that and asserts `git status --porcelain` (and a
# fixture-dir checksum) is byte-identical before/after.

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
# --entrypoint <bin> and --differential 'flag::with::without' are BOTH repeatable
# (card 07: shell-entrypoint smoke + differential dead-flag detection).
CHANGED=()
ENTRYPOINTS=()
DIFFERENTIALS=()
add_changed() {
  local raw="$1" tok _o="$IFS"
  set -f; IFS=$' \t\n'
  for tok in $raw; do [ -n "$tok" ] && CHANGED+=("$tok"); done
  IFS="$_o"; set +f
}
while [ $# -gt 0 ]; do
  case "$1" in
    --changed)        shift; [ $# -gt 0 ] || usage "--changed requires a value"; add_changed "$1"; shift ;;
    --changed=*)      add_changed "${1#--changed=}"; shift ;;
    --entrypoint)     shift; [ $# -gt 0 ] || usage "--entrypoint requires a value"; ENTRYPOINTS+=("$1"); shift ;;
    --entrypoint=*)   ENTRYPOINTS+=("${1#--entrypoint=}"); shift ;;
    --differential)   shift; [ $# -gt 0 ] || usage "--differential requires a value"; DIFFERENTIALS+=("$1"); shift ;;
    --differential=*) DIFFERENTIALS+=("${1#--differential=}"); shift ;;
    -h|--help)   printf 'usage: %s --changed <file-or-list> [--changed <more>] [--entrypoint <bin>] [--differential '\''flag::with::without'\'']\n' "$PROG" >&2; exit 3 ;;
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
    md|json|txt|yml|yaml|sh|tmpl) HAS_DOC=1 ;; # .sh + .tmpl (prose templates) treated as doc/non-exec surface
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

# ---- run a runner, capture combined output + exit code ----------------------
# All captures land in one script-scoped temp DIR removed by an EXIT/INT/TERM trap,
# so a signal between mktemp and the read can never leak a temp (mirrors
# negative-control.sh's isolation). run_capture is ALSO called inside the
# `$(verdict_*)` command-substitution subshells below: those inherit WORKTMP but do
# NOT fire the parent's EXIT trap, so the dir survives until the parent cleans it —
# and the trap's `rm -rf` returns 0, so it never clobbers the script's exit code.
CAP=""; RUN_RC=0
WORKTMP=$(mktemp -d) || { log "cannot create temp workspace (mktemp -d failed)"; exit 3; }
trap 'rm -rf "$WORKTMP"' EXIT INT TERM
run_capture() {
  set +e
  run_with_timeout "$TIMEOUT_SECS" "$@" >"$WORKTMP/cap" 2>&1
  RUN_RC=$?
  set -e
  CAP=$(cat "$WORKTMP/cap")
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
  # 'tests N' alone is not trustworthy: some node versions count an empty file or a
  # skip-only suite as 'tests 1'. Cross-check the executed counts (pass+fail+todo)
  # from node's summary — zero executed assertions => empty, whatever 'tests N' says.
  local n_pass n_fail n_todo n_exec
  n_pass=$(printf '%s\n' "$CAP" | grep -oE 'pass[[:space:]]+[0-9]+' | grep -oE '[0-9]+$' | tail -1) || true
  n_fail=$(printf '%s\n' "$CAP" | grep -oE 'fail[[:space:]]+[0-9]+' | grep -oE '[0-9]+$' | tail -1) || true
  n_todo=$(printf '%s\n' "$CAP" | grep -oE 'todo[[:space:]]+[0-9]+' | grep -oE '[0-9]+$' | tail -1) || true
  if [ -n "$n_pass" ] || [ -n "$n_fail" ] || [ -n "$n_todo" ]; then
    n_exec=$(( ${n_pass:-0} + ${n_fail:-0} + ${n_todo:-0} ))
    if [ "$n_exec" -eq 0 ]; then
      log "node --test: pass+fail+todo=0 — suite executed nothing (empty) despite any 'tests N'"
      printf 'empty-suite\n'; return
    fi
    log "node --test: pass+fail+todo=$n_exec (>0) — coverage present"
    printf 'covered\n'; return
  fi
  # Fallback when node emitted no count summary at all: the 'tests N' heuristic.
  if printf '%s\n' "$CAP" | grep -Eq 'tests[[:space:]]+0([^0-9]|$)'; then printf 'empty-suite\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eq 'tests[[:space:]]+[1-9][0-9]*'; then printf 'covered\n'; return; fi
  log "node --test: no parseable 'tests N' summary (exit=$RUN_RC) — cannot confirm (fail-closed)"
  printf 'unverifiable-suite\n'
}

verdict_pkg() {
  local script="$1"
  # --passWithNoTests disables the very empty-suite signal this gate relies on:
  # jest then prints a GREEN "Test Suites: 1 passed" line while running zero tests.
  # A suite whose runner is invoked with it cannot be verified — fail closed.
  case "$script" in
    *--passWithNoTests*)
      log "package.json test: script uses --passWithNoTests — that flag masks empty suites (fail-closed)"
      log "VERDICT: unverifiable-suite"
      printf 'unverifiable-suite\n'; return ;;
  esac
  log "package.json test script: [$script] — running via 'sh -c' (timeout ${TIMEOUT_SECS}s)"
  run_capture sh -c "$script"
  log "package.json test: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "package.json test: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  # The jest "passed count" is anchored to jest's own '^Tests:' summary line, so a
  # "Test Suites: 1 passed" line (printed even for an empty --passWithNoTests run)
  # can NEVER satisfy coverage. Mocha's "N passing" and node/TAP "tests N" remain.
  if printf '%s\n' "$CAP" | grep -Eiq \
      'tests[[:space:]]+[1-9]|[1-9][0-9]*[[:space:]]+passing|^Tests:.*[1-9][0-9]*[[:space:]]+(passed|failed)'; then
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
  # A build/setup failure runs ZERO tests yet prints 'FAIL pkg [build failed]';
  # route it to unverifiable-suite BEFORE the covered check so it never reads green.
  if printf '%s\n' "$CAP" | grep -Eq '\[(build|setup) failed\]'; then
    log "go test: package failed to build/setup — no tests executed (fail-closed)"
    printf 'unverifiable-suite\n'; return
  fi
  # COVERED is checked BEFORE empty: in a multi-package module one package can have
  # passing tests ('ok') while another has none ('[no test files]'). Any real result
  # line proves tests ran, so empty is declared ONLY when no result line exists.
  if printf '%s\n' "$CAP" | grep -Eq '^(ok|PASS|FAIL|---)'; then printf 'covered\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eq 'no test files'; then printf 'empty-suite\n'; return; fi
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

# --- entrypoint smoke + differential dead-flag (card 07) --------------------
# Own-tests + zero-check above establish that a runnable behavioral suite EXISTS
# and is NON-EMPTY. Card 07 hooks in HERE: for each declared shell entrypoint,
#  (a) SMOKE it in a non-destructive form (--help) and assert it boots — a
#      crash-on-invoke is exit 2 entrypoint-error.
#  (b) DIFFERENTIAL: for each --differential 'flag::with::without', run the
#      entrypoint WITH the flag and WITHOUT it and assert the observable output
#      differs AS DECLARED (with-marker only-with, without-marker only-without).
#      A flag whose presence changes nothing is exit 2 dead-affordance. This is a
#      DIFFERENTIAL check, not "assert not error" — a silent no-op flag boots fine.
#  (c) A .md entrypoint is a command/skill prompt doc, NOT a shell binary: it is
#      reported (not-shell-smokable -> routed to B2/review) and NEVER executed,
#      NEVER silently passed, NEVER failed.
# Reuses the card-06 isolation/timeout helpers (run_capture / run_with_timeout).
SHELL_EPS=()
smoke_entrypoints() {
  # nothing to smoke; a --differential with no shell entrypoint to run against is usage
  if [ "${#ENTRYPOINTS[@]}" -eq 0 ]; then
    [ "${#DIFFERENTIALS[@]}" -eq 0 ] || usage "--differential requires a shell --entrypoint to run against"
    return 0
  fi

  local ep
  for ep in "${ENTRYPOINTS[@]}"; do
    case "$ep" in
      *.md)
        # (c) markdown prompt doc — do NOT execute; report + route (not a silent pass)
        log "entrypoint[$ep]: markdown prompt doc, not a shell binary — out of shell smoke"
        printf 'not-shell-smokable: %s -> routed to B2/review\n' "$ep" >&2
        continue
        ;;
    esac
    SHELL_EPS+=("$ep")
    # (a) SMOKE: non-destructive probe under hard timeout; assert it boots (non-error)
    log "entrypoint[$ep]: smoke probe '--help' (timeout ${TIMEOUT_SECS}s)"
    run_capture "$ep" --help
    log "entrypoint[$ep]: smoke exit=$RUN_RC"
    if [ "$RUN_RC" != 0 ]; then
      # A hard crash — killed by signal (>=128), not-executable (126), not-found
      # (127) or timeout (124) — is a genuine entrypoint-error. But a conventional
      # --help/usage handler may print usage and exit with a SMALL non-zero code;
      # that is not a crash. Distinguish by whether usage/help text was printed.
      if [ "$RUN_RC" -eq 124 ] || [ "$RUN_RC" -eq 126 ] || [ "$RUN_RC" -eq 127 ] || [ "$RUN_RC" -ge 128 ]; then
        log "entrypoint[$ep]: hard crash on invoke (exit $RUN_RC: signal/not-exec/not-found/timeout)"
        log "VERDICT: entrypoint-error ($ep)"
        exit 2
      fi
      if printf '%s\n' "$CAP" | grep -Eiq 'usage|help|option|--[a-z]'; then
        log "entrypoint[$ep]: exit $RUN_RC but printed usage/help — conventional usage exit, not a crash"
      else
        log "entrypoint[$ep]: errored on invoke (exit $RUN_RC) with no usage output — treating as crash"
        log "VERDICT: entrypoint-error ($ep)"
        exit 2
      fi
    fi
  done

  [ "${#DIFFERENTIALS[@]}" -gt 0 ] || return 0
  if [ "${#SHELL_EPS[@]}" -eq 0 ]; then
    usage "--differential given but no shell (non-.md) --entrypoint to run against"
  fi

  local spec flag rest with without ep2 out_with out_without ok
  for spec in "${DIFFERENTIALS[@]}"; do
    case "$spec" in
      *"::"*"::"*) : ;;
      *) usage "--differential must be 'flag::observable-with::observable-without' (got: $spec)" ;;
    esac
    flag="${spec%%::*}"; rest="${spec#*::}"; with="${rest%%::*}"; without="${rest#*::}"
    # An empty with/without marker makes 'grep -qF -- ""' match every line, so an
    # unwired flag would spuriously read as observable — reject it as a usage error.
    [ -n "$with" ] && [ -n "$without" ] || usage "--differential with/without markers must be non-empty (got: $spec)"
    for ep2 in "${SHELL_EPS[@]}"; do
      run_capture "$ep2" "$flag"; out_with="$CAP"
      run_capture "$ep2";         out_without="$CAP"
      ok=1
      # with-marker must appear WITH the flag and NOT without it; without-marker vice-versa
      if ! printf '%s\n' "$out_with"    | grep -qF -- "$with";    then ok=0; fi
      if   printf '%s\n' "$out_without" | grep -qF -- "$with";    then ok=0; fi
      if ! printf '%s\n' "$out_without" | grep -qF -- "$without"; then ok=0; fi
      if   printf '%s\n' "$out_with"    | grep -qF -- "$without"; then ok=0; fi
      if [ "$out_with" = "$out_without" ]; then
        log "entrypoint[$ep2]: '$flag' produced IDENTICAL output with/without — no observable effect"
        ok=0
      fi
      if [ "$ok" != 1 ]; then
        log "entrypoint[$ep2]: differential FAILED for '$flag' (declared with='$with' without='$without')"
        log "VERDICT: dead-affordance ($ep2 $flag)"
        exit 2
      fi
      log "entrypoint[$ep2]: differential OK for '$flag' (observable differs as declared)"
    done
  done
}
smoke_entrypoints
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
