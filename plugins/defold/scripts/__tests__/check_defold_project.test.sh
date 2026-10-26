#!/usr/bin/env bash
# Runs test_check_defold_project.py: 25 end-to-end cases that build Defold projects in a temp dir
# and assert the checker's exit codes, JSON schema, errors and warnings. It does not run Bob or a
# Defold engine, so it proves the checker matches its own fixtures, not Bob's real behaviour.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_*.py'
