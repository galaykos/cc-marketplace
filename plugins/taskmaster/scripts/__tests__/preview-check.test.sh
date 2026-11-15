#!/usr/bin/env bash
# Drives scripts/preview-check.sh and serve.py's check routes on a temp docroot: the axe-core pin, no route serving the check or taking findings, GET /_checks (checked, stale, a NUL), .checks never served, then with a real browser one fixture page per check (ids, texts, widths, exit codes), a clean shell page and a plain one, shell pages of one to six frames at 375, a finding in the fourth, fifth or sixth frame named by position, the limits of a layout or creative pass (E7: seven frames, five options, a fourth switcher, a name used twice, a name serve.py refuses in a switcher and on a kind with one option; none on the same pages with no pass mark, under another pass-kind value, or on a page at every limit), each palette's contrast in light and in dark (E8: soft text at 3:1 in a palette's dark set only, named with palette, scheme, ratio, colours and element, once across three widths, and none with the value fixed; each of the seven pairs lowered alone on a page that draws every primitive; all seven on a page that draws none, measured on a probe, one colour in oklch(), one see-through; a see-through background over a tinted paper; a palette with no dark set beside one with an empty rule; a palette that is its kind's one option; four passing palettes on a ledger pair, whose screenshot after the run E6 finds equal to a load nothing switched), escaping, forged answers and posts, a proxy, a download, WebRTC, a hung font, a busy page, a signal, pruning, E6 against the ledger, the server auto-start, no process left behind.
# Misses: whether the model runs the script or acts on a finding; of E7, a switcher written by hand on a page with no pass mark, an empty option name, a refused or repeated name in the style or type switcher, a fifth option there, and two limits broken on one page; of E8, a see-through colour that is not rgba(), most of the soft-text primitives, a palette on a page with no frame, a state whose check throws, and a state loop that runs out of time; macOS and Edge lookup paths; a browser that is found but cannot start; the PNGs' content (looked at by eye, not here). With no browser the browser half prints SKIP.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
R="$here/../preview-check.sh"
P="$here/../preview.sh"
SHELL_HTML="$here/../../skills/visual-decisions/assets/shell.html"
AXE="$here/../../vendor/axe-core/axe.min.js"
pass=0; fail=0
ok() { pass=$((pass+1)); }
bad() { echo "FAIL $1: $2"; fail=$((fail+1)); }
summary() { echo "preview-check.sh tests: $pass passed, $fail failed"; }

if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "SKIP: python3 or curl not found"
  summary
  exit 0
fi

T="$(mktemp -d)"
D="$T/mockups"
pids=""
free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }
udp_port="$(python3 -c 'import socket;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
hang_port="$(free_port)"
cleanup() {
  for d in "$D" "$T/auto"; do [ -d "$d" ] && bash "$P" --docroot "$d" --stop >/dev/null 2>&1; done
  for p in $pids; do kill "$p" 2>/dev/null; done
  for p in $pids; do wait "$p" 2>/dev/null; done
  rm -rf "$T"
}
trap cleanup EXIT
mkdir -p "$T/tmp"
export TMPDIR="$T/tmp"

code() { curl -s -o "$T/resp" -w '%{http_code}' --max-time 5 "$@"; }
expect() {
  local name=$1 want=$2 got; shift 2
  got="$(code "$@")"
  if [ "$got" = "$want" ]; then ok; else bad "$name" "want $want, got $got: $(head -c 200 "$T/resp")"; fi
}
# fields <key>...: those keys of the last JSON response, as one JSON list.
fields() { python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(json.dumps([d.get(k) for k in sys.argv[2:]]))' "$T/resp" "$@"; }

# ---- the vendored axe-core is the file that was reviewed --------------------------
sha="$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$AXE" 2>/dev/null)"
[ "$sha" = 20c09fe157a8a34a30e241aaa1fcdade657734f08ab379ecfbeb7d45cc46e878 ] && ok || bad "axe-core pin" "vendor/axe-core/axe.min.js sha256 is $sha"

# ---- fixtures: shell pages under f/ (not ledger files), ledger passes at the top ----
mkdir -p "$D/f"
python3 - "$SHELL_HTML" "$D" "$udp_port" "$hang_port" <<'EOF'
import os, re, sys, time
shell = open(sys.argv[1], encoding="utf-8").read()
root, udp_port, hang_port = sys.argv[2], sys.argv[3], sys.argv[4]
assert shell.count("</head>") == 1 and shell.count('<main id="vd-frames">') == 1

TABLE = """<table class="vd-table">
<thead><tr><th scope="col">Customer</th><th scope="col" class="vd-num">Amount</th><th scope="col">Status</th></tr></thead>
<tbody>
<tr><td>Harbor Freight</td><td class="vd-num">$4,120</td><td><span class="vd-chip vd-ok">Paid</span></td></tr>
<tr><td>Lumen Dental</td><td class="vd-num">$860</td><td><span class="vd-chip vd-warn">Due Friday</span></td></tr>
<tr><td>Okafor Builders</td><td class="vd-num">$12,400</td><td><span class="vd-chip vd-err">Overdue</span></td></tr>
</tbody></table>"""
CARDS = """<div class="vd-cards">
<div class="vd-card"><h3>Harbor Freight</h3><p>$4,120</p><span class="vd-chip vd-ok">Paid</span></div>
<div class="vd-card"><h3>Lumen Dental</h3><p>$860</p><span class="vd-chip vd-warn">Due Friday</span></div>
<div class="vd-card"><h3>Okafor Builders</h3><p>$12,400</p><span class="vd-chip vd-err">Overdue</span></div>
</div>"""
SAME_ROWS = TABLE.replace("Lumen Dental</td><td class=\"vd-num\">$860</td><td><span class=\"vd-chip vd-warn\">Due Friday",
                          "Harbor Freight</td><td class=\"vd-num\">$4,120</td><td><span class=\"vd-chip vd-ok\">Paid").replace(
                          "Okafor Builders</td><td class=\"vd-num\">$12,400</td><td><span class=\"vd-chip vd-err\">Overdue",
                          "Harbor Freight</td><td class=\"vd-num\">$4,120</td><td><span class=\"vd-chip vd-ok\">Paid")
SAME_CARDS = """<div class="vd-cards">""" + """
<div class="vd-card"><h3>Harbor Freight</h3><p>$4,120</p><span class="vd-chip vd-ok">Paid</span></div>""" * 3 + "\n</div>"
assert SAME_ROWS.count("Harbor Freight") == 3

