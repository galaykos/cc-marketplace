#!/usr/bin/env bash
# preview-feedback.sh list [--all] | wait [--timeout S] | reply --id ID --status addressed|dismissed [--text LINE] | shot --id ID, each with [--docroot DIR] (default taskmaster-docs/mockups): reads DIR/.feedback.jsonl, the rows serve.py's POST /_feedback appends; prints rows as JSON, one per line, control, format and blank-rendering characters escaped; a handed-out row still open is unread again after 15 min; wait (stats every 0.5 s, parses on a change, default 600 s) and reply rewrite under DIR/.feedback.lock (serve.py's flock) through a dot temp file and a rename.
# Exit: 0 done (list/wait print rows, wait then marks them handed_out with the time, reply prints the row, shot prints the PNG path); 2 bad argument; 3 wait timed out, nothing printed; 4 shot found no Chromium-family browser ($PREVIEW_BROWSER, PATH, macOS bundles, Playwright's cache); 5 no row with that id, or shot's row has no anchor or a page outside DIR; 1 python3 missing, wait could not print, the browser failed or ran past 30 s, or no PNG written.
# Misses: row text is whatever the page posted, third-party script on it included; shot loads the page from 127.0.0.1 when preview.sh's server answers, else from disk (file://, where page script has file-scheme reach), with the default theme, scheme and states, not the row's; a row appended by anything other than serve.py skips the lock.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/preview-feedback.sh
set -u

usage() { echo "usage: preview-feedback.sh list [--all] | wait [--timeout S] | reply --id ID --status addressed|dismissed [--text LINE] | shot --id ID   [--docroot DIR]" >&2; exit 2; }

cmd="${1:-}"; [ $# -gt 0 ] && shift
case "$cmd" in list | wait | reply | shot) ;; -h | --help) sed -n '2,4p' "$0"; exit 0 ;; *) usage ;; esac
docroot="taskmaster-docs/mockups"; all=0; timeout=600; id=""; status=""; text=""
while [ $# -gt 0 ]; do
  case "$1" in
    --docroot) [ $# -ge 2 ] || usage; docroot=$2; shift ;;
    --all) all=1 ;;
    --timeout) case "${2:-}" in '' | *[!0-9]*) usage ;; esac; timeout=$2; shift ;;
    --id) [ -n "${2:-}" ] || usage; id=$2; shift ;;
    --status) case "${2:-}" in addressed | dismissed) status=$2 ;; *) usage ;; esac; shift ;;
    --text) [ $# -ge 2 ] || usage; text=$2; shift ;;
    *) usage ;;
  esac
  shift
done
case "$cmd" in
  reply) [ -n "$id" ] && [ -n "$status" ] || usage ;;
  shot) [ -n "$id" ] || usage ;;
esac
command -v python3 >/dev/null 2>&1 || { echo "preview-feedback.sh: python3 not found" >&2; exit 1; }

