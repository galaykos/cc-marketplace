#!/bin/bash
# Statusline badge showing the active terse level, e.g. [TERSE:ULTRA].
#
# Opt-in, and deliberately not offered by any hook — a plugin that nags to edit
# settings.json on first run is a plugin that edits settings.json. Wire it yourself:
#
#   "statusLine": { "type": "command",
#                   "command": "bash ~/.claude/plugins/.../candor/scripts/statusline.sh" }
#
# The level is level.sh's: CC_TERSE, then the level file, then the cc_terse /config option.
#
# SECURITY. The level file is user-writable state rendered into a terminal on every
# keystroke, which makes it an injection surface: a symlinked level file blanks the
# badge (a link pointed at a private key would render its bytes) although the hooks
# follow it; level.sh caps the read, and only a whitelisted level renders. Anything
# unrecognized renders nothing rather than echoing bytes from a file this script does
# not control.
FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode"

[ -L "$FLAG" ] && exit 0

read -r MODE _ <<< "$("${BASH:-bash}" "$(dirname "$0" 2>/dev/null)/level.sh" 2>/dev/null)"

case "$MODE" in
  lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra) ;;
  *) exit 0 ;;
esac

# 2 = dim, 36 = cyan. Kept to two SGR codes so the badge cannot repaint the line.
printf '\033[2;36m[TERSE:%s]\033[0m' "$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"
