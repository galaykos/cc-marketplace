#!/usr/bin/env bash
# Drives board-build.py: a JSON spec renders 3 artboards with knobs, pick buttons,
# meta sizes and no external request; a markdown spec parses; tokens.json steers
# the accent; the gates reject lorem, external assets, and a 1-artboard spec.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
cat > spec.json <<'JSON'
{"title":"Invoice inbox","brief":"Accountants triage 200 invoices a day","device":"desktop","boards":[
 {"title":"Dense table","tradeoff":"Fastest scan; weakest on phone","body":"<nav class=\"dk-nav\"><span class=\"brand\">Ledgerly</span><a href=\"#\" aria-current=\"page\">Inbox</a><a href=\"#\">Paid</a></nav><div class=\"dk-pad\"><h1>Inbox · 214 open</h1><table class=\"dk-table\"><tr><th>Vendor</th><th class=\"num\">Amount</th></tr><tr><td>Northwind Traders</td><td class=\"num\">€1,240.00</td></tr></table></div>"},
 {"title":"Card queue","tradeoff":"One decision at a time; slower bulk work","body":"<div class=\"dk-pad dk-stack\"><h1>Next up</h1><div class=\"dk-card\"><h3>Northwind Traders</h3><p class=\"muted\">Due in 3 days</p><button class=\"dk-btn\">Approve €1,240.00</button></div></div>"},
 {"title":"Split view","tradeoff":"Context without leaving the list; needs width","device":"tablet","body":"<div class=\"dk-sidebar\"><nav><a href=\"#\" aria-current=\"page\">Inbox</a><a href=\"#\">Paid</a></nav><div class=\"dk-pad\"><h2>Northwind Traders</h2><p>Invoice 8841 · €1,240.00</p></div></div>"}
]}
JSON
out="$(python3 "$here/board-build.py" spec.json --docroot .design-kit 2>/dev/null)"
[ -f "$out" ] || { echo "FAIL: no output file: $out"; exit 1; }
case "$out" in .design-kit/boards/*-invoice-inbox.html) ;; *) echo "FAIL: unexpected path $out"; exit 1 ;; esac
n="$(grep -c 'class="dk-board"' "$out")"; [ "$n" = 3 ] || { echo "FAIL: expected 3 artboards, got $n"; exit 1; }
grep -q 'id="dk-knobs"' "$out" || { echo "FAIL: knob panel missing"; exit 1; }
[ "$(grep -o 'data-act="pick">Pick' "$out" | wc -l | tr -d " ")" = 3 ] || { echo "FAIL: pick buttons"; exit 1; }
grep -q 'data-design-kit-board' "$out" || { echo "FAIL: board script missing"; exit 1; }
grep -q 'Copy edits as prompt' "$out" || { echo "FAIL: copy-as-prompt control missing"; exit 1; }
grep -q 'content="1:1280x800"' "$out" && grep -q 'content="3:768x1024"' "$out" || { echo "FAIL: meta sizes"; exit 1; }
grep -q '<option value="3">' "$out" || { echo "FAIL: scope options"; exit 1; }
grep -q 'contenteditable' "$out" || { echo "FAIL: shell lacks the contenteditable wiring"; exit 1; }
if grep -qE '(src|href)="https?://|@import|<link ' "$out"; then echo "FAIL: external reference in output"; exit 1; fi
grep -q '{{' "$out" && { echo "FAIL: unfilled slot"; exit 1; }

mkdir -p design-system
cat > design-system/tokens.json <<'JSON'
{"color":{"accent":{"$type":"color","$value":"#2f7d4f"}},"radius":{"md":{"$type":"dimension","$value":"6px"}},"space":{"base":{"$value":"10px"}},"font":{"family":{"body":{"$value":"Georgia, serif"}}}}
JSON
out2="$(python3 "$here/board-build.py" spec.json --out b2.html 2>err.txt)"
grep -q -- '--dk-accent-h:145' b2.html || { echo "FAIL: accent hue from tokens (expected 145)"; grep -o -- '--dk-accent-h:[0-9]*' b2.html; exit 1; }
grep -q -- '--dk-radius:6px' b2.html && grep -q -- '--dk-space:10px' b2.html && grep -q 'Georgia' b2.html || { echo "FAIL: tokens not applied"; cat err.txt; exit 1; }
sha="$(python3 -c "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest()[:12])" design-system/tokens.json)"
grep -q "<meta name=\"design-kit-tokens\" content=\"$sha " b2.html || { echo "FAIL: board tokens stamp"; grep design-kit-tokens b2.html; exit 1; }
grep -q '<meta name="design-kit-tokens" content="none ' "$out" || { echo "FAIL: untokened board should stamp none"; grep design-kit-tokens "$out"; exit 1; }

cat > spec.md <<'MD'
# Onboarding
Brief: New sellers list a first product in under five minutes
Device: phone

## Board: Single scroll
Trade-off: No navigation to learn; long on small screens
```html
<div class="dk-pad dk-stack"><h1>List your first product</h1><div class="dk-field"><label>Product name</label><input class="dk-input" value="Hand-thrown mug"></div><button class="dk-btn">Continue</button></div>
```

## Board: Stepper
Trade-off: Progress is visible; four taps minimum
```html
<div class="dk-pad dk-stack"><p class="muted">Step 1 of 4</p><h1>What are you selling?</h1><button class="dk-btn">Next</button></div>
```
MD
out3="$(python3 "$here/board-build.py" spec.md --out b3.html 2>/dev/null)"
[ "$(grep -c 'class="dk-board"' b3.html)" = 2 ] && grep -q 'content="1:375x812"' b3.html || { echo "FAIL: markdown spec"; exit 1; }
grep -q 'Hand-thrown mug' b3.html || { echo "FAIL: markdown body lost"; exit 1; }

python3 - <<'PY' > lorem.json
import json;s=json.load(open('spec.json'));s['boards'][1]['body']='<p>Lorem ipsum dolor</p>';print(json.dumps(s))
PY
python3 "$here/board-build.py" lorem.json --out x.html 2>e && { echo "FAIL: lorem accepted"; exit 1; } || [ $? = 2 ]
grep -q lorem e || { echo "FAIL: lorem message"; cat e; exit 1; }
python3 - <<'PY' > ext.json
import json;s=json.load(open('spec.json'));s['boards'][0]['body']='<img src="https://cdn.example.com/x.png">';print(json.dumps(s))
PY
python3 "$here/board-build.py" ext.json --out x.html 2>e && { echo "FAIL: external asset accepted"; exit 1; } || [ $? = 2 ]
python3 - <<'PY' > one.json
import json;s=json.load(open('spec.json'));s['boards']=s['boards'][:1];print(json.dumps(s))
PY
python3 "$here/board-build.py" one.json --out x.html 2>e && { echo "FAIL: 1 artboard accepted"; exit 1; } || [ $? = 2 ]
echo "PASS board-build.test.sh"
