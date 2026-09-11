#!/usr/bin/env bash
# Harness for server/serve.py: boots a session on a free port against a scratch
# root and proves the bridge contract end to end — event append with a
# monotonic seq, long-poll delivery that advances the cursor exactly once,
# editor injection into served HTML, the CSRF header requirement, the
# path-traversal refusal, reply broadcast over SSE, proxy-mode injection and
# Location rewriting, and --status/--stop lifecycle. Stdlib python3 + curl only.
set -u
HERE="$(cd "$(dirname "$0")/../.." && pwd)"
SERVE="$HERE/server/serve.py"
pass=0; fail=0
T=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done; rm -rf "$T"; }
trap cleanup EXIT
ok()   { pass=$((pass+1)); }
bad()  { echo "FAIL $1"; [ -n "${2:-}" ] && echo "  $2" | head -5; fail=$((fail+1)); }

port_of() { python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['port'])" "$1"; }
wait_state() { for _ in $(seq 1 60); do [ -f "$1" ] && return 0; sleep 0.05; done; return 1; }

# ---- html mode ---------------------------------------------------------------
ROOT="$T/root"; mkdir -p "$ROOT/pages"
printf '<html><body><h1 id="t">hi</h1></body></html>' > "$ROOT/pages/index.html"
printf ':root{--background:#fff}' > "$ROOT/tokens.css"
THEME_DESIGN_QUIET=1 python3 "$SERVE" --root "$ROOT" --mode html --port 0 >"$T/html.log" 2>&1 &
pids+=($!)
wait_state "$ROOT/state.json" || bad "html: state.json never appeared" "$(cat "$T/html.log")"
P=$(port_of "$ROOT/state.json"); U="http://127.0.0.1:$P"

body=$(curl -s "$U/")
grep -q '__td/editor.js' <<<"$body" && grep -q '<h1 id="t">hi</h1>' <<<"$body" && ok || bad "html: index not injected" "$body"
grep -q 'no-store' <<<"$(curl -sI "$U/pages/index.html")" && ok || bad "html: no-store missing"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$U/../etc/passwd")" != "200" ] && ok || bad "html: traversal served"
grep -q 'editor chrome' <<<"$(curl -s "$U/__td/editor.css")" && ok || bad "html: editor.css not served"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$U/favicon.ico")" = 204 ] && ok || bad "html: favicon should be an empty 204, not a console 404"
# partials: inlined at serve time, recursively; a missing one stays visible; flow.json is served or defaulted
mkdir -p "$ROOT/partials"; printf '<nav id="side"><!-- include: inner --></nav>' > "$ROOT/partials/side.html"; printf '<b>deep</b>' > "$ROOT/partials/inner.html"
printf '<html><body><!-- include: side --><!-- include: nope --><main>p</main></body></html>' > "$ROOT/pages/p.html"
body=$(curl -s "$U/pages/p.html")
grep -q '<nav id="side"><b>deep</b></nav>' <<<"$body" && grep -q 'missing partial: partials/nope.html' <<<"$body" && ok || bad "partials: include not expanded / missing not marked" "$body"
[ "$(curl -s "$U/__td/flow")" = '{"pages": [], "edges": []}' ] && ok || bad "flow: default when absent" "$(curl -s "$U/__td/flow")"
printf '{"pages":["index.html"],"edges":[]}' > "$ROOT/flow.json"
grep -q '"pages":\["index.html"\]' <<<"$(curl -s "$U/__td/flow")" && ok || bad "flow: file not served"
rm -f "$ROOT/pages/p.html"
# skins: a fresh root starts in wireframe; the list names every shipped file; a switch copies + records
[ "$(cat "$ROOT/skin")" = wireframe ] && grep -q 'skin: wireframe' "$ROOT/skin.css" && ok || bad "skin: fresh root did not start in wireframe"
grep -q '"skins": \["astryx", "bootstrap", "mui", "shadcn", "wireframe"\]' <<<"$(curl -s "$U/__td/skins")" && ok || bad "skin: list wrong (base must be excluded)" "$(curl -s "$U/__td/skins")"
head -c 200 "$ROOT/skin.css" | grep -q 'theme-design base sheet' && ok || bad "skin: root skin.css must start with base.css"
grep -q 'id="search"' <<<"$(curl -s "$U/icons.svg")" && grep -q '__tdCharts' <<<"$(curl -s "$U/charts.js")" && ok || bad "assets: icons.svg / charts.js not served"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Theme-Design: 1' -d '{"name":"../editor"}' "$U/__td/skin")" = 400 ] && ok || bad "skin: unknown/traversal name accepted"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -d '{"name":"mui"}' "$U/__td/skin")" = 403 ] && ok || bad "skin: switch without CSRF header accepted"

