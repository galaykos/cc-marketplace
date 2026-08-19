#!/usr/bin/env bash
# Install-shaped end-to-end test for the candor plugin.
#
# WHAT THIS CARRIES THAT THE OTHER TWO HARNESSES DO NOT. gate.test.sh and
# candor-scan.test.sh invoke the scripts by their in-repo path. That leaves four
# things untested, and all four are ways a plugin ships broken through a green
# suite:
#   1. the hook is reached the way Claude Code reaches it — by expanding
#      ${CLAUDE_PLUGIN_ROOT} in hooks/hooks.json, not by a path someone typed;
#   2. the plugin is a COPY in a temp dir, so nothing may resolve back into this
#      repository (a relative `../` would pass in-tree and fail on every install);
#   3. the consumer project is NOT a git repository — this gate claims to be
#      portable where the marketplace's own scripts/done-gate.sh is not;
#   4. transcript entries carry the full real-world field set (uuid, sessionId,
#      timestamp, cwd, gitBranch, message.role, message.id), not the minimal
#      shape the other fixtures use.
#
# The payload sends transcript_path, which is the field the hook actually reads
# (scripts/lib/plugin-checks.sh, pc_harness_payload).
set -u

SRC="$(cd "$(dirname "$0")/.." && cd .. && pwd)"   # plugins/candor
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }

WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
export CLAUDE_PLUGIN_ROOT="$WS/plugin-root"
PROJ="$WS/consumer-project"
mkdir -p "$CLAUDE_PLUGIN_ROOT" "$PROJ/src"
cp -R "$SRC/." "$CLAUDE_PLUGIN_ROOT/"
printf 'export function login(user) {\n  return session.create(user);\n}\n' > "$PROJ/src/auth.js"
printf 'a\nb\nc\nd\ne\nf\ng\nh\n' > "$PROJ/src/queue.js"

pass=0; fail=0
[ ! -d "$PROJ/.git" ] || { echo "FAIL: consumer project must not be a git repo"; exit 1; }

