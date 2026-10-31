#!/bin/bash
# statusline.sh — prints the active terse level (level.sh's rule: CC_TERSE, the level file, the cc_terse option) as a badge, e.g. [TERSE:ULTRA], a reader name with its length level, e.g. [TERSE:ON-CALL/ULTRA]; nothing when off, for a symlinked level file or a value outside the vocabulary.
# Opt-in: wire it yourself as a "statusLine" command in settings.json. Misses what level.sh misses: --settings files, managed-settings.d drop-ins, MDM policy.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/statusline.sh
FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode"

[ -L "$FLAG" ] && exit 0

read -r MODE _ LEN <<< "$("${BASH:-bash}" "$(dirname "$0" 2>/dev/null)/level.sh" 2>/dev/null)"

case "$MODE" in
  lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra) ;;
  newcomer | expert | on-call) MODE="$MODE/$LEN" ;;
  *) exit 0 ;;
esac

# 2 = dim, 36 = cyan. Kept to two SGR codes so the badge cannot repaint the line.
printf '\033[2;36m[TERSE:%s]\033[0m' "$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"
