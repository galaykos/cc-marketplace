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
# SAFETY: this gate RUNS code (the artifact's own tests) IN the directory it runs in —
# a misbehaving suite CAN write there (runner cache dirs, coverage files, test-created
# artifacts). Three modes decide which directory that is:
#   --isolate   the gate builds the disposable checkout ITSELF: a detached `git worktree`
#               of HEAD under mktemp -d, verified to exist and to be a different
#               toplevel than the live repo BEFORE anything runs (refuses, exit 3,
#               otherwise — it never falls back to running in place), removed by the
#               EXIT trap. It never reads or writes the live .env.
#   --in-place  the caller has already isolated (a temp fixture, a scratch clone); run
#               in cwd. The dogfood harnesses do this and assert `git status --porcelain`
#               (and a fixture-dir checksum) is byte-identical before/after.
#   neither     as --in-place, EXCEPT inside a registered run's live tree
#               (.claude/task-runner/active-run.json at the toplevel), where it refuses.
# WHY --isolate exists (2026-09-24): the header used to say "tree isolation is the
# CALLER's responsibility", so every run improvised worktree + symlink + env steps. One
# such hand-built `git worktree add` was rejected with the rest of its Bash call, the
# next call's `cd /tmp/<dir>; cp .env.example .env && php artisan key:generate` ran in
# the live repo after the cd failed, and a developer's .env and APP_KEY were destroyed.
# RESIDUAL --isolate does not close: vendor/ and node_modules/ are SYMLINKED from the
# live tree (a fresh install per gate run is minutes), so a suite that writes into its
# dependency dirs writes live; and the worktree is HEAD, so uncommitted changes to
# tracked files are not what gets tested (warned, not refused — the record is keyed by
# HEAD anyway).

set -euo pipefail

PROG=behavioral-gate
BG_RECORD_DIR=
log()   { printf '%s: %s\n' "$PROG" "$*" >&2; }
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

# MACHINE EVIDENCE. gate-pass.json is written by the MODEL, so on its own it records a
# claim, not a run: a run can write {"head":...} having never invoked this script. This
# writes what THIS script actually concluded, for the HEAD it concluded it at, and
# candor's Stop gate (clause 4) cross-checks the claim against it.
#
# Armed by the directory existing (created at run registration), so a plain non-run
# invocation writes nothing. Called on EVERY exit path, including the honest
# no-executable-surface pass: a legitimate run that produced no runnable surface would
# otherwise leave no record, and the completion gate would block it forever for a pass
# it actually earned. Failure to write is never fatal — verdict and exit code are
# unchanged either way, so this can only ever add evidence, never withhold a result.
bg_record() { # bg_record <verdict-label> [runners]
  # --record-dir names the LIVE repo's bg dir. run.md runs this gate from a disposable
  # checkout so it cannot mutate the tree it is judging, which means $(pwd) here is the
  # temp copy: without the flag the record landed in a directory about to be deleted and
  # the completion gate then blocked an honest run for a pass it had actually earned.
  bg_dir="${BG_RECORD_DIR:-$(pwd)/.claude/task-runner/bg}"
  [ -d "$bg_dir" ] && [ -w "$bg_dir" ] || return 0
  command -v git >/dev/null 2>&1 || return 0
  bg_head=$(git rev-parse HEAD 2>/dev/null) || return 0
  printf '{"head":"%s","verdict":"%s","runners":"%s"}\n' \
    "$bg_head" "$1" "${2:-}" > "$bg_dir/bg-$bg_head.json" 2>/dev/null || true
  return 0
}

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
CUSTOM_RUNNERS=()
ISOLATE=0; IN_PLACE=0
add_changed() {
  local raw="$1" tok _o="$IFS"
  set -f; IFS=$' \t\n'
  for tok in $raw; do [ -n "$tok" ] && CHANGED+=("$tok"); done
  IFS="$_o"; set +f
}
while [ $# -gt 0 ]; do
  case "$1" in
    --record-dir)     shift; [ $# -gt 0 ] || usage "--record-dir requires a value"; BG_RECORD_DIR="$1"; shift ;;
    --changed)        shift; [ $# -gt 0 ] || usage "--changed requires a value"; add_changed "$1"; shift ;;
    --changed=*)      add_changed "${1#--changed=}"; shift ;;
    --entrypoint)     shift; [ $# -gt 0 ] || usage "--entrypoint requires a value"; ENTRYPOINTS+=("$1"); shift ;;
    --entrypoint=*)   ENTRYPOINTS+=("${1#--entrypoint=}"); shift ;;
    --differential)   shift; [ $# -gt 0 ] || usage "--differential requires a value"; DIFFERENTIALS+=("$1"); shift ;;
    --differential=*) DIFFERENTIALS+=("${1#--differential=}"); shift ;;
    --runner)         shift; [ $# -gt 0 ] || usage "--runner requires a value"; CUSTOM_RUNNERS+=("$1"); shift ;;
    --runner=*)       CUSTOM_RUNNERS+=("${1#--runner=}"); shift ;;
    --isolate)        ISOLATE=1; shift ;;
    --in-place)       IN_PLACE=1; shift ;;
    -h|--help)   printf 'usage: %s (--isolate | --in-place) --changed <file-or-list> [--changed <more>] [--entrypoint <bin>] [--differential '\''flag::with::without'\''] [--runner '\''<cmd>::<empty-regex>'\''] [--record-dir <live-repo>/.claude/task-runner/bg]\n' "$PROG" >&2; exit 3 ;;
    --*)         usage "unknown flag: $1" ;;
    *)           add_changed "$1"; shift ;;
  esac
