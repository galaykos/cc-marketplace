#!/usr/bin/env python3
"""note-shot.py - `dk notes --shot ID`: a note's raw page at its static content URL, headless and at the note's size, its element centred and outlined, 2 s after the load, as the PNG whose path it prints; exit 0, 2 bad arguments, 4 no PNG (no browser, no server, over 60 s). The selector is page data: an argument of a function run over DevTools in render-check.py's isolated world, whose DOM page script cannot replace; one that matches nothing shoots the page as it is and says so on stderr.
Misses: what comes after those 2 s; an element hidden, or inside an iframe or a shadow root; an outline below a modal dialog, under a rule that styles every div !important, or taken out by the page; a page that is gone is shot as the server's 404, one that leaves within the 2 s not at all.
Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/note-shot.py
"""
import argparse
import base64
import importlib.util
import os
import sys
import time
from urllib.parse import quote

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("dkcheck", os.path.join(HERE, "render-check.py"))
check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check)

SETTLE_MS = 2000  # real time: on the clock of --virtual-time-budget what a scroll reveals never gets its frames
OUTLINE_JS = """async function (selector, ms) {
  const box = document.createElement('div');
  const place = () => {
    let el = null;
    try { el = document.querySelector(selector); } catch (e) { /* not a selector */ }
    if (!el) { box.remove(); return false; }
    el.scrollIntoView({ block: 'center', inline: 'center', behavior: 'instant' });
    const r = el.getBoundingClientRect();
    box.style.cssText = 'all:initial;position:fixed;box-sizing:border-box;pointer-events:none;z-index:2147483647;border:3px solid #d93025;'
      + 'border-radius:4px;box-shadow:0 0 0 4000px rgba(0,0,0,.2);'
      + `left:${r.left - 5}px;top:${r.top - 5}px;width:${r.width + 10}px;height:${r.height + 10}px`;
    document.documentElement.append(box);
    return true;
  };
  place(); // first, so that what a scroll reveals has the wait to come in
  await new Promise((r) => setTimeout(r, ms));
  return place();
}"""


def die(why):
    print("dk notes: %s; no screenshot taken" % why, file=sys.stderr)
    sys.exit(4)


def size(text):
    w, h = map(int, text.split("x"))
    return w, h


def shoot(ch, url, wh, selector):
    """(PNG bytes, whether the selector matched)."""
    ch.call("Browser.setDownloadBehavior", {"behavior": "deny"})
    sid = ch.open(*wh)[1]
    nav = ch.call("Page.navigate", {"url": url}, sid)
    if nav.get("errorText"):
        raise RuntimeError("it could not open the page: " + nav["errorText"])
    ch.wait_for(sid, "Page.loadEventFired", check.LOAD_S)
    ctx = ch.call("Page.createIsolatedWorld", {"frameId": nav["frameId"], "worldName": check.WORLD}, sid)["executionContextId"]
    drawn = ch.call("Runtime.callFunctionOn", {"functionDeclaration": OUTLINE_JS, "executionContextId": ctx, "arguments": [{"value": selector}, {"value": SETTLE_MS}],
                                               "awaitPromise": True, "returnByValue": True}, sid)
    png = ch.call("Page.captureScreenshot", {"format": "png"}, sid)
    return base64.b64decode(png["data"]), drawn["result"].get("value")


def main(argv=None):
    deadline = time.monotonic() + check.TOTAL_S
    ap = argparse.ArgumentParser(prog="note-shot.py", description="The outlined shot of a note's element.")
    ap.add_argument("--docroot", required=True)
    ap.add_argument("--page", required=True)
    ap.add_argument("--selector", required=True)
    ap.add_argument("--size", required=True, type=size)
    ap.add_argument("--out", required=True)
    a = ap.parse_args(argv)

    exe = check.find_browser()[0]
    if not exe:
        die(check.NO_BROWSER)
    origin = check.start_server(a.docroot)
    if not origin:
        die("the preview server did not start")
    check.exit_on_signals()
    try:
        ch = check.Chrome(exe, deadline, check.TOTAL_S)  # the deadline is the only limit of a call: one page, and a cold browser
    except OSError as exc:
        die("could not start %s: %s" % (exe, exc.strerror or exc))
    try:
        try:
            png, matched = shoot(ch, "%s/%s?static=1" % (origin, quote(a.page)), a.size, a.selector)
        finally:
            ch.close()
    except (EOFError, BrokenPipeError):
        die("the browser exited %d" % ch.proc.returncode)
    except (OSError, RuntimeError) as exc:
        die("the browser " + ("ran past %d s" % check.TOTAL_S if time.monotonic() >= deadline else "failed: %s" % exc))
    try:
        with open(a.out, "wb") as fh:
            fh.write(png)
    except OSError as exc:
        die("could not write %s: %s" % (a.out, exc.strerror or exc))
    if not matched:
        print("dk notes: no element of the page matches the note's selector; the screenshot has no outline", file=sys.stderr)
    print(a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
