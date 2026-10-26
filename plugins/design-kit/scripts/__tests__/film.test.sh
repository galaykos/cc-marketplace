#!/usr/bin/env bash
# Drives film.py through test_film.py: doctor's exit 3, the synth → beat-detection round trip, every check rule, the moov order.
# NOT PROVEN where ffmpeg/ffprobe are absent: sheet, cuts, loudness, pops and the video probes skip and say so; nothing judges a film.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_film.py' -v 2>&1 | tail -n 40
