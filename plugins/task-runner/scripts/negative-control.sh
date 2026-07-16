#!/usr/bin/env bash
# negative-control.sh - B3(b) isolated red-before-green control.
#
# Proves a Verify command CAN fail (goes RED by an ASSERTION failure) against a
# targeted disabling of the feature, in an ISOLATED COPY so the live working tree
# is never mutated. A red caused by a build / collection / import error is NOT a
# valid control (the check never reached an assertion) and is rejected.
#
# Usage:
#   negative-control.sh --verify "<cmd>" --target <impl-file> [--mutate <sed-expr> | --auto]
#   negative-control.sh --classify-stdin      # (internal) classify a red blob on stdin
#
# Isolation: the caller's working directory (CWD) is copied to a fresh mktemp -d
# (minus .git); the target's tests come along, only <impl-file> is mutated. Every
# run happens in the copy; the temp is discarded; the live tree is untouched. For
# a test-adding card the new test is already present in the copy - only the impl
# is mutated.
#
# Exit codes:
#   0  discriminating  - assertion-red on the mutated copy, green on the unmutated
#   2  vacuous         - Verify is GREEN in BOTH the mutated and unmutated states
#   3  usage
#   4  invalid-control - the red was a build/collection/import error, not an assert
#   5  isolation / mutation / baseline failure (halt)
set -euo pipefail

PROG=negative-control
log()   { printf '%s: %s\n' "$PROG" "$*" >&2; }
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
halt()  { printf '%s: %s\n' "$PROG" "$1" >&2; exit 5; }

# classify_red: read a run's combined stdout+stderr on stdin; print one of
#   collection | build | assertion | unknown
# Precedence: collection/import first (a collection error can also print a
# SyntaxError line), then build/compile, then assertion. Signatures verified
# against real output of `node --test` and `pytest`; go/jest signatures included.
classify_red() {
  local blob; blob=$(cat)
  # collection / import errors (pytest ERROR collecting, python ImportError,
  # node MODULE_NOT_FOUND / Cannot find module, go missing package)
  if printf '%s\n' "$blob" | grep -Eq \
     'ERROR collecting|errors? during collection|INTERNALERROR|ModuleNotFoundError|ImportError|Cannot find module|ERR_MODULE_NOT_FOUND|MODULE_NOT_FOUND|cannot find package'; then
    printf 'collection\n'; return 0
  fi
  # build / compile / syntax errors
  if printf '%s\n' "$blob" | grep -Eq \
     'SyntaxError|IndentationError|TabError|\[build failed\]|# command-line-arguments|error TS[0-9]'; then
    printf 'build\n'; return 0
  fi
  # assertion failures (the ONLY valid control)
  if printf '%s\n' "$blob" | grep -Eq \
     'AssertionError|ERR_ASSERTION|^E +assert|assert(ion)?[[:space:]]+(failed|error)|--- FAIL:|FAILED .*assert|expect\(|Expected:.*Received:'; then
    printf 'assertion\n'; return 0
  fi
  printf 'unknown\n'; return 0
}

if [ "${1:-}" = "--classify-stdin" ]; then classify_red; exit 0; fi

# ---- arg parse ----
VERIFY=""; TARGET=""; MUTATE=""; HAVE_MUTATE=0; AUTO=0
while [ $# -gt 0 ]; do
  case "$1" in
    --verify) [ $# -ge 2 ] || usage "--verify needs an argument"; VERIFY="$2"; shift 2 ;;
    --target) [ $# -ge 2 ] || usage "--target needs an argument"; TARGET="$2"; shift 2 ;;
    --mutate) [ $# -ge 2 ] || usage "--mutate needs an argument"; MUTATE="$2"; HAVE_MUTATE=1; shift 2 ;;
    --auto)   AUTO=1; shift ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done
[ -n "$VERIFY" ] || usage "need --verify \"<cmd>\""
[ -n "$TARGET" ] || usage "need --target <impl-file>"
if [ "$HAVE_MUTATE" = 1 ] && [ "$AUTO" = 1 ]; then usage "--mutate and --auto are mutually exclusive"; fi
if [ "$HAVE_MUTATE" = 0 ] && [ "$AUTO" = 0 ]; then AUTO=1; fi
[ -f "$TARGET" ] || usage "target file not found (relative to CWD): $TARGET"

