#!/usr/bin/env bash
# Tests plugins/git-workflow/hooks/merge-checks.sh against real PreToolUse payloads,
# with a stub `gh` first on PATH that logs its cwd and arguments and prints rows in
# gh's non-TTY `pr checks` shape (name, bucket, elapsed, link, description).
#
# Picked up by the repo's "Plugin author-time lint + harness tests" CI step,
# which globs plugins/*/scripts/__tests__/*.test.sh.
#
# Sections:
#   1. VERDICT: pending, failing, cancelled -> ask naming the checks and the switch;
#      all green, no checks reported -> silent.
#   2. WHAT IS A MERGE: wrappers and selectors reach gh; --help, --auto, other gh
#      verbs, quoted or heredoc text, and a variable PR never call it.
#   3. FAIL-OPEN AND SWITCH: no gh, a gh that hangs, no jq, bad input, the off-switch.
set -u

here=$(cd "$(dirname "$0")" && pwd)
HOOK="$here/../../hooks/merge-checks.sh"
BASH_BIN="$(command -v bash)"

[ -f "$HOOK" ] || { printf 'FAIL: hook not found at %s\n' "$HOOK"; exit 1; }
[ -x "$HOOK" ] || { printf 'FAIL: %s is not executable\n' "$HOOK"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
stub="$tmp/stub"; nogh="$tmp/nogh"; repo="$tmp/repo"; LOG="$tmp/gh.log"
mkdir -p "$stub" "$nogh" "$repo"

# Stub modes: running (one check still pending), fail, cancel, many (seven pending),
# green (pass + skipping), none (gh's no-checks error), slow (hangs).
cat > "$stub/gh" <<'STUB'
#!/bin/bash
printf '%s|%s\n' "$PWD" "$*" >> "$STUB_LOG"
T=$(printf '\t')
case "${STUB_GH_MODE:-green}" in
  running) printf 'build%spending%s0%shttps://ci.example/1%s\n' "$T" "$T" "$T" "$T"
           printf 'lint%spass%s12s%shttps://ci.example/2%s\n' "$T" "$T" "$T" "$T"; exit 8 ;;
  fail)    printf 'unit tests%sfail%s1m2s%shttps://ci.example/3%s\n' "$T" "$T" "$T" "$T"
           printf 'lint%spass%s12s%shttps://ci.example/2%s\n' "$T" "$T" "$T" "$T"; exit 1 ;;
  cancel)  printf 'deploy-preview%scancel%s3s%shttps://ci.example/4%s\n' "$T" "$T" "$T" "$T"; exit 1 ;;
  many)    for n in 1 2 3 4 5 6 7; do printf 'job-%s%spending%s0%shttps://ci.example/%s%s\n' "$n" "$T" "$T" "$T" "$n" "$T"; done; exit 8 ;;
  green)   printf 'build%spass%s1m%shttps://ci.example/1%s\n' "$T" "$T" "$T" "$T"
           printf 'docs%sskipping%s0%shttps://ci.example/5%s\n' "$T" "$T" "$T" "$T"; exit 0 ;;
  none)    printf "no checks reported on the 'feature/x' branch\n" >&2; exit 1 ;;
  slow)    exec sleep 30 ;;
esac
STUB
chmod +x "$stub/gh"
# A PATH holding every tool the hook uses except gh (this machine may have a real one).
for t in jq cat tr grep awk head mktemp sleep rm; do
  p=$(command -v "$t") && ln -s "$p" "$nogh/$t"
done

payload() { # tool command
  jq -cn --arg t "$1" --arg c "$2" --arg cwd "$repo" \
    '{session_id:"s1",transcript_path:"/tmp/t.jsonl",cwd:$cwd,hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$c}}'
}
run() { # mode command [tool] -> hook stdout; gh calls land in $LOG
  : > "$LOG"
  payload "${3:-Bash}" "$2" | STUB_LOG="$LOG" STUB_GH_MODE="$1" PATH="$stub:$PATH" "$BASH_BIN" "$HOOK"
}
is_ask() { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision == "ask"' >/dev/null 2>&1; }
reason() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
gh_calls() { wc -l < "$LOG" | tr -d ' '; }

printf '== verdict\n'
out=$(run running 'gh pr merge 12 --squash')
is_ask "$out" && ok || bad "a check still running must ask" "$out"
r=$(reason "$out")
case "$r" in *"still running: build"*) ok ;; *) bad "ask must name the running check" "$r" ;; esac
case "$r" in *"CC_MERGE_CHECKS=off"*) ok ;; *) bad "ask must name the off-switch" "$r" ;; esac
case "$r" in *lint*) bad "a passing check is not named" "$r" ;; *) ok ;; esac

out=$(run fail 'gh pr merge 12 --squash')
is_ask "$out" && ok || bad "failing check must ask" "$out"
case "$(reason "$out")" in *"failing: unit tests"*) ok ;; *) bad "ask must name the failing check, spaces kept" "$(reason "$out")" ;; esac

out=$(run cancel 'gh pr merge 12')
case "$(reason "$out")" in *"failing: deploy-preview"*) ok ;; *) bad "a cancelled check counts as failing" "$out" ;; esac

out=$(run many 'gh pr merge 12')
case "$(reason "$out")" in *"job-5 +2 more"*) ok ;; *) bad "names are capped at five plus a count" "$(reason "$out")" ;; esac

