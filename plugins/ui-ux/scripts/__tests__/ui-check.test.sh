#!/usr/bin/env bash
# ui-check.test.sh — fixture transcripts for hooks/ui-check.sh: when it sends the turn back, prints one line or stays silent; one block per
#   edit set, the person speaking, a declined request; paths, Bash writes, subagents, browser evidence and settings; fail-open on bad input.
set -u
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_DATA CC_UI_CHECK CLAUDE_PLUGIN_OPTION_CC_UI_CHECK
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/ui-check.sh"
[ -f "$HOOK" ] || { echo "FAIL: hook not found at $HOOK"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (the hook fails open without it)"; exit 0; }

TMP="$(mktemp -d)"; trap 'chmod -R u+rwX "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
# The user's own settings must not decide a case: a playwright plugin enabled there would turn every notice into a block.
export HOME="$TMP/home" CLAUDE_CONFIG_DIR="$TMP/home/.claude"
mkdir -p "$CLAUDE_CONFIG_DIR"
rc=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n      %s\n' "$1" "$2"; rc=1; }

# A fresh git project and a path-shaped transcript per case, as the host sends them.
new_case() {
  P=$(mktemp -d "$TMP/proj.XXXXXX"); mkdir -p "$P/src"
  git init -q "$P" 2>/dev/null
  T="$CLAUDE_CONFIG_DIR/projects/-$(basename "$P")/0f8e2a6c-$(basename "$P").jsonl"
  mkdir -p "$(dirname "$T")"; : > "$T"; W=$T; RCWD=""; FAILNEXT=0; NOSTAMP=0
}
# Records go to W: the session transcript, or a subagent's beside it (<session>/subagents/agent-<id>.jsonl) with its .meta.json.
in_sub() { # <id> <finished: true|false> [requestShape]
  W="${T%.jsonl}/subagents/agent-$1.jsonl"; mkdir -p "$(dirname "$W")"; : >> "$W"
  jq -cn --argjson fin "$2" --arg shape "${3:-}" '{agentType:"ui-ux:ui-ux-engineer", toolUseId:"toolu_x"}
    + (if $shape == "" then {} else {requestShape:$shape} end) + (if $fin then {finished:true} else {} end)' > "${W%.jsonl}.meta.json"
}
in_main() { W=$T; }
n=0
stamp() { n=$((n + 1)); TS=$(printf '2026-10-27T%02d:%02d:%02d.000Z' $((10 + n / 3600)) $((n / 60 % 60)) $((n % 60))); }
tool() { # <name> <input json>; RCWD adds the record's cwd, FAILNEXT=1 marks its result an error, NOSTAMP=1 drops its timestamp
  stamp
  jq -cn --arg id "toolu_$n" --arg ts "$TS" --arg name "$1" --argjson in "$2" --arg cwd "$RCWD" --argjson nots "$NOSTAMP" \
    '{type:"assistant", message:{role:"assistant", content:[{type:"text", text:"Next step."}, {type:"tool_use", id:$id, name:$name, input:$in}]}}
     + (if $nots == 1 then {} else {timestamp:$ts} end) + (if $cwd == "" then {} else {cwd:$cwd} end)' >> "$W"
  jq -cn --arg id "toolu_$n" --arg ts "$TS" --argjson err "$FAILNEXT" \
    '{type:"user", timestamp:$ts, message:{role:"user", content:[{type:"tool_result", tool_use_id:$id, content:"ok"} + (if $err == 1 then {is_error:true} else {} end)]}}' >> "$W"
  FAILNEXT=0
}
edit()   { tool Edit "$(jq -cn --arg f "$1" '{file_path:$f, old_string:"a", new_string:"b"}')"; }
write()  { tool Write "$(jq -cn --arg f "$1" '{file_path:$f, content:"<div></div>"}')"; }
bashc()  { tool Bash "$(jq -cn --arg c "$1" '{command:$c}')"; }
browse() { tool mcp__plugin_playwright_playwright__browser_navigate '{"url":"http://localhost:5173/"}'; }
said()   { stamp; jq -cn --arg ts "$TS" --arg t "$1" '{type:"user", timestamp:$ts, message:{role:"user", content:$t}}' >> "$W"; }
delta()  { # <added json array> <removed json array>
  stamp; jq -cn --arg ts "$TS" --argjson a "$1" --argjson r "$2" \
    '{type:"attachment", timestamp:$ts, attachment:{type:"deferred_tools_delta", addedNames:$a, removedNames:$r}}' >> "$W"
}
PW='["mcp__plugin_playwright_playwright__browser_navigate","mcp__plugin_playwright_playwright__browser_console_messages"]'
listed() { delta "[\"WebFetch\",${PW#[}" '[]'; }
age() { # <path> <minutes ago>
  local e s; e=$(( $(date +%s) - $2 * 60 ))
  s=$(date -r "$e" +%Y%m%d%H%M.%S 2>/dev/null) || s=$(date -d "@$e" +%Y%m%d%H%M.%S); touch -t "$s" "$1"
}
fire() { # [stop_hook_active] [VAR=value …] — sets OUT and RC
  local active="${1:-false}"; shift 2>/dev/null
  OUT=$(jq -cn --arg t "$T" --arg c "$P" --argjson a "$active" \
    '{session_id:"11111111-2222-3333-4444-555555555555", transcript_path:$t, cwd:$c,
      hook_event_name:"Stop", stop_hook_active:$a, last_assistant_message:"Done."}' \
    | env "$@" bash "$HOOK" 2>/dev/null)
  RC=$?
}
is_block()  { [ "$RC" -eq 0 ] && printf '%s' "$OUT" | jq -e '.decision == "block" and (.reason | type) == "string" and (.systemMessage | type) == "string"' >/dev/null 2>&1; }
is_notice() { [ "$RC" -eq 0 ] && printf '%s' "$OUT" | jq -e '(has("decision") | not) and (.systemMessage | type) == "string" and (.systemMessage | length) > 0' >/dev/null 2>&1; }
is_silent() { [ "$RC" -eq 0 ] && [ -z "$OUT" ]; }
expect() { # <label> <is_block|is_notice|is_silent> [jq condition on OUT]
  if "$2" && { [ -z "${3:-}" ] || printf '%s' "$OUT" | jq -e "$3" >/dev/null 2>&1; }; then pass "$1"
  else fail "$1" "rc=$RC out=${OUT:-<silent>}"; fi
}
markers() { find "$1" -name 'ui-check-*' -type f 2>/dev/null | wc -l | tr -d ' '; }
NOTICE='.systemMessage | contains("no browser check was seen") and (contains("no browser tool") | not)'

new_case; listed; edit "$P/src/App.tsx"
fire
expect "a UI edit with no browser call since: one block, JSON on stdout, exit 0" is_block \
  '(.reason | contains("src/App.tsx") and contains("375, 768 and 1280") and contains("console") and contains("CC_UI_CHECK=off")) and (.systemMessage | contains("App.tsx"))'
if [ "$(markers "$P/.claude/ui-ux")" = 1 ]; then pass "the block's state file lands in the project (key hashed, not a raw path)"
else fail "the block's state file lands in the project (key hashed, not a raw path)" "found $(markers "$P/.claude/ui-ux") under $P/.claude/ui-ux"; fi
fire
expect "the same edits after a block: silent" is_silent
browse; edit "$P/src/styles/app.css"
fire
expect "a browser call after a block, then a newer UI edit: block again" is_block '.reason | contains("src/styles/app.css")'

new_case; listed; edit "$P/src/Old.vue"; browse; write "$P/resources/views/home.blade.php"
fire
expect "a UI edit newer than the last browser call: block naming only the edits since" is_block \
  '.reason | contains("resources/views/home.blade.php") and (contains("Old.vue") | not)'

new_case; listed; edit "$P/src/Old.tsx"; bashc "$(printf "cat > src/New.vue <<'EOF'\n<template/>\nEOF")"
fire
for i in 1 2 3 4 5 6 7 8 9; do bashc "grep -n Button src/Old.tsx > /tmp/ui-check-$i.txt"; done
fire
expect "nine later Bash reads after a block do not block the same edits again (only a strictly newer edit does)" is_silent

new_case; listed; edit "$P/src/App.tsx"; said "Now update the README, please."
fire
expect "the person spoke after the edit: silent (only edits since they last spoke count)" is_silent
NOTE="$(printf '<task-notification>\n<task-id>a1</task-id>\n<status>completed</status>\n</task-notification>')"
new_case; listed; edit "$P/src/App.tsx"; said "$NOTE"
fire
expect "a task notification opens a turn: the session's earlier edit is silent" is_silent
new_case; listed; in_sub a1 true; edit "$P/src/Hero.tsx"; in_main; said "$NOTE"
fire
expect "a subagent's edit survives its own task notification (turn openers clear only the session's edits): block" is_block '.reason | contains("src/Hero.tsx")'
new_case; listed; edit "$P/src/App.tsx"
stamp; jq -cn --arg ts "$TS" '{type:"user", timestamp:$ts, message:{role:"user", content:[{type:"image", source:{type:"base64", media_type:"image/png", data:"iVBO"}}]}}' >> "$T"
fire
expect "a prompt whose content starts with an image opens a turn: silent" is_silent
new_case; listed; edit "$P/src/App.tsx"
stamp; jq -cn --arg ts "$TS" '{type:"user", isCompactSummary:true, timestamp:$ts, message:{role:"user", content:"This session is being continued from a previous conversation."}}' >> "$T"
fire
expect "a compact summary is not the person speaking: block" is_block
new_case; listed; edit "$P/src/A.tsx"
fire
edit "$P/src/B.tsx"; fire true; said "Thanks. Now the API docs."; write "$P/docs/api.md"
fire
expect "an edit made during the hook's own continuation is not raised in a later, unrelated turn" is_silent

new_case; listed; edit "$P/src/A.tsx"
fire
edit "$P/src/B.tsx"
fire
expect "after a block with no browser call since, a newer edit only prints (declined)" is_notice \
  '.systemMessage | contains("B.tsx") and contains("not taken up")'
edit "$P/src/C.tsx"
fire
expect "declined stays a print until a browser call is seen" is_notice '.systemMessage | contains("C.tsx")'
browse; edit "$P/src/D.tsx"
fire
expect "a browser call ends the decline: the next edit blocks" is_block '.reason | contains("src/D.tsx")'

new_case; listed; edit "$P/src/A.tsx"
fire
said "Next: the settings page."; edit "$P/src/B.tsx"
fire
expect "one prompt after a declined block: still only prints" is_notice
said "And the profile page."; edit "$P/src/C.tsx"
fire
expect "the person's second prompt since the block ends the decline: block" is_block '.reason | contains("src/C.tsx")'

new_case; listed; edit "$P/src/A.tsx"
fire
said "Next: the settings page."; edit "$P/src/B.tsx"
fire
bashc "npm run dev"; edit "$P/src/C.tsx"
fire
expect "a dev-server start after a declined block ends the decline: block" is_block '.reason | contains("src/C.tsx")'

new_case; listed; edit "$P/src/App.tsx"; browse
fire
expect "a browser call after the UI edit: silent" is_silent

new_case; listed; edit "$P/src/App.tsx"
fire true
expect "the continuation stop (stop_hook_active true): silent" is_silent

new_case; listed; edit "$P/src/api.ts"; write "$P/README.md"; bashc "cat src/App.tsx | head -n 20"
bashc "grep -n Button src/App.tsx > /tmp/buttons.txt"
fire
expect "only non-UI edits, a read of a .tsx and its output redirected to a .txt: silent" is_silent

new_case; listed
for f in src/__tests__/a.tsx src/__mocks__/b.tsx tests/c.html test/d.vue e2e/e.html cypress/f.tsx spec/g.tsx playwright/h.html \
         src/i.test.tsx src/j.spec.tsx src/k.stories.tsx src/l.story.tsx src/m.cy.tsx src/setupTests.tsx; do edit "$P/$f"; done
fire
expect "test, mock, e2e, story and setupTests files: silent" is_silent

new_case; listed
for f in .claude/x.html .github/y.html taskmaster-docs/mockups/a.html dist/index.html build/b.css out/c.html coverage/d.html \
         storybook-static/e.html node_modules/pkg/f.css; do write "$P/$f"; done
fire
expect "scratch and generated paths (.claude, taskmaster-docs, dist, build, out, coverage, storybook-static, node_modules): silent" is_silent

new_case; listed
for f in packages/web/dist/a.html apps/site/.next/b.html src/.nuxt/c.css web/.svelte-kit/d.html pkg/node_modules/e.css \
         .claude/worktrees/w1/dist/f.html; do write "$P/$f"; done
fire
expect "generated directories at any depth, inside a worktree too: silent" is_silent

new_case; listed; in_sub w1 true; edit "$P/.claude/worktrees/agent-w1/src/App.tsx"; in_main
fire
expect "an isolated-worktree subagent's UI edit under .claude/worktrees counts: block" is_block '.reason | contains(".claude/worktrees/agent-w1/src/App.tsx")'

new_case; listed; write "$TMP/elsewhere/report.html"
fire
expect "a UI file outside the project (a scratch report.html): silent" is_silent

new_case; listed; FAILNEXT=1; edit "$P/src/App.tsx"
fire
expect "an edit whose result is an error: silent" is_silent

new_case; edit "$P/src/App.tsx"
fire
expect "no browser tool in the transcript or settings: one systemMessage naming the file, no block" is_notice \
  "($NOTICE) and (.systemMessage | contains(\"App.tsx\") and contains(\"CC_UI_CHECK=off\"))"

new_case; listed; edit "$P/src/App.tsx"
fire false CC_UI_CHECK=warn
expect "CC_UI_CHECK=warn: systemMessage, no block" is_notice '.systemMessage | contains("App.tsx") and contains("CC_UI_CHECK=warn")'

new_case; listed; edit "$P/src/App.tsx"
loud=""
for v in off OFF false 0 no; do fire false CC_UI_CHECK=$v; is_silent || loud="$loud $v"; done
[ -z "$loud" ] && pass "CC_UI_CHECK=off, OFF, false, 0 or no: silent" || fail "CC_UI_CHECK=off, OFF, false, 0 or no: silent" "spoke under:$loud"
fire false CC_UI_CHECK=WARN
expect "CC_UI_CHECK=WARN reads as warn: systemMessage, no block" is_notice
rm -f "$P"/.claude/ui-ux/ui-check-*
fire false CLAUDE_PLUGIN_OPTION_CC_UI_CHECK=off
expect "the /config option cc_ui_check set to off: silent" is_silent
fire false CC_UI_CHECK=on CLAUDE_PLUGIN_OPTION_CC_UI_CHECK=off
expect "CC_UI_CHECK=on beats the /config option: block" is_block

new_case; listed; edit "$P/src/App.tsx"; mkdir -p "$P/.claude/ui-ux"; chmod 555 "$P/.claude/ui-ux"
fire
if [ -w "$P/.claude/ui-ux" ]; then echo "SKIP  state that cannot be saved: this user can write a mode-555 directory"
else expect "state that cannot be saved: systemMessage, no block (an unrecorded block could repeat every stop)" is_notice \
  '.systemMessage | contains("could not save")'; fi
chmod 755 "$P/.claude/ui-ux"

new_case; edit "$P/src/App.tsx"; mkdir -p "$P/.claude"
printf '{"enabledPlugins":{"playwright@claude-plugins-official":true}}\n' > "$P/.claude/settings.json"
fire
expect "the playwright plugin enabled in project settings: block" is_block

new_case; edit "$P/src/App.tsx"; mkdir -p "$P/.claude"
printf '{"enabledPlugins":{"playwright@claude-plugins-official":false},"permissions":{"allow":["Bash(npx playwright test:*)"]}}\n' > "$P/.claude/settings.json"
fire
expect "the playwright plugin disabled and only named in a permission: systemMessage only" is_notice "$NOTICE"

new_case; listed; delta '[]' "$PW"; edit "$P/src/App.tsx"; mkdir -p "$P/.claude"
printf '{"enabledPlugins":{"playwright@claude-plugins-official":true}}\n' > "$P/.claude/settings.json"
fire
expect "a tool list whose browser tools were removed decides alone: systemMessage, though settings enable playwright" is_notice "$NOTICE"

new_case; edit "$P/src/App.tsx"; mkdir -p "$P/.claude"
printf '{"enabledPlugins":{"playwright@claude-plugins-official":true}}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
printf '{"enabledPlugins":{"playwright@claude-plugins-official":false}}\n' > "$P/.claude/settings.local.json"
fire
expect "local settings disabling playwright beat user settings enabling it: systemMessage" is_notice "$NOTICE"
printf '{"enabledPlugins":{"playwright@claude-plugins-official":false}}\n' > "$CLAUDE_CONFIG_DIR/settings.json"
printf '{"enabledPlugins":{"playwright@claude-plugins-official":true}}\n' > "$P/.claude/settings.local.json"
rm -f "$P"/.claude/ui-ux/ui-check-*
fire
expect "local settings enabling playwright beat user settings disabling it: block" is_block
rm -f "$CLAUDE_CONFIG_DIR/settings.json"

new_case; edit "$P/src/App.tsx"
printf '{"mcpServers":{"chrome-devtools":{"command":"npx","args":["chrome-devtools-mcp@latest"]}}}\n' > "$P/.mcp.json"
fire
expect "a chrome server in .mcp.json nobody approved: systemMessage" is_notice "$NOTICE"
mkdir -p "$P/.claude"; printf '{"enableAllProjectMcpServers":true}\n' > "$P/.claude/settings.json"
rm -f "$P"/.claude/ui-ux/ui-check-*
fire
expect "the same server once project servers are approved: block" is_block

new_case; edit "$P/src/App.tsx"
printf '{"mcpServers":{"chrome-devtools":{"command":"npx","args":["chrome-devtools-mcp@latest"]}}}\n' > "$CLAUDE_CONFIG_DIR/.claude.json"
fire
expect "a chrome MCP server in the user's .claude.json: block" is_block
jq -n --arg p "$P" '{mcpServers:{"chrome-devtools":{command:"npx"}}, projects:{($p):{disabledMcpServers:["chrome-devtools"]}}}' > "$CLAUDE_CONFIG_DIR/.claude.json"
rm -f "$P"/.claude/ui-ux/ui-check-*
fire
expect "the same server disabled for this project: systemMessage" is_notice "$NOTICE"
rm -f "$CLAUDE_CONFIG_DIR/.claude.json"

new_case; listed; bashc "$(printf "cat > src/Card.vue <<'EOF'\n<template><div class=\"card\"/></template>\nEOF")"
fire
expect "a Bash heredoc writing src/Card.vue: block naming it" is_block '.reason | contains("src/Card.vue")'

