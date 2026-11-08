#!/usr/bin/env bash
# Harness for hooks/review-state.sh with the payload shapes the host sends: a forge-using context that changed the
# scene is blocked once per change cycle; a review clears it; neighbours stay silent (no forge in use, the _for_cli
# headless call, a failed review, one whose traceback names contact_sheet, stop_hook_active, another transcript,
# the off switch, a malformed payload); the 24 h sweep never deletes the current context's state.
set -u
here=$(cd "$(dirname "$0")" && pwd)
H="$here/../../hooks/review-state.sh"
[ -x "$H" ] || { printf 'FAIL: review-state.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export CLAUDE_PLUGIN_DATA="$T/data"
unset CC_FORGE_REVIEW CLAUDE_PLUGIN_OPTION_CC_FORGE_REVIEW
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }
post() { # <transcript> <tool_name> <code-or-response>
  jq -cn --arg t "$1" --arg n "$2" --arg c "$3" '{session_id:"s", transcript_path:$t, cwd:"/tmp", hook_event_name:"PostToolUse",
    tool_name:$n, tool_input:{code:$c}, tool_response:[{type:"text", text:$c}]}' | bash "$H"
}
stop() { jq -cn --arg t "$1" --argjson a "${2:-false}" '{session_id:"s", transcript_path:$t, cwd:"/tmp", hook_event_name:"Stop", stop_hook_active:$a}' | bash "$H"; }
blocks() { printf '%s' "$1" | jq -e '.decision == "block" and (.reason | contains("/asset-forge:review"))' >/dev/null 2>&1; }

EXEC=mcp__Blender__execute_blender_code
REVIEW=mcp__plugin_asset-forge_forge__render_review_set
[ -z "$(stop /t/a.jsonl)" ] && ok "a fresh context stops freely" || bad "fresh stop"
post /t/a.jsonl "$EXEC" 'bpy.data.objects["Cube"].location.x = 1' >/dev/null
[ -z "$(stop /t/a.jsonl)" ] && ok "Blender edits without forge in use never block" || bad "no-forge block"

post /t/b.jsonl "$EXEC" 'sys.path.insert(0, "/x/asset-forge/blender_lib"); import forge' >/dev/null
out=$(stop /t/b.jsonl); blocks "$out" && ok "a forge context that changed the scene is blocked at Stop" || bad "block ($out)"
[ -z "$(stop /t/b.jsonl)" ] && ok "it blocks once per change cycle" || bad "second block"
post /t/b.jsonl "$EXEC" 'more edits' >/dev/null
[ -z "$(stop /t/b.jsonl)" ] && ok "more edits in the same cycle do not block again" || bad "same-cycle block"

post /t/c.jsonl "$EXEC" 'import forge' >/dev/null
[ -z "$(stop /t/c.jsonl true)" ] && ok "stop_hook_active never blocks" || bad "stop_hook_active"

post /t/d.jsonl "$EXEC" 'import forge' >/dev/null
post /t/d.jsonl "$REVIEW" '{"ok": false, "stage": "input", "error": "no object"}' >/dev/null
out=$(stop /t/d.jsonl); blocks "$out" && ok "a failed review does not clear the change" || bad "failed review cleared ($out)"
post /t/h.jsonl "$EXEC" 'import forge' >/dev/null
post /t/h.jsonl "$REVIEW" '{"ok": false, "stage": "op:call", "traceback": "File review_renders.py, in _contact_sheet"}' >/dev/null
out=$(stop /t/h.jsonl); blocks "$out" && ok "a failed review whose traceback names contact_sheet does not clear it" || bad "traceback cleared ($out)"
post /t/d.jsonl "$REVIEW" '{"ok": true, "contact_sheet": "/tmp/x/contact_sheet.png"}' >/dev/null
[ -z "$(stop /t/d.jsonl)" ] && ok "a successful review clears the change" || bad "review did not clear"
post /t/d.jsonl "$EXEC" 'deform.inflate(...)' >/dev/null
out=$(stop /t/d.jsonl); blocks "$out" && ok "an edit after the review starts a new cycle that blocks again" || bad "new cycle ($out)"

post /t/e.jsonl mcp__plugin_asset-forge_forge__validate_asset '{}' >/dev/null
post /t/e.jsonl mcp__Blender__execute_blender_code_for_cli 'headless read' >/dev/null
[ -z "$(stop /t/e.jsonl)" ] && ok "the _for_cli headless call does not mark a change" || bad "_for_cli marked"

post /t/f.jsonl "$EXEC" 'import forge' >/dev/null
[ -z "$(CC_FORGE_REVIEW=off stop /t/f.jsonl)" ] && ok "CC_FORGE_REVIEW=off silences it" || bad "env off"
[ -z "$(CLAUDE_PLUGIN_OPTION_CC_FORGE_REVIEW=false stop /t/f.jsonl)" ] && ok "the /config option set to false silences it" || bad "option off"
out=$(stop /t/f.jsonl); blocks "$out" && ok "another transcript keeps its own state" || bad "per-transcript ($out)"

post /t/g.jsonl "$EXEC" 'import forge' >/dev/null
touch -t 200001010000 "$CLAUDE_PLUGIN_DATA/review-$(printf '%s' /t/g.jsonl | cksum | cut -d' ' -f1)"
out=$(stop /t/g.jsonl); blocks "$out" && ok "the 24 h sweep keeps the state of the context that is firing" || bad "own state swept ($out)"

out=$(printf 'not json' | bash "$H"); rc=$?
[ -z "$out" ] && [ "$rc" = 0 ] && ok "a malformed payload fails open" || bad "malformed (rc=$rc)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