def page(a=TABLE, b=CARDS, css="", top="", caption="Dense table, scans by column.", more=()):
    """The shell with frames A and B filled, then one frame per content in more (C onward); the frames left over are deleted."""
    s = shell
    fills = {
        "title": "How should the invoice list read?", "question": "How should the invoice list read?",
        "axis": "layout", "pass": "pass 1 of 1", "theme-note": "baseline theme",
        "variant-A-label": "Table", "variant-A-caption": caption, "variant-A-content": a,
        "tradeoffs-A": '<li data-n="1">Amounts line up for comparison</li><li data-n="2">Tight on a phone</li>',
        "variant-B-label": "Cards", "variant-B-caption": "One card per customer.", "variant-B-content": b,
        "tradeoffs-B": '<li data-n="1">Reads well on a phone</li><li data-n="2">Fewer rows per screen</li>',
    }
    for letter, content in zip("CDEF", more):
        fills.update({"variant-%s-label" % letter: "Lines", "variant-%s-caption" % letter: "One sentence per customer.", "variant-%s-content" % letter: content,
                      "tradeoffs-%s" % letter: '<li data-n="1">Reads as prose</li><li data-n="2">No column to scan</li>'})
    for k, v in fills.items():
        assert "<!-- SLOT: %s -->" % k in s, k
        s = s.replace("<!-- SLOT: %s -->" % k, v)
    for letter in "CDEF"[len(more):]:
        s = re.sub(r"<!-- FRAME-%s-START -->.*?<!-- FRAME-%s-END -->" % (letter, letter), "", s, flags=re.S)
    if css:
        s = s.replace("</head>", "<style>" + css + "</style>\n</head>")
    if top:
        s = s.replace('<main id="vd-frames">', top + '\n<main id="vd-frames">')
    return s

def write(name, text, age=0):
    path = os.path.join(root, name)
    with open(path, "w", encoding="utf-8") as h:
        h.write(text)
    if age:
        t = time.time() - age
        os.utime(path, (t, t))

IMG = '<img src="missing-chart.png" alt="Revenue by month" width="160" height="90">'
STATES = lambda body: ('<div data-state="populated">' + body + '<ul></ul></div>'
                       '<div data-state="empty"><table class="vd-table"><thead><tr><th scope="col">Customer</th></tr></thead>'
                       '<tbody></tbody></table><p>No invoices yet. <button type="button" class="vd-btn">Import invoices</button></p></div>')
write("f/clean.html", page())
write("f/broken-img.html", page(a=TABLE + IMG, b=CARDS + IMG))
write("f/console.html", page(top="<script>console.error('Ledger sync failed: \\x1b[31mretry\\u202e now')</script>"))
write("f/overflow.html", page(top='<div class="fx-wide">Settlement account 4410 9923 0042</div>', css=".fx-wide{width:560px;padding:8px}"))
write("f/clipped.html", page(
    a=TABLE + '<p class="fx-clip">Northwind Traders International Holdings Limited</p>'
              '<p class="fx-ell" title="Fenwick and Company Wholesale Distribution">Fenwick and Company Wholesale Distribution</p>',
    b=CARDS + '<p class="fx-clip">Northwind Traders International Holdings Limited</p>'
              '<p class="fx-ell" title="Fenwick and Company Wholesale Distribution">Fenwick and Company Wholesale Distribution</p>',
    css=".fx-clip,.fx-ell{width:120px;overflow:hidden;white-space:nowrap}.fx-ell{text-overflow:ellipsis}"))
write("f/contrast.html", page(a=TABLE + '<p class="fx-grey">Last synced 4 minutes ago</p>', b=CARDS + '<p class="fx-grey">Last synced 4 minutes ago</p>',
                              css=".fx-grey{color:#b0b0b0;background:#c8c8c8}"))
write("f/lorem.html", page(a=TABLE + "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>"))
write("f/rows.html", page(a=SAME_ROWS, b=SAME_CARDS))
write("f/identical.html", page(b=TABLE))
write("f/target.html", page(a=TABLE + '<div><button type="button" class="fx-tiny" aria-label="Edit row">E</button><button type="button" class="fx-tiny" aria-label="Delete row">D</button></div>',
                            b=CARDS + '<div><button type="button" class="fx-tiny" aria-label="Edit row">E</button><button type="button" class="fx-tiny" aria-label="Delete row">D</button></div>',
                            css=".fx-tiny{width:16px;height:16px;padding:0;font-size:10px;border:1px solid #555;background:#fff;color:#111}"))
write("f/overlap.html", page(top='<div class="fx-a">Payment received from Harbor Freight</div><div class="fx-b">Refund issued to Lumen Dental</div>',
                             css=".fx-a,.fx-b{padding:0 24px;line-height:20px}.fx-b{margin-top:-14px}"))
write("f/emptylist.html", page(a=STATES(TABLE), b=STATES(CARDS)))
write("f/plain.html", "<!doctype html><html lang=en><title>Plain page</title><p>No shell, no check loader.</p></html>")
# A page's own script cannot answer for the check, post for it, or reach the user's machine through it.
write("f/forge-answer.html", page(top="<script>window.__vdCheck = {status: '\\x1b[2J', recorded: false, error: '\\x1b[31mforged\\u202e\\nreason'};</script>"))
write("f/forge-post.html", page(a=TABLE + "<p>Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>", top="""<script>
(() => {
  const run = new URLSearchParams(location.search).get('_run');
  const real = window.fetch;
  window.fetch = (u, o) => (String(u).endsWith('/_check') && !(o && o.forged) ? new Promise(() => {}) : real(u, o));
  const forged = run ? real('/_check', {method: 'POST', forged: true, headers: {'Content-Type': 'application/json', 'X-Preview-Check': '1'},
    body: JSON.stringify({page: location.pathname.slice(1), run, width: innerWidth, findings: [], dropped: 0})}) : Promise.resolve();
  window.__vdCheck = forged.then(() => ({status: 200, recorded: true}));
})();
</script>"""))
write("f/external.html", page(a=TABLE + '<img src="http://example.com/logo.png" alt="Company logo" width="40" height="40">'))
write("f/download.html", page(top="""<script>addEventListener('load', () => { const a = document.createElement('a');
a.href = URL.createObjectURL(new Blob(['planted by the page'], {type: 'text/plain'})); a.download = 'vd-planted.txt';
document.body.appendChild(a); a.click(); });</script>"""))
write("f/rtc.html", page(top="""<script>const pc = new RTCPeerConnection({iceServers: [{urls: 'stun:127.0.0.1:%s'}]});
pc.createDataChannel('x'); pc.createOffer().then(o => pc.setLocalDescription(o));</script>""" % udp_port))
write("f/font-hang.html", page(top="<script>addEventListener('load', () => { const f = new FontFace('Hang', 'url(http://127.0.0.1:%s/hang.woff2)');"
                               " document.fonts.add(f); f.load().catch(() => {}); });</script>" % hang_port))
write("f/ramp.html", page(a='<h2 class="vd-display">Invoices due this week</h2><p class="vd-t1">Twelve customers owe 48,200 dollars</p>' + TABLE))
write("f/busy.html", page(top="<script>addEventListener('load', () => setTimeout(() => { const t = Date.now(); while (Date.now() - t < 34000); }, 0));</script>"))
write("f/textnodes.html", page(a=TABLE + "<p class=\"fx-row\">" + "".join("Harbor Freight ledger %d. <!---->" % i for i in range(4600)) + "</p>"))
write("f/huge.html", page(a=TABLE + "".join('<p class="fx-row">Ledger line %d: Harbor Freight paid %d dollars on account %d.</p>' % (i, 100 + i, 4000 + i) for i in range(5000))))
write("f/gone.html", page())
# Six frames, a too-wide line in the last three, the last two alike; then the same with no third block and no letter stamped by the shell's script, so only position can name a frame.
FAR = '<p class="fx-far">Settlement account 4410 9923 0042</p> '
late = lambda top="": page(a="<p>Harbor Freight paid $4,120</p>", b="<p>Lumen Dental owes $860 by Friday</p>", css=".fx-far{width:900px}", top=top,
                           more=["<p>Okafor Builders is $12,400 overdue</p>", FAR + "<p>Harbor Freight paid $4,120</p>"]
                                + [FAR + "<p>Lumen Dental owes $860 by Friday</p>"] * 2)