new_case; listed; bashc "$(printf "cat > notes.md <<'EOF'\necho x > src/App.tsx\nEOF")"
fire
expect "a heredoc body holding 'echo x > src/App.tsx' while the command writes a .md: silent" is_silent

new_case; listed; bashc "$(printf "cd web && cat > src/App.tsx <<'EOF'\n<div/>\nEOF")"; bashc "pushd web; echo '<div/>' > src/Nav.tsx; popd"
fire
expect "a relative Bash target after cd or pushd: silent" is_silent

new_case; listed; RCWD="$P/web"; bashc "echo '<div/>' > src/App.tsx"; RCWD=""
fire
expect "a relative Bash target resolves against the record's cwd: block naming web/src/App.tsx" is_block '.reason | contains("web/src/App.tsx")'

new_case; listed; RCWD="$TMP/elsewhere"; bashc "echo '<div/>' > src/App.tsx"; RCWD=""
fire
expect "a relative Bash target whose record cwd is outside the project: silent" is_silent

loud=""
for w in "npx playwright test" "node puppeteer-shot.js" "npx cypress run" "php artisan dusk" "npx vitest --browser" \
         "npm run test-storybook" "npx wdio run" "npx lighthouse http://localhost:5173" "npx lhci autorun" "npx pa11y http://localhost:5173"; do
  new_case; listed; edit "$P/src/App.tsx"; bashc "$w"; fire; is_silent || loud="$loud [$w]"
