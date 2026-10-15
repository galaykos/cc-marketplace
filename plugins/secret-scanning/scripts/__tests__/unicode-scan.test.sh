#!/usr/bin/env bash
# unicode-scan.test.sh — fixture cases for hooks/unicode-scan.sh: each invisible class, the bidi message, the per-context one-shot, the off
#   switches, fail-open, the Bash write path and the log-BOM skip. Bytes come from printf escapes: a literal invisible byte would not survive an editor or a paste.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/scripts/__tests__/unicode-scan.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/unicode-scan.sh"
BASH_BIN="${BASH:-bash}"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

# The one-shot is per model context and file; a case that needs a warning again in the same context clears the markers.
newday() { find "$TMPDIR" -maxdepth 1 -name 'cc-unicode-*' -type d -exec rmdir {} + 2>/dev/null; }
fire() { # file [tool]
  newday
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
printf 'first\n\xef\xbb\xbf2026-10-15T10:00:00Z step output\n'           > "$T/step.log"   # a CI step's BOM leading a log line
printf 'build\tRun tests\t\xef\xbb\xbf2026-10-15T10:00:00Z ok\n'          > "$T/gh.log"     # gh run view --log: after the job and step fields
printf 'ok \xef\xbb\xbfhidden\n'                                          > "$T/mid.log"    # a BOM mid-line in a log
printf '\xef\xbb\xbf\xe2\x80\x8bx\n'                                     > "$T/run.log"    # a BOM leading a run of invisibles
printf 'line one\nline\xe2\x80\x8btwo\n'                                  > "$T/zw.log"     # U+200B in a log

warns()  { out=$(fire "$1"); case "$out" in *additionalContext*) ok "$2" ;; *) bad "$2" "expected a warning, got: ${out:-<silent>}" ;; esac; }
silent() { out=$(fire "$1"); [ -z "$out" ] && ok "$2" || bad "$2" "expected silence, got: $out"; }

warns  "$T/zw.ts"     "zero-width space warns"
warns  "$T/wj.ts"     "word joiner warns"
warns  "$T/sh.ts"     "soft hyphen warns"
warns  "$T/tag.ts"    "a Unicode tag character warns"
warns  "$T/midbom.ts" "a BOM in the middle of a file warns"
silent "$T/clean.ts"  "clean ASCII is silent"
silent "$T/bom.ts"    "a LEADING BOM is an encoding, not a hider"
silent "$T/step.log"  "a lone BOM leading a line of a .log is a CI step's encoding"
silent "$T/gh.log"    "a lone BOM leading a tab-separated field of a .log (gh run view --log) is skipped too"
warns  "$T/mid.log"   "a BOM mid-line in a .log still warns"
warns  "$T/run.log"   "a BOM leading a run of invisible characters in a .log still warns"
warns  "$T/zw.log"    "a zero-width space in a .log still warns"

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

newday; cp "$T/zw.ts" "$T/day.ts"
day() { # session [agent_id] — a Read of day.ts; a subagent's payload carries its parent's session_id and an agent_id of its own
  jq -cn --arg s "$1" --arg a "${2:-}" --arg f "$T/day.ts" \
    '{session_id:$s, transcript_path:("/tmp/"+$s), tool_name:"Read", tool_input:{file_path:$f}} + (if $a == "" then {} else {agent_id:$a} end)' \
    | "$BASH_BIN" "$HOOK" 2>/dev/null
}
first=$(day two); again=$(day two)
[ -n "$first" ] && [ -z "$again" ] && ok "warns once per file in one context" || bad "warns once per file in one context" "first=${first:0:40} again=${again:0:40}"
sub=$(day two agent-a); subagain=$(day two agent-a)
[ -n "$sub" ] && [ -z "$subagain" ] && ok "a subagent of the warned session reading the file is warned, once" \
  || bad "a subagent of the warned session reading the file is warned, once" "sub=${sub:0:40} again=${subagain:0:40}"
out=$(day three)
[ -n "$out" ] && ok "a new session reading the file is warned" || bad "a new session reading the file is warned" "got: <silent>"
nosess() { jq -cn --arg t "$1" --arg f "$T/day.ts" '{transcript_path:$t, tool_name:"Read", tool_input:{file_path:$f}}' | "$BASH_BIN" "$HOOK" 2>/dev/null; }
a1=$(nosess /tmp/ta); a2=$(nosess /tmp/ta); b1=$(nosess /tmp/tb)
[ -n "$a1" ] && [ -z "$a2" ] && [ -n "$b1" ] && ok "without a session_id the transcript path keys the context" \
  || bad "without a session_id the transcript path keys the context" "a1=${a1:0:30} a2=${a2:0:30} b1=${b1:0:30}"
