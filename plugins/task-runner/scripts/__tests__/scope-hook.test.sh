#!/usr/bin/env bash
# Tests for scope.sh (PostToolUse scope-lock tripwire).
#
# The hook's warn channel is the PostToolUse stdout JSON envelope
# ({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":...}})
# with exit 0 — the one non-blocking channel the executing model receives. Plain
# text on stdout never reaches it, which is the fault these cases lock against
# regressing. Every fixture lives under a mktemp -d workspace; the hook is driven
# with canned PostToolUse stdin JSON and judged on rc + stdout + stderr.
set -u
# This session may export CLAUDE_PROJECT_DIR (pointing at the marketplace repo); the
# hook's state-root resolver reads it, so the fixtures must not inherit it. CLAUDE_PLUGIN_DATA
# would move the bash-effects marker out of the fixture repo, where case 18 looks for it.
unset CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_DATA

here=$(cd "$(dirname "$0")" && pwd)
HOOK="$here/../../hooks/scope.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

pass=0; fail=0
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT

CWD="$WS/repo"; mkdir -p "$CWD/.claude/task-runner"
git init -q "$CWD" 2>/dev/null
SCOPE="$CWD/.claude/task-runner/scope.json"
# A REGISTERED run (0.41.0): scope files are read only while active-run.json exists, and
# only when not older than it. Back-dated so every scope file written below is newer.
ACTIVE="$CWD/.claude/task-runner/active-run.json"
printf '{"slug":"t"}' > "$ACTIVE"; touch -t 202601010000 "$ACTIVE"

stdin_for() { # <file_path> -> canned PostToolUse stdin
  jq -cn --arg cwd "$CWD" --arg f "$1" \
    '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}}'
}

# run_case <desc> <stdin> <exp_rc> <stdout: envelope|silent> [ctx-substr...]
# envelope: stdout must parse as the PostToolUse envelope and additionalContext
#           must contain every listed substring.
# silent:   stdout must be empty (fail-open / in-scope paths emit no envelope).
run_case() {
  local desc="$1" json="$2" exp_rc="$3" mode="$4"; shift 4
  local out rc ok=1 reason="" ctx sub
  set +e
  out=$(printf '%s' "$json" | bash "$HOOK" 2>/dev/null); rc=$?
  set +e
  [ "$rc" = "$exp_rc" ] || { ok=0; reason="rc=$rc want=$exp_rc"; }
  if [ "$mode" = envelope ]; then
    if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
      ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty')
      [ -n "$ctx" ] || { ok=0; reason="$reason; additionalContext empty"; }
      for sub in "$@"; do
        case "$ctx" in *"$sub"*) ;; *) ok=0; reason="$reason; ctx missing <$sub>";; esac
      done
    else
      ok=0; reason="$reason; stdout is not the PostToolUse envelope: <$out>"
    fi
  else
    [ -z "$out" ] || { ok=0; reason="$reason; expected silent stdout, got <$out>"; }
  fi
  if [ "$ok" = 1 ]; then printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"; pass=$((pass+1))
  else printf 'FAIL: %s (%s)\n' "$desc" "$reason"; fail=$((fail+1)); fi
}

# 1) out-of-scope edit -> envelope on stdout with additionalContext naming the
#    file, the task, and the scope-creep instruction; exit 0 (never blocking).
printf '{"allow":["src/allowed.js","lib/"],"task":"card 07"}' > "$SCOPE"
run_case "out-of-scope edit -> additionalContext envelope" \
  "$(stdin_for "$CWD/other/file.js")" 0 envelope \
  "other/file.js" "card 07" "scope creep"

# 2) in-scope edit (exact allow entry) -> no envelope, exit 0
run_case "in-scope exact match -> silent" \
  "$(stdin_for "$CWD/src/allowed.js")" 0 silent

# 3) in-scope edit (directory-prefix allow entry) -> no envelope, exit 0
run_case "in-scope dir-prefix match -> silent" \
  "$(stdin_for "$CWD/lib/deep/nested.js")" 0 silent

