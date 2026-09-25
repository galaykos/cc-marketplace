#!/usr/bin/env bash
# snapshot.sh — `dk snapshot` and `dk review`: PNGs of the running app's routes, and
# a before/after page pairing two shot sets.
#
# WHAT IT DOES.
#   snapshot [--routes /,/pricing] [--device desktop|mobile|both] [--base-url URL]
#            [--out DIR] [--storage-state FILE]
#     loads each route in the Chromium-family browser board-export.sh locates — asked
#     for as `board-export.sh --which`, so the discovery and its install hint live in
#     one place — and writes <out>/<device>/<route-slug>.png. <out> defaults to
#     .design-kit/shots/<git short sha, else a UTC timestamp>/, and a second shoot at
#     the same commit writes <sha>-2 rather than over the set you are about to
#     compare against. desktop is 1440x900, mobile 390x844. --base-url defaults to
#     `codebase-scaffold.sh --detect`'s dev_url.
#   review --base <dir|git-ref> [--current DIR]
#     pairs the newest shot set (or --current) against the base — a directory, or a
#     git ref whose shots were committed, extracted read-only into
#     .design-kit/shots/_base-<ref>/ — writes .design-kit/reviews/<pair>.html with
#     before | after | a pixel-diff heatmap per route, serves it through preview.sh,
#     and prints one table row per route with the changed-pixel percentage. Either
#     side may name a set dir or any parent of one. The heatmap and the percentage
#     need python3 + Pillow; without it the page shows the pair alone and every row
#     reads `no diff engine: install Pillow`.
#
# BEHIND A LOGIN. Every authenticated app in the measured sessions sat behind a login
# this script could not pass, so none of them could get a before/after here (the
# marketplace's rationale/2026-09-25-session-plugin-usage-review.md, UI/UX section).
# --storage-state FILE replays a signed-in session: a Playwright storageState JSON,
# {"cookies": [...], "origins": [{"origin", "localStorage": [{name, value}]}]}, saved
# by whoever signed in
# through the project's walk access, a self-registered or seeded test user and never
# the user's own account (README, "Behind a login", has the one-call way to save it).
# The browser's --screenshot CLI has no way to take a cookie, so this path drives the
# same browser over the DevTools protocol on a pipe (--remote-debugging-pipe, python3
# stdlib only): cookies set before the first navigation, localStorage seeded on each
# new document of a matching origin, one browser for every shot. It settles in REAL
# time — the load event, then 500 ms with no request in flight, at most 3 s — because
# a virtual-time budget left CDP screenshots hanging (measured 2026-09-25, Chrome 153).
# A route that ends on another URL (a sign-in redirect, an expired session) is still
# shot, with a WARN naming where it landed; a file holding cookies for other hosts than
# the base URL's draws a WARN too. The file holds a live session token: one
# inside a git work tree that git does not ignore (a tracked file never counts as
# ignored) is REFUSED, exit 1 — keep it under .design-kit/, which dk.sh keeps ignored,
# or outside the repo.
#
# WHERE SHOTS GO. $DESIGN_KIT_DIR (dk.sh exports it, anchored at the project root),
# else .design-kit at the git toplevel — not under a subdirectory the shell cd'd into,
# which scattered a second .design-kit/ (finding 2 of the same rationale file).
#
# EXIT. 0 shot / rendered · 1 bad arguments (a refused or malformed --storage-state
# too) · 2 the browser or the server was unreachable, printed as NOT MEASURED and never
# as "no change": a shot nobody took is not a screen that did not change.
#
# WHAT IT DOES NOT DO. No visual ASSERTION and no threshold gate — it renders a pair
# and a number; whether the change is wanted is the reader's call. It never signs in:
# without --storage-state a route behind a login shoots the login page, and the state
# carries cookies and localStorage only — no sessionStorage, IndexedDB or auth header.
# No per-component crops, no scroll or animation settling beyond one 3 s budget
# (virtual time on the plain path, real time behind a login), no device emulation past
# the viewport size (no touch, no mobile UA, no DPR change). A pixel counts as changed
# when any channel moves by more than 10, so antialiasing and font hinting differences
# between two machines count as change. Shots written outside the preview docroot
# (an --out elsewhere) open from disk but 404 through the server.
#
# Standing: **gate** for the exit codes, the pairing and the --storage-state refusals —
# scripts/__tests__/snapshot.test.sh drives the argument errors, a missing, malformed
# or un-ignored state file, the unreachable exit, both diff-engine branches and the
# pairing over fixture PNG dirs; with a browser installed it also shoots plain routes
# and a cookie-guarded one through a state file, and skips both when there is none,
# saying so. Reading the pair — deciding the change is the one you meant — is
# **agent-graded**; nothing here asserts a pixel.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
DK="${DESIGN_KIT_DIR:-$(git rev-parse --show-cdup 2>/dev/null || true).design-kit}"

