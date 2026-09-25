#!/usr/bin/env bash
# Author-time tests for the candor Stop gate.
#
# The hook reads the Stop payload's transcript_path (session JSONL) and blocks a
# turn on either of two clauses: a file:line citation that does not resolve, or a
# position retracted after bare pushback with nothing re-checked. These cases
# drive it with synthetic transcripts plus canned Stop-hook stdin and assert rc +
# stderr — including every fail-open, escape and mode the header promises.
#
# The payload carries transcript_path, not session_id: this hook's entire input is
# the transcript, and a harness that sent only session_id would grade a branch the
# host never takes (scripts/lib/plugin-checks.sh, pc_harness_payload).
set -u

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/candor/hooks/gate.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS="$(mktemp -d)"; trap 'rm -rf "$WS"' EXIT
# This session exports CLAUDE_PROJECT_DIR (the marketplace repo); cc_state_root would read
# it for a non-git cwd under it. In-flight records land under TMPDIR — kept in the sandbox.
unset CLAUDE_PROJECT_DIR
export TMPDIR="$WS/tmp"; mkdir -p "$TMPDIR"
PREAMBLE="$ROOT/plugins/candor/hooks/preamble.sh"
CWD="$WS/proj"; mkdir -p "$CWD/src" "$CWD/deep/nested"
MARKER="$CWD/.claude/candor/last"
CLAIMED="$CWD/.claude/candor/blocked"

# Real files the citations can resolve against.
printf 'a\nb\nc\nd\ne\n' > "$CWD/src/real.ts"           # 5 lines
printf 'x\ny\n'          > "$CWD/deep/nested/deep.ts"   # 2 lines

# Transcript builders: one JSONL line per entry.
asst()  { jq -cn --arg t "$1" '{type:"assistant",message:{content:[{type:"text",text:$t}]}}'; }
user()  { jq -cn --arg t "$1" '{type:"user",message:{content:$t}}'; }
tools() { jq -cn '$ARGS.positional | {type:"assistant",message:{content:[.[] | {type:"tool_use",name:.}]}}' --args "$@"; }
tres()  { jq -cn '{type:"user",message:{content:[{type:"tool_result",content:"ok"}]}}'; }

payload()        { jq -cn --arg tp "$1" --arg cwd "$CWD" '{transcript_path:$tp,cwd:$cwd,stop_hook_active:false}'; }
payload_active() { jq -cn --arg tp "$1" --arg cwd "$CWD" '{transcript_path:$tp,cwd:$cwd,stop_hook_active:true}'; }

check()      { rm -f "$MARKER" "$CLAIMED"; check_keep "$@"; }
check_keep() {
  local desc="$1" envv="$2" tfile="$3" exp_rc="$4" exp_sub="$5" err rc ok=1
  err=$(payload "$tfile" | env $envv bash "$HOOK" 2>&1 >/dev/null); rc=$?
  [ "$rc" -eq "$exp_rc" ] || ok=0
  if [ "$exp_sub" != "__NONE__" ]; then
    printf '%s' "$err" | grep -qF "$exp_sub" || ok=0
  else
    [ -z "$err" ] || ok=0
  fi
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s want %s; stderr=%s)\n' "$desc" "$rc" "$exp_rc" "$err"; fi
}

CITE_SUB='cites a location that does not exist'
REV_SUB='retracts your position anyway'

# ---------------------------------------------------------------------------
# CLAUSE 1 — citations
# ---------------------------------------------------------------------------
T="$WS/c1.jsonl"; { user "where is the bug"; asst "The bug is at src/ghost.ts:12 — fix it there."; } > "$T"
check "nonexistent file:line blocks"                  "" "$T" 2 "$CITE_SUB"
check_keep "same message re-stop passes (one-shot)"   "" "$T" 0 "__NONE__"

T="$WS/c2.jsonl"; { user "where"; asst "See src/real.ts:3 for the guard."; } > "$T"
check "resolving citation passes"                     "" "$T" 0 "__NONE__"

T="$WS/c3.jsonl"; { user "where"; asst "See src/real.ts:900 for the guard."; } > "$T"
check "citation past EOF blocks"                      "" "$T" 2 "$CITE_SUB"

# 0.3.2: the block above created the state dir; it must carry a self-ignoring
# .gitignore so the markers never appear in the user's `git status`.
if [ "$(cat "$CWD/.claude/candor/.gitignore" 2>/dev/null)" = "*" ]; then pass=$((pass+1)); printf 'PASS  state dir ignores itself\n'
else fail=$((fail+1)); printf 'FAIL  state dir ignores itself (.claude/candor/.gitignore missing or not "*")\n'; fi

