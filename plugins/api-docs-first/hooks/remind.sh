#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only when the prompt reads
# like the work it nudges about — a mere mention of the words stays silent.
command -v jq >/dev/null 2>&1 || exit 0
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

{
  input=$(cat)
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow
  # OFF SWITCH. CC_REMIND=off silences every reminder hook in the marketplace —
  # the reminder twin of the boost hooks' CC_BOOST. Environment is the one state
  # independently-installed plugins genuinely share.
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  # TRIGGER NARROWING (the boost hooks' C17 pattern, applied to reminders). The
  # keyword used to be grepped from the WHOLE prompt, so a pasted transcript, a
  # task notification, or a request to change the hook itself fired the nudge.
  # In order: drop fenced code and backticked spans; read only the head of the
  # prompt (a pasted log buries its keywords deep); refuse prompts that are
  # ABOUT the reminder machinery; refuse this hook's own output echoed back.
  # LIMITATION (honest scope): heuristic, not parsing — an unquoted keyword in
  # the head still fires, a real request past the head no longer does.
  # CC_REMIND=off is the reliable control, this is the cheap one.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400)
  printf '%s' "$head" | grep -qiE 'hook (success|feedback|output)|task-notification|SYSTEM NOTIFICATION|UserPromptSubmit' && exit 0
  printf '%s' "$head" | grep -qiE '(delete|remove|uninstall|disable|install|list|which|audit|fix|update|change|write|rewrite|edit)[a-z -]{0,40}(plugin|hook|reminder|trigger)' && exit 0
  printf '%s' "$head" | grep -qF '/api-docs-first:check' && exit 0 # own suggestion quoted back = transcript, not intent
  # QUESTION-SHAPED PROMPTS (misfire regression, live transcript 2026-08-25). The
  # trigger is a bare verb list matched anywhere in the head, so "can I BUILD a
  # tool on Claude Code?" and "if we needed to BUILD from scratch, what would you
  # do?" both scored as work-shaped. Asking WHETHER to do the work is not asking
  # for it, and a clarify nudge on a question is pure noise: the deliverable is
  # prose, and there is no edit for the nudge to sit in front of.
  #
  # CLAUSE-LEVEL, not prompt-level, because one prompt can do both ("that looks
  # wrong. fix the parser"). Split the head into clauses, keep only those actually
  # carrying the trigger, and stand down only when EVERY one of them is
  # interrogative — a clause counts as interrogative when it ended in `?` or opens
  # with a question word. A single imperative trigger clause is enough to speak.
  #
  # LIMITATION (honest scope): heuristic, not parsing. "how do I add caching?" is
  # refused even though the user may well want it built; the nudge returns on their
  # next, imperative, prompt. A delayed nudge is the cheaper error than a false one,
  # and CC_REMIND=off remains the reliable control.
  clauses=$(printf '%s' "$head" | awk '{gsub(/\?/," __Q__\n"); gsub(/\. /,"\n"); print}')
  if printf '%s\n' "$clauses" | grep -qiE '\b(librar\w*|sdk|integrat\w*|webhook|oauth|graphql|(external|third[- ]party|public|vendor) api|api (client|key|token|docs?|reference))\b'; then
    printf '%s\n' "$clauses" | grep -iE '\b(librar\w*|sdk|integrat\w*|webhook|oauth|graphql|(external|third[- ]party|public|vendor) api|api (client|key|token|docs?|reference))\b' \
      | grep -qvE '(__Q__|^[[:space:]]*(can|could|should|would|shall|is|are|was|were|do|does|did|am|will|what|why|how|when|where|which|who|whether)[^a-z])' \
      || exit 0
  fi
  # TURN-TAKING. Evaluated only after the prompt already matched this
  # hook's own trigger, so an out-of-phase artifact costs one lane.tsv read and
  # nothing else. sid is needed by the guard's session check, so resolve it first.
  sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
  cc_phase_guard 'api-docs-first:remind' || exit 0
  if printf '%s' "$head" | grep -qiE '\b(librar\w*|sdk|integrat\w*|webhook|oauth|graphql|(external|third[- ]party|public|vendor) api|api (client|key|token|docs?|reference))\b' && printf '%s' "$head" | grep -qiE '\b(build|implement|write|creat\w*|add|wire|connect|integrat\w*|call|fetch|use|fix|debug|update)\b'; then
    # MONOTONIC PRECEDENCE. Rank arbitrates only between hooks that
    # share a phase; the phase sentinel does the real turn-taking. Guaranteed:
    # among hooks eligible THIS TURN, the best rank always speaks, in every
    # invocation order. NOT guaranteed: exactly one line — a worse-ranked sibling
    # that reads before its better-ranked peer claims will also print. Output is
    # bounded at one line per eligible hook. Claiming determinism here would be an
    # over-claim; hooks launch in parallel and single-voice needs a settle window,
    # which would cost latency on every prompt.
    #
    # Markers are FLAT (cc-remind-<key>-rank-<NN>), never nested under a per-key
    # directory. Nested claims fail ENOENT without an -p, so no hook would ever
    # yield and ALL would print; and the shipped sweep below uses rmdir with
    # -maxdepth 1, which can neither remove a non-empty directory nor descend into
    # it, so every prompt would leak a marker forever and each leak is a permanent
    # gag. Flat markers are cleaned by that same sweep unchanged.
    #
    # The key carries the PHASE, so a voice that stood down earlier gets a fresh
    # claim namespace when its own phase arrives instead of meeting a stale claim.
    key=$(printf '%s%s%s' "$sid" "$prompt" "$cc_phase_now" | cksum | cut -d' ' -f1)
    mkdir "${TMPDIR:-/tmp}/cc-remind-$key-rank-40" 2>/dev/null
    best=$(ls -d "${TMPDIR:-/tmp}/cc-remind-$key-rank-"* 2>/dev/null \
             | sed 's/.*-rank-//' | sort -n | head -1)
    if [ -z "$best" ] || [ "$best" = '40' ]; then
      printf '%s (%s).\n' 'api-docs-first: this prompt mentions an API/SDK integration — verify current official docs before writing integration code, and if none are accessible ask the user for a URL or file' '/api-docs-first:check'
    fi
    find "${TMPDIR:-/tmp}" -maxdepth 1 \( -name 'cc-remind-*' -o -name 'cc-workprompt-*' \) -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
  fi
} 2>/dev/null
exit 0