# CSRF: no header -> 403; header -> appended with seq 1
code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d '{"type":"message","text":"x"}' "$U/__td/event")
[ "$code" = 403 ] && ok || bad "html: event without header accepted ($code)"
r=$(curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"type":"message","text":"make it blue"}' "$U/__td/event")
grep -q '"seq": 1' <<<"$r" && ok || bad "html: first seq not 1" "$r"
grep -q 'make it blue' "$ROOT/events.jsonl" && grep -q '\*\*user\*\*' "$ROOT/transcript.md" && ok || bad "html: event/transcript not persisted"

# long-poll returns the pending batch and advances the cursor; a second poll times out empty
n=$(curl -s "$U/__td/next?timeout=1")
grep -q 'make it blue' <<<"$n" && [ "$(cat "$ROOT/cursor")" = 1 ] && ok || bad "html: next did not deliver/advance" "$n / cursor=$(cat "$ROOT/cursor")"
[ "$(curl -s "$U/__td/next?timeout=1")" = "[]" ] && ok || bad "html: second poll redelivered"
# a poll that is already waiting wakes when an event lands
( sleep 0.5; curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"type":"select","selector":"#t"}' "$U/__td/event" >/dev/null ) &
start=$(date +%s); n=$(curl -s "$U/__td/next?timeout=5"); took=$(( $(date +%s) - start ))
grep -q '"selector": "#t"' <<<"$n" && [ "$took" -lt 4 ] && ok || bad "html: waiting poll not woken (took ${took}s)" "$n"
# presence: listening is true only while a /__td/next is blocked
grep -q '"listening": false' <<<"$(curl -s "$U/__td/state")" && ok || bad "presence: idle server should not be listening"
curl -s "$U/__td/next?timeout=3" >/dev/null &
sleep 0.4
grep -q '"listening": true' <<<"$(curl -s "$U/__td/state")" && ok || bad "presence: blocked poll should read listening"
wait $! 2>/dev/null
grep -q '"listening": false' <<<"$(curl -s "$U/__td/state")" && ok || bad "presence: listening should drop when the poll returns"
# an externally advanced cursor (the hook) is honoured
printf '<html><body>x</body></html>' > "$ROOT/pages/a.html"
curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"type":"annotate","text":"later"}' "$U/__td/event" >/dev/null
tail -1 "$ROOT/events.jsonl" | python3 -c "import sys,json;print(json.loads(sys.stdin.read())['seq'])" > "$ROOT/cursor"
[ "$(curl -s "$U/__td/next?timeout=1")" = "[]" ] && ok || bad "html: hook-advanced cursor ignored"
# bad payloads
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Theme-Design: 1' -d '{"nope":1}' "$U/__td/event")" = 400 ] && ok || bad "html: typeless event accepted"
[ "$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'X-Theme-Design: 1' -d 'not json' "$U/__td/event")" = 400 ] && ok || bad "html: invalid json accepted"

