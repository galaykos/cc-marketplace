#!/usr/bin/env bash
# Harness for scripts/sources-check.sh and hooks/verify-return.sh. Load-bearing: a cited URL the agent never fetched
# blocks (exit 2, reason on stderr); a fetched one, a redirect target and a trailing-slash variant pass; other agent types
# and a third bad return pass through, so the gate cannot trap an agent.
set -u
here=$(cd "$(dirname "$0")" && pwd)
S="$here/../sources-check.sh"
H="$here/../../hooks/verify-return.sh"
[ -x "$S" ] && [ -x "$H" ] || { printf 'FAIL: scripts not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export TMPDIR="$T"
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

TR="$T/agent.jsonl"
{
  jq -cn '{type:"assistant", message:{content:[{type:"tool_use", id:"t1", name:"WebFetch", input:{url:"https://example.org/report/", prompt:"p"}}]}}'
  jq -cn '{type:"user", message:{content:[{type:"tool_result", tool_use_id:"t1", content:"page text"}]}}'
  jq -cn '{type:"assistant", message:{content:[{type:"tool_use", id:"t2", name:"WebFetch", input:{url:"http://old.example.com/a", prompt:"p"}}]}}'
  jq -cn '{type:"user", message:{content:[{type:"tool_result", tool_use_id:"t2", content:"REDIRECT DETECTED: The URL redirects to a different host. Redirect URL: https://new.example.com/a"}]}}'
  jq -cn '{type:"assistant", message:{content:[{type:"tool_use", id:"t3", name:"WebSearch", input:{query:"q"}}]}}'
  jq -cn '{type:"user", message:{content:[{type:"tool_result", tool_use_id:"t3", content:"https://searched.example.net/only-a-snippet"}]}}'
} > "$TR"

src() { printf '%s\n' "$1" | bash "$S" --transcript "$TR"; }
src "claim: x
  url: https://example.org/report" >/dev/null; [ $? = 0 ] && ok "fetched URL passes (trailing slash ignored)" || bad "fetched URL"
src "  url: https://new.example.com/a." >/dev/null; [ $? = 0 ] && ok "redirect target in the WebFetch result passes" || bad "redirect target"
out=$(src "  url: https://searched.example.net/only-a-snippet"); rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'not fetched this session: https://searched.example.net/only-a-snippet' && ok "a URL seen only in WebSearch results is not fetched" || bad "search-only URL (rc=$rc out=$out)"
src "no urls here" >/dev/null 2>&1; [ $? = 2 ] && ok "a return with no cited URL is a usage exit" || bad "no URL"

VERIFIER_OK='CLAIM: Product X shipped in 2026
VERDICT: confirmed
FETCH: https://example.org/report — retrieved 2026-11-07T10:00Z — "Product X shipped in March 2026"
CORROBORATION: https://new.example.com/a'
VERIFIER_UNFETCHED='CLAIM: Product X shipped in 2026
VERDICT: confirmed
FETCH: https://invented.example.com/page — retrieved 2026-11-07T10:00Z — "made up"
CORROBORATION: https://new.example.com/a'
VERIFIER_BADFORMAT='CLAIM: Product X shipped in 2026
VERDICT: confirmed
FETCH: https://example.org/report — retrieved 2026-11-07T10:00Z — "Product X shipped"
CORROBORATION: none found'

hook() { # <agent_type> <message> <agent_id>
  jq -cn --arg t "$1" --arg m "$2" --arg id "$3" --arg tp "$TR" \
    '{session_id:"s", transcript_path:"/x/main.jsonl", cwd:"/tmp", hook_event_name:"SubagentStop", stop_hook_active:false,
      agent_id:$id, agent_type:$t, agent_transcript_path:$tp, last_assistant_message:$m}' | bash "$H"
}
hook ultra-deep-research:verifier "$VERIFIER_OK" a1 2>/dev/null; [ $? = 0 ] && ok "a well-formed, fetched verdict stops" || bad "good verdict"
err=$(hook ultra-deep-research:verifier "$VERIFIER_UNFETCHED" a2 2>&1 >/dev/null); rc=$?
[ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'invented.example.com' && ok "an unfetched citation blocks with the URL on stderr" || bad "unfetched (rc=$rc err=$err)"
err=$(hook ultra-deep-research:verifier "$VERIFIER_BADFORMAT" a3 2>&1 >/dev/null); rc=$?
[ "$rc" = 2 ] && printf '%s' "$err" | grep -q 'verdict-lint' && ok "confirmed with no corroboration blocks via verdict-lint" || bad "verdict-lint (rc=$rc err=$err)"
hook ultra-deep-research:researcher "  url: https://invented.example.com/page" r1 2>/dev/null; [ $? = 2 ] && ok "a researcher citing an unfetched page blocks" || bad "researcher"
hook general-purpose "  url: https://invented.example.com/page" g1 2>/dev/null; [ $? = 0 ] && ok "other agent types pass through" || bad "other agent"
hook ultra-deep-research:verifier "$VERIFIER_UNFETCHED" a4 2>/dev/null
hook ultra-deep-research:verifier "$VERIFIER_UNFETCHED" a4 2>/dev/null
hook ultra-deep-research:verifier "$VERIFIER_UNFETCHED" a4 2>/dev/null; [ $? = 0 ] && ok "a third bad return from one agent is let through" || bad "bound"
out=$(printf 'not json' | bash "$H" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "malformed payload fails open" || bad "malformed (rc=$rc)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