write("f/late-frames.html", late())
write("f/late-gap.html", re.sub(r"<!-- FRAME-C-START -->.*?<!-- FRAME-C-END -->", "", late(
    "<script>addEventListener('load', () => document.querySelectorAll('.vd-frame').forEach(f => f.removeAttribute('data-vd-letter')));</script>"), flags=re.S))

# E7: each limit of a layout pass broken by the smallest page that breaks it, the same five pages with no pass marks, seven frames on a creative pass and under another pass-kind value, a page at every limit, and a name too long on a kind with one option.
MARKS = ' data-vd-pass-kind="layout" data-vd-pass="1"'
def marked(text, marks):
    """The page with these pass marks on its body in place of the shell's."""
    assert text.count(MARKS) == 1, "the shell's body does not carry" + MARKS
    return text.replace(MARKS, marks)

def presets(text, palettes=(), styles=(), types=()):
    """The page with one empty rule per name in the shell's palette, style and type slots, so an option changes nothing but its name."""
    for kind, options in (("palette", palettes), ("style", styles), ("type", types)):
        slot = "/* SLOT: %ss */" % kind
        assert slot in text, "the shell has no slot %ss" % kind
        text = text.replace(slot, "\n".join('html[data-vd-%s="%s"] .vd-content {}' % (kind, o) for o in options))
    return text

LINES = ["<p>Harbor Freight paid $4,120</p>", "<p>Lumen Dental owes $860 by Friday</p>", "<p>Okafor Builders is $12,400 overdue</p>",
         "<p>Northwind Traders paid $2,310</p>", "<p>Fenwick Wholesale owes $640 by Monday</p>", "<p>Calloway Print is $1,980 overdue</p>"]
six = page(a=LINES[0], b=LINES[1], more=LINES[2:])
assert six.count("</main>") == 1
seven = six.replace("</main>", """<section class="vd-frame" id="vd-g" tabindex="-1">
<h2><span class="vd-badge">G</span>Lines</h2> <p class="vd-caption">One sentence per customer.</p>
<div class="vd-content"><p>Brightwater Marina paid $7,050</p></div>
<ul class="vd-tradeoffs"><li data-n="1">Reads as prose</li> <li data-n="2">No column to scan</li></ul>
</section>
</main>""")
# The shell builds palette, style and type only: a fourth switcher is markup an author wrote by hand.
DENSITY = ('<div class="vd-seg vd-switcher" role="group" aria-label="Density" data-vd-switcher="density">'
           '<button type="button" data-vd-option="Compact" aria-pressed="true">Compact</button> '
           '<button type="button" data-vd-option="Roomy" aria-pressed="false">Roomy</button></div>')
limits = {
    "frames": seven,
    "options": presets(page(), ["Neutral", "Sand", "Slate", "Moss", "Berry"]),
    "switchers": presets(page(top=DENSITY), ["Neutral", "Sand"], ["Soft", "Sharp"], ["Sans", "Serif"]),
    "duplicate": presets(page(), ["Neutral", "Berry", "Berry"]),
    "name": presets(page(), ["Cocoa & cream", "Neutral"]),
}
for name, text in limits.items():
    write("f/limit-%s.html" % name, text)
    write("f/limit-%s-unmarked.html" % name, marked(text, ""))
write("f/limit-creative.html", marked(seven, ' data-vd-pass-kind="creative" data-vd-pass="1"'))
write("f/limit-other.html", marked(seven, ' data-vd-pass-kind="data-shape" data-vd-pass="1"'))
LONGEST, TOO_LONG = "Slate_2 - harbor at dusk", "Harbour morning at sunset"
assert len(LONGEST) == 24 and len(TOO_LONG) == 25
write("f/limit-most.html", presets(six, ["Neutral", "Sand", LONGEST, "Moss"], ["Soft", "Sharp", "Round", "Flat"], ["Sans", "Serif", "Mono", "Slab"]))
write("f/limit-lone.html", presets(page(), [TOO_LONG]))

# E8: a palette's seven pairs, each lowered by the smallest rule that lowers it alone, on a page that draws every primitive and on one that draws none.
def ratio(fg, bg):
    """WCAG 2 contrast of two #rrggbb colours, cut to two decimals as a finding prints it."""
    lum = lambda c: sum(k * (v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4)
                        for k, v in zip((0.2126, 0.7152, 0.0722), (int(c[i:i + 2], 16) / 255 for i in (1, 3, 5))))
    lo, hi = sorted((lum(fg), lum(bg)))
    return "%.2f" % (int((hi + 0.05) / (lo + 0.05) * 100) / 100)

def palette(name, light="", dark=None):
    """A palette's rule, and its dark rule when it has a dark set."""
    rule = 'html[data-vd-palette="%s"] .vd-content { %s }' % (name, light)
    return rule if dark is None else rule + '\nhtml[data-vd-palette="%s"][data-vd-scheme="dark"] .vd-content { %s }' % (name, dark)

def painted(text, *rules):
    """The page with these rules in the shell's palette slot."""
    assert "/* SLOT: palettes */" in text, "the shell has no slot palettes"
    return text.replace("/* SLOT: palettes */", "\n".join(rules))

APP = ('<div class="vd-nav"><span class="vd-brand">Ledgerly</span> <a href="#" aria-current="page">Invoices</a> <a href="#">Customers</a></div> '
       '<p class="vd-small">Last synced 4 minutes ago</p> '
       '<div class="vd-tabs"><span class="vd-tab" aria-current="page">Open</span> <span class="vd-tab">Settled</span></div> '
       '<div class="vd-alert">Two invoices are overdue</div> <p><span class="vd-btn vd-primary">New invoice</span></p> ')
ROWS = ('<div class="vd-row"><span>Harbor Freight</span> <span class="vd-chip vd-ok">Paid</span></div> '
        '<div class="vd-row"><span>Lumen Dental</span> <span class="vd-chip vd-warn">Due Friday</span></div> '
        '<div class="vd-row"><span>Okafor Builders</span> <span class="vd-chip vd-err">Overdue</span></div>')
