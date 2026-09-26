#!/usr/bin/env bash
# scripts/host-constants.sh — the four Claude Code skill-listing constants, in ONE place.
#
# WHAT THEY ARE. The host budgets its skill listing at
#   budget_chars = contextWindowTokens x bytesPerToken x skillListingBudgetFraction
# and truncates any single entry's description at skillListingMaxDescChars. Read out of
# the shipped CLI binary (2.1.278, 2026-09-22) the four defaults sit in one minified
# declaration:  var <a>=0.01,<b>=4,<c>=200000;var <d>=1536;
#
# WHY THIS FILE EXISTS. Until 2026-09-22 `1536` was a bare literal in three places —
# scripts/context-budget.sh, scripts/lib/plugin-checks.sh and the SHIPPED
# plugins/all-plugins/scripts/all-plugins.sh — and `0.01` / `200000` in two more, with
# nothing anywhere re-reading the binary they claim to mirror. The 2026-09-22 panel
# (AR 8, rationale/specialist-panel-2026-09-22.md #59) found them all still correct and
# entirely unverifiable: a host release that moved one would leave every gate, README
# paragraph and fraction recommendation in this repo quietly wrong. One definition plus a
# re-read is the smallest thing that makes the claim falsifiable.
#
# TWO USES:
#   sourced  — defines HOST_LISTING_* and runs nothing else.
#   --check  — greps the PINNED CLI binary (pin read from scripts/official-validate.sh)
#              for those four literals in their declaration window and reports a diff.
#
# STANDING: WARN. Wired into CI as a `continue-on-error: true` step beside
# check-doc-staleness.sh — it reports a host change, it never fails a build on one,
# because the repo cannot be red for something upstream did between releases.
#
# WHAT IT DOES NOT CATCH:
#   - a host that keeps the literals and changes the FORMULA around them. The window is
#     anchored on `skillListingMaxDescChars??`, so the constants are read where the
#     listing code reads them, but arithmetic elsewhere is invisible here.
#   - any machine without the pinned build on disk: that path is a WARN-skip, and a
#     WARN-skip is the normal case on a fresh checkout and in CI.
#   - `bytesPerToken`. The host default is 4 and this file records it, but
#     context-budget.sh deliberately reports the 3-byte worst case (opus-5), so the two
#     numbers differ ON PURPOSE and no check can tell that apart from drift.
#   - the `SLASH_COMMAND_TOOL_CHAR_BUDGET` env short-circuit, which bypasses the formula
#     entirely when set (the binary returns it before any of these are read). Nothing
#     here or in context-budget.sh models a user who exports it.

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

# The declaration, anchored on the accessor that names the cap — one forward scan, no
# leading `.{N}` window (that form backtracks for minutes on a 200 MB binary).
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