printf 'const c = 3;\n' >> "$T/day.ts"; out=$(day two)
[ -z "$out" ] && ok "an edit leaving the invisible characters as they were stays silent" \
  || bad "an edit leaving the invisible characters as they were stays silent" "$out"
printf 'const d\xe2\x81\xa0 = 4;\n' >> "$T/day.ts"; out=$(day two)
case "$out" in *"U+2060"*) ok "a change to the file's invisible characters warns again" ;;
  *) bad "a change to the file's invisible characters warns again" "got: ${out:-<silent>}" ;; esac
# Seven U+200B, of which the report names six; turning the seventh into U+202E changes what the file hides, so it warns again, as bidi.
z=$(printf '\xe2\x80\x8b'); printf 'a%s%s%s%s%s%s b%s\n' "$z" "$z" "$z" "$z" "$z" "$z" "$z" > "$T/day.ts"; day two >/dev/null
printf 'a%s%s%s%s%s%s b\xe2\x80\xae\n' "$z" "$z" "$z" "$z" "$z" "$z" > "$T/day.ts"; out=$(day two)
case "$out" in *"BIDIRECTIONAL OVERRIDE"*) ok "a change past the sixth reported character warns again, and picks the message" ;;
  *) bad "a change past the sixth reported character warns again, and picks the message" "got: ${out:-<silent>}" ;; esac

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
newday; first=$(nbfire "$T/bidi.ipynb" nb-once); second=$(nbfire "$T/bidi.ipynb" nb-once)
case "$first" in *"bidi.ipynb"*"BIDIRECTIONAL OVERRIDE"*) [ -z "$second" ] ;; *) false ;; esac \
  && ok "a NotebookEdit notebook with a bidi control warns once, like a Write" \
  || bad "a NotebookEdit notebook with a bidi control warns once, like a Write" "first=${first:0:60} second=${second:0:40}"
out=$(nbfire "$T/clean.ipynb" nb-clean)
[ -z "$out" ] && ok "a NotebookEdit on a clean notebook is silent" || bad "a NotebookEdit on a clean notebook is silent" "$out"

unset CLAUDE_PROJECT_DIR
# The host sets the plugin data dir, which holds the bash-effects marker; without it the marker falls back under the repo (last case).
export CLAUDE_PLUGIN_DATA="$T/data"
R="$T/repo"; mkdir -p "$R/app/sub" "$T/outside"; git -C "$R" init -q 2>/dev/null
cp "$T/zw.ts" "$R/app/sub/zw.ts"; cp "$T/bidi.ts" "$R/app/up.ts"; cp "$T/clean.ts" "$R/app/sub/clean.ts"
cp "$T/zw.ts" "$T/outside/zw.ts"
bashfire() { # command [cwd] [session] [event] — a fresh context in one session, as a session's subagents are
  newday
  jq -cn --arg c "$1" --arg d "${2:-$R/app/sub}" --arg t "/tmp/b$RANDOM$RANDOM" --arg s "${3:-sess}" --arg e "${4:-PostToolUse}" \
    '{hook_event_name:$e, session_id:$s, transcript_path:$t, tool_name:"Bash", cwd:$d, tool_input:{command:$c}}' \
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
# After an in-command cd a relative target is skipped, a miss and never a wrong file; a cd inside a heredoc body moves nothing.
mkdir -p "$R/app/sub/docs"; cp "$T/bidi.ts" "$R/app/sub/README.md"; cp "$T/clean.ts" "$R/app/sub/docs/README.md"
out=$(bashfire "$(printf "cd docs && cat > README.md <<'EOF'\nclean\nEOF")")
[ -z "$out" ] && ok "a relative target after an in-command cd is skipped, not read from the payload cwd" \
  || bad "a relative target after an in-command cd is skipped, not read from the payload cwd" "got: ${out:0:120}"
out=$(bashfire "$(printf "cat > zw.ts <<'EOF'\ncd /srv\nEOF")")
case "$out" in *"zw.ts"*) ok "a cd inside a heredoc body does not skip the target" ;; *) bad "a cd inside a heredoc body does not skip the target" "got: ${out:-<silent>}" ;; esac

