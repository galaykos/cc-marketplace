#!/usr/bin/env bash
# commit-scan.test.sh — hooks/commit-scan.sh against real PreToolUse Bash payloads in a scratch repository with a bare remote:
#   a staged secret, `-a` over an unstaged tracked one, `git add` of an untracked one and an unpushed one deny, naming file:line and the
#   label, never the value; their nearest neighbours stay silent (a clean commit, an unstaged secret, a pushed one, a placeholder, a quoted
#   or dry-run command, a heredoc body). Secret shapes are assembled at runtime: the write guard would deny a write of this file.
set -u
here=$(cd "$(dirname "$0")" && pwd)
H="$here/../../hooks/commit-scan.sh"
[ -x "$H" ] || { printf 'FAIL: commit-scan.sh not executable\n'; exit 1; }
command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || { printf 'SKIP: jq and git are required\n'; exit 0; }
pass=0; fail=0
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
unset CC_SECRET_COMMIT_SCAN CLAUDE_PLUGIN_OPTION_CC_SECRET_COMMIT_SCAN

TOK=$(printf 'AK%s%s' 'IA' 'Q7ZT9WM2RP4LX8VN')
FIX=$(printf 'api_%s = "%s"' 'key' 'example_Kq7Zt9WmRp4Lx8Vn3Bc6Yd')
R="$T/w"
g() { git -C "$R" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }
hook() { # <command> [cwd]
  jq -cn --arg c "$1" --arg d "${2:-$R}" \
    '{session_id:"s1", transcript_path:"/tmp/t.jsonl", cwd:$d, permission_mode:"default", hook_event_name:"PreToolUse",
      tool_name:"Bash", tool_input:{command:$c, description:"commit the change"}, tool_use_id:"toolu_01"}' | bash "$H"
}
reason() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
denies() { [ "$(printf '%s' "$2" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)" = deny ] && ok "$1" || bad "$1 (got: ${2:-<empty>})"; }
silent() { [ -z "$2" ] && ok "$1" || bad "$1 (got: $2)"; }
reset() { g reset -q --hard; g clean -qfd; }

git init -q --bare "$T/remote.git"
git init -q -b main "$R"
printf 'base\n' > "$R/a.txt"; mkdir -p "$R/src"; printf 'x = 1\n' > "$R/src/app.py"
g add -A; g commit -qm base; g remote add origin "$T/remote.git"; g push -q -u origin main

printf '== commit\n'
printf 'k=%s\n' "$TOK" > "$R/s.txt"; g add s.txt
out=$(hook 'git commit -m "add s"')
denies "a staged secret denies git commit" "$out"
r=$(reason "$out")
case "$r" in *"s.txt:1 an AWS access key ID"*) ok "the deny names file:line and the pattern" ;; *) bad "file:line and pattern (got: $r)" ;; esac
case "$r" in *"$TOK"*|*AKIA*) bad "the deny never prints the value, masked or not (got: $r)" ;; *) ok "the deny never prints the value, masked or not" ;; esac
case "$r" in *"CC_SECRET_COMMIT_SCAN=off"*) ok "the deny names the off switch" ;; *) bad "off switch (got: $r)" ;; esac
denies "git -C <dir> commit denies from another cwd" "$(hook "git -C $R commit -m x" "$T")"
denies "cd <dir> && git commit denies from another cwd" "$(hook "cd $R && git commit -m x" "$T")"
denies "an env prefix and a wrapper still match" "$(hook 'GIT_AUTHOR_NAME=x env FOO=1 git commit -qm wip')"
denies "a commit on a later line, its message from a heredoc, denies" "$(hook "$(printf 'npm test\ngit commit -F - <<%s\nfix: thing\n%s' "'EOF'" EOF)")"
denies "from a subdirectory the whole index is read" "$(hook 'git commit -m x' "$R/src")"
for c in 'git log --oneline -3' 'git commit --dry-run -m x' 'echo "git commit"' 'git status # git commit' 'git push --dry-run'; do
  silent "$c is silent with a staged secret" "$(hook "$c")"
done
silent "a commit through bash -c is not read (a stated miss)" "$(hook 'bash -c "git commit -m x"')"
export CC_SECRET_COMMIT_SCAN=off
silent "CC_SECRET_COMMIT_SCAN=off silences it" "$(hook 'git commit -m x')"
unset CC_SECRET_COMMIT_SCAN
export CLAUDE_PLUGIN_OPTION_CC_SECRET_COMMIT_SCAN=false
silent "the /config option cc_secret_commit_scan=false silences it" "$(hook 'git commit -m x')"
unset CLAUDE_PLUGIN_OPTION_CC_SECRET_COMMIT_SCAN
reset

