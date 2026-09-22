#!/usr/bin/env bash
# unread-pick.sh — UserPromptSubmit: one line, only when a board pick is waiting.
#
# WHAT IT CATCHES. The user picked an artboard on a design-kit board (the board
# posted it to the server's loopback /_decision route → .design-kit/decisions.jsonl)
# and then typed a prompt without telling the session. Prints ONE line naming the
# board and artboard so the session reads the pick instead of asking for it — the
# "session watching the board" half of the decision channel, without polling.
#
# WHAT IT DOES NOT DO. It never blocks, never reads the prompt, and says nothing
# when every row is consumed or no board exists. It reads the phase sentinel
# (.claude/cc-phase.json): when a registered run has moved past `decide` (build,
# verify, review, ship) it stays silent — a pick left unread during execution is
# not this hook's turn. Off with CC_REMIND=off or CC_DESIGN_KIT_PICK=off.
# Standing: scripts/__tests__/unread-pick.test.sh drives silent, one-line, consumed
# and phase-gated cases; nothing proves the model acts on the line (agent-graded).
set -euo pipefail
[ "${CC_REMIND:-on}" = "off" ] && exit 0
[ "${CC_DESIGN_KIT_PICK:-on}" = "off" ] && exit 0
input="$(cat 2>/dev/null || true)"
cwd=""
if command -v jq >/dev/null 2>&1; then cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"; fi
[ -n "$cwd" ] || cwd="$PWD"
dec="$cwd/.design-kit/decisions.jsonl"
[ -s "$dec" ] || exit 0

sentinel="$cwd/.claude/cc-phase.json"
if [ -r "$sentinel" ] && command -v jq >/dev/null 2>&1; then
  phase="$(jq -r '.phase // empty' "$sentinel" 2>/dev/null || true)"
  case "$phase" in build|verify|review|ship) exit 0 ;; esac
fi

python3 - "$dec" <<'PY'
import json, sys
rows = []
for ln in open(sys.argv[1], encoding="utf-8"):
    try: rows.append(json.loads(ln))
    except ValueError: pass
unread = [r for r in rows if not r.get("consumed")]
if not unread: sys.exit(0)
r = unread[-1]
who = r.get("board") or "a board"
pick = ("artboard %s" % r["picked"]) if r.get("picked") else "knob/text edits, no artboard picked"
extra = "" if len(unread) == 1 else " (+%d earlier)" % (len(unread) - 1)
print("design-kit: %s has an unread pick — %s%s. `dk.sh decision --latest --consume` reads it; /design-kit:in-codebase with no arguments renders it." % (who, pick, extra))
PY
exit 0
