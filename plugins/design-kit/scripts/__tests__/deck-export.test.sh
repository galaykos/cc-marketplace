#!/usr/bin/env bash
# Drives deck-export.sh: usage exit 2; --pdf with no browser exits 3 and names
# what to install; --pdf with a browser on this machine writes a real PDF (skipped
# with a note when none is found); --pptx without pptxgenjs and without consent
# exits 3 naming the variable; --pptx with DESIGN_KIT_TEST_NETWORK=1 installs and
# writes a PPTX whose slide count matches the deck (opt-in: it downloads).
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
printf '# T\n## One\n- a\n> notes: n\n## Two\n=> 42 | answer\n' > o.md
python3 "$here/deck-build.py" o.md --out deck.html >/dev/null

set +e; bash "$here/deck-export.sh" deck.html 2>/dev/null; rc=$?; set -e
[ "$rc" = 2 ] || { echo "FAIL: no mode should exit 2 (rc=$rc)"; exit 1; }

set +e; DESIGN_KIT_BROWSER=/nonexistent bash "$here/deck-export.sh" deck.html --pdf 2>err.txt; rc=$?; set -e
[ "$rc" = 3 ] && grep -q "Install one of" err.txt || { echo "FAIL: missing browser should exit 3 with install hint (rc=$rc)"; cat err.txt; exit 1; }

set +e; bash "$here/deck-export.sh" deck.html --pdf --out out.pdf >/dev/null 2>err.txt; rc=$?; set -e
if [ "$rc" = 3 ]; then
  echo "note: no Chromium-family browser on this machine — real PDF path not exercised"
else
  [ "$rc" = 0 ] && head -c 4 out.pdf | grep -q '%PDF' || { echo "FAIL: pdf export rc=$rc"; cat err.txt; exit 1; }
fi

set +e; bash "$here/deck-export.sh" deck.html --pptx 2>err.txt; rc=$?; set -e
if command -v node >/dev/null 2>&1; then
  [ "$rc" = 3 ] && grep -q "DESIGN_KIT_PPTX_INSTALL=1" err.txt || { echo "FAIL: pptx without consent should exit 3 naming the variable (rc=$rc)"; cat err.txt; exit 1; }
  [ -d .design-kit/.cache/node_modules ] && { echo "FAIL: installed without consent"; exit 1; }
  if [ "${DESIGN_KIT_TEST_NETWORK:-0}" = "1" ]; then
    DESIGN_KIT_PPTX_INSTALL=1 bash "$here/deck-export.sh" deck.html --pptx --out out.pptx >/dev/null 2>err.txt || { echo "FAIL: pptx export"; cat err.txt; exit 1; }
    n="$(python3 -c "import zipfile;print(len([x for x in zipfile.ZipFile('out.pptx').namelist() if x.startswith('ppt/slides/slide') and x.endswith('.xml')]))")"
    [ "$n" = 3 ] || { echo "FAIL: pptx has $n slides, deck has 3"; exit 1; }
    python3 -c "import zipfile;z=zipfile.ZipFile('out.pptx');assert '42' in z.read('ppt/slides/slide3.xml').decode();assert any('notesSlide' in x for x in z.namelist())" || { echo "FAIL: pptx content"; exit 1; }
  else
    echo "note: DESIGN_KIT_TEST_NETWORK not set — pptxgenjs install path not exercised"
  fi
else
  [ "$rc" = 3 ] && grep -q "node is required" err.txt || { echo "FAIL: no node should exit 3 (rc=$rc)"; exit 1; }
fi
echo "PASS deck-export.test.sh"