# 0.3.2: a `~/` citation is a real location in the user's home, not the absolute
# path `/.claude/...` the old extraction class made of it. HOME is pointed at a
# scratch dir so the case is hermetic either way.
FAKEHOME="$WS/home"; mkdir -p "$FAKEHOME/.claude"; printf '{\n  "model": "x"\n}\n' > "$FAKEHOME/.claude/settings.json"
T="$WS/c3b.jsonl"; { user "where is my model set"; asst "Your model is set in ~/.claude/settings.json:2."; } > "$T"
check "~/ citation into a real home file passes"     "HOME=$FAKEHOME" "$T" 0 "__NONE__"
T="$WS/c3c.jsonl"; { user "where"; asst "See ~/.claude/settings.json:40 for it."; } > "$T"
check "~/ citation past EOF blocks"                   "HOME=$FAKEHOME" "$T" 2 "$CITE_SUB"
T="$WS/c3d.jsonl"; { user "where"; asst "See ~/nowhere/ghost.py:3 for it."; } > "$T"
check "~/ citation into a missing file blocks"        "HOME=$FAKEHOME" "$T" 2 "$CITE_SUB"

T="$WS/c4.jsonl"; { user "where"; asst "See src/real.ts:6 — the last line."; } > "$T"
check "one line past wc -l tolerated (no trailing newline)" "" "$T" 0 "__NONE__"

T="$WS/c5.jsonl"; { user "where"; asst "Fetch https://example.com/index.php:80 for the port demo."; } > "$T"
check "URL with a port is not a citation"             "" "$T" 0 "__NONE__"

T="$WS/c6.jsonl"; { user "where"; asst "The service listens on example.com:8080 in staging."; } > "$T"
check "host:port is not a citation"                   "" "$T" 0 "__NONE__"

T="$WS/c7.jsonl"; { user "where"; asst "Create src/ghost.ts and put the handler there."; } > "$T"
check "bare nonexistent path (no line) passes"        "" "$T" 0 "__NONE__"

T="$WS/c8.jsonl"; { asst "It is at src/ghost.ts:12."; user "and now"; asst "All set."; } > "$T"
check "stale citation in an EARLIER message does not bleed" "" "$T" 0 "__NONE__"

T="$WS/c9.jsonl"; { user "where"; asst "See nested/deep.ts:2 — cited from a subdirectory."; } > "$T"
check "subdirectory-relative citation resolves"       "" "$T" 0 "__NONE__"

T="$WS/c10.jsonl"; { user "where"; asst "See $CWD/src/real.ts:2 for it."; } > "$T"
check "absolute path citation resolves"               "" "$T" 0 "__NONE__"

T="$WS/c11.jsonl"; { user "when"; asst "The job ran at 10:30 and took v1.2.3:4 seconds."; } > "$T"
check "clock times and version strings are not citations" "" "$T" 0 "__NONE__"

# The resolver ladder. Measured on 47 real transcripts, an abbreviated path is far
# more common than an invented one, so only a basename that exists NOWHERE blocks.
T="$WS/c12.jsonl"; { user "where"; asst "See src/wrong/dir/deep.ts:1 — abbreviated path, real filename."; } > "$T"
check "unique basename under a wrong directory resolves" "" "$T" 0 "__NONE__"

T="$WS/c13.jsonl"; { user "where"; asst "See src/wrong/dir/deep.ts:99 — line past the resolved file."; } > "$T"
check "wrong-directory path still line-checked once unique" "" "$T" 2 "$CITE_SUB"

printf 'q\n' > "$CWD/src/dup.ts"; printf 'q\n' > "$CWD/deep/dup.ts"
T="$WS/c14.jsonl"; { user "where"; asst "See lib/elsewhere/dup.ts:400 — ambiguous basename."; } > "$T"
check "ambiguous basename is not decidable, passes"  "" "$T" 0 "__NONE__"

T="$WS/c15.jsonl"; { user "where"; asst "See plugins/x/.../real.ts:900 — an elided path."; } > "$T"
check "elided path (...) is prose, not a citation"   "" "$T" 0 "__NONE__"

T="$WS/c16.jsonl"; { user "where"; asst "See src/ghost.ts:12 — invented filename."; } > "$T"
check "invented basename blocks with the name in the reason" "" "$T" 2 "no file named ghost.ts exists anywhere"

# ---------------------------------------------------------------------------
# CLAUSE 2 — unevidenced reversal
# ---------------------------------------------------------------------------
T="$WS/r1.jsonl"; { asst "The retry is disabled."; user "Are you sure?"; asst "You're absolutely right, my mistake — it is enabled."; } > "$T"
check "bare pushback + retraction + no tool blocks"   "" "$T" 2 "$REV_SUB"
check_keep "same reversal re-stop passes (one-shot)"  "" "$T" 0 "__NONE__"

T="$WS/r2.jsonl"; { asst "The retry is disabled."; user "Are you sure?"; tools Bash; tres; asst "You're right — the setting is on."; } > "$T"
check "a tool call after the pushback passes"         "" "$T" 0 "__NONE__"

T="$WS/r3.jsonl"; { asst "It is disabled."; user "No, it is set in config/queue.php"; asst "You're right, my mistake."; } > "$T"
check "pushback carrying a path disarms the clause"   "" "$T" 0 "__NONE__"

