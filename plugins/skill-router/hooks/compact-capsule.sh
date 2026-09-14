#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
#
# SessionStart, matcher `compact` ONLY. After a compaction, re-states the task
# state that lives on disk and that the summary may have dropped: the arc phase
# sentinel, a registered task-runner run and its scope lock, and any open
# taskmaster ledgers. Every one of those files survives compaction; what does not
# survive is the model's knowledge that they exist, so it never thinks to look.
# approaches/hooks/compact-recovery.sh solves this for ONE ledger (its own
# deliberation marker) and this hook covers the rest; it deliberately does not
# mention that marker, so a session with both installed hears each once.
#
# WHY SessionStart AND NOT PreCompact. PreCompact stdout goes to the debug log and
# never reaches the model — the documented context-injecting events are
# UserPromptSubmit, UserPromptExpansion, SessionStart and PostModelSwitch. So the
# capsule cannot be planted before the summary; it is re-asserted after it, once.
#
# WHY skill-router. It already owns the SessionStart catalog and the per-session
# routing state, and it is the plugin most bundles share, so the capsule fires in
# the most installs for the fewest declarations.
#
# COST. Matcher `compact` — silent on startup, resume, clear and fork, so the
# always-on budget reads 0 (context-budget.sh drives SessionStart with
# source=startup). A session that compacts pays one short block per compaction,
# and only when at least one ledger exists.
#
# MEASUREMENT RIDER. The phase sentinel records the session_id that wrote it and
# the payload carries the session_id after compaction. Whether those match is the
# open question in rationale/collective-taskforce-backlog.md #6 (two shipped
# mechanisms key on it). Each firing appends one line to
# .claude/skill-router/compact-log.jsonl saying whether they matched. Standing:
# recorded — nothing reads it yet; it exists so the answer accrues on real
# sessions instead of waiting for a probe that has not been run in 25 days.
#
# LIMITATION (honest scope):
#   - Advisory. SessionStart stdout informs a turn; it cannot block one.
#   - Names the files and their headline fields; the reasoning behind a phase or a
#     card lives in the summarized transcript and no hook can pull it back.
#   - Cannot tell a live ledger from a stale one. It prints the sentinel's own
#     started_at and defers to each owner's TTL (taskmaster's reminder hook
#     unlinks a sentinel older than its cc_phase_ttl_min).
#   - Knows the ledgers it names. A plugin that keeps state elsewhere is invisible
#     here — add its path to this file, which is why the list is short and literal.
{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  src=$(printf '%s' "$input" | jq -r '.source // empty' 2>/dev/null) || exit 0
  [ "$src" = "compact" ] || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

  lines=""
  add() { lines="${lines}- $1
"; }

  sentinel_sid=""
  f="$cwd/.claude/cc-phase.json"
  if [ -f "$f" ]; then
    phase=$(jq -r '.phase // empty' "$f" 2>/dev/null)
    owner=$(jq -r '.owner // empty' "$f" 2>/dev/null)
    sentinel_sid=$(jq -r '.session_id // empty' "$f" 2>/dev/null)
    since=$(jq -r '.started_at // empty' "$f" 2>/dev/null)
    if [ -n "$phase" ]; then
      who="another session"
      [ -n "$sentinel_sid" ] && [ "$sentinel_sid" = "$sid" ] && who="this session"
      add "arc phase \`$phase\`${owner:+ owned by $owner}${since:+ since $since}, declared by $who — .claude/cc-phase.json (reminder hooks outside this phase stand down; the owner clears it)"
    fi
  fi

  f="$cwd/.claude/task-runner/active-run.json"
  if [ -f "$f" ]; then
    slug=$(jq -r '.slug // empty' "$f" 2>/dev/null)
    branch=$(jq -r '.branch // empty' "$f" 2>/dev/null)
    idx=$(jq -r '.index_path // empty' "$f" 2>/dev/null)
    add "registered task-runner run${slug:+ \`$slug\`}${branch:+ on branch $branch}${idx:+, cards at $idx} — .claude/task-runner/active-run.json (the completion gate still requires a recorded behavioral-gate pass before this run may stop clean)"
  fi

  f="$cwd/.claude/task-runner/scope.json"
  [ -f "$f" ] && add "scope lock active — .claude/task-runner/scope.json (edits outside it are warned; the run owns the list)"

  names=""
  for f in "$cwd"/.claude/taskmaster/ledger-*.md; do
    [ -f "$f" ] || continue
    names="${names}${names:+, }${f##*/}"
  done
  [ -n "$names" ] && add "open taskmaster ambiguity ledger(s): $names — .claude/taskmaster/ (grill offers Resume / Start fresh; do not re-ask what a ledger already settled)"

  names=""
  for f in "$cwd"/.claude/taskmaster/goal-ledger-*.md; do
    [ -f "$f" ] || continue
    names="${names}${names:+, }${f##*/}"
  done
  [ -n "$names" ] && add "goal ledger(s) from a hands-off run: $names — .claude/taskmaster/ (every auto-take is audited there)"

  [ -n "$lines" ] || exit 0

  printf '[skill-router] Context was compacted. Task state on disk that the summary may have dropped:\n%s' "$lines"
  printf 'Read each file before acting on it; a stale entry is bounded by its owner'"'"'s TTL, not by this notice.\n'

  if [ -n "$sentinel_sid" ] && [ -n "$sid" ]; then
    match=false; [ "$sentinel_sid" = "$sid" ] && match=true
    dir="$cwd/.claude/skill-router"
    mkdir -p "$dir" 2>/dev/null && { [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null; } && printf '{"event":"compact","sentinel_session_matches_payload":%s}\n' "$match" >> "$dir/compact-log.jsonl" 2>/dev/null
  fi
} 2>/dev/null || exit 0
exit 0
