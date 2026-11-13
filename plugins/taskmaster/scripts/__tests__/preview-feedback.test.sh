#!/usr/bin/env bash
# Drives scripts/preview-feedback.sh against temp docroots and a live serve.py: list (unread, --all, escaping), wait (a row posted during the wait ends it; timeout; the 15-minute lease; print before mark; parse only on a change), reply (atomic rewrite, one line, bad args), posts racing rewrites, shot (exit 4 on stderr without a browser; a stand-in browser for the URL, sandbox, profile, time limit and failure; a PNG of the row's viewport size over http and from the file with a real one).
# Misses: whether the PNG shows the outlined element (looked at by eye, not here); a browser that is found but cannot start; the shell's own controls (no browser runs the page here).
set -u
here="$(cd "$(dirname "$0")" && pwd)"
R="$here/../preview-feedback.sh"
SERVE="$here/../../skills/visual-decisions/assets/serve.py"
SHELL_HTML="$here/../../skills/visual-decisions/assets/shell.html"
pass=0; fail=0
ok() { pass=$((pass+1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail+1)); }

if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: python3 or curl not found"
  echo "preview-feedback.sh tests: 0 passed, 0 failed"
  exit 0
fi

T="$(mktemp -d)"
pids=""
cleanup() {
  [ -d "$T/live" ] && bash "$here/../preview.sh" --docroot "$T/live" --stop >/dev/null 2>&1
  for p in $pids; do kill "$p" 2>/dev/null; done
  for p in $pids; do wait "$p" 2>/dev/null; done
  rm -rf "$T"
}
trap cleanup EXIT

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }
ids() { python3 -c 'import json,sys;print(" ".join(json.loads(l)["id"] for l in sys.stdin if l.strip()))'; }
# field <file> <id> <key>: one row's field as JSON; unparseable lines skipped.
field() { python3 -c 'import json,sys
rows={}
for l in open(sys.argv[1],"rb").read().split(b"\n"):
    try: r=json.loads(l)
    except ValueError: continue
    rows[r["id"]]=r
print(json.dumps(rows[sys.argv[2]][sys.argv[3]]))' "$@"; }
inode() { python3 -c 'import os,sys;print(os.stat(sys.argv[1]).st_ino)' "$1"; }

# ---- list on a docroot with no feedback yet -----------------------------------
D="$T/root"; mkdir -p "$D"
out="$(bash "$R" list --docroot "$D")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok || bad "list, no file" "want exit 0 and no output, got $rc: $out"
out="$(bash "$R" list --docroot "$T/missing")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok || bad "list, no docroot" "want exit 0 and no output, got $rc: $out"

# ---- list: unread open rows; --all; one escaped line per row ------------------
python3 - "$D/.feedback.jsonl" <<'EOF'
import json, sys
def row(i, **kw):
    r = {"id": i, "ts": "2026-11-12T10:00:00Z", "page": "current.html", "kind": "note", "variant": "B", "anchor": None,
         "text": "n", "context": {}, "status": "open", "reply": "", "handed_out": False}
    r.update(kw)
    return json.dumps(r, ensure_ascii=False)
with open(sys.argv[1], "w", encoding="utf-8") as h:
    h.write(row("aa01", kind="pick", text="") + "\n")
    h.write(row("aa02", handed_out=True) + "\n")
    h.write("garbage, not json\n")
    h.write(row("aa03", status="addressed", reply="done") + "\n")
    h.write(row("aa04", text="\x1b[31mred\u200bzero\u2028sep\nline2\U000e0041vs\U000e0100fill\u3164blank\u2800") + "\n")
EOF
sum_before="$(cksum < "$D/.feedback.jsonl")"
out="$(bash "$R" list --docroot "$D")"; rc=$?
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | ids)" = "aa01 aa04" ] && ok || bad "list unread" "want aa01 aa04, got $rc: $out"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 2 ] && ok || bad "list one line per row" "$out"
printf '%s' "$out" | LC_ALL=C grep -q "$(printf '\033')" && bad "list escapes ESC" "a raw ESC byte reached the output" || ok
printf '%s' "$out" | grep -qF "$(printf '\342\200\213')" && bad "list escapes U+200B" "a raw zero-width space reached the output" || ok
printf '%s' "$out" | grep -qF "$(printf '\342\200\250')" && bad "list escapes U+2028" "a raw line separator reached the output" || ok
printf '%s' "$out" | grep -qF "$(printf '\363\240\201\201')" && bad "list escapes a tag character" "a raw U+E0041 reached the output" || ok
printf '%s' "$out" | grep -qF "$(printf '\363\240\204\200')" && bad "list escapes a variation selector" "a raw U+E0100 reached the output" || ok
printf '%s' "$out" | grep -qF "$(printf '\343\205\244')" && bad "list escapes the Hangul filler" "a raw U+3164 reached the output" || ok
printf '%s' "$out" | grep -qF "$(printf '\342\240\200')" && bad "list escapes the blank Braille cell" "a raw U+2800 reached the output" || ok
printf '%s\n' "$out" | python3 -c '
import json,sys
r=[json.loads(l) for l in sys.stdin][1]
assert r["text"]=="\x1b[31mred\u200bzero\u2028sep\nline2\U000e0041vs\U000e0100fill\u3164blank\u2800", repr(r["text"])' 2>/dev/null && ok || bad "list keeps the text" "escaped output does not decode to the stored text"
out="$(bash "$R" list --docroot "$D" --all)"
[ "$(printf '%s\n' "$out" | ids)" = "aa01 aa02 aa03 aa04" ] && ok || bad "list --all" "want aa01..aa04, got: $out"
[ "$(cksum < "$D/.feedback.jsonl")" = "$sum_before" ] && ok || bad "list is read-only" "list changed the file"

