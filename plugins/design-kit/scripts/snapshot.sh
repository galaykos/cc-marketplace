#!/usr/bin/env bash
# snapshot.sh — `dk snapshot` and `dk review`: PNGs of the running app's routes, and
# a before/after page pairing two shot sets.
#
# WHAT IT DOES.
#   snapshot [--routes /,/pricing] [--device desktop|mobile|both] [--base-url URL]
#            [--out DIR]
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
# EXIT. 0 shot / rendered · 1 bad arguments · 2 the browser or the server was
# unreachable, printed as NOT MEASURED and never as "no change": a shot nobody took
# is not a screen that did not change.
#
# WHAT IT DOES NOT DO. No visual ASSERTION and no threshold gate — it renders a pair
# and a number; whether the change is wanted is the reader's call. No auth flows (a
# route behind a login shoots the login page), no per-component crops, no scroll or
# animation settling beyond one 3 s virtual-time budget, no device emulation past the
# viewport size (no touch, no mobile UA, no DPR change). A pixel counts as changed
# when any channel moves by more than 10, so antialiasing and font hinting differences
# between two machines count as change. Shots written outside the preview docroot
# (an --out elsewhere) open from disk but 404 through the server.
#
# Standing: **gate** for the exit codes and the pairing —
# scripts/__tests__/snapshot.test.sh drives the argument errors, the unreachable exit,
# both diff-engine branches and the pairing over fixture PNG dirs, and skips the
# shoot when no browser is installed, saying so. Reading the pair — deciding the
# change is the one you meant — is **agent-graded**; nothing here asserts a pixel.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
DK="${DESIGN_KIT_DIR:-.design-kit}"

usage() { sed -n '2,42p' "$0"; }
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

mode="${1:-}"; [ $# -gt 0 ] && shift
case "$mode" in
  snapshot|review) ;;
  -h|--help|"") usage; exit 0 ;;
  *) die "unknown mode $mode — snapshot | review" 1 ;;
esac

if [ "$mode" = snapshot ]; then
  routes="/"; device="desktop"; base_url=""; out=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --routes) routes="${2:-}"; [ -n "$routes" ] || die "--routes needs a comma-separated list" 1; shift ;;
      --device) device="${2:-}"; [ -n "$device" ] || die "--device needs desktop, mobile or both" 1; shift ;;
      --base-url) base_url="${2:-}"; [ -n "$base_url" ] || die "--base-url needs a URL" 1; shift ;;
      --out) out="${2:-}"; [ -n "$out" ] || die "--out needs a directory" 1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "unknown flag $1" 1 ;;
    esac
    shift
  done
  case "$device" in desktop|mobile|both) ;; *) die "--device must be desktop, mobile or both (got $device)" 1 ;; esac

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
  shot_n=0
  for d in $devices; do
    case "$d" in desktop) w=1440; h=900 ;; mobile) w=390; h=844 ;; esac
    mkdir -p "$out/$d"
    for r in "${route_list[@]}"; do
      [ -n "$r" ] || continue
      case "$r" in /*) ;; *) r="/$r" ;; esac
      png="$out/$d/$(slug "$r").png"
      "$browser" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
        --force-device-scale-factor=1 --run-all-compositor-stages-before-draw \
        --virtual-time-budget=3000 --window-size="$w,$h" --screenshot="$png" \
        "${base_url%/}$r" >/dev/null 2>&1 \
        || not_measured "the browser exited non-zero on $r ($d)"
      [ -s "$png" ] || not_measured "no PNG written for $r ($d)"
      echo "shot=$png"; shot_n=$((shot_n + 1))
    done
  done
  echo "shots=$out ($shot_n)"
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
  git archive "$base" -- "$DK/shots" 2>/dev/null | tar -x -C "$base_root" 2>/dev/null || true
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