done
[ "${#CHANGED[@]}" -gt 0 ] || usage "no --changed files given (want --changed <file-or-list>)"
[ "$ISOLATE" = 1 ] && [ "$IN_PLACE" = 1 ] && usage "--isolate and --in-place are mutually exclusive"

# ---- ISOLATION (see the SAFETY header) ---------------------------------------
# Every step that can fail refuses with exit 3 and runs NOTHING: the failure this
# exists for was a setup step that failed silently while the steps after it ran in the
# live repo. Cleanup is one function so the WORKTMP trap below can call it too — a
# second `trap … EXIT` would replace this one.
ISO_LIVE=""; ISO_DIR=""; ISO_TREE=""
iso_cleanup() {
  [ -n "$ISO_DIR" ] || return 0
  if [ -n "$ISO_TREE" ] && [ -n "$ISO_LIVE" ]; then
    git -C "$ISO_LIVE" worktree remove --force "$ISO_TREE" >/dev/null 2>&1 || true
  fi
  rm -rf "$ISO_DIR" 2>/dev/null || true
  [ -n "$ISO_LIVE" ] && git -C "$ISO_LIVE" worktree prune >/dev/null 2>&1
  return 0
}
iso_refuse() { log "--isolate: $1 — refusing; nothing was run"; exit 3; }

live_top=""
command -v git >/dev/null 2>&1 && live_top=$(git rev-parse --show-toplevel 2>/dev/null || true)