usage() { sed -n '2,/^set -euo pipefail$/p' "$0" | sed '$d'; }
die() { echo "snapshot: $1" >&2; exit "${2:-1}"; }
not_measured() {
  echo "snapshot: $1" >&2
  echo "NOT MEASURED IS A FAILURE HERE: a shot nobody took is not a screen that did not change." >&2
  exit 2
}
slug() { local s; s="$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]\{1,\}/-/g; s/^-//; s/-$//')"; printf '%s' "${s:-index}"; }
find_set() { # prints the deepest dir under $1 holding device subdirs with PNGs, or ""
  python3 - "$1" <<'PY'
import os, sys
found = set()
for dp, _dns, fns in os.walk(sys.argv[1]):
    if os.path.basename(dp) in ("desktop", "mobile") and any(f.endswith(".png") for f in fns):
        found.add(os.path.dirname(dp))
print(sorted(found)[-1] if found else "")
PY
}
# check_state <file> — exit 1 unless it exists, reads as a storageState, and cannot be
# committed. `git check-ignore` never reports a tracked file as ignored, so a tracked
# state file is refused even when a .gitignore pattern matches it.
check_state() {
  [ -f "$1" ] && [ -r "$1" ] || die "--storage-state $1: no such readable file — save one first (README, \"Behind a login\")" 1
  local dir top
  dir="$(cd "$(dirname "$1")" && pwd)"
  if top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
    git -C "$dir" check-ignore -q -- "$(basename "$1")" 2>/dev/null \
      || die "REFUSED --storage-state $1: it is inside the git work tree $top and git does not ignore it (or it is tracked). It holds a live session token the next \`git add -A\` would commit. Move it under .design-kit/ (dk keeps that ignored) or outside the repo, or gitignore it." 1
  fi
  python3 - "$1" <<'PY' || die "--storage-state $1 is not a Playwright storageState: want {\"cookies\": [{\"name\", \"value\", \"domain\", …}], \"origins\": [{\"origin\", \"localStorage\": [{\"name\", \"value\"}]}]} holding at least one cookie or localStorage entry" 1
import json, sys
try:
    st = json.load(open(sys.argv[1], encoding="utf-8"))
except (OSError, ValueError):
    sys.exit(1)
cookies, origins = (st.get("cookies", []), st.get("origins", [])) if isinstance(st, dict) else (None, None)
pair = lambda d: isinstance(d, dict) and isinstance(d.get("name"), str) and isinstance(d.get("value"), str)
ok = isinstance(cookies, list) and isinstance(origins, list) and all(pair(c) for c in cookies)
ok = ok and all(isinstance(o, dict) and isinstance(o.get("origin"), str) and isinstance(o.get("localStorage", []), list)
                and all(pair(i) for i in o.get("localStorage", [])) for o in origins)
sys.exit(0 if ok and (cookies or any(o.get("localStorage") for o in origins)) else 1)
PY
}

mode="${1:-}"; [ $# -gt 0 ] && shift
case "$mode" in
  snapshot|review) ;;
  -h|--help|"") usage; exit 0 ;;
  *) die "unknown mode $mode — snapshot | review" 1 ;;
esac

