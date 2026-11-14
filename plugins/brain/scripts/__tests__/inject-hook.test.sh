#!/usr/bin/env bash
# Smoke tests for brain/hooks/inject.sh — the SessionStart hook that injects .cc-artifacts/brain/INDEX.md
# with a staleness hint. Branches: a map built at HEAD → no hint; a commit touching only the
# map (its own commit) → no hint; ≤5 files changed outside it → the "refresh
# now" imperative with a count; more → the passive offer; an active task-runner run (either
# scope.json path) → the passive offer; an unreachable `built:` hash → the passive offer with no count;
# malformed payload → silent exit 0; no map → the nudge on startup only, never on compact/resume;
# a map only in the pre-2026-11-14 brain/ is read until .cc-artifacts/brain/ exists, then never.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
HOOK="$ROOT/plugins/brain/hooks/inject.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit 0; }
[ -f "$HOOK" ] || { echo "FAIL: $HOOK not found"; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"; MAP="$REPO/.cc-artifacts/brain"
rc=0
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: ${2:-<none>} want: ${3:-<none>}"; rc=1; fi; }
g() { git -C "$REPO" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
run() { jq -n --arg c "$REPO" '{hook_event_name:"SessionStart",cwd:$c}' | env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>/dev/null; }
hint() { run | grep -o '⚠ brain map is behind HEAD[^—]*— [A-Za-z]*' | head -1; }
stamp() { # write the map stamped at the current HEAD, as the indexer does
  mkdir -p "$MAP"
  printf 'built: %s · 1 areas · 1 files\n# Index\n- app\n' "$(git -C "$REPO" rev-parse --short HEAD)" > "$MAP/INDEX.md"
}

mkdir -p "$REPO"; g init -q; echo a > "$REPO/a.txt"; g add -A; g commit -qm init
stamp
check "1 a map built at HEAD prints the map and no hint" "$(run | grep -c 'BRAIN MAP (project data)')$(hint)" "1"

g add -A; g commit -qm "brain: map"
check "2 the map's own commit is not drift" "$(hint)" ""

echo b > "$REPO/b.txt"; g add -A; g commit -qm b
check "3 one file outside the map orders the refresh" "$(hint)" "⚠ brain map is behind HEAD (built $(head -1 "$MAP/INDEX.md" | awk '{print $2}'), 1 files changed) — Claude"

for i in 1 2 3 4 5 6; do echo "$i" > "$REPO/f$i.txt"; done; g add -A; g commit -qm many
check "4 more than five files is the passive offer" "$(hint | sed 's/.*— //')" "offer"

stamp; g add -A; g commit -qm "brain: refresh"; echo c > "$REPO/c.txt"; g add -A; g commit -qm c
check "5a control: no task-runner run keeps the imperative" "$(hint | sed 's/.*— //')" "Claude"
mkdir -p "$REPO/.cc-artifacts/task-runner"; echo '{}' > "$REPO/.cc-artifacts/task-runner/scope.json"
check "5 an active task-runner run demotes the imperative to the offer" "$(hint | sed 's/.*— //')" "offer"
rm -rf "$REPO/.cc-artifacts/task-runner"
mkdir -p "$REPO/.claude/task-runner"; echo '{}' > "$REPO/.claude/task-runner/scope.json"
check "5b a run whose scope.json is still under .claude/ demotes it too" "$(hint | sed 's/.*— //')" "offer"
mkdir -p "$REPO/.cc-artifacts/task-runner"
check "5c once .cc-artifacts/task-runner/ exists, a stale .claude/ scope.json no longer demotes" "$(hint | sed 's/.*— //')" "Claude"
rm -rf "$REPO/.claude" "$REPO/.cc-artifacts/task-runner"

printf 'built: deadbeef · 1 areas · 1 files\n# Index\n' > "$MAP/INDEX.md"
check "6 an unreachable built hash is the offer with no count" "$(hint)" "⚠ brain map is behind HEAD (built deadbeef) — offer"

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "7 malformed payload fails open" "$out" "rc=0"

# The no-map nudge prints on startup only; resume, clear and compaction reprinted it before.
NOMAP="$TMP/nomap"; mkdir -p "$NOMAP"
git -C "$NOMAP" init -q; for i in $(seq 1 200); do : > "$NOMAP/s$i.txt"; done; git -C "$NOMAP" add -A
nudge() { jq -n --arg c "$NOMAP" --arg s "$1" '{hook_event_name:"SessionStart",cwd:$c} + (if $s == "" then {} else {source:$s} end)' \
  | env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>/dev/null | grep -c 'no map for this project yet'; }
check "8 startup prints the no-map nudge" "$(nudge startup)" "1"
check "9 a payload with no source counts as startup" "$(nudge '')" "1"
check "10 compact is silent" "$(nudge compact)" "0"
check "11 resume is silent" "$(nudge resume)" "0"

# A map from before 2026-11-14 lives in brain/: read until .cc-artifacts/brain/ exists, then ignored.
OLD="$TMP/old"; mkdir -p "$OLD/brain"; git -C "$OLD" init -q
printf 'built: (no git) · 1 areas · 1 files\n# Index\n- legacy-area\n' > "$OLD/brain/INDEX.md"
inject() { jq -n --arg c "$OLD" '{hook_event_name:"SessionStart",cwd:$c}' | env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>/dev/null; }
check "12 a map only in brain/ is injected" "$(inject | grep -c '^- legacy-area$')" "1"
mkdir -p "$OLD/.cc-artifacts/brain"; printf 'built: (no git) · 1 areas · 1 files\n# Index\n- new-area\n' > "$OLD/.cc-artifacts/brain/INDEX.md"
check "13 once .cc-artifacts/brain/ exists its map wins and brain/ is not read" "$(inject | grep -cE '^- (new|legacy)-area$')$(inject | grep -c '^- new-area$')" "11"
rm "$OLD/.cc-artifacts/brain/INDEX.md"
check "14 an emptied .cc-artifacts/brain/ never falls back to the old map" "$(inject | grep -c 'legacy-area')" "0"

exit "$rc"