# rich: off by default, on after the route, injected on <html> at serve time only
grep -q '"rich": false' <<<"$(curl -s "$U/__td/state")" && ! grep -q 'data-rich' <<<"$(curl -s "$U/")" && ok || bad "rich: should be off on a fresh root"
r=$(curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"on":true}' "$U/__td/rich")
grep -q '"rich": true' <<<"$r" && grep -q '<html data-rich' <<<"$(curl -s "$U/")" && ! grep -q 'data-rich' "$ROOT/pages/index.html" && [ "$(cat "$ROOT/rich")" = 1 ] && ok || bad "rich: toggle not applied/injected" "$r"
curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"on":false}' "$U/__td/rich" >/dev/null
curl -s "$U/__td/next?timeout=1" >/dev/null
r=$(curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"name":"mui"}' "$U/__td/skin")
grep -q '"skin": "mui"' <<<"$r" && grep -q 'skin: mui' "$ROOT/skin.css" && [ "$(cat "$ROOT/skin")" = mui ] && grep -q '"type": "skin", "name": "mui"' "$ROOT/events.jsonl" && ok || bad "skin: switch did not copy/record" "$r"
n=$(curl -s "$U/__td/next?timeout=1"); grep -q '"type": "skin"' <<<"$n" && ok || bad "skin: switch event not delivered to the poll" "$n"
rm -f "$ROOT/skin.css"; grep -q 'skin: wireframe' <<<"$(curl -s "$U/skin.css")" && ok || bad "skin: /skin.css without a root file should fall back to wireframe"

# SSE: a reply is broadcast; a file change pushes reload
curl -s -N --max-time 3 "$U/__td/events" > "$T/sse.txt" &
ssepid=$!
sleep 0.4
curl -s -X POST -H 'Content-Type: application/json' -H 'X-Theme-Design: 1' -d '{"text":"done","reload":true}' "$U/__td/reply" >/dev/null
curl -s "$U/__td/next?timeout=0.3" >/dev/null
printf ':root{--background:#000}' > "$ROOT/tokens.css"
sleep 1.6; wait "$ssepid" 2>/dev/null
grep -q '"type": "assistant"' "$T/sse.txt" && grep -q '"reload"' "$T/sse.txt" && grep -q 'tokens.css' "$T/sse.txt" && ok || bad "html: sse missing assistant/reload/watch" "$(cat "$T/sse.txt")"
grep -q '"type": "presence", "listening": true' "$T/sse.txt" && grep -q '"type": "presence", "listening": false' "$T/sse.txt" && ok || bad "presence: SSE did not carry both transitions" "$(cat "$T/sse.txt")"
grep -q '\*\*assistant\*\*.*done' "$ROOT/transcript.md" && ok || bad "html: assistant reply not in transcript"
grep -q '"pages": \["a.html", "index.html"\]' <<<"$(curl -s "$U/__td/state")" && ok || bad "html: state pages wrong" "$(curl -s "$U/__td/state")"

# the prompt hook budgets in whole events: with the cursor at 0 and eight ~430-byte
# events queued, it must print only what fits in 3000 chars, advance the cursor to
# the LAST event it printed in full, and leave the rest for the next poll.
HOOK="$HERE/hooks/pending-events.sh"
if command -v jq >/dev/null 2>&1; then
  HC="$T/hookcwd"; ROOTH="$HC/.theme-design"; mkdir -p "$ROOTH"
  printf '{"pid": %s, "mode": "html", "url": "http://localhost:0/"}' "$$" > "$ROOTH/state.json"
  pad=$(printf 'x%.0s' $(seq 1 380))
  : > "$ROOTH/events.jsonl"
  for i in $(seq 1 8); do printf '{"type":"select","seq":%s,"selector":"#e%s","text":"%s"}\n' "$i" "$i" "$pad" >> "$ROOTH/events.jsonl"; done
  echo 0 > "$ROOTH/cursor"
  hout=$(printf '{"prompt":"hello","cwd":"%s"}' "$HC" | bash "$HOOK" 2>&1)
  shown=$(grep -c '^{' <<<"$hout"); cur=$(cat "$ROOTH/cursor")
  [ "$shown" -ge 1 ] && [ "$shown" -lt 8 ] && [ "$cur" = "$shown" ] && grep -q "$shown of 8 shown" <<<"$hout" && ok || bad "hook: whole-event budget/cursor wrong (shown=$shown cursor=$cur)" "$hout"
  ! grep -q '^{[^}]*$' <<<"$hout" && ok || bad "hook: an event was cut mid-JSON"
  hout2=$(printf '{"prompt":"hello","cwd":"%s"}' "$HC" | bash "$HOOK" 2>&1)
  grep -q "$((8 - shown)) of 8 pending\|browser event(s) pending" <<<"$hout2" && [ "$(cat "$ROOTH/cursor")" = 8 ] && ok || bad "hook: second prompt did not drain the remainder" "$hout2"
  hout3=$(printf '{"prompt":"/theme-design:init","cwd":"%s"}' "$HC" | bash "$HOOK" 2>&1)
  [ -z "$hout3" ] && ok || bad "hook: slash prompt to this plugin must be silent" "$hout3"
