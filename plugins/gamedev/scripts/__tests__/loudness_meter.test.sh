#!/usr/bin/env bash
# Runs test_loudness_meter.py: EBU Tech 3341 V4 cases 1, 2, 4, 5, 6 and 15-19 read within their tolerances, targets and the true-peak ceiling fire and stay quiet in tolerance, WAVE_FORMAT_EXTENSIBLE reads, exits 0/1/2/3 hold, nothing is written.
# Does not prove EBU Tech 3341 compliance (cases 7-14 and 20-23 are not run) or agreement with ffmpeg where ffmpeg is absent (the 4 ffmpeg cases skip), or Python 3.10/3.11 itself: a patched wave module stands in, and big-endian is a patched sys.byteorder.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
command -v ffmpeg >/dev/null 2>&1 \
  || echo "loudness_meter.test.sh: ffmpeg absent: the 4 ffmpeg decode/agreement cases are skipped; the missing-ffmpeg exit 3 case still runs"
PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_loudness_meter.py'