if [ "$ISOLATE" = 1 ]; then
  [ -n "$live_top" ] || iso_refuse "$(pwd) is not inside a git work tree, so there is no HEAD to check out"
  ISO_LIVE=$(cd "$live_top" && pwd -P) || iso_refuse "cannot resolve the live toplevel $live_top"
  trap 'iso_cleanup' EXIT INT TERM
  ISO_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bg-isolate.XXXXXX" 2>/dev/null) || iso_refuse "mktemp -d failed"
  ISO_DIR=$(cd "$ISO_DIR" && pwd -P) || iso_refuse "cannot resolve the temp dir"
  git -C "$ISO_LIVE" worktree add --detach -q "$ISO_DIR/tree" HEAD >/dev/null 2>&1 \
    || iso_refuse "git worktree add $ISO_DIR/tree HEAD failed"
  ISO_TREE="$ISO_DIR/tree"
  # Verified, not assumed: the directory exists AND git inside it names IT as the
  # toplevel. A tree that resolves to the live repo is the incident, so it refuses.
  [ -d "$ISO_TREE" ] || iso_refuse "$ISO_TREE does not exist after worktree add"
  iso_top=$(git -C "$ISO_TREE" rev-parse --show-toplevel 2>/dev/null) || iso_refuse "$ISO_TREE is not a git work tree"
  iso_top=$(cd "$iso_top" && pwd -P) || iso_refuse "cannot resolve $iso_top"
  [ "$iso_top" = "$ISO_TREE" ] || iso_refuse "$ISO_TREE resolves to toplevel $iso_top, not itself"
  [ "$iso_top" != "$ISO_LIVE" ] || iso_refuse "the isolated tree resolves to the live repo $ISO_LIVE"

  if [ -n "$(git -C "$ISO_LIVE" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    log "WARN: the live tree has uncommitted changes to tracked files; --isolate tests HEAD $(git -C "$ISO_LIVE" rev-parse --short HEAD 2>/dev/null), so those changes are NOT tested — commit them first"
  fi
  # Dependency dirs are symlinked, not installed: the residual named in the header.
  for dep in vendor node_modules; do
    if [ -d "$ISO_LIVE/$dep" ] && [ ! -e "$ISO_TREE/$dep" ]; then
      ln -s "$ISO_LIVE/$dep" "$ISO_TREE/$dep" || iso_refuse "cannot link $dep into $ISO_TREE"
    fi
  done
  # Environment: built from the tree's OWN committed example, by absolute path into the
  # verified tree. The live .env is never read — it holds the developer's credentials.
  if [ -f "$ISO_TREE/.env.example" ] && [ ! -e "$ISO_TREE/.env" ]; then
    cp "$ISO_TREE/.env.example" "$ISO_TREE/.env" || iso_refuse "cannot write $ISO_TREE/.env"
  fi
  # Laravel: tests take their env from phpunit.xml, but the app still boots with
  # APP_KEY. Exported for this process only — `artisan key:generate` writes a .env
  # file, which is the command that destroyed a live key.
  if [ -f "$ISO_TREE/artisan" ] && [ -z "${APP_KEY:-}" ]; then
    APP_KEY="base64:$(head -c 32 /dev/urandom | base64 | tr -d '\n')"; export APP_KEY
  fi
  # The record belongs to the live repo, not the tree about to be deleted.
  : "${BG_RECORD_DIR:=$ISO_LIVE/.claude/task-runner/bg}"
  # Keep the caller's position: `--changed` paths are relative to it.
  iso_rel=$(pwd -P); iso_rel=${iso_rel#"$ISO_LIVE"}
  if [ -d "$ISO_TREE$iso_rel" ]; then cd "$ISO_TREE$iso_rel"; else cd "$ISO_TREE"; fi
  log "isolate: running in $(pwd) (worktree of HEAD $(git rev-parse --short HEAD 2>/dev/null)); removed on exit"
elif [ "$IN_PLACE" = 0 ] && [ -n "$live_top" ] && [ -e "$live_top/.claude/task-runner/active-run.json" ]; then
  log "refusing to run in $live_top: it is a registered task-runner run's LIVE tree, and a suite run here can mutate it"
  log "re-run with --isolate (the gate builds and removes its own worktree), or --in-place if cwd is already a disposable copy"
  exit 3
fi

# ---- (a) CLASSIFY: touched files -> language flags --------------------------
# php/rs/rb/java+kt were added 2026-09-22 (SW 1 of the specialist panel). Before that
# the classifier knew py/js/go and nothing else, so a PHP, Rust, Java or Ruby run fell
# to HAS_OPAQUE=1 -> no-behavioral-coverage -> exit 2 with no flag to escape it, and
# candor's Stop gate then refused every close: a gate that could not be passed rather
# than a rule that could be followed. Measured on four fixtures with green suites:
# EXIT=2 all four.
HAS_PY=0; HAS_JS=0; HAS_GO=0; HAS_PHP=0; HAS_RS=0; HAS_RB=0; HAS_JAVA=0; HAS_DOC=0; HAS_OPAQUE=0
for f in "${CHANGED[@]}"; do
  base="${f##*/}"; ext="${base##*.}"; [ "$ext" = "$base" ] && ext=""
  case "$ext" in
    py)                        HAS_PY=1 ;;
    js|mjs|cjs|jsx|ts|tsx)     HAS_JS=1 ;;
    go)                        HAS_GO=1 ;;
    php)                       HAS_PHP=1 ;;
    rs)                        HAS_RS=1 ;;
    rb)                        HAS_RB=1 ;;
    java|kt)                   HAS_JAVA=1 ;;
    md|json|txt|yml|yaml|sh|tmpl) HAS_DOC=1 ;; # .sh + .tmpl (prose templates) treated as doc/non-exec surface
    *)                         HAS_OPAQUE=1 ;;
  esac
