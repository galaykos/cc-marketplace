#!/usr/bin/env bash
# Behavioural harness for templates/blocks/option-resolver.md (cc_option): every
# precedence layer — environment, level file, userConfig option, default — plus the
# pc_shared_blocks arm that keeps pasted copies of the block byte-identical.
# Each arm runs in a subshell with the switch and its CLAUDE_PLUGIN_OPTION_ twin unset
# first, so a CC_TERSE set in the caller's own shell cannot leak into a verdict.
set -u
cd "$(dirname "$0")/../.." || exit 2   # repo root
. templates/blocks/option-resolver.md || { echo "FAIL: cannot source templates/blocks/option-resolver.md"; exit 1; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
rc=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 — $2"; rc=1; }

resolve() { # <env|-> <option|-> <name> <default> [<level-file>]; "-" leaves that layer unset
  local ev="$1" ov="$2"; shift 2
  (
    unset "$1" "CLAUDE_PLUGIN_OPTION_$1" 2>/dev/null
    [ "$ev" = - ] || export "$1=$ev"
    [ "$ov" = - ] || export "CLAUDE_PLUGIN_OPTION_$1=$ov"
    cc_option "$@"
  )
}

miss=""
expect() { # <want> <env|-> <option|-> <name> <default> [<level-file>]
  local want="$1" got st err; shift
  got=$(resolve "$@" 2>"$T/err"); st=$?
  err=$(cat "$T/err")
  [ "$got" = "$want" ] && [ "$st" -eq 0 ] && [ -z "$err" ] && return 0
  miss="want '$want' from ($*), got '$got' status $st stderr '$err'"
  return 1
}
verdict() { if [ "$2" -eq 0 ]; then pass "$1"; else fail "$1" "$miss"; fi; }

SW=CC_FIXTURE_SWITCH
expect off off on "$SW" on && expect on on off "$SW" off
verdict "env var beats option and default" $?
expect off - off "$SW" on
verdict "option used when env var unset" $?
expect off "" off "$SW" on
verdict "empty env var falls through to option" $?
expect quiet - - "$SW" quiet && expect on "" "" "$SW" on
verdict "default used when neither set" $?
expect on - true "$SW" off && expect off - false "$SW" on
verdict "option true/false normalised to on/off" $?
expect on - - "bad-name" on && expect on - - "" on && expect on - - "9LIVES" on
verdict "malformed name yields the default silently" $?

LVL="$T/terse-mode"; printf 'full extra\n' > "$LVL"
NOFILE="$T/no-such-level-file"
expect lite lite ultra CC_TERSE off "$LVL"
verdict "CC_TERSE env beats level file" $?
expect full - ultra CC_TERSE off "$LVL"
verdict "CC_TERSE level file beats option" $?
expect ultra - ultra CC_TERSE off "$NOFILE"
verdict "CC_TERSE option used when no env and no file" $?
expect off - - CC_TERSE off "$NOFILE" && expect off - - CC_TERSE off "$T"
verdict "CC_TERSE default when nothing set" $?

# ---- pc_shared_blocks owns cc_option ---------------------------------------------
. scripts/lib/plugin-checks.sh || { echo "FAIL: cannot source scripts/lib/plugin-checks.sh"; exit 1; }
P="$T/plugins"; mkdir -p "$P/verbatim/hooks" "$P/drifted/hooks"
{ echo '#!/bin/bash'; cat templates/blocks/option-resolver.md; echo 'exit 0'; } > "$P/verbatim/hooks/switch.sh"
{ echo '#!/bin/bash'; sed 's/false) v=off/false) v=of/' templates/blocks/option-resolver.md; echo 'exit 0'; } \
  > "$P/drifted/hooks/switch.sh"
if grep -qF 'false) v=of ;;' "$P/drifted/hooks/switch.sh"; then
  out=$(pc_shared_blocks "$P" templates/blocks) || true
  case "$out" in
    *"drifted/hooks/switch.sh option-resolver.md"*) pass "shared-blocks names a drifted cc_option copy" ;;
    *) fail "shared-blocks names a drifted cc_option copy" "got: ${out:-<empty>}" ;;
  esac
  case "$out" in
    *verbatim/hooks/switch.sh*) fail "verbatim cc_option copy stays clean" "flagged: $out" ;;
    *) pass "verbatim cc_option copy stays clean" ;;
  esac
else
  fail "shared-blocks names a drifted cc_option copy" "the one-character edit matched nothing in the block"
fi

exit "$rc"
