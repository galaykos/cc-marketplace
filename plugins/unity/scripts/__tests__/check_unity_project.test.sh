#!/usr/bin/env bash
# Proves check_unity_project.py's verdicts, exit codes and JSON shape on synthetic projects (32 unittest cases).
# Does NOT prove it against a real Unity install; the peak-memory probe runs only where /proc exists (Linux).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_*.py'
