#!/usr/bin/env bash
# host-constants.sh [--check] — the four Claude Code skill-listing constants in one place (budget_chars = contextWindowTokens x bytesPerToken x skillListingBudgetFraction; skillListingMaxDescChars caps one entry). Sourced: defines HOST_LISTING_* only. --check: re-reads them from the pinned CLI binary.
# Misses: a formula changed around unchanged literals, a machine without the pinned build (WARN-skip, the CI norm), bytesPerToken (context-budget.sh uses 3 on purpose), SLASH_COMMAND_TOOL_CHAR_BUDGET. Standing: WARN (continue-on-error in CI).
# Why, limits, history: rationale/derivations/scripts.md § scripts/host-constants.sh

HOST_LISTING_FRACTION=0.01
HOST_LISTING_BYTES_PER_TOKEN=4
HOST_LISTING_CTX_TOKENS=200000
HOST_LISTING_MAX_DESC=1536

# Sourced? Define and stop. (Executed: $0 is this file; sourced: it is the caller's.)
case "${BASH_SOURCE[0]}" in "$0") ;; *) return 0 ;; esac

[ "${1:-}" = "--check" ] || { printf 'usage: %s --check   (or source it for HOST_LISTING_*)\n' "${0##*/}" >&2; exit 2; }

hc_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pin="${HOST_CONSTANTS_PIN:-$(sed -n 's/^PIN="\([0-9.]*\)".*/\1/p' "$hc_root/scripts/official-validate.sh" | head -1)}"
[ -n "$pin" ] || { echo "WARN: host-constants: no PIN= found in scripts/official-validate.sh — cannot pick a binary to read"; exit 0; }

bin="${HOST_CONSTANTS_BIN:-$HOME/.local/share/claude/versions/$pin}"
if [ ! -r "$bin" ]; then
  echo "WARN: host-constants: pinned CLI build $pin is not on this machine ($bin) — the four listing constants were NOT re-read"
  echo "      declared: fraction=$HOST_LISTING_FRACTION bytesPerToken=$HOST_LISTING_BYTES_PER_TOKEN ctxTokens=$HOST_LISTING_CTX_TOKENS maxDesc=$HOST_LISTING_MAX_DESC"
  exit 0
fi

# Anchored on the accessor naming the cap, with no leading `.{N}` window: that form backtracks for minutes on a 200 MB binary.
decl="$(LC_ALL=C grep -a -o -E '[A-Za-z0-9_$]+=[0-9.]+,[A-Za-z0-9_$]+=[0-9]+,[A-Za-z0-9_$]+=[0-9]+;var [A-Za-z0-9_$]+=[0-9]+;function [A-Za-z0-9_$]+\(\)\{return [A-Za-z0-9_$]+\(\)\.skillListingMaxDescChars' "$bin" 2>/dev/null | head -1)"
if [ -z "$decl" ]; then
  echo "WARN: host-constants: $pin does not carry the four-constant declaration next to skillListingMaxDescChars — the listing code was restructured; re-read it by hand and update this file"
  exit 1
fi

nums="$(printf '%s' "$decl" | LC_ALL=C sed -E 's/^[A-Za-z0-9_$]+=([0-9.]+),[A-Za-z0-9_$]+=([0-9]+),[A-Za-z0-9_$]+=([0-9]+);var [A-Za-z0-9_$]+=([0-9]+);.*/\1 \2 \3 \4/')"
set -- $nums
if [ "$1" = "$HOST_LISTING_FRACTION" ] && [ "$2" = "$HOST_LISTING_BYTES_PER_TOKEN" ] \
   && [ "$3" = "$HOST_LISTING_CTX_TOKENS" ] && [ "$4" = "$HOST_LISTING_MAX_DESC" ]; then
  echo "OK: host-constants: CLI $pin still declares fraction=$1 bytesPerToken=$2 ctxTokens=$3 maxDesc=$4"
  exit 0
fi

echo "WARN: host-constants: CLI $pin does NOT declare the constants this repo assumes"
echo "      declared here: fraction=$HOST_LISTING_FRACTION bytesPerToken=$HOST_LISTING_BYTES_PER_TOKEN ctxTokens=$HOST_LISTING_CTX_TOKENS maxDesc=$HOST_LISTING_MAX_DESC"
echo "      read from $pin: fraction=$1 bytesPerToken=$2 ctxTokens=$3 maxDesc=$4"
echo "      fix scripts/host-constants.sh, then re-check every doc that quotes these (plugins/all-plugins/README.md, plugins/all-plugins/scripts/all-plugins.sh)"
exit 1