T="$WS/r4.jsonl"; { asst "It is disabled."; user 'Are you sure? `retry_after` is right there.'; asst "You're right, apologies."; } > "$T"
check "pushback carrying a backtick disarms"          "" "$T" 0 "__NONE__"

LONG="Are you sure about that? I have been staring at this for an hour and my reading of the situation is that the worker does in fact retry, because the supervisor restarts it on a non-zero exit and the job is not marked failed until the attempt counter is exhausted, which is a completely different mechanism from what you described and I would like you to reconcile the two before we go any further with this."
T="$WS/r5.jsonl"; { asst "It is disabled."; user "$LONG"; asst "You're right, I was wrong."; } > "$T"
check "long argued pushback disarms (>400 chars)"     "" "$T" 0 "__NONE__"

T="$WS/r6.jsonl"; { asst "It is disabled."; user "Are you sure?"; asst "I re-read the settings — you're right, it is on."; } > "$T"
check "stated basis (re-read) passes"                 "" "$T" 0 "__NONE__"

T="$WS/r7.jsonl"; { asst "It is disabled."; user "Are you sure?"; asst "I still think it is disabled; the flag defaults to false."; } > "$T"
check "holding the position passes"                   "" "$T" 0 "__NONE__"

T="$WS/r8.jsonl"; { user "add a test"; asst "You're right that a test helps — added."; } > "$T"
check "retraction language without pushback passes"   "" "$T" 0 "__NONE__"

T="$WS/r9.jsonl"; { asst "Deleting the branch now."; user "No, don't do that."; asst "Understood — leaving it in place."; } > "$T"
check "an instruction (not a challenge) passes"       "" "$T" 0 "__NONE__"

# Clause priority: a turn that trips both reports the citation.
T="$WS/p1.jsonl"; { asst "It is fine."; user "Are you sure?"; asst "You're right, my mistake — see src/ghost.ts:9."; } > "$T"
check "citation clause reported first when both trip" "" "$T" 2 "$CITE_SUB"

# ---------------------------------------------------------------------------
# Modes and fail-open
# ---------------------------------------------------------------------------
T="$WS/m1.jsonl"; { user "where"; asst "The bug is at src/ghost.ts:12."; } > "$T"
check "warn mode prints but does not block" "CC_CANDOR_GATE=warn" "$T" 0 "$CITE_SUB"
check "off mode is silent"                  "CC_CANDOR_GATE=off"  "$T" 0 "__NONE__"

check "missing transcript fails open"       "" "$WS/does-not-exist.jsonl" 0 "__NONE__"

T="$WS/f1.jsonl"; : > "$T"
check "empty transcript fails open"         "" "$T" 0 "__NONE__"

T="$WS/f2.jsonl"; printf 'not json at all\n' > "$T"
check "malformed transcript fails open"     "" "$T" 0 "__NONE__"

T="$WS/f3.jsonl"; { tools Read; } > "$T"
check "no assistant prose fails open"       "" "$T" 0 "__NONE__"

# Namespaced disarm: this gate's OWN continuation releases the turn; a sibling
# gate's block (shared flag set, no record of ours) does not.
T="$WS/d1.jsonl"; { user "where"; asst "The bug is at src/ghost.ts:12."; } > "$T"
rm -f "$MARKER" "$CLAIMED"
payload "$T" | bash "$HOOK" >/dev/null 2>&1
if [ -f "$CLAIMED" ]; then pass=$((pass+1)); printf 'PASS  block writes the namespaced record\n'
else fail=$((fail+1)); printf 'FAIL  block writes the namespaced record\n'; fi
payload_active "$T" | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$CLAIMED" ]; then pass=$((pass+1)); printf 'PASS  own continuation releases and clears the record\n'
else fail=$((fail+1)); printf 'FAIL  own continuation releases and clears the record (rc=%s)\n' "$rc"; fi
rm -f "$MARKER" "$CLAIMED"
payload_active "$T" | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 2 ]; then pass=$((pass+1)); printf 'PASS  sibling block does not disarm this gate\n'
else fail=$((fail+1)); printf 'FAIL  sibling block does not disarm this gate (rc=%s)\n' "$rc"; fi