done
[ -z "$loud" ] && pass "every browser word in a later Bash command counts as a browser call: silent" \
  || fail "every browser word in a later Bash command counts as a browser call: silent" "spoke after:$loud"

loud=""
for w in "npm run test:e2e" "pnpm e2e" "npx vitest --project=browser" "chromium --headless --screenshot=/tmp/s.png http://localhost:5173" \
         "npx backstop test" "npx @axe-core/cli http://localhost:5173"; do
  new_case; listed; edit "$P/src/App.tsx"; bashc "$w"; fire; is_silent || loud="$loud [$w]"
done
[ -z "$loud" ] && pass "e2e, headless, screenshot, backstop and axe runs count as browser calls: silent" \
  || fail "e2e, headless, screenshot, backstop and axe runs count as browser calls: silent" "spoke after:$loud"

quiet=""
for w in "cat playwright.config.ts" "npm i -D @playwright/test" "git commit -m 'add cypress tests'" "npx playwright install chromium" \
         "node scripts/notify.js \"browser tests come next\"" "$(printf "cat > run-checks.sh <<'EOF'\nnpx playwright test\nEOF")"; do
  new_case; listed; edit "$P/src/App.tsx"; bashc "$w"; fire; is_block || quiet="$quiet [$w]"
done
[ -z "$quiet" ] && pass "reading, installing, committing or writing a file that names a browser tool is not a check: block" \
  || fail "reading, installing, committing or writing a file that names a browser tool is not a check: block" "silent after:$quiet"

