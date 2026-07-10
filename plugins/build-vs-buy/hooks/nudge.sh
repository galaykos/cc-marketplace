#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# UserPromptSubmit nudge. When a prompt proposes BUILDING a capability that is
# usually a solved, off-the-shelf problem, surface /build-vs-buy:check once — the gate
# is meant to fire BEFORE eager coding, and self-invocation is exactly what gets
# skipped. Fail-open: prints at most a reminder, never blocks the prompt.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  [ -n "$prompt" ] || exit 0
  case "$prompt" in "/"*) exit 0 ;; esac  # slash commands manage their own flow

  # Intent to build + a commonly-solved capability = worth a build-vs-buy pause.
  build_intent='(build|implement|write|create|roll[[:space:]-]*(my|our|your)?[[:space:]-]*own|from[[:space:]]scratch|hand[[:space:]-]*roll)'
  solved='(auth(entication|orization)?|login|session|oauth|jwt|password[[:space:]]hash|parser|tokeni[sz]er|date[[:space:]-]*(lib|library|math|parsing)|time[[:space:]]?zone|queue|job[[:space:]]queue|message[[:space:]]broker|cache|rate[[:space:]-]*limit(er|ing)?|state[[:space:]]machine|pdf|csv[[:space:]]parser|email[[:space:]]sending|smtp|payment|billing|encryption|crypto(graphy)?|hashing|search[[:space:]]engine|full[[:space:]-]*text[[:space:]]search|orm|scheduler|cron|websocket|pub[[:space:]-]*sub|i18n|internationali[sz]ation|feature[[:space:]]flag|markdown[[:space:]]parser|diff(ing)?[[:space:]]algorithm|uuid|slug)'

  if printf '%s' "$prompt" | grep -qiE "$build_intent" \
     && printf '%s' "$prompt" | grep -qiE "$solved"; then
    echo "build-vs-buy: this looks like building a capability that is often already solved by a battle-tested library or service. Before writing it, run /build-vs-buy:check to weigh take (adopt) vs wrap vs write — an existing-solution search, a health table, and a take/wrap/write verdict. Skip only if you already know no fit exists."
  fi
} 2>/dev/null
exit 0
