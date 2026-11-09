#!/usr/bin/env bash
# Proves inspect_glb.py's CLI contract on struct-packed GLB/glTF fixtures: counts, extents, budgets, extensions, exit codes.
# Does NOT prove an engine imports a passing file: no importer runs here; KTX2 and WebP cases use hand-packed headers (real files were checked once, see the derivation).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_*.py'
