#!/usr/bin/env bash
# negative-control.sh — proves a Verify command CAN fail: in two copies of ROOT (default cwd, minus .git) it mutates only <impl-file> and passes when the mutated run is RED by a non-build/collection failure and the unmutated run green. The live tree is never touched.
# Misses: whether the mutation disabled the feature under test (--auto takes the first of eight fixed edits that changes the file); a red of unknown signature counts as discriminating; a flaky Verify can read either way.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/negative-control.sh (marketplace repository)

# Usage:
#   negative-control.sh --verify "<cmd>" --target <impl-file> [--root <dir>] [--mutate <sed-expr> | --auto]
#                       [--record-dir <dir> --card <id>]   # write nc-pass-<id>.json on exit 0
#   negative-control.sh --skip "<reason>" --record-dir <dir> --card <id>   # record a documented non-run
#   negative-control.sh --classify-stdin      # (internal) classify a red blob on stdin
#
# Isolation: the copy ROOT (CWD by default, or --root <dir> to narrow the copied
# subtree — cheaper when CWD carries a heavy node_modules/.venv the target doesn't
# need) is copied to a fresh mktemp -d (minus .git); the target's tests come along,
# only <impl-file> (resolved UNDER the root, and where the Verify command runs) is
# mutated. Every run happens in the copy; the temp is discarded; the live tree is
# untouched. For a test-adding card the new test is already present in the copy -
# only the impl is mutated.
#
# Exit codes:
#   0  discriminating  - a non-build/collection RED on the mutated copy, green on
#                        the unmutated copy (assertion, TAP not-ok, diff, ...)
#   2  vacuous         - Verify is GREEN in BOTH the mutated and unmutated states
#   3  usage
#   4  invalid-control - the red was POSITIVELY a build/collection/import error,
#                        not a behavioral failure
#   5  isolation / mutation / baseline failure (halt)
set -euo pipefail

PROG=negative-control
log()   { printf '%s: %s\n' "$PROG" "$*" >&2; }
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
halt()  { printf '%s: %s\n' "$PROG" "$1" >&2; exit 5; }

# classify_red: a run's combined output on stdin -> collection | build | assertion | unknown, assertion markers first, so a test asserting on the string "SyntaxError" stays an assertion.
classify_red() {
  local blob; blob=$(cat)
  # Never printed by a build/collection error. `not ok ` is not one: TAP prints it for any failing subtest, a load failure included.
  if printf '%s\n' "$blob" | grep -Eq \
     'AssertionError|ERR_ASSERTION|--- FAIL:|^E +assert|assert(ion)?[[:space:]]+(failed|error)|FAILED .*assert|expect\(|Expected:.*Received:'; then
    printf 'assertion\n'; return 0
  fi
  if printf '%s\n' "$blob" | grep -Eq \
     'ERROR collecting|errors? during collection|INTERNALERROR|ModuleNotFoundError|ImportError|Cannot find module|ERR_MODULE_NOT_FOUND|MODULE_NOT_FOUND|cannot find package'; then
    printf 'collection\n'; return 0
  fi
  if printf '%s\n' "$blob" | grep -Eq \
     'SyntaxError|IndentationError|TabError|\[build failed\]|# command-line-arguments|error TS[0-9]'; then
    printf 'build\n'; return 0
  fi
  # Only once build/collection are ruled out: node --test prints ✖ for build failures too, and `not ok 1 - <file>` under its TAP reporter.
  if printf '%s\n' "$blob" | grep -Eq '✖|✗|not ok '; then
    printf 'assertion\n'; return 0
  fi
  printf 'unknown\n'; return 0
}

if [ "${1:-}" = "--classify-stdin" ]; then classify_red; exit 0; fi