done
log "classify: py=$HAS_PY js=$HAS_JS go=$HAS_GO php=$HAS_PHP rs=$HAS_RS rb=$HAS_RB java=$HAS_JAVA doc=$HAS_DOC opaque=$HAS_OPAQUE (files=${#CHANGED[@]})"

runners=()
[ "$HAS_PY" = 1 ] && runners+=("py")
[ "$HAS_JS" = 1 ] && runners+=("js")
[ "$HAS_GO" = 1 ] && runners+=("go")
[ "$HAS_PHP" = 1 ] && runners+=("php")
[ "$HAS_RS" = 1 ] && runners+=("rs")
[ "$HAS_RB" = 1 ] && runners+=("rb")
[ "$HAS_JAVA" = 1 ] && runners+=("java")
# --runner is the escape for the FIFTH language — anything the classifier still calls
# opaque. Declaring one satisfies the opaque surface: the caller has named a command
# and the output that means "it ran nothing", which is the only thing the classifier
# was ever supplying.
ci=0
for _cr in ${CUSTOM_RUNNERS[@]+"${CUSTOM_RUNNERS[@]}"}; do
  case "$_cr" in *"::"*) : ;; *) usage "--runner must be '<cmd>::<empty-output-regex>' (got: $_cr)" ;; esac
  [ -n "${_cr%%::*}" ] || usage "--runner command must be non-empty (got: $_cr)"
  [ -n "${_cr#*::}" ]  || usage "--runner empty-output regex must be non-empty (got: $_cr)"
  ci=$((ci + 1)); runners+=("custom$ci")
done

if [ "${#runners[@]}" -eq 0 ]; then
  if [ "$HAS_OPAQUE" = 1 ]; then
    log "needs behavioral coverage but NO test runner resolves for the touched types"
    log "declare one with --runner '<cmd>::<empty-output-regex>' if this stack has a suite"
    log "VERDICT: no-behavioral-coverage"
    bg_record no-behavioral-coverage
    exit 2
  fi
  log "only non-executable/doc types touched (.md/.json/.txt/.yml/.yaml/.sh); no runner resolvable"
  log "VERDICT: no-executable-surface (honest lint-only; nothing to run)"
  bg_record no-executable-surface
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
php_has_tests() {
  find . -type d -name vendor -prune -o -type f \
    \( -name '*Test.php' -o -name '*_test.php' -o -path './tests/*.php' \) -print 2>/dev/null | grep -q .
}
# Rust tests are USUALLY inline `#[test]` fns in the same file, not a separate naming
# convention, so the static zero-check greps for the attribute as well as tests/. The
# pattern is deliberately loose (anywhere on the line, any `#[<path>test…]` attribute:
# `#[test]`, `#[tokio::test]`, `#[rstest]`, `#[test_case(..)]`) and deliberately not
# `#[cfg(test)]`, which is a module gate and not a test. Over-matching — a commented-out
# attribute — costs nothing: cargo then runs and the empty-suite branch renders the
# verdict. UNDER-matching is the expensive direction, because it reports
# no-behavioral-coverage for a crate that does have tests.
rs_has_tests() {
  { find . -type d -name target -prune -o -type f -path './tests/*.rs' -print 2>/dev/null | grep -q .; } && return 0
  grep -rl --include='*.rs' --exclude-dir=target -E '#\[[a-z_:]*test' . 2>/dev/null | grep -q .
}
rb_has_tests() { find . -type f \( -name '*_spec.rb' -o -name '*_test.rb' \) 2>/dev/null | grep -q .; }
java_has_tests() {
  find . -type d \( -name build -o -name target -o -name .gradle \) -prune -o -type f \
    \( -name '*Test.java'  -o -name '*Tests.java'  -o -name '*TestCase.java' \
    -o -name '*Test.kt'    -o -name '*Tests.kt'    -o -name '*Spec.kt' \) -print 2>/dev/null | grep -q .
}

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
trap 'rm -rf "$WORKTMP"; iso_cleanup' EXIT INT TERM
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

