#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only when the prompt reads
# like the work it nudges about — a mere mention of the words stays silent.
command -v jq >/dev/null 2>&1 || exit 0
# --- phase guard (spec §4.3) -------------------------------------------------
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
# Standing: the GATE (pc_phase_guard) proves a hook READS the sentinel. No gate
# can prove an artifact HONOURS it in every branch — that half is agent-graded.
#
# Also publishes cc_phase_now — the phase in force, or empty. The rank marker key
# includes it (spec §4.4), which is what lets a voice that stood down at one phase
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
  [ "$want" = "$have" ] && return 0
  return 1
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
  # TURN-TAKING (spec §4.3). Evaluated only after the prompt already matched this
  # hook's own trigger, so an out-of-phase artifact costs one lane.tsv read and
  # nothing else. sid is needed by the guard's session check, so resolve it first.
  sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
  cc_phase_guard 'api-docs-first:remind' || exit 0
  if printf '%s' "$head" | grep -qiE '\b(sdk|endpoint|integrat\w*|webhook|oauth|graphql)\b' && printf '%s' "$head" | grep -qiE '\b(build|implement|write|creat\w*|add|wire|connect|integrat\w*|call|fetch|use|fix|debug|update)\b'; then
    # MONOTONIC PRECEDENCE (spec §4.4). Rank arbitrates only between hooks that
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