VERIFY=""; TARGET=""; MUTATE=""; HAVE_MUTATE=0; AUTO=0; ROOT="."
RECORD_DIR=""; CARD=""; SKIP_REASON=""; HAVE_SKIP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --verify) [ $# -ge 2 ] || usage "--verify needs an argument"; VERIFY="$2"; shift 2 ;;
    --target) [ $# -ge 2 ] || usage "--target needs an argument"; TARGET="$2"; shift 2 ;;
    --root)   [ $# -ge 2 ] || usage "--root needs an argument"; ROOT="$2"; shift 2 ;;
    --mutate) [ $# -ge 2 ] || usage "--mutate needs an argument"; MUTATE="$2"; HAVE_MUTATE=1; shift 2 ;;
    --auto)   AUTO=1; shift ;;
    --record-dir) [ $# -ge 2 ] || usage "--record-dir needs an argument"; RECORD_DIR="$2"; shift 2 ;;
    --card)   [ $# -ge 2 ] || usage "--card needs an argument"; CARD="$2"; shift 2 ;;
    --skip)   [ $# -ge 2 ] || usage "--skip needs a reason argument"; SKIP_REASON="$2"; HAVE_SKIP=1; shift 2 ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done

# --record-dir + --card: a pass writes nc-pass-<card>.json, authored by this tool; --skip writes nc-skip-<card>.json, its reason model-authored. Card ids are path-safe only.
if [ -n "$CARD" ]; then
  case "$CARD" in *[!a-zA-Z0-9._-]*) usage "--card carries path characters: $CARD" ;; esac
fi
record_write() { # $1 = pass|skip, $2 = json body
  [ -n "$RECORD_DIR" ] && [ -n "$CARD" ] || return 0
  mkdir -p "$RECORD_DIR" 2>/dev/null || { printf '%s: warn: cannot create --record-dir %s\n' "$PROG" "$RECORD_DIR" >&2; return 0; }
  printf '%s\n' "$2" > "$RECORD_DIR/nc-$1-$CARD.json" 2>/dev/null \
    || printf '%s: warn: could not write nc-%s record for card %s\n' "$PROG" "$1" "$CARD" >&2
}
if [ "$HAVE_SKIP" = 1 ]; then
  [ -n "$RECORD_DIR" ] && [ -n "$CARD" ] || usage "--skip needs --record-dir and --card"
  esc_reason=$(printf '%s' "$SKIP_REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')
  record_write skip "{\"card\":\"$CARD\",\"skipped\":true,\"reason\":\"$esc_reason\"}"
  echo "skip-recorded"
  exit 0
fi

[ -n "$VERIFY" ] || usage "need --verify \"<cmd>\""
[ -n "$TARGET" ] || usage "need --target <impl-file>"
if [ "$HAVE_MUTATE" = 1 ] && [ "$AUTO" = 1 ]; then usage "--mutate and --auto are mutually exclusive"; fi
if [ "$HAVE_MUTATE" = 0 ] && [ "$AUTO" = 0 ]; then AUTO=1; fi
[ -d "$ROOT" ] || usage "--root dir not found: $ROOT"

SRC=$(cd "$ROOT" && pwd -P) || halt "cannot resolve --root: $ROOT"
[ -f "$SRC/$TARGET" ] || usage "target file not found under root ($ROOT): $TARGET"

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

if [ "$rc_red" -eq 0 ]; then
  log "vacuous: Verify is GREEN on both the mutated and unmutated copy - it does not detect the disabled feature"
  echo "vacuous"
  exit 2
fi

klass=$(printf '%s' "$out_red" | classify_red)
case "$klass" in
  build|collection)
    log "invalid-control: the mutated red was a $klass error, not a behavioral failure - it does not prove the check discriminates on behavior"
    log "--- mutated-run output (tail) ---"
    printf '%s\n' "$out_red" | tail -20 >&2
    echo "invalid-control"
    exit 4 ;;
  assertion)
    log "discriminating: mutated copy RED by assertion failure (rc=$rc_red); unmutated copy GREEN"
    esc_v=$(printf '%s' "$VERIFY" | sed 's/\\/\\\\/g; s/"/\\"/g')
    record_write pass "{\"card\":\"$CARD\",\"target\":\"$TARGET\",\"verify\":\"$esc_v\"}"
    echo "discriminating"
    exit 0 ;;
  *)
    # Outside the allowlist (TAP `not ok`, a plain `exit 1` with a diff, a bespoke assert) yet not build/collection: the Verify did discriminate.
    log "discriminating: mutated copy RED (rc=$rc_red) by a non-build/collection failure; unmutated copy GREEN"
    esc_v=$(printf '%s' "$VERIFY" | sed 's/\\/\\\\/g; s/"/\\"/g')
    record_write pass "{\"card\":\"$CARD\",\"target\":\"$TARGET\",\"verify\":\"$esc_v\"}"
    echo "discriminating"
    exit 0 ;;
esac