# ---- reply: one row rewritten by rename, the rest byte for byte ---------------
ino="$(inode "$D/.feedback.jsonl")"
lines_before="$(sed -n '1p;2p;3p;4p' "$D/.feedback.jsonl")"
out="$(bash "$R" reply --docroot "$D" --id aa04 --status addressed --text "$(printf 'fixed the colour\nsecond line')")"; rc=$?
[ "$rc" = 0 ] && ok || bad "reply exit" "want 0, got $rc: $out"
[ "$(field "$D/.feedback.jsonl" aa04 status)" = '"addressed"' ] && ok || bad "reply status" "$(field "$D/.feedback.jsonl" aa04 status)"
[ "$(field "$D/.feedback.jsonl" aa04 reply)" = '"fixed the colour second line"' ] && ok || bad "reply is one line" "$(field "$D/.feedback.jsonl" aa04 reply)"
[ "$(field "$D/.feedback.jsonl" aa04 handed_out)" = true ] && ok || bad "reply marks handed out" "$(field "$D/.feedback.jsonl" aa04 handed_out)"
[ "$(sed -n '1p;2p;3p;4p' "$D/.feedback.jsonl")" = "$lines_before" ] && ok || bad "reply keeps other rows" "rows 1-4 (garbage line included) changed"
[ "$(inode "$D/.feedback.jsonl")" != "$ino" ] && ok || bad "reply is a rename" "the file was rewritten in place (same inode)"
ls -A "$D" | grep -q '^\.feedback-.*\.tmp$' && bad "reply temp file" "a temp file was left: $(ls -A "$D")" || ok
printf '%s\n' "$out" | ids | grep -qx aa04 && ok || bad "reply prints the row" "$out"
for args in "--id aa01 --status open" "--id aa01" "--status addressed" "--id aa01 --status addressed --text"; do
  bash "$R" reply --docroot "$D" $args >/dev/null 2>&1; rc=$?
  [ "$rc" = 2 ] && ok || bad "reply bad arguments '$args'" "want exit 2, got $rc"
done
bash "$R" reply --docroot "$D" --id nope --status dismissed >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] && ok || bad "reply unknown id" "want exit 5, got $rc"
bash "$R" frobnicate >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok || bad "unknown subcommand" "want exit 2, got $rc"

