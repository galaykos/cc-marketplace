#!/usr/bin/env bash
# Drives artifact-bundle.py: a page with local css/js/png/woff and a relative link
# becomes ONE file (data URIs, no local refs left), stamped, v1 then v2 kept; an
# https script is reported not inlined; a markdown fixture renders headings, a
# table and code through the shell; --zip writes an archive; a Latin-1 file is
# refused with a position.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
b="python3 $here/artifact-bundle.py"
out="$tmp/out"

mkdir -p "$tmp/site/css" "$tmp/site/img" "$tmp/site/fonts"
printf 'body{background:url(../img/dot.png);} @font-face{font-family:F;src:url(../fonts/f.woff2)}' > "$tmp/site/css/a.css"
printf 'console.log("hi")' > "$tmp/site/app.js"
printf '\x89PNG\r\n\x1a\nfake' > "$tmp/site/img/dot.png"
printf 'wOF2fake' > "$tmp/site/fonts/f.woff2"
cat > "$tmp/site/index.html" <<'EOF'
<!doctype html><html><head><title>Fixture</title>
<link rel="stylesheet" href="css/a.css">
<script src="https://cdn.example.com/lib.js"></script>
</head><body>
<img src="img/dot.png" alt="">
<a href="about.html">about</a> <a href="#top">top</a>
<script src="app.js"></script>
</body></html>
EOF

r1="$($b "$tmp/site/index.html" --name fixture --out-dir "$out")"
f="$out/fixture.html"
[ -f "$f" ] || { echo "FAIL: no output"; exit 1; }
grep -q 'data:image/png;base64,' "$f" || { echo "FAIL: png not inlined"; exit 1; }
grep -q 'data:font/woff2;base64,' "$f" || { echo "FAIL: woff2 not inlined"; exit 1; }
grep -q 'console.log("hi")' "$f" || { echo "FAIL: js not inlined"; exit 1; }
grep -q 'background:url(' "$f" || { echo "FAIL: css not inlined"; exit 1; }
grep -qE 'src="app.js"|href="css/a.css"|url\(\.\./img' "$f" && { echo "FAIL: local ref left"; exit 1; }
grep -q 'src="https://cdn.example.com/lib.js"' "$f" || { echo "FAIL: https script should stay external"; exit 1; }
case "$r1" in *"network: https://cdn.example.com/lib.js"*) ;; *) echo "FAIL: network not reported: $r1"; exit 1 ;; esac
case "$r1" in *"unresolved-link: about.html"*) ;; *) echo "FAIL: relative link not reported"; exit 1 ;; esac
grep -qE '<meta name="design-kit-artifact" content="fixture v1 [0-9]{4}-' "$f" || { echo "FAIL: v1 stamp"; exit 1; }
[ -f "$out/.versions/fixture/v1.html" ] || { echo "FAIL: v1 not kept"; exit 1; }

$b "$tmp/site/index.html" --name fixture --out-dir "$out" --zip >/dev/null
grep -q 'content="fixture v2 ' "$f" || { echo "FAIL: v2 stamp"; exit 1; }
[ -f "$out/.versions/fixture/v2.html" ] && [ -f "$out/.versions/fixture/v1.html" ] || { echo "FAIL: versions not both kept"; exit 1; }
python3 -c "import json,sys;d=json.load(open('$out/fixture.versions.json'));sys.exit(0 if [v['v'] for v in d['versions']]==[1,2] else 1)" || { echo "FAIL: ledger"; exit 1; }
[ -f "$out/fixture.zip" ] || { echo "FAIL: zip"; exit 1; }
python3 -c "import zipfile;assert zipfile.ZipFile('$out/fixture.zip').namelist()==['fixture.html']"

cat > "$tmp/doc.md" <<'EOF'
# Status report

Some *text* with `code` and a [link](https://example.com).

| col a | col b |
|---|---|
| 1 | 2 |

- one
- two

```sh
echo hi
```
EOF
$b "$tmp/doc.md" --out-dir "$out" >/dev/null
d="$out/doc.html"
grep -q '<title>Status report</title>' "$d" || { echo "FAIL: md title"; exit 1; }
grep -q '<h1>Status report</h1>' "$d" || { echo "FAIL: md h1"; exit 1; }
grep -q '<table><thead><tr><th>col a</th><th>col b</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>' "$d" || { echo "FAIL: md table"; exit 1; }
grep -q '<pre><code class="language-sh">echo hi</code></pre>' "$d" || { echo "FAIL: md code"; exit 1; }
grep -q '<ul><li>one</li><li>two</li></ul>' "$d" || { echo "FAIL: md list"; exit 1; }
grep -q '<em>text</em> with <code>code</code> and a <a href="https://example.com">link</a>' "$d" || { echo "FAIL: md inline"; exit 1; }
grep -q 'data-design-kit-reload' "$d" && { echo "FAIL: reload snippet leaked into an artifact"; exit 1; }

printf '<html><body>caf\xe9</body></html>' > "$tmp/latin.html"
if err="$($b "$tmp/latin.html" --out-dir "$out" 2>&1)"; then echo "FAIL: latin-1 accepted"; exit 1; fi
case "$err" in *"not valid UTF-8 at byte 15 (line 1, column 16)"*) ;; *) echo "FAIL: utf-8 message: $err"; exit 1 ;; esac

echo "PASS artifact-bundle.test.sh"
