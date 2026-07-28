#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH, where `env bash` itself exits 127.
#
# UserPromptSubmit router. Matches the prompt against prompt-rules.tsv and prints
# ONE line naming the best-suited command. Arbitration is by the table's explicit
# priority column, which is the whole point: the reminder hooks resolve a tie by
# scheduling order (their own comment says so), and scheduling order is not a
# routing decision. Fail-open: any error, or a missing jq, exits silently.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null) || exit 0
  case "$prompt" in "" | "/"*) exit 0 ;; esac # empty, or slash commands manage their own flow

  # OFF SWITCHES. CC_REMIND=off silences every advisory nudge in the marketplace
  # (this hook is one); CC_ROUTE=off silences only this one. Environment is the
  # single state independently-installed plugins genuinely share.
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  case "${CC_ROUTE:-on}" in off) exit 0 ;; esac

  rules="${CLAUDE_PLUGIN_ROOT}/prompt-rules.tsv"
  [ -f "$rules" ] && [ -r "$rules" ] || exit 0

  # TRIGGER NARROWING, identical in shape to the reminder hooks': drop fenced and
  # backticked spans, read only the head (a pasted log buries its keywords deep),
  # refuse prompts that are ABOUT this machinery, and refuse this hook's own line
  # echoed back. LIMITATION (honest scope): heuristic, not parsing. An unquoted
  # keyword in the head still fires and a real request past the head no longer
  # does; CC_ROUTE=off is the reliable control, this is the cheap one.
  scrub=$(printf '%s' "$prompt" | awk '/^```/{f=!f; next} !f' | sed 's/`[^`]*`//g')
  head=$(printf '%s' "$scrub" | tr '\n' ' ' | cut -c1-400)
  printf '%s' "$head" | grep -qiE 'hook (success|feedback|output)|task-notification|SYSTEM NOTIFICATION|UserPromptSubmit' && exit 0
  printf '%s' "$head" | grep -qiE '(delete|remove|uninstall|disable|install|list|which|audit|fix)[a-z -]{0,40}(plugin|hook|reminder|router|route|trigger)' && exit 0
  printf '%s' "$head" | grep -qF '[skill-router]' && exit 0

  # Sibling plugins directory, for the installed-plugin filter. Unset
  # CLAUDE_PLUGIN_ROOT means we cannot tell, so rules fire (bias to surface) —
  # same rule route.sh applies to the file-signal table.
  plugins_dir=""
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && plugins_dir="$(dirname "$CLAUDE_PLUGIN_ROOT")"
  plugin_installed() { # $1 owning_plugin — fire-if-uncertain
    [ -z "$plugins_dir" ] && return 0
    [ -d "$plugins_dir/$1" ] && return 0
    return 1
  }

  # ---- pick the highest-priority surviving match ------------------------------
  # Strictly greater-than keeps ties on the FIRST row, so the table reads as
  # written: reorder rows to break a tie, do not renumber the whole band.
  best_pri=-1; best_cmd=""; best_reason=""
  while IFS=$'\t' read -r pattern command plugin priority reason || [ -n "$pattern" ]; do
    case "$pattern" in ''|'#'*) continue ;; esac
    reason="${reason%$'\r'}"
    [ -n "$command" ] && [ -n "$plugin" ] && [ -n "$priority" ] || continue
    case "$priority" in ''|*[!0-9]*) continue ;; esac
    printf '%s' "$head" | grep -qiE "$pattern" 2>/dev/null || continue
    plugin_installed "$plugin" || continue
    [ "$priority" -gt "$best_pri" ] || continue
    best_pri="$priority"; best_cmd="$command"; best_reason="$reason"
  done < "$rules"
  [ -n "$best_cmd" ] || exit 0

  # ---- PER-PROMPT BUDGET, shared with every reminder hook ----------------------
  # Same key derivation as templates/reminder-hook.sh.tmpl, so whichever process
  # claims the marker first is the only voice on this prompt. Claiming it here is
  # what stops a generic "use /taskmaster:task" nudge landing next to a specific
  # route. RESIDUAL, stated rather than papered over: the harness decides which
  # UserPromptSubmit hook runs first, so a reminder hook CAN still win the race and
  # speak instead of this router. Priority is authoritative among these rules, not
  # across independently-installed processes — the same class of limit the boost
  # hooks' co-activation residual names. CC_REMIND=off leaves this router as the
  # only voice, which is the reliable control.
  sid=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null)
  key=$(printf '%s%s' "$sid" "$prompt" | cksum | cut -d' ' -f1)
  mark="${TMPDIR:-/tmp}/cc-remind-$key"
  if mkdir "$mark" 2>/dev/null || [ ! -d "$mark" ]; then
    printf '[skill-router] %s — %s.\n' "$best_reason" "$best_cmd"
  fi
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-remind-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null
} 2>/dev/null
exit 0