# ---- wait: hands out what is unread now, then times out ------------------------
out="$(bash "$R" wait --docroot "$D" --timeout 5)"; rc=$?
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | ids)" = aa01 ] && ok || bad "wait, row already unread" "want aa01, got $rc: $out"
[[ "$(field "$D/.feedback.jsonl" aa01 handed_out)" =~ ^\"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\"$ ]] && ok || bad "wait marks handed out with a time" "$(field "$D/.feedback.jsonl" aa01 handed_out)"
[ "$(field "$D/.feedback.jsonl" aa01 status)" = '"open"' ] && ok || bad "wait keeps the status" "$(field "$D/.feedback.jsonl" aa01 status)"
[ -z "$(bash "$R" list --docroot "$D")" ] && ok || bad "list after wait" "a handed-out row is still listed"
start=$SECONDS
out="$(bash "$R" wait --docroot "$D" --timeout 1)"; rc=$?
[ "$rc" = 3 ] && [ -z "$out" ] && ok || bad "wait timeout" "want exit 3 and no output, got $rc: $out"
[ $((SECONDS - start)) -ge 1 ] && ok || bad "wait timeout length" "returned before 1 s"
bash "$R" wait --docroot "$D" --timeout soon >/dev/null 2>&1; rc=$?
[ "$rc" = 2 ] && ok || bad "wait bad timeout" "want exit 2, got $rc"

# ---- handed out is a 15-minute lease while the row stays open ------------------
L="$T/lease"; mkdir -p "$L"
python3 - "$L/.feedback.jsonl" <<'EOF'
import json, sys, time
ago = lambda m: time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - m * 60))
with open(sys.argv[1], "w") as h:
    for i, out in (("ls01", ago(20)), ("ls02", ago(5))):
        h.write(json.dumps({"id": i, "page": "current.html", "kind": "note", "variant": "A", "anchor": None, "text": "t",
                            "context": {}, "status": "open", "reply": "", "handed_out": out}) + "\n")
EOF
out="$(bash "$R" list --docroot "$L")"
[ "$(printf '%s\n' "$out" | ids)" = ls01 ] && ok || bad "lease: list" "want ls01 (handed out 20 min ago, still open), got: $out"
out="$(bash "$R" wait --docroot "$L" --timeout 2)"; rc=$?
[ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | ids)" = ls01 ] && ok || bad "lease: wait" "want ls01 again, got $rc: $out"
[ -z "$(bash "$R" list --docroot "$L")" ] && ok || bad "lease: renewed" "the row is still listed after wait handed it out again"
# A pick has no reply step, so nothing ever closes it: once handed out it must stay handed out, or every later pass re-reads an old answer.
python3 - "$L/.feedback.jsonl" <<'EOF'
import json, sys, time
ago = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - 20 * 60))
with open(sys.argv[1], "w") as h:
    h.write(json.dumps({"id": "pk01", "page": "current.html", "kind": "pick", "variant": "B", "anchor": None, "text": "",
                        "context": {}, "status": "open", "reply": "", "handed_out": ago}) + "\n")
EOF
[ -z "$(bash "$R" list --docroot "$L")" ] && ok || bad "lease: pick" "a pick handed out 20 min ago was listed again"
out="$(bash "$R" wait --docroot "$L" --timeout 1)"; rc=$?
[ "$rc" = 3 ] && [ -z "$out" ] && ok || bad "lease: pick wait" "want a timeout (3) and no output, got $rc: $out"

# ---- a row reaches stdout before it is marked: a waiter that cannot write hands nothing out ----
if [ -w /dev/full ]; then
  printf '%s\n' '{"id":"pf01","page":"current.html","kind":"note","variant":"A","anchor":null,"text":"t","context":{},"status":"open","reply":"","handed_out":false}' > "$L/.feedback.jsonl"
  bash "$R" wait --docroot "$L" --timeout 2 >/dev/full 2>/dev/null
  [ "$(bash "$R" list --docroot "$L" | ids)" = pf01 ] && ok || bad "print before mark" "a wait whose output failed still marked the row handed out"
else echo "SKIP: no /dev/full — print-before-mark not exercised"; fi

# ---- wait re-reads only when the file's size or mtime moves ---------------------
printf '%s\n' '{"id":"rr01","page":"current.html","kind":"note","variant":"A","anchor":null,"text":"t","context":{},"status":"shut","reply":"","handed_out":false}' > "$L/.feedback.jsonl"
bash "$R" wait --docroot "$L" --timeout 3 > "$T/rr.out" 2>&1 & rrw=$!; pids="$pids $rrw"
sleep 1
python3 - "$L/.feedback.jsonl" <<'EOF'
import os, sys
p = sys.argv[1]; st = os.stat(p)
with open(p, "r+b") as h:
    data = h.read(); h.seek(0); h.write(data.replace(b'"shut"', b'"open"'))
os.utime(p, ns=(st.st_atime_ns, st.st_mtime_ns))
EOF
wait "$rrw"; rc=$?
[ "$rc" = 3 ] && ok || bad "wait skips an unchanged file" "want exit 3 (size and mtime unchanged, no re-read), got $rc: $(cat "$T/rr.out")"
[ "$(bash "$R" list --docroot "$L" | ids)" = rr01 ] && ok || bad "wait re-read fixture" "the in-place edit did not open rr01"

