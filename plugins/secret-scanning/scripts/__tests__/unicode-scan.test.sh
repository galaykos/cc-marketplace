#!/usr/bin/env bash
# Fixture tests for hooks/unicode-scan.sh — the invisible-character scanner.
# Bytes are written with printf escapes, never with literal invisible characters in
# this file: a fixture whose point is an unreadable byte must not depend on that byte
# surviving an editor, a copy-paste, or this repo's own review.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/unicode-scan.sh"
BASH_BIN="${BASH:-bash}"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

fire() { # file [tool]
  printf '{"session_id":"u%s","transcript_path":"/tmp/u%s","tool_name":"%s","tool_input":{"file_path":"%s"}}' \
    "$RANDOM$RANDOM" "$RANDOM$RANDOM" "${2:-Read}" "$1" | "$BASH_BIN" "$HOOK" 2>/dev/null
}

printf 'const a = 1;\nconst b\xe2\x80\x8b = 2;\n'                       > "$T/zw.ts"      # U+200B
printf 'const a\xe2\x81\xa0 = 1;\n'                                     > "$T/wj.ts"      # U+2060
printf 'soft\xc2\xadhyphen\n'                                           > "$T/sh.ts"      # U+00AD
printf 'if (a) {\n  // \xe2\x80\xae } \xe2\x81\xa6 if (0) \xe2\x81\xa9\n}\n' > "$T/bidi.ts"   # U+202E + isolates
printf 'x\xf3\xa0\x80\x81y\n'                                           > "$T/tag.ts"     # U+E0001 tag
printf 'const a = 1;\n'                                                 > "$T/clean.ts"
printf '\xef\xbb\xbfconst a = 1;\n'                                     > "$T/bom.ts"     # leading BOM
printf 'x = 1;\n\xef\xbb\xbfy = 2;\n'                                   > "$T/midbom.ts"  # BOM mid-file

warns()  { out=$(fire "$1"); case "$out" in *additionalContext*) ok "$2" ;; *) bad "$2" "expected a warning, got: ${out:-<silent>}" ;; esac; }
silent() { out=$(fire "$1"); [ -z "$out" ] && ok "$2" || bad "$2" "expected silence, got: $out"; }

warns  "$T/zw.ts"     "zero-width space warns"
warns  "$T/wj.ts"     "word joiner warns"
warns  "$T/sh.ts"     "soft hyphen warns"
warns  "$T/tag.ts"    "a Unicode tag character warns"
warns  "$T/midbom.ts" "a BOM in the middle of a file warns"
silent "$T/clean.ts"  "clean ASCII is silent"
silent "$T/bom.ts"    "a LEADING BOM is an encoding, not a hider"

# the bidi class gets its own message, because the consequence is different
out=$(fire "$T/bidi.ts")
case "$out" in
  *"BIDIRECTIONAL OVERRIDE"*) ok "bidi overrides get the Trojan Source message" ;;
  *) bad "bidi overrides get the Trojan Source message" "got: ${out:-<silent>}" ;;
esac
out=$(fire "$T/zw.ts")
case "$out" in
  *"ZERO-WIDTH"*) ok "non-bidi gets the zero-width message" ;;
  *) bad "non-bidi gets the zero-width message" "got: ${out:-<silent>}" ;;
esac

# the report names a location, not just a fact
out=$(fire "$T/zw.ts")
case "$out" in
  *"line 2"*"U+200B"*) ok "the report names line and codepoint" ;;
  *) bad "the report names line and codepoint" "got: $out" ;;
esac

# one-shot per file per session
SID='{"session_id":"once","transcript_path":"/tmp/once","tool_name":"Read","tool_input":{"file_path":"'"$T"'/zw.ts"}}'
first=$(printf '%s' "$SID" | "$BASH_BIN" "$HOOK" 2>/dev/null)
second=$(printf '%s' "$SID" | "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -n "$first" ] && [ -z "$second" ] && ok "warns once per file per session" \
  || bad "warns once per file per session" "first=${first:0:40} second=${second:0:40}"

# off switches
out=$(printf '{"session_id":"o1","transcript_path":"/tmp/o1","tool_name":"Read","tool_input":{"file_path":"'"$T"'/zw.ts"}}' \
      | CC_UNICODE_SCAN=off "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "CC_UNICODE_SCAN=off silences it" || bad "CC_UNICODE_SCAN=off silences it" "$out"
out=$(printf '{"session_id":"o2","transcript_path":"/tmp/o2","tool_name":"Read","tool_input":{"file_path":"'"$T"'/zw.ts"}}' \
      | CC_REMIND=off "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "CC_REMIND=off silences it (it is an advisory)" || bad "CC_REMIND=off silences it" "$out"

# fail-open
out=$(printf 'garbage' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc"
silent "$T/missing.ts" "a file that does not exist is silent"
out=$(fire "$T/zw.ts" Bash)
[ -z "$out" ] && ok "silent on a tool it does not match" || bad "silent on a tool it does not match" "$out"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
