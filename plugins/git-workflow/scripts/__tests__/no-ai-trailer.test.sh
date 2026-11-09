#!/usr/bin/env bash
# Tests plugins/git-workflow/hooks/no-ai-trailer.sh.
#
# Picked up by the repo's "Plugin author-time lint + harness tests" CI step,
# which globs plugins/*/scripts/__tests__/*.test.sh.
#
# Three sections:
#   1. CLASSIFICATION — commands that must be denied, and the ALLOW rows that
#      matter more: a guard that fires on `git log | grep co-authored` or on a
#      human co-author trailer gets switched off, and then it guards nothing.
#   2. HOOK PROTOCOL — real PreToolUse stdin for Bash and Write/Edit, the
#      deny JSON shape, the CLAUDE_AI_TRAILER=allow switch.
#   3. FAIL-OPEN — no jq, malformed JSON, empty input: silent, exit 0.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GUARD="$here/../../hooks/no-ai-trailer.sh"
BASH_BIN="$(command -v bash)"

[ -f "$GUARD" ] || { printf 'FAIL: guard not found at %s\n' "$GUARD"; exit 1; }
[ -x "$GUARD" ] || { printf 'FAIL: %s is not executable\n' "$GUARD"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }

pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

tier_of() { "$BASH_BIN" "$GUARD" --check "$1" >/dev/null 2>&1; case $? in 0) echo allow ;; 2) echo deny ;; *) echo error ;; esac; }
expect() { local want="$1" cmd="$2" got; got=$(tier_of "$cmd"); [ "$got" = "$want" ] && ok || bad "want $want, got $got" "$cmd"; }

TRAILER='Co-Authored-By: Claude <noreply@anthropic.com>'
GEN='🤖 Generated with [Claude Code](https://claude.com/claude-code)'

printf '== classification: deny\n'
expect deny "git commit -m \"feat: x

$TRAILER\""                                              # the shape observed on 2.1.266 with attribution.commit=""
expect deny "git commit -m \"feat: x\" -m \"$TRAILER\""
expect deny "git commit --amend -m \"fix: y

$GEN\""
expect deny "git commit --trailer 'Co-authored-by: Claude Opus <noreply@anthropic.com>' -m x"
expect deny "git -c user.name=x commit -F- <<EOF
feat: y

$GEN

$TRAILER
EOF"
expect deny "git commit -m \"\$(cat <<'EOF'
feat: z

co-authored-by: claude <noreply@anthropic.com>
EOF
)\""
expect deny "git merge --no-ff topic -m \"merge topic

$TRAILER\""
expect deny "git tag -a v1 -m \"v1

$TRAILER\""
expect deny "gh pr create --title t --body \"$GEN\""
expect deny "gh pr merge 12 --squash --body \"$TRAILER\""
expect deny "cd /repo && git add -A && git commit -m \"x

$TRAILER\""
expect deny "git commit -m 'x' -m 'Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>'"

printf '== classification: deny — git global options before the verb\n'
# Every one of these reaches a real commit and every one was ALLOWED until
# 2026-09-15. The bug hid because the then-current prefix matched the literal
# `.git` inside `--git-dir=/repo/.git commit` — right verdict, wrong reason — so
# the single form anyone had tested passed while the other eight did not.
expect deny "git --git-dir=/repo/.git commit -m \"x

$TRAILER\""
expect deny "git --git-dir /repo/bare commit -m \"x

$TRAILER\""
expect deny "git --work-tree=/tmp/wt commit -m \"x

$TRAILER\""
expect deny "git --work-tree /tmp/wt commit -m \"x

$TRAILER\""
expect deny "git --no-pager commit -m \"x

$TRAILER\""
expect deny "git -P commit -m \"x

$TRAILER\""
expect deny "git --namespace=ns commit -m \"x

$TRAILER\""
expect deny "git --exec-path=/usr/lib/git-core commit -m \"x

$TRAILER\""
expect deny "git -c user.email=x@y --no-pager commit -m \"x

$TRAILER\""
expect deny "git -C /repo --no-pager tag -a v1 -m \"x

$TRAILER\""
expect deny "bash -c 'git --no-pager commit -m \"x

$TRAILER\"'"

printf '== classification: deny — keyword and assignment command positions\n'
# The four shapes classify_command's own comment names as the reason the keyword/assignment
# prefix exists. The comment claimed they were "verified both directions by fixture" while
# none of them had one.
expect deny "if true; then git commit -m \"x

$TRAILER\"; fi"
expect deny "for f in a; do git commit -m \"x

$TRAILER\"; done"
expect deny "while :; do git commit -m \"x

$TRAILER\"; break; done"
expect deny "sudo git commit -m \"x

$TRAILER\""
expect deny "VAR=1 git commit -m \"x

