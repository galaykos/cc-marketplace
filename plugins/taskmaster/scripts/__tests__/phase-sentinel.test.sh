#!/usr/bin/env bash
# Fixture tests for phase-sentinel.sh — the script writer of .cc-artifacts/cc-phase/<session key>.json
# (AR 11 of the 2026-09-22 specialist panel: four prose writers, no script writer).
#
# THE LOAD-BEARING CASE IS THE TYPO. Everything else here is bookkeeping; the reason
# this script exists at all is that a misspelled phase scores 0 in the reader's
# ordering table and every phase guard proceeds — which is byte-identical to having no
# sentinel, with nothing printed anywhere. So "write refuses an unknown phase" is the
# case that would make the script worth keeping if every other one were deleted.
#
# The second load-bearing case is the round trip through a REAL reader: this harness
# does not assert the JSON looks right, it drives taskmaster's own remind.sh (which
# carries the shared phase-guard block) against a sentinel this script wrote, and
# asserts the hook stands down. A writer whose output its reader cannot parse would
# pass every shape assertion and fail the only thing that matters.
#
# The third is TWO SESSIONS IN ONE REPO (section 10): B's write or clear must leave A's
# phase and A's reminders exactly as they were, and each case keeps a neighbour that
# must stay silent, so a reader that stopped standing down at all cannot pass it.
set -u
unset CLAUDE_PROJECT_DIR   # a live session exports it; the state root would resolve there
here=$(cd "$(dirname "$0")" && pwd)
S="$here/../phase-sentinel.sh"
PLUGIN_ROOT=$(cd "$here/../.." && pwd)
[ -x "$S" ] || { printf 'FAIL: phase-sentinel.sh not executable at %s\n' "$S"; exit 1; }

pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
ok()  { printf 'PASS: %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL: %s — %s\n' "$1" "$2"; fail=$((fail+1)); }

run() { # run <cwd> <args...> -> sets RC, OUT (stderr+stdout)
  local wd="$1"; shift
  OUT=$("$S" "$@" --cwd "$wd" 2>&1); RC=$?
}

P="$T/proj"; mkdir -p "$P"
SENT="$P/.cc-artifacts/cc-phase/S1.json"

# ---- 1. write: the file lands, with every key the readers use ----------------------
run "$P" write build --owner task-runner:run --session S1
[ "$RC" = 0 ] || bad "write build exits 0" "rc=$RC ($OUT)"
[ "$RC" = 0 ] && ok "write build exits 0"
if [ -f "$SENT" ]; then ok "write creates .cc-artifacts/cc-phase/S1.json"; else bad "write creates the sentinel" "absent"; fi
[ "$(cat "$P/.cc-artifacts/cc-phase/.gitignore" 2>/dev/null)" = '*' ] && ok "the sentinel dir ignores itself in git" \
  || bad "sentinel dir .gitignore" "missing or not '*'"

if command -v jq >/dev/null 2>&1; then
  for k in phase owner session_id started_at; do
    v=$(jq -r --arg k "$k" '.[$k] // empty' "$SENT" 2>/dev/null)
    if [ -n "$v" ]; then ok "sentinel carries .$k"; else bad "sentinel carries .$k" "missing or unparseable"; fi
  done
  [ "$(jq -r .phase "$SENT")" = build ] && ok "phase is what was asked for" || bad "phase" "got $(jq -r .phase "$SENT")"
  [ "$(jq -r .session_id "$SENT")" = S1 ] && ok "session_id is the caller's" || bad "session_id" "got $(jq -r .session_id "$SENT")"
else
  printf 'SKIP: jq absent — key assertions skipped\n'
fi

