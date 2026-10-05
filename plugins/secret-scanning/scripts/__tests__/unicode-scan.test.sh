#!/usr/bin/env bash
# unicode-scan.test.sh — fixture cases for hooks/unicode-scan.sh: each invisible class, the bidi message, the one-shot, the off switches,
#   fail-open and the Bash write path. Bytes come from printf escapes: a literal invisible byte would not survive an editor or a paste.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/scripts/__tests__/unicode-scan.test.sh
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

out=$(fire "$T/zw.ts")
case "$out" in
  *"line 2"*"U+200B"*) ok "the report names line and codepoint" ;;
  *) bad "the report names line and codepoint" "got: $out" ;;
esac

SID='{"session_id":"once","transcript_path":"/tmp/once","tool_name":"Read","tool_input":{"file_path":"'"$T"'/zw.ts"}}'
first=$(printf '%s' "$SID" | "$BASH_BIN" "$HOOK" 2>/dev/null)
second=$(printf '%s' "$SID" | "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -n "$first" ] && [ -z "$second" ] && ok "warns once per file per session" \
  || bad "warns once per file per session" "first=${first:0:40} second=${second:0:40}"

printf 'const a = 1;\n' > "$T/later.ts"
LATER='{"session_id":"later","transcript_path":"/tmp/later","tool_name":"Write","tool_input":{"file_path":"'"$T"'/later.ts"}}'
first=$(printf '%s' "$LATER" | "$BASH_BIN" "$HOOK" 2>/dev/null)
printf 'const b\xe2\x80\x8b = 2;\n' >> "$T/later.ts"
second=$(printf '%s' "$LATER" | "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -z "$first" ] && case "$second" in *additionalContext*) true ;; *) false ;; esac \
  && ok "a clean first touch does not use up the file's warning" \
  || bad "a clean first touch does not use up the file's warning" "first=${first:0:40} second=${second:0:40}"

out=$(printf '{"session_id":"o1","transcript_path":"/tmp/o1","tool_name":"Read","tool_input":{"file_path":"'"$T"'/zw.ts"}}' \
      | CC_UNICODE_SCAN=off "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "CC_UNICODE_SCAN=off silences it" || bad "CC_UNICODE_SCAN=off silences it" "$out"
out=$(printf '{"session_id":"o2","transcript_path":"/tmp/o2","tool_name":"Read","tool_input":{"file_path":"'"$T"'/zw.ts"}}' \
      | CC_REMIND=off "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "CC_REMIND=off silences it (it is an advisory)" || bad "CC_REMIND=off silences it" "$out"

out=$(printf 'garbage' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc"
silent "$T/missing.ts" "a file that does not exist is silent"
out=$(fire "$T/zw.ts" Glob)
[ -z "$out" ] && ok "silent on a tool it does not match" || bad "silent on a tool it does not match" "$out"

printf '{"cells":[{"source":["x = 1  # \xe2\x80\xae\\n"]}]}\n' > "$T/bidi.ipynb"   # U+202E in a cell
printf '{"cells":[{"source":["x = 1\\n"]}]}\n'                  > "$T/clean.ipynb"
nbfire() { # notebook session
  printf '{"session_id":"%s","transcript_path":"/tmp/%s","tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s","cell_id":"c1","new_source":"x = 1"}}' \
    "$2" "$2" "$1" | "$BASH_BIN" "$HOOK" 2>/dev/null
}
first=$(nbfire "$T/bidi.ipynb" nb-once); second=$(nbfire "$T/bidi.ipynb" nb-once)
case "$first" in *"bidi.ipynb"*"BIDIRECTIONAL OVERRIDE"*) [ -z "$second" ] ;; *) false ;; esac \
  && ok "a NotebookEdit notebook with a bidi control warns once, like a Write" \
  || bad "a NotebookEdit notebook with a bidi control warns once, like a Write" "first=${first:0:60} second=${second:0:40}"
out=$(nbfire "$T/clean.ipynb" nb-clean)
[ -z "$out" ] && ok "a NotebookEdit on a clean notebook is silent" || bad "a NotebookEdit on a clean notebook is silent" "$out"

unset CLAUDE_PROJECT_DIR
R="$T/repo"; mkdir -p "$R/app/sub" "$T/outside"; git -C "$R" init -q 2>/dev/null
cp "$T/zw.ts" "$R/app/sub/zw.ts"; cp "$T/bidi.ts" "$R/app/up.ts"; cp "$T/clean.ts" "$R/app/sub/clean.ts"
cp "$T/zw.ts" "$T/outside/zw.ts"
bashfire() { # command [cwd]
  jq -cn --arg c "$1" --arg d "${2:-$R/app/sub}" --arg s "b$RANDOM$RANDOM" \
    '{session_id:$s, transcript_path:("/tmp/"+$s), tool_name:"Bash", cwd:$d, tool_input:{command:$c}}' \
    | "$BASH_BIN" "$HOOK" 2>/dev/null
}
out=$(bashfire "$(printf "cat > zw.ts <<'EOF'\nbody\nEOF")")
case "$out" in *"ZERO-WIDTH"*"zw.ts"*|*"zw.ts"*"ZERO-WIDTH"*) ok "a heredoc-written file is scanned" ;; *) bad "a heredoc-written file is scanned" "got: ${out:-<silent>}" ;; esac
out=$(bashfire "echo x > ../up.ts")
case "$out" in *"BIDIRECTIONAL OVERRIDE"*) ok "a ../ target from a subdirectory cwd resolves under the repo root" ;; *) bad "a ../ target from a subdirectory cwd resolves under the repo root" "got: ${out:-<silent>}" ;; esac
out=$(bashfire "echo x > zw.ts && echo y >> ../up.ts")
case "$out" in *"zw.ts"*"up.ts"*) ok "two written files are both reported" ;; *) bad "two written files are both reported" "got: ${out:-<silent>}" ;; esac
out=$(bashfire "echo x > clean.ts"); [ -z "$out" ] && ok "a clean Bash-written file is silent" || bad "a clean Bash-written file is silent" "$out"
out=$(bashfire "echo x > $T/outside/zw.ts"); [ -z "$out" ] && ok "a target outside the project root is skipped" || bad "a target outside the project root is skipped" "$out"
out=$(bashfire "cat zw.ts | grep x"); [ -z "$out" ] && ok "a Bash call with no write target is silent" || bad "a Bash call with no write target is silent" "$out"
out=$(bashfire "echo x > missing.ts"); [ -z "$out" ] && ok "a target that does not exist is silent" || bad "a target that does not exist is silent" "$out"
# The cap: nine targets, only the ninth carries a hit, so the 8-target bound shows as silence.
cmd9=""; for i in 1 2 3 4 5 6 7 8; do cp "$T/clean.ts" "$R/app/sub/c$i.ts"; cmd9="${cmd9}echo x > c$i.ts; "; done
out=$(bashfire "${cmd9}echo x > zw.ts"); [ -z "$out" ] && ok "at most 8 targets are handled per call" || bad "at most 8 targets are handled per call" "$out"
out=$(bashfire "echo x > zw.ts" "$T/gone"); [ -z "$out" ] && ok "a cwd that no longer exists fails open" || bad "a cwd that no longer exists fails open" "$out"
[ -z "$(find "$R" -name .claude 2>/dev/null)" ] && ok "no .claude/ state under the repo root or the subdirectory" \
  || bad "no .claude/ state under the repo root or the subdirectory" "$(find "$R" -name .claude)"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
