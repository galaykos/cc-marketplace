#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
#
# SessionStart: inject the terse contract when — and only when — a level is active.
#
# ONE SOURCE OF TRUTH. The contract text is extracted at runtime from the marked
# block in skills/terse-output/SKILL.md, so the skill body and the injected card
# can never drift. The path comes from ${CLAUDE_PLUGIN_ROOT}, which Claude Code
# exports for hook commands — NOT from a $0-relative guess. That guess is exactly
# how the plugin this one replaces silently fell back to a stub ruleset that had
# no intensity levels in it at all, in every install where the hook did not sit
# one directory below the skills dir.
#
# LIMITATION (honest scope — the four laws, see
# claude-authoring/skills/authoring-skills/SKILL.md "The four laws"):
#   - This injects a contract; it cannot enforce one. Nothing can rewrite a message
#     after the model emits it. Per-turn reinforcement lives in mode.sh, and
#     after-the-fact measurement in /terse:check. Both are advisory.
#   - Level state is machine-local (one file under the Claude config dir), so it
#     is shared by every project on this machine and not by a team. Deliberate:
#     how terse the user wants their own terminal is a user preference, not a
#     repo policy.
#   - If the SKILL.md block cannot be read, the hook emits one line naming the
#     level instead of a second copy of the rules. A duplicate ruleset is how the
#     two copies drift, so the degraded path stays deliberately thin.
{
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  state="$cfg/terse-mode"

  # Env beats file, the CC_BOOST / CC_REMIND convention: environment is the one
  # state independently-installed plugins genuinely share, and the only control a
  # headless run can set.
  level="${CC_TERSE:-}"
  if [ -z "$level" ] && [ -r "$state" ]; then
    read -r level _ < "$state" 2>/dev/null || level=""
  fi

  case "$level" in
    lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra) ;;
    *) exit 0 ;; # off, unset, or anything unrecognized — say nothing
  esac

  root="${CLAUDE_PLUGIN_ROOT:-}"
  skill="$root/skills/terse-output/SKILL.md"

  card=""
  if [ -n "$root" ] && [ -r "$skill" ]; then
    card=$(awk '/<!-- terse-contract:start -->/{f=1; next} /<!-- terse-contract:end -->/{f=0} f' "$skill" 2>/dev/null)
  fi

  if [ -n "$card" ]; then
    printf 'TERSE MODE ACTIVE — level: %s. Applies to chat messages only.\n\n%s\n' "$level" "$card"
  else
    printf 'TERSE MODE ACTIVE — level: %s. Contract unreadable at %s; run /terse:level to re-state it.\n' \
      "$level" "${skill:-<unknown>}"
  fi
} 2>/dev/null
exit 0
