#!/usr/bin/env bash
# commit-scan.test.sh — hooks/commit-scan.sh on real PreToolUse Bash payloads in a scratch repository with bare remotes: each way a commit or push records or sends a secret denies, naming file:line and the label, never the value, beside the nearest neighbour that stays silent;
#   no repository's fsmonitor, filter or gpg.program command runs. Not covered: the host killing the hook, bash 3.2 and BSD find (run on Linux), a URL naming origin's repository.
#   Secret shapes are assembled at runtime: the write guard would deny a write of this file.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/hooks/commit-scan.sh
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
case "$r" in ''|*"$TOK"*|*AKIA*) bad "the deny never prints the value, masked or not (got: ${r:-<no reason>})" ;; *) ok "the deny never prints the value, masked or not" ;; esac
case "$r" in *"CC_SECRET_COMMIT_SCAN=off"*) ok "the deny names the off switch" ;; *) bad "off switch (got: $r)" ;; esac
denies "git -C <dir> commit denies from another cwd" "$(hook "git -C $R commit -m x" "$T")"
denies "cd <dir> && git commit denies from another cwd" "$(hook "cd $R && git commit -m x" "$T")"
denies "an env prefix and a wrapper still match" "$(hook 'GIT_AUTHOR_NAME=x env FOO=1 git commit -qm wip')"
denies "a commit on a later line, its message from a heredoc, denies" "$(hook "$(printf 'npm test\ngit commit -F - <<%s\nfix: thing\n%s' "'EOF'" EOF)")"
denies "from a subdirectory the whole index is read" "$(hook 'git commit -m x' "$R/src")"
for c in 'git log --oneline -3' 'git commit --dry-run -m x' 'echo "git commit"' 'git status # git commit'; do
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

printf 'k=%s\n' "$TOK" > "$R/s.txt"; g add s.txt; printf 'clean\n' > "$R/s.txt"; printf 'notes\n' > "$R/notes.md"
denies "git add <other> && git commit still reads a staged secret the working tree has dropped" "$(hook 'git add notes.md && git commit -m x')"
denies "so does git commit -i <other>" "$(hook 'git commit -i a.txt -m x')"
reset
printf 'clean\n' > "$R/s.txt"; g add s.txt; printf 'notes\n' > "$R/notes.md"
silent "git add <other> && git commit with a staged file clean in index and tree is silent" "$(hook 'git add notes.md && git commit -m x')"
reset

printf 'k=%s\n' "$TOK" > "$R/new.txt"
denies "git add <untracked secret> && git commit denies" "$(hook 'git add new.txt && git commit -m x')"
denies "git add -A && git commit denies" "$(hook 'git add -A && git commit -m x')"
printf 'clean\n' > "$R/other.txt"
silent "git add <another file> && git commit leaves the untracked secret out" "$(hook 'git add other.txt && git commit -m x')"
silent "git add -u (tracked only) && git commit leaves it out" "$(hook 'git add -u && git commit -m x')"
silent "a heredoc body naming git add -A is no command" "$(hook "$(printf 'cat > notes.md <<%s\ngit add -A && git commit -m x\n%s\ngit status' EOF EOF)")"
denies "git add \"\$f\" && git commit reads every untracked file" "$(hook 'f=new.txt; git add "$f" && git commit -m x')"
silent "git add -p (tracked hunks only) && git commit leaves it out" "$(hook 'git add -p && git commit -m x')"
reset
printf 'clean\n' > "$R/other.txt"
silent "git add \"\$f\" && git commit with only clean untracked files is silent" "$(hook 'f=other.txt; git add "$f" && git commit -m x')"
reset
{ printf 'k=%s\n' "$TOK"; head -c 1048576 /dev/zero | tr '\0' a | fold -w 100; } > "$R/big.txt"
silent "an untracked file over 1 MiB is not read (MAX_FILE_BYTES, a stated miss)" "$(hook 'git add big.txt && git commit -m x')"
g add big.txt
silent "a staged file over 1 MiB diffs as binary, unread" "$(hook 'git commit -m x')"
reset
{ printf 'k=%s\n' "$TOK"; head -c 1000000 /dev/zero | tr '\0' a | fold -w 100; } > "$R/big.txt"
denies "an untracked file under 1 MiB is still read" "$(hook 'git add big.txt && git commit -m x')"
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
silent "git push --dry-run stays silent" "$(hook 'git push --dry-run')"
printf '#!/bin/sh\ntouch "%s/gpg-ran"\nexit 1\n' "$T" > "$T/gpg"; chmod +x "$T/gpg"
g update-ref refs/heads/main "$(git -C "$R" cat-file commit HEAD | awk '/^committer /{ print; print "gpgsig -----BEGIN PGP SIGNATURE-----"; print " x"; print " -----END PGP SIGNATURE-----"; next } 1' \
  | git -C "$R" hash-object -t commit -w --stdin)"
