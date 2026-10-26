#!/usr/bin/env bash
# Proves check_godot_project.py's codes, severities and exit codes on throwaway projects built in a temp dir.
# Does NOT prove Godot itself agrees: no engine binary runs here, the fixtures encode the expected loader behaviour.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_*.py'
