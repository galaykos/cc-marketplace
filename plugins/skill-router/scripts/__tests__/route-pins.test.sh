#!/usr/bin/env bash
# route-pins.test.sh — pins hooks/route.sh's Bash target cap on both sides and paths of each main-block step (nudge_high_matches's
# one-nudge-per-skill and command-row installed filter, delivery before persistence, queue_low_matches's installed filter,
# persistence's pending_low dedup) on scratch rules.
set -u
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_DATA CC_REMIND CLAUDE_PLUGIN_OPTION_CC_REMIND
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/skill-router/hooks/route.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
PR="$WS/plugins/skill-router"
mkdir -p "$PR" "$WS/plugins/pinplug"
printf '%s\n' \
  $'glob\t*.pin8\tcap8-canary\tpinplug\thigh' \
  $'glob\t*.pin9\tcap9-canary\tpinplug\thigh' \
  $'glob\t*.pinx\tdup-canary\tpinplug\thigh' \
  $'glob\tdup.*\tdup-canary\tpinplug\thigh' \
  $'glob\t*.pind\tdeliver-canary\tpinplug\thigh' \
  $'command\t\\bpincmd\\b\tlivecmd-canary\tpinplug\thigh' \
  $'command\t\\bpincmd\\b\tghostcmd-canary\tpinabsent\thigh' \
  $'content\tPINLOW\tpresent-canary\tpinplug\tlow' \
  $'content\tPINLOW\tabsent-canary\tpinabsent\tlow' > "$PR/rules.tsv"

ok()  { echo "PASS: $1"; pass=$((pass+1)); }
bad() { echo "FAIL: $1 — $2"; fail=$((fail+1)); }
hook() {
  env CLAUDE_PLUGIN_ROOT="$PR" "$@" bash "$HOOK" 2>/dev/null
  local rc=$?; [ "$rc" -eq 0 ] || echo "rc=$rc" >> "$WS/nonzero"
}
edit() { # cwd file transcript [env...]
  local c="$1" f="$2" t="$3"; shift 3
  jq -cn --arg c "$c" --arg f "$f" --arg tp "$t" \
    '{hook_event_name:"PostToolUse",tool_name:"Edit",session_id:"sess",transcript_path:$tp,cwd:$c,
      tool_input:{file_path:$f,old_string:"a",new_string:"b"}}' | hook "$@"
}
bashw() { # cwd command transcript — runs the command, then the hook
  local c="$1" cmd="$2" t="$3"
  (cd "$c" && bash -c "$cmd") >/dev/null 2>&1
  jq -cn --arg c "$c" --arg cmd "$cmd" --arg tp "$t" \
    '{hook_event_name:"PostToolUse",tool_name:"Bash",session_id:"sess",transcript_path:$tp,cwd:$c,
      tool_input:{command:$cmd,description:"write"}}' | hook
}
nudges_for() { jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null | grep -c "load the \`$1\`"; }
statef() { printf '%s/.claude/skill-router/fired-%s.json' "$1" "$(printf '%s' "$2" | cksum | cut -d' ' -f1)"; }
mkrepo() { mkdir -p "$1"; git -C "$1" init -q; }

R="$WS/cap"; mkrepo "$R"
seven='echo a > t1.txt; echo a > t2.txt; echo a > t3.txt; echo a > t4.txt; echo a > t5.txt; echo a > t6.txt; echo a > t7.txt'
out=$(bashw "$R" "$seven; echo a > eighth.pin8" "$WS/t-cap8")
[ "$(nudges_for cap8-canary <<<"$out")" = 1 ] && ok "cap: the 8th Bash target is read" \
  || bad "cap: the 8th Bash target is read" "got: ${out:-<empty>}"
out=$(bashw "$R" "$seven; echo a > eighth.pin8; echo a > ninth.pin9" "$WS/t-cap9")
if [ ! -f "$R/ninth.pin9" ]; then bad "cap: a 9th Bash target is not read" "fixture: ninth.pin9 was not written"
elif [ "$(nudges_for cap8-canary <<<"$out")" = 1 ] && [ "$(nudges_for cap9-canary <<<"$out")" = 0 ]; then ok "cap: a 9th Bash target is not read"
else bad "cap: a 9th Bash target is not read" "got: ${out:-<empty>}"; fi

R="$WS/dup"; mkrepo "$R"; : > "$R/dup.pinx"
out=$(edit "$R" "$R/dup.pinx" "$WS/t-dup")
[ "$(nudges_for dup-canary <<<"$out")" = 1 ] && ok "high pass: two rows drawing one skill on one file nudge it once" \
  || bad "high pass: two rows drawing one skill on one file nudge it once" "got: ${out:-<empty>}"

R="$WS/cmd"; mkrepo "$R"
out=$(bashw "$R" "pincmd run" "$WS/t-cmd")
[ "$(nudges_for livecmd-canary <<<"$out")" = 1 ] && [ "$(nudges_for ghostcmd-canary <<<"$out")" = 0 ] \
  && ok "high pass: a command row whose plugin is not installed draws no nudge" \
  || bad "high pass: a command row whose plugin is not installed draws no nudge" "got: ${out:-<empty>}"

R="$WS/deliver"; mkrepo "$R"; : > "$R/x.pind"; : > "$WS/datafile"
out=$(edit "$R" "$R/x.pind" "$WS/t-deliver" CLAUDE_PLUGIN_DATA="$WS/datafile")
[ "$(nudges_for deliver-canary <<<"$out")" = 1 ] && ok "deliver: a nudge survives a state dir that cannot be created" \
  || bad "deliver: a nudge survives a state dir that cannot be created" "got: ${out:-<empty>}"

R="$WS/low"; mkrepo "$R"; printf 'PINLOW\n' > "$R/note.txt"
edit "$R" "$R/note.txt" "$WS/t-low" >/dev/null
sf=$(statef "$R" "$WS/t-low")
if jq -e '(.pending_low | any(.skill == "present-canary")) and (.pending_low | any(.skill == "absent-canary") | not)' "$sf" >/dev/null 2>&1
then ok "low pass: a content row whose plugin is not installed stays out of pending_low"
else bad "low pass: a content row whose plugin is not installed stays out of pending_low" "state: $(cat "$sf" 2>/dev/null)"; fi

edit "$R" "$R/note.txt" "$WS/t-low" >/dev/null
if [ "$(jq --arg f "$R/note.txt" '[.pending_low[] | select(.skill == "present-canary" and .file == $f)] | length' "$sf" 2>/dev/null)" = 1 ]
then ok "persist: a low signal repeated on one file is queued once"
else bad "persist: a low signal repeated on one file is queued once" "state: $(cat "$sf" 2>/dev/null)"; fi

[ ! -s "$WS/nonzero" ] && ok "every hook call exited 0" || bad "every hook call exited 0" "$(cat "$WS/nonzero")"

echo "route-pins: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
