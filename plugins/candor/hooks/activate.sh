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
# .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
#   - This injects a contract; it cannot enforce one. Nothing can rewrite a message
#     after the model emits it. Per-turn reinforcement lives in mode.sh, and
#     after-the-fact measurement in /candor:check. Both are advisory.
#   - Level state is machine-local (one file under the Claude config dir), so it
#     is shared by every project on this machine and not by a team. Deliberate:
#     how terse the user wants their own terminal is a user preference, not a
#     repo policy.
#   - If the SKILL.md block cannot be read, the hook emits one line naming the
#     level instead of a second copy of the rules. A duplicate ruleset is how the
#     two copies drift, so the degraded path stays deliberately thin.
# The level: CC_TERSE, then the level file, then the /config option cc_terse.

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

{
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  state="$cfg/terse-mode"

  # Env beats file, the CC_BOOST / CC_REMIND convention: environment is the one
  # state independently-installed plugins genuinely share, and the only control a
  # headless run can set.
  level=$(cc_option CC_TERSE off "$state")

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
    printf 'TERSE MODE ACTIVE — level: %s. Contract unreadable at %s; run /candor:level to re-state it.\n' \
      "$level" "${skill:-<unknown>}"
  fi
} 2>/dev/null
exit 0
