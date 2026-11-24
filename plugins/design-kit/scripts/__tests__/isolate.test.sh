#!/usr/bin/env bash
# Drives isolate.py as units, no server: host_ok (names, numeric forms, brackets, userinfo, ports, control characters), inside (symlinks, a shared prefix, a linked docroot, NUL), scriptable.
# Misses: what the server does with the answers, and XML_POLICY and COMMON on the wire (serve.test.sh); a symlink swapped between inside() and the open.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
python3 - "$here/isolate.py" "$tmp" <<'PY' || { echo "FAIL: isolate.py units"; exit 1; }
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("dkisolate", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
tmp, bad = sys.argv[2], []

def check(fn, cases, want):
    for args in cases:
        try:
            got = getattr(m, fn)(*args)
        except Exception as exc:
            got = repr(exc)
        if got is not want:
            bad.append("FAIL: %s%r is %s, want %s" % (fn, tuple(args), got, want))

check("host_ok", [[v] for v in (
    "localhost", "LocalHost", "localhost:8124", "127.0.0.1", "127.0.0.1:8124", "192.168.1.9:8124", "0.0.0.0",
    "[::1]", "[::1]:8124", "[FE80::1]:80", "[::ffff:127.0.0.1]:8124")], True)
check("host_ok", [[v] for v in (
    None, "", " ", "evil.example", "evil.example:8124", "localhost.evil", "localhost.", "127.0.0.1.", "localhost.:8124",
    "127.0.0.1.evil.example", "foo.localhost", "local_host", "127.1", "0x7f.0.0.1", "2130706433", "256.0.0.1", "...",
    "localhost:", "localhost:x", "localhost:8124:1", "127.0.0.1:-1", "::1", "[::1", "[127.0.0.1]", "[localhost]", "[::g]",
    "[::1]evil.example", "evil.example[::1]", "[::1].evil.example", "[fe80::1%eth0]", "x@127.0.0.1", "127.0.0.1@evil.example",
    "127.0.0.1/x", "evil.example/@127.0.0.1", "127.0.0.1?x", "127.0.0.1#x", "127.0.0.1\\x", "http://127.0.0.1", "//127.0.0.1",
    "127.0.0.1\t", "127.0.0.1\n", " 127.0.0.1", "local\thost", "127.0.0.1, evil.example", "localhoſt", "١٢٧.0.0.1")], False)

root, out = os.path.join(tmp, "root"), os.path.join(tmp, "root-out")
os.makedirs(os.path.join(root, "a")); os.makedirs(out)
for p in (os.path.join(root, "a", "p.html"), os.path.join(out, "p.html")):
    open(p, "w").close()
at = lambda *p: os.path.join(root, *p)
os.symlink(os.path.join(out, "p.html"), at("file-out")); os.symlink(out, at("dir-out")); os.symlink(os.path.join(out, "gone"), at("dangling-out"))
os.symlink(at("a", "p.html"), at("file-in")); os.symlink("a", at("dir-in")); os.symlink(at("dir-out"), at("a", "twice-out"))
os.symlink(root, os.path.join(tmp, "linked-root"))
check("inside", [(root, root), (root, at("a", "p.html")), (root, at("a", "gone")), (root, at("file-in")), (root, at("dir-in", "p.html")),
                 (os.path.join(tmp, "linked-root"), at("a", "p.html")), (root, os.path.join(tmp, "linked-root", "a")),
                 (root + os.sep, at("a")), (os.sep, at("a"))], True)
check("inside", [(root, tmp), (root, out), (root, at("..", "root-out", "p.html")), (root, at("file-out")), (root, at("dir-out")),
                 (root, at("dir-out", "p.html")), (root, at("dir-out", "gone")), (root, at("dangling-out")), (root, at("a", "twice-out", "p.html")),
                 (root, at("a\0b"))], False)

check("scriptable", [[v] for v in ("text/xml", "application/xml", "image/svg+xml", "application/xhtml+xml", "application/atom+xml", "model/xml",
                                   "IMAGE/SVG+XML", "text/xml; charset=utf-8")], True)
check("scriptable", [[v] for v in ("", "text/html", "text/plain", "image/png", "application/pdf", "application/octet-stream", "application/xml-dtd",
                                   "text/plain; x=+xml")], False)
print("\n".join(bad), end="\n" if bad else "")
sys.exit(1 if bad else 0)
PY
echo "PASS isolate.test.sh"
