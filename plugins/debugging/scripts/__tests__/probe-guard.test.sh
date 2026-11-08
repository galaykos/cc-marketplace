#!/usr/bin/env bash
# Harness for hooks/probe-guard.sh against real PreToolUse Bash payloads in a scratch repository.
# Load-bearing: a staged added `[DEBUG-` line asks, also on --amend and on -a; the neighbours stay silent (unstaged, removed lines,
# git status and git log, a commit message naming the marker, a quoted -a, echo, the off switch, no repository, a bad payload).
set -u
here=$(cd "$(dirname "$0")" && pwd)
H="$here/../../hooks/probe-guard.sh"
[ -x "$H" ] || { printf 'FAIL: probe-guard.sh not executable\n'; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }
pass=0; fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
unset CC_PROBE_GUARD CLAUDE_PLUGIN_OPTION_CC_PROBE_GUARD

R="$T/repo"; mkdir -p "$R"
g() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }
hook() { # <command> [cwd]
  jq -cn --arg c "$1" --arg d "${2:-$R}" \
    '{session_id:"s1", transcript_path:"/tmp/t.jsonl", cwd:$d, permission_mode:"default", hook_event_name:"PreToolUse",
      tool_name:"Bash", tool_input:{command:$c, description:"check the tree, then commit"}, tool_use_id:"toolu_01"}' | bash "$H"
}
decision() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }
reason()   { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
asks()   { [ "$(decision "$2")" = ask ] && ok "$1" || bad "$1 (got: $2)"; }
silent() { [ -z "$2" ] && ok "$1" || bad "$1 (got: $2)"; }
reset() { g reset -q --hard; g clean -qfd; }

g init -q -b main
printf 'def total(xs):\n    s = 0\n    for x in xs:\n        s += x\n    return s\n' > "$R/app.py"
printf 'print("[DEBUG-7c1e] old probe")\nkeep = 1\n' > "$R/old.py"
printf '# Notes\n' > "$R/notes.md"
g add -A; g commit -qm init

printf '== asks\n'
printf 'def total(xs):\n    s = 0\n    print("[DEBUG-a4f2] xs=", xs)\n    for x in xs:\n        s += x\n    return s\n' > "$R/app.py"
g add app.py
out=$(hook 'git commit -m "fix total"')
asks "a staged added [DEBUG- line asks on git commit" "$out"
r=$(reason "$out")
case "$r" in *"app.py:3"*) ok "the ask names the file and line" ;; *) bad "file:line (got: $r)" ;; esac
case "$r" in *"CC_PROBE_GUARD=off"*) ok "the ask names the off switch" ;; *) bad "off switch (got: $r)" ;; esac
asks "git commit --amend with a staged marker asks" "$(hook 'git commit --amend --no-edit')"
asks "a wrapped commit asks (cd, env assignment, &&)" "$(hook "cd $R && GIT_AUTHOR_NAME=x git commit -qm wip")"
asks "a commit on a later line of the command asks" "$(hook "$(printf 'npm test\ngit commit -m wip')")"
asks "git -C <dir> -c k=v commit asks" "$(hook "git -C $R -c commit.gpgsign=false commit -m wip")"
mkdir -p "$R/src"; out=$(cd "$R/src" && hook 'git commit -m wip' "$R/src")
case "$(reason "$out")" in *"app.py:3"*) ok "from a subdirectory the whole index is read, paths from the root" ;; *) bad "subdir (got: $out)" ;; esac

printf '== silent\n'
for c in 'git status' 'git log --oneline -5' 'git diff --cached' 'git log --grep "git commit"' 'echo "git commit later"'; do
  silent "$c is silent with a staged marker" "$(hook "$c")"
done
reset
printf 'def total(xs):\n    print("[DEBUG-a4f2] unstaged")\n    return sum(xs)\n' > "$R/app.py"
printf 'x = 1\n' > "$R/other.py"; g add other.py
silent "an unstaged marker is silent" "$(hook 'git commit -m "add other"')"
silent "a quoted -a in the message is not -a" "$(hook 'git commit -m "rename -a flag"')"
asks "git commit -am stages the tracked marker, so it asks" "$(hook 'git commit -am wip')"
asks "git commit --all asks too" "$(hook 'git commit --all -m wip')"
silent "-ma is -m with the value a, not -a" "$(hook 'git commit -ma')"
reset
printf 'print("done")\nkeep = 1\n' > "$R/old.py"; g add old.py
silent "a marker in a removed line is silent, the added line beside it too" "$(hook 'git commit -m "drop probe"')"
reset
printf 'x = 2\n' > "$R/other.py"; g add other.py
silent "a commit message naming [DEBUG- is silent" "$(hook 'git commit -m "remove [DEBUG-a4f2] probes"')"
silent "a heredoc message naming [DEBUG- is silent" "$(hook "$(printf 'git commit -F- <<EOF\nstrip [DEBUG-a4f2] probes\nEOF')")"

printf '== caps, switch, fail-open\n'
reset
for i in 1 2 3 4 5 6 7; do printf 'log("[DEBUG-b%s]")\n' "$i" > "$R/f$i.js"; done
g add -A
r=$(reason "$(hook 'git commit -m wip')")
case "$r" in *"adds 7 line(s)"*"(+2 more)"*) ok "seven probes: the count, five names, +2 more" ;; *) bad "cap (got: $r)" ;; esac
silent "CC_PROBE_GUARD=off silences it" "$(CC_PROBE_GUARD=off hook 'git commit -m wip')"
silent "the /config option off silences it" "$(CLAUDE_PLUGIN_OPTION_CC_PROBE_GUARD=false hook 'git commit -m wip')"
mkdir -p "$T/plain"
silent "outside a repository it is silent" "$(hook 'git commit -m wip' "$T/plain")"
out=$(printf 'not json' | bash "$H"); rc=$?
[ -z "$out" ] && [ "$rc" = 0 ] && ok "a malformed payload fails open" || bad "malformed (rc=$rc out=$out)"
N="$T/new"; mkdir -p "$N"; git -C "$N" init -q -b main; printf 'p("[DEBUG-c0de]")\n' > "$N/a.js"; git -C "$N" add a.js
asks "a first commit (no HEAD) with a staged marker asks, -a included" "$(hook 'git commit -am first' "$N")"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
