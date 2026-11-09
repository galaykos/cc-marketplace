#!/usr/bin/env bash
# Runs test_check_phaser_v4.py: Math.PI2, type: Phaser.CANVAS and an unrendered RenderTexture/DynamicTexture fire on Phaser 4, also inside a template's ${}; comments, strings, template text, regex literals, rendered or auto-rendering textures and a Phaser 3 project stay silent; exit codes 0/1/2 hold; nothing is written.
# Does not prove Phaser agrees: no browser or Phaser build runs here, the fixtures encode the v4 migration guide as read on 2026-11-09.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_check_phaser_v4.py'