new_case; listed; bashc "echo '<div/>' > src/App.tsx && npx playwright test"
fire
expect "a check after a write in the same command: silent" is_silent

new_case; listed; edit "$P/src/App.tsx"; bashc "$(printf "bash <<'EOF'\nnpx playwright test\nEOF")"
fire
expect "a heredoc that bash runs, holding a playwright run, counts as a check: silent" is_silent

new_case; listed; edit "$P/src/App.TSX"
fire
expect "an upper-case extension is a UI file (.TSX): block" is_block '.reason | contains("src/App.TSX")'
new_case; listed; edit "$P/src/App.tsx"; tool mcp__Chrome-DevTools__navigate_page '{"url":"http://localhost:5173/"}'
fire
expect "an upper-case browser tool name counts (mcp__Chrome-DevTools__…): silent" is_silent

new_case; listed; bashc "$(printf "cat > src/Card.vue <<'EOF'\n<template/>\nEOF")"
for i in 1 2 3 4 5 6 7 8 9; do bashc "npx tsc --noEmit src/App.tsx 2>&1 >&2 2>/dev/null | head -n 5"; done
fire
expect "fd-only redirects are not writes and do not use up the eight-command window: block naming src/Card.vue" is_block '.reason | contains("src/Card.vue")'

new_case; delta '["mcp__shots__take_screenshot"]' '[]'; edit "$P/src/App.tsx"
fire
expect "a screenshot-only tool list is not a browser tool: systemMessage" is_notice "$NOTICE"

