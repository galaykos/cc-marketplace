#!/usr/bin/env bash
# Runs test_check_steam_build.py: Valve's SDK sample scripts and game-ci output shapes check clean, each error and warning code fires, exit codes 0/1/2 hold, and nothing is written.
# Does not prove the rules match what steamcmd does today: the cases encode the Steamworks docs as read, and no case runs steamcmd.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_check_steam_build.py'
