#!/bin/bash
# SessionStart (startup only) hint: all-plugins is enabled and no other plugin of its marketplace is.
# all-plugins installs the leaves and adds nothing itself; a user once ran days of sessions with zero
# leaves, believing the marketplace was on. One line to the person (systemMessage, never model context).
# CC_ALL_PLUGINS_HINT=off hides the startup line naming all-plugins as the only plugin enabled.
# "Enabled" is the enabledPlugins map merged from the settings files the CLI writes, later wins: user
# (${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json), then project and local (<project>/.claude/settings.json,
# settings.local.json), the project being CLAUDE_PROJECT_DIR, else the payload cwd.
# Misses: managed policy settings, --settings files and --plugin-dir loads. Unseen all-plugins: silent;
# leaves enabled only through a channel unread here: a wrong line.
# Fail open: no jq, unreadable settings or any error prints nothing.
{
  [ "${CC_ALL_PLUGINS_HINT:-on}" = off ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  [ "$(printf '%s' "$input" | jq -r '.source // "startup"' 2>/dev/null)" = startup ] || exit 0
  proj="${CLAUDE_PROJECT_DIR:-}"
  [ -n "$proj" ] || proj=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  files=("${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json")
  [ -n "$proj" ] && [ -d "$proj" ] && files+=("$proj/.claude/settings.json" "$proj/.claude/settings.local.json")
  merged=$(for f in "${files[@]}"; do
      [ -r "$f" ] && jq -c '.enabledPlugins // {} | if type == "object" then . else {} end' "$f" 2>/dev/null
    done | jq -cs 'add // {}' 2>/dev/null) || exit 0
  bare=$(printf '%s' "$merged" | jq -r '[to_entries[] | select(.value == true) | .key] as $on
    | [$on[] | select(startswith("all-plugins@")) | ltrimstr("all-plugins@")
       | select(. as $m | [$on[] | select(endswith("@" + $m))] | length == 1)] | .[0] // empty' 2>/dev/null)
  [ -n "$bare" ] || exit 0
  jq -cn --arg m "all-plugins is the only $bare plugin enabled here, and it adds nothing by itself: run /all-plugins:install to install the rest (it asks user or local scope). CC_ALL_PLUGINS_HINT=off hides this line." \
    '{systemMessage: $m}'
} 2>/dev/null
exit 0