new_case; listed; edit "$P/src/App.tsx"; tool mcp__shots__take_screenshot '{"url":"http://localhost:5173/"}'
fire
expect "a tool whose name holds screenshot counts as a browser call: silent" is_silent

new_case; listed; for i in 1 2 3 4 5 6 7 8 9; do edit "$P/src/Part$i.tsx"; done
for i in $(seq 1 40); do edit "$P/src/App.tsx"; done
fire
expect "one file edited 40 times is named once; ten files read as 8 listed and 2 more" is_block \
  '(.reason | [match("src/App.tsx"; "g")] | length) == 1 and (.reason | contains("and 2 more")) and (.systemMessage | contains("and 7 more"))'

new_case; listed; edit "$P/src/odd	name.tsx"
fire
expect "a UI path holding a tab stays one file" is_block '(.reason | [match("  - "; "g")] | length) == 1 and (.reason | contains("name.tsx"))'

new_case; listed; tool Agent '{"description":"Build the hero","prompt":"Build it."}'
in_sub a1 true; edit "$P/src/Hero.tsx"; in_main
fire
expect "a subagent's UI edit with no browser call since: the parent turn is sent back, naming it as a subagent's edit" is_block \
  '(.reason | contains("src/Hero.tsx (a subagent'"'"'s edit)")) and (.systemMessage | contains("by a subagent"))'

