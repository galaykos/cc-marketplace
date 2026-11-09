#!/usr/bin/env bash
# Runs test_check_unreal_project.py: every source rule fires inside its version window and stays silent in comments, strings, successor names, #if 0 and engine-version #if branches; each Zen/DDC config code fires on 5.8 and not on 5.7; exit codes 0/1/2 hold; nothing is written.
# Does not prove Unreal agrees: no engine or compiler runs here, the fixtures encode Epic's release notes as read on 2026-11-09.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_check_unreal_project.py'