drawn = page(a=APP + CARDS, b=APP + ROWS)
# No primitive in a frame; the chip above the frames is the page's own, outside what a palette paints.
bare = page(a=LINES[0], b=LINES[1], top='<p><span class="vd-chip vd-info">Beta</span></p>')
NEUTRAL = palette("Neutral")
DUSK_LIGHT, DUSK_DARK = "--vd-primary: #4f46e5;", "--vd-paper: #101014; --vd-surface: #1a1a20; --vd-ink: #f4f4f5; --vd-ink-soft: %s; --vd-primary: #a5b4fc; --vd-on-primary: #101014;"
assert ratio("#5f5f68", "#101014") == "3.00" and float(ratio("#a1a1aa", "#101014")) > 4.5
write("f/soft-dark.html", painted(drawn, NEUTRAL, palette("Dusk", DUSK_LIGHT, DUSK_DARK % "#5f5f68")))
write("f/soft-dark-fixed.html", painted(drawn, NEUTRAL, palette("Dusk", DUSK_LIGHT, DUSK_DARK % "#a1a1aa")))
write("f/soft-dark-lone.html", painted(drawn, palette("Dusk", DUSK_LIGHT, DUSK_DARK % "#5f5f68")))
# Each rule sets a value and has no dark rule, so its palette is light only (the chip one restates the shell's line colour for that); body text is lowered with the surface darkened, so the alert's ink still reads.
LOW = {
    "body": ("--vd-ink: #8c8c8c; --vd-surface: #000000;", ""),
    "soft": ("--vd-ink-soft: #9a9a9a;", ""),
    "button": ("--vd-on-primary: #9db8f2;", ""),
    "chip": ("--vd-line: #e4e4e7;", 'html[data-vd-palette="Low"] .vd-chip.vd-warn { color: #b8a13c; }'),
    "alert": ("--vd-surface: #777777;", ""),
    "nav": ("--vd-nav-ink-soft: rgba(255, 255, 255, .3);", ""),
    "primary": ("--vd-primary: #7aa7f5; --vd-on-primary: #10131a;", ""),
}
for name, (tokens, css) in LOW.items():
    write("f/pair-%s.html" % name, painted(drawn, NEUTRAL, palette("Low", tokens)).replace("</head>", "<style>" + css + "</style>\n</head>"))
write("f/pairs-bare.html", painted(bare, NEUTRAL, palette("Low", "--vd-ink: #8c8c8c; --vd-ink-soft: oklch(0.7 0 0); --vd-primary: #7aa7f5; --vd-on-primary: #9db8f2;"
                                                                " --vd-nav-ink: #6a6a6a; --vd-nav-ink-soft: rgba(255, 255, 255, .3);"))
      .replace("</head>", '<style>html[data-vd-palette="Low"] .vd-chip.vd-info { color: #7f9fd8; }</style>\n</head>'))
# A tint an author lays on the soft text: Low's soft ink reads on its paper (5.15:1) and not on that paper under the tint, #c4c8cc.
assert float(ratio("#6a6a6a", "#f5faff")) > 4.5 and ratio("#6a6a6a", "#c4c8cc") == "3.21"
write("f/tinted.html", painted(drawn, NEUTRAL, palette("Low", "--vd-ink-soft: #6a6a6a; --vd-paper: #f5faff;"))
      .replace("</head>", "<style>.vd-small{background-color:rgba(0,0,0,.2)}</style>\n</head>"))
# Daylight sets a value and has no dark rule: dark by hand would lay its ink on the shell's dark paper, a look the shell never shows. Neutral's empty rule keeps the shell's dark set, where the soft ink this page hard-codes does not read.
assert float(ratio("#57575e", "#ffffff")) > 4.5 and ratio("#57575e", "#1b1b1f") == "2.39"
write("f/light-only.html", painted(drawn, palette("Daylight", "--vd-ink: #1f2937;"), NEUTRAL).replace("</head>", "<style>.vd-small{color:#57575e}</style>\n</head>"))
# Four palettes that pass, the second one and the dark scheme authored on the html tag; as a ledger pair that renders the same, so E6 compares the checked page with a load nothing switched.
BERRY = palette("Berry", "--vd-paper: #fff5f8; --vd-surface: #fde7ee; --vd-ink: #3b0a1f; --vd-ink-soft: #7a2e4a; --vd-line: #f3c4d3; --vd-primary: #be185d;"
                         " --vd-on-primary: #ffffff; --vd-nav-bg: #831843; --vd-nav-ink: #fff5f8; --vd-nav-ink-soft: rgba(255, 245, 248, .8);",
                "--vd-paper: #1f0a14; --vd-surface: #2b0f1c; --vd-ink: #fde7ee; --vd-ink-soft: #f0a6c0; --vd-line: #5c1f38; --vd-primary: #f472b6;"
                " --vd-on-primary: #1f0a14; --vd-nav-bg: #4a0d28; --vd-nav-ink: #fde7ee; --vd-nav-ink-soft: rgba(253, 231, 238, .75);")
MOSS = palette("Moss", "--vd-paper: #f7faf5; --vd-surface: #e9f2e4; --vd-ink: #14230f; --vd-ink-soft: #40573a; --vd-line: #c9dcc0; --vd-primary: #3f6212;"
                       " --vd-on-primary: #ffffff; --vd-nav-bg: #1a2e14; --vd-nav-ink: #f7faf5; --vd-nav-ink-soft: rgba(247, 250, 245, .8);",
               "--vd-paper: #10180d; --vd-surface: #1a2615; --vd-ink: #e9f2e4; --vd-ink-soft: #a9c29f; --vd-line: #2f4426; --vd-primary: #a3e635;"
               " --vd-on-primary: #10180d; --vd-nav-bg: #223319; --vd-nav-ink: #e9f2e4; --vd-nav-ink-soft: rgba(233, 242, 228, .75);")
SLATE = palette("Slate", "--vd-paper: #f8fafc; --vd-surface: #e2e8f0; --vd-ink: #0f172a; --vd-ink-soft: #475569; --vd-primary: #1d4ed8; --vd-nav-bg: #0f172a;",
                "--vd-paper: #0f172a; --vd-surface: #1e293b; --vd-ink: #f1f5f9; --vd-ink-soft: #cbd5e1; --vd-primary: #93c5fd; --vd-on-primary: #0f172a; --vd-nav-bg: #1e293b;")
HTML_TAG = '<html lang="en" dir="ltr" data-vd-dir="ltr" data-vd-scheme="light">'
four = painted(page(a=APP + TABLE, b=APP + ROWS), NEUTRAL, BERRY, MOSS, SLATE)
assert four.count(HTML_TAG) == 1, "the shell's html tag is not " + HTML_TAG
four = four.replace(HTML_TAG, HTML_TAG[:-len('"light">')] + '"dark" data-vd-palette="Berry">')
write("2026-11-10-looks-a.html", four, age=500)
write("2026-11-10-looks-b.html", four.replace("</body>", "<!-- second draft -->\n</body>"), age=400)

# E6: a ledger with a renders-the-same pair (b differs from a by a comment only) and a changed current.html.
write("2026-11-12-a.html", page(), age=300)
write("2026-11-12-b.html", page().replace("</body>", "<!-- second draft -->\n</body>"), age=200)
changed = page(caption="Dense table; amounts right-aligned for comparison.")
write("2026-11-13-c.html", changed, age=10)
write("current.html", changed)
EOF
# One to six frames: shell-controls.test.sh's pages, so the pages a person walks are the pages checked here.
bash "$here/shell-controls.test.sh" --emit "$D/f" || bad "frame-count fixtures" "shell-controls.test.sh --emit did not write them"