new_case; listed; in_sub a1 true; edit "$P/src/Hero.tsx"; in_main; browse
fire
expect "a subagent's UI edit, then a browser call in the parent: silent" is_silent

new_case; listed; in_sub a1 true; edit "$P/src/Hero.tsx"; browse; in_main
fire
expect "a subagent's browser call after its own UI edit: silent" is_silent

new_case; listed; in_sub a1 true; browse; in_main; edit "$P/src/App.tsx"
fire
expect "a subagent's browser call, then a newer UI edit in the parent: block" is_block '.reason | contains("src/App.tsx")'

new_case; listed; browse; in_sub a1 true; tool Read "{\"file_path\":\"$P/README.md\"}"; NOSTAMP=1; edit "$P/src/Late.tsx"; NOSTAMP=0; in_main
fire
expect "a subagent record with no timestamp takes the previous record's: its edit after the browser call blocks" is_block '.reason | contains("src/Late.tsx")'

new_case; listed; edit "$P/src/Main.tsx"; in_sub bad true; edit "$P/src/Broken.vue"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/x/src/Half.tsx\n' >> "$W"
in_sub good true; edit "$P/src/Good.vue"; in_main
fire
expect "a subagent file with a bad line drops only that subagent" is_block \
  '.reason | contains("src/Main.tsx") and contains("src/Good.vue") and (contains("Broken.vue") | not)'

