#!/usr/bin/env bash
# Proves check_bpy_scripts.py's CLI contract and rule windows on fixture Python, and blender_qa.py's pure parts and exit codes.
# Does NOT prove a rule against a real Blender unless BLENDER_EXE names a binary: CI has none, so those tests skip there.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_*.py'
