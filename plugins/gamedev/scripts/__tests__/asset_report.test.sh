#!/usr/bin/env bash
# Runs test_asset_report.py: size/alpha/colour pass and fail cases (Pillow only), and the missing-Pillow exit 2 forced by a stub PIL (everywhere).
# Does not prove the checks catch every fake-transparency file: one transparent pixel anywhere passes --require-alpha.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
python3 -I -c 'import PIL' >/dev/null 2>&1 \
  || echo "asset_report.test.sh: Pillow absent: the 4 image cases are skipped; the missing-Pillow case still runs"
PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_asset_report.py'
