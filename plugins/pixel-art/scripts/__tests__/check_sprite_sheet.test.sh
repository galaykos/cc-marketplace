#!/usr/bin/env bash
# Proves check_sprite_sheet.py's CLI contract and its sheet-vs-JSON rules on Aseprite-shaped fixture exports.
# Does NOT prove the fixtures match what a given Aseprite release writes: no Aseprite binary runs here.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_check_sprite_sheet.py'