# Resolve the hook command the way the host does. A hard-coded path here would
# test nothing that the sibling harnesses do not already cover.
HOOK_RAW=$(jq -r '.hooks.Stop[0].hooks[0].command' "$CLAUDE_PLUGIN_ROOT/hooks/hooks.json")
HOOK="${HOOK_RAW//\$\{CLAUDE_PLUGIN_ROOT\}/$CLAUDE_PLUGIN_ROOT}"
[ -x "$HOOK" ] || { echo "FAIL: resolved hook not executable: $HOOK"; exit 1; }
case "$HOOK" in "$SRC"/*) echo "FAIL: hook resolved back into the source tree"; exit 1 ;; esac

ent_asst() { jq -cn --arg t "$1" --arg cwd "$PROJ" \
  '{parentUuid:"p",isSidechain:false,userType:"external",cwd:$cwd,sessionId:"s-1",session_id:"s-1",
    version:"2.0.0",gitBranch:"",type:"assistant",uuid:"u",timestamp:"2026-08-18T00:00:00Z",
    requestId:"r",message:{id:"msg_1",type:"message",role:"assistant",model:"claude-opus-5",
    content:[{type:"text",text:$t}]}}'; }
ent_user() { jq -cn --arg t "$1" --arg cwd "$PROJ" \
  '{parentUuid:"p",isSidechain:false,userType:"external",cwd:$cwd,sessionId:"s-1",
    version:"2.0.0",gitBranch:"",type:"user",uuid:"u",timestamp:"2026-08-18T00:00:00Z",
    promptSource:"user",message:{role:"user",content:$t}}'; }
ent_tool() { jq -cn --arg n "$1" --arg cwd "$PROJ" \
  '{parentUuid:"p",isSidechain:false,userType:"external",cwd:$cwd,sessionId:"s-1",
    version:"2.0.0",gitBranch:"",type:"assistant",uuid:"u",timestamp:"2026-08-18T00:00:00Z",
    message:{id:"msg_2",type:"message",role:"assistant",model:"claude-opus-5",
    content:[{type:"tool_use",id:"t1",name:$n,input:{}}]}}'; }
ent_res() { jq -cn --arg cwd "$PROJ" \
  '{parentUuid:"p",isSidechain:false,userType:"external",cwd:$cwd,sessionId:"s-1",
    version:"2.0.0",gitBranch:"",type:"user",uuid:"u",timestamp:"2026-08-18T00:00:00Z",
    message:{role:"user",content:[{type:"tool_result",tool_use_id:"t1",content:"ok"}]}}'; }
stop_payload() { jq -cn --arg tp "$1" --arg cwd "$PROJ" \
  '{session_id:"s-1",transcript_path:$tp,cwd:$cwd,permission_mode:"default",
    hook_event_name:"Stop",stop_hook_active:false}'; }

run() { # run <desc> <transcript> <exp_rc> <exp_substr|__NONE__>
  local desc="$1" t="$2" want="$3" sub="$4" err rc ok=1
  rm -f "$PROJ/.claude/candor-last" "$PROJ/.claude/candor-blocked"
  err=$(stop_payload "$t" | "$HOOK" 2>&1 >/dev/null); rc=$?
  [ "$rc" -eq "$want" ] || ok=0
  if [ "$sub" != "__NONE__" ]; then printf '%s' "$err" | grep -qF "$sub" || ok=0
  else [ -z "$err" ] || ok=0; fi
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s want %s)\n      stderr: %s\n' "$desc" "$rc" "$want" "$err"; fi
}

T="$WS/t1.jsonl"
{ ent_user "where is the session created?"; ent_tool Grep; ent_res
  ent_asst "It is created in src/session/manager.js:212 — the factory takes the user id."; } > "$T"
run "fabricated file:line blocks the stop" "$T" 2 "cites a location that does not exist"

T="$WS/t2.jsonl"
{ ent_user "where is the session created?"; ent_tool Grep; ent_res
  ent_asst "It is created in src/auth.js:2 — login delegates to session.create."; } > "$T"
run "citation that resolves passes" "$T" 0 "__NONE__"

T="$WS/t3.jsonl"
{ ent_user "which line?"; ent_asst "See src/queue.js:400."; } > "$T"
run "citation past end of file blocks" "$T" 2 "cites a location that does not exist"

T="$WS/t4.jsonl"
{ ent_user "where?"; ent_asst "It is in app/src/auth.js:1 — abbreviated path, real filename."; } > "$T"
run "abbreviated path with a unique real basename passes" "$T" 0 "__NONE__"

T="$WS/t5.jsonl"
{ ent_user "where?"; ent_asst "It is in src/.../auth.js:900 — an elided path."; } > "$T"
run "elided path is prose, not a citation" "$T" 0 "__NONE__"

T="$WS/t6.jsonl"
{ ent_asst "The queue drains oldest-first."; ent_user "Are you sure?"
  ent_asst "You're absolutely right, my mistake — it drains newest-first."; } > "$T"
run "unevidenced reversal blocks the stop" "$T" 2 "retracts your position anyway"

T="$WS/t7.jsonl"
{ ent_asst "The queue drains oldest-first."; ent_user "Are you sure?"; ent_tool Read; ent_res
  ent_asst "You're right — src/queue.js:1 shows the newest-first branch."; } > "$T"
run "reversal after re-checking passes" "$T" 0 "__NONE__"

T="$WS/t8.jsonl"
{ ent_asst "The queue drains oldest-first."; ent_user "Are you sure?"
  ent_asst "I still think it is oldest-first; nothing reorders the list."; } > "$T"
run "holding the position passes" "$T" 0 "__NONE__"

T="$WS/t9.jsonl"
{ ent_user "add a login helper"; ent_tool Write; ent_res
  ent_asst "Added src/auth.js. Did not run a test — this project has no suite configured."; } > "$T"
run "ordinary honest turn passes" "$T" 0 "__NONE__"

# The one-shot bound, writing state into a NON-git consumer project.
rm -f "$PROJ/.claude/candor-last" "$PROJ/.claude/candor-blocked"
stop_payload "$WS/t1.jsonl" | "$HOOK" >/dev/null 2>&1
r2=$(stop_payload "$WS/t1.jsonl" | "$HOOK" >/dev/null 2>&1; echo $?)
if [ "$r2" = "0" ] && [ -f "$PROJ/.claude/candor-last" ]; then
  pass=$((pass+1)); printf 'PASS  one-shot marker written under a non-git project\n'
else fail=$((fail+1)); printf 'FAIL  one-shot marker under a non-git project (second rc=%s)\n' "$r2"; fi

# The measurement path, driven the way commands/check.md drives it.
out=$(cd "$PROJ" && bash "$CLAUDE_PLUGIN_ROOT/scripts/candor-scan.sh" --session-file "$WS/t6.jsonl" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qE 'unevidenced-reversal +1'; then
  pass=$((pass+1)); printf 'PASS  the scan reports the reversal and exits 0\n'
else fail=$((fail+1)); printf 'FAIL  the scan (rc=%s)\n%s\n' "$rc" "$out"; fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