# ---- 2. THE TYPO CASE. An unknown phase is a refusal, never a written file ---------
rm -f "$SENT"
run "$P" write buidl --owner taskmaster:task --session S1
if [ "$RC" = 3 ] && [ ! -e "$SENT" ]; then ok "unknown phase -> usage error(3), nothing written"
else bad "unknown phase refused" "rc=$RC sentinel-exists=$([ -e "$SENT" ] && echo yes || echo no)"; fi
case "$OUT" in *"unknown phase"*) ok "the refusal names the problem" ;; *) bad "refusal message" "$OUT" ;; esac

# every phase in the arc is accepted, so the check cannot drift into rejecting a real one
for ph in understand shape decide plan build verify review ship; do
  run "$P" write "$ph" --owner x:y --session S1
  [ "$RC" = 0 ] || { bad "phase '$ph' accepted" "rc=$RC"; continue; }
done
ok "all eight arc phases accepted"

# ---- 3. --owner is required; a sentinel with no owner tells the capsule nothing ----
rm -f "$SENT"
run "$P" write build --session S1
if [ "$RC" = 3 ] && [ ! -e "$SENT" ]; then ok "missing --owner -> usage error(3), nothing written"
else bad "missing --owner refused" "rc=$RC"; fi

# ---- 4. --session is required: a sentinel no session owns is the cross-session leak --
rm -rf "$P/.cc-artifacts/cc-phase"
run "$P" write build --owner task-runner:run
if [ "$RC" = 3 ] && [ -z "$(ls "$P/.cc-artifacts/cc-phase" 2>/dev/null)" ]; then ok "write without --session -> usage error(3), nothing written"
else bad "write without --session refused" "rc=$RC ($OUT)"; fi
case "$OUT" in *"requires --session"*) ok "the refusal names --session" ;; *) bad "missing --session message" "$OUT" ;; esac
run "$P" write build --owner task-runner:run --session '/../'
[ "$RC" = 3 ] && ok "a session id with no key byte -> usage error(3)" || bad "keyless session refused" "rc=$RC"
run "$P" write build --owner task-runner:run --session '../x/S9'
if [ "$RC" = 0 ] && [ -f "$P/.cc-artifacts/cc-phase/xS9.json" ] && [ ! -e "$P/.cc-artifacts/x" ]; then
  ok "path bytes in a session id are dropped: the file stays inside .cc-artifacts/cc-phase/"
else bad "session id path bytes" "rc=$RC ($(ls -R "$P/.cc-artifacts" 2>/dev/null | tr '\n' ' '))"; fi
run "$P" clear --session '../x/S9'
run "$P" write build --owner task-runner:run --session S1
run "$P" clear
if [ "$RC" = 3 ] && [ -f "$SENT" ]; then ok "clear without --session -> usage error(3), nothing removed"
else bad "clear without --session refused" "rc=$RC"; fi

# ---- 5. clear removes it, and clearing nothing is success not an error -------------
run "$P" clear --session S1
[ "$RC" = 0 ] && [ ! -e "$SENT" ] && ok "clear removes the sentinel" || bad "clear" "rc=$RC"
run "$P" clear --session S1
[ "$RC" = 0 ] && ok "clear on an absent sentinel is still success" || bad "idempotent clear" "rc=$RC"

# ---- 6. a cwd that is not a directory is refused, never created --------------------
run "$T/does-not-exist" write build --owner a:b --session S1
[ "$RC" = 3 ] && [ ! -e "$T/does-not-exist" ] && ok "non-directory --cwd refused, nothing created" \
  || bad "non-directory --cwd" "rc=$RC"

# ---- 7. usage surface: no args prints usage and exits 3 ---------------------------
OUT=$("$S" 2>&1); RC=$?
[ "$RC" = 3 ] && ok "no subcommand -> usage(3)" || bad "no subcommand" "rc=$RC"
OUT=$("$S" frobnicate 2>&1); RC=$?
[ "$RC" = 3 ] && ok "unknown subcommand -> usage(3)" || bad "unknown subcommand" "rc=$RC"