$TRAILER\""
expect deny "GIT_AUTHOR_NAME=x GIT_AUTHOR_EMAIL=y git commit -m \"x

$TRAILER\""
expect deny "nohup timeout 30 git commit -m \"x

$TRAILER\""
expect deny "echo . | xargs git commit -m \"x

$TRAILER\""

printf '== classification: deny — the binary spelled with a path\n'
# The command-position anchor lists no `/`, so every one of these bypassed it. The
# pre-2026-09-15 loose prefix caught them by accident, which is the only reason the
# regression was visible at all: tightening the anchor turned the guard OFF for the
# most obvious wrapper there is — spelling out where git lives.
expect deny "/usr/bin/git commit -m \"x

$TRAILER\""
expect deny "/usr/local/bin/git commit -m \"x

$TRAILER\""
expect deny "./bin/git commit -m \"x

$TRAILER\""
expect deny "../git commit -m \"x

$TRAILER\""
expect deny "~/bin/git commit -m \"x

$TRAILER\""
expect deny "sudo /usr/bin/git commit -m \"x

$TRAILER\""
expect deny "cd /repo; /usr/bin/git --no-pager commit -m \"x

$TRAILER\""
expect deny "/opt/homebrew/bin/gh pr create --title t --body \"$TRAILER\""

printf '== classification: allow\n'
expect allow 'git commit -m "fix: drop the co-authored-by trailer from the release script"'
expect allow 'git log --format=%B | grep -i "co-authored-by: claude"'
expect allow 'grep -rn "Co-Authored-By: Claude" plugins/'
expect allow 'git commit -m "docs: credit" --trailer "Co-authored-by: Jane Doe <jane@example.com>"'
expect allow 'git commit -m "feat: add claude api client"'
expect allow 'git commit -m "chore: regenerate with claude-code chassis"'
expect allow 'git push origin HEAD'
# The path prefix must end in `/`, and `echo` is not a command position — neither of
# these runs git, and denying them would be the false positive the anchor exists to stop.
expect allow '/usr/share/digit commit -m "x co-authored-by: claude <noreply@anthropic.com>"'
expect allow 'echo "run /usr/bin/git commit later"  # co-authored-by: claude <noreply@anthropic.com>'
expect allow '/usr/bin/git --no-pager log | grep "co-authored-by: claude <noreply@anthropic.com>"'
# The option run accepts dash / path / assignment tokens only. It must not swallow a
# bare word, or `git --no-pager log | grep <trailer>` starts denying a read.
expect allow 'git --no-pager log --format=%B | grep -i "co-authored-by: claude"'
expect allow 'git status --short && echo "co-authored-by: claude was removed"'
expect allow 'git rev-parse HEAD  # co-authored-by: claude'
expect allow 'git show master:NOTES.md | grep "Generated with [Claude Code]"'
expect allow 'gh pr view 12 --json body'
expect allow 'echo "Co-Authored-By: Claude" > /tmp/scratch.txt'
expect allow ''

# The `(` delimiter is a stated residual, pinned in BOTH directions so a future
# "simplification" cannot quietly trade the guard's teeth for the false positive.
expect deny "echo \"see (git commit -m 'x $TRAILER')\""   # residual FP, documented in the header
expect deny "bash -c 'git commit -m \"x $TRAILER\"'"      # must stay denied: the quote tokens earn their place
expect deny "sh -c 'git commit -m \"x $TRAILER\"'"
expect deny "eval 'git commit -m \"x $TRAILER\"'"

printf '== classification: allow — the trailer sits outside the git write (retro #22)\n'
# Each was denied through 0.13.7, which matched the trailer and the verb anywhere in the command: a heredoc body's
# `- git commit` bullet read as a command, and a trailer in a grep, echo or heredoc lent itself to a clean commit.
# The first two replay the retro's findings.md firing (f5ffe3b6, 2026-11-05): its visible head, plus a reconstructed
# bullet and the clean commit chained after it, since the extract clipped the input at 300 characters.
expect allow "cat >> .claude/overseer/milestones/m5/findings.md <<'EOF'
# m5 findings / backlog
- card 01 review (medium): Opponents.cs:41 RoyalFuryFirstTurn defaults to 4
- low: the template still adds $TRAILER
EOF
git add -A && git commit -q -F - <<'EOF'
m5 card 01: tunables and the Royal Fury formula
EOF"
expect allow "cat >> findings.md <<'EOF'
- git commit -m x used to carry $TRAILER
EOF"
expect allow "cat > probe.sh <<'EOF'
probe \"git commit -q -F - <<'X'
$TRAILER
X\"
EOF"
expect allow "git commit -m \"card 01\" && git log -1 --format=%B | grep -ci \"co-authored-by: claude\""
expect allow "grep -l \"$TRAILER\" .git/COMMIT_EDITMSG; git commit -m clean"
expect allow "printf '%s\n' \"$TRAILER\" > /tmp/t.txt; git tag v1 -m release"
expect allow "python3 - <<'EOF'
TRAILER = '$TRAILER'
EOF
git commit -m 'feat: scrubber'"
expect allow "git commit -m x 2>&1 | tee log; echo '$TRAILER' >> notes"
expect allow "git commit -m \"x\" & echo '$TRAILER'"
expect allow "cat <<'EOF' > .claude/notes.md
gh pr create --body \"$GEN\"
EOF"
expect allow "grep -c \"$TRAILER\" log; git commit -q -F - <<'EOF'
Code review since fe42cc2: 21 fixes to spell rules, the Shop chest and spell looks