fi

# a second start on the same root refuses while the first lives
out=$(THEME_DESIGN_QUIET=1 python3 "$SERVE" --root "$ROOT" --mode html --port 0 2>&1); rc=$?
[ $rc -ne 0 ] && grep -q 'already running' <<<"$out" && ok || bad "html: duplicate start not refused" "$out"

# lifecycle
python3 "$SERVE" --root "$ROOT" --status | grep -q '"mode": "html"' && ok || bad "html: --status"
python3 "$SERVE" --root "$ROOT" --stop | grep -q stopped && sleep 0.3 && [ ! -f "$ROOT/state.json" ] && ok || bad "html: --stop"
python3 "$SERVE" --root "$ROOT" --status >/dev/null 2>&1 && bad "html: --status after stop should fail" || ok

# ---- proxy mode ----------------------------------------------------------------
UP="$T/upstream"; mkdir -p "$UP/sub"
printf '<!doctype html><html><body><main>app</main></body></html>' > "$UP/index.html"
printf 'body{}' > "$UP/app.css"
UPP=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
python3 -m http.server "$UPP" --bind 127.0.0.1 -d "$UP" >"$T/up.log" 2>&1 &
pids+=($!)
for _ in $(seq 1 60); do curl -s -o /dev/null "http://127.0.0.1:$UPP/" && break; sleep 0.05; done
ROOT2="$T/root2"; mkdir -p "$ROOT2"
THEME_DESIGN_QUIET=1 python3 "$SERVE" --root "$ROOT2" --mode proxy --proxy "http://127.0.0.1:$UPP" --port 0 >"$T/proxy.log" 2>&1 &
pids+=($!)
wait_state "$ROOT2/state.json" || bad "proxy: state.json never appeared" "$(cat "$T/proxy.log")"
P2=$(port_of "$ROOT2/state.json"); U2="http://127.0.0.1:$P2"
body=$(curl -s "$U2/")
grep -q '<main>app</main>' <<<"$body" && grep -q '__td/editor.js' <<<"$body" && ok || bad "proxy: html not proxied+injected" "$body"
[ "$(curl -s "$U2/app.css")" = 'body{}' ] && ok || bad "proxy: non-html body altered"
loc=$(curl -s -o /dev/null -w '%{redirect_url}' "$U2/sub")
grep -q "127.0.0.1:$P2/sub/\|localhost:$P2/sub/" <<<"$loc" && ok || bad "proxy: Location not rewritten to own origin ($loc)"
[ "$(curl -s -o /dev/null -w '%{http_code}' "$U2/missing")" = 404 ] && ok || bad "proxy: upstream status not passed through"
grep -q '"mode": "proxy"' <<<"$(curl -s "$U2/__td/state")" && ok || bad "proxy: control lane not reachable"
kill "${pids[1]}" 2>/dev/null; wait "${pids[1]}" 2>/dev/null; sleep 0.2
[ "$(curl -s -o /dev/null -w '%{http_code}' "$U2/")" = 502 ] && ok || bad "proxy: dead upstream should be 502"
python3 "$SERVE" --root "$ROOT2" --stop >/dev/null

echo "theme-design serve tests: $pass passed, $fail failed"
exit $((fail > 0))
