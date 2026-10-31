#!/usr/bin/env bash
# Proves check_tilemaps.py's CLI contract and its Tiled/LDtk reference, GID-masking and layer-format rules on fixture maps.
# Does NOT prove a real engine loads the map: no Tiled, LDtk, Phaser or melonJS runs here, and zstd is decoded only on Python 3.14+.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_check_tilemaps.py'
