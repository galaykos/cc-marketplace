#!/usr/bin/env bash
# Tests for announce.sh (SessionStart cold-session run announcement).
#
# Each case is a branch a one-character edit could remove while the happy path stays
# green: the silence that keeps the always-on context budget at zero for a project with
# no run, the matcher guard that leaves compaction to skill-router, the card-count
# parse, the off switch, and fail-open on a malformed payload. Fixtures live under a
# mktemp -d workspace; the hook is driven with canned SessionStart stdin JSON and
# judged on rc + the additionalContext string.
set -u
unset CLAUDE_PROJECT_DIR   # the hook's state-root resolver reads it; fixtures must not inherit it

here=$(cd "$(dirname "$0")" && pwd)
HOOK="$here/../../hooks/announce.sh"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available (hook fails open without it)"; exit 0; }
[ -x "$HOOK" ] || { echo "FAIL: hook not executable at $HOOK"; exit 1; }

rc=0
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT

fire() { # <cwd> [source] [session] -> additionalContext (empty when silent)
  printf '{"hook_event_name":"SessionStart","source":"%s","cwd":"%s","session_id":"%s"}' "${2:-startup}" "$1" "${3:-S1}" \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}
check() { if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: ${2:-<none>} want: ${3:-<none>}"; rc=1; fi; }
has() { if printf '%s' "$2" | grep -qF -- "$3"; then echo "PASS: $1"; else echo "FAIL: $1 — missing '$3' in: ${2:-<none>}"; rc=1; fi; }

BARE="$WS/bare"; mkdir -p "$BARE"
check "1 no active-run.json: silent (the always-on budget stays 0)" "$(fire "$BARE")" ""

RUN="$WS/run"; mkdir -p "$RUN/.cc-artifacts/task-runner" "$RUN/tasks/demo"
printf '{"slug":"2026-09-22-demo","branch":"feat/orders","index_path":"tasks/demo/00-INDEX.md"}\n' \
  > "$RUN/.cc-artifacts/task-runner/active-run.json"
mkdir -p "$RUN/.cc-artifacts/cc-phase"; printf '{"phase":"build","owner":"task-runner:run","session_id":"S1"}\n' > "$RUN/.cc-artifacts/cc-phase/S1.json"
cat > "$RUN/tasks/demo/00-INDEX.md" <<'EOF'
| card | title | status |
|---|---|---|
| 01 | a | done |
| 02 | b | in progress |
| 03 | c | parked — blocked on an API key |
| 04 | d |  |
EOF
line=$(fire "$RUN")
check "2 a registered run announces exactly one line" "$(printf '%s' "$line" | grep -c .)" "1"
has "3 the line names the slug" "$line" '`2026-09-22-demo`'
has "4 the line names the branch" "$line" 'branch `feat/orders`'
has "5 done and parked cards are closed, the rest remain" "$line" '2 of 4 cards still open'
has "6 the declared phase is named with its owner" "$line" 'phase `build` set by task-runner:run'
if printf '%s' "$line" | grep -q 'status outside'; then echo "FAIL: 6b a vocabulary-only index names no unrecognised status"; rc=1; else echo "PASS: 6b a vocabulary-only index names no unrecognised status"; fi

line2=$(fire "$RUN" startup S2)
has "6c another session's line still names the run" "$line2" '`2026-09-22-demo`'
if printf '%s' "$line2" | grep -q 'phase `'; then echo "FAIL: 6d another session's phase is not this session's"; rc=1; else echo "PASS: 6d another session's phase is not this session's"; fi
check "7 source=compact is skill-router's lane, not this one" "$(fire "$RUN" compact)" ""
check "8 source=resume announces" "$(printf '%s' "$(fire "$RUN" resume)" | grep -c .)" "1"

rm -rf "$RUN/.cc-artifacts/cc-phase"
printf '{"slug":"plain"}\n' > "$RUN/.cc-artifacts/task-runner/active-run.json"
line=$(fire "$RUN")
check "9 a run with no index still announces" "$(printf '%s' "$line" | grep -c .)" "1"
if printf '%s' "$line" | grep -q 'cards still open'; then echo "FAIL: 10 no index means no invented card count"; rc=1; else echo "PASS: 10 no index means no invented card count"; fi

check "11 CC_REMIND=off is silent" \
  "$(printf '{"hook_event_name":"SessionStart","source":"startup","cwd":"%s"}' "$RUN" | CC_REMIND=off bash "$HOOK" 2>/dev/null)" ""

out=$(printf 'not json' | bash "$HOOK" 2>/dev/null; echo "rc=$?")
check "12 malformed payload fails open" "$out" "rc=0"

# 13-15) STATE ROOT (0.41.0). The payload cwd follows the model's `cd`; the run is
#        registered at the project root. Before, a session opened in a subdirectory
#        looked for app/Models/.cc-artifacts/task-runner/active-run.json and said nothing.
git init -q "$RUN" 2>/dev/null
mkdir -p "$RUN/app/Models"
printf '{"slug":"2026-09-22-demo","branch":"feat/orders","index_path":"tasks/demo/00-INDEX.md"}\n' \
  > "$RUN/.cc-artifacts/task-runner/active-run.json"
line=$(fire "$RUN/app/Models")
has "13 subdirectory cwd: the root's run is announced" "$line" '`2026-09-22-demo`'
has "14 subdirectory cwd: the root-relative index still resolves" "$line" '2 of 4 cards still open'
check "15 subdirectory cwd: no .claude/ or .cc-artifacts/ created there" "$([ -e "$RUN/app/Models/.claude" ] || [ -e "$RUN/app/Models/.cc-artifacts" ] && echo yes)" ""

# 16) a tag named like the run's branch: --abbrev-ref printed `heads/feat/orders`, and the line
#     told the session it was on another branch than its own run's
TAGR="$WS/tagged"; mkdir -p "$TAGR/.cc-artifacts/task-runner"
git init -q -b feat/orders "$TAGR" 2>/dev/null && git -C "$TAGR" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$TAGR" tag feat/orders
printf '{"slug":"tagged","branch":"feat/orders"}\n' > "$TAGR/.cc-artifacts/task-runner/active-run.json"
line=$(fire "$TAGR")
check "16 a tag named like the branch: no 'you are on' another branch" "$(printf '%s' "$line" | grep -c 'you are on')" "0"
# 17) symbolic-ref's exit 1 is a detached head, named as candor names it; any other exit is unknown and never compared
SHIM="$WS/shim"; mkdir -p "$SHIM"
printf '#!/bin/sh\nfor a in "$@"; do [ "$a" = symbolic-ref ] && exit 128; done\nexec %s "$@"\n' "$(command -v git)" > "$SHIM/git"; chmod +x "$SHIM/git"
line=$(PATH="$SHIM:$PATH" fire "$TAGR")
check "17a symbolic-ref exiting 128: no 'you are on'" "$(printf '%s' "$line" | grep -c 'you are on')" "0"
git -C "$TAGR" checkout -q --detach
has "17b a detached head beside a run on a branch: 'you are on HEAD'" "$(fire "$TAGR")" '(you are on `HEAD`)'

ODD="$WS/odd"; mkdir -p "$ODD/.cc-artifacts/task-runner" "$ODD/tasks/odd"
printf '{"slug":"2026-10-08-odd","index_path":"tasks/odd/00-INDEX.md"}\n' > "$ODD/.cc-artifacts/task-runner/active-run.json"
printf '%s\n' '| card | title | status |' '|---|---|---|' '| 01 | a | committed e93ffc7 — verify 7/7 |' \
  '| 02 | b | Committed 3f6acd7 |' '| 03 | c | done (f403ab9) |' '| 04 | d | pending |' > "$ODD/tasks/odd/00-INDEX.md"
line=$(fire "$ODD")
has "20 a status outside the vocabulary is counted open and named" "$line" '3 of 4 cards still open (2 with a status outside pending, in_progress, done, parked, blocked: counted open)'

# 21-24) a run registered before 2026-11-14: its run file under .claude/task-runner/, its index under taskmaster-docs/,
#        this session's phase under .claude/cc-phase/. Announced from a one-time copy; the old files stay as they were.
OLD="$WS/old"; mkdir -p "$OLD/.claude/task-runner" "$OLD/.claude/cc-phase" "$OLD/taskmaster-docs/tasks/old"
printf '{"slug":"2026-11-01-old","index_path":"taskmaster-docs/tasks/old/00-INDEX.md"}\n' > "$OLD/.claude/task-runner/active-run.json"
printf '{"phase":"verify","owner":"task-runner:run","session_id":"S1"}\n' > "$OLD/.claude/cc-phase/S1.json"
printf '%s\n' '| card | title | status |' '|---|---|---|' '| 01 | a | done |' '| 02 | b | pending |' > "$OLD/taskmaster-docs/tasks/old/00-INDEX.md"
before=$(cd "$OLD/.claude" && find . -type f -exec cksum {} + | sort)
line=$(fire "$OLD")
has "21 a run under .claude/task-runner/ is announced, its taskmaster-docs/ index counted" "$line" '`2026-11-01-old` — 1 of 2 cards still open'
has "22 this session's phase under .claude/cc-phase/ is still named" "$line" 'phase `verify` set by task-runner:run'
check "23 the run file is copied to .cc-artifacts/task-runner/" "$(jq -r .slug "$OLD/.cc-artifacts/task-runner/active-run.json" 2>/dev/null)" "2026-11-01-old"
check "24 the old files are left as they were" "$(cd "$OLD/.claude" && find . -type f -exec cksum {} + | sort)" "$before"

exit $rc