printf 'clean\n' > "$R/c.txt"; g add c.txt
silent "a clean staged change is silent" "$(hook 'git commit -m clean')"
reset
printf '%s\n' "$FIX" > "$R/fixture.txt"; g add fixture.txt
silent "a staged placeholder value (the fixture escape) is silent" "$(hook 'git commit -m fixture')"
reset

printf 'k=%s\n' "$TOK" >> "$R/a.txt"
denies "-a with an unstaged tracked secret denies" "$(hook 'git commit -am wip')"
denies "--all denies too" "$(hook 'git commit --all -m wip')"
denies "a pathspec commit reads the working tree" "$(hook 'git commit a.txt -m wip')"
silent "a plain commit leaves the unstaged secret out, silent" "$(hook 'git commit -m "rename -a flag"')"
reset

printf 'k=%s\n' "$TOK" > "$R/new.txt"
denies "git add <untracked secret> && git commit denies" "$(hook 'git add new.txt && git commit -m x')"
denies "git add -A && git commit denies" "$(hook 'git add -A && git commit -m x')"
printf 'clean\n' > "$R/other.txt"
silent "git add <another file> && git commit leaves the untracked secret out" "$(hook 'git add other.txt && git commit -m x')"
silent "git add -u (tracked only) && git commit leaves it out" "$(hook 'git add -u && git commit -m x')"
silent "a heredoc body naming git add -A is no command" "$(hook "$(printf 'cat > notes.md <<%s\ngit add -A && git commit -m x\n%s\ngit status' EOF EOF)")"
reset

printf '== push\n'
printf 'k=%s\n' "$TOK" > "$R/s.txt"; g add s.txt; g commit -qm secret
printf 'clean\n' > "$R/s.txt"; g commit -qam scrub
out=$(hook 'git push')
denies "a secret in an earlier outgoing commit denies git push, though a later one removed it" "$out"
case "$(reason "$out")" in *"$(git -C "$R" rev-parse --short HEAD~1):s.txt:1 an AWS access key ID"*) ok "the push deny names commit:file:line" ;;
  *) bad "commit:file:line (got: $(reason "$out"))" ;; esac
denies "git -C <dir> push origin main denies" "$(hook "git -C $R push origin main" "$T")"
silent "git push -n stays silent" "$(hook 'git push -n')"
silent "a commit message whose heredoc body says git push is no push" "$(hook "$(printf 'git commit -F - <<%s\ngit push\n%s' EOF EOF)")"
g push -q
silent "once the secret is on the remote, git push is silent" "$(hook 'git push')"
g checkout -q -b feature
printf 'k=%s\n' "$TOK" > "$R/f.txt"; g add f.txt; g commit -qm feat; g checkout -q main
denies "a named refspec is read, not HEAD" "$(hook 'git push -u origin feature')"
silent "the same push by HEAD (main, all pushed) is silent" "$(hook 'git push origin HEAD')"
g checkout -q feature; g reset -q --hard main; g checkout -q main

printf '== fail open\n'
silent "a cwd outside any repository is silent" "$(hook 'git commit -m x' "$T")"
silent "a bad payload is silent" "$(printf 'not json commit' | bash "$H")"
mkdir -p "$T/copy/hooks"; cp "$H" "$T/copy/hooks/"
printf 'k=%s\n' "$TOK" > "$R/s2.txt"; g add s2.txt
silent "a missing scripts/scan-range.sh is silent" "$(jq -cn --arg d "$R" '{cwd:$d,tool_name:"Bash",tool_input:{command:"git commit -m x"}}' | bash "$T/copy/hooks/commit-scan.sh")"
reset
git -C "$R" config core.fsmonitor "touch $T/fsmonitor-ran; false"; printf 'more\n' >> "$R/a.txt"
hook 'git commit -am x' >/dev/null
[ ! -e "$T/fsmonitor-ran" ] && ok "a repository's core.fsmonitor command is not run by the hook's git calls" || bad "core.fsmonitor ran"
git -C "$R" config --unset core.fsmonitor; reset

jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | test("hooks/commit-scan.sh"))' \
  "$here/../../hooks/hooks.json" >/dev/null 2>&1 && ok "hooks.json registers commit-scan.sh on PreToolUse Bash" || bad "hooks.json registration"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