# ---- end to end: a note posted to serve.py during the wait ends it ------------
E="$T/live"; mkdir -p "$E"; cp "$SHELL_HTML" "$E/current.html"
port="$(free_port)"; base="http://127.0.0.1:$port"
python3 "$SERVE" --docroot "$E" --port "$port" >"$T/serve.log" 2>&1 &
srv=$!; pids="$pids $srv"
for _ in $(seq 1 50); do grep -q '^Serving ' "$T/serve.log" 2>/dev/null && break; sleep 0.1; done
post() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'X-Preview-Feedback: 1' -H 'Expect:' --data "$1" "$base/_feedback"; }
bash "$R" wait --docroot "$E" --timeout 15 >"$T/wait.out" 2>&1 &
waiter=$!; pids="$pids $waiter"
sleep 1
start=$SECONDS
got="$(post '{"page":"current.html","kind":"note","variant":"B","text":"tighter spacing","anchor":{"selector":"#vd-b > .vd-content","tag":"div","text":"","rect":{"x":0,"y":0,"w":10,"h":10}},"context":{"viewport":{"w":900,"h":700}}}')"
[ "$got" = 200 ] && ok || bad "e2e post" "want 200, got $got"
wait "$waiter"; rc=$?
[ "$rc" = 0 ] && grep -q '"tighter spacing"' "$T/wait.out" && ok || bad "e2e wait" "want exit 0 with the note, got $rc: $(cat "$T/wait.out")"
[ $((SECONDS - start)) -lt 5 ] && ok || bad "e2e wait latency" "took $((SECONDS - start)) s after the post"
note_id="$(ids < "$T/wait.out")"
[ -z "$(bash "$R" list --docroot "$E")" ] && ok || bad "e2e list after wait" "the handed-out note is still unread"

# ---- posts racing rewrites: no row is lost (padding makes each rewrite slow enough to be hit; 3000 rows stay under serve.py's 2 MiB cap) ----
python3 -c '
import json,sys
with open(sys.argv[1],"a") as h:
    for i in range(3000):
        h.write(json.dumps({"id":"pad%d"%i,"page":"old.html","kind":"note","variant":None,"anchor":None,"text":"p"*400,"context":{},"status":"dismissed","reply":"","handed_out":True})+"\n")' "$E/.feedback.jsonl"
( for i in $(seq 1 60); do post "{\"page\":\"current.html\",\"kind\":\"pick\",\"variant\":\"A\",\"text\":\"r$i\"}" >/dev/null; done ) &
poster=$!; pids="$pids $poster"
i=0; while kill -0 "$poster" 2>/dev/null; do i=$((i+1)); bash "$R" reply --docroot "$E" --id "$note_id" --status addressed --text "pass $i" >/dev/null; done
wait "$poster"
n="$(bash "$R" list --docroot "$E" --all | wc -l | tr -d ' ')"
[ "$n" = 3061 ] && ok || bad "posts racing rewrites ($i rewrites)" "want 3061 rows, got $n"
kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null

# ---- shot -------------------------------------------------------------------------
pick_id="$(bash "$R" list --docroot "$E" --all | python3 -c 'import json,sys;print([r["id"] for r in map(json.loads,sys.stdin) if r["kind"]=="pick"][0])')"
bash "$R" shot --docroot "$E" --id "$pick_id" >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] && ok || bad "shot on a pick" "want exit 5 (no anchor), got $rc"
bash "$R" shot --docroot "$E" --id nope >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] && ok || bad "shot unknown id" "want exit 5, got $rc"
printf '%s\n' '{"id":"esc1","page":"../outside.html","kind":"note","variant":"A","text":"x","anchor":{"selector":"p","tag":"p","text":"","rect":{}},"context":{},"status":"open","reply":"","handed_out":true}' >> "$E/.feedback.jsonl"
printf '<p>outside</p>\n' > "$T/outside.html"
bash "$R" shot --docroot "$E" --id esc1 >/dev/null 2>&1; rc=$?
[ "$rc" = 5 ] && ok || bad "shot outside the docroot" "want exit 5, got $rc"
out="$(PREVIEW_BROWSER="$T/no-such-browser" bash "$R" shot --docroot "$E" --id "$note_id" 2>&1)"; rc=$?
[ "$rc" = 4 ] && [ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] && ok || bad "shot without a browser" "want exit 4 and one line, got $rc: $out"
out="$(PREVIEW_BROWSER="$T/no-such-browser" bash "$R" shot --docroot "$E" --id "$note_id" 2>/dev/null)"
[ -z "$out" ] && ok || bad "shot without a browser: stdout" "the message went to stdout, where png=\$(shot) takes it for a path: $out"

