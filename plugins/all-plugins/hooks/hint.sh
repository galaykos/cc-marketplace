#!/bin/bash
# hint.sh — SessionStart, startup only: one systemMessage line to the person, never model context, when all-plugins is the only plugin of its marketplace in the enabledPlugins merged from user, project and local settings (later wins). Off: CC_ALL_PLUGINS_HINT=off hides the startup line naming all-plugins as the only plugin enabled. Fails open.
# Misses: managed policy settings, --settings files and --plugin-dir loads: an all-plugins enabled only there stays silent, leaves enabled only there draw a wrong line.
# Why, limits, history: rationale/derivations/plugin-all-plugins.md § plugins/all-plugins/hooks/hint.sh
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
  jq -cn --arg m "all-plugins is the only $bare plugin enabled here, and it adds nothing by itself: run /all-plugins:install to install the rest (it asks local or project scope). CC_ALL_PLUGINS_HINT=off hides this line." \
    '{systemMessage: $m}'
} 2>/dev/null
exit 0
