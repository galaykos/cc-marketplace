#!/usr/bin/env bash
# Offline tests for technique-fingerprint.py — the stack and motion detector the
# design-research method runs per motion reference (mining-method.md §2a).
#
# Every fixture is a saved page written into a temp dir and read through --file,
# so nothing here touches the network. --file resolves each asset URL by PATH
# under the page's directory and ignores the host, which is what makes the
# first-party rule testable: a third-party asset sits on disk beside the page,
# and the only thing keeping it out of the report is the rule under test.
#
# Picked up by the repo's "Plugin author-time lint + harness tests" CI step,
# which globs plugins/*/scripts/__tests__/*.test.sh.
set -u
FP="$(cd "$(dirname "$0")/.." && pwd)/technique-fingerprint.py"
command -v python3 >/dev/null 2>&1 || { echo 'SKIP: python3 not installed'; exit 0; }
[ -f "$FP" ] || { echo "FAIL: $FP not found"; exit 1; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0; fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

# The homepage must clear the 500-byte shell threshold, so every page carries
# this paragraph of real-looking copy.
FILL='<p>Fieldnote keeps every survey crew on one sheet: jobs, owners and slipping dates, synced at the van and read by both shifts. Each crew lead opens the same page at the depot, marks what moved, and the office sees it before the kettle boils. The handover note is the page itself, so nobody rewrites it at shift change. Nothing here is a claim; it is filler long enough to be a page.</p>'

page() { # dir body-html
  mkdir -p "$1"
  printf '<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Fieldnote</title>%s</head><body><main><h1>Fieldnote</h1>%s</main></body></html>\n' "$2" "$FILL" > "$1/index.html"
}
hits_json() { # report.json -> "Name=where" lines
  python3 -c 'import json,sys; [print(f"{k}={v}") for k,v in json.load(open(sys.argv[1]))["hits"].items()]' "$1"
}

# --- 1. The motion page: first-party JS and CSS read, third-party never read ---
S="$T/motion"
page "$S" '<link rel="stylesheet" href="/assets/site.css"><script src="/assets/app.js"></script><script src="https://cdn.thirdparty.test/vendor.js"></script>'
mkdir -p "$S/assets"
cat > "$S/assets/app.js" <<'JS'
import{gsap}from"gsap";import{ScrollTrigger}from"gsap/ScrollTrigger";gsap.registerPlugin(ScrollTrigger);
const lenis=new Lenis({autoRaf:false});lenis.on("scroll",ScrollTrigger.update);
/* a framework runtime string, not intent: */ const vt="view-transition-name";
JS
printf '.hero{animation:reveal linear both;animation-timeline: view()}\n.btn{--tw-ring-offset-width:0px}\n' > "$S/assets/site.css"
printf 'window.__THREE__="r170";\n' > "$S/vendor.js"   # the third-party path, on disk on purpose

out=$(python3 "$FP" --file "$S/index.html" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok || bad "motion page did not exit 0 (rc=$rc)" "$(printf '%s' "$out" | tail -3)"
for want in 'GSAP [j]' 'GSAP ScrollTrigger [j]' 'Lenis [j]' 'CSS scroll-driven [c]' 'Tailwind [c]'; do
  printf '%s\n' "$out" | grep -qF "$want" && ok || bad "motion page: '$want' not reported" "$(printf '%s' "$out" | grep -E 'motion|styling' | head -2)"
done
printf '%s\n' "$out" | grep -q 'three\.js' \
  && bad "third-party vendor.js was read — the first-party rule let it in" "$(printf '%s' "$out" | grep three)" || ok
printf '%s\n' "$out" | grep -q 'View Transitions API' \
  && bad "a view-transition string in JS counted — only markup or CSS is intent" "$(printf '%s' "$out" | grep 'View Trans')" || ok
printf '%s\n' "$out" | grep -q '1 third-party asset(s) not read' && ok \
  || bad "the report did not count the skipped third-party script" "$(printf '%s' "$out" | grep '^read:')"

# --- 2. --json is parseable and carries the same verdicts ---
python3 "$FP" --file "$S/index.html" --json > "$T/motion.json" 2>/dev/null
if python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); assert r["ok"] is True and "limits" in r and "read" in r' "$T/motion.json" 2>/dev/null; then ok
else bad "--json output is not the documented shape" "$(head -c 300 "$T/motion.json")"; fi
hj=$(hits_json "$T/motion.json")
printf '%s\n' "$hj" | grep -qx 'Lenis=j' && ok || bad "--json: Lenis not reported as j" "$hj"
printf '%s\n' "$hj" | grep -q '^three.js=' && bad "--json: third-party three.js leaked in" "$hj" || ok

# --- 3. The manifest guard: a package.json map is a mention, not a use ---
S="$T/manifest"
page "$S" '<script src="/deps.js"></script><script src="/use.js"></script>'
printf 'var m={"dependencies":{"lenis":"^1.1.0","react":"^19.0.0"}};\n' > "$S/deps.js"
printf '/* nothing */\n' > "$S/use.js"
python3 "$FP" --file "$S/index.html" --json > "$T/m.json" 2>/dev/null
hits_json "$T/m.json" | grep -q '^Lenis=' && bad "a \"lenis\":\"^1.1.0\" manifest entry counted as a use" "$(hits_json "$T/m.json")" || ok
printf 'const lenis=new Lenis();lenis.raf(0);\n' > "$S/use.js"   # the control: a real use (the signature is lowercase, as in the corpus detector)
python3 "$FP" --file "$S/index.html" --json > "$T/m.json" 2>/dev/null
hits_json "$T/m.json" | grep -qx 'Lenis=j' && ok || bad "the manifest control (a real Lenis use) was not reported" "$(hits_json "$T/m.json")"

# --- 4. View Transitions from markup and from CSS DO count ---
S="$T/vt"
page "$S" '<link rel="stylesheet" href="/vt.css"><style>h1{view-transition-name:title}</style>'
printf '@view-transition{navigation:auto}\n' > "$S/vt.css"
python3 "$FP" --file "$S/index.html" --json > "$T/vt.json" 2>/dev/null
hits_json "$T/vt.json" | grep -qx 'View Transitions API=hc' && ok \
  || bad "View Transitions in markup and CSS should report as hc" "$(hits_json "$T/vt.json")"

# --- 5. Caps: the script count and the byte total both bind ---
S="$T/caps"
page "$S" '<script src="/first.js"></script><script src="/second.js"></script>'
python3 -c 'print("/*" + "x" * 5000 + "*/")' > "$S/first.js"
printf 'gsap.to(".a",{x:1});\n' > "$S/second.js"
python3 "$FP" --file "$S/index.html" > "$T/c0.txt" 2>&1
grep -qF 'GSAP [j]' "$T/c0.txt" && ok || bad "caps control: GSAP in the second script not found uncapped" "$(cat "$T/c0.txt")"
python3 "$FP" --file "$S/index.html" --max-js 1 > "$T/c1.txt" 2>&1
if ! grep -q 'GSAP' "$T/c1.txt" && grep -qF 'first-party JS 1 of 2' "$T/c1.txt"; then ok
else bad "--max-js 1 still read the second script" "$(grep -E '^read:|GSAP' "$T/c1.txt")"; fi
python3 "$FP" --file "$S/index.html" --max-bytes 3000 > "$T/c2.txt" 2>&1
if ! grep -q 'GSAP' "$T/c2.txt" && grep -q 'stopped at the byte cap' "$T/c2.txt"; then ok
else bad "--max-bytes did not stop the read before the second script" "$(grep -E '^read:|GSAP' "$T/c2.txt")"; fi

# --- 6. Refused shapes exit 1 with a reason, never a traceback ---
S="$T/shell"; mkdir -p "$S"
printf '<!doctype html><html><body><div id="root"></div><script src="/app.js"></script></body></html>\n' > "$S/index.html"
out=$(python3 "$FP" --file "$S/index.html" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'shell document'; then ok
else bad "a near-empty shell should exit 1 naming the shell (rc=$rc)" "$out"; fi

S="$T/wall"
page "$S" '<script>/* Just a moment... cf-chl- */</script>'
out=$(python3 "$FP" --file "$S/index.html" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'bot challenge'; then ok
else bad "a bot-challenge page should exit 1 naming it (rc=$rc)" "$out"; fi

# Unreachable over the network, still offline: nothing listens on the discard port.
out=$(python3 "$FP" 'http://127.0.0.1:9/' 2>&1); rc=$?
if [ "$rc" -eq 1 ] && ! printf '%s' "$out" | grep -q 'Traceback' && printf '%s' "$out" | grep -q 'NOT READ'; then ok
else bad "an unreachable host should fail soft with exit 1 (rc=$rc)" "$(printf '%s' "$out" | tail -3)"; fi

# --- 7. Safety: a saved page cannot read outside its own directory ---
S="$T/site/deep"
page "$S" '<script src="/%2e%2e/%2e%2e/secret.js"></script>'
printf 'gsap.to(".secret",{x:1});\n' > "$T/secret.js"
python3 "$FP" --file "$S/index.html" > "$T/esc.txt" 2>&1
grep -q 'GSAP' "$T/esc.txt" && bad "an encoded ../ asset path read a file outside the page directory" "$(cat "$T/esc.txt")" || ok

# --- 8. Usage errors are exit 2 ---
python3 "$FP" >/dev/null 2>&1;                                   [ $? -eq 2 ] && ok || bad "no argument did not exit 2" ""
python3 "$FP" https://example.test --file "$T/motion/index.html" >/dev/null 2>&1; [ $? -eq 2 ] && ok || bad "URL plus --file did not exit 2" ""
python3 "$FP" --file "$T/absent.html" >/dev/null 2>&1;           [ $? -eq 2 ] && ok || bad "a missing --file did not exit 2" ""
out=$(python3 "$FP" 'file:///etc/passwd' 2>&1); rc=$?
if [ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -q 'root:'; then ok
else bad "a file:// URL must be refused as usage (exit 2), never read" "rc=$rc"; fi

# --- 9. Unquoted attribute values still name assets ---
S="$T/unquoted"
page "$S" '<link rel=stylesheet href=/assets/site.css><script src=/assets/app.js></script>'
mkdir -p "$S/assets"
printf 'gsap.to(".a",{x:1});\n' > "$S/assets/app.js"
printf '.hero{animation:reveal linear both;animation-timeline: view()}\n' > "$S/assets/site.css"
out=$(python3 "$FP" --file "$S/index.html" 2>&1)
for want in 'GSAP [j]' 'CSS scroll-driven [c]'; do
  printf '%s\n' "$out" | grep -qF "$want" && ok || bad "unquoted src=/href=: '$want' not reported" "$(printf '%s' "$out" | grep -E '^read:|motion')"
done

# --- 10. A malformed asset URL is skipped with a note, never a traceback ---
S="$T/badurl"
page "$S" '<script src="http://[::1/x.js"></script><script src="/a%00b.js"></script><script src="/ok.js"></script>'
printf 'gsap.to(".a",{x:1});\n' > "$S/ok.js"
out=$(python3 "$FP" --file "$S/index.html" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -q Traceback && printf '%s\n' "$out" | grep -qF 'GSAP [j]' \
   && printf '%s\n' "$out" | grep -q '2 unusable asset URL(s) skipped'; then ok
else bad "a bad IPv6 host and a %00 path should be skipped with a note, the rest read (rc=$rc)" "$(printf '%s' "$out" | tail -4)"; fi

# --- 11. A library named in visible copy is not evidence; in markup it is ---
S="$T/prose"
page "$S" '<p>Our map runs on leaflet, the editor on lexical, the carousels on embla and swiper, the charts on highcharts.</p>'
python3 "$FP" --file "$S/index.html" --json > "$T/prose.json" 2>/dev/null
hj=$(hits_json "$T/prose.json")
for n in 'Mapbox/MapLibre/Leaflet' 'Lexical' 'Embla Carousel' 'Swiper' 'Highcharts'; do
  printf '%s\n' "$hj" | grep -q "^$n=" && bad "a library named only in visible text counted: $n" "$hj" || ok
done
S="$T/markup"
page "$S" '<div class="swiper"><div class="swiper-wrapper"></div></div><div id="map" class="leaflet-container"></div><script src="/vendor/highcharts.js"></script>'
mkdir -p "$S/vendor"; printf '/* bundle */\n' > "$S/vendor/highcharts.js"
python3 "$FP" --file "$S/index.html" --json > "$T/markup.json" 2>/dev/null
hj=$(hits_json "$T/markup.json")
for n in 'Swiper=h' 'Mapbox/MapLibre/Leaflet=h' 'Highcharts=h'; do
  printf '%s\n' "$hj" | grep -qx "$n" && ok || bad "a class or script URL naming a library stopped counting: $n" "$hj"
done

# --- 12. One fetch stops at its wall-clock deadline, however slowly the bytes drip ---
#     A local server drips a byte-sized chunk every 0.1 s for 6 s; urllib's timeout is per
#     socket read and never fires, so only the deadline can end the read at ~1 s.
out=$(python3 - "$FP" <<'PY' 2>&1
import importlib.util, socket, sys, threading, time
spec = importlib.util.spec_from_file_location('tf', sys.argv[1]); tf = importlib.util.module_from_spec(spec); spec.loader.exec_module(tf)
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); srv.bind(('127.0.0.1', 0)); srv.listen(1)
def serve():
    c, _ = srv.accept(); c.recv(65536)
    c.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n')
    end = time.monotonic() + 6
    try:
        while time.monotonic() < end:
            c.sendall(b'<p>drip</p>'); time.sleep(0.1)
    except OSError:
        pass
    c.close()
threading.Thread(target=serve, daemon=True).start()
t0 = time.monotonic()
code, _, body, note = tf.net_fetch(f'http://127.0.0.1:{srv.getsockname()[1]}/', 1_000_000, 1.0)
el = time.monotonic() - t0
print(f'elapsed={el:.1f}s status={code} body={len(body)} note={note!r}')
sys.exit(0 if el < 3 and code == 200 and body.startswith('<p>drip</p>') and 'deadline' in note else 1)
PY
); rc=$?
[ "$rc" -eq 0 ] && ok || bad "a dripping response was not cut at the per-fetch deadline" "$out"
# ...and an ordinary Content-Length body still reads whole: http.client closes the socket
# the moment the length is consumed, so the deadline loop must not touch it again.
out=$(python3 - "$FP" <<'PY' 2>&1
import importlib.util, socket, sys, threading
spec = importlib.util.spec_from_file_location('tf', sys.argv[1]); tf = importlib.util.module_from_spec(spec); spec.loader.exec_module(tf)
srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); srv.bind(('127.0.0.1', 0)); srv.listen(1)
body = b'gsap.to(".a",{x:1});' * 5000
def serve():
    c, _ = srv.accept(); c.recv(65536)
    c.sendall(b'HTTP/1.1 200 OK\r\nContent-Type: text/javascript\r\nContent-Length: %d\r\n\r\n' % len(body) + body)
    c.recv(1); c.close()
threading.Thread(target=serve, daemon=True).start()
code, _, text, note = tf.net_fetch(f'http://127.0.0.1:{srv.getsockname()[1]}/app.js', 4_000_000, 5.0)
print(f'status={code} body={len(text)} note={note!r}')
sys.exit(0 if code == 200 and len(text) == len(body) and not note else 1)
PY
); rc=$?
[ "$rc" -eq 0 ] && ok || bad "a Content-Length body did not read whole through the deadline loop" "$out"

# --- 13. --max-bytes caps the read that crosses it; a gzip label on a plain body reads the body ---
S="$T/budget"
page "$S" '<script src="/big.js"></script>'
python3 -c 'print("/*" + "x" * 5000 + "*/ gsap.to(\".a\",{x:1});")' > "$S/big.js"
python3 "$FP" --file "$S/index.html" --max-bytes 3000 --json > "$T/budget.json" 2>/dev/null
if python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); sys.exit(0 if r["read"]["bytes"] <= 3000 and "GSAP" not in r["hits"] and "byte cap" in r["read"]["stopped_at"] else 1)' "$T/budget.json"; then ok
else bad "--max-bytes 3000 read past the budget inside one asset" "$(python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); print(r["read"], sorted(r["hits"]))' "$T/budget.json" 2>&1)"; fi
out=$(python3 - "$FP" <<'PY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location('tf', sys.argv[1]); tf = importlib.util.module_from_spec(spec); spec.loader.exec_module(tf)
got = tf._decode(b'<p>sent plain</p>', 'gzip', 100)
print(repr(got)); sys.exit(0 if got == '<p>sent plain</p>' else 1)
PY
); rc=$?
[ "$rc" -eq 0 ] && ok || bad "a body labelled gzip that is not gzip decoded to nothing" "$out"

# A malformed URL argument is a usage error (exit 2), never a traceback — exit 1 means "refused".
for arg in 'http://[::1/' ; do
  out=$(python3 "$FP" "$arg" 2>&1); rc=$?
  { [ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -q Traceback; } && ok || bad "malformed URL '$arg' should exit 2 without a traceback (rc=$rc)" "$out"
done
out=$(python3 "$FP" --file "$S/index.html" --base-url 'http://[::1/' 2>&1); rc=$?
{ [ "$rc" -eq 2 ] && ! printf '%s' "$out" | grep -q Traceback; } && ok || bad "malformed --base-url should exit 2 without a traceback (rc=$rc)" "$out"

printf '\ntechnique-fingerprint: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