# A stand-in browser records its arguments and its parent, writes a PNG signature, exits $FAKE_RC.
fake="$T/fake-browser"
cat > "$fake" <<'EOF'
#!/bin/sh
: > "$FAKE_LOG"
for a in "$@"; do printf '%s\n' "$a" >> "$FAKE_LOG"; done
ps -o comm= -p "$PPID" > "$FAKE_LOG.parent" 2>/dev/null
for a in "$@"; do case "$a" in --screenshot=*) printf '\211PNG\r\n\032\n' > "${a#--screenshot=}" ;; esac; done
exit "${FAKE_RC:-0}"
EOF
chmod +x "$fake"
shoot() { FAKE_LOG="$T/fake.log" PREVIEW_BROWSER="$fake" bash "$R" shot --docroot "$E" --id "$note_id" "$@"; }
out="$(shoot 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok || bad "shot, stand-in browser" "want exit 0, got $rc: $out"
case "$(tail -n 1 "$T/fake.log")" in file://*/current.html\?*) ok ;; *) bad "shot, no server: the file" "want file://…/current.html?…, got $(tail -n 1 "$T/fake.log")" ;; esac
if [ "$(id -u)" = 0 ]; then grep -qx -- --no-sandbox "$T/fake.log" && ok || bad "shot as root" "--no-sandbox missing; Chrome will not start as root without it"
else grep -qx -- --no-sandbox "$T/fake.log" && bad "shot sandbox" "--no-sandbox passed without root or PREVIEW_BROWSER_NO_SANDBOX=1" || ok; fi
grep -q -- '^--user-data-dir=' "$T/fake.log" && ok || bad "shot profile" "no temp --user-data-dir"
if command -v timeout >/dev/null 2>&1; then
  [ "$(tr -d ' ' < "$T/fake.log.parent")" = timeout ] && ok || bad "shot time limit" "the browser's parent is $(cat "$T/fake.log.parent"), not timeout"
fi
PREVIEW_BROWSER_NO_SANDBOX=1 shoot >/dev/null 2>&1
grep -qx -- --no-sandbox "$T/fake.log" && ok || bad "shot sandbox opt-in" "PREVIEW_BROWSER_NO_SANDBOX=1 did not pass --no-sandbox"
out="$(FAKE_RC=7 shoot 2>&1)"; rc=$?
[ "$rc" != 0 ] && case "$out" in *7*) true ;; *) false ;; esac && ok || bad "shot, browser fails" "want a non-zero exit naming the browser's exit 7, got $rc: $out"

# With the server running (preview.sh's pid and URL files), shot loads the page over http from loopback.
sport="$(free_port)"
bash "$here/../preview.sh" --docroot "$E" --port "$sport" >/dev/null 2>&1
out="$(shoot 2>&1)"; rc=$?
u="$(tail -n 1 "$T/fake.log")"
case "$u" in "http://127.0.0.1:$sport/current.html?"*static=1*_outline=*) ok ;; *) bad "shot, server running: http" "want http://127.0.0.1:$sport/current.html?static=1&_outline=…, got $rc: $u" ;; esac

shoot_real() {
  out="$(bash "$R" shot --docroot "$E" --id "$note_id" 2>&1)"; rc=$?
  if [ "$rc" = 4 ]; then echo "SKIP: no Chromium-family browser here — the PNG half of shot ($1) is not exercised ($out)"; return; fi
  png="$(printf '%s\n' "$out" | tail -n 1)"
  [ "$rc" = 0 ] && [ "$png" = "$E/.feedback-shots/$note_id.png" ] && ok || bad "shot path ($1)" "want exit 0 and $E/.feedback-shots/$note_id.png, got $rc: $out"
  python3 - "$png" <<'EOF' 2>&1 | grep . && bad "shot PNG ($1)" "see above" || ok
import struct, sys
data = open(sys.argv[1], "rb").read()
assert data[:8] == b"\x89PNG\r\n\x1a\n", data[:8]
assert struct.unpack(">II", data[16:24]) == (900, 700), struct.unpack(">II", data[16:24])
EOF
}
shoot_real "over http"
bash "$here/../preview.sh" --docroot "$E" --stop >/dev/null 2>&1
shoot_real "from the file"

echo "preview-feedback.sh tests: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
