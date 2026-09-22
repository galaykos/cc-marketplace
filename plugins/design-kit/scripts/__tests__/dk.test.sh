#!/usr/bin/env bash
# Drives every dk.sh verb against a temp Vite React project: system → check → slides →
# board → decision (posted through the server's loopback route) → scratch → bundle →
# share --zip → export (no-browser path) → status. Asserts workshop.json keys,
# usage.jsonl lines, the URL never being a literal port, and DECISIONS.md.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; port=$(( 20000 + RANDOM % 10000 ))
trap 'cd /; bash "$here/preview.sh" --docroot "$tmp/.design-kit" --stop >/dev/null 2>&1 || true; rm -rf "$tmp"' EXIT
cd "$tmp"; git init -q .
mkdir -p src/components
cat > package.json <<'J'
{"name":"fx","scripts":{"dev":"vite"},"dependencies":{"react":"^18.3.1","react-dom":"^18.3.1"},"devDependencies":{"vite":"^6.0.0","@vitejs/plugin-react":"^4.3.0"}}
J
printf 'import react from "@vitejs/plugin-react"\nexport default { plugins:[react()], server:{ port: 5177 } }\n' > vite.config.js
printf ':root{--color-primary:#1d4ed8;--color-text:#0b1a3a;--color-surface:#ffffff;--font-sans:"IBM Plex Sans",sans-serif;--space-2:8px;--radius-md:10px}\n' > src/index.css
printf 'export interface ButtonProps { variant?: "primary" | "ghost"; children: any }\nexport function Button(p: ButtonProps) { return null }\n' > src/components/Button.tsx
printf '# Deck\nsub\n\n## Claim one\n- a\n- b\n> notes: n\n' > outline.md
cat > spec.json <<'J'
{"title":"Fx board","brief":"b","boards":[{"title":"A","tradeoff":"t","body":"<div class=\"dk-pad\"><h1>Alpha</h1><p>Real text</p></div>"},{"title":"B","tradeoff":"t","body":"<div class=\"dk-pad\"><h1>Beta</h1><p>Real text</p></div>"}]}
J
printf '<!doctype html><html><head><title>Page</title></head><body><p>hi</p></body></html>' > page.html
export DESIGN_KIT_PORT="$port"
dk() { bash "$here/dk.sh" "$@"; }

out="$(dk system . 2>/dev/null)"
case "$out" in *"url=http://127.0.0.1:$port/previews/kit.html"*) ;; *) echo "FAIL: system url: $out"; exit 1 ;; esac
[ -f design-system/tokens.json ] && [ -f .design-kit/previews/kit.html ] || { echo "FAIL: system outputs"; exit 1; }
python3 -c 'import json;ws=json.load(open(".design-kit/workshop.json"));assert len(ws["system"]["stamp"])==12,ws' || { echo "FAIL: workshop system.stamp"; exit 1; }

chk="$(dk check)"; case "$chk" in "design-system: "*) ;; *) echo "FAIL: check line: $chk"; exit 1 ;; esac

out="$(dk slides outline.md 2>/dev/null)"
deck="$(echo "$out" | sed -n 's/^deck=//p')"; [ -f "$deck" ] || { echo "FAIL: deck not built: $out"; exit 1; }
case "$out" in *"url=http://127.0.0.1:$port/decks/"*) ;; *) echo "FAIL: deck url: $out"; exit 1 ;; esac

out="$(dk board spec.json 2>/dev/null)"
board="$(echo "$out" | sed -n 's/^board=//p')"; [ -f "$board" ] || { echo "FAIL: board not built: $out"; exit 1; }
grep -q "/_decision" "$board" || { echo "FAIL: board lacks the decision post"; exit 1; }

# no decision yet → exit 3
if dk decision --latest >/dev/null 2>&1; then echo "FAIL: decision should be empty"; exit 1; fi
# the board posts through the server; simulate that post
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Design-Kit-Decision: 1' -H 'Content-Type: application/json' \
  --data "{\"board\":\"$(basename "$board")\",\"picked\":2,\"knobs\":{\"all\":{\"hue\":200}},\"text\":{},\"prompt\":\"From the design board, implement artboard 2 (\\\"B\\\").\"}" "http://127.0.0.1:$port/_decision")"
[ "$code" = 200 ] || { echo "FAIL: decision post http $code"; exit 1; }
# a second post for the same board (a knob move after the pick) — consume must read both as one decision
curl -s -o /dev/null -X POST -H 'X-Design-Kit-Decision: 1' -H 'Content-Type: application/json' \
  --data "{\"board\":\"$(basename "$board")\",\"picked\":2,\"knobs\":{\"all\":{\"hue\":210}},\"text\":{},\"prompt\":\"From the design board, implement artboard 2 (\\\"B\\\").\\nGlobal adjustments: accent hue 210°.\"}" "http://127.0.0.1:$port/_decision"
