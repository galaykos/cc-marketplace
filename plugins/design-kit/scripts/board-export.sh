#!/usr/bin/env bash
# board-export.sh — export a design board's artboards to PNG (one per artboard) or PDF.
#
# WHAT IT DOES. `board-export.sh <board.html> --png [--board N]` opens
# `file://…#board=N` in a headless Chromium-family browser at that artboard's own
# frame size (read from the page's `<meta name="design-kit-board" content="N:WxH">`
# tags; the shell isolates one artboard when the hash is set) and writes
# `<board>-board-N.png` beside the file — every artboard unless --board names one.
# `--pdf` prints the whole board through the shell's print CSS, one artboard per
# page, to `<board>.pdf`. `--which` prints the browser it would use and exits.
#
# BROWSER RESOLUTION, first hit wins: $DESIGN_KIT_BROWSER; google-chrome, chromium,
# chromium-browser, microsoft-edge, chrome on PATH; the macOS app bundles for
# Chrome, Chromium, Edge; a Playwright-installed Chromium under ~/Library/Caches or
# ~/.cache/ms-playwright. None found → the exact install hint, exit 3.
#
# WHAT IT DOES NOT DO. No Safari or Firefox (their headless screenshot flags
# differ; not wired). No scaling: PNGs are 1× at frame size. Standing:
# scripts/__tests__/board-export.test.sh drives the no-browser exit and, when a
# browser is present on the machine running it, one real PNG.
set -euo pipefail

usage() { sed -n '2,20p' "$0"; }

find_browser() {
  if [ -n "${DESIGN_KIT_BROWSER:-}" ]; then
    [ -x "$DESIGN_KIT_BROWSER" ] && { echo "$DESIGN_KIT_BROWSER"; return 0; }
    return 1
  fi
  local c
  for c in google-chrome chromium chromium-browser microsoft-edge chrome; do
    command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return 0; }
  done
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
           "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  for c in "$HOME"/Library/Caches/ms-playwright/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium \
           "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux*/chrome; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

board=""; mode=""; which_only=0; only=""
while [ $# -gt 0 ]; do
  case "$1" in
    --png) mode=png ;;
    --pdf) mode=pdf ;;
    --board) only="$2"; shift ;;
    --which) which_only=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "board-export: unknown flag $1" >&2; exit 2 ;;
    *) board="$1" ;;
  esac
  shift
done

if ! browser="$(find_browser)"; then
  cat >&2 <<'EOF'
board-export: no Chromium-family browser found.
  Install one of:
    macOS   brew install --cask google-chrome      (or chromium, microsoft-edge)
    Debian  sudo apt install chromium
    any     npx playwright install chromium         (then re-run; the cache path is probed)
  Or point DESIGN_KIT_BROWSER at an executable.
  Without one: open the board in any browser and print to PDF; the print CSS gives one artboard per page.
EOF
  exit 3
fi
[ "$which_only" = 1 ] && { echo "$browser"; exit 0; }

[ -n "$board" ] && [ -f "$board" ] || { echo "board-export: board.html path required" >&2; usage >&2; exit 2; }
[ -n "$mode" ] || { echo "board-export: choose --png or --pdf" >&2; exit 2; }
abs="$(cd "$(dirname "$board")" && pwd)/$(basename "$board")"
stem="${abs%.html}"

if [ "$mode" = pdf ]; then
  out="$stem.pdf"
  "$browser" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --run-all-compositor-stages-before-draw \
    --virtual-time-budget=3000 --no-pdf-header-footer --print-to-pdf="$out" "file://$abs" >/dev/null 2>&1 \
    || { echo "board-export: browser exited non-zero for PDF" >&2; exit 4; }
  [ -s "$out" ] || { echo "board-export: no PDF written" >&2; exit 4; }
  echo "$out"
  exit 0
fi

metas="$(grep -oE 'name="design-kit-board" content="[0-9]+:[0-9]+x[0-9]+"' "$abs" | grep -oE '[0-9]+:[0-9]+x[0-9]+' || true)"
[ -n "$metas" ] || { echo "board-export: no design-kit-board meta tags in $board — was it built by board-build.py?" >&2; exit 2; }
written=0
while IFS= read -r m; do
  n="${m%%:*}"; size="${m#*:}"; w="${size%x*}"; h="${size#*x}"
  [ -n "$only" ] && [ "$only" != "$n" ] && continue
  out="$stem-board-$n.png"
  "$browser" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --force-device-scale-factor=1 \
    --run-all-compositor-stages-before-draw --virtual-time-budget=3000 \
    --window-size="$w,$h" --screenshot="$out" "file://$abs#board=$n" >/dev/null 2>&1 \
    || { echo "board-export: browser exited non-zero for artboard $n" >&2; exit 4; }
  [ -s "$out" ] || { echo "board-export: no PNG written for artboard $n" >&2; exit 4; }
  echo "$out"; written=$((written + 1))
done <<< "$metas"
[ "$written" -gt 0 ] || { echo "board-export: artboard $only not in this board" >&2; exit 2; }