port="$(free_port)"
PREVIEW_PORT="$port" bash "$P" --docroot "$D" --port "$port" >/dev/null 2>&1 || bad "server start" "preview.sh did not start serve.py"
B="http://127.0.0.1:$port"

# ---- routes ----------------------------------------------------------------------
# The check runs in an isolated world the runner injects: no route serves it to a page or takes its findings.
expect "check script not served" 404 "$B/_check.js"
expect "axe not served" 404 "$B/_axe.js"
# Nothing of the check reaches the server by a bare path a page's <base href> could send elsewhere: no fetch, no script tag, no loader.
CHECK_JS="$here/../../skills/visual-decisions/assets/check.js"
grep -nE "fetch\(|\.src = '/|/_check\.js|/_axe\.js" "$CHECK_JS" && bad "check.js reaches the server" "see above" || ok
grep -n "_check.js\|get('_check')" "$SHELL_HTML" && bad "the shell still carries the check loader" "see above" || ok
expect "checks before a run" 200 "$B/_checks?page=f/clean.html"
[ "$(fields checked)" = "[false]" ] && ok || bad "checks before a run" "want checked false: $(cat "$T/resp")"
expect "checks, unknown page" 404 "$B/_checks?page=f/nope.html"
expect "checks, non-local Host" 403 -H "Host: example.com" "$B/_checks?page=f/clean.html"
expect "checks, a NUL in the page" 404 "$B/_checks?page=f/a%00b.html"
[ "$(fields error)" = '["no such page in the docroot"]' ] && ok || bad "checks, a NUL: JSON answer" "$(head -c 200 "$T/resp")"
expect "checks, a control character" 404 "$B/_checks?page=f/a%01b.html"

post() { curl -s -o "$T/resp" -w '%{http_code}' --max-time 5 -X POST -H 'Content-Type: application/json' "$@" "$B/_check"; }
BODY='{"page":"f/clean.html","run":"r1","width":375,"findings":[]}'
[ "$(post -H 'X-Preview-Check: 1' -d "$BODY")" = 404 ] && ok || bad "no route takes findings" "POST /_check answered $(cat "$T/resp")"
[ -z "$(find "$D" -path '*/.checks/*' -name '*.json' 2>/dev/null)" ] && ok || bad "a post wrote a record" "$(find "$D" -path '*/.checks/*')"
# /_checks counts the records preview-check.sh writes: one written here as it writes them.
expect "checks dir" 200 "$B/_checks?page=f/clean.html"
dir="$(fields dir | tr -d '"[]')"
mkdir -p "$D/$dir"
python3 - "$D/f/clean.html" "$D/$dir/375.json" <<'EOF'
import hashlib, json, sys
digest = hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest()
json.dump({"page": "f/clean.html", "page_sha256": digest, "run": "r1", "width": 375, "ts": "2026-11-13T00:00:00Z",
           "findings": [{"check": "E4", "selector": "p", "text": "lorem ipsum", "detail": "x"}], "dropped": 0}, open(sys.argv[2], "w"))
EOF
expect "checks after a record" 200 "$B/_checks?page=f/clean.html"
[ "$(fields checked findings)" = "[true, 1]" ] && ok || bad "checks after a record" "want checked, 1 finding: $(cat "$T/resp")"
expect "the record is never served" 404 "$B/$dir/375.json"
expect "the folder is never served" 404 "$B/.checks/"
cp "$D/f/clean.html" "$T/clean.bak"; printf '\n<!-- edited -->\n' >> "$D/f/clean.html"
expect "checks after an edit" 200 "$B/_checks?page=f/clean.html"
[ "$(fields checked stale)" = "[false, true]" ] && ok || bad "an edited page reads unchecked" "$(cat "$T/resp")"
cp "$T/clean.bak" "$D/f/clean.html"

# ---- arguments -------------------------------------------------------------------
bash "$R" --docroot "$D" --widths abc >/dev/null 2>&1; [ $? = 2 ] && ok || bad "bad --widths" "want exit 2"
bash "$R" --docroot "$D" --page ../x.html >/dev/null 2>&1; [ $? = 2 ] && ok || bad "--page outside" "want exit 2"
bash "$R" --docroot "$D" --page f/missing.html >/dev/null 2>&1; [ $? = 2 ] && ok || bad "--page missing" "want exit 2"
out="$(PREVIEW_BROWSER="$T/no-such-browser" bash "$R" --docroot "$D" --page f/clean.html 2>"$T/err")"; rc=$?
[ "$rc" = 4 ] && [ -z "$out" ] && [ "$(wc -l < "$T/err" | tr -d ' ')" = 1 ] && ok || bad "no browser" "want exit 4, one stderr line, no stdout; got $rc: $out $(cat "$T/err")"

# ---- the browser half ------------------------------------------------------------
# run <page> [args]: prints findings to $T/out, stderr to $T/err, sets $rc and $secs.
run() { local s=$SECONDS; bash "$R" --docroot "$D" --page "$@" >"$T/out" 2>"$T/err"; rc=$?; secs=$((SECONDS - s)); }
run f/clean.html
if [ "$rc" = 4 ]; then
  echo "SKIP: no Chromium-family browser here — the render checks are not exercised ($(cat "$T/err"))"
  summary
  [ "$fail" -eq 0 ]
  exit
fi

# got: the findings as sorted "check|text|widths" lines (advisories and not_reported lines apart), exit 1 on bad output.
got() { python3 - "$T/out" <<'EOF'
import json, sys
lines = [json.loads(l) for l in open(sys.argv[1], encoding="utf-8") if l.strip()]
assert lines and "summary" in lines[-1], "no summary line"
out = sorted({"%s|%s|%s" % (f["check"], f["text"], ",".join(map(str, f["widths"]))) for f in lines[:-1] if "check" in f and not f.get("advisory")})
print("\n".join(out))
EOF
}
# want <name> <exit> [check|text|widths ...]
want() {
  local name=$1 code=$2 have expected; shift 2
  have="$(got)" || { bad "$name" "unreadable output: $(head -c 300 "$T/out") $(cat "$T/err")"; return; }
  expected="$(printf '%s\n' "$@" | sed '/^$/d' | sort -u)"
  [ "$rc" = "$code" ] && [ "$have" = "$expected" ] && ok || bad "$name" "want exit $code and [$(echo $expected)], got $rc and [$(echo $have)] $(head -c 300 "$T/err")"
}
# names <name> <check> <text> <pattern>: some finding with that check and text has a detail matching the pattern.
names() {
  local have
  have="$(python3 -c '
import json, sys
for l in open(sys.argv[1], encoding="utf-8"):
    f = json.loads(l) if l.strip() else {}
    if [f.get("check"), f.get("text")] == sys.argv[2:4]: print(f["detail"])' "$T/out" "$2" "$3" 2>&1)"
  printf '%s\n' "$have" | grep -q -- "$4" && ok || bad "$1" "want a $2 \"$3\" detail matching \"$4\", got $rc: ${have//$'\n'/ | } $(head -c 300 "$T/err")"
}
ALL=375,768,1280