# ---------------------------------------------------------------------------
# SubagentStop — the same gate over a subagent's final report (payload shape
# measured live on 2.1.267: agent_id, agent_type, agent_transcript_path,
# last_assistant_message, stop_hook_active, plus the PARENT transcript_path).
# ---------------------------------------------------------------------------
sub_payload() { # agent-transcript  last-msg  [stop_hook_active]
  jq -cn --arg tp "$WS/parent.jsonl" --arg atp "$1" --arg m "$2" --arg cwd "$CWD" --argjson a "${3:-false}" \
    '{hook_event_name:"SubagentStop",transcript_path:$tp,agent_transcript_path:$atp,agent_id:"aac4725192b90da07",agent_type:"Explore",last_assistant_message:$m,cwd:$cwd,stop_hook_active:$a}'
}
{ user "main thread prompt"; } > "$WS/parent.jsonl"
A="$WS/agent.jsonl"; { user "find the bug"; asst "placeholder"; } > "$A"
SUB_MARKER="$CWD/.claude/candor/last-$(printf '%s' aac4725192b90da07 | cksum | cut -d' ' -f1)"
SUB_CLAIMED="$CWD/.claude/candor/blocked-$(printf '%s' aac4725192b90da07 | cksum | cut -d' ' -f1)"
sub_check() { # desc  last-msg  exp_rc  exp_sub
  local desc="$1" msg="$2" exp_rc="$3" exp_sub="$4" err rc ok=1
  rm -f "$MARKER" "$CLAIMED" "$SUB_MARKER" "$SUB_CLAIMED"
  err=$(sub_payload "$A" "$msg" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  [ "$rc" -eq "$exp_rc" ] || ok=0
  if [ "$exp_sub" != "__NONE__" ]; then printf '%s' "$err" | grep -qF "$exp_sub" || ok=0; else [ -z "$err" ] || ok=0; fi
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$desc"
  else fail=$((fail+1)); printf 'FAIL  %s (rc=%s want %s; stderr=%s)\n' "$desc" "$rc" "$exp_rc" "$err"; fi
}
sub_check "subagent: fabricated citation in last_assistant_message blocks" "Found it at src/ghost.ts:12." 2 "this report cites a location that does not exist"
sub_check "subagent: resolving citation passes"                            "Found it at src/real.ts:3."   0 "__NONE__"
sub_check "subagent: reversal clause disarmed (no user turn to push back)" "You're right, my mistake."   0 "__NONE__"
# last_assistant_message wins over the transcript: the transcript says src/real.ts:3 (clean) but the payload text fabricates.
{ user "find the bug"; asst "See src/real.ts:3."; } > "$A"
sub_check "subagent: payload text is judged, not the transcript tail"      "Found it at src/ghost.ts:12." 2 "this report"
# Markers are per agent: a subagent block must not consume the main thread's disarm, and vice versa.
rm -f "$MARKER" "$CLAIMED" "$SUB_MARKER" "$SUB_CLAIMED"
sub_payload "$A" "Found it at src/ghost.ts:12." | bash "$HOOK" >/dev/null 2>&1
if [ -f "$SUB_CLAIMED" ] && [ ! -f "$CLAIMED" ]; then pass=$((pass+1)); printf 'PASS  subagent block writes its own claim, not the main thread'"'"'s\n'
else fail=$((fail+1)); printf 'FAIL  subagent block writes its own claim (sub=%s main=%s)\n' "$([ -f "$SUB_CLAIMED" ] && echo y || echo n)" "$([ -f "$CLAIMED" ] && echo y || echo n)"; fi
sub_payload "$A" "Found it at src/ghost.ts:12." true | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ] && [ ! -f "$SUB_CLAIMED" ]; then pass=$((pass+1)); printf 'PASS  subagent continuation releases its own record\n'
else fail=$((fail+1)); printf 'FAIL  subagent continuation releases its own record (rc=%s)\n' "$rc"; fi
rm -f "$MARKER" "$CLAIMED" "$SUB_MARKER" "$SUB_CLAIMED"
sub_payload "$A" "Found it at src/ghost.ts:12." | bash "$HOOK" >/dev/null 2>&1
sub_payload "$A" "Found it at src/ghost.ts:12." | bash "$HOOK" >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  subagent: same report re-stop passes (one-shot)\n'
else fail=$((fail+1)); printf 'FAIL  subagent: same report re-stop passes (rc=%s)\n' "$rc"; fi


