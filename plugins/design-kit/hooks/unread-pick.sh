#!/bin/bash
# unread-pick.sh — UserPromptSubmit: one line, only when a board pick is waiting.
#
# WHAT IT CATCHES. The user picked an artboard on a design-kit board (the board
# posted it to the server's loopback /_decision route → .design-kit/decisions.jsonl)
# and then typed a prompt without telling the session. Prints ONE line naming the
# board and artboard so the session reads the pick instead of asking for it — the
# "session watching the board" half of the decision channel, without polling.
#
# WHAT IT DOES NOT DO. It never blocks, never reads the prompt, and says nothing
# when every row is consumed or no board exists. Turn-taking is not hand-rolled here:
# it runs the marketplace's shared phase guard (templates/blocks/phase-guard.md,
# inlined below) against its OWN lane.tsv row, so the phase list cannot drift from
# the declaration the way a hardcoded one did — that copy read build|verify|review|ship
# and spoke through `plan`, and had no TTL and no session check, so a sentinel left by
# a run that died muted this channel in every later session. Off with CC_REMIND=off or
# CC_DESIGN_KIT_PICK=off.
#
# WHERE IT LOOKS. The phase sentinel is read at the project root, not the payload cwd,
# which follows the model's `cd` (finding 2, rationale/2026-09-25-session-plugin-usage-
# review.md) — so both shared blocks are inlined below: state-root (held byte-identical
# to templates/blocks/state-root.md by pc_shared_blocks) and phase-guard. NO gate holds
# the phase-guard copy to its block — keeping the two identical is by hand, **recorded**.
#
# FAIL-OPEN, like every hook here: no python3, no jq, no readable sentinel, a foreign
# session or a stale one all mean "proceed" or "say nothing", never an error on the
# user's prompt. `set -e` is deliberately absent — an unset variable or a non-zero
# probe must not take the prompt down with it.
#
# Standing: scripts/__tests__/unread-pick.test.sh drives silent, one-line, consumed,
# phase-gated, stale-sentinel, subdirectory-cwd and no-python3 cases — **gate** (CI globs every
# plugins/*/scripts/__tests__/*.test.sh). Nothing proves the model ACTS on the line
# (agent-graded), and nothing here proves the guard is honoured on a branch the
# harness does not drive.

# --- state root ----------------------------------------------------------------
# Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
# 2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
# its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
# at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
# the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
# the caller's spelling and path-prefix comparisons still hold); outside git,
# CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
# nothing and status 1 — the caller exits rather than resurrect a deleted project.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

[ "${CC_REMIND:-on}" = "off" ] && exit 0
[ "${CC_DESIGN_KIT_PICK:-on}" = "off" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0
input="$(cat 2>/dev/null || true)"
cwd=""
if command -v jq >/dev/null 2>&1; then cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null || true)"; fi
[ -n "$cwd" ] || cwd="$PWD"
root=$(cc_state_root "$cwd") || exit 0
# The root's board first, then the cwd's: dk.sh writes .design-kit/ under the shell cwd it
# ran in, which is the root unless the model had already cd'd into a subdirectory.
dec="$root/.design-kit/decisions.jsonl"
[ -s "$dec" ] || dec="$cwd/.design-kit/decisions.jsonl"
[ -s "$dec" ] || exit 0

