# find-browser.sh, sourced by preview-feedback.sh (shot) and preview-check.sh: find_browser prints the first Chromium-family browser, from $PREVIEW_BROWSER alone when it is set, else PATH, the macOS app bundles, Playwright's cache; returns 1 when none is found.
# Misses: Firefox and Safari; a browser installed anywhere else; a browser that is found but cannot start (the caller sees that when it runs it).
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/preview-check.sh
find_browser() {
  if [ -n "${PREVIEW_BROWSER:-}" ]; then
    [ -x "$PREVIEW_BROWSER" ] && { echo "$PREVIEW_BROWSER"; return 0; }
    return 1
  fi
  local c
  for c in google-chrome chromium chromium-browser microsoft-edge chrome; do
    command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return 0; }
  done
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
           "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "$HOME"/Library/Caches/ms-playwright/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium \
           "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux*/chrome; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}
