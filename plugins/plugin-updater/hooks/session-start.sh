#!/bin/bash
# session-start.sh — SessionStart startup: report the last background update run once, then start scripts/update-all.sh detached for the session's folder (payload cwd) and user scope when that folder's last completed run is older than the interval (lock-guarded); returns at once.
# With CC_PLUGIN_UPDATER_AUTO=off it only counts that folder's outdated installs from JSON files. Never updates in-line, never passes -y. Fails open: no python3 or any error prints nothing.
# Why, limits, history: rationale/derivations/plugin-plugin-updater.md § plugins/plugin-updater/hooks/session-start.sh
{
  command -v python3 >/dev/null 2>&1 || exit 0
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd) || exit 0
  python3 -I "$root/scripts/plugin_updates.py" hook
} 2>/dev/null
exit 0