# 3b) PATH BOUNDARY: an allow entry must not admit a sibling that merely shares
#     its text prefix. Before the boundary fix a raw startswith allowed all three.
printf '{"allow":["src/util.ts","app/Models"],"task":"card 07"}' > "$SCOPE"
run_case "sibling extension not admitted (util.ts vs util.tsx)" \
  "$(stdin_for "$CWD/src/util.tsx")" 0 envelope "src/util.tsx"
run_case "prefix sibling dir not admitted (Models vs ModelsBackup)" \
  "$(stdin_for "$CWD/app/ModelsBackup/X.php")" 0 envelope "app/ModelsBackup/X.php"
run_case "exact file entry still allowed" \
  "$(stdin_for "$CWD/src/util.ts")" 0 silent
run_case "dir entry without trailing slash still allows its children" \
  "$(stdin_for "$CWD/app/Models/Order.php")" 0 silent

# restore the fixture the later cases expect
printf '{"allow":["src/allowed.js","lib/"],"task":"card 07"}' > "$SCOPE"

# 4) editing scope.json itself is never in scope but always ignored
run_case "edit to scope.json itself -> silent" \
  "$(stdin_for "$CWD/.claude/task-runner/scope.json")" 0 silent

# 5) fail-open: no scope file declared -> no-op even for a wild edit
rm -f "$SCOPE"
run_case "missing scope file -> silent exit 0" \
  "$(stdin_for "$CWD/anywhere/at/all.js")" 0 silent

# 6) fail-open: malformed scope.json -> exit 0, NO envelope; the operator warning
#    goes to real stderr (fd 3), not into the model's context
printf '{not valid json' > "$SCOPE"
set +e
err=$(printf '%s' "$(stdin_for "$CWD/other/file.js")" | bash "$HOOK" 2>&1 1>/dev/null); erc=$?
set +e
if [ "$erc" = 0 ] && printf '%s' "$err" | grep -q "malformed"; then
  printf 'PASS: malformed scope.json -> exit 0, stderr warning (rc=%s)\n' "$erc"; pass=$((pass+1))
else
  printf 'FAIL: malformed scope.json (rc=%s err=<%s>)\n' "$erc" "$err"; fail=$((fail+1))
fi
run_case "malformed scope.json -> stdout stays silent" \
  "$(stdin_for "$CWD/other/file.js")" 0 silent
printf '{"allow":["src/allowed.js"],"task":"card 07"}' > "$SCOPE"

# 7) fail-open: malformed stdin -> exit 0, silent
run_case "malformed stdin -> silent exit 0" 'not json{{{' 0 silent

# 8) fail-open: stdin missing cwd/file_path fields -> exit 0, silent
run_case "stdin without cwd/file_path -> silent exit 0" '{}' 0 silent

# 9) fail-open: jq absent (empty PATH dir) -> exit 0, stdout silent.
#    The hook is exec'd directly: its absolute-path shebang (#!/bin/bash) is the
#    very thing that keeps it runnable under a stripped PATH.
EMPTYBIN="$WS/emptybin"; mkdir -p "$EMPTYBIN"
set +e
out=$(printf '%s' "$(stdin_for "$CWD/other/file.js")" | env PATH="$EMPTYBIN" "$HOOK" 2>/dev/null); jrc=$?
set +e
if [ "$jrc" = 0 ] && [ -z "$out" ]; then
  printf 'PASS: jq missing -> silent stdout, exit 0 (rc=%s)\n' "$jrc"; pass=$((pass+1))
else
  printf 'FAIL: jq missing (rc=%s stdout=<%s>)\n' "$jrc" "$out"; fail=$((fail+1))
fi

# 10) state hygiene (0.34.4): the run's state dir ignores itself once any hook sees it.
if [ "$(cat "$CWD/.claude/task-runner/.gitignore" 2>/dev/null)" = "*" ]; then
  printf 'PASS: .claude/task-runner/ ignores itself\n'; pass=$((pass+1))