out=$(run green 'gh pr merge 12 --squash --delete-branch')
[ -z "$out" ] && ok || bad "all green (pass + skipping) must be silent" "$out"
[ "$(gh_calls)" = 1 ] && ok || bad "the green case must still have asked gh" "calls=$(gh_calls)"

out=$(run none 'gh pr merge --squash')
[ -z "$out" ] && ok || bad "no checks reported must be silent" "$out"

printf '== what is a merge\n'
out=$(run running 'gh pr merge 42 --squash -R octo/widgets')
is_ask "$out" && ok || bad "selector + -R must still ask" "$out"
grep -qxF "$repo|pr checks 42 -R octo/widgets" "$LOG" && ok || bad "gh must get the selector and repo, in the payload cwd" "$(cat "$LOG")"

run running 'gh pr merge --squash' >/dev/null
grep -qxF "$repo|pr checks" "$LOG" && ok || bad "a bare merge checks the current branch's PR" "$(cat "$LOG")"

run running 'gh pr merge --squash --body "fixes the 12 flaky specs" --repo=octo/widgets 7' >/dev/null
grep -qxF "$repo|pr checks 7 -R octo/widgets" "$LOG" && ok || bad "a quoted --body value is not the selector" "$(cat "$LOG")"

run running 'gh pr merge https://github.com/octo/widgets/pull/9 --merge' >/dev/null
grep -qxF "$repo|pr checks https://github.com/octo/widgets/pull/9" "$LOG" && ok || bad "a PR URL is passed through" "$(cat "$LOG")"

for c in 'cd /srv/app && gh pr merge 12 --squash' \
         'git push && gh pr merge 12' \
         'git push
gh pr merge 12 --squash' \
         'git push;gh pr merge 12' \
         'bash -c "gh pr merge 12 --squash"' \
         'GH_PROMPT_DISABLED=1 /usr/local/bin/gh pr merge 12'; do
  out=$(run running "$c")
  is_ask "$out" && ok || bad "a merge behind a wrapper must ask" "$c"
done
out=$(run running 'gh pr merge 12' mcp__ide__execute_terminal_command)
is_ask "$out" && ok || bad "the MCP terminal tool is read too" "$out"

for c in 'gh pr merge --help' \
         'gh pr merge 12 --auto --squash' \
         'gh pr merge 12 --disable-auto' \
         'gh pr view 12' \
         'gh pr checks 12' \
         'gh pr create --title "merge the parser"' \
         'git merge --no-ff topic' \
         'git commit -m "next: gh pr merge 12 once green"' \
         "echo 'gh pr merge 12'" \
         'gh pr merge "$PR" --squash' \
         'for n in 1 2; do gh pr merge $n; done' \
         "cat > notes.md <<'EOF'
gh pr merge 12 --squash
EOF" \
         'ls -la && git status'; do
  out=$(run running "$c")
  [ -z "$out" ] && [ "$(gh_calls)" = 0 ] && ok || bad "must be silent and never call gh" "$c -> out=$out calls=$(gh_calls)"
done

printf '== fail-open and switch\n'
out=$(payload Bash 'gh pr merge 12' | STUB_LOG="$LOG" PATH="$nogh" "$BASH_BIN" "$HOOK"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "no gh on PATH must be silent exit 0" "rc=$rc out=$out"

start=$(date +%s)
out=$(run slow 'gh pr merge 12'); rc=$?
took=$(( $(date +%s) - start ))
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "a gh that hangs must be silent exit 0" "rc=$rc out=$out"
[ "$took" -le 8 ] && ok || bad "a hanging gh is killed at the 5 s watchdog" "took ${took}s"

out=$(payload Bash 'gh pr merge 12' | STUB_LOG="$LOG" STUB_GH_MODE=running CC_MERGE_CHECKS=off PATH="$stub:$PATH" "$BASH_BIN" "$HOOK")
[ -z "$out" ] && ok || bad "CC_MERGE_CHECKS=off must disable the hook" "$out"
out=$(payload Bash 'gh pr merge 12' | STUB_LOG="$LOG" STUB_GH_MODE=running CLAUDE_PLUGIN_OPTION_CC_MERGE_CHECKS=false PATH="$stub:$PATH" "$BASH_BIN" "$HOOK")
[ -z "$out" ] && ok || bad "the /config option set to false must disable the hook" "$out"
out=$(payload Bash 'gh pr merge 12' | STUB_LOG="$LOG" STUB_GH_MODE=running CC_MERGE_CHECKS=on CLAUDE_PLUGIN_OPTION_CC_MERGE_CHECKS=false PATH="$stub:$PATH" "$BASH_BIN" "$HOOK")
is_ask "$out" && ok || bad "the variable beats the /config option" "$out"

out=$(printf 'not json merge' | PATH="$stub:$PATH" "$BASH_BIN" "$HOOK"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "malformed input must be silent exit 0" "rc=$rc out=$out"
out=$(printf '' | PATH="$stub:$PATH" "$BASH_BIN" "$HOOK"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "empty input must be silent exit 0" "rc=$rc out=$out"
out=$(payload Bash 'gh pr merge 12' | PATH=/nonexistent "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "no jq on PATH must be silent exit 0" "rc=$rc out=$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