want "clean shell page" 0
[ "$secs" -lt 30 ] && ok || bad "three widths in time" "took $secs s"
python3 - "$T/out" "$D" <<'EOF' 2>&1 | grep . && bad "clean run: summary and shots" "see above" || ok
import json, struct, sys
s = [json.loads(l) for l in open(sys.argv[1])][-1]["summary"]
assert s["findings"] == 0 and s["widths"] == [375, 768, 1280], s
for w, path in zip((375, 768, 1280), s["shots"]):
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n" and struct.unpack(">I", data[16:20])[0] == w, (path, data[:24])
assert s["previous"] is None, s
EOF
grep -q '"check": "E6"' "$T/out" && bad "no E6 outside the ledger" "a page under f/ got an E6 line" || ok
curl -s -o "$T/resp" "$B/_checks?page=f/clean.html"
[ "$(fields checked findings)" = "[true, 0]" ] && ok || bad "badge data after a clean run" "$(cat "$T/resp")"

run f/broken-img.html;  want "E1 broken image" 1 "E1|resource failed to load|$ALL"
run f/console.html;     want "E1 console error" 1 "E1|console error|$ALL"
LC_ALL=C grep -q "$(printf '\033')" "$T/out" && bad "output escapes ESC" "a raw ESC byte reached the output" || ok
grep -qF "$(printf '\342\200\256')" "$T/out" && bad "output escapes U+202E" "a raw right-to-left override reached the output" || ok
python3 -c '
import json,sys
f=[json.loads(l) for l in open(sys.argv[1])][0]
assert "\x1b[31mretry\u202e now" in f["detail"], f' "$T/out" 2>/dev/null && ok || bad "escaped detail decodes" "$(head -c 300 "$T/out")"
run f/overflow.html;    want "E2 overflow at 375 only" 1 "E2|page scrolls sideways|375"
run f/clipped.html;     want "E2 clipped text (ellipsis with a title passes)" 1 "E2|text clipped|$ALL"
run f/target.html;      want "E2 small targets" 1 "E2|target smaller than 24 px|$ALL"
run f/overlap.html;     want "E2 overlapping text" 1 "E2|text overlaps|$ALL"
run f/contrast.html;    want "E3 low contrast (axe)" 1 "E3|color-contrast|$ALL"
run f/lorem.html;       want "E4 lorem ipsum" 1 "E4|lorem ipsum|$ALL"
run f/rows.html;        want "E4 three identical rows" 1 "E4|identical rows|$ALL"
run f/emptylist.html;   want "E4 empty list (a data-state=empty table passes)" 1 "E4|empty list|$ALL"
run f/identical.html;   want "E5 identical variants" 1 "E5|variants identical|$ALL"
grep -q 'advisory' "$T/out" && ok || bad "E5 says advisory" "$(head -c 300 "$T/out")"
run f/plain.html;       want "a page not built from the shell is checked too" 0
run f/ramp.html;        want "the shell's display line above a t1 line is not an overlap" 0
for n in 1 2 3 4 5 6; do run "f/layout-$n.html" --widths 375; want "one to six frames no sideways scroll at 375 ($n)" 0; done
run f/late-frames.html --widths 375
names "E2 names variant D" E2 "variant scrolls sideways" "^variant D is "
names "E2 names variant E" E2 "variant scrolls sideways" "^variant E is "
names "E2 names variant F" E2 "variant scrolls sideways" "^variant F is "
names "E5 names variants E and F" E5 "variants identical" "variants E and F have "
run f/late-gap.html --widths 375
names "E2 names the third of five frames variant C, its id vd-d and no letter stamped on it" E2 "variant scrolls sideways" "^variant C is "

# E7, the limits of a layout or creative pass: one finding per broken limit, naming the rule and the number found; none on a page with no pass-kind mark.
run f/limit-frames.html;    want "seven frames reported" 1 "E7|more than 6 frames|$ALL"
names "seven frames reported: the number found" E7 "more than 6 frames" "^7 frames; "
run f/limit-options.html;   want "five options reported" 1 "E7|more than 4 options in a switcher|$ALL"
names "five options reported: the switcher and the number found" E7 "more than 4 options in a switcher" "^the palette switcher has 5 options; "
run f/limit-switchers.html; want "four switchers reported" 1 "E7|more than 3 switchers|$ALL"
names "four switchers reported: the number found and the kinds" E7 "more than 3 switchers" "^4 switchers (palette, style, type, density); "
run f/limit-duplicate.html; want "duplicate option name reported" 1 "E7|option name repeated|$ALL"
names "duplicate option name reported: the name and the number found" E7 "option name repeated" '^the palette switcher has 2 options named "Berry"; '
run f/limit-name.html;      want "refused option name reported" 1 "E7|option name the server refuses|$ALL"
names "refused option name reported: the name and the number found" E7 "option name the server refuses" '^the palette switcher has 1 name outside .*: "Cocoa & cream"; '
python3 -c 'import json,sys;s=json.loads(open(sys.argv[1]).read().splitlines()[-1])["summary"];assert s["findings"]==1,s' "$T/out" 2>/dev/null \
  && ok || bad "refused option name reported: once, though it is the active option and so on the html tag too" "$(tail -n 1 "$T/out")"
run f/limit-creative.html --widths 375; want "creative pass with seven frames reported" 1 "E7|more than 6 frames|375"
names "creative pass with seven frames reported: the number found" E7 "more than 6 frames" "^7 frames; "
for p in frames options switchers duplicate name; do run "f/limit-$p-unmarked.html" --widths 375; want "unmarked page clean for all five limits ($p)" 0; done
run f/limit-other.html --widths 375; want "seven frames under a pass-kind value that is neither layout nor creative draw none" 0
run f/limit-most.html;      want "six frames and three four-option switchers clean, one name 24 characters of every kind a name may hold" 0
run f/limit-lone.html --widths 375; want "a 25-character name on a kind with one option, which has no switcher, reported" 1 "E7|option name the server refuses|375"
names "a 25-character name on a kind with one option: where it is applied" E7 "option name the server refuses" '^the palette applied with no switcher has 1 name outside .*: "Harbour morning at sunset"; '

# E8, each palette's contrast in light and in dark: one finding per pair under 4.5:1, naming the palette, the scheme, the ratio and what was measured, from the first width's load only.
# count <name> <n>: the summary counts n findings.
count() {
  python3 -c 'import json,sys;s=json.loads(open(sys.argv[1]).read().splitlines()[-1])["summary"];assert s["findings"]==int(sys.argv[2]),s' "$T/out" "$2" 2>/dev/null \
    && ok || bad "$1" "want $2 finding(s) in the summary: $(tail -n 1 "$T/out")"
}
run f/soft-dark.html;       want "dark soft text under 4.5 reported with palette name" 1 "E8|soft text under 4.5:1|375"
names "dark soft text under 4.5 reported with palette name: the scheme, the ratio and the element" E8 "soft text under 4.5:1" \
  '^palette "Dusk", dark: soft text is 3\.00:1 (#5f5f68 on #101014), on p "Last synced 4 minutes ago"$'