else
  printf 'FAIL: .claude/task-runner/.gitignore missing or not "*"\n'; fail=$((fail+1))
fi

# 11) PER-CARD SCOPE FILES (SW 8 of the 2026-09-22 panel). routing.md writes one
#     scope-<cardId>.json per delegated/tracked card; until 0.38.0 this hook read only
#     the fixed scope.json, so the delegated path — the one the plugin sells — had no
#     mechanical tripwire at all. These cases fail against that logic: with NO
#     scope.json present, the old hook was silent on every path.
rm -f "$SCOPE"
printf '{"allow":["src/card-a.js"],"task":"card 01"}' > "$CWD/.claude/task-runner/scope-01.json"
printf '{"allow":["src/card-b.js"],"task":"card 02"}' > "$CWD/.claude/task-runner/scope-02.json"

run_case "per-card scope only: out-of-union edit -> envelope naming both cards" \
  "$(stdin_for "$CWD/src/stray.js")" 0 envelope "src/stray.js" "card 01, card 02"
run_case "per-card scope only: card 01's file -> silent" \
  "$(stdin_for "$CWD/src/card-a.js")" 0 silent
run_case "per-card scope only: card 02's file -> silent (union, not first-file-wins)" \
  "$(stdin_for "$CWD/src/card-b.js")" 0 silent
run_case "edit to a scope-<cardId>.json itself -> silent" \
  "$(stdin_for "$CWD/.claude/task-runner/scope-01.json")" 0 silent

# 12) inline scope.json joins the SAME union rather than replacing it.
printf '{"allow":["src/inline.js"],"task":"inline"}' > "$SCOPE"
run_case "inline + per-card: inline file -> silent" \
  "$(stdin_for "$CWD/src/inline.js")" 0 silent
run_case "inline + per-card: card file still silent" \
  "$(stdin_for "$CWD/src/card-a.js")" 0 silent
run_case "inline + per-card: stray still warns" \
  "$(stdin_for "$CWD/src/stray.js")" 0 envelope "src/stray.js"

# 13) one malformed member disarms the whole call (stated in the header): a partial
#     union would warn about a path the file it could not parse had allowed.
printf 'not json' > "$CWD/.claude/task-runner/scope-03.json"
run_case "one malformed scope file -> whole call not enforced, stdout silent" \
  "$(stdin_for "$CWD/src/stray.js")" 0 silent
set +e
err=$(printf '%s' "$(stdin_for "$CWD/src/stray.js")" | bash "$HOOK" 2>&1 >/dev/null); set +e
case "$err" in *"scope-03.json is malformed"*)
  printf 'PASS: malformed member named on stderr\n'; pass=$((pass+1)) ;;
  *) printf 'FAIL: malformed member not named on stderr: <%s>\n' "$err"; fail=$((fail+1)) ;;
esac
rm -f "$CWD/.claude/task-runner/scope-03.json" "$CWD/.claude/task-runner/scope-01.json" \
      "$CWD/.claude/task-runner/scope-02.json"

# 13b) VALID JSON, WRONG SHAPE. Orchestrators wrote {card, allowed}; `.allow // []` read
#      it as an empty list and every edit of the run warned. Now it disarms like a
#      malformed file and names the expected shape.
printf '{"card":"04","allowed":["src/card-d.js"]}' > "$CWD/.claude/task-runner/scope-04.json"
run_case "scope file with no allow array -> whole call not enforced, stdout silent" \
  "$(stdin_for "$CWD/src/card-d.js")" 0 silent
set +e
err=$(printf '%s' "$(stdin_for "$CWD/src/card-d.js")" | bash "$HOOK" 2>&1 >/dev/null); set +e
case "$err" in *'scope-04.json has no "allow" array (expected {"allow":["path","dir/"],"task":"<id>"})'*)
  printf 'PASS: wrong-shape member named on stderr with the expected shape\n'; pass=$((pass+1)) ;;
  *) printf 'FAIL: wrong-shape member not named on stderr: <%s>\n' "$err"; fail=$((fail+1)) ;;
