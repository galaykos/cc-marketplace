#!/usr/bin/env bash
# deck-export.sh <deck.html> --pdf|--pptx [--out <file>]
#
# WHAT IT DOES. --pdf prints the deck (its print CSS is one 1280x720 page per
# slide) with a headless Chromium-family browser: $DESIGN_KIT_BROWSER if set,
# else the first found of Chrome / Chromium / Edge / Brave on macOS and Linux
# paths, else a Playwright-installed chromium under the user's cache. --pptx
# runs deck-export-pptx.mjs with pptxgenjs, read from
# .design-kit/.cache/node_modules (at the git root, or under $DESIGN_KIT_DIR),
# which this script installs ONLY when
# DESIGN_KIT_PPTX_INSTALL=1 — the command sets that after the user consented.
#
# EXIT CODES. 0 written · 2 usage · 3 a tool is missing (stderr says exactly
# what to install or which consent is needed) · 4 the tool ran and produced
# nothing usable. Standing: scripts/__tests__/deck-export.test.sh drives the
# missing-browser path, the consent-gated pptx path, and a real PDF when a
# browser exists on the machine running the harness. Nothing here proves the PDF
# looks right — open it.
set -euo pipefail

deck=""; mode=""; out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --pdf|--pptx) mode="${1#--}" ;;
    --out) out="$2"; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    -*) echo "deck-export: unknown flag $1" >&2; exit 2 ;;
    *) deck="$1" ;;
  esac
  shift
done
[ -n "$deck" ] && [ -n "$mode" ] || { echo "usage: deck-export.sh <deck.html> --pdf|--pptx [--out <file>]" >&2; exit 2; }
[ -f "$deck" ] || { echo "deck-export: no such deck: $deck" >&2; exit 2; }
[ -n "$out" ] || out="${deck%.html}.$mode"
here="$(cd "$(dirname "$0")" && pwd)"

find_browser() {
  if [ -n "${DESIGN_KIT_BROWSER:-}" ]; then
    [ -x "$DESIGN_KIT_BROWSER" ] && { echo "$DESIGN_KIT_BROWSER"; return 0; }
    return 1
  fi
  local c
  for c in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
    google-chrome google-chrome-stable chromium chromium-browser microsoft-edge brave-browser; do
    if [ -x "$c" ]; then echo "$c"; return 0; fi
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  for c in "$HOME/Library/Caches/ms-playwright"/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium \
           "$HOME/.cache/ms-playwright"/chromium-*/chrome-linux*/chrome; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

case "$mode" in
  pdf)
    browser="$(find_browser)" || {
      cat >&2 <<'EOF'
deck-export: no Chromium-family browser found for --pdf.
  Install one of: Google Chrome (https://www.google.com/chrome/), Chromium, Microsoft Edge, Brave,
  or `npx playwright install chromium`, or point DESIGN_KIT_BROWSER at a browser binary.
  Without one, open the deck in any browser and press P — the print dialog's "Save as PDF" is the same output.
EOF
      exit 3
    }
    abs="$(cd "$(dirname "$deck")" && pwd)/$(basename "$deck")"
    "$browser" --headless=new --disable-gpu --no-sandbox --no-pdf-header-footer \
      --print-to-pdf="$out" "file://$abs" >/dev/null 2>&1 || true
    [ -s "$out" ] && head -c 4 "$out" | grep -q '%PDF' || { echo "deck-export: browser produced no PDF at $out" >&2; exit 4; }
    echo "deck-export: $out"
    ;;
  pptx)
    command -v node >/dev/null 2>&1 || { echo "deck-export: node is required for --pptx (https://nodejs.org)" >&2; exit 3; }
    # $DESIGN_KIT_DIR from dk.sh, else .design-kit at the git root — not under a
    # subdirectory the shell cd'd into, where a second pptxgenjs install would land
    cache="${DESIGN_KIT_DIR:-$(git rev-parse --show-cdup 2>/dev/null || true).design-kit}/.cache"
    if [ ! -d "$cache/node_modules/pptxgenjs" ]; then
      if [ "${DESIGN_KIT_PPTX_INSTALL:-0}" != "1" ]; then
        cat >&2 <<EOF
deck-export: --pptx needs the pptxgenjs npm package, not installed yet.
  It goes into $cache/node_modules (this project only, never global) — rerun with
  DESIGN_KIT_PPTX_INSTALL=1 once the user has agreed to that download.
EOF
        exit 3
      fi
      mkdir -p "$cache"
      [ -f "$cache/package.json" ] || printf '{"name":"design-kit-cache","private":true}\n' > "$cache/package.json"
      ( cd "$cache" && npm install --silent --no-audit --no-fund pptxgenjs >/dev/null ) \
        || { echo "deck-export: npm install pptxgenjs failed in $cache" >&2; exit 3; }
    fi
    NODE_PATH="$(cd "$cache/node_modules" && pwd)" node "$here/deck-export-pptx.mjs" "$deck" "$out" \
      || { echo "deck-export: pptx conversion failed" >&2; exit 4; }
    [ -s "$out" ] || { echo "deck-export: no file written at $out" >&2; exit 4; }
    echo "deck-export: $out"
    ;;
esac