# ---- 8. ROUND TRIP through a real reader. taskmaster:remind owns phase `shape`
# (lane.tsv), so a sentinel at `build` must silence it and one at `understand` must not.
H="$PLUGIN_ROOT/hooks/remind.sh"
if command -v jq >/dev/null 2>&1 && [ -f "$H" ]; then
  fire() {
    printf '{"hook_event_name":"UserPromptSubmit","prompt":"build a login page","cwd":"%s","session_id":"S1","transcript_path":"/nowhere/S1.jsonl"}' "$P" \
      | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$H" 2>/dev/null
  }
  "$S" clear --session S1 --cwd "$P" >/dev/null 2>&1
  [ -n "$(fire)" ] && ok "reader speaks with no sentinel (the case the guard must not break)" \
    || bad "reader speaks with no sentinel" "silent — fixture or trigger drifted, later cases are vacuous"
  "$S" write build --owner task-runner:run --session S1 --cwd "$P" >/dev/null 2>&1
  [ -z "$(fire)" ] && ok "a script-written 'build' sentinel makes the shape-phase reader stand down" \
    || bad "reader stands down at a later phase" "it spoke"
  "$S" write understand --owner taskmaster:task --session S1 --cwd "$P" >/dev/null 2>&1
  [ -n "$(fire)" ] && ok "an 'understand' sentinel leaves the shape-phase reader eligible" \
    || bad "reader eligible at an earlier phase" "it stood down"
  "$S" clear --session S1 --cwd "$P" >/dev/null 2>&1
else
  printf 'SKIP: jq or remind.sh absent — reader round trip skipped\n'
fi

# ---- 9. SUBDIRECTORY: writer and reader agree on the project ROOT --------------------
# The model's shell follows its `cd`, and every hook payload's cwd with it (finding 2 of
# rationale/2026-09-25-session-plugin-usage-review.md). A writer run from app/Models must
# write at the repo root, and a generated reader fired with cwd=app/Models must honour it.
G="$T/repo"; mkdir -p "$G/app/Models"; git -C "$G" init -q
GS="$G/.cc-artifacts/cc-phase/S1.json"
OUT=$(cd "$G/app/Models" && "$S" write build --owner task-runner:run --session S1 2>&1); RC=$?
if [ "$RC" = 0 ] && [ -f "$GS" ]; then ok "writer run from a subdirectory (default \$PWD) writes at the repo root"
else bad "writer from a subdirectory lands at the root" "rc=$RC ($OUT)"; fi
[ ! -e "$G/app/Models/.cc-artifacts" ] && [ ! -e "$G/app/Models/.claude" ] && ok "no .cc-artifacts/ or .claude/ under the subdirectory" \
  || bad "no .cc-artifacts/ or .claude/ under the subdirectory" "one appeared"
OUT=$("$S" clear --session S1 --cwd "$G/app/Models" 2>&1); RC=$?
[ "$RC" = 0 ] && [ ! -e "$GS" ] && ok "clear --cwd <subdir> removes the root's sentinel" || bad "clear from a subdirectory" "rc=$RC ($OUT)"
if command -v jq >/dev/null 2>&1 && [ -f "$H" ]; then
  subfire() {
    printf '{"hook_event_name":"UserPromptSubmit","prompt":"build a login page","cwd":"%s","session_id":"S1","transcript_path":"/nowhere/S1.jsonl"}' "$G/app/Models" \
      | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" bash "$H" 2>/dev/null
  }
  [ -n "$(subfire)" ] && ok "generated reader, subdirectory cwd: speaks with no sentinel (control arm)" \
    || bad "generated reader speaks from a subdirectory with no sentinel" "silent — later cases are vacuous"
  (cd "$G/app/Models" && "$S" write build --owner task-runner:run --session S1 >/dev/null 2>&1)
  [ -z "$(subfire)" ] && ok "generated reader, subdirectory cwd: stands down at a root 'build' sentinel" \
    || bad "generated reader honours the root sentinel from a subdirectory" "it spoke"
  "$S" write understand --owner taskmaster:task --session S1 --cwd "$G/app/Models" >/dev/null 2>&1
  [ -n "$(subfire)" ] && ok "generated reader, subdirectory cwd: eligible at a root 'understand' sentinel" \
    || bad "generated reader eligible at an earlier phase from a subdirectory" "it stood down"
  "$S" clear --session S1 --cwd "$G" >/dev/null 2>&1
