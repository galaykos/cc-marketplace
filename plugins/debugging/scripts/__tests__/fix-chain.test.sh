#!/usr/bin/env bash
# Harness for hooks/fix-chain.sh. Load-bearing: two fix commits on one file after the session's first prompt speak once;
# the neighbours stay silent (fix commits on different files, non-fix commits, commits before the session, CC_REMIND=off).
set -u
here=$(cd "$(dirname "$0")" && pwd)
H="$here/../../hooks/fix-chain.sh"
[ -x "$H" ] || { printf 'FAIL: fix-chain.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export TMPDIR="$T/tmp"; mkdir -p "$TMPDIR"
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }

R="$T/repo"; mkdir -p "$R"; git -C "$R" init -q -b main; git -C "$R" config user.email t@t; git -C "$R" config user.name t
commit() { # <file> <subject> [date]
  printf '%s\n' "$RANDOM" >> "$R/$1"; git -C "$R" add -A
  if [ -n "${3:-}" ]; then GIT_COMMITTER_DATE="$3" git -C "$R" commit -qm "$2" --date "$3"; else git -C "$R" commit -qm "$2"; fi
}
prompt() { # <transcript> [prompt]
  jq -cn --arg c "$R" --arg t "$1" --arg p "${2:-it is still broken}" \
    '{session_id:"s", transcript_path:$t, cwd:$c, hook_event_name:"UserPromptSubmit", prompt:$p}' | bash "$H"
}
silent() { [ -z "$2" ] && ok "$1" || bad "$1 (got: $2)"; }

commit app.php "Fix checkout total" "2020-01-01T00:00:00"
commit app.php "fix: rounding" "2020-01-02T00:00:00"
out=$(prompt /t/a.jsonl); silent "first prompt only records the session start" "$out"
out=$(prompt /t/a.jsonl); silent "fix commits from before the session do not count" "$out"

sleep 1
commit app.php "Fix credits not deducted"
out=$(prompt /t/a.jsonl); silent "one fix commit in the session is silent" "$out"
commit README.md "Update docs"
commit app.php "fixes #69: purchase total"
out=$(prompt /t/a.jsonl)
printf '%s' "$out" | grep -q '2 fix commits this session touch app.php' && ok "two fix commits on one file speak" || bad "two fix commits (got: $out)"
out=$(prompt /t/a.jsonl); silent "it speaks once per level" "$out"
commit app.php "hotfix: webhook"
commit app.php "Bugfix: retry"
out=$(prompt /t/a.jsonl)
printf '%s' "$out" | grep -q '4 fix commits' && ok "it speaks again at four" || bad "four (got: $out)"

sleep 1; out=$(prompt /t/b.jsonl); silent "another transcript starts its own count" "$out"
sleep 1
commit one.php "Fix one"; commit two.php "Fix two"
out=$(prompt /t/b.jsonl); silent "fix commits on different files are silent" "$out"

commit two.php "fix two again"
out=$(CC_REMIND=off prompt /t/b.jsonl); silent "CC_REMIND=off silences it" "$out"

out=$(printf 'not json' | bash "$H"); rc=$?
[ -z "$out" ] && [ "$rc" = 0 ] && ok "malformed payload fails open" || bad "malformed payload (rc=$rc)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