# --- phase guard -------------------------------------------------------------
# NOTE ON THE EXTENSION: this block is shell, not markdown. It is named .md because
# template-engine.sh:50 hardcodes `<blocksdir>/<name>.md` for every include directive.
# Teaching the engine other extensions is a change to a gated shared component and
# is not worth it for one file — the engine only ever copies raw bytes.
# Do NOT write a literal include or substitution directive in this file's comments:
# includes are expanded once and not rescanned, but substitution runs over the whole
# rendered text afterwards, so a directive quoted here becomes a missing-key error.
# Stand down when the arc is in a phase this artifact does not own. The sentinel
# only ever NARROWS: absent, foreign, stale or malformed all mean "everyone is
# eligible", which is byte-for-byte today's behaviour. That is deliberate — the
# plain-prompt path is the overwhelming case and must not change, so turn-taking
# engages only once an entry command has actually declared a phase.
#
# WHERE IT LIVES: <state root>/.claude/cc-phase.json, the root cc_state_root resolves
# from the payload cwd. That function comes from the state-root block
# (templates/blocks/state-root.md), which the reminder template includes just above
# this one; a hand copy of this guard must paste it too, or the call fails and the
# guard proceeds as if no sentinel existed. It read `<payload cwd>/.claude/` until
# 2026-09-25, and the payload cwd follows the model's `cd` (finding 2 of
# rationale/2026-09-25-session-plugin-usage-review.md): a sentinel written at the root
# was absent to a hook whose cwd had drifted into a subdirectory, and absent means
# proceed. taskmaster/scripts/phase-sentinel.sh writes at the same root, so writer and
# reader agree from any directory of the project.
#
# Reader contract, in order:
#   absent .............. proceed (no sentinel, no turns)
#   jq missing .......... proceed (fail open, as every hook here does)
#   unparseable ......... proceed
#   session_id differs .. proceed (several sessions share one .claude/ dir)
#   older than TTL ...... proceed, and unlink — a run that died mid-way must not
#                         mute this project's channel in every future session.
#                         The cited precedent .claude/task-runner/active-run.json
#                         is cleared by a MODEL INSTRUCTION, which is why
#                         candor's gate.sh (clause 4) says of it "Nothing clears it";
#                         that gate survives only because it SPEAKS when it
#                         blocks. A silent reader has no such remedy, so the TTL
#                         is the whole of this one's safety.
#   phase == our lane ... proceed
#   lane is `any` ....... proceed (guards are not phase steps)
#   otherwise ........... stand down, silently
#
# TTL is deliberately SHORT. Expiring early degrades to the status quo (the nudge
# fires when it maybe should not); expiring late mutes a real channel. Those costs
# are not symmetric, so this errs toward speaking.
#
# HOW OFTEN THIS ACTUALLY ENGAGES — state it plainly, because the answer is "less
# often than the word turn-taking suggests". Four commands write a sentinel:
# taskmaster:task (shape), task-runner:run (build), git-workflow:finish (ship), and
# code-architecture:coding-task on its `trivial` verdict (build). A BARE PROMPT writes
# none. So on the plain-prompt path — which this design's own notes call the
# overwhelming case — no phase exists, every voice stays eligible, and what arbitrates
# is the rank tiebreak, not the arc. That is collision-avoidance, not turn-taking.
# Turn-taking engages once work enters through a command that declares a phase.
#
# This is a real limit, not a defect to route around: nothing can observe "the arc"
# without something declaring it, and inferring a phase from prompt text would be the
# routing-table-in-shell that route-prompt.sh's own header refuses. The honest claim is
# the narrow one — say the guard engages on the pipeline path, never that the
# marketplace takes turns everywhere.
#
# Standing: the GATE (pc_phase_guard) proves a hook READS the sentinel. No gate
# can prove an artifact HONOURS it in every branch — that half is agent-graded.
#
# Also publishes cc_phase_now — the phase in force, or empty. The rank marker key
# includes it, which is what lets a voice that stood down at one phase
# claim a FRESH key and speak when its own phase arrives. Without it a rank claim
# written on turn 1 outlives the eligibility that produced it and permanently gags
# whichever hook is later the highest ELIGIBLE one.
cc_phase_ttl_min=120
cc_phase_now=""
cc_phase_guard() { # $1 = this artifact's id, e.g. taskmaster:remind. 0 = proceed.
  local sentinel lane want have ssid root
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "${cwd:-}" ] || cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || return 0
  root=$(cc_state_root "$cwd") || return 0
  sentinel="$root/.claude/cc-phase.json"
  [ -r "$sentinel" ] || return 0

  # Stale? mtime, not started_at — no ISO-8601 parsing in portable shell, and the
  # file is rewritten whenever the phase changes, so mtime IS the phase's age.
  if [ -n "$(find "$sentinel" -maxdepth 0 -mmin +"$cc_phase_ttl_min" 2>/dev/null)" ]; then
    rm -f "$sentinel" 2>/dev/null
    return 0
  fi

  have=$(jq -r '.phase // empty' "$sentinel" 2>/dev/null) || return 0
  [ -n "$have" ] || return 0
  cc_phase_now="$have"

  # Nested ifs: a conjunction of two bracket tests here once tripped
  # chassis-template-tests.sh's "hook(plain): no extraGuard when null" assertion,
  # then a substring match over the whole rendered file. Since 2026-09-25 it pins the
  # trigger line instead — the state-root block carries that shape legitimately — so
  # the nesting is no longer load-bearing. It stays; it reads the same either way.
  ssid=$(jq -r '.session_id // empty' "$sentinel" 2>/dev/null)
  if [ -n "$ssid" ]; then
    if [ -n "${sid:-}" ]; then
      case "$ssid" in "$sid") ;; *) return 0 ;; esac
    fi
  fi

  # Our own lane, read from the plugin's OWN lane.tsv — never a sibling's, so this
  # works when the plugin is installed alone (spec S2b).
  lane="${CLAUDE_PLUGIN_ROOT:-}/lane.tsv"
  [ -r "$lane" ] || return 0
  want=$(awk -F'\t' -v a="$1" '$1==a {print $3; exit}' "$lane" 2>/dev/null)
  [ -n "$want" ] || return 0
  [ "$want" = any ] && return 0

  # ORDERED, not equal. Exact equality was the first cut and it was a global mute: the
  # phases COMMANDS write (shape, build, ship) and the phases ADVISORIES declare
  # (understand, decide) are disjoint sets, so `want = have` was unreachable and every
  # phase-owning voice stood down whenever any sentinel existed. Only `any` lanes spoke.
  # The two vocabularies are disjoint for a real reason — "what phase is this command"
  # and "what phase does this advice belong to" are different questions — so the fix is
  # to compare position, not string.
  #
  # An advisory speaks while the arc is AT or BEFORE its phase, and stands down once the
  # arc has moved PAST it. Clarify-the-requirements is useful at understand and shape; on
  # turn 40 of an executing build it is the defect this guard exists to kill.
  cc_phase_ix() { case "$1" in
    understand) echo 1 ;; shape) echo 2 ;; decide) echo 3 ;; plan) echo 4 ;;
    build) echo 5 ;; verify) echo 6 ;; review) echo 7 ;; ship) echo 8 ;; *) echo 0 ;;
  esac; }
  local wi hi; wi=$(cc_phase_ix "$want"); hi=$(cc_phase_ix "$have")
  { [ "$wi" = 0 ] || [ "$hi" = 0 ]; } && return 0
  [ "$hi" -gt "$wi" ] && return 1
  return 0
}
# --- end phase guard ---------------------------------------------------------

sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
cc_phase_guard 'design-kit:unread-pick' || exit 0

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