esac
rm -f "$CWD/.claude/task-runner/scope-04.json"

# 13c) an Edit/Write OUTSIDE the project root (a /tmp probe, the user's memory dir) is no
#      card's file; it was told to "revert this edit". An in-root stray still warns.
run_case "Edit to an absolute path outside the root -> silent" \
  "$(stdin_for "$WS/elsewhere/notes.md")" 0 silent
run_case "Edit to an in-root path outside scope -> still warns" \
  "$(stdin_for "$CWD/src/stray.js")" 0 envelope "src/stray.js"

# ---- 0.41.0: finding 8 (stale scope), finding 2 (state root), finding 1 (Bash writes)
#      of rationale/2026-09-25-session-plugin-usage-review.md.
ctx_of() { printf '%s' "$1" | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
lacks() { # <desc> <ctx> <substr>: the envelope must NOT mention substr
  case "$2" in *"$3"*) printf 'FAIL: %s (ctx mentions <%s>)\n' "$1" "$3"; fail=$((fail+1)) ;;
    *) printf 'PASS: %s\n' "$1"; pass=$((pass+1)) ;; esac
}
stdin_bash() { # <command> [cwd] -> canned PostToolUse stdin for a Bash call
  jq -cn --arg cwd "${2:-$CWD}" --arg c "$1" '{cwd:$cwd, tool_name:"Bash", tool_input:{command:$c}}'
}
printf '{"allow":["src/allowed.js","lib/"],"task":"card 07"}' > "$SCOPE"

# 14) STALE SCOPE, NO RUN. A finished run's scope-*.json flagged the next task's spec edit
#     as scope creep: the old hook read scope files whether or not a run was live.
mv "$ACTIVE" "$ACTIVE.bak"
run_case "stale scope.json with no registered run -> silent" \
  "$(stdin_for "$CWD/other/file.js")" 0 silent
mv "$ACTIVE.bak" "$ACTIVE"
run_case "same scope.json once a run is registered -> warns again" \
  "$(stdin_for "$CWD/other/file.js")" 0 envelope "other/file.js"

# 15) a scope file OLDER than active-run.json belongs to an earlier registration: its
#     allow list and its task name both drop out of the union.
OLD="$CWD/.claude/task-runner/scope-99.json"
printf '{"allow":["src/old.js"],"task":"card 99"}' > "$OLD"; touch -t 202501010000 "$OLD"
ctx=$(ctx_of "$(stdin_for "$CWD/src/old.js")")
case "$ctx" in *"src/old.js"*"card 07"*)
  printf 'PASS: scope file older than active-run.json -> its allow list is ignored\n'; pass=$((pass+1)) ;;
  *) printf 'FAIL: older scope file still honoured (ctx=<%s>)\n' "$ctx"; fail=$((fail+1)) ;; esac
lacks "older scope file's task is not named" "$ctx" "card 99"
rm -f "$OLD"

# 16) BASH WRITES. PostToolUse, so a target counts only if it exists after the call.
mkdir -p "$CWD/other" "$CWD/src"
echo x > "$CWD/other/out.js"; echo x > "$CWD/src/allowed.js"; echo '{}' > "$CWD/.claude/task-runner/gate-pass.json"
run_case "Bash heredoc write outside scope -> envelope" \
  "$(stdin_bash "cat > other/out.js <<'EOF'
const big = 1 > 0 ? 'a' : 'b';
EOF")" 0 envelope "other/out.js" "card 07" "scope creep"
run_case "Bash write inside scope -> silent" \
  "$(stdin_bash "printf 'x' > src/allowed.js")" 0 silent