# ---- php / rs / rb / java (SW 1, 2026-09-22) --------------------------------
# Each follows the SAME three-step shape as py/js/go above and must: (1) declare
# no-behavioral-coverage when no own-test exists statically, (2) declare
# unverifiable-suite when the runner binary is absent — never a silent pass, and
# (3) check its EMPTY signal BEFORE its covered signal wherever the empty output is
# unambiguous, and AFTER it wherever a multi-target runner can print both (rs, like go).
# Unparseable output is unverifiable-suite. The table in
# skills/behavioral-gate/references/runners.md mirrors these; this script is the
# source of truth.

verdict_php() {
  if ! php_has_tests; then
    log "php: no *Test.php / *_test.php / tests/*.php present — no runnable own-test"; printf 'no-behavioral-coverage\n'; return
  fi
  local bin=""
  if   [ -x ./vendor/bin/pest ];     then bin=./vendor/bin/pest
  elif [ -x ./vendor/bin/phpunit ];  then bin=./vendor/bin/phpunit
  elif command -v pest    >/dev/null 2>&1; then bin=pest
  elif command -v phpunit >/dev/null 2>&1; then bin=phpunit
  fi
  if [ -z "$bin" ]; then
    log "php: tests present but neither vendor/bin/pest nor vendor/bin/phpunit is executable (fail-closed)"; printf 'unverifiable-suite\n'; return
  fi
  log "php: running '$bin' (timeout ${TIMEOUT_SECS}s)"
  run_capture "$bin"
  log "php: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "php: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  # PHPUnit's empty signal is "No tests executed!"; Pest's is "No tests found".
  if printf '%s\n' "$CAP" | grep -Eq 'No tests executed|No tests found'; then printf 'empty-suite\n'; return; fi
  # PHPUnit green: "OK (5 tests, 9 assertions)". PHPUnit red and Pest both print a
  # "Tests:" summary line carrying a non-zero count.
  if printf '%s\n' "$CAP" | grep -Eq 'OK \([1-9][0-9]* test|Tests:[[:space:]]+[1-9]|FAILURES!|ERRORS!'; then printf 'covered\n'; return; fi
  log "php: no parseable test count in output — refusing to assume coverage (fail-closed)"
  printf 'unverifiable-suite\n'
}

verdict_rs() {
  if ! rs_has_tests; then
    log "cargo test: no tests/*.rs and no #[test] attribute present — no runnable own-test"; printf 'no-behavioral-coverage\n'; return
  fi
  if ! command -v cargo >/dev/null 2>&1; then
    log "cargo test: tests present but 'cargo' not installed (fail-closed)"; printf 'unverifiable-suite\n'; return
  fi
  log "cargo test: running 'cargo test' (timeout ${TIMEOUT_SECS}s)"
  run_capture cargo test
  log "cargo test: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "cargo test: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  # A compile error runs ZERO tests while printing a non-zero exit; route it to
  # unverifiable BEFORE anything else so it never reads green (same trap as go's
  # '[build failed]').
  if printf '%s\n' "$CAP" | grep -Eq 'error\[E[0-9]+\]|error: could not compile|^error: aborting'; then
    log "cargo test: crate failed to compile — no tests executed (fail-closed)"
    printf 'unverifiable-suite\n'; return
  fi
  # COVERED before EMPTY, as with go: a crate has one 'test result:' line per target
  # (lib, each bin, each integration test, doc-tests), so a 0-passed line sits beside
  # a real one routinely. Empty is declared only when NO target passed anything.
  if printf '%s\n' "$CAP" | grep -Eq 'test result:.*[1-9][0-9]* passed'; then printf 'covered\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eq 'test result:.*\b0 passed'; then printf 'empty-suite\n'; return; fi
  log "cargo test: no parseable 'test result:' line — fail-closed"; printf 'unverifiable-suite\n'
}

