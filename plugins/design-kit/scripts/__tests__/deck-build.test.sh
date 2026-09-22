#!/usr/bin/env bash
# Drives deck-build.py on a fixture outline: slide count, hash ids, notes in
# data-notes and <aside>, the big figure, a nested list, a data-URI image,
# self-containment (no external src/href), the 6-line gate (exit 2) and
# --allow-long, the missing-title gate, and theme pickup from DESIGN-SYSTEM.md.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
printf 'PNG' > pic.png
cat > outline.md <<'EOF'
# Quarterly review

A subtitle line

## Revenue grew because of retention

- Net revenue retention hit 118%
- Churn fell
  - SMB churn halved
- New logos flat

> notes: Lead with retention.
> Chart is next.

## The one number

=> 118% | net revenue retention

## Code and picture

```js
const x = 1;
```

![a picture](pic.png)
EOF
python3 "$here/deck-build.py" outline.md --out deck.html >/dev/null
[ "$(grep -c '<section class="slide' deck.html)" = 4 ] || { echo "FAIL: expected 4 sections"; exit 1; }
grep -q 'id="s4"' deck.html || { echo "FAIL: hash id s4 missing"; exit 1; }
grep -q 'data-notes="Lead with retention.' deck.html || { echo "FAIL: notes not in data-notes"; exit 1; }
grep -q '<aside class="notes">Lead with retention.' deck.html || { echo "FAIL: notes aside missing"; exit 1; }
grep -q '<div class="value">118%</div>' deck.html || { echo "FAIL: big figure missing"; exit 1; }
grep -q '<li>SMB churn halved' deck.html || { echo "FAIL: nested bullet missing"; exit 1; }
grep -q 'src="data:image/png;base64,' deck.html || { echo "FAIL: image not inlined"; exit 1; }
grep -q '<code class="language-js">const x = 1;' deck.html || { echo "FAIL: code block missing"; exit 1; }
grep -qE '(src|href)="(https?:)?//' deck.html && { echo "FAIL: external reference in deck"; exit 1; }
grep -q '<title>Quarterly review</title>' deck.html || { echo "FAIL: title missing"; exit 1; }

cat > long.md <<'EOF'
# Long
## Too long
- a
- b
- c
- d
- e
- f
- g
EOF
set +e; python3 "$here/deck-build.py" long.md --out long.html 2>err.txt; rc=$?; set -e
[ "$rc" = 2 ] && grep -q "over 6 visible lines" err.txt || { echo "FAIL: 7-line slide should exit 2 (rc=$rc)"; cat err.txt; exit 1; }
python3 "$here/deck-build.py" long.md --out long.html --allow-long 2>err.txt >/dev/null
grep -q "^WARN" err.txt || { echo "FAIL: --allow-long should warn"; exit 1; }

printf '## No title slide\n- x\n' > notitle.md
set +e; python3 "$here/deck-build.py" notitle.md --out nt.html 2>/dev/null; rc=$?; set -e
[ "$rc" = 2 ] || { echo "FAIL: missing title should exit 2 (rc=$rc)"; exit 1; }

mkdir -p design-system
cat > design-system/DESIGN-SYSTEM.md <<'EOF'
## Design system
- Colors: primary #1a4d8f, accent #f59e0b, surface #f8fafc
- Typography: Inter for body, JetBrains Mono for code
EOF
python3 "$here/deck-build.py" outline.md --out themed.html 2>err.txt >/dev/null
grep -q 'dk-accent:#1a4d8f' themed.html || { echo "FAIL: theme accent not applied"; grep dk- themed.html | head -3; exit 1; }
grep -q 'dk-font:"Inter"' themed.html || { echo "FAIL: theme font not applied"; exit 1; }
grep -q "DESIGN-SYSTEM.md" err.txt || { echo "FAIL: theme source not reported"; exit 1; }
sha="$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest()[:12])" design-system/DESIGN-SYSTEM.md)"
grep -q "<meta name=\"design-kit-tokens\" content=\"$sha " themed.html || { echo "FAIL: tokens stamp sha"; grep design-kit-tokens themed.html; exit 1; }

python3 "$here/deck-build.py" outline.md >out.txt 2>/dev/null
grep -qE '^deck-build: \.design-kit/decks/[0-9]{4}-[0-9]{2}-[0-9]{2}-quarterly-review\.html' out.txt || { echo "FAIL: default output path: $(cat out.txt)"; exit 1; }
echo "PASS deck-build.test.sh"
