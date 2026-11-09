#!/usr/bin/env bash
# Runs test_check_itch_html5.py on ZIPs built in a temp dir: each error and warning code fires, the at-limit ZIPs (1,000 files, 500 MB, 200 MB, 240 characters, unflagged UTF-8) stay clean, exits 0/1/2 hold, nothing is written.
# Does not prove itch.io's upload enforces exactly these limits today: the cases encode https://itch.io/docs/creators/html5 as read on 2026-11-09, and no case uploads.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"; PYTHONDONTWRITEBYTECODE=1 python3 -I -B -m unittest discover -s "$here" -p 'test_check_itch_html5.py'