run_case "Bash with no write targets -> silent" \
  "$(stdin_bash "ls -la && git status --short | head -5")" 0 silent
run_case "Bash target that does not exist after the call -> silent" \
  "$(stdin_bash "echo x > other/never-written.js")" 0 silent
run_case "Bash write to the run's own state (.claude/task-runner/) -> silent" \
  "$(stdin_bash "echo '{\"head\":\"x\"}' > .claude/task-runner/gate-pass.json")" 0 silent
ctx=$(ctx_of "$(stdin_bash "echo x | tee src/allowed.js other/out.js")")
case "$ctx" in *"other/out.js was edited"*)
  printf 'PASS: Bash tee to two paths -> the out-of-scope one warns\n'; pass=$((pass+1)) ;;
  *) printf 'FAIL: tee out-of-scope target not flagged (ctx=<%s>)\n' "$ctx"; fail=$((fail+1)) ;; esac
lacks "Bash tee to two paths -> the in-scope one does not" "$ctx" "src/allowed.js"

# 17) STATE ROOT. The payload cwd follows the model's `cd`; the scope files live at the
#     project root. The old hook looked under the subdirectory, found none, and was silent.
SUB="$CWD/app/Models"; mkdir -p "$SUB"
run_case "subdirectory cwd -> reads the ROOT scope (Edit outside scope warns)" \
  "$(jq -cn --arg cwd "$SUB" --arg f "$CWD/other/file.js" '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}}')" \
  0 envelope "other/file.js"
run_case "subdirectory cwd -> in-scope Edit stays silent" \
  "$(jq -cn --arg cwd "$SUB" --arg f "$CWD/src/allowed.js" '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}}')" 0 silent
echo x > "$SUB/Local.php"
run_case "subdirectory cwd -> Bash relative target named repo-relative" \
  "$(stdin_bash "echo x > Local.php" "$SUB")" 0 envelope "app/Models/Local.php"
run_case "subdirectory cwd -> Bash ../ target normalized, in scope -> silent" \
  "$(stdin_bash "echo x > ../../src/allowed.js" "$SUB")" 0 silent
if [ -e "$SUB/.claude" ] || [ -e "$CWD/app/.claude" ]; then
  printf 'FAIL: a .claude/ dir appeared under the subdirectory\n'; fail=$((fail+1))
else
  printf 'PASS: no .claude/ dir created under the subdirectory\n'; pass=$((pass+1))
fi
rm -f "$CWD/.claude/task-runner/gate-pass.json"