git -C "$R" config log.showSignature true; git -C "$R" config gpg.program "$T/gpg"
denies "a signed outgoing commit is read" "$(hook 'git push')"
[ ! -e "$T/gpg-ran" ] && ok "a repository's gpg.program does not run under log.showSignature" || bad "gpg.program ran"
git -C "$R" config --unset log.showSignature; git -C "$R" config --unset gpg.program
silent "a commit message whose heredoc body says git push is no push" "$(hook "$(printf 'git commit -F - <<%s\ngit push\n%s' EOF EOF)")"
g push -q
silent "once the secret is on the remote, git push is silent" "$(hook 'git push')"
g checkout -q -b feature
printf 'k=%s\n' "$TOK" > "$R/f.txt"; g add f.txt; g commit -qm feat; g checkout -q main
denies "a named refspec is read, not HEAD" "$(hook 'git push -u origin feature')"
silent "the same push by HEAD (main, all pushed) is silent" "$(hook 'git push origin HEAD')"
g checkout -q feature; g reset -q --hard main; g checkout -q main

printf '== what a push sends, and where\n'
g push -q origin feature
g checkout -q -b wip; printf 'k=%s\n' "$TOK" > "$R/w.txt"; g add w.txt; g commit -qm wip; g checkout -q main
g config push.default matching
silent "push.default=matching leaves a branch the remote lacks out" "$(hook 'git push')"
g checkout -q feature; printf 'k=%s\n' "$TOK" > "$R/f.txt"; g add f.txt; g commit -qm feat; g checkout -q main
denies "push.default=matching reads every branch the remote also has" "$(hook 'git push')"
g config --unset push.default
silent "the default push.default reads the current branch only" "$(hook 'git push')"
g config remote.origin.push refs/heads/feature:refs/heads/feature
denies "a remote.<name>.push refspec is read" "$(hook 'git push')"
g config --unset remote.origin.push
denies "a refspec held in a variable reads every branch" "$(hook 'b=main; git push origin "$b"')"
denies "a glob refspec reads every branch" "$(hook "git push origin 'refs/heads/*:refs/heads/*'")"
git init -q --bare "$T/mirror.git"; g remote add mir "$T/mirror.git"; g push -q mir main
silent "a push to another remote already holding main is silent" "$(hook 'git push mir')"
g config remote.mir.mirror true
denies "a mirror remote reads every branch" "$(hook 'git push mir')"
g config --unset remote.mir.mirror
git init -q --bare "$T/public.git"; g remote add public "$T/public.git"
denies "a push to a new remote reads history only another remote holds" "$(hook 'git push public main')"
denies "so does --repo=<remote>" "$(hook 'git push --repo=public')"
denies "and a path for a remote" "$(hook "git push $T/public.git main")"
silent "the same push to the remote holding it is silent" "$(hook 'git push origin main')"
silent "a remote held in a variable counts every remote-tracking ref (a stated miss)" "$(hook 'r=public; git push "$r" main')"
mkdir -p "$T/cap/hooks" "$T/cap/scripts"; cp "$here/../../hooks/patterns.sh" "$here/../../hooks/patterns.tsv" "$T/cap/hooks/"
cp "$here/../scan-range.sh" "$T/cap/scripts/"; sed 's/^MAX_PUSH_COMMITS=.*/MAX_PUSH_COMMITS=2/' "$H" > "$T/cap/hooks/commit-scan.sh"
H0=$H; H="$T/cap/hooks/commit-scan.sh"
printf 'k=%s\n' "$TOK" > "$R/n.txt"; g add n.txt; g commit -qm new
denies "past MAX_PUSH_COMMITS for the destination, the commits no remote holds are still read" "$(hook 'git push public main')"
g reset -q --hard HEAD~1
silent "and past it with every commit on some remote nothing is read (a stated miss)" "$(hook 'git push public main')"
H=$H0
g branch -D wip; g checkout -q feature; g reset -q --hard main; g checkout -q main
silent "a refspec held in a variable, every branch already pushed, is silent" "$(hook 'b=main; git push origin "$b"')"

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
git -C "$R" config filter.mk.clean "touch $T/filter-ran; cat"; git -C "$R" config filter.mk.required true
printf '*.txt filter=mk\n' > "$R/.git/info/attributes"; printf 'k=%s\n' "$TOK" >> "$R/a.txt"
out=$(hook 'git commit -am x')
[ ! -e "$T/filter-ran" ] && ok "a repository's clean filter is not run by the hook's worktree diff" || bad "the clean filter ran"
denies "with its filters blanked the worktree diff is still read" "$out"
git -C "$R" config --remove-section filter.mk; rm -f "$R/.git/info/attributes"; reset
S="$T/subrepo"; git init -q -b main "$S"; printf 'a\n' > "$S/a.txt"; printf '*.txt filter=sm\n' > "$S/.gitattributes"
git -C "$S" add -A; git -C "$S" -c user.email=t@t -c user.name=t commit -qm s
g -c protocol.file.allow=always submodule add -q "$S" sub; g commit -qm sub
git -C "$R/sub" config filter.sm.clean "touch $T/sub-filter-ran; cat"; touch -t 200001010000 "$R/sub/a.txt"; printf 'more\n' >> "$R/a.txt"
hook 'git commit -am x' >/dev/null
[ ! -e "$T/sub-filter-ran" ] && ok "a submodule's clean filter is not run either" || bad "the submodule's clean filter ran"

jq -e '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | test("hooks/commit-scan.sh"))' \
  "$here/../../hooks/hooks.json" >/dev/null 2>&1 && ok "hooks.json registers commit-scan.sh on PreToolUse Bash" || bad "hooks.json registration"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
