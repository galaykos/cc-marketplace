#!/bin/bash
# Statusline badge showing the active terse level, e.g. [TERSE:ULTRA].
#
# Opt-in, and deliberately not offered by any hook — a plugin that nags to edit
# settings.json on first run is a plugin that edits settings.json. Wire it yourself:
#
#   "statusLine": { "type": "command",
#                   "command": "bash ~/.claude/plugins/.../terse/scripts/statusline.sh" }
#
# SECURITY. The level file is user-writable state rendered into a terminal on every
# keystroke, which makes it an injection surface: refuse symlinks (a link pointed at
# a private key would render its bytes), cap the read, strip everything outside a
# tiny character class, and whitelist the result. Anything unrecognized renders
# nothing rather than echoing bytes from a file this script does not control.
FLAG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/terse-mode"

[ -L "$FLAG" ] && exit 0
[ -f "$FLAG" ] || exit 0

MODE=$(head -c 32 "$FLAG" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]')
MODE=$(printf '%s' "$MODE" | tr -cd 'a-z-')

case "$MODE" in
  lite | full | ultra | wenyan-lite | wenyan-full | wenyan-ultra) ;;
  *) exit 0 ;;
esac

# 2 = dim, 36 = cyan. Kept to two SGR codes so the badge cannot repaint the line.
printf '\033[2;36m[TERSE:%s]\033[0m' "$(printf '%s' "$MODE" | tr '[:lower:]' '[:upper:]')"