# 18) INTERPRETER WRITES (0.47.0, bash-write-effects). A file git reports changed since this
#     hook's previous call in the run, after an interpreter, cp, mv, install or patch run, is
#     judged as an Edit of it would be. One repo per shape group: a reused repo carries the
#     marker. All red against 0.46.3 except the silent ones, which pin what must not change.
mkrun() { # <dir> -> a git repo with a registered run allowing src/allowed.js and lib/
  mkdir -p "$1/.claude/task-runner" "$1/src" "$1/lib" "$1/other"; git init -q "$1"
  printf '{"slug":"t"}' > "$1/.claude/task-runner/active-run.json"; touch -t 202601010000 "$1/.claude/task-runner/active-run.json"
  printf '{"allow":["src/allowed.js","lib/"],"task":"card 07"}' > "$1/.claude/task-runner/scope.json"
}
runb() { (cd "$1" && bash -c "$2") >/dev/null 2>&1; ctx_of "$(stdin_bash "$2" "$1")"; } # <repo> <command>: run it, then the hook
edit_ctx() { ctx_of "$(jq -cn --arg cwd "$1" --arg f "$2" '{cwd:$cwd, tool_name:"Edit", tool_input:{file_path:$f}}')"; }
check() { if [ "$2" = 1 ]; then printf 'PASS: %s\n' "$1"; pass=$((pass+1)); else printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); fi; }
if command -v python3 >/dev/null 2>&1; then
  R="$WS/fx-effects"; mkrun "$R"; MK="$R/.claude/task-runner/bash-effects.mark"
  ctx=$(runb "$R" "python3 - <<'PY'
open('other/first.js', 'w').write('x\n')
PY")
  check "effects: the first call of a run in a repo is silent and leaves the marker (ctx=<$ctx>)" \
    "$([ -z "$ctx" ] && [ -f "$MK" ] && echo 1)"
  ctx_b=$(runb "$R" "python3 - <<'PY'
open('other/py.js', 'w').write('x\n')
PY")
  check "effects: a python heredoc write outside scope warns that it changed and may not be the command's, never to revert it (bash=<$ctx_b>)" \
    "$(case "$ctx_b" in *"other/py.js changed since the previous tool call"*"git diff -- other/py.js"*"never revert a change you did not make"*) echo 1 ;; esac)"
  lacks "effects: a file the effects found is never told 'revert this edit'" "$ctx_b" "revert this edit"
  ctx=$(runb "$R" "python3 - <<'PY'
open('src/allowed.js', 'w').write('x\n'); open('lib/deep.js', 'w').write('x\n')
PY")
  check "effects: a python heredoc write inside scope is silent (ctx=<$ctx>)" "$([ -z "$ctx" ] && echo 1)"
  ctx=$(runb "$R" "python3 -c 'print(1)'")
  check "effects: a matching run that wrote nothing is silent (ctx=<$ctx>)" "$([ -z "$ctx" ] && echo 1)"
  echo x > "$R/other/edited.js"; edit_ctx "$R" "$R/other/edited.js" >/dev/null
  ctx=$(runb "$R" "python3 - <<'PY'
open('other/py2.js', 'w').write('x\n')
PY")
  check "effects: the next interpreter write outside scope warns (ctx=<$ctx>)" \
    "$(case "$ctx" in *"other/py2.js changed since"*) echo 1 ;; esac)"
  lacks "effects: a file an Edit changed between two Bash calls is not read again" "$ctx" "other/edited.js"
  ctx=$(runb "$R" "cp src/allowed.js other/copied.js")
  check "effects: a cp destination outside scope warns (ctx=<$ctx>)" \
    "$(case "$ctx" in *"other/copied.js changed since"*) echo 1 ;; esac)"
  touch -t 202501010000 "$MK"
  ctx=$(runb "$R" "python3 - <<'PY'
open('other/late.js', 'w').write('x\n')
PY")
  check "effects: a marker older than active-run.json (an earlier run's) reads nothing (ctx=<$ctx>)" \
    "$([ -z "$ctx" ] && [ "$MK" -nt "$R/.claude/task-runner/active-run.json" ] && echo 1)"
  N="$WS/fx-norun"; mkdir -p "$N"; git init -q "$N"
  runb "$N" "python3 -c 'print(1)'" >/dev/null
  check "effects: no registered run -> no state written into the repo" "$([ ! -e "$N/.claude" ] && echo 1)"

  # Two workers of one session in one tree: worker B's python run writes other/stray.js and worker A's hook call ends
  # first. A is told the file changed and may not be its own, never to revert it; B, its window spent, is silent.
  wb() { # <repo> <context> <command> [session] [event] -> the hook's raw stdout on that Bash call
    jq -cn --arg cwd "$1" --arg t "/t/$2.jsonl" --arg c "$3" --arg s "${4:-sess}" --arg e "${5:-PostToolUse}" \
      '{hook_event_name:$e, session_id:$s, transcript_path:$t, cwd:$cwd, tool_name:"Bash", tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null
  }
  wctx() { wb "$@" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
  W="$WS/fx-workers"; mkrun "$W"; wb "$W" worker-a 'ls' >/dev/null
  (cd "$W" && python3 -c "open('other/stray.js', 'w').write('x\n')")
  ctx_a=$(wctx "$W" worker-a "python3 -c 'print(1)'")
  ctx_bw=$(wctx "$W" worker-b "python3 - <<'PY'
open('other/stray.js', 'w').write('x\n')
PY")
  check "effects: two workers, one tree — A hears of B's file as maybe not its own and is never told to revert it; B is silent (a=<$ctx_a> b=<$ctx_bw>)" \
    "$(case "$ctx_a" in *"other/stray.js changed since"*"never revert a change you did not make"*) [ -z "$ctx_bw" ] && echo 1 ;; esac)"
  lacks "effects: two workers — A is not told to revert B's file" "$ctx_a" "revert this edit"

  # A marker another session dated reads nothing: a user's edit between sessions is not the next session's write.
  S="$WS/fx-sessions"; mkrun "$S"; wb "$S" s1 'ls' sess-1 >/dev/null
  echo x > "$S/other/user.js"
  ctx=$(wctx "$S" s2 "python3 -c 'print(1)'" sess-2)
  check "effects: a marker another session dated reads nothing (ctx=<$ctx>)" "$([ -z "$ctx" ] && echo 1)"

  # A failed command fires PostToolUseFailure: its writes are read, and the envelope names that event.
  F="$WS/fx-failed"; mkrun "$F"; wb "$F" f1 'ls' >/dev/null
  (cd "$F" && python3 -c "open('other/failed.js', 'w').write('x\n')")
  out=$(wb "$F" f1 "python3 gen.py && false" sess PostToolUseFailure)
  check "effects: a failed python run (PostToolUseFailure) is read, its envelope naming that event (out=<$out>)" \
    "$(printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUseFailure" and (.hookSpecificOutput.additionalContext | contains("other/failed.js"))' >/dev/null 2>&1 && echo 1)"
  # A failed command may stop before its redirect: another writer's file it names is not called its edit.
  T="$WS/fx-failed-redirect"; mkrun "$T"; echo theirs > "$T/other/x.js"
  ctx=$(wctx "$T" t1 'npm test && echo done > other/x.js' sess PostToolUseFailure)
  check "failed redirect, no marker yet: the named target takes the effects wording (ctx=<$ctx>)" \
    "$(case "$ctx" in *"other/x.js changed since"*) echo 1 ;; esac)"
  lacks "failed redirect, no marker yet: never told to revert" "$ctx" "revert this edit"
  ctx=$(wctx "$T" t1 'npm test && echo done > other/x.js' sess PostToolUseFailure)
  check "failed redirect: a named target older than the previous call's marker is not reported (ctx=<$ctx>)" "$([ -z "$ctx" ] && echo 1)"
  echo y > "$T/other/w.js"
  ctx=$(wctx "$T" t1 'echo y > other/w.js; false' sess PostToolUseFailure)
  check "failed command after its redirect ran: the named target still warns as an edit (ctx=<$ctx>)" \
    "$(case "$ctx" in *"other/w.js was edited"*) echo 1 ;; esac)"
  check "effects: scope.sh is registered on PostToolUseFailure for Bash" \
    "$(jq -e '.hooks.PostToolUseFailure[] | select(.matcher == "Bash") | .hooks[] | select(.command | test("hooks/scope.sh"))' \
      "$(dirname "$HOOK")/hooks.json" >/dev/null 2>&1 && echo 1)"

  # Another plugin's marker is not a write: cc_bash_effects_mark gives its dir a `*` .gitignore, so git never lists it.
  G="$WS/fx-sibling"; mkrun "$G"; wb "$G" g1 'ls' >/dev/null
  mkdir -p "$G/.claude/security"; printf '*\n' > "$G/.claude/security/.gitignore"; echo 123 > "$G/.claude/security/bash-effects.mark"
  ctx=$(wctx "$G" g1 "python3 -c 'print(1)'")
  check "effects: a sibling plugin's fresh marker under .claude/ is not read as the command's write (ctx=<$ctx>)" "$([ -z "$ctx" ] && echo 1)"
else
  echo "SKIP 18: python3 not available"
fi

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