verdict_rb() {
  if ! rb_has_tests; then
    log "rspec: no *_spec.rb / *_test.rb present — no runnable own-test"; printf 'no-behavioral-coverage\n'; return
  fi
  local -a cmd=()
  if   [ -f Gemfile ] && command -v bundle >/dev/null 2>&1; then cmd=(bundle exec rspec)
  elif command -v rspec >/dev/null 2>&1;                    then cmd=(rspec)
  fi
  if [ "${#cmd[@]}" -eq 0 ]; then
    log "rspec: specs present but neither 'bundle exec rspec' nor 'rspec' is available (fail-closed)"; printf 'unverifiable-suite\n'; return
  fi
  log "rspec: running '${cmd[*]}' (timeout ${TIMEOUT_SECS}s)"
  run_capture "${cmd[@]}"
  log "rspec: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "rspec: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  # "0 examples, 0 failures" is the empty signal and it is unambiguous — rspec prints
  # exactly one summary line per run — so it is checked first.
  if printf '%s\n' "$CAP" | grep -Eq '(^|[^0-9])0 examples'; then printf 'empty-suite\n'; return; fi
  if printf '%s\n' "$CAP" | grep -Eq '[1-9][0-9]* examples?'; then printf 'covered\n'; return; fi
  log "rspec: no parseable 'N examples' summary — fail-closed"; printf 'unverifiable-suite\n'
}

verdict_java() {
  if ! java_has_tests; then
    log "java/kotlin: no *Test(s).java / *Test(s).kt / *Spec.kt present — no runnable own-test"; printf 'no-behavioral-coverage\n'; return
  fi
  # --rerun-tasks on the Gradle path, measured 2026-09-22: a plain `gradle test` on an
  # already-built tree prints `> Task :test UP-TO-DATE` and executes NOTHING, and the
  # gate is run from a copied checkout that carries build/ — so the second invocation of
  # an honest green suite failed. Forcing the task is what makes the Java arm passable
  # at all. Cost: the compile is redone (0.6s on the probe fixture; minutes on a large
  # module, which is what BEHAVIORAL_GATE_TIMEOUT is for). Maven's surefire always runs.
  # BOTH wrappers before EITHER system binary. A project that ships ./mvnw is a Maven
  # project, and a `gradle` that happens to be on the developer's PATH has no business
  # building it — checking the system binary first ran the wrong build system whenever
  # both were present.
  local -a cmd=()
  if   [ -x ./gradlew ];                    then cmd=(./gradlew test --rerun-tasks)
  elif [ -x ./mvnw ];                       then cmd=(./mvnw test)
  elif command -v gradle >/dev/null 2>&1;   then cmd=(gradle test --rerun-tasks)
  elif command -v mvn >/dev/null 2>&1;      then cmd=(mvn test)
  fi
  if [ "${#cmd[@]}" -eq 0 ]; then
    log "java/kotlin: tests present but no gradlew/gradle/mvnw/mvn available (fail-closed)"; printf 'unverifiable-suite\n'; return
  fi
  log "java/kotlin: running '${cmd[*]}' (timeout ${TIMEOUT_SECS}s)"
  run_capture "${cmd[@]}"
  log "java/kotlin: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "java/kotlin: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  # Surefire's empty signal is "Tests run: 0"; Gradle's is a test task that found no
  # source. A task reported UP-TO-DATE executed nothing THIS invocation, which is not
  # a pass either — name --rerun-tasks rather than guess.
  if printf '%s\n' "$CAP" | grep -Eq 'Tests run: 0|Task :[a-zA-Z:]*test NO-SOURCE|No tests found|There are no tests to run|did not discover any tests'; then
    printf 'empty-suite\n'; return
  fi
  # Defensive: --rerun-tasks above should make this unreachable on the Gradle path, but a
  # wrapper or init script can still skip the task, and a skipped task is not a pass.
  if printf '%s\n' "$CAP" | grep -Eq 'Task :[a-zA-Z:]*test UP-TO-DATE'; then
    log "java/kotlin: the test task was UP-TO-DATE — nothing executed this invocation (fail-closed)"
    printf 'unverifiable-suite\n'; return
  fi
  if printf '%s\n' "$CAP" | grep -Eq 'Tests run: [1-9]|[1-9][0-9]* tests? completed'; then printf 'covered\n'; return; fi
  # GRADLE'S WEAK SIGNAL, stated rather than hidden. `gradle test` prints no counts at
  # all on a green run — only "BUILD SUCCESSFUL" (verified against Gradle 9.7.1,
  # 2026-09-22) — so for that one path the gate falls back to "test sources exist
  # (checked above) and the test task did not fail". That is weaker than every other row
  # in this file. Two ways past it, both named in runners.md: a suite whose tests are all
  # filtered out by a --tests selector, and a build that sets failOnNoDiscoveredTests to
  # false (on Gradle 9 the default TRUE turns a zero-discovery run into the build failure
  # matched as empty-suite above — that default is doing the empty-detection here).
  if printf '%s\n' "$CAP" | grep -Eq 'BUILD SUCCESSFUL'; then
    log "java/kotlin: gradle printed no test counts; falling back to test-sources-exist + BUILD SUCCESSFUL (weak signal — see runners.md)"
    printf 'covered\n'; return
  fi
  log "java/kotlin: no parseable test count in output — refusing to assume coverage (fail-closed)"
  printf 'unverifiable-suite\n'
}