# ---------------------------------------------------------------------------
# CLAUSE INDEPENDENCE — a bounded clause 4 does not silence clauses 1-3
# ---------------------------------------------------------------------------
# On master these were three Stop hooks, each evaluated on every stop. The 0.3.0
# merge let clause 4 (a registered run with no gate pass) take the only verdict
# slot and exit 0 on its per-HEAD bound, so from the second stop at a HEAD until
# the next commit an invented citation or a naked completion claim passed. A live
# run is exactly where those happen. These cases pin: clause 4 blocks first and
# alone; once bounded (or in warn mode) it prints and the other clauses still bite.
if command -v git >/dev/null 2>&1; then
  rm -f "$MARKER" "$CLAIMED"
  git -C "$CWD" init -q && git -C "$CWD" config user.email t@t.t && git -C "$CWD" config user.name t
  git -C "$CWD" add -A >/dev/null 2>&1 && git -C "$CWD" commit -qm init
  SENT="$CWD/.claude/task-runner/active-run.json"; NUDGE="$CWD/.claude/task-runner/gate-nudge"
  mkdir -p "$CWD/.claude/task-runner"; printf '{"slug":"t"}' > "$SENT"
  touch -t 200001010000 "$SENT"                   # registration precedes every stop below
  RUN_SUB='registered run with no behavioral-gate pass'

  T="$WS/c4a.jsonl"; { user "fix it"; asst "Fixed at src/ghost.ts:12."; } > "$T"
  err=$(payload "$T" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$RUN_SUB" && ! printf '%s' "$err" | grep -qF "$CITE_SUB" && [ -r "$NUDGE" ]; then
    pass=$((pass+1)); printf 'PASS  live run: clause 4 blocks first and alone, writes the nudge\n'
  else fail=$((fail+1)); printf 'FAIL  live run: clause 4 blocks first and alone (rc=%s nudge=%s stderr=%s)\n' "$rc" "$([ -r "$NUDGE" ] && echo y || echo n)" "$err"; fi

  err=$(payload_active "$T" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$RUN_SUB" && printf '%s' "$err" | grep -qF "$CITE_SUB"; then
    pass=$((pass+1)); printf 'PASS  bounded clause 4 prints, clause 1 still blocks the invented citation (continuation)\n'
  else fail=$((fail+1)); printf 'FAIL  bounded clause 4 + clause 1 on continuation (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  rm -f "$MARKER" "$CLAIMED"
  err=$(payload "$T" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$CITE_SUB"; then
    pass=$((pass+1)); printf 'PASS  bounded clause 4, fresh stop: clause 1 still blocks\n'
  else fail=$((fail+1)); printf 'FAIL  bounded clause 4, fresh stop: clause 1 (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  T="$WS/c4b.jsonl"; { user "fix it"; asst "Fixed at src/real.ts:3."; } > "$T"
  rm -f "$MARKER" "$CLAIMED"
  err=$(payload "$T" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$err" | grep -qF "$RUN_SUB"; then
    pass=$((pass+1)); printf 'PASS  bounded clause 4 with a clean turn: print-only exit 0\n'
  else fail=$((fail+1)); printf 'FAIL  bounded clause 4 with a clean turn (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  T="$WS/c4c.jsonl"; { user "fix it"; tools Edit; tres; asst "Done — implemented and verified."; } > "$T"
  rm -f "$MARKER" "$CLAIMED"
  err=$(payload "$T" | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'claims completion'; then
    pass=$((pass+1)); printf 'PASS  bounded clause 4: clause 3 still blocks a naked completion claim\n'
  else fail=$((fail+1)); printf 'FAIL  bounded clause 4 + clause 3 (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  T="$WS/c4a.jsonl"; rm -f "$MARKER" "$CLAIMED" "$NUDGE"
  err=$(payload "$T" | TASK_RUNNER_STOP_GATE=warn bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$RUN_SUB" && printf '%s' "$err" | grep -qF "$CITE_SUB" && [ ! -e "$NUDGE" ]; then
    pass=$((pass+1)); printf 'PASS  clause 4 in warn mode prints, writes no nudge, clause 1 still blocks\n'
  else fail=$((fail+1)); printf 'FAIL  clause 4 warn + clause 1 (rc=%s nudge=%s stderr=%s)\n' "$rc" "$([ -e "$NUDGE" ] && echo y || echo n)" "$err"; fi

  rm -f "$SENT" "$NUDGE" "$MARKER" "$CLAIMED"
else
  printf 'SKIP  clause-independence cases (git not available)\n'
fi

# ---------------------------------------------------------------------------
# CLAUSE 5 — lockfile drift. Needs a real git worktree: the clause reads
# `git status --porcelain` and `git diff -U0` on the manifest, so a fixture that
# faked either would grade a branch the hook never takes.
# ---------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
  LW="$WS/lockproj"; mkdir -p "$LW"
  ( cd "$LW" && git init -q . && git config user.email t@t && git config user.name t \
    && printf '{"name":"x","dependencies":{"a":"^1.0.0"}}\n' > package.json \
    && printf '{"lockfileVersion":3}\n' > package-lock.json \
    && git add -A && git commit -qm init ) >/dev/null 2>&1

  lock_payload() { jq -cn --arg cwd "$LW" '{transcript_path:"/nonexistent",cwd:$cwd,stop_hook_active:false}'; }
  clear_lock_state() { rm -rf "$LW/.claude/candor"; }

  ( cd "$LW" && printf '{"name":"x","dependencies":{"a":"^1.0.0","b":"^2.0.0"}}\n' > package.json )
  clear_lock_state
  err=$(lock_payload | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'lockfile did not'; then
    pass=$((pass+1)); printf 'PASS  clause 5: a dependency added with no lockfile change blocks\n'
  else fail=$((fail+1)); printf 'FAIL  clause 5 blocks on drift (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  ( cd "$LW" && printf '{"lockfileVersion":3,"packages":{}}\n' > package-lock.json )
  clear_lock_state
  err=$(lock_payload | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$err" ]; then
    pass=$((pass+1)); printf 'PASS  clause 5: manifest AND lockfile changed together is silent\n'
  else fail=$((fail+1)); printf 'FAIL  clause 5 silent on a matched pair (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  ( cd "$LW" && git checkout -q -- . && printf '{"name":"x","version":"2.0.0","dependencies":{"a":"^1.0.0"}}\n' > package.json )
  clear_lock_state
  err=$(lock_payload | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$err" ]; then
    pass=$((pass+1)); printf 'PASS  clause 5: a version bump is not a dependency change\n'
  else fail=$((fail+1)); printf 'FAIL  clause 5 silent on a version-only edit (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  ( cd "$LW" && git checkout -q -- . && printf '{"name":"x","dependencies":{"a":"^1.0.0","c":"^3.0.0"}}\n' > package.json )
  clear_lock_state
  err=$(lock_payload | CC_LOCKFILE_GATE=off bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$err" ]; then
    pass=$((pass+1)); printf 'PASS  clause 5: CC_LOCKFILE_GATE=off silences it\n'
  else fail=$((fail+1)); printf 'FAIL  clause 5 off switch (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  err=$(jq -cn --arg cwd "$LW" '{agent_transcript_path:"/nonexistent",cwd:$cwd,hook_event_name:"SubagentStop",last_assistant_message:"done"}' \
        | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 0 ]; then
    pass=$((pass+1)); printf 'PASS  clause 5: disarmed for a subagent (no user turn to answer it)\n'
  else fail=$((fail+1)); printf 'FAIL  clause 5 subagent disarm (rc=%s stderr=%s)\n' "$rc" "$err"; fi

  # 0.5.0 state root: porcelain paths are repo-relative, so a stop taken from a
  # subdirectory used to read `sub/package.json`, find nothing and pass silently.
  mkdir -p "$LW/sub/dir"
  ( cd "$LW" && printf '{"name":"x","dependencies":{"a":"^1.0.0","d":"^4.0.0"}}\n' > package.json )
  clear_lock_state
  err=$(jq -cn --arg cwd "$LW/sub/dir" '{transcript_path:"/nonexistent",cwd:$cwd,stop_hook_active:false}' | bash "$HOOK" 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'lockfile did not' && [ ! -e "$LW/sub/dir/.claude" ] && [ -f "$LW/.claude/candor/last" ]; then
    pass=$((pass+1)); printf 'PASS  clause 5: a stop from a subdirectory reads the manifest at the repo root, state at the root\n'
  else fail=$((fail+1)); printf 'FAIL  clause 5 from a subdirectory (rc=%s subdir-state=%s stderr=%s)\n' "$rc" "$([ -e "$LW/sub/dir/.claude" ] && echo y || echo n)" "$err"; fi

  ( cd "$LW" && git checkout -q -- . )
else
  printf 'SKIP  clause 5 cases (git not available)\n'
fi

# ---------------------------------------------------------------------------
# 0.5.0 — state root, in-flight workers, the no-behavioral-coverage exit.
# One throwaway repo, driven through the real hooks: preamble.sh writes the in-flight
# record on SubagentStart, gate.sh removes it on SubagentStop and reads it on Stop.
# ---------------------------------------------------------------------------
if command -v git >/dev/null 2>&1; then
  RR="$WS/run"; mkdir -p "$RR/src/deep"
  printf 'a\nb\nc\nd\n' > "$RR/src/real.ts"
  git -C "$RR" init -q && git -C "$RR" config user.email t@t.t && git -C "$RR" config user.name t
  git -C "$RR" add -A >/dev/null 2>&1 && git -C "$RR" commit -qm init
  SUBD="$RR/src/deep"
  RHEAD=$(git -C "$RR" rev-parse HEAD); H12=${RHEAD:0:12}
  TRD="$RR/.claude/task-runner"; RSENT="$TRD/active-run.json"; RNUDGE="$TRD/gate-nudge"
  SID="sess-0-5-0"
  IDIR="$TMPDIR/cc-candor-inflight-$(printf '%s' "$SID" | cksum | cut -d' ' -f1)"
  rec_of() { printf '%s/%s' "$IDIR" "$(printf '%s' "$1" | cksum | cut -d' ' -f1)"; }
  RUN_SUB='registered run with no behavioral-gate pass'
  WAIT_SUB='still in flight'

  # stop_json <cwd> <transcript> [background_tasks-json] — the Stop payload as the host sends it
  stop_json() {
    if [ -n "${3:-}" ]; then
      jq -cn --arg cwd "$1" --arg tp "$2" --arg sid "$SID" --argjson bt "$3" \
        '{hook_event_name:"Stop",session_id:$sid,transcript_path:$tp,cwd:$cwd,stop_hook_active:false,background_tasks:$bt}'
    else
      jq -cn --arg cwd "$1" --arg tp "$2" --arg sid "$SID" \
        '{hook_event_name:"Stop",session_id:$sid,transcript_path:$tp,cwd:$cwd,stop_hook_active:false}'
    fi
  }
  start_json() { jq -cn --arg cwd "$RR" --arg sid "$SID" --arg a "$1" --arg tp "$WS/rparent.jsonl" \
    '{hook_event_name:"SubagentStart",session_id:$sid,transcript_path:$tp,cwd:$cwd,agent_id:$a,agent_type:"general-purpose"}'; }
  substop_json() { jq -cn --arg cwd "$RR" --arg sid "$SID" --arg a "$1" --arg m "$2" --arg tp "$WS/rparent.jsonl" --arg atp "$WS/ragent.jsonl" \
    '{hook_event_name:"SubagentStop",session_id:$sid,transcript_path:$tp,agent_transcript_path:$atp,cwd:$cwd,agent_id:$a,agent_type:"general-purpose",last_assistant_message:$m,stop_hook_active:false}'; }
  # run_hook <hook> <json> [env] — sets rc and err
  run_hook() { err=$(printf '%s' "$2" | env ${3:-} bash "$1" 2>&1 >/dev/null); rc=$?; }
  verdict_is() { # desc  condition-exit-status
    if [ "$2" -eq 0 ]; then pass=$((pass+1)); printf 'PASS  %s\n' "$1"
    else fail=$((fail+1)); printf 'FAIL  %s (rc=%s stderr=%s)\n' "$1" "$rc" "$err"; fi
  }
  clear_rr() { rm -rf "$RR/.claude/candor" "$RNUDGE"; }

  CLEAN="$WS/rclean.jsonl"; { user "run the cards"; asst "Waiting on the workers."; } > "$CLEAN"
  { user "run the cards"; } > "$WS/rparent.jsonl"
  { user "card 01"; asst "placeholder"; } > "$WS/ragent.jsonl"

  # --- state root: a subdirectory cwd reads and writes at the repo root -----------------
  T="$WS/rsub1.jsonl"; { user "where"; asst "The guard is at src/real.ts:3."; } > "$T"
  clear_rr; run_hook "$HOOK" "$(stop_json "$SUBD" "$T")"
  verdict_is "state root: a repo-relative citation resolves from a subdirectory cwd" "$([ "$rc" -eq 0 ] && [ -z "$err" ]; echo $?)"
  T="$WS/rsub2.jsonl"; { user "where"; asst "The guard is at src/ghost.ts:3."; } > "$T"
  clear_rr; run_hook "$HOOK" "$(stop_json "$SUBD" "$T")"
  verdict_is "state root: a block from a subdirectory writes its marker at the repo root, none in the subdir" \
    "$([ "$rc" -eq 2 ] && [ -f "$RR/.claude/candor/last" ] && [ ! -e "$SUBD/.claude" ]; echo $?)"

  mkdir -p "$TRD"; printf '{"slug":"t"}' > "$RSENT"; touch -t 200001010000 "$RSENT"
  clear_rr; run_hook "$HOOK" "$(stop_json "$SUBD" "$CLEAN")"
  verdict_is "state root: a subdirectory cwd reads the run registered at the repo root" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$RUN_SUB" && [ -r "$RNUDGE" ] && [ ! -e "$SUBD/.claude" ]; echo $?)"

  # --- in-flight workers -----------------------------------------------------------------
  rm -rf "$IDIR"
  run_hook "$PREAMBLE" "$(start_json agentA)"
  verdict_is "in flight: SubagentStart writes a record holding the agent_id" \
    "$([ "$(cat "$(rec_of agentA)" 2>/dev/null)" = agentA ]; echo $?)"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$CLEAN")"
  verdict_is "in flight: a fresh record suppresses the no-gate-pass block, prints, writes no nudge" \
    "$([ "$rc" -eq 0 ] && printf '%s' "$err" | grep -qF "$WAIT_SUB" && ! printf '%s' "$err" | grep -qF "$RUN_SUB" && [ ! -e "$RNUDGE" ]; echo $?)"
  run_hook "$HOOK" "$(substop_json agentA "Card 01 done; the tests ran green.")"
  verdict_is "in flight: SubagentStart then SubagentStop leaves no record" \
    "$([ "$rc" -eq 0 ] && [ -z "$(ls -A "$IDIR" 2>/dev/null)" ]; echo $?)"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$CLEAN")"
  verdict_is "in flight: after the last hand-back the no-gate-pass block is back" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$RUN_SUB"; echo $?)"

  run_hook "$PREAMBLE" "$(start_json agentOld)"; touch -t 200001010000 "$(rec_of agentOld)"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$CLEAN")"
  verdict_is "in flight: an expired record (>180 min) does not suppress the block, and is swept" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$RUN_SUB" && [ ! -e "$(rec_of agentOld)" ]; echo $?)"

  run_hook "$PREAMBLE" "$(start_json agentOff)" "CC_PREAMBLE=off"
  verdict_is "in flight: CC_PREAMBLE=off silences the text, not the record" \
    "$([ -z "$(printf '%s' "$err")" ] && [ -f "$(rec_of agentOff)" ]; echo $?)"
  run_hook "$HOOK" "$(substop_json agentOff "Found it at src/ghost.ts:12.")"
  verdict_is "in flight: a SubagentStop the gate BLOCKS keeps the record (the agent keeps running)" \
    "$([ "$rc" -eq 2 ] && [ -f "$(rec_of agentOff)" ]; echo $?)"
  run_hook "$HOOK" "$(substop_json agentOff "Found it at src/real.ts:3.")"
  verdict_is "in flight: its clean SubagentStop then removes it" "$([ "$rc" -eq 0 ] && [ ! -e "$(rec_of agentOff)" ]; echo $?)"

  # The host's list, probed on CLI 2.1.282, wins whenever the payload carries it.
  BT_RUNNING='[{"id":"a176b79786a57ef62","type":"subagent","status":"running","description":"card 02","agent_type":"general-purpose"}]'
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$CLEAN" "$BT_RUNNING")"
  verdict_is "in flight: background_tasks listing a running subagent suppresses the block with no record" \
    "$([ "$rc" -eq 0 ] && printf '%s' "$err" | grep -qF "$WAIT_SUB"; echo $?)"
  run_hook "$PREAMBLE" "$(start_json agentKilled)"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$CLEAN" '[{"id":"b1","type":"shell","status":"running","command":"sleep 9"}]')"
  verdict_is "in flight: a present background_tasks with no worker outranks a stale record (killed agent)" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "$RUN_SUB"; echo $?)"
  rm -f "$(rec_of agentKilled)"

  # Only the no-gate-pass branch stands down: a claimed pass short of its records still blocks.
  mkdir -p "$TRD/bg"
  printf '{"head":"%s","cards_total":1,"cards_done":1,"cards_parked":0}' "$RHEAD" > "$TRD/gate-pass.json"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$CLEAN" "$BT_RUNNING")"
  verdict_is "in flight: a claimed pass with no bg verdict record still blocks" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'left no verdict record'; echo $?)"

  # --- no-behavioral-coverage + a recorded coverage reduction -------------------------------
  printf '{"head":"%s","verdict":"no-behavioral-coverage"}' "$RHEAD" > "$TRD/bg/bg-$RHEAD.json"
  COVRED="$TRD/reductions/coverage-bg-$H12.json"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$CLEAN")"
  verdict_is "coverage: no-behavioral-coverage without a reduction blocks and names the reduction command" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'reached "no-behavioral-coverage"' && printf '%s' "$err" | grep -qF "reduction-record.sh --kind coverage --id bg-$H12"; echo $?)"
  RS="$ROOT/plugins/task-runner/scripts/reduction-record.sh"
  if [ -r "$RS" ]; then
    # The real writer, run from a subdirectory: it must land the file this gate reads.
    ( cd "$SUBD" && bash "$RS" --kind coverage --id "bg-$H12" --reason "no JS runner in this project" ) >/dev/null 2>&1
  else
    printf 'SKIP  reduction-record.sh not in this checkout; writing its record shape by hand\n'
    mkdir -p "$TRD/reductions"
    printf '{"kind":"coverage","id":"bg-%s","reduced":true,"reason":"no JS runner"}\n' "$H12" > "$COVRED"
  fi
  verdict_is "coverage: reduction-record.sh --kind coverage --id bg-<HEAD12> writes the file the gate reads" "$([ -f "$COVRED" ]; echo $?)"
  T="$WS/rhide.jsonl"; { user "run the cards"; asst "All cards done, gate recorded."; } > "$T"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$T")"
  verdict_is "coverage: a matching reduction the closing report never names still blocks (disclosure)" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF "never names" && printf '%s' "$err" | grep -qF "bg-$H12"; echo $?)"
  T="$WS/rshow.jsonl"; { user "run the cards"; asst "Cards done. Reduced: bg-$H12 — no JS runner in this project covers the changed React files."; } > "$T"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$T")"
  verdict_is "coverage: no-behavioral-coverage + matching reduction + report naming it -> allow" \
    "$([ "$rc" -eq 0 ] && [ -z "$err" ]; echo $?)"
  touch -t 199901010000 "$COVRED"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$T")"
  verdict_is "coverage: a reduction older than the run's registration does not count" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'reached "no-behavioral-coverage"'; echo $?)"
  touch "$COVRED"
  printf '{"head":"%s","verdict":"unverifiable-suite"}' "$RHEAD" > "$TRD/bg/bg-$RHEAD.json"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$T")"
  verdict_is "coverage: unverifiable-suite plus a coverage reduction still blocks" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'reached "unverifiable-suite"'; echo $?)"
  printf '{"head":"%s","verdict":"empty-suite"}' "$RHEAD" > "$TRD/bg/bg-$RHEAD.json"
  clear_rr; run_hook "$HOOK" "$(stop_json "$RR" "$T")"
  verdict_is "coverage: empty-suite plus a coverage reduction still blocks" \
    "$([ "$rc" -eq 2 ] && printf '%s' "$err" | grep -qF 'reached "empty-suite"'; echo $?)"
else
  printf 'SKIP  0.5.0 state-root / in-flight / coverage cases (git not available)\n'
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
