#!/bin/bash
# SessionStart: while a terse level is active (CC_TERSE, then the level file, then /config cc_terse), prints the contract block of skills/terse-output/SKILL.md read at runtime under ${CLAUDE_PLUGIN_ROOT}, and a reader name's row of its reader table, or one line naming the level when that block is unreadable. Always exits 0.
# Misses enforcement (nothing rewrites a message once emitted) and a per-project level (the level file is one per machine).
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/activate.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
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

  level=$(cc_option CC_TERSE off "$state")

  case "$level" in
    lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra) shown=$level ;;
    newcomer) shown="$level (lite)" ;;
    expert) shown="$level (full)" ;;
    on-call) shown="$level (ultra)" ;;
    *) exit 0 ;; # off, unset, or anything unrecognized — say nothing
  esac

  root="${CLAUDE_PLUGIN_ROOT:-}"
  skill="$root/skills/terse-output/SKILL.md"

  card="" r=""
  if [ -n "$root" ] && [ -r "$skill" ]; then
    card=$(awk '/<!-- terse-contract:start -->/{f=1; next} /<!-- terse-contract:end -->/{f=0} f' "$skill" 2>/dev/null)
    # As hooks/mode.sh's reader(): a reader name's row of the skill's reader table, one line.
    [ "$shown" = "$level" ] || r=$(awk -F'|' -v n="$level" '/<!-- terse-readers:start -->/{f=1; next} /<!-- terse-readers:end -->/{f=0}
      f { for (i = 2; i <= 5; i++) gsub(/^ +| +$/, "", $i)
          if ($2 == n) printf "Reader %s: %s. Lists and findings %s (no cap when findings are the deliverable).", n, $4, $5 }' "$skill" 2>/dev/null)
  fi
  [ -z "$r" ] || r=$'\n'"$r"$'\n'

  if [ -n "$card" ]; then
    printf 'TERSE MODE ACTIVE — level: %s. Applies to chat messages only.\n\n%s\n%s' "$shown" "$card" "$r"
  else
    printf 'TERSE MODE ACTIVE — level: %s. Contract unreadable at %s; run /candor:level to re-state it.\n' \
      "$shown" "${skill:-<unknown>}"
  fi
} 2>/dev/null
exit 0