if [ "$mode" = snapshot ]; then
  routes="/"; device="desktop"; base_url=""; out=""; state=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --routes) routes="${2:-}"; [ -n "$routes" ] || die "--routes needs a comma-separated list" 1; shift ;;
      --device) device="${2:-}"; [ -n "$device" ] || die "--device needs desktop, mobile or both" 1; shift ;;
      --base-url) base_url="${2:-}"; [ -n "$base_url" ] || die "--base-url needs a URL" 1; shift ;;
      --out) out="${2:-}"; [ -n "$out" ] || die "--out needs a directory" 1; shift ;;
      --storage-state) state="${2:-}"; [ -n "$state" ] || die "--storage-state needs a file (a Playwright storageState JSON)" 1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag $1" 1 ;;
    esac
    shift
  done
  case "$device" in desktop|mobile|both) ;; *) die "--device must be desktop, mobile or both (got $device)" 1 ;; esac
  # before the browser probe, so a bad state file is a 1 on a machine with no browser too
  [ -z "$state" ] || check_state "$state"

  if [ -z "$base_url" ]; then
    base_url="$(bash "$here/codebase-scaffold.sh" --detect 2>/dev/null | sed -n 's/^dev_url=//p')"
    [ "$base_url" = "-" ] && base_url=""
    [ -n "$base_url" ] || die "no --base-url given and no dev server URL detected — pass --base-url http://localhost:PORT" 1
    echo "snapshot: base-url=$base_url (detected)" >&2
  fi

  # The browser lives in board-export.sh; this asks it rather than re-implementing the
  # probe order, so a new install path is added once.
  hint="$(mktemp)"
  set +e; browser="$(bash "$here/board-export.sh" --which 2>"$hint")"; rc=$?; set -e
  if [ "$rc" != 0 ] || [ -z "$browser" ]; then
    cat "$hint" >&2; rm -f "$hint"
    not_measured "no Chromium-family browser — nothing was shot"
  fi
  rm -f "$hint"

  python3 - "$base_url" <<'PY' || not_measured "the base URL is unreachable — is the dev server running?"
import sys, urllib.error, urllib.request
try:
    urllib.request.urlopen(sys.argv[1], timeout=5).read(1)
except urllib.error.HTTPError:
    pass  # a 404 at / is still a server that answered
except Exception as e:
    print(f"snapshot: {sys.argv[1]} unreachable — {e}", file=sys.stderr)
    sys.exit(1)