p="$(dk decision --latest --consume)"
case "$p" in *"hue 210"*) ;; *) echo "FAIL: latest row not returned: $p"; exit 1 ;; esac
grep -q '"consumed": false' .design-kit/decisions.jsonl && { echo "FAIL: an earlier row of the same board stayed unread"; exit 1; }
case "$p" in *"implement artboard 2"*) ;; *) echo "FAIL: decision prose: $p"; exit 1 ;; esac
if dk decision --latest >/dev/null 2>&1; then echo "FAIL: decision not consumed"; exit 1; fi
python3 -c 'import json;ws=json.load(open(".design-kit/workshop.json"));assert ws["board"]["picked"]==2,ws' || { echo "FAIL: workshop board.picked"; exit 1; }
dk decision --record "board Fx board, artboard 2 (B), hue 200, rendered with Button; gaps: none" >/dev/null
grep -q "artboard 2 (B)" design-system/DECISIONS.md || { echo "FAIL: DECISIONS.md"; exit 1; }

dk scratch --detect | grep -q "stack=vite-react" || { echo "FAIL: scratch detect"; exit 1; }
dk scratch --create hero >/dev/null
python3 -c 'import json;ws=json.load(open(".design-kit/workshop.json"));assert ws["scratch"]["slug"]=="hero" and ws["scratch"]["kept"] is True' || { echo "FAIL: workshop scratch"; exit 1; }
if dk scratch --verify >/dev/null 2>&1; then echo "FAIL: verify should fail with scratch present"; exit 1; fi
dk scratch --cleanup >/dev/null; dk scratch --verify >/dev/null || { echo "FAIL: verify after cleanup"; exit 1; }

out="$(dk bundle page.html --name pg 2>/dev/null)"
case "$out" in *"artifact=.design-kit/artifacts/pg.html v1"*"url=http://127.0.0.1:$port/artifacts/pg.html"*) ;; *) echo "FAIL: bundle: $out"; exit 1 ;; esac
z="$(dk share .design-kit/artifacts/pg.html --zip)"; [ -f .design-kit/artifacts/pg.zip ] || { echo "FAIL: share zip: $z"; exit 1; }

if DESIGN_KIT_BROWSER=/nonexistent dk export "$deck" --pdf >/dev/null 2>&1; then echo "FAIL: export without browser should fail"; exit 1; fi

st="$(dk status)"
case "$st" in *"system [tokens "*"board ["*"picked 2"*"scratch [hero · cleaned]"*"artifact [pg v1]"*"deck ["*) ;; *) echo "FAIL: status: $st"; exit 1 ;; esac
case "$st" in *"server: http://127.0.0.1:$port/"*) ;; *) echo "FAIL: status server line: $st"; exit 1 ;; esac

# gallery flow strip + badge
gal="$(curl -s "http://127.0.0.1:$port/")"
case "$gal" in *'class="flow"'*"picked 2"*) ;; *) echo "FAIL: gallery flow strip"; exit 1 ;; esac

n="$(wc -l < .design-kit/usage.jsonl | tr -d ' ')"; [ "$n" -ge 12 ] || { echo "FAIL: usage.jsonl has $n lines"; exit 1; }
python3 -c '
import json
rows=[json.loads(l) for l in open(".design-kit/usage.jsonl")]
verbs={r["verb"] for r in rows}; need={"system","check","slides","board","decision","scratch","bundle","share","export","status"}
assert need<=verbs, need-verbs
assert all(set(r)=={"ts","verb","outcome","artifact"} for r in rows)
assert any(r["verb"]=="export" and r["outcome"]=="fail" for r in rows)
' || { echo "FAIL: usage.jsonl shape"; exit 1; }
grep -rq "8124" .design-kit/usage.jsonl .design-kit/workshop.json && { echo "FAIL: literal port in state"; exit 1; }
# self-ignore: first verb inside a git repo writes one managed block; a second verb leaves one block; tracked scratch is never ignored
dk="$here/dk.sh"; ig="$(mktemp -d)"; ( cd "$ig" && git init -q && git commit -q --allow-empty -m init
  out="$(bash "$dk" status 2>&1)"; case "$out" in *"added .design-kit/ and __design-kit__/ to .gitignore"*) ;; *) echo "FAIL: self-ignore line missing: $out"; exit 1 ;; esac
  git check-ignore -q .design-kit/x && git check-ignore -q __design-kit__/x || { echo "FAIL: scratch not ignored"; exit 1; }
  bash "$dk" status >/dev/null 2>&1; [ "$(grep -c 'design-kit scratch (managed' .gitignore)" = 1 ] || { echo "FAIL: managed block duplicated"; exit 1; }
  rm .gitignore; mkdir -p __design-kit__ && echo x > __design-kit__/keep && git add __design-kit__ && git commit -q -m tracked
  out="$(bash "$dk" status 2>&1)"; case "$out" in *".gitignore"*) echo "FAIL: tracked scratch must be left alone silently: $out"; exit 1 ;; esac
  [ ! -f .gitignore ] || { echo "FAIL: .gitignore written despite tracked scratch"; exit 1; }
  DESIGN_KIT_IGNORE=off bash "$dk" status >/dev/null 2>&1; [ ! -f .gitignore ] || { echo "FAIL: DESIGN_KIT_IGNORE=off ignored"; exit 1; }
) || exit 1; rm -rf "$ig"

echo "PASS dk.test.sh"
