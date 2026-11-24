#!/usr/bin/env bash
# Drives artifact-bundle.py: a page with local css/js/png/woff and a relative link becomes ONE file (data URIs, no local refs left), stamped, v1 then v2 kept; an https script is reported not inlined; a markdown fixture renders headings, a table and code through the shell; --zip writes an archive; a Latin-1 file is refused with a position; an index page is named after its folder, and a slug whose ledger names another source warns.
# NOT PROVEN here: that dk bundle prints the report (dk.test.sh).
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
grep -qE '<meta name="design-kit-tokens" content="none (none|[0-9a-f]{7,})">' "$f" || { echo "FAIL: tokens stamp on artifact"; grep design-kit-tokens "$f"; exit 1; }
[ "$(grep -c 'name="design-kit-tokens"' "$f")" -eq 1 ] || { echo "FAIL: tokens stamp duplicated"; exit 1; }
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

# out-of-tree refs stay external and are reported; nothing outside the input tree is inlined
mkdir -p "$tmp/tree" "$tmp/secret"; echo "SECRET-MARKER-42" > "$tmp/secret/key.txt"
printf '<html><head><link rel="stylesheet" href="../secret/key.txt"></head><body><img src="/etc/hosts"><p>x</p></body></html>' > "$tmp/tree/probe.html"
o="$($b "$tmp/tree/probe.html" --out-dir "$out" 2>&1)"
grep -q "SECRET-MARKER-42" "$out/probe.html" && { echo "FAIL: out-of-tree file inlined"; exit 1; }
case "$o" in *"resolves outside the input tree"*) ;; *) echo "FAIL: out-of-tree ref not reported: $o"; exit 1 ;; esac
grep -q 'href="../secret/key.txt"' "$out/probe.html" || { echo "FAIL: out-of-tree ref not left in place"; exit 1; }

# size ceiling warns (exit 0) — ceiling lowered through the harness-only env override
o="$(DESIGN_KIT_MAX_BYTES=100 $b "$tmp/tree/probe.html" --out-dir "$out" 2>&1)" || { echo "FAIL: over-ceiling should still exit 0"; exit 1; }
case "$o" in *"over the 16 MiB ceiling"*) ;; *) echo "FAIL: no size warning: $o"; exit 1 ;; esac

# an index page takes its folder's name, so two of them keep two histories; the same source again says nothing
idx="$tmp/idx"; real="$(cd "$tmp" && pwd -P)"; mkdir -p "$tmp/a" "$tmp/b" "$tmp/C d" "$tmp/other/a" "$tmp/index"
for p in a/index.html b/index.html "C d/Index.htm" other/a/index.html index/index.html; do printf '<html><head></head><body>from %s</body></html>' "$p" > "$tmp/$p"; done
o="$($b "$tmp/a/index.html" --out-dir "$idx"; $b "$tmp/b" --out-dir "$idx"; $b "$tmp/C d/Index.htm" --out-dir "$idx"; cd "$tmp/a"; $b index.html --out-dir "$idx")"
[ "$(cd "$idx" && echo *.html)" = "a.html b.html c-d.html" ] && grep -q 'from a/index' "$idx/a.html" && grep -q 'from b/index' "$idx/b.html" \
  || { echo "FAIL: two index pages in different folders make two slugs: $(cd "$idx" && echo *.html)"; exit 1; }
case "$o" in *WARN:*) echo "FAIL: one source per slug warned: $o"; exit 1 ;; esac
# another source for a slug warns and joins the history as it stands; the ledger then names it
one="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["versions"])' "$idx/a.versions.json")"
o="$($b "$tmp/other/a/index.html" --out-dir "$idx")"
case "$o" in *"WARN: slug \"a\" already holds versions of $real/a/index.html; pass --name to keep them apart"*) ;; *) echo "FAIL: a second source for a slug warns: $o"; exit 1 ;; esac
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert str(d["versions"][:2])==sys.argv[2] and len(d["versions"])==3 and d["source"]==sys.argv[3], d' "$idx/a.versions.json" "$one" "$real/other/a/index.html" \
  || { echo "FAIL: a second source rewrote the ledger's versions or is not its source"; exit 1; }
case "$($b "$tmp/other/a/index.html" --out-dir "$idx")" in *WARN:*) echo "FAIL: the ledger's own source warned"; exit 1 ;; esac
# a ledger from before 0.20.0 names no source: it takes this one and says nothing; a link to the same file is the same source
printf '{"slug": "old", "versions": [{"v": 1, "sha256": "x"}]}' > "$idx/old.versions.json"
cp "$tmp/a/index.html" "$tmp/old.html"; ln -s old.html "$tmp/link.html"
o="$($b "$tmp/old.html" --out-dir "$idx"; $b "$tmp/link.html" --name old --out-dir "$idx")"
case "$o" in *WARN:*) echo "FAIL: a ledger with no source adopts silently: $o"; exit 1 ;; esac
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d.get("source")==sys.argv[2] and d["versions"][0]=={"v":1,"sha256":"x"} and [v["v"] for v in d["versions"]]==[1,2,3], d' "$idx/old.versions.json" "$real/old.html" \
  || { echo "FAIL: a ledger with no source adopts this one and keeps its versions"; exit 1; }
# the index.html every index page shared until 0.20.0 is left and named, unless --name chose the slug or the page itself writes it
left="WARN: artifacts/index.html from an earlier bundle is left in place"
printf OLD > "$idx/index.html"
case "$($b "$tmp/b/index.html" --out-dir "$idx")" in *"$left"*) ;; *) echo "FAIL: an earlier artifacts/index.html is not named"; exit 1 ;; esac
case "$($b "$tmp/b/index.html" --name b --out-dir "$idx")" in *"$left"*) echo "FAIL: --name b named the earlier index.html"; exit 1 ;; esac
[ "$(cat "$idx/index.html")" = OLD ] || { echo "FAIL: the earlier index.html was touched"; exit 1; }
case "$($b "$tmp/index" --out-dir "$idx")" in *"$left"*) echo "FAIL: a folder named index was told its own page is left in place"; exit 1 ;; esac
# at the filesystem root the folder has no name: the file's own name stays
python3 -I -B - "$here/artifact-bundle.py" "$tmp/root" >/dev/null <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("ab", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
isfile = os.path.isfile
os.path.isfile = lambda p: p == "/index.html" or isfile(p)
m.read_utf8 = lambda p: "<p>at the root</p>"
m.main(["/index.html", "--out-dir", sys.argv[2]])
PY
[ "$(cd "$tmp/root" && echo *.html)" = index.html ] || { echo "FAIL: /index.html should keep the name index: $(cd "$tmp/root" && echo *.html)"; exit 1; }

echo "PASS artifact-bundle.test.sh"
