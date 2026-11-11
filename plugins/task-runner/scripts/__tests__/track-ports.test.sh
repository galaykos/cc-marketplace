#!/usr/bin/env bash
# Harness for track-ports.sh. Load-bearing: two tracks never get one port, a worktree claims from the main
# repository's registry, and a port something listens on is skipped, so a clean claim is not vacuous.
set -u
here=$(cd "$(dirname "$0")" && pwd)
C="$here/../track-ports.sh"
[ -x "$C" ] || { printf 'FAIL: track-ports.sh not executable\n'; exit 1; }
pass=0; fail=0
T=$(mktemp -d); trap 'kill "${LPID:-}" 2>/dev/null; rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s\n' "$1"; fail=$((fail+1)); }
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

R="$T/repo"; mkdir -p "$R"
git -C "$R" init -q && git -C "$R" config user.email t@t.t && git -C "$R" config user.name t \
  && echo a > "$R/a.txt" && git -C "$R" add a.txt && git -C "$R" commit -qm seed || { printf 'FAIL: cannot build a repository\n'; exit 1; }
BASE=47100
run() { (cd "$1" && shift && bash "$C" "$@" 2>&1); }
expect() { # name rc grep cwd args...
  local name=$1 want=$2 has=$3 cwd=$4; shift 4
  out=$(run "$cwd" "$@"); rc=$?
  if [ "$rc" = "$want" ] && { [ -z "$has" ] || printf '%s' "$out" | grep -q -- "$has"; }; then ok "$name"; else bad "$name (rc=$rc out=$out)"; fi
}

expect "the first claim gets the base block" 0 "Ports 47100-47109 are this track's (alpha)" "$R" claim --id alpha --base $BASE
expect "a second track gets the next block" 0 "Ports 47110-47119 are this track's (beta)" "$R" claim --id beta --base $BASE
expect "claiming again returns the same block" 0 "Ports 47100-47109" "$R" claim --id alpha --base $BASE
expect "list names both claims" 0 "beta 47110-47119" "$R" list
[ -f "$R/.claude/task-runner/.gitignore" ] && ok "the registry is gitignored" || bad "no .gitignore beside the registry"

git -C "$R" worktree add -q "$T/wt" -b track-x 2>/dev/null
expect "a worktree sees the main repository's claims" 0 "Ports 47120-47129 are this track's (gamma)" "$T/wt" claim --id gamma --base $BASE
[ ! -e "$T/wt/.claude/task-runner/ports" ] && ok "nothing is written inside the worktree" || bad "the worktree got its own registry"

expect "release frees the block" 0 "" "$R" release --id alpha
expect "the freed block is handed out again" 0 "Ports 47100-47109 are this track's (delta)" "$R" claim --id delta --base $BASE
expect "releasing an unknown id is not an error" 0 "" "$R" release --id nobody

expect "a count sizes the block" 0 "Ports 47130-47132 are this track's (small)" "$R" claim --id small --count 3 --base $BASE

if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import socket,time,sys
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", 47205)); s.listen(1); print("up", flush=True); time.sleep(60)' > "$T/up" 2>/dev/null &
  LPID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [ -s "$T/up" ] && break; sleep 0.1; done
  if [ -s "$T/up" ]; then
    expect "a block holding a listening port is skipped" 0 "Ports 47210-47219 are this track's (busy)" "$R" claim --id busy --base 47200
  else
    printf 'SKIP: could not open a listener on 47205\n'
  fi
  kill "$LPID" 2>/dev/null
else
  printf 'SKIP: listening-port case (python3 is required)\n'
fi

mkdir -p "$R/.claude/task-runner/ports/.lock"; touch -d '5 minutes ago' "$R/.claude/task-runner/ports/.lock"
expect "a lock left by a killed run is taken over" 0 "this track's (late)" "$R" claim --id late --base $BASE

expect "an id with a slash is a usage error" 3 "usage" "$R" claim --id ../x
expect "claim with no id is a usage error" 3 "usage" "$R" claim
expect "a privileged base is a usage error" 3 "usage" "$R" claim --id low --base 80
expect "a zero count is a usage error" 3 "usage" "$R" claim --id z --count 0
expect "an unknown mode is a usage error" 3 "usage" "$R" grab --id z
expect "outside a repository is a usage error" 3 "not inside a git repository" "$T" claim --id z
expect "the last block under the port ceiling is claimable" 0 "Ports 65526-65535" "$R" claim --id top --base 65526
expect "no block left under the ceiling exits 1" 1 "no free block" "$R" claim --id over --base 65526

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" = 0 ]