PY

  if [ -z "$out" ]; then
    stamp="$(git rev-parse --short HEAD 2>/dev/null || true)"
    [ -n "$stamp" ] || stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    out="$DK/shots/$stamp"; n=2
    while [ -d "$out" ] && [ -n "$(ls -A "$out" 2>/dev/null)" ]; do out="$DK/shots/$stamp-$n"; n=$((n + 1)); done
  fi

  devices="$device"; [ "$device" = both ] && devices="desktop mobile"
  IFS=',' read -r -a route_list <<< "$routes"
  jobs=()   # one "device<TAB>w<TAB>h<TAB>route<TAB>png" per shot
  for d in $devices; do
    case "$d" in desktop) w=1440; h=900 ;; mobile) w=390; h=844 ;; esac
    mkdir -p "$out/$d"
    for r in "${route_list[@]}"; do
      [ -n "$r" ] || continue
      case "$r" in /*) ;; *) r="/$r" ;; esac
      jobs+=("$d	$w	$h	$r	$out/$d/$(slug "$r").png")
    done
  done

  if [ -n "$state" ]; then
    python3 - "$browser" "$state" "${base_url%/}" ${jobs[@]+"${jobs[@]}"} <<'PY' \
      || not_measured "the signed-in shoot stopped before every route was shot"
import base64, json, os, select, shutil, subprocess, sys, tempfile, time, urllib.parse

browser, state_path, base = sys.argv[1:4]
jobs = [j.split("\t") for j in sys.argv[4:]]
state = json.load(open(state_path, encoding="utf-8"))


def cookie(c):  # a storageState cookie → a CDP Network.CookieParam
    p = {"name": c["name"], "value": c["value"], "path": c.get("path") or "/"}
    if c.get("domain"):
        p["domain"] = c["domain"]
    else:
        p["url"] = c.get("url") or base
    for k in ("secure", "httpOnly"):
        if k in c:
            p[k] = bool(c[k])
    # Chrome DROPS a SameSite=None cookie that is not Secure, without an error (measured
    # 2026-09-25: the route shot its login page). No browser stores one, so the pair can
    # only be a serializer's quirk; left unset, the cookie gets the browser's default.
    if c.get("sameSite") in ("Strict", "Lax") or (c.get("sameSite") == "None" and c.get("secure")):
        p["sameSite"] = c["sameSite"]
    if isinstance(c.get("expires"), (int, float)) and c["expires"] > 0:
        p["expires"] = c["expires"]
    return p


cookies = [cookie(c) for c in state.get("cookies", [])]
# A plain storageState() off a browser attached to a real profile saves every site's
# cookies — measured 2026-09-25: 48 of 49 were the user's own (google, linkedin,
# youtube…), one was the app's. They are set anyway (an app may span hosts); the file is
# named so it gets re-saved with the filtered call.
host = urllib.parse.urlsplit(base).hostname or ""
foreign = sorted({d for d in (c.get("domain", "").lstrip(".") for c in cookies)
                  if d and host != d and not host.endswith("." + d)})
if foreign:
    print("snapshot: WARN %s holds cookies for %d host(s) that are not %s (%s) — sessions that are not this"
          " app's, maybe your own; re-save it filtered to the app's URL (README, \"Behind a login\")."
          % (state_path, len(foreign), host, ", ".join(foreign[:4]) + (", …" if len(foreign) > 4 else "")),
          file=sys.stderr)
storage ={o["origin"]: [[i["name"], i["value"]] for i in o.get("localStorage", [])] for o in state.get("origins", [])}
seed = ("(() => { try { const e = %s[location.origin];"
        " if (e) for (const [k, v] of e) localStorage.setItem(k, v); } catch (_) {} })()" % json.dumps(storage))

# Chrome reads commands on fd 3 and writes replies on fd 4, each a JSON text ending in NUL.
profile = tempfile.mkdtemp(prefix="dk-snapshot-")
cmd_r, cmd_w = os.pipe()
out_r, out_w = os.pipe()


def wire():  # in the child before exec: its two pipe ends onto fds 3 and 4, inheritable
    a, b = os.dup(cmd_r), os.dup(out_w)
    os.dup2(a, 3)
    os.dup2(b, 4)
    os.set_inheritable(3, True)
    os.set_inheritable(4, True)


proc = subprocess.Popen(
    [browser, "--headless=new", "--disable-gpu", "--no-sandbox", "--hide-scrollbars", "--no-first-run",
     "--no-default-browser-check", "--remote-debugging-pipe", "--user-data-dir=" + profile, "about:blank"],
    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    preexec_fn=wire, close_fds=False)
os.close(cmd_r)
os.close(out_w)
buf, seq, sid, loaded, last_net, inflight = b"", 0, None, False, 0.0, set()


def read(deadline):
    global buf
    while b"\0" not in buf:
        left = deadline - time.time()
        if left <= 0 or not select.select([out_r], [], [], left)[0]:
            raise TimeoutError("no answer from the browser in time")
        chunk = os.read(out_r, 1 << 16)
        if not chunk:
            raise EOFError("the browser exited")
        buf += chunk
    raw, buf = buf.split(b"\0", 1)
    return json.loads(raw)


def note(m):  # an event of the current tab: requests in flight, and the load event
    global loaded, last_net
    name, p = m.get("method", ""), m.get("params", {})
    if m.get("sessionId") != sid:
        return
    if name == "Network.requestWillBeSent":
        inflight.add(p.get("requestId"))
        last_net = time.time()
    elif name in ("Network.loadingFinished", "Network.loadingFailed"):
        inflight.discard(p.get("requestId"))
        last_net = time.time()
    elif name == "Page.loadEventFired":
        loaded = True


def call(method, params=None, session=None, timeout=30):
    global seq
    seq += 1
    msg = {"id": seq, "method": method, "params": params or {}}
    if session:
        msg["sessionId"] = session
    data = json.dumps(msg).encode() + b"\0"
    while data:
        data = data[os.write(cmd_w, data):]
    deadline = time.time() + timeout
    while True:
        m = read(deadline)
        if m.get("id") == seq:
            if "error" in m:
                raise RuntimeError("%s: %s" % (method, m["error"].get("message", m["error"])))
            return m.get("result", {})
        note(m)


def settle():  # the load event, then 500 ms with nothing in flight, at most 3 s
    end = time.time() + 3
    while time.time() < end and (inflight or time.time() - last_net < 0.5):
        try:
            note(read(end if inflight else min(end, last_net + 0.5)))
        except TimeoutError:
            pass


def landed_elsewhere(want, got):
    a, b = urllib.parse.urlsplit(want), urllib.parse.urlsplit(got)
    return (a.netloc, a.path.rstrip("/")) != (b.netloc, b.path.rstrip("/"))


failed = None
try:
    for n, (dev, w, h, route, png) in enumerate(jobs):
        url = base + route
        tid = call("Target.createTarget", {"url": "about:blank"})["targetId"]
        sid = call("Target.attachToTarget", {"targetId": tid, "flatten": True})["sessionId"]
        inflight.clear()
        call("Page.enable", session=sid)
        call("Network.enable", session=sid)
        if n == 0 and cookies:  # cookies belong to the browser profile: once serves every tab
            try:
                call("Network.setCookies", {"cookies": cookies}, sid)
            except RuntimeError as e:
                raise RuntimeError("the browser refused a cookie in %s — %s" % (state_path, e))
        if storage:
            call("Page.addScriptToEvaluateOnNewDocument", {"source": seed}, sid)
        call("Emulation.setDeviceMetricsOverride",
             {"width": int(w), "height": int(h), "deviceScaleFactor": 1, "mobile": False}, sid)
        loaded, last_net = False, time.time()
        nav = call("Page.navigate", {"url": url}, sid)
        if nav.get("errorText"):
            raise RuntimeError("%s (%s): %s" % (route, dev, nav["errorText"]))
        deadline = time.time() + 30
        while not loaded:
            note(read(deadline))
        settle()
        href = call("Runtime.evaluate", {"expression": "location.href", "returnByValue": True}, sid)
        href = href.get("result", {}).get("value") or url
        if landed_elsewhere(url, href):
            print("snapshot: WARN %s (%s) ended on %s — a sign-in redirect? The session in %s may have"
                  " expired, or its cookies name another host than %s." % (route, dev, href, state_path, base),
                  file=sys.stderr)
        shot = base64.b64decode(call("Page.captureScreenshot", {"format": "png"}, sid)["data"])
        with open(png, "wb") as fh:
            fh.write(shot)
        print("shot=" + png, flush=True)
        call("Target.closeTarget", {"targetId": tid})
except (OSError, ValueError, KeyError, RuntimeError, EOFError) as e:
    failed = e
finally:
    try:
        call("Browser.close", timeout=5)
    except Exception:
        pass
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
    shutil.rmtree(profile, ignore_errors=True)
if failed:
    print("snapshot: %s" % (str(failed) or type(failed).__name__), file=sys.stderr)
    sys.exit(2)
PY
  else
    for job in ${jobs[@]+"${jobs[@]}"}; do
      IFS=$'\t' read -r d w h r png <<< "$job"
      "$browser" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
        --force-device-scale-factor=1 --run-all-compositor-stages-before-draw \
        --virtual-time-budget=3000 --window-size="$w,$h" --screenshot="$png" \
        "${base_url%/}$r" >/dev/null 2>&1 \
        || not_measured "the browser exited non-zero on $r ($d)"
      [ -s "$png" ] || not_measured "no PNG written for $r ($d)"
      echo "shot=$png"
    done
  fi
  echo "shots=$out (${#jobs[@]})"
  exit 0
fi

base=""; current=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) base="${2:-}"; [ -n "$base" ] || die "--base needs a directory or a git ref" 1; shift ;;
    --current) current="${2:-}"; [ -n "$current" ] || die "--current needs a directory" 1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown flag $1" 1 ;;
  esac
  shift
done
[ -n "$base" ] || die "review needs --base <dir|git-ref>" 1

if [ -d "$base" ]; then
  base_root="$base"
else
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 \
    || die "--base '$base' is neither a directory nor a git ref" 1
  base_root="$DK/shots/_base-$(slug "$base")"
  rm -rf "$base_root"; mkdir -p "$base_root"
  # From the toplevel, with a toplevel-relative path: `git archive` refuses a pathspec
  # outside the cwd, so run from a subdirectory it never found the root's shots.
  top="$(git rev-parse --show-toplevel)"
  shots_rel="$(python3 -c 'import os,sys;print(os.path.relpath(os.path.realpath(sys.argv[1]),os.path.realpath(sys.argv[2])))' "$DK/shots" "$top")"
  git -C "$top" archive "$base" -- "$shots_rel" 2>/dev/null | tar -x -C "$base_root" 2>/dev/null || true
fi
base_set="$(find_set "$base_root")"
[ -n "$base_set" ] || die "--base '$base' carries no shot set (a desktop/ or mobile/ dir of PNGs)" 1

if [ -z "$current" ]; then
  while IFS= read -r c; do
    c="${c%/}"
    case "$c" in */_base-*) continue ;; esac
    [ "$(cd "$c" && pwd)" = "$(cd "$base_set" && pwd)" ] && continue
    current="$c"; break
  done < <(ls -td "$DK"/shots/*/ 2>/dev/null || true)
  [ -n "$current" ] || die "no current shot set under $DK/shots — run \`dk snapshot\` first" 1
fi
current_set="$(find_set "$current")"
[ -n "$current_set" ] || die "--current '$current' carries no shot set (a desktop/ or mobile/ dir of PNGs)" 1

pair="$(basename "$current_set")-vs-$(basename "$base_set")"
html="$DK/reviews/$(slug "$pair").html"
mkdir -p "$DK/reviews"

python3 - "$base_set" "$current_set" "$html" <<'PY' || die "review page could not be written" 1
import os, sys

base, cur, html = sys.argv[1:4]
try:
    from PIL import Image, ImageChops
    engine = True
except ImportError:
    engine = False

THRESHOLD = 10


def collect(root):
    shots = {}
    for dev in ("desktop", "mobile"):
        d = os.path.join(root, dev)
        if not os.path.isdir(d):
            continue
        for f in sorted(os.listdir(d)):
            if f.endswith(".png"):
                shots[(dev, f[:-4])] = os.path.join(d, f)
    return shots


def canvas(im, size):
    if im.size == size:
        return im
    out = Image.new("RGB", size, (255, 255, 255))
    out.paste(im, (0, 0))
    return out


def diff(a, b, out_png):
    """changed-pixel % over the union canvas, and a heatmap beside it."""
    ia = Image.open(a).convert("RGB")
    ib = Image.open(b).convert("RGB")
    size = (max(ia.size[0], ib.size[0]), max(ia.size[1], ib.size[1]))
    ia, ib = canvas(ia, size), canvas(ib, size)
    delta = ImageChops.difference(ia, ib).convert("L").point(lambda v: 255 if v > THRESHOLD else 0)
    changed = sum(delta.histogram()[1:])
    total = size[0] * size[1]
    heat = Image.merge("RGB", (delta, Image.new("L", size, 0), Image.new("L", size, 0)))
    heat = Image.blend(ib.convert("RGB").point(lambda v: 60 + v // 4), heat, 0.75)
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    heat.save(out_png)
    return 100.0 * changed / total if total else 0.0


b_shots, c_shots = collect(base), collect(cur)
rows = []
for key in sorted(set(b_shots) | set(c_shots)):
    dev, route = key
    before, after = b_shots.get(key), c_shots.get(key)
    pct, heat = None, None
    if before and after:
        status = "same"
        if engine:
            pct = diff(before, after, os.path.join(os.path.dirname(html), "diff", f"{dev}__{route}.png"))
            heat = os.path.join(os.path.dirname(html), "diff", f"{dev}__{route}.png")
            status = "changed" if pct > 0 else "same"
        else:
            status = "changed" if open(before, "rb").read() != open(after, "rb").read() else "same"
    else:
        status = "added" if after else "removed"
    rows.append((route, dev, pct, status, before, after, heat))

rel = lambda p: os.path.relpath(p, os.path.dirname(html) or ".") if p else ""
cell = lambda p, label: (f'<figure><img src="{rel(p)}" alt="{label}"><figcaption>{label}</figcaption></figure>'
                         if p else f'<figure class="missing"><div>no {label} shot</div></figure>')
body = []
for route, dev, pct, status, before, after, heat in rows:
    n = "—" if pct is None else f"{pct:.2f}%"
    body.append(
        f'<section><h2>{route} <span class="dev">{dev}</span> '
        f'<span class="st {status}">{status}</span> <span class="pct">{n}</span></h2><div class="pair">'
        + cell(before, "before") + cell(after, "after")
        + (cell(heat, "diff") if heat else
           '<figure class="missing"><div>no diff engine: install Pillow</div></figure>')
        + "</div></section>")

note = ("" if engine else
        "<p class=\"warn\">no diff engine: install Pillow (<code>python3 -m pip install Pillow</code>) "
        "for the heatmap and the changed-pixel percentage; the pair above is unmeasured.</p>")
open(html, "w", encoding="utf-8").write(
    "<!doctype html><meta charset=utf-8><title>design-kit review</title>"
    "<style>body{font:14px/1.5 system-ui,sans-serif;margin:24px;background:#0f1115;color:#e6e8ee}"
    "h1{font-size:18px}h2{font-size:14px;font-weight:600;margin:24px 0 8px}"
    ".dev,.pct{color:#9aa3b2;font-weight:400}.st{font-size:11px;padding:1px 6px;border-radius:9px;"
    "background:#2a2f3a}.st.changed{background:#7f1d1d}.st.added{background:#1e3a8a}"
    ".st.removed{background:#3f3f46}.pair{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}"
    "figure{margin:0;background:#171a21;border:1px solid #232735;border-radius:6px;padding:6px}"
    "img{width:100%;height:auto;display:block;border-radius:3px}"
    "figcaption{color:#9aa3b2;font-size:11px;margin-top:4px}"
    ".missing div{color:#9aa3b2;font-size:12px;padding:24px 8px;text-align:center}"
    ".warn{color:#fbbf24}.meta{color:#9aa3b2}</style>"
    f"<h1>before / after</h1><p class=meta>base <code>{base}</code> → current <code>{cur}</code>"
    f" · a pixel counts as changed when any channel moves by more than {THRESHOLD}</p>{note}"
    + "".join(body)
    + "<p class=meta>No assertion was made here: this page renders the pair and counts pixels. "
      "Whether the change is the one you meant is your call.</p>")

print("| route | device | changed% | status |")
print("|---|---|---|---|")
for route, dev, pct, status, *_ in rows:
    print(f"| {route} | {dev} | {'no diff engine: install Pillow' if pct is None else f'{pct:.2f}'} | {status} |")
counts = {}
for r in rows:
    counts[r[3]] = counts.get(r[3], 0) + 1
print("summary: " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items())) if counts
      else "summary: no route in either set")
print("review=" + html)
PY

out="$(bash "$here/preview.sh" --docroot "$DK" 2>&1)" || { echo "$out" >&2; not_measured "the preview server did not start"; }
echo "$out" | grep -v '^preview: http' >&2 || true
url="$(cat "$DK/.preview.url" 2>/dev/null || true)"
[ -n "$url" ] || not_measured "the preview server did not write its URL"
echo "url=${url%/}/${html#"$DK"/}"
