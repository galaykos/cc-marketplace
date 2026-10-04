#!/bin/bash
# statusline.sh — prints the active terse level as a badge, e.g. [TERSE:ULTRA]; nothing when off, for a symlinked level file or for any
#   value outside the level vocabulary. Opt-in: wire it yourself as a "statusLine" command in settings.json.
# The level is level.sh's: CC_TERSE, then the level file, then the cc_terse /config option.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/scripts/statusline.sh
FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode"

[ -L "$FLAG" ] && exit 0

read -r MODE _ <<< "$("${BASH:-bash}" "$(dirname "$0" 2>/dev/null)/level.sh" 2>/dev/null)"

case "$MODE" in
  lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra) ;;
  *) exit 0 ;;
esac

# 2 = dim, 36 = cyan. Kept to two SGR codes so the badge cannot repaint the line.
printf '\033[2;36m[TERSE:%s]\033[0m' "$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"