# Interpreter writes (bash-write-effects): a file a python run changed in git since this hook's previous call warns as a Write of it
# would; the first call in a repo only sets the marker; a run that wrote nothing, and a file an Edit changed between two Bash calls, stay silent.
K="$T/fx"; mkdir -p "$K/app"; git -C "$K" init -q 2>/dev/null
pyrun() { # python source [session] [event] — runs it in $K as the Bash tool would, then the hook
  local c="python3 - <<'PY'
$1
PY"
  (cd "$K" && bash -c "$c") >/dev/null 2>&1
  bashfire "$c" "$K" "${2:-sess}" "${3:-PostToolUse}"
}
out=$(pyrun "open('app/first.ts', 'w').write('const a' + chr(0x200b) + ' = 1;\n')")
[ -f "$K/app/first.ts" ] || bad "effects fixture" "the first python heredoc did not write app/first.ts"
[ -z "$out" ] && [ -n "$(find "$T/data" -name bash-effects-unicode.mark 2>/dev/null)" ] && ok "effects: the first call in a repo is silent and sets the marker" \
  || bad "effects: the first call in a repo is silent and sets the marker" "got: ${out:-<silent>}"
out=$(pyrun "open('app/zw.ts', 'w').write('const b' + chr(0x200b) + ' = 2;\n')")
case "$out" in *"ZERO-WIDTH"*"zw.ts"*|*"zw.ts"*"ZERO-WIDTH"*) ok "effects: a python heredoc write warns" ;; *) bad "effects: a python heredoc write warns" "got: ${out:-<silent>}" ;; esac
edit_out=$(fire "$K/app/zw.ts" Write)
ctx() { jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$1" 2>/dev/null; }
[ -n "$(ctx "$out")" ] && [ "$(ctx "$out")" = "$(ctx "$edit_out")" ] && ok "effects: the warning is the one a Write of that file draws" \
  || bad "effects: the warning is the one a Write of that file draws" "python=${out:0:80} write=${edit_out:0:80}"
out=$(bashfire "python3 -c 'print(1)'" "$K")   # app/zw.ts is still dirty in git, but older than the marker
[ -z "$out" ] && ok "effects: a python run that wrote nothing is silent" || bad "effects: a python run that wrote nothing is silent" "$out"
printf 'const c\xe2\x80\x8b = 3;\n' > "$K/app/edited.ts"
jq -cn --arg f "$K/app/edited.ts" --arg d "$K" '{session_id:"sess", transcript_path:"/tmp/e1", tool_name:"Edit", cwd:$d, tool_input:{file_path:$f}}' \
  | "$BASH_BIN" "$HOOK" >/dev/null 2>&1
out=$(pyrun "open('app/clean2.ts', 'w').write('const d = 4;\n')")
[ -z "$out" ] && ok "effects: a file an Edit changed between two Bash calls is not read again" \
  || bad "effects: a file an Edit changed between two Bash calls is not read again" "$out"
out=$(pyrun "open('app/failed.ts', 'w').write('const f' + chr(0x200b) + ' = 1;\n')
raise SystemExit(1)" sess PostToolUseFailure)
[ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$out" 2>/dev/null)" = PostToolUseFailure ] && case "$(ctx "$out")" in *"failed.ts"*) true ;; *) false ;; esac \
  && ok "effects: a failed python run (PostToolUseFailure) warns in that event's envelope" \
  || bad "effects: a failed python run (PostToolUseFailure) warns in that event's envelope" "got: ${out:-<silent>}"
jq -e '.hooks.PostToolUseFailure[] | select(.matcher == "Bash") | .hooks[] | select(.command | test("hooks/unicode-scan.sh"))' \
  "$(dirname "$HOOK")/hooks.json" >/dev/null 2>&1 && ok "effects: unicode-scan.sh is registered on PostToolUseFailure for Bash" \
  || bad "effects: unicode-scan.sh is registered on PostToolUseFailure for Bash" "$(jq -c '.hooks.PostToolUseFailure' "$(dirname "$HOOK")/hooks.json")"
out=$(pyrun "open('app/other.ts', 'w').write('const o' + chr(0x200b) + ' = 1;\n')" other-session)
[ -z "$out" ] && ok "effects: a marker another session dated reads nothing" || bad "effects: a marker another session dated reads nothing" "$out"
out=$(CLAUDE_PLUGIN_DATA= bashfire "echo x > clean.ts")
[ -f "$R/.claude/secret-scanning/bash-effects-unicode.mark" ] && ! git -C "$R" status --porcelain --untracked-files=all 2>/dev/null | grep -q '\.claude' \
  && ok "effects: without a plugin data dir the marker sits under the repo, ignored by git" \
  || bad "effects: without a plugin data dir the marker sits under the repo, ignored by git" "$(git -C "$R" status --porcelain --untracked-files=all 2>/dev/null | grep '\.claude')"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