# --runner '<cmd>::<empty-output-regex>'. The CALLER owns the empty signal here, which
# is the whole point and also the whole residual: a regex that never matches turns an
# empty suite into a green one, and nothing in this script can tell. What the gate
# still owns is the pair of failures a declaration cannot paper over — a command that
# never started (126/127/signal) and one that hung (124).
verdict_custom() {
  local spec="$1" cmd="${1%%::*}" empty="${1#*::}"
  log "custom runner: running 'sh -c \"$cmd\"' (timeout ${TIMEOUT_SECS}s)"
  run_capture sh -c "$cmd"
  log "custom runner: exit=$RUN_RC"
  if [ "$RUN_RC" = 124 ]; then log "custom runner: TIMED OUT"; printf 'unverifiable-suite\n'; return; fi
  if [ "$RUN_RC" -eq 126 ] || [ "$RUN_RC" -eq 127 ] || [ "$RUN_RC" -ge 128 ]; then
    log "custom runner: did not start (exit $RUN_RC: not-executable/not-found/signal) — fail-closed"
    printf 'unverifiable-suite\n'; return
  fi
  if printf '%s\n' "$CAP" | grep -Eq -- "$empty"; then
    log "custom runner: output matched the declared empty signal /$empty/"
    printf 'empty-suite\n'; return
  fi
  printf 'covered\n'
}

verdicts=()
ci=0
for r in "${runners[@]}"; do
  case "$r" in
    py) v=$(verdict_py) ;;
    js) v=$(verdict_js) ;;
    go) v=$(verdict_go) ;;
    php) v=$(verdict_php) ;;
    rs) v=$(verdict_rs) ;;
    rb) v=$(verdict_rb) ;;
    java) v=$(verdict_java) ;;
    custom*) ci=$((ci + 1)); v=$(verdict_custom "${CUSTOM_RUNNERS[$((ci - 1))]}") ;;
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
        bg_record entrypoint-error
        exit 2
      fi
      if printf '%s\n' "$CAP" | grep -Eiq 'usage|help|option|--[a-z]'; then
        log "entrypoint[$ep]: exit $RUN_RC but printed usage/help — conventional usage exit, not a crash"
      else
        log "entrypoint[$ep]: errored on invoke (exit $RUN_RC) with no usage output — treating as crash"
        log "VERDICT: entrypoint-error ($ep)"
        bg_record entrypoint-error
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
        bg_record dead-affordance
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
  bg_record "$FINAL" "${verdicts[*]:-}"
  log "VERDICT: $FINAL (runners: ${verdicts[*]})"
  exit 2
fi
bg_record covered "${verdicts[*]:-}"
log "VERDICT: covered (runners: ${verdicts[*]})"
exit 0
