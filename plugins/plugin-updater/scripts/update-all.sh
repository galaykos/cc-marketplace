#!/usr/bin/env bash
# update-all.sh — update every installed Claude Code plugin across all scopes and project folders, one at a time; --dry-run lists only, --last prints the last background run. Exit 0 done, 1 a failure or a changed command needs you, 2 a precondition or another run holds the lock.
# Never passes -y or --accept-command: an update whose marketplace-declared command changed is reported for the person, never accepted.
# Why, limits, history: rationale/derivations/plugin-plugin-updater.md § plugins/plugin-updater/scripts/update-all.sh
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
command -v python3 >/dev/null 2>&1 || { echo "update-all.sh: python3 not found on PATH" >&2; exit 2; }
exec python3 -I "$here/plugin_updates.py" update "$@"
