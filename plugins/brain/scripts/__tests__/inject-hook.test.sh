#!/usr/bin/env bash
# Smoke tests for brain/hooks/inject.sh — the SessionStart hook that injects brain/INDEX.md
# with a staleness hint. Branches: a map built at HEAD → no hint; a commit touching only
# brain/ (the map's own commit) → no hint; ≤5 files changed outside brain/ → the "refresh
# now" imperative with a count; more → the passive offer; an active task-runner run →
# the passive offer; an unreachable `built:` hash → the passive offer with no count;
# malformed payload → silent exit 0; no map → the nudge on a project's first startup only, never on compact/resume.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/brain/hooks/inject.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
rc=0
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: ${2:-<none>} want: ${3:-<none>}"; rc=1; fi; }
g() { git -C "$REPO" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
run() { jq -n --arg c "$REPO" '{hook_event_name:"SessionStart",cwd:$c}' | env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>/dev/null; }
hint() { run | grep -o '⚠ brain map is behind HEAD[^—]*— [A-Za-z]*' | head -1; }
stamp() { # write the map stamped at the current HEAD, as the indexer does
  mkdir -p "$REPO/brain"
  printf 'built: %s · 1 areas · 1 files\n# Index\n- app\n' "$(git -C "$REPO" rev-parse --short HEAD)" > "$REPO/brain/INDEX.md"
}

mkdir -p "$REPO"; g init -q; echo a > "$REPO/a.txt"; g add -A; g commit -qm init
stamp
check "1 a map built at HEAD prints the map and no hint" "$(run | grep -c 'BRAIN MAP (project data)')$(hint)" "1"

g add -A; g commit -qm "brain: map"
check "2 the map's own commit is not drift" "$(hint)" ""

echo b > "$REPO/b.txt"; g add -A; g commit -qm b
check "3 one file outside brain/ orders the refresh" "$(hint)" "⚠ brain map is behind HEAD (built $(head -1 "$REPO/brain/INDEX.md" | awk '{print $2}'), 1 files changed) — Claude"

for i in 1 2 3 4 5 6; do echo "$i" > "$REPO/f$i.txt"; done; g add -A; g commit -qm many
check "4 more than five files is the passive offer" "$(hint | sed 's/.*— //')" "offer"

stamp; g add -A; g commit -qm "brain: refresh"; echo c > "$REPO/c.txt"; g add -A; g commit -qm c
mkdir -p "$REPO/.claude/task-runner"; echo '{}' > "$REPO/.claude/task-runner/scope.json"
check "5 an active task-runner run demotes the imperative to the offer" "$(hint | sed 's/.*— //')" "offer"
rm -rf "$REPO/.claude"

printf 'built: deadbeef · 1 areas · 1 files\n# Index\n' > "$REPO/brain/INDEX.md"
check "6 an unreachable built hash is the offer with no count" "$(hint)" "⚠ brain map is behind HEAD (built deadbeef) — offer"

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "7 malformed payload fails open" "$out" "rc=0"

# The no-map nudge prints on the first startup in a project only: resume, clear and compaction
# reprinted it before 0.4.5, and every new session did before 0.4.6 (45 fires, 0 maps, 2026-10-21).
export CLAUDE_PLUGIN_DATA="$TMP/plugin-data"
mkrepo() { mkdir -p "$1"; git -C "$1" init -q; for i in $(seq 1 200); do : > "$1/s$i.txt"; done; git -C "$1" add -A; }
nudge() { # $1 source ("" = none), $2 repo
  jq -n --arg c "$2" --arg s "$1" '{hook_event_name:"SessionStart",cwd:$c} + (if $s == "" then {} else {source:$s} end)' \
  | env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>/dev/null | grep -c 'no map for this project yet'; }
NOMAP="$TMP/nomap"; mkrepo "$NOMAP"
check "10 compact is silent" "$(nudge compact "$NOMAP")" "0"
check "11 resume is silent" "$(nudge resume "$NOMAP")" "0"
check "8 the first startup in a project prints the no-map nudge" "$(nudge startup "$NOMAP")" "1"
check "12 the second startup in the same project is silent" "$(nudge startup "$NOMAP")" "0"
check "13 the once-per-project marker is on disk" "$(find "$CLAUDE_PLUGIN_DATA" -name nudged -type f | grep -c .)" "1"
NOMAP2="$TMP/nomap2"; mkrepo "$NOMAP2"
check "9 a payload with no source counts as startup, in another project" "$(nudge '' "$NOMAP2")" "1"

exit "$rc"