- Legendary and Frost/Grass gates read a new bestCheckpoint that Molt keeps
EOF"
expect allow "echo '$TRAILER' >> notes; git commit -F - <<< 'feat: clean'"
# Quoted message text is not a variable, substitution or -F/-t option.
expect allow "echo '$TRAILER' >> notes; git commit -m \"add -f flag\""
expect allow "echo '$TRAILER' >> notes; git commit -m 'costs \$5, see \`make -t\`'"
expect allow "echo '$TRAILER' >> notes; git commit -m \"costs \\\$5, see \\\`make\\\`\""

printf '== classification: deny — the message reaches the git write another way\n'
# The same split must keep these: the message comes through a pipe, a here-string, a variable, a substitution,
# a file written earlier in the same command, or a shell reading a heredoc. Each was denied before the split too.
expect deny "git add -A && git commit -q -F - <<'EOF'
Code review since fe42cc2: 21 fixes to spell rules

$TRAILER
EOF"
expect deny "cat >> findings.md <<'EOF'
- card 01 committed
EOF
git add -A && git commit -F - <<'EOF'
card 01

$TRAILER
EOF"
expect deny "cat <<'EOF' | git commit -F -
x

$TRAILER
EOF"
expect deny "printf 'x\n\n%s\n' '$TRAILER' | git commit -F -"
expect deny "git commit -F - <<< \"x

$TRAILER\""
expect deny "msg='x

$TRAILER'; git commit -m \"\$msg\""
expect deny "cat > /tmp/m <<'EOF'
x

$TRAILER
EOF
git commit -F /tmp/m"
expect deny "printf '%s\n' '$GEN' > body.md && gh pr edit 12 --body-file body.md"
expect deny "git commit -m \"\$(cat /tmp/msg)\" && echo '$TRAILER'"
expect deny "git commit -F <(printf 'x\n\n%s' '$TRAILER')"
expect deny "git commit -m \"\$(cat <<'EOF'
fix: don't \"quote\" this; really

$TRAILER
EOF
)\""
expect deny "gh pr create --title t --body \"\$(cat <<'EOF'
## Summary
- a; b | c (twice)

$GEN
EOF
)\""
expect deny "git commit -F - <<-EOF
	x

	$TRAILER
	EOF"
expect deny "git commit -F - <<EOF && git push
x

$TRAILER
EOF"
expect deny "bash <<'EOF'
git commit -m \"x

$TRAILER\"
EOF"
expect deny "(cd /repo && git commit -m \"x

$TRAILER\")"
expect deny "# don't forget
git commit -m \"x

$TRAILER\""
expect deny "git commit -m \"x\" \\
  -m \"$TRAILER\""
expect deny "git commit -m \"feat: a) b

$TRAILER\""
expect deny "echo \$((1<<2)); git commit -m \"x $TRAILER\""          # unsplittable: judged whole
expect deny "cat > /tmp/m <<'EOF'
$TRAILER
EOF
git commit -F \"/tmp/m\""

printf '== classification: deny — a pipe across a line break, from a group, or |&\n'
# The rows ending in xargs or git am carry no stdin value, so only the splitter keeps them denied.
expect deny "printf '%s\n' x '' '$TRAILER' |
git commit -F -"
expect deny "{ echo x; echo; echo \"$TRAILER\"; } | git commit -F -"
expect deny "( echo x; echo; echo \"$TRAILER\" ) | git commit -F -"
expect deny "printf 'x\n\n%s\n' '$TRAILER' |& git commit -F -"
expect deny "printf '%s\n' x '' '$TRAILER' |
xargs -0 git commit -m"
expect deny "printf '%s\n' x '' '$TRAILER' | # the message
# then the commit
xargs -0 git commit -m"
expect deny "cat <<'EOF' |
x

