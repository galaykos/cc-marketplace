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
  printf '%s' "$head" | grep -qiE '(delete|remove|uninstall|disable|install|list|which|audit|fix)[a-z -]{0,40}(plugin|hook|reminder|trigger)' && exit 0
  printf '%s' "$head" | grep -qF '/build-vs-buy:check' && exit 0 # own suggestion quoted back = transcript, not intent
  if printf '%s' "$head" | grep -qiE '\b(build|implement|write|create)\b|roll[[:space:]-]*(my|our|your)?[[:space:]-]*own|from[[:space:]]scratch|hand[[:space:]-]*roll' && printf '%s' "$head" | grep -qiE '(auth(entication|orization)?|login|session|oauth|jwt|password[[:space:]]hash|parser|tokeni[sz]er|date[[:space:]-]*(lib|library|math|parsing)|time[[:space:]]?zone|queue|job[[:space:]]queue|message[[:space:]]broker|cache|rate[[:space:]-]*limit(er|ing)?|state[[:space:]]machine|pdf|csv[[:space:]]parser|email[[:space:]]sending|smtp|payment|billing|encryption|crypto(graphy)?|hashing|search[[:space:]]engine|full[[:space:]-]*text[[:space:]]search|orm|scheduler|cron|websocket|pub[[:space:]-]*sub|i18n|internationali[sz]ation|feature[[:space:]]flag|markdown[[:space:]]parser|diff(ing)?[[:space:]]algorithm|uuid|slug)'; then
    # PER-PROMPT BUDGET: at most one reminder line per prompt across every
    # reminder hook installed. All hooks derive the same key from the prompt;
    # mkdir is the atomic test-and-set, first hook to claim it speaks. Which
    # one wins is scheduling order — acceptable for advisory nudges; the
    # alternative was four competing "do this first" directives on one prompt.
    # Fail open: with an unwritable TMPDIR the claim fails but no marker
    # exists, so the reminder still prints. Markers self-clean after a day.
    sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
    key=$(printf '%s%s' "$sid" "$prompt" | cksum | cut -d' ' -f1)
    mark="${TMPDIR:-/tmp}/cc-remind-$key"
    if mkdir "$mark" 2>/dev/null || [ ! -d "$mark" ]; then
      printf '%s (%s).\n' 'build-vs-buy: this looks like building a capability often already solved by a battle-tested library or service — before writing it, weigh take (adopt) vs wrap vs write via an existing-solution search, health table, and verdict; skip only if you already know no fit exists' '/build-vs-buy:check'
    fi
    find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-remind-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
  fi
} 2>/dev/null
exit 0