new_case; listed; in_sub q1 true; bashc "$(printf "cat > \"src/Q.vue\" <<'EOF'\n<template/>\nEOF")"; in_main
fire
expect "a subagent's Bash write with a quoted target is found (the scan crosses escaped quotes)" is_block '.reason | contains("src/Q.vue")'

new_case; listed; edit "$P/src/Main.tsx"; in_sub r0 false; edit "$P/src/Busy.vue"; in_main
fire
expect "a running subagent that is not a background agent: judged now, the parent's edit blocks" is_block '.reason | contains("src/Main.tsx")'
new_case; listed; edit "$P/src/Main.tsx"; in_sub r2 false background; tool Read "{\"file_path\":\"$P/README.md\"}"; in_main
fire
expect "a running background subagent with no UI work in its file: judged now, the parent's edit blocks" is_block '.reason | contains("src/Main.tsx")'
new_case; listed; edit "$P/src/Main.tsx"; in_sub r1 false background; edit "$P/src/BUSY.VUE"; in_main
fire
if is_silent && [ "$(markers "$P/.claude/ui-ux")" = 0 ]; then pass "a running background subagent doing UI work (matched in any case): silent, nothing recorded"
else fail "a running background subagent doing UI work (matched in any case): silent, nothing recorded" "rc=$RC out=${OUT:-<silent>} markers=$(markers "$P/.claude/ui-ux")"; fi
age "${T%.jsonl}/subagents/agent-r1.jsonl" 31
fire
expect "an unfinished subagent idle for 31 minutes is skipped: the parent's edit blocks" is_block \
  '.reason | contains("src/Main.tsx") and (contains("Busy.vue") | not)'