SRC=$(pwd -P)

# ---- isolate: copy the working tree (minus .git) into two fresh temp copies ----
TMP=$(mktemp -d 2>/dev/null) || halt "mktemp -d failed"
trap 'rm -rf "$TMP"' EXIT
GREEN="$TMP/green"; RED="$TMP/red"
mkdir -p "$GREEN" "$RED" || halt "mkdir of isolated copies failed"

copy_tree() {
  local s="$1" d="$2"
  ( cd "$s" && tar -cf - --exclude='./.git' . ) 2>/dev/null | ( cd "$d" && tar -xf - ) 2>/dev/null
}
copy_tree "$SRC" "$GREEN" || halt "failed to copy working tree into isolated green copy"
copy_tree "$SRC" "$RED"   || halt "failed to copy working tree into isolated red copy"
{ [ -f "$GREEN/$TARGET" ] && [ -f "$RED/$TARGET" ]; } || halt "target missing in isolated copy: $TARGET"

# ---- mutate the RED copy's impl only ----
if [ "$HAVE_MUTATE" = 1 ]; then
  if ! sed "$MUTATE" "$RED/$TARGET" > "$RED/$TARGET.nc.tmp" 2>/dev/null; then
    rm -f "$RED/$TARGET.nc.tmp"; halt "mutation sed expression failed: $MUTATE"
  fi
  mv "$RED/$TARGET.nc.tmp" "$RED/$TARGET"
else
  # --auto: apply the first feature-disabling edit that actually changes the file
  auto_applied=0
  for expr in \
    's/return true/return false/' \
    's/return false/return true/' \
    's/=== /!== /' \
    's/ == / != /' \
    's/ != / == /' \
    's/return \([0-9][0-9]*\)/return (\1 + 1)/' \
    's/>=/</' \
    's/<=/>/' ; do
    if sed "$expr" "$RED/$TARGET" > "$RED/$TARGET.nc.tmp" 2>/dev/null \
       && ! cmp -s "$RED/$TARGET" "$RED/$TARGET.nc.tmp"; then
      mv "$RED/$TARGET.nc.tmp" "$RED/$TARGET"; auto_applied=1; break
    fi
    rm -f "$RED/$TARGET.nc.tmp"
  done
  [ "$auto_applied" = 1 ] || halt "--auto found no feature-disabling edit for $TARGET; pass --mutate"
fi

# a mutation that changed nothing is not a control
if cmp -s "$GREEN/$TARGET" "$RED/$TARGET"; then
  halt "mutation was a no-op (target unchanged); control cannot run"
fi

# ---- run Verify in each copy ----
RC=0; OUT=""
run_verify() { # $1 dir ; sets globals RC and OUT
  local dir="$1"
  RC=0
  OUT=$( cd "$dir" && bash -c "$VERIFY" 2>&1 ) || RC=$?
}

run_verify "$GREEN"; rc_green=$RC; out_green=$OUT
if [ "$rc_green" -ne 0 ]; then
  log "unmutated baseline is NOT green (rc=$rc_green); the control cannot run"
  log "--- baseline output (tail) ---"
  printf '%s\n' "$out_green" | tail -20 >&2
  exit 5
fi

run_verify "$RED"; rc_red=$RC; out_red=$OUT

# ---- decide ----
if [ "$rc_red" -eq 0 ]; then
  log "vacuous: Verify is GREEN on both the mutated and unmutated copy - it does not detect the disabled feature"
  echo "vacuous"
  exit 2
fi

klass=$(printf '%s' "$out_red" | classify_red)
case "$klass" in
  assertion)
    log "discriminating: mutated copy RED by assertion failure (rc=$rc_red); unmutated copy GREEN"
    echo "discriminating"
    exit 0 ;;
  build|collection)
    log "invalid-control: the mutated red was a $klass error, not an assertion failure - it does not prove the check discriminates on behavior"
    log "--- mutated-run output (tail) ---"
    printf '%s\n' "$out_red" | tail -20 >&2
    echo "invalid-control"
    exit 4 ;;
  *)
    log "invalid-control: the mutated red could not be classified as an assertion failure"
    log "--- mutated-run output (tail) ---"
    printf '%s\n' "$out_red" | tail -20 >&2
    echo "invalid-control"
    exit 4 ;;
esac