find_browser() {
  if [ -n "${PREVIEW_BROWSER:-}" ]; then
    [ -x "$PREVIEW_BROWSER" ] && { echo "$PREVIEW_BROWSER"; return 0; }
    return 1
  fi
  local c
  for c in google-chrome chromium chromium-browser microsoft-edge chrome; do
    command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return 0; }
  done
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
           "$HOME/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
           "$HOME"/Library/Caches/ms-playwright/chromium-*/chrome-mac*/Chromium.app/Contents/MacOS/Chromium \
           "$HOME"/.cache/ms-playwright/chromium-*/chrome-linux*/chrome; do
    [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

run() {
  python3 - "$cmd" "$docroot" "$all" "$timeout" "$id" "$status" "$text" <<'PY'
import calendar, contextlib, json, os, re, sys, tempfile, time, unicodedata
from pathlib import Path
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import ProxyHandler, build_opener

try:
    import fcntl
except ImportError:
    fcntl = None

cmd, docroot, all_rows, timeout, want_id, status, text = sys.argv[1:8]
root = Path(docroot)
FILE = root / ".feedback.jsonl"
LEASE = 15 * 60  # a handed-out row that is still open comes back after this many seconds
# Variation selectors and the letters that render blank (Hangul fillers, the empty Braille cell): not C*, yet they hide text.
BLANK = set(range(0xFE00, 0xFE10)) | set(range(0xE0100, 0xE01F0)) | set(range(0x180B, 0x1810)) | {0x115F, 0x1160, 0x3164, 0xFFA0, 0x2800}


def hidden(c):
    cat = unicodedata.category(c)
    return cat[0] == "C" or cat in ("Zl", "Zp") or ord(c) in BLANK


def show(row):
    """One JSON line; a control, format, private-use, unassigned or separator character, a variation selector or a blank-rendering letter is escaped, so a row cannot act on a terminal; U+034F and U+3000 still print raw."""
    out = json.dumps(row, ensure_ascii=False)
    return "".join(json.dumps(c)[1:-1] if hidden(c) else c for c in out)


def load():
    """[[row or None, raw bytes]] per non-blank line; an unparseable line is kept as raw bytes, so a rewrite never drops it."""
    try:
        fd = os.open(str(FILE), os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
    except FileNotFoundError:
        return []
    with os.fdopen(fd, "rb") as handle:
        data = handle.read()
    entries = []
    for raw in data.split(b"\n"):
        if not raw.strip():
            continue
        try:
            row = json.loads(raw)
        except ValueError:
            row = None
        entries.append([row if isinstance(row, dict) else None, raw])
    return entries


@contextlib.contextmanager
def locked():
    """serve.py's lock: an append waits while the file is read and replaced, so it never lands in the old copy."""
    fd = os.open(str(root / ".feedback.lock"), os.O_WRONLY | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0), 0o600)
    try:
        if fcntl:
            fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def save(entries):
    fd, tmp = tempfile.mkstemp(dir=str(root), prefix=".feedback-", suffix=".tmp")
    try:
        with os.fdopen(fd, "wb") as handle:
            for _row, raw in entries:
                handle.write(raw + b"\n")
        os.replace(tmp, str(FILE))
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def update(entry, **fields):
    entry[0].update(fields)
    entry[1] = json.dumps(entry[0], ensure_ascii=False).encode("utf-8")


def handed_at(row):
    """When the row was handed out (epoch seconds); 0 for never; None for any other value, such as true (handed out, no lease)."""
    out = row.get("handed_out")
    if isinstance(out, str):
        try:
            return calendar.timegm(time.strptime(out, "%Y-%m-%dT%H:%M:%SZ"))
        except ValueError:
            return None
    return None if out else 0


def unread(entries):
    """Open rows never handed out, or notes handed out more than LEASE ago. A pick has no reply that closes it, so its hand-out is final."""
    now = time.time()
    return [e for e in entries if e[0] and e[0].get("status") == "open" and handed_at(e[0]) is not None
            and (handed_at(e[0]) == 0 or (e[0].get("kind") == "note" and now - handed_at(e[0]) >= LEASE))]


def lease_ends(entries):
    """The earliest time a lease on an open row runs out, so wait re-reads then without a change on disk."""
    ends = [handed_at(e[0]) + LEASE for e in entries
            if e[0] and e[0].get("status") == "open" and e[0].get("kind") == "note" and handed_at(e[0])]
    return min(ends, default=float("inf"))


def signature():
    try:
        st = os.stat(str(FILE))
    except OSError:
        return None
    return (st.st_ino, st.st_size, st.st_mtime_ns)


def find(entries):
    return next((e for e in entries if e[0] and e[0].get("id") == want_id), None)


if cmd == "list":
    for row, _raw in (load() if all_rows == "1" else unread(load())):
        if row is not None:
            print(show(row))
    sys.exit(0)

if cmd == "wait":
    deadline = time.monotonic() + int(timeout)
    seen, due = "unread", 0.0
    while True:
        # Parse only when the file's inode, size or mtime moved, or a lease ran out.
        sig = signature()
        if sig != seen or time.time() >= due:
            seen, entries = sig, load()
            due = lease_ends(entries)
            if unread(entries):
                with locked():
                    entries = load()
                    fresh = unread(entries)
                    if fresh:
                        # Print before marking: a waiter killed or unable to write leaves the rows unread.
                        try:
                            for row, _raw in fresh:
                                print(show(row))
                            sys.stdout.flush()
                        except OSError as exc:
                            print("preview-feedback.sh: could not print the rows (%s); none marked handed out" % exc.strerror, file=sys.stderr)
                            os._exit(1)
                        stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
                        for entry in fresh:
                            update(entry, handed_out=stamp)
                        save(entries)
                        sys.exit(0)
        if time.monotonic() >= deadline:
            sys.exit(3)
        time.sleep(0.5)

if cmd == "reply":
    if not FILE.is_file():
        print("preview-feedback.sh: no row %s in %s" % (want_id, FILE), file=sys.stderr)
        sys.exit(5)
    with locked():
        entries = load()
        entry = find(entries)
        if entry is None:
            print("preview-feedback.sh: no row %s in %s" % (want_id, FILE), file=sys.stderr)
            sys.exit(5)
        update(entry, status=status, reply=" ".join(text.split())[:300], handed_out=True)
        save(entries)
    print(show(entry[0]))
    sys.exit(0)

# shot: resolve the row to a URL, the PNG path and the viewport; the shell outlines ?_outline= and scrolls to it.
entry = find(load())
row = entry[0] if entry else None
anchor = row.get("anchor") if row else None
if not row or not isinstance(anchor, dict) or not isinstance(anchor.get("selector"), str) or not anchor["selector"]:
    print("preview-feedback.sh: no row %s with an element anchor in %s" % (want_id, FILE), file=sys.stderr)
    sys.exit(5)
page = row.get("page") if isinstance(row.get("page"), str) else ""
base = root.resolve()
target = (base / page).resolve()
if (not re.fullmatch(r"[A-Za-z0-9_-]{1,32}", want_id) or any(s.startswith(".") for s in page.split("/"))
        or base not in target.parents or not target.is_file()):
    print("preview-feedback.sh: row %s names no page inside %s" % (want_id, base), file=sys.stderr)
    sys.exit(5)
viewport = (row.get("context") or {}).get("viewport") or {}


def size(value, low, high, default):
    return min(max(int(value), low), high) if isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0 else default


def served_at():
    """This docroot's running server as http://127.0.0.1:<port>/ (preview.sh's pid and URL files, a live pid, a 200 for the page), else None."""
    try:
        pid = int((root / ".preview.pid").read_text().strip())
        port = urlsplit((root / ".preview.url").read_text().strip()).port
        if pid <= 0 or not port:
            return None
        os.kill(pid, 0)
        base = "http://127.0.0.1:%d/" % port
        with build_opener(ProxyHandler({})).open(base + quote(page) + "?static=1", timeout=3) as resp:
            return base if resp.status == 200 else None
    except (OSError, ValueError):
        return None


# Over http when the server runs: the page then has the reach it has in the user's browser, not file-scheme reach.
base_url = served_at()
query = urlencode({"static": "1", "_outline": anchor["selector"]})
url = (base_url + quote(page) if base_url else target.as_uri()) + "?" + query
print("\t".join([url, str(base / ".feedback-shots" / (want_id + ".png")),
                 str(size(viewport.get("w"), 320, 3840, 1280)), str(size(viewport.get("h"), 240, 2160, 800))]))
PY
}

if [ "$cmd" != shot ]; then
  run
  exit $?
fi

spec="$(run)" || exit $?
IFS="$(printf '\t')" read -r url out w h <<EOF
$spec
EOF
browser="$(find_browser)" || { echo "preview-feedback.sh: no Chromium-family browser found (PREVIEW_BROWSER, PATH, Playwright's cache); no screenshot taken" >&2; exit 4; }
mkdir -p "$(dirname "$out")" || exit 1
rm -f "$out"
profile="$(mktemp -d)" || exit 1
# Chrome's sandbox stays on: off only as root, where Chrome refuses to start with it, or on PREVIEW_BROWSER_NO_SANDBOX=1.
sandbox=""; { [ "$(id -u)" = 0 ] || [ "${PREVIEW_BROWSER_NO_SANDBOX:-}" = 1 ]; } && sandbox="--no-sandbox"
limit=""; command -v timeout >/dev/null 2>&1 && limit="timeout 30"
$limit "$browser" --headless=new --disable-gpu $sandbox --hide-scrollbars --force-device-scale-factor=1 \
  --run-all-compositor-stages-before-draw --virtual-time-budget=3000 --no-first-run --no-default-browser-check \
  --user-data-dir="$profile" --window-size="$w,$h" --screenshot="$out" "$url" >/dev/null 2>&1
rc=$?
rm -rf "$profile"
if [ "$rc" != 0 ]; then
  if [ "$rc" = 124 ] && [ -n "$limit" ]; then why="ran past 30 s"; else why="exited $rc"; fi
  rm -f "$out"
  echo "preview-feedback.sh: $browser $why for $url; no screenshot taken" >&2
  exit 1
fi
[ -s "$out" ] || { echo "preview-feedback.sh: $browser wrote no PNG for $url" >&2; exit 1; }
echo "$out"
