#!/usr/bin/env bash
# Harness for worker-check.sh. Load-bearing: a commit on another branch after registration is reported, a
# comment-heavy worker diff is reported, and the neighbours stay silent (the run's own commits, track branches,
# a normal diff with a few comments, a shebang, PHP attributes).
set -u
here=$(cd "$(dirname "$0")" && pwd)
W="$here/../worker-check.sh"
[ -x "$W" ] || { printf 'FAIL: worker-check.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

R="$T/repo"; mkdir -p "$R"; cd "$R" || exit 1
git init -q -b main; git config user.email t@t; git config user.name t
printf 'x\n' > a.txt; git add a.txt; GIT_COMMITTER_DATE='2020-01-01T00:00:00' git commit -qm init --date 2020-01-01
git branch other
git switch -q -c feature
start=$(git rev-parse HEAD)
mkdir -p .claude/task-runner
printf '{"slug":"s","base":"%s","branch":"feature","start_sha":"%s"}\n' "$start" "$start" > .claude/task-runner/active-run.json
touch -d '1 minute ago' .claude/task-runner/active-run.json

expect() { # name rc grep
  out=$(bash "$W" 2>&1); rc=$?
  if [ "$rc" = "$2" ] && { [ -z "$3" ] || printf '%s' "$out" | grep -q "$3"; }; then ok "$1"; else bad "$1 (rc=$rc out=$out)"; fi
}

expect "fresh run, nothing changed: clean" 0 ""

printf 'def f():\n    return 1\n' > impl.py; git add impl.py; git commit -qm "card 1"
expect "the run's own commit is not stray" 0 ""

git branch feature-track-ui; git switch -q feature-track-ui; printf 'y\n' > t.txt; git add t.txt; git commit -qm track; git switch -q feature
expect "a track branch is not stray" 0 ""

git switch -q other; printf 'z\n' > o.txt; git add o.txt; git commit -qm "harness slip"; git switch -q feature
expect "a commit on another branch after registration is stray" 1 "stray-commit: branch other"
git branch -f other "$start"
touch -d '1 minute ago' .claude/task-runner/active-run.json

{ printf '#!/usr/bin/env python3\n'; for i in $(seq 1 30); do printf '# explain step %s\nx%s = %s\n' "$i" "$i" "$i"; done; } > heavy.py
expect "untracked comment-heavy file is reported" 1 "comment-heavy: 30 of 63"
rm heavy.py

{ for i in $(seq 1 30); do printf '# explain step %s\nx%s = %s\n' "$i" "$i" "$i"; done; } > old.py
touch -d '2 hours ago' old.py
expect "untracked comment-heavy file older than the run is not reported" 0 ""
rm old.py

{ for i in $(seq 1 40); do printf 'const v%s = %s;\n' "$i" "$i"; done; printf '// why: the API caps at 40\n'; } > light.ts
git add light.ts; git commit -qm "card 2"
expect "a normal diff with one why-comment is clean" 0 ""

{ printf '<?php\n'; for i in $(seq 1 25); do printf '#[Attr%s]\nfunction f%s() {}\n' "$i" "$i"; done; } > attrs.php
git add attrs.php; git commit -qm "card 3"
expect "PHP attributes are code, not comments" 0 ""

{ for i in $(seq 1 25); do printf '/**\n * Does thing %s.\n */\nfunction g%s() {}\n' "$i" "$i"; done; } > doc.ts
git add doc.ts; git commit -qm "card 4"
expect "docblock-heavy committed diff is reported" 1 "comment-heavy"

out=$(bash "$W" --since deadbeef 2>&1); rc=$?
[ "$rc" = 3 ] && ok "unresolvable --since is a usage error" || bad "unresolvable --since (rc=$rc)"
rm .claude/task-runner/active-run.json
out=$(bash "$W" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "no registered run is a usage error" || bad "no run (rc=$rc)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
