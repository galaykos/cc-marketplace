#!/usr/bin/env bash
# Runs the forge library's in-Blender tests (blender/test_*.py) through blender/run.py; skips when no Blender is found.
# Usage: forge-lib.test.sh [test_module ...] [-k substring]
set -u
here=$(cd "$(dirname "$0")" && pwd)
blender=$(cd "$here/../../server/forge_server" && python3 -c 'import headless; p, _ = headless.find_blender(); print(p or "")')
if [ -z "$blender" ]; then printf 'SKIP: no Blender found; forge library tests not run\n'; exit 0; fi
WAYLAND_DISPLAY= "$blender" -b --factory-startup --python-exit-code 1 --python "$here/blender/run.py" -- "$@" 2>&1 \
  | grep -E '^(PASS|FAIL|  failed|[0-9]+ passed)|Error|Traceback|^  File|^    |^[A-Za-z]*Error'
exit "${PIPESTATUS[0]}"
