#!/bin/bash
# Mechanical verification for /terse:compress. Exits non-zero when the compressed
# file lost something the original had.
#
#   verify-compress.sh <compressed-file> <backup-file>
#
# WHY A SCRIPT AND NOT A CHECKLIST. Every other rule in this plugin is prose a
# model can satisfy by believing it did. These four checks either pass or fail on
# bytes: identifiers and URLs present in both, heading set unchanged, every number
# still there, and the file actually got smaller. That is the whole difference
# between `agent-graded` and something with teeth, and compression is the one
# place in this plugin that edits a user's file.
#
# It does NOT judge meaning. A compression that kept every identifier and dropped
# the sentence explaining why still passes here — that part stays agent-graded,
# and saying so is the honest scope.
set -u
new="${1:-}"; old="${2:-}"
[ -r "$new" ] && [ -r "$old" ] || {
  printf 'usage: verify-compress.sh <compressed-file> <backup-file>\n' >&2; exit 2; }

rc=0
fail() { printf 'FAIL  %s\n' "$1"; rc=1; }
pass() { printf 'PASS  %s\n' "$1"; }

# Trailing sentence punctuation is stripped: a URL written mid-sentence and the
# same URL at a sentence end must compare equal, or every rewrap looks like a loss.
ids() {
  grep -oE '`[^`]+`|https?://[^ )]+|\b[A-Za-z0-9_.-]+\.(md|json|ya?ml|sh|js|ts|py|php)\b' "$1" 2>/dev/null |
    sed 's/[.,;:)]*$//' | sort -u
}
lost=$(comm -23 <(ids "$old") <(ids "$new"))
if [ -n "$lost" ]; then
  fail "identifiers/URLs present in the original are missing:"
  printf '%s\n' "$lost" | sed 's/^/        /'
else
  pass "every identifier, path and URL survived"
fi

# No `|| echo 0` here: grep -c ALREADY prints 0, and exits 1 while doing it, so the
# fallback appended a second line. "0\n0" then made `[ -ne ]` error out and the
# heading check passed unconditionally on any headingless file — a check that
# cannot fail, which is the theater this repo's own doctrine names.
h_old=$(grep -c '^#' "$old" 2>/dev/null)
h_new=$(grep -c '^#' "$new" 2>/dev/null)
if [ "$h_old" -ne "$h_new" ]; then
  fail "heading count changed: $h_old → $h_new (a section moved or vanished)"
else
  pass "heading count unchanged ($h_new)"
fi

# Fenced blocks, content and all. The skill's strictest rule is that code survives
# byte-for-byte, and until this check existed that rule had no teeth: `ids()` only
# sees backticked spans, URLs and dotted filenames, so deleting a whole ```bash
# block full of bare commands passed every other check.
fences() { awk '/^[[:space:]]*```/{f=!f; next} f' "$1" 2>/dev/null | sed 's/[[:space:]]*$//' | sort; }
lostf=$(comm -23 <(fences "$old") <(fences "$new"))
if [ -n "$lostf" ]; then
  fail "lines inside fenced code blocks are missing:"
  printf '%s\n' "$lostf" | sed 's/^/        /'
else
  pass "fenced code blocks intact"
fi

nums() { grep -oE '\b[0-9]+([.,][0-9]+)*\b' "$1" 2>/dev/null | sort -u; }
lostn=$(comm -23 <(nums "$old") <(nums "$new"))
if [ -n "$lostn" ]; then
  fail "numbers dropped: $(printf '%s' "$lostn" | tr '\n' ' ')"
else
  pass "every number survived"
fi

b_old=$(wc -c < "$old" | tr -d ' '); b_new=$(wc -c < "$new" | tr -d ' ')
if [ "$b_new" -ge "$b_old" ]; then
  fail "no reduction: $b_old → $b_new bytes"
else
  pass "size $b_old → $b_new bytes ($(( (b_old - b_new) * 100 / b_old ))% smaller)"
fi

[ "$rc" -eq 0 ] || printf '\nrestore with: mv %s %s\n' "$old" "$new"
exit "$rc"