new_case; listed; edit "$P/src/App.tsx"; in_sub a2 true; edit "$P/src/Hidden.vue"; in_main
sub="${T%.jsonl}/subagents/agent-a2.jsonl"; chmod 000 "$sub"
fire
if [ -r "$sub" ]; then echo "SKIP  an unreadable subagent transcript: this user can read a mode-000 file"
else expect "an unreadable subagent transcript is skipped: the parent's own edit still blocks, the subagent's is not named" is_block \
  '.reason | contains("src/App.tsx") and (contains("Hidden.vue") | not)'; fi
chmod 644 "$sub"

D=$(mktemp -d "$TMP/proj.XXXXXX"); mkdir -p "$D/src" "$D/sub"; git init -q "$D" 2>/dev/null; git init -q "$D/sub" 2>/dev/null
P="$D/sub"; T="$CLAUDE_CONFIG_DIR/projects/-nested/0f8e2a6c-nested.jsonl"; mkdir -p "$(dirname "$T")"; : > "$T"; W=$T
listed; edit "$D/src/App.tsx"
fire
expect "without CLAUDE_PROJECT_DIR a nested repo is the project: the parent repo's edit is outside it, silent" is_silent
fire false CLAUDE_PROJECT_DIR="$D"
expect "CLAUDE_PROJECT_DIR decides the project: the same edit blocks" is_block
[ "$(markers "$D/.claude/ui-ux")" = 1 ] && pass "its state lands under CLAUDE_PROJECT_DIR" \
  || fail "its state lands under CLAUDE_PROJECT_DIR" "found $(markers "$D/.claude/ui-ux") under $D/.claude/ui-ux"

new_case; listed; edit "$P/src/App.tsx"; T1=$T
T="${T%.jsonl}-second.jsonl"; W=$T; : > "$T"; listed; edit "$P/src/App.tsx"
fire; second=$OUT; T=$T1; fire
if [ -n "$second" ] && is_block && [ "$(markers "$P/.claude/ui-ux")" = 2 ]; then pass "one state file per session: a second session's block does not silence the first"
else fail "one state file per session: a second session's block does not silence the first" "first=${OUT:-<silent>} markers=$(markers "$P/.claude/ui-ux")"; fi

new_case; listed; edit "$P/src/App.tsx"
fire false CLAUDE_PLUGIN_DATA="$TMP/data"
if is_block && [ "$(markers "$TMP/data")" -ge 1 ] && [ "$(markers "$P/.claude")" = 0 ]; then pass "with CLAUDE_PLUGIN_DATA set the state lands there, none in the project"
else fail "with CLAUDE_PLUGIN_DATA set the state lands there, none in the project" "rc=$RC data=$(markers "$TMP/data") project=$(markers "$P/.claude")"; fi

new_case; listed; edit "$P/src/App.tsx"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"mcp__plugin_playwright_playwright__browser_navigate","input":{"url":"http://loc\n' >> "$T"
in_sub a5 true; edit "$P/src/Sub.vue"; in_main
fire
expect "a session line that does not parse silences everything, a subagent's edit included: exit 0" is_silent

new_case; listed; edit "$P/src/App.tsx"; rm -f "$T"
fire
expect "a transcript that does not exist: silent, exit 0" is_silent

OUT=$(printf 'not json' | bash "$HOOK" 2>/dev/null); RC=$?
expect "a payload that is not JSON: silent, exit 0" is_silent

printf '\n'
[ "$rc" -eq 0 ] && printf 'ui-check.test: all cases passed\n' || printf 'ui-check.test: FAILURES above\n'
exit "$rc"
