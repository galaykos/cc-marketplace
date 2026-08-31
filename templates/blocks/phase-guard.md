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
# Reader contract, in order:
#   absent .............. proceed (no sentinel, no turns)
#   jq missing .......... proceed (fail open, as every hook here does)
#   unparseable ......... proceed
#   session_id differs .. proceed (several sessions share one .claude/ dir)
#   older than TTL ...... proceed, and unlink — a run that died mid-way must not
#                         mute this project's channel in every future session.
#                         The cited precedent .claude/task-runner/active-run.json
#                         is cleared by a MODEL INSTRUCTION, which is why
#                         completion-gate.sh:71 says of it "Nothing clears it";
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
  local sentinel lane want have ssid
  command -v jq >/dev/null 2>&1 || return 0
  [ -n "${cwd:-}" ] || cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || return 0
  sentinel="$cwd/.claude/cc-phase.json"
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

  # Nested ifs on purpose, never a conjunction of two bracket tests on one line:
  # chassis-template-tests.sh:113 treats that shape as a leaked extraGuard and
  # fails the render. Do not quote the shape in a comment either — the assertion
  # is a substring match over the rendered file, so describing it reintroduces it.
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