fi

# ---- 10. TWO SESSIONS IN ONE REPO -----------------------------------------------------
# Until taskmaster 0.56.0 the sentinel was one repo-wide file: B's write replaced A's, B's
# clear removed it, and a write with no --session silenced every session. Each assertion
# below names one session that must stay silent and one that must speak.
M="$T/two"; mkdir -p "$M"; git -C "$M" init -q
if command -v jq >/dev/null 2>&1 && [ -f "$H" ]; then
  say() { # say <session> -> the reader's output for that session
    printf '{"hook_event_name":"UserPromptSubmit","prompt":"build a login page","cwd":"%s","session_id":"%s","transcript_path":"/nowhere/%s.jsonl"}' "$M" "$1" "$1" \
      | CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" TMPDIR="$(mktemp -d "$T/tmp.XXXXXX")" bash "$H" 2>/dev/null
  }
  two() { # two <label> <A speaks|silent> <B speaks|silent>
    local a=silent b=silent
    [ -n "$(say A)" ] && a=speaks
    [ -n "$(say B)" ] && b=speaks
    if [ "$a $b" = "$2 $3" ]; then ok "two sessions: $1"; else bad "two sessions: $1" "wanted A $2, B $3; got A $a, B $b"; fi
  }
  phase_of() { jq -r '.phase // "none"' "$M/.cc-artifacts/cc-phase/$1.json" 2>/dev/null || echo none; }

  "$S" write build --owner task-runner:run --session A --cwd "$M" >/dev/null 2>&1
  two "A's build silences A only" silent speaks
  "$S" write understand --owner taskmaster:task --session B --cwd "$M" >/dev/null 2>&1
  [ "$(phase_of A)" = build ] && ok "two sessions: B's write leaves A's phase at build" \
    || bad "two sessions: B's write leaves A's phase" "A's phase is $(phase_of A)"
  two "after B's write, A still stands down and B (understand) speaks" silent speaks
  "$S" write build --owner task-runner:run --session B --cwd "$M" >/dev/null 2>&1
  "$S" clear --session B --cwd "$M" >/dev/null 2>&1
  [ "$(phase_of A)" = build ] && ok "two sessions: B's clear leaves A's sentinel" \
    || bad "two sessions: B's clear leaves A's sentinel" "A's phase is $(phase_of A)"
  two "after B's clear, A still stands down and B speaks" silent speaks
  OUT=$("$S" write build --owner x:y --cwd "$M" 2>&1); RC=$?
  [ "$RC" = 3 ] && ok "two sessions: a write naming no session is refused" || bad "sessionless write refused" "rc=$RC"
  two "a refused sessionless write silences nobody new" silent speaks
  "$S" clear --session A --cwd "$M" >/dev/null 2>&1
  two "A's own clear lets A speak again; B unchanged" speaks speaks

  # ---- 11. LEGACY repo-wide .claude/cc-phase.json: no reader honours it; a write or a
  # clear removes it when it names no session, names the caller, or is past the TTL.
  mkdir -p "$M/.claude"
  printf '{"phase":"build","owner":"x:y"}\n' > "$M/.claude/cc-phase.json"
  two "a legacy sentinel naming no session silences nobody" speaks speaks
  "$S" clear --session B --cwd "$M" >/dev/null 2>&1
  [ ! -e "$M/.claude/cc-phase.json" ] && ok "legacy: a clear removes a legacy sentinel naming no session" \
    || bad "legacy: owner-less legacy removed" "it survived"
  printf '{"phase":"build","owner":"x:y","session_id":"OLD"}\n' > "$M/.claude/cc-phase.json"
  "$S" write understand --owner taskmaster:task --session B --cwd "$M" >/dev/null 2>&1
  [ -f "$M/.claude/cc-phase.json" ] && ok "legacy: another live session's legacy sentinel is left to its owner" \
    || bad "legacy: another session's fresh legacy sentinel kept" "it was removed"
  printf '{"phase": "build", "session_id": "OLD"}\n' > "$M/.claude/cc-phase.json"
  "$S" clear --session B --cwd "$M" >/dev/null 2>&1
  [ -f "$M/.claude/cc-phase.json" ] && ok "legacy: a hand-written owner with spaces around the colon is still read as an owner" \
    || bad "legacy: spaced owner kept" "it was removed as owner-less"
  touch -t 200001010000 "$M/.claude/cc-phase.json"
  "$S" clear --session B --cwd "$M" >/dev/null 2>&1
  [ ! -e "$M/.claude/cc-phase.json" ] && ok "legacy: one past the TTL is removed" || bad "legacy: expired legacy removed" "it survived"
  printf '{"phase":"build","owner":"x:y","session_id":"A"}\n' > "$M/.claude/cc-phase.json"
  "$S" write build --owner task-runner:run --session A --cwd "$M" >/dev/null 2>&1
  [ ! -e "$M/.claude/cc-phase.json" ] && ok "legacy: the caller's own legacy sentinel is replaced by its per-session file" \
    || bad "legacy: own legacy removed" "it survived"
  "$S" clear --session A --cwd "$M" >/dev/null 2>&1

  # ---- 12. PRE-2026-11-14 per-session file under .claude/cc-phase/: read when the new one is
  # absent, never written; clear removes it beside the new one.
  O="$M/.claude/cc-phase/L.json"; mkdir -p "$M/.claude/cc-phase"
  printf '{"phase":"build","owner":"task-runner:run","session_id":"L"}\n' > "$O"
  [ -z "$(say L)" ] && ok "old path: a build sentinel only under .claude/cc-phase/ makes the reader stand down" \
    || bad "old path: reader falls back to .claude/cc-phase/" "it spoke"
  before=$(cksum < "$O")
  "$S" write understand --owner taskmaster:task --session L --cwd "$M" >/dev/null 2>&1
  [ "$(jq -r .phase "$M/.cc-artifacts/cc-phase/L.json" 2>/dev/null)" = understand ] && ok "old path: write lands under .cc-artifacts/cc-phase/" \
    || bad "old path: write lands at the new path" "$(ls -R "$M/.cc-artifacts" 2>&1 | tr '\n' ' ')"
  [ "$(cksum < "$O")" = "$before" ] && ok "old path: write leaves the .claude/cc-phase/ file untouched" \
    || bad "old path: write left the old file untouched" "it changed"
  [ -n "$(say L)" ] && ok "old path: the new 'understand' sentinel wins over the old 'build' one" \
    || bad "old path: the new sentinel wins" "it stood down"
  "$S" clear --session L --cwd "$M" >/dev/null 2>&1
  [ ! -e "$O" ] && [ ! -e "$M/.cc-artifacts/cc-phase/L.json" ] && ok "old path: clear removes the session's file at both paths" \
    || bad "old path: clear removes both" "old=$([ -e "$O" ] && echo kept || echo gone) new=$([ -e "$M/.cc-artifacts/cc-phase/L.json" ] && echo kept || echo gone)"
  "$S" write build --owner task-runner:run --session K --cwd "$M" >/dev/null 2>&1
  [ ! -e "$M/.claude/cc-phase/K.json" ] && ok "old path: a write never creates a file under .claude/cc-phase/" \
    || bad "old path: write stayed off the old path" "K.json appeared there"
  "$S" clear --session K --cwd "$M" >/dev/null 2>&1
else
  printf 'SKIP: jq or remind.sh absent — two-session cases skipped\n'
fi

printf -- '---- phase-sentinel: %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
