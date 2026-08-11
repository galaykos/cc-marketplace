#!/usr/bin/env bash
# generated from templates/reminder-hook.sh.tmpl by scripts/generate.sh — edit the template or .chassis.json, not this file
# Fail open: never block the prompt. Print a reminder only when the prompt reads
# like the work it nudges about — a mere mention of the words stays silent.
command -v jq >/dev/null 2>&1 || exit 0
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
  printf '%s' "$head" | grep -qF '/taskmaster:task' && exit 0 # own suggestion quoted back = transcript, not intent
  if printf '%s' "$head" | grep -qiE '\b(build|create|add|implement|develop|rewrite|refactor|fix|update|change|write)\b'; then
    # PRIORITY DIRECTIVE (budgetExempt): a binding workflow directive, not an
    # advisory nudge — it prints on every matching prompt and still CLAIMS the
    # shared per-prompt marker (best-effort) so advisory reminders scheduled
    # AFTER it yield. Honest limitation: hooks launch in parallel, so an
    # advisory that ran FIRST may already have spoken — that order can still
    # stack two lines on one prompt; the accepted trade. Also drops a
    # session-scoped cc-workprompt marker — a CROSS-PLUGIN signal consumed by
    # taskmaster's optional clarify gate (PreToolUse, off by default); a
    # second budgetExempt plugin would arm that gate too. Markers self-clean.
    # NOTE: budgetShared/budgetExempt are derived complements (generate.sh) —
    # a direct render must set exactly one or the emitted if/fi goes empty.
    sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
    key=$(printf '%s%s' "$sid" "$prompt" | cksum | cut -d' ' -f1)
    mkdir "${TMPDIR:-/tmp}/cc-remind-$key" 2>/dev/null
    mkdir "${TMPDIR:-/tmp}/cc-workprompt-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)" 2>/dev/null
    printf '%s (%s).\n' 'taskmaster: work-shaped prompt — before the first code edit, run one batched clarifying round to zero ambiguity, or state in one line why this task is trivial enough to skip it' '/taskmaster:task'
    find "${TMPDIR:-/tmp}" -maxdepth 1 \( -name 'cc-remind-*' -o -name 'cc-workprompt-*' \) -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
  fi
} 2>/dev/null
exit 0