$TRAILER
EOF
xargs -0 git commit -m"
expect deny "{ echo x; echo \"$TRAILER\"; } | xargs -0 git commit -m"
expect deny "( echo x; echo \"$TRAILER\" ) | xargs -0 git commit -m"
expect deny "{ echo x
echo \"$TRAILER\"
} |
git am"
expect deny "printf 'x\n\n%s\n' '$TRAILER' |& xargs -0 git commit -m"

printf '== classification: deny — stdin read from a file the same command wrote\n'
expect deny "printf 'x\n\n%s\n' \"$TRAILER\" > /tmp/m; git commit -F - < /tmp/m"
expect deny "printf 'x\n\n%s\n' \"$TRAILER\" > /tmp/m && cat /tmp/m | git commit -F -"
expect deny "printf 'x\n\n%s\n' \"$TRAILER\" > /tmp/m; git commit -F- < /tmp/m"
expect deny "printf 'x\n\n%s\n' \"$TRAILER\" > /tmp/m; cat /tmp/m | git commit --file=-"
expect deny "printf '%s\n' '$GEN' > b.md; cat b.md | gh pr create --title t --body-file -"
expect deny "printf '%s\n' '$GEN' > n.md; gh release create v1 --notes-file - < n.md"
expect deny "printf 'x\n\n%s\n' \"$TRAILER\" > /tmp/m; git am < /tmp/m"
expect deny "git notes add -m \"$TRAILER\" HEAD"
expect deny "gh release create v1 --notes \"$GEN\""

printf '== hook protocol\n'
payload() { # tool_name command
  jq -cn --arg t "$1" --arg c "$2" '{session_id:"s1",transcript_path:"/tmp/t.jsonl",hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$c}}'
}
out=$(payload Bash "git commit -m \"x

$TRAILER\"" | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && ok || bad "deny path must exit 0, got $rc" "Bash deny"
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "expected permissionDecision deny" "$out"
printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null 2>&1 && ok || bad "expected hookEventName PreToolUse" "$out"
printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -q 'Co-Authored-By' && ok || bad "reason must name the trailer" "$out"
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason')" = 'git-workflow blocked AI attribution in this commit, merge, tag or PR: remove the "Co-Authored-By: Claude …" trailer and any "Generated with Claude Code" line, then run the same command again (not through a message file). CLAUDE_AI_TRAILER=allow, set by the user, turns this guard off.' ] \
  && ok || bad "reason: what was blocked, the fix, one off switch" "$out"

out=$(payload Bash 'git commit -m "fix: y"' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "clean commit must be silent" "rc=$rc out=$out"

out=$(payload Bash "cat >> .claude/overseer/milestones/m5/findings.md <<'EOF'
- low: the template still adds $TRAILER
EOF
git add -A && git commit -q -m \"m5 card 01\"" | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "retro #22 replay: an append beside a clean commit must be silent" "rc=$rc out=$out"

out=$(payload mcp__phpstorm__execute_terminal_command "git commit -m \"x

$TRAILER\"" | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "MCP terminal tool must be classified too" "$out"

out=$(jq -cn --arg c "$TRAILER" '{session_id:"s1",transcript_path:"/tmp/t.jsonl",hook_event_name:"PreToolUse",tool_name:"Write",tool_input:{file_path:"/repo/.git/COMMIT_EDITMSG",content:("x\n\n"+$c)}}' | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "Write into COMMIT_EDITMSG must be denied" "$out"

out=$(jq -cn --arg c "$TRAILER" '{tool_name:"Edit",tool_input:{file_path:"/repo/.git/MERGE_MSG",old_string:"x",new_string:$c}}' | "$BASH_BIN" "$GUARD")
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok || bad "Edit into MERGE_MSG must be denied" "$out"

out=$(jq -cn --arg c "$TRAILER" '{tool_name:"Write",tool_input:{file_path:"/repo/docs/history.md",content:$c}}' | "$BASH_BIN" "$GUARD")
[ -z "$out" ] && ok || bad "a doc mentioning the trailer is not a git message file" "$out"

out=$(payload Bash "git commit -m \"x

$TRAILER\"" | CLAUDE_AI_TRAILER=allow "$BASH_BIN" "$GUARD")
[ -z "$out" ] && ok || bad "CLAUDE_AI_TRAILER=allow must disable the guard" "$out"

printf '== fail-open\n'
out=$(printf 'not json' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "malformed input must be silent exit 0" "rc=$rc out=$out"
out=$(printf '' | "$BASH_BIN" "$GUARD"); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "empty input must be silent exit 0" "rc=$rc out=$out"
out=$(payload Bash "git commit -m \"$TRAILER\"" | PATH=/nonexistent "$BASH_BIN" "$GUARD" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok || bad "no jq on PATH must be silent exit 0" "rc=$rc out=$out"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