count "dark soft text under 4.5 reported with palette name: once, though the page loads at three widths and passes in light" 1
run f/soft-dark-fixed.html; want "dark soft text under 4.5 reported with palette name: none on the same page with the value fixed" 0
run f/soft-dark-lone.html --widths 375; want "a palette that is its kind's one option, which has no switcher, is checked in dark too" 1 "E8|soft text under 4.5:1|375"
names "a palette that is its kind's one option: the palette and the scheme" E8 "soft text under 4.5:1" '^palette "Dusk", dark: soft text is 3\.00:1 '
while IFS='|' read -r fixture pair measured <&3; do
  run "f/pair-$fixture.html" --widths 375; want "each of seven pairs reported ($pair)" 1 "E8|$pair under 4.5:1|375"
  names "each of seven pairs reported ($pair): the palette, the scheme, the ratio and the element a frame draws" E8 "$pair under 4.5:1" "^palette \"Low\", light: $pair is $measured"
  count "each of seven pairs reported ($pair): no other pair, and no dark finding for a palette with no dark set" 1
done 3<<'EOF'
body|body text|3\.36:1 (#8c8c8c on #ffffff), on div "Ledgerly Invoices
soft|soft text|2\.81:1 (#9a9a9a on #ffffff), on p "Last synced 4 minutes ago"$
button|button text|2\.60:1 (#9db8f2 on #2563eb), on span "New invoice"$
chip|chip text|2\.38:1 (#b8a13c on #fef9c3), on span "Due Friday"$
alert|alert text|3\.95:1 (#18181b on #777777), on div "Two invoices are overdue"$
nav|nav text|2\.70:1 (#5d5d5f on #18181b), on a "Customers"$
primary|primary used as text|2\.42:1 (#7aa7f5 on #ffffff), on span "Open"$
EOF
run f/pairs-bare.html --widths 375
want "a pair no frame draws is measured on a probe" 1 "E8|body text under 4.5:1|375" "E8|soft text under 4.5:1|375" "E8|button text under 4.5:1|375" "E8|chip text under 4.5:1|375" \
  "E8|alert text under 4.5:1|375" "E8|nav text under 4.5:1|375" "E8|primary used as text under 4.5:1|375"
count "a pair no frame draws is measured on a probe: one finding a pair" 7
while IFS='|' read -r pair measured <&3; do
  names "a pair no frame draws is measured on a probe ($pair)" E8 "$pair under 4.5:1" "^palette \"Low\", light: $pair is $measured, on a probe: no frame draws it\$"
done 3<<'EOF'
soft text|2\.6[0-9]:1 (#9[def]9[def]9[def] on #ffffff)
button text|1\.21:1 (#9db8f2 on #7aa7f5)
chip text|2\.19:1 (#7f9fd8 on #dbeafe)
alert text|3\.22:1 (#8c8c8c on #fafafa)
nav text|2\.70:1 (#5d5d5f on #18181b)
primary used as text|2\.42:1 (#7aa7f5 on #ffffff)
EOF
run f/tinted.html --widths 375; want "a see-through background is laid over what is behind it" 1 "E8|soft text under 4.5:1|375"
names "a see-through background is laid over what is behind it: the ratio and the colours" E8 "soft text under 4.5:1" '^palette "Low", light: soft text is 3\.21:1 (#6a6a6a on #c4c8cc), on p '
run f/light-only.html --widths 375; want "a palette with no dark set is checked in light only, one with an empty rule in dark too" 1 "E8|soft text under 4.5:1|375"
names "a palette with an empty rule is checked in dark: the palette and the scheme" E8 "soft text under 4.5:1" '^palette "Neutral", dark: soft text is 2\.39:1 (#57575e on #1b1b1f), on p '
count "a palette with no dark set is checked in light only: no finding under it" 1

# A page's own script: a global it sets is not the check's answer, a post it makes is not a record.
run f/forge-answer.html; want "a page-set __vdCheck is not the answer" 0
cat "$T/out" "$T/err" | LC_ALL=C grep -q "$(printf '\033')" && bad "forged answer escaped" "a raw ESC reached the output: $(cat "$T/err")" || ok
run f/forge-post.html;  want "a forged empty post does not hide lorem ipsum" 1 "E4|lorem ipsum|$ALL"

# Nothing leaves the machine: a proxy in the environment is not used, a download is refused, WebRTC sends no UDP.
proxy_log="$T/proxy.log"; pport="$(free_port)"
python3 -c '
import socket, sys, threading
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(16)
def one(c):
    with c:
        open(sys.argv[2], "ab").write(c.recv(4096).split(b"\r\n")[0] + b"\n")
        c.sendall(b"HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
while True:
    threading.Thread(target=one, args=(s.accept()[0],), daemon=True).start()' "$pport" "$proxy_log" &
pids="$pids $!"
sleep 0.3
s0=$SECONDS; env -u XDG_CURRENT_DESKTOP -u DESKTOP_SESSION -u GNOME_DESKTOP_SESSION_ID -u KDE_FULL_SESSION \
  http_proxy="http://127.0.0.1:$pport" https_proxy="http://127.0.0.1:$pport" all_proxy="http://127.0.0.1:$pport" \
  bash "$R" --docroot "$D" --page f/external.html --widths 375 >"$T/out" 2>"$T/err"; rc=$?
want "an off-machine image reads as a failed load" 1 "E1|resource failed to load|375"
grep -q 'example.com' "$proxy_log" 2>/dev/null && bad "a proxy in the environment" "the page's request reached it: $(cat "$proxy_log")" || ok
mkdir -p "$T/home"
HOME="$T/home" XDG_CONFIG_HOME="$T/home/.config" bash "$R" --docroot "$D" --page f/download.html --widths 375 >"$T/out" 2>"$T/err"; rc=$?
sleep 1
[ -z "$(find "$T/home" -name 'vd-planted*' 2>/dev/null)" ] && ok || bad "a page-started download" "it was saved: $(find "$T/home" -name 'vd-planted*')"
python3 -c '
import socket, sys
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.bind(("127.0.0.1", int(sys.argv[1]))); s.settimeout(8)
n = 0
try:
    while True:
        s.recvfrom(2048); n += 1
except socket.timeout:
    pass
open(sys.argv[2], "w").write(str(n))' "$udp_port" "$T/udp.count" &
upid=$!
sleep 0.3
run f/rtc.html --widths 375
wait "$upid"
[ "$(cat "$T/udp.count")" = 0 ] && ok || bad "WebRTC" "$(cat "$T/udp.count") UDP packet(s) reached a STUN address the page named"

# A web font the page starts loading at load, and that never arrives, does not hold the check past 3 s.
python3 -c 'import socket,sys,time;s=socket.socket();s.bind(("127.0.0.1",int(sys.argv[1])));s.listen(64);time.sleep(120)' "$hang_port" &
pids="$pids $!"
sleep 0.3
run f/font-hang.html --widths 375; want "a hung font" 0
[ "$secs" -lt 15 ] && ok || bad "a hung font: time" "took $secs s"

# Few elements, many text nodes: E4's own cap is said too.
run f/textnodes.html --widths 375
python3 -c 'import json,sys;s=json.loads(open(sys.argv[1]).read().splitlines()[-1])["summary"];assert s.get("capped",0)>0,s' "$T/out" 2>/dev/null \
  && ok || bad "a page of 4600 text nodes says it was capped" "got $rc: $(tail -n 1 "$T/out") $(head -c 300 "$T/err")"
# A huge page is walked to a cap, and says so.
run f/huge.html --widths 375
python3 -c 'import json,sys;s=json.loads(open(sys.argv[1]).read().splitlines()[-1])["summary"];assert s.get("capped",0)>0 and s["widths"]==[375],s' "$T/out" 2>/dev/null \
  && ok || bad "a huge page says it was capped" "got $rc: $(tail -n 1 "$T/out") $(head -c 300 "$T/err")"

# The sandbox switched off is said.
PREVIEW_BROWSER_NO_SANDBOX=1 bash "$R" --docroot "$D" --page f/clean.html --widths 375 >"$T/out" 2>"$T/err"; rc=$?
[ "$rc" = 0 ] && grep -q 'sandbox is off' "$T/err" && ok || bad "sandbox off is said" "got $rc: $(cat "$T/err")"

# A page that keeps the browser busy: the width reads not reported, what was collected still prints, as JSON.
run f/busy.html --widths 375
python3 - "$T/out" <<'EOF' 2>&1 | grep . && bad "a busy page" "got $rc: $(head -c 400 "$T/out") $(cat "$T/err")" || ok
import json, sys
lines = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
assert lines and lines[-1]["summary"]["not_reported"] == [375], lines
assert any(l.get("not_reported") == 375 and isinstance(l.get("reason"), str) for l in lines[:-1]), lines
EOF
[ "$rc" = 5 ] && ok || bad "a busy page: exit" "want 5, got $rc"
# A caller's timeout: the browser closes and its profile goes.
timeout -s TERM 3 bash "$R" --docroot "$D" --page f/busy.html --widths 375 >/dev/null 2>&1
sleep 1
pgrep -f -- "--user-data-dir=$T/tmp" >/dev/null && bad "TERM: browser" "$(pgrep -af -- "--user-data-dir=$T/tmp")" || ok
[ -z "$(ls -A "$T/tmp")" ] && ok || bad "TERM: profile" "left behind: $(ls -A "$T/tmp")"

# A page deleted since its check: its folder goes at the next run.
run f/gone.html --widths 375
gone="$(python3 -c 'import json,sys,os;print(os.path.dirname(json.loads(open(sys.argv[1]).read().splitlines()[-1])["summary"]["shots"][0]))' "$T/out")"
rm "$D/f/gone.html"
[ -d "$gone" ] && run f/clean.html --widths 375
[ -n "$gone" ] && [ ! -e "$gone" ] && ok || bad "a deleted page's folder is pruned" "$gone is still there"

# An open tab learns of a run: the server streams "checked" with the page.
curl -sN --max-time 6 "$B/events" >"$T/sse" 2>/dev/null &
cpid=$!
sleep 0.5
run f/clean.html --widths 375
wait "$cpid"
grep -q '^event: checked' "$T/sse" && grep -q '^data: f/clean.html' "$T/sse" && ok || bad "checked event" "$(cat "$T/sse")"
run f/clean.html --widths 375
[ "$rc" = 0 ] && [ "$(python3 -c 'import json,sys;print(json.loads(open(sys.argv[1]).read().splitlines()[-1])["summary"]["widths"])' "$T/out")" = "[375]" ] && ok || bad "--widths 375" "got $rc: $(tail -n 1 "$T/out")"

# E6: current.html against the newest ledger pass that differs from it (c is its own copy, so b).
e6() { python3 -c '
import json,sys
a=[json.loads(l) for l in open(sys.argv[1]) if l.strip()]
e=[f for f in a[:-1] if f["check"]=="E6"]
assert len(e)==1 and e[0]["advisory"] is True, a
print(e[0]["text"]+"|"+a[-1]["summary"]["previous"])' "$T/out"; }
run current.html
[ "$rc" = 0 ] && [ "$(e6 2>&1)" = "changed since the previous pass|2026-11-12-b.html" ] && ok || bad "E6 changed" "want exit 0 and a change against b, got $rc: $(e6 2>&1) $(cat "$T/err")"
grep -q '"detail": "[0-9.]*% of pixels' "$T/out" && ok || bad "E6 says how much" "$(grep E6 "$T/out")"
run 2026-11-12-b.html
[ "$rc" = 0 ] && [ "$(e6 2>&1)" = "no visible change since the previous pass|2026-11-12-a.html" ] && ok || bad "E6 unchanged" "want no visible change against a, got $rc: $(e6 2>&1) $(cat "$T/err")"
# E8 on a ledger pair that renders the same: E6 holds the screenshot taken after every palette was switched through against a load of the older pass, where nothing was switched.
run 2026-11-10-looks-b.html --widths 375; want "four passing palettes clean" 0
[ "$(e6 2>&1)" = "no visible change since the previous pass|2026-11-10-looks-a.html" ] && ok \
  || bad "four passing palettes clean: the look after the run is the look the page loaded with" "want no visible change against the pass it copies, got $rc: $(e6 2>&1) $(cat "$T/err")"

# Nothing left running: no browser on this run's temp profiles, no profile left behind.
pgrep -f -- "--user-data-dir=$T/tmp" >/dev/null && bad "no browser left" "$(pgrep -af -- "--user-data-dir=$T/tmp")" || ok
[ -z "$(ls -A "$T/tmp")" ] && ok || bad "temp profiles removed" "$(ls -A "$T/tmp")"

# No server: the script starts one through preview.sh and says so.
mkdir -p "$T/auto"; cp "$D/f/clean.html" "$T/auto/page.html"
port2="$(free_port)"
out="$(PREVIEW_PORT="$port2" bash "$R" --docroot "$T/auto" --page page.html 2>"$T/err")"; rc=$?
[ "$rc" = 0 ] && grep -q "started the preview server" "$T/err" && ok || bad "auto-start" "want exit 0 and a started line, got $rc: $(cat "$T/err")"
bash "$P" --docroot "$T/auto" --stop >/dev/null 2>&1
# A port held by something else: preview.sh cannot start, the script exits 3.
port3="$(free_port)"
python3 -m http.server "$port3" --bind 127.0.0.1 -d "$T/auto" >/dev/null 2>&1 &
pids="$pids $!"
for _ in $(seq 1 50); do curl -s -o /dev/null "http://127.0.0.1:$port3/" && break; sleep 0.1; done
PREVIEW_PORT="$port3" bash "$R" --docroot "$T/auto" --page page.html >/dev/null 2>"$T/err"; rc=$?
[ "$rc" = 3 ] && ok || bad "busy port" "want exit 3, got $rc: $(cat "$T/err")"

summary
[ "$fail" -eq 0 ]
