#!/usr/bin/env bash
# Proves check_ebitengine.py's CLI contract, its masking and its Update/Draw-body rules on fixture Go.
# Does NOT prove a flagged call is wrong in a real project: no Go toolchain or type checker runs here.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_*.py'
