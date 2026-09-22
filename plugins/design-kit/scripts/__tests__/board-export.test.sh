#!/usr/bin/env bash
# Drives board-export.sh: no browser → install hint and exit 3; missing meta tags →
# exit 2; with a browser on this machine, one artboard exports to a real PNG and
# --pdf writes a PDF. The browser half is skipped with a message when none exists.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
set +e
DESIGN_KIT_BROWSER=/nonexistent bash "$here/board-export.sh" x.html --png >out 2>err; rc=$?
set -e
[ "$rc" = 3 ] || { echo "FAIL: expected exit 3 without a browser, got $rc"; cat err; exit 1; }
grep -qi "install" err && grep -q "DESIGN_KIT_BROWSER" err || { echo "FAIL: install hint"; cat err; exit 1; }

cat > spec.json <<'JSON'
{"title":"Export probe","boards":[
 {"title":"A","tradeoff":"a","device":"phone","body":"<div class=\"dk-pad\"><h1>Artboard A</h1><p>Visible in the PNG.</p></div>"},
 {"title":"B","tradeoff":"b","device":"phone","body":"<div class=\"dk-pad\"><h1>Artboard B</h1></div>"}]}
JSON
python3 "$here/board-build.py" spec.json --out board.html >/dev/null 2>&1
if ! browser="$(bash "$here/board-export.sh" --which 2>/dev/null)"; then
  echo "PASS board-export.test.sh (no browser on this machine; PNG/PDF half skipped)"; exit 0
fi
printf '<html><body>no meta</body></html>' > plain.html
set +e; bash "$here/board-export.sh" plain.html --png >out 2>err; rc=$?; set -e
[ "$rc" = 2 ] || { echo "FAIL: expected exit 2 for a page without meta tags, got $rc"; exit 1; }
png="$(bash "$here/board-export.sh" board.html --png --board 2)"
[ -s "$png" ] || { echo "FAIL: no PNG"; exit 1; }
[ "$(head -c 8 "$png" | od -An -tx1 | tr -d ' \n')" = "89504e470d0a1a0a" ] || { echo "FAIL: not a PNG"; exit 1; }
case "$png" in *board-2.png) ;; *) echo "FAIL: name $png"; exit 1 ;; esac
[ -f "${png%-board-2.png}-board-1.png" ] && { echo "FAIL: --board 2 exported artboard 1 too"; exit 1; }
pdf="$(bash "$here/board-export.sh" board.html --pdf)"
[ -s "$pdf" ] && [ "$(head -c 4 "$pdf")" = "%PDF" ] || { echo "FAIL: PDF"; exit 1; }
echo "PASS board-export.test.sh (browser: $browser)"
