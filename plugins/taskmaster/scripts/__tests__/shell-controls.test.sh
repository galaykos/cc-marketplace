#!/usr/bin/env bash
# Drives the shipped shell live through serve.py (no ?static=1, so Pick and Note are there) in a headless Chromium over its DevTools pipe, with real clicks and key presses, on pages of one to six frames: sideways scroll and frames per row at 375 and 1280, a jump link, Pick and Note per frame under its position letter, a pick's stored row and Picked state with a middle frame removed, number keys, Flip mode, title buttons that wrap, and the title's buttons reading Focus, Pick, Note on screen and by Tab on one row, on a wrapped row and around a picked frame's long label, each at least 24 px wide and tall at 375, 768 and 1280 on a page with no look and on one whose picked frame's label wraps them into rows; on pages marked pass 1, 2 and 12 and one with no pass mark, the pass number a pick and a note store and Picked only while the newest stored pick is on the page's own pass; on pages that author palette, style and type presets, the switcher row (its own line, order, labels, the first option active, a kind with one option or none, a creative pass, a page with no pass mark, Tab, Enter and Space, no reload, one such page loaded with ?static=1) and what a look restyles: every frame's content and nav bar, never the header, a title, a caption or a tradeoff list; and what a tab keeps of palette, style, type, Scheme and Direction: across a reload and the reload a pass written over the page causes, a kept option the next pass lacks, a second tab, another page path, another decision title, ?static=1, sessionStorage that throws; a look authored on the html tag, and one naming an option the page lacks; a kind's one option applied with no switcher shown; at 375 on such a page, the Look control that stands in for the switcher row (one control, closed on load, opened and closed by click and by Enter with focus kept, every switcher drawn and stacked once open, at 430 too, an option chosen inside it, a switcher too wide for the screen wrapping its options onto further lines, at 320 and 375 with four 24-character names per kind, each option in the window and at least 24 px tall, the last one clicked) and the closed header's share of the viewport on six frames with the version picker, the feedback controls and the check badge showing; no Look control and one line of switchers at 768 and 1280; a frame reached by a number key or a jump link landing with its title row below the sticky header, at 375 by 800 and at 1280 by 500; a header over 55% of the window's height that stops sticking and has no room kept for it (320 by 480 with Look open, a frame reached by a number key shown in the window), one at most half that still sticks (375 by 800, 1280 by 800), its state at 55% and 45%, a pixel past each and between the two over six animation frames, Look opened and closed across both, and Look opened on a scrolled page staying in the window with focus; on a themed project's page (palettes Project, which has no dark rule, and Neutral), Project listed first and active in each switcher with no Theme control in the header, the Scheme toggle disabled with its note beside it under Project and working under Neutral, a dark scheme chosen under Neutral held light while Project is active, and the palette and scheme a pick stores as its context theme (baseline on a page with no palette) and the scheme a pick and a note store as its own field (light while a palette with no dark set holds a chosen dark); where a palette's dark rule stands (the top level, directly inside @media screen, inside @media print, @supports, a narrower @media screen or a block nested in one, and an empty first rule before a filled one) as the Scheme toggle, the values painted on screen and under print media, and the toggle against the rule the render check reads; the palette, style and type names a pick and a note store (no key for a kind the page has no option for, the one option of a kind whose switcher is hidden, none for a name serve.py refuses), the picked frame's button as its text, the accessible name the browser computes and aria-pressed, under the recorded look and under another palette, style or type, the second pick that Pick with current look stores, a look change against the pick said in a status region (once when it stops matching, again when it matches, never with nothing picked or on a page that opens unmatched) with focus left on the switcher, and at 375 a picked frame's label that fits its title row alone, and one wider than that row; under emulated print media on the dark scheme, a frame's paper, ink, nav bar, primary button and info alert in the active palette's light set, for a palette with a dark rule and for Neutral; against a second server of its own that answers a post with 400, a refused pick's message drawn in words on the line under its Pick button (the frame not marked Picked, one post sent, the live region reading the same words, the button's computed description, nothing drawn under print media, gone once the next pick from that button is stored), a refused note's on Send note's row from a frame's Note button and from Point & note (none in a box opened afterwards), at 375 the title's buttons at full width above the message with no sideways scroll, the message of a pick sent after that server stopped, and a refusal in that server's words (a 507's sentence with its status, a 500 with an HTML body, a sentence holding markup drawn as text, one cut at 200 characters, JSON with no sentence); with serve.py's own lock held, a pick and a note that get no answer (the message, the frame not marked Picked, Send note usable and its text kept, the browser asked for a 10 s limit, which the case shortens in the page). --emit DIR only writes those pages into DIR.
# Misses: Firefox and Safari; touch and what a screen reader says beyond the Pick button's computed name (a status region's text is read, never speech: after a refused pick and a look change against the pick; a look change against a pick whose frame the page lacks); a refusal serve.py itself sends (every status here, 400 to 507, is a stub's answer), a 200 whose body is no JSON, a post serve.py stores after the page gave up on it (the page has said Not recorded by then), a limit kept by anything but the browser's AbortSignal.timeout or, with that deleted, a timer, an answer whose body stalls after its status, the reload of rows after a stored post (it has no limit), and the words another browser gives a failed request; a refusal message on the dark scheme, in RTL, in a zoomed frame, under a Picked label or title buttons that take two rows, wider than its title row, or in the note box at 375, and its contrast; a message left beside one control when another's post is stored; Stacked mode, the width presets; print on paper (page breaks, dropped backgrounds, any frame but those the print case reads); a note's stored row beyond its pass number and look; a pick stored before rows carried a look, shown on a page that has one; a look changed while a post is on its way; the title's button order, and a title button's size, in RTL, in a zoomed frame and with a Replay button; the 24 px width floor at work (no label the shell draws is that narrow); a picked frame's label at any width but 375 and 2560 (at 768 and 1280 its size alone is read); an earlier round's pick on a page rewritten in place to its next pass (it is posted under the pass 2 page's path instead); a pass mark that is no whole number; how a wrapped title looks (walked by eye); the width at which Look takes over (375, 430, 768 and 1280 are driven, nothing between) and a resize across it; Space on Look; how Look, its caret and its open groups look, wrapped options' lines and fill included (walked by eye); a switcher between 601 and 767 px wide, where options do not wrap and four 24-character names overflow the page; the header's height with Look open, at any width but 375 (at 320 Look takes a line of its own), or closed on a page whose question wraps or that shows a Diffs toggle, a State bar or the Scheme note (each adds a line; a themed page of six frames is not measured); the Scheme note at 375, and one too long for its line; a State bar's place in the header; a frame reached in Stacked mode, by a link to its id from another page, or with Look open at any size but 320 by 480; a header made tall by zoom (window sizes are driven), by a State bar or by the Scheme note; the page following a control in a browser that does not focus a clicked button; a phone's own URL bar (window heights are driven); of a look, all but a frame's paper, ink, nav bar, one button's corner and font (so spacing, shadow, soft ink, line and surface, and primary off the print case), and Moss's dark set; a dark rule whose attribute selectors are written in the other order (read as no dark set); a palette on the html tag of a page of another pass kind; a context theme past the 30 characters serve.py keeps; an option name that holds a double quote or a backslash; aria-pressed once the attribute is set by hand after load; a shell rule keyed on a look attribute being there, whatever its value; a tab duplicated or opened from the page, which the browser hands a copy of the kept look; a kept Scheme or Direction that is neither of its two values; a kept option the page lacks while its html tag authors another; a choice made under ?static=1; storage refused by a browser setting (the case makes window.sessionStorage throw); what paints before the script applies a kept look; the reload an event-stream announcement causes (a page overwritten here is refused its stream and reloads on its own one-second fetch). With no Chromium-family browser it prints SKIP and exits 0, or exits 1 under PREVIEW_REQUIRE_BROWSER=1.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
SHELL_HTML="$here/../../skills/visual-decisions/assets/shell.html"
SERVE="$here/../../skills/visual-decisions/assets/serve.py"
summary() { echo "shell-controls tests: $1 passed, $2 failed"; }
skip() { echo "SKIP: $1"; summary 0 0; [ "${PREVIEW_REQUIRE_BROWSER:-}" = 1 ] && exit 1; exit 0; }

emit=""
if [ "${1:-}" = --emit ]; then
  [ -n "${2:-}" ] || { echo "usage: shell-controls.test.sh [--emit DIR]" >&2; exit 2; }
  emit=$2
fi
command -v python3 >/dev/null 2>&1 || skip "python3 not found"  # skip: nothing here runs without python3; PREVIEW_REQUIRE_BROWSER=1 exits 1 instead

# build_pages <dir>: layout-1.html to layout-6.html (that many frames), layout-gap.html (six, the third block deleted), pass-2.html and pass-12.html (three, the body marked pass 2 and pass 12), pass-none.html (three, no pass marks), look-5.html (five, with palettes Neutral, Berry and Moss, styles Soft and Sharp, types Sans and Serif), look-6.html (six, the same presets), look-long.html (three, four palettes whose names do not fit a 375 px screen side by side), look-24.html (three, four names of 24 characters per kind), look-one.html (three, one palette, one style, one type), look-harbour.html and look-wordy.html (three, one option per kind: a picked frame's label fits a phone's title row alone but not beside Focus and Note, and is wider than that row), look-refused.html (three, palettes R&D, a name serve.py refuses, and Neutral), look-25.html (three, palettes of a 25-character name, refused for its length alone, and Neutral), look-creative.html (three, a creative pass with two palettes), look-other.html (three, no pass marks, look-5's presets and one frame's own radius), look-authored.html (look-5 with Berry, Sharp, Serif, the dark scheme and dir rtl on its html tag), look-authored-gone.html (look-5 with a palette it lacks on its html tag), kept.html, fewer.html and retitled.html (each look-5, for the runner to overwrite with its -next.html: look-5 on pass 2, the same without Moss, look-5 under another title), look-said.html (look-5, picked on by the look-change cases alone), themed.html (three, a themed project's page: palettes Project, which has no dark set, and Neutral; styles and types Project and Neutral), scheme-top.html, scheme-screen.html, scheme-print.html, scheme-supports.html, scheme-screen-wide.html and scheme-nested.html (three, one palette Day whose dark rule stands where the name says) and scheme-first-empty.html (three, a palette Twice declared twice, an empty rule before one that sets a value), from the shipped shell.
build_pages() {
  python3 - "$SHELL_HTML" "$1" <<'EOF'
import os, re, sys
shell = open(sys.argv[1], encoding="utf-8").read()
out = sys.argv[2]

TABLE = """<table class="vd-table">
<thead><tr><th scope="col">Customer</th> <th scope="col" class="vd-num">Amount</th> <th scope="col">Status</th></tr></thead>
<tbody>
<tr><td>Harbor Freight</td> <td class="vd-num">$4,120</td> <td><span class="vd-chip vd-ok">Paid</span></td></tr>
<tr><td>Lumen Dental</td> <td class="vd-num">$860</td> <td><span class="vd-chip vd-warn">Due Friday</span></td></tr>
<tr><td>Okafor Builders</td> <td class="vd-num">$12,400</td> <td><span class="vd-chip vd-err">Overdue</span></td></tr>
</tbody></table>"""
CARDS = """<div class="vd-cards">
<div class="vd-card"><h3>Harbor Freight</h3> <p>$4,120</p> <span class="vd-chip vd-ok">Paid</span></div>
<div class="vd-card"><h3>Lumen Dental</h3> <p>$860</p> <span class="vd-chip vd-warn">Due Friday</span></div>
<div class="vd-card"><h3>Okafor Builders</h3> <p>$12,400</p> <span class="vd-chip vd-err">Overdue</span></div>
</div>"""
SPLIT = """<div class="vd-split">
<div class="vd-list">
<div class="vd-row" aria-current="true"><span>Harbor Freight</span> <span class="vd-num">$4,120</span></div>
<div class="vd-row"><span>Lumen Dental</span> <span class="vd-num">$860</span></div>
<div class="vd-row"><span>Okafor Builders</span> <span class="vd-num">$12,400</span></div>
</div>
<div class="vd-detail"><h3>Harbor Freight</h3> <p>$4,120</p> <span class="vd-chip vd-ok">Paid</span></div>
</div>"""
SUMMARY = """<div class="vd-kpis">
<div class="vd-kpi"><b>$17,380</b> <span>Billed</span></div>
<div class="vd-kpi"><b>$12,400</b> <span>Overdue</span></div>
<div class="vd-kpi"><b>$860</b> <span>Due Friday</span></div>
</div>
<div class="vd-row"><span>Harbor Freight</span> <span class="vd-chip vd-ok">Paid</span></div>
<div class="vd-row"><span>Lumen Dental</span> <span class="vd-chip vd-warn">Due Friday</span></div>
<div class="vd-row"><span>Okafor Builders</span> <span class="vd-chip vd-err">Overdue</span></div>"""
GROUPED = """<h3>Overdue</h3>
<div class="vd-row"><span>Okafor Builders</span> <span class="vd-num">$12,400</span></div>
<h3>Due Friday</h3>
<div class="vd-row"><span>Lumen Dental</span> <span class="vd-num">$860</span></div>
<h3>Paid</h3>
<div class="vd-row"><span>Harbor Freight</span> <span class="vd-num">$4,120</span></div>"""
ACCORDION = """<div class="vd-accordion">
<div class="vd-acc-item open"><div class="vd-acc-head">Okafor Builders</div> <div class="vd-acc-body">$12,400 <span class="vd-chip vd-err">Overdue</span></div></div>
<div class="vd-acc-item"><div class="vd-acc-head">Lumen Dental</div> <div class="vd-acc-body">$860 <span class="vd-chip vd-warn">Due Friday</span></div></div>
<div class="vd-acc-item"><div class="vd-acc-head">Harbor Freight</div> <div class="vd-acc-body">$4,120 <span class="vd-chip vd-ok">Paid</span></div></div>
</div>"""
# label, caption, content, two tradeoffs; frame A takes the first. Every content holds the same three invoices, a space between its elements: preview-check.sh's E5 compares the variants' words, and joins the text of touching elements into one.
VARIANTS = [
    ("Table", "Dense table, scans by column.", TABLE, "Amounts line up for comparison", "Tight on a phone"),
    ("Cards", "One card per customer.", CARDS, "Reads well on a phone", "Fewer rows per screen"),
    # No-break spaces: this label cannot fold, so at 375 the title's three buttons cannot all sit beside it.
    ("Split&nbsp;list&nbsp;and&nbsp;detail", "Pick a customer, read the invoice beside it.", SPLIT, "The invoice opens without leaving the list", "Two columns fold into one on a phone"),
    ("Summary first", "Totals above the list.", SUMMARY, "What is owed reads before any row", "The list starts lower on the screen"),
    ("Grouped by status", "Overdue first, paid last.", GROUPED, "What needs chasing is on top", "A customer is harder to find by name"),
    ("Accordion", "One line per customer, opened for the amount.", ACCORDION, "Most customers per screen", "An amount takes a click"),
]


def page(n, drop=""):
    """The shell with its first n frames filled (A onward) and the rest deleted; a letter in drop is filled, then its frame deleted too."""
    s = shell
    fills = {"title": "How should the invoice list read?", "question": "How should the invoice list read?",
             "axis": "layout", "pass": "pass 1 of 1", "theme-note": "baseline theme"}
    for letter, (label, caption, content, pro, con) in zip("ABCDEF"[:n], VARIANTS):
        fills.update({"variant-%s-label" % letter: label, "variant-%s-caption" % letter: caption, "variant-%s-content" % letter: content,
                      "tradeoffs-%s" % letter: '<li data-n="1">%s</li><li data-n="2">%s</li>' % (pro, con)})
    for k, v in fills.items():
        assert "<!-- SLOT: %s -->" % k in s, "the shell has no slot %s" % k
        s = s.replace("<!-- SLOT: %s -->" % k, v)
    for letter in "ABCDEF"[n:] + drop:
        # C to F ship inside markers; B has none, so its section goes by id.
        block = (r"\s*<!-- FRAME-%s-START -->.*?<!-- FRAME-%s-END -->" % (letter, letter) if letter in "CDEF"
                 else r'\s*<section class="vd-frame" id="vd-%s".*?</section>' % letter.lower())
        s, found = re.subn(block, "", s, flags=re.S)
        assert found == 1, "the shell has no frame block %s" % letter
    return s


MARKS = ' data-vd-pass-kind="layout" data-vd-pass="1"'
PASS_2 = ' data-vd-pass-kind="layout" data-vd-pass="2"'
ROOT = '<html lang="en" dir="ltr" data-vd-dir="ltr" data-vd-scheme="light">'


def marked(text, marks):
    """The page with these pass marks on its body in place of the shell's."""
    assert MARKS in text, "the shell's body does not carry%s" % MARKS
    return text.replace(MARKS, marks)


def rooted(text, tag):
    """The page with this start tag in place of the shell's html tag."""
    assert ROOT in text, "the shell's html tag is not %s" % ROOT
    return text.replace(ROOT, tag)


def write(name, text):
    with open(os.path.join(out, name), "w", encoding="utf-8") as h:
        h.write(text)


# Opens every frame of a look page: the nav bar a palette repaints and a button whose corners a style turns.
APP_BAR = """<div class="vd-nav"><span class="vd-brand">Ledgerly</span> <a href="#" aria-current="page">Invoices</a> <a href="#">Customers</a></div>
<div class="vd-toolbar"><span class="vd-input">Search invoices</span> <span class="vd-btn vd-primary">New invoice</span></div>
"""
# The runner's NEUTRAL, BERRY, BERRY_DARK, MOSS and SERIF hold these values as the browser reports them.
NEUTRAL = 'html[data-vd-palette="Neutral"] .vd-content {}'
BERRY = """html[data-vd-palette="Berry"] .vd-content { --vd-paper: #fff5f8; --vd-surface: #fde7ee; --vd-ink: #3b0a1f; --vd-ink-soft: #7a2e4a; --vd-line: #f3c4d3;
  --vd-primary: #be185d; --vd-on-primary: #ffffff; --vd-nav-bg: #831843; --vd-nav-ink: #fff5f8; --vd-nav-ink-soft: rgba(255, 245, 248, .8); }
html[data-vd-palette="Berry"][data-vd-scheme="dark"] .vd-content { --vd-paper: #1f0a14; --vd-surface: #2b0f1c; --vd-ink: #fde7ee; --vd-ink-soft: #f0a6c0; --vd-line: #5c1f38;
  --vd-primary: #f472b6; --vd-on-primary: #1f0a14; --vd-nav-bg: #4a0d28; --vd-nav-ink: #fde7ee; --vd-nav-ink-soft: rgba(253, 231, 238, .75); }"""
MOSS = """html[data-vd-palette="Moss"] .vd-content { --vd-paper: #f7faf5; --vd-surface: #e9f2e4; --vd-ink: #14230f; --vd-ink-soft: #40573a; --vd-line: #c9dcc0;
  --vd-primary: #3f6212; --vd-on-primary: #ffffff; --vd-nav-bg: #1a2e14; --vd-nav-ink: #f7faf5; --vd-nav-ink-soft: rgba(247, 250, 245, .8); }
html[data-vd-palette="Moss"][data-vd-scheme="dark"] .vd-content { --vd-paper: #10180d; --vd-surface: #1a2615; --vd-ink: #e9f2e4; --vd-ink-soft: #a9c29f; --vd-line: #2f4426;
  --vd-primary: #a3e635; --vd-on-primary: #10180d; --vd-nav-bg: #223319; --vd-nav-ink: #e9f2e4; --vd-nav-ink-soft: rgba(233, 242, 228, .75); }"""
SOFT = 'html[data-vd-style="Soft"] .vd-content { --vd-radius: 12px; --vd-space: 8px; --vd-shadow: 0 2px 6px rgba(0, 0, 0, .08), 0 8px 24px rgba(0, 0, 0, .08); }'
SHARP = 'html[data-vd-style="Sharp"] .vd-content { --vd-radius: 0; --vd-space: 6px; --vd-shadow: none; }'
SANS = 'html[data-vd-type="Sans"] .vd-content {}'
SERIF = 'html[data-vd-type="Serif"] .vd-content { --vd-font: Georgia, "Times New Roman", serif; }'
# A project's own theme as its author declares it: the three colours it defines and no dark rule, its radius and spacing, its font. The runner's PROJECT holds the palette as the browser reports it.
PROJECT = 'html[data-vd-palette="Project"] .vd-content { --vd-primary: #0f766e; --vd-surface: #f0fdfa; --vd-ink: #134e4a; }'
PROJECT_STYLE = 'html[data-vd-style="Project"] .vd-content { --vd-radius: 4px; --vd-space: 6px; }'
PROJECT_TYPE = 'html[data-vd-type="Project"] .vd-content { --vd-font: Verdana, Geneva, sans-serif; }'


def look(n, palettes=(), styles=(), types=(), css=""):
    """page(n) with the app bar opening every frame, these rules in the shell's palette, style and type slots, and css closing its custom block."""
    s = page(n).replace('<div class="vd-content">', '<div class="vd-content">' + APP_BAR)
    for slot, rules in (("palettes", palettes), ("styles", styles), ("types", types)):
        assert "/* SLOT: %s */" % slot in s, "the shell has no slot %s" % slot
        s = s.replace("/* SLOT: %s */" % slot, "\n".join(rules))
    assert s.count("</style>\n</head>") == 1, "the shell's custom block does not close the head"
    return s.replace("</style>\n</head>", css + "\n</style>\n</head>")


for n in range(1, 7):
    write("layout-%d.html" % n, page(n))
write("layout-gap.html", page(6, drop="C"))
write("pass-2.html", marked(page(3), PASS_2))
write("pass-none.html", marked(page(3), ""))
write("pass-12.html", marked(page(3), ' data-vd-pass-kind="layout" data-vd-pass="12"'))
look_5 = look(5, [NEUTRAL, BERRY, MOSS], [SOFT, SHARP], [SANS, SERIF])
write("look-5.html", look_5)
write("look-6.html", look(6, [NEUTRAL, BERRY, MOSS], [SOFT, SHARP], [SANS, SERIF]))
write("look-long.html", look(3, ['html[data-vd-palette="%s"] .vd-content {}' % name
                                 for name in ("Harbour morning", "Berry preserve", "Moss and stone", "Paper lantern")]))
# Four names of 24 characters, the longest a name may be, per kind: words that can fold at a space, at a hyphen or nowhere, and the widest letters.
NAMES_24 = {"palette": ("Harbour morning at dawns", "MMMMMMMMMMMMMMMMMMMMMMMM", "Moss-and-stone-and-water", "Paper_lantern_at_evening"),
            "style": ("Soft corners wide gutter", "Sharp corners tight rows", "WWWWWWWWWWWWWWWWWWWWWWWW", "Raised_cards_soft_shadow"),
            "type": ("Humanist sans serif text", "Geometric-sans-for-heads", "Old style serif for body", "000000000000000000000000")}
assert all(len(name) == 24 for names in NAMES_24.values() for name in names), "an option name of look-24.html is not 24 characters"
write("look-24.html", look(3, *(['html[data-vd-%s="%s"] .vd-content {}' % (kind, name) for name in NAMES_24[kind]] for kind in ("palette", "style", "type"))))
write("look-one.html", look(3, [BERRY], [SHARP], [SERIF]))
write("look-harbour.html", look(3, ['html[data-vd-palette="Harbour morning"] .vd-content {}'], [SOFT], [SERIF]))
write("look-wordy.html", look(3, ['html[data-vd-palette="Harbour morning at dawn"] .vd-content {}'],
                              ['html[data-vd-style="Comfortable and rounded"] .vd-content {}'], ['html[data-vd-type="Humanist sans serif"] .vd-content {}']))
write("look-refused.html", look(3, ['html[data-vd-palette="R&D"] .vd-content {}', NEUTRAL]))
# The runner's NAME_25 is this name: one character past the 24 serve.py stores, each a character it allows.
NAME_25 = "Paper lantern at evenings"
assert len(NAME_25) == 25, "the long palette name of look-25.html is not 25 characters"
write("look-25.html", look(3, ['html[data-vd-palette="%s"] .vd-content {}' % NAME_25, NEUTRAL]))
write("look-creative.html", marked(look(3, [NEUTRAL, BERRY]), ' data-vd-pass-kind="creative" data-vd-pass="1"'))
write("look-other.html", marked(look(3, [NEUTRAL, BERRY, MOSS], [SOFT, SHARP], [SANS, SERIF], css="#vd-b .vd-content{--vd-radius:0}"), ""))
# Only dir is turned: data-vd-dir is the shell's own mirror, which an author does not write.
write("look-authored.html", rooted(look_5, '<html lang="en" dir="rtl" data-vd-dir="ltr" data-vd-scheme="dark"'
                                           ' data-vd-palette="Berry" data-vd-style="Sharp" data-vd-type="Serif">'))
write("look-authored-gone.html", rooted(look_5, ROOT[:-1] + ' data-vd-palette="Plum">'))
# Written before serve.py starts: a page that appeared under it would be announced as changed, and reload the tab that has it open.
for name in ("kept", "fewer", "retitled", "look-said"):
    write(name + ".html", look_5)
write("kept-next.html", marked(look_5, PASS_2))
write("fewer-next.html", marked(look(5, [NEUTRAL, BERRY], [SOFT, SHARP], [SANS, SERIF]), PASS_2))
assert look_5.count("<title>How should the invoice list read?</title>") == 1, "the page's title is not its question"
write("retitled-next.html", look_5.replace("<title>How should the invoice list read?</title>", "<title>Which invoice list ships?</title>"))
themed = look(3, [PROJECT, NEUTRAL], [PROJECT_STYLE, 'html[data-vd-style="Neutral"] .vd-content {}'], [PROJECT_TYPE, 'html[data-vd-type="Neutral"] .vd-content {}'])
assert themed.count("baseline theme") == 1, "the page's theme note is not the one page() fills"
write("themed.html", themed.replace("baseline theme", "project theme"))
# The runner's DAY and DAY_DARK hold these values as the browser reports them. Named scheme-*: preview-check.test.sh emits these pages into the folder of its own dark-* fixtures.
DAY = 'html[data-vd-palette="Day"] .vd-content { --vd-paper: #fffbeb; --vd-ink: #1f2937; }'
DAY_DARK = 'html[data-vd-palette="Day"][data-vd-scheme="dark"] .vd-content { --vd-paper: #111827; --vd-ink: #f9fafb; }'
for name, block in (("top", "%s"), ("screen", "@media screen { %s }"), ("print", "@media print { %s }"), ("supports", "@supports (display: grid) { %s }"),
                    ("screen-wide", "@media screen and (min-width: 1px) { %s }"), ("nested", "@media screen { @supports (display: grid) { %s } }")):
    write("scheme-%s.html" % name, look(3, [DAY, block % DAY_DARK]))
write("scheme-first-empty.html", look(3, ['html[data-vd-palette="Twice"] .vd-content {}', 'html[data-vd-palette="Twice"] .vd-content { --vd-surface: #fef3c7; }']))
EOF
}

if [ -n "$emit" ]; then
  mkdir -p "$emit" && build_pages "$emit"
  exit
fi

. "$here/../find-browser.sh"
browser="$(find_browser)" || skip "no Chromium-family browser here (PREVIEW_BROWSER, PATH, Playwright's cache): the shell's controls are not exercised"  # skip: a machine without a browser cannot run any case; PREVIEW_REQUIRE_BROWSER=1 exits 1 instead
sandbox=""; { [ "$(id -u)" = 0 ] || [ "${PREVIEW_BROWSER_NO_SANDBOX:-}" = 1 ]; } && sandbox="--no-sandbox"

T="$(mktemp -d)"
srv=""
cleanup() {
  [ -n "$srv" ] && { kill "$srv" 2>/dev/null; wait "$srv" 2>/dev/null; }
  rm -rf "$T"
}
trap cleanup EXIT
mkdir -p "$T/docroot" "$T/tmp"
export TMPDIR="$T/tmp"

build_pages "$T/docroot" 2>"$T/build.err" || { echo "FAIL fixture pages: not built from the shipped shell: $(tail -n 1 "$T/build.err")"; summary 0 1; exit 1; }
# Picks as serve.py stored them before rows carried a pass (no "pass" key): B on the page with no pass mark, A on a page marked pass 1.
printf '{"id": "0a1b2c3%s", "ts": "2026-11-01T09:00:00Z", "page": "%s", "kind": "pick", "variant": "%s", "anchor": null, "text": "", "context": {"viewport": {"w": 1280, "h": 800}, "theme": "baseline light", "states": {}, "console": []}, "status": "open", "reply": "", "handed_out": false}\n' \
  d pass-none.html B e layout-2.html A >"$T/docroot/.feedback.jsonl"
port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
python3 "$SERVE" --docroot "$T/docroot" --port "$port" >"$T/serve.log" 2>&1 &
srv=$!
for _ in $(seq 1 50); do
  grep -q '^Serving ' "$T/serve.log" 2>/dev/null && break
  kill -0 "$srv" 2>/dev/null || break
  sleep 0.1
done
grep -q '^Serving ' "$T/serve.log" 2>/dev/null || { echo "FAIL server start: serve.py did not start: $(tail -n 1 "$T/serve.log")"; summary 0 1; exit 1; }

python3 - "http://127.0.0.1:$port/" "$browser" "$sandbox" "$T/docroot" <<'PY'
import contextlib, fcntl, json, os, select, shutil, signal, subprocess, sys, tempfile, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, quote
from urllib.request import ProxyHandler, Request, build_opener

base, browser, sandbox, docroot = sys.argv[1:5]
opener = build_opener(ProxyHandler({}))
passed = failed = 0


def case(name, ok, detail=""):
    """One case: counted when ok, else one FAIL line."""
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print("FAIL %s: %s" % (name, detail), flush=True)


class Browser:
    """Chrome over --remote-debugging-pipe, as scripts/preview-check.sh drives it: NUL-terminated JSON on fds 3 (to it) and 4 (from it)."""

    def __init__(self):
        self.profile = tempfile.mkdtemp(prefix="vd-controls-")
        to_r, self.to_w = os.pipe()
        self.from_r, from_w = os.pipe()
        a, b = fcntl.fcntl(to_r, fcntl.F_DUPFD_CLOEXEC, 10), fcntl.fcntl(from_w, fcntl.F_DUPFD_CLOEXEC, 10)
        os.close(to_r)
        os.close(from_w)
        args = [browser, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run", "--no-default-browser-check",
                "--disable-background-networking", "--disable-extensions", "--disable-sync", "--no-pings",
                "--proxy-server=http://127.0.0.1:9", "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1",
                "--user-data-dir=" + self.profile, "--remote-debugging-pipe"] + ([sandbox] if sandbox else []) + ["about:blank"]
        self.proc = subprocess.Popen(["bash", "-c", 'exec "$@" 3<&%d 4>&%d %d<&- %d>&-' % (a, b, a, b), "bash"] + args,
                                     pass_fds=(a, b), stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL, start_new_session=True)
        os.close(a)
        os.close(b)
        self.buf, self.next_id, self.loaded, self.session, self.target = b"", 0, False, None, None

    def tab(self):
        """A fresh tab, the last one closed: a page left in the back/forward cache keeps its /events stream open, and past six of those nothing loads."""
        if self.target:
            self.call("Target.closeTarget", {"targetId": self.target}, tab=False)
        self.target = self.call("Target.createTarget", {"url": "about:blank"}, tab=False)["targetId"]
        self.session = self.call("Target.attachToTarget", {"targetId": self.target, "flatten": True}, tab=False)["sessionId"]
        self.call("Page.enable")

    def recv(self, until):
        while b"\0" not in self.buf:
            wait = until - time.monotonic()
            if wait <= 0:
                raise TimeoutError("the browser did not answer in time")
            if select.select([self.from_r], [], [], wait)[0]:
                chunk = os.read(self.from_r, 1 << 20)
                if not chunk:
                    raise EOFError("the browser exited")
                self.buf += chunk
        raw, _, self.buf = self.buf.partition(b"\0")
        msg = json.loads(raw)
        if msg.get("method") == "Page.loadEventFired":
            self.loaded = True
        return msg

    def call(self, method, params=None, timeout=15, tab=True):
        self.next_id += 1
        msg = {"id": self.next_id, "method": method, "params": params or {}}
        if tab and self.session:
            msg["sessionId"] = self.session
        os.write(self.to_w, json.dumps(msg).encode("utf-8") + b"\0")
        until = time.monotonic() + timeout
        while True:
            got = self.recv(until)
            if got.get("id") == self.next_id:
                if "error" in got:
                    raise RuntimeError("%s: %s" % (method, got["error"].get("message")))
                return got.get("result", {})

    def close(self):
        try:
            self.call("Browser.close", timeout=3, tab=False)
        except Exception:
            pass
        try:
            self.proc.wait(5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except OSError:
                pass
            self.proc.wait()
        shutil.rmtree(self.profile, ignore_errors=True)


def js(expression):
    """The value of a JavaScript expression in the page; a promise is awaited."""
    res = cdp.call("Runtime.evaluate", {"expression": expression, "awaitPromise": True, "returnByValue": True})
    if res.get("exceptionDetails"):
        raise RuntimeError("page script threw: %s" % json.dumps(res["exceptionDetails"])[:300])
    return res.get("result", {}).get("value")


def wait(condition, ms=5000):
    """True once the JavaScript condition holds, False when it still does not after ms."""
    return js("new Promise(done => { const t0 = Date.now(); (function poll() { if (%s) done(true); else if (Date.now() - t0 > %d) done(false);"
              " else setTimeout(poll, 20); })(); })" % (condition, ms))


def settle(static=False):
    """Wait for the tab's next load and, on a live page, for its Pick and Note buttons and its check badge."""
    until = time.monotonic() + 15
    while not cdp.loaded:
        cdp.recv(until)
    cdp.call("Page.bringToFront")
    if not static and not wait("!document.getElementById('vd-fb').hidden && !document.getElementById('vd-check-badge').hidden"):
        raise RuntimeError("%s: the feedback controls or the check badge never appeared" % js("location.pathname"))


def open_page(name, width, static=False, fresh=True, stream=True, height=800, at=None):
    """Load a docroot page at this viewport width (and height), in a fresh tab or, with fresh=False, in the tab already open: live, returning once its Pick and Note buttons and its check badge are in place, or with ?static=1, once it has loaded. stream=False refuses the fresh tab's pages their event stream. at is another server's address to load it from in place of serve.py's."""
    if fresh:
        cdp.tab()
        if not stream:
            cdp.call("Network.enable")
            cdp.call("Network.setBlockedURLs", {"urls": ["*/events"]})
    cdp.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
    cdp.loaded = False
    nav = cdp.call("Page.navigate", {"url": (at or base) + quote(name) + ("?static=1" if static else "")})
    if nav.get("errorText"):
        raise RuntimeError("could not load %s: %s" % (name, nav["errorText"]))
    settle(static)


def reload():
    """Reload the open tab, as the browser's own reload button does."""
    cdp.loaded = False
    cdp.call("Page.reload")
    settle()


def next_pass(name):
    """Write a page's -next.html over it, as a pass is written over the one before, and wait for the reload the open page then does by itself. The page has to be open with stream=False: serve.py has eight event streams and holds a closed tab's until a write to it fails, so which pages here would get one varies by run."""
    # With no stream a page fetches itself each second and reloads once two fetches differ, so its first has to be in before the file changes.
    if not wait("performance.getEntriesByType('resource').some(e => e.initiatorType === 'fetch' && e.name === location.href)"):
        raise RuntimeError("%s never fetched itself: was it opened with stream=False?" % name)
    cdp.loaded = False
    # Moved into place whole: a fetch that met a half-written page would reload into it.
    part = os.path.join(docroot, name + ".part")
    shutil.copyfile(os.path.join(docroot, name.replace(".html", "-next.html")), part)
    os.replace(part, os.path.join(docroot, name))
    settle()


def style(selector, prop):
    """One computed style property of the first element matching the selector."""
    return js("getComputedStyle(document.querySelector(%s)).getPropertyValue(%s)" % (json.dumps(selector), json.dumps(prop)))


def click(selector):
    """A real mouse click on the centre of the first element matching the selector; it must be the topmost element there."""
    # The sticky header reacts to the scroll a frame or more later, so a covered target is re-measured for up to 1 s before failing.
    deadline = time.time() + 1.0
    while True:
        at = js("(() => { const el = document.querySelector(%s); if (!el) return null; el.scrollIntoView({ block: 'center', inline: 'center' });"
                " const r = el.getBoundingClientRect(), x = r.left + r.width / 2, y = r.top + r.height / 2, hit = document.elementFromPoint(x, y);"
                " return { x, y, hit: !!hit && el.contains(hit) }; })()" % json.dumps(selector))
        if not at or at["hit"] or time.time() >= deadline:
            break
        time.sleep(0.05)
    if not at or not at["hit"]:
        raise RuntimeError("cannot click %s: %s" % (selector, "something covers it" if at else "no such element"))
    for kind in ("mousePressed", "mouseReleased"):
        cdp.call("Input.dispatchMouseEvent", {"type": kind, "x": at["x"], "y": at["y"], "button": "left", "clickCount": 1})


NAMED_KEYS = {"Tab": ("Tab", 9, ""), "Enter": ("Enter", 13, "\r"), "Space": (" ", 32, " ")}


def key(char):
    """A real press of one letter or digit key, or of Tab, Enter or Space by name, sent to whatever has focus."""
    if char in NAMED_KEYS:
        value, vk, text = NAMED_KEYS[char]
        ev = {"key": value, "code": char, "windowsVirtualKeyCode": vk}
    else:
        ev, text = {"key": char, "code": ("Digit" if char.isdigit() else "Key") + char.upper(), "windowsVirtualKeyCode": ord(char.upper())}, char
    cdp.call("Input.dispatchKeyEvent", dict(ev, type="keyDown", text=text))
    cdp.call("Input.dispatchKeyEvent", dict(ev, type="keyUp"))


def rows(name):
    """The feedback rows serve.py holds for a page."""
    with opener.open(base + "_feedback?page=" + quote(name), timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))["rows"]


def seed_pick(name, letter, number):
    """Store a pick of this frame on this pass number for a page through serve.py, the way the page's own post does."""
    body = json.dumps({"page": name, "kind": "pick", "variant": letter, "pass": number}).encode("utf-8")
    with opener.open(Request(base + "_feedback", body, {"Content-Type": "application/json", "X-Preview-Feedback": "1"}), timeout=5) as resp:
        resp.read()


# Per frame: its box, title box and badge box (the badge sits on the title's first line) in page coordinates, its badge, and its title buttons by accessible name.
FRAMES = """(() => {
  const box = el => { const r = el.getBoundingClientRect(); return { left: r.left, top: r.top + scrollY, right: r.right, bottom: r.bottom + scrollY, width: r.width }; };
  return Array.from(document.querySelectorAll('.vd-frame')).map(f => ({
    box: box(f), title: box(f.querySelector('h2')), line: box(f.querySelector('.vd-badge')), badge: f.querySelector('.vd-badge').textContent,
    buttons: Array.from(f.querySelectorAll('h2 button')).map(b => ({
      name: b.getAttribute('aria-label') || b.textContent, text: b.textContent, pressed: b.getAttribute('aria-pressed'), box: box(b) })) }));
})()"""
# Each jump link's text and the position of the frame it leads to.
JUMPS = """Array.from(document.querySelectorAll('nav[aria-label="Jump to variant"] a')).map(a =>
  [a.textContent, Array.from(document.querySelectorAll('.vd-frame')).indexOf(document.getElementById(a.hash.slice(1)))])"""
FOCUSED = "Array.from(document.querySelectorAll('.vd-frame')).indexOf(document.activeElement)"
INNER = ("(() => { const m = document.getElementById('vd-frames'), c = getComputedStyle(m);"
         " return m.clientWidth - parseFloat(c.paddingLeft) - parseFloat(c.paddingRight); })()")
LETTERS = "ABCDEF"
EACH = ["one frame has", "two frames each have", "three frames each have", "four frames each have", "five frames each have", "six frames each have"]
NTH = ["first", "second", "third", "fourth", "fifth", "sixth"]
# Every name a Pick button takes starts with Pick, whatever it reads.
PICK_B = '#vd-b button[aria-label^="Pick"]'
PICK, PICKED = ["Pick", "false"], ["Picked", "true"]


def group(name, body):
    """Run one page's cases; a page that never loads or a control that cannot be clicked fails under this name, and the next group still runs."""
    try:
        body()
    except Exception as exc:
        case(name, False, "stopped: %s: %s" % (type(exc).__name__, exc))


def each_count(n):
    name = "layout-%d.html" % n
    open_page(name, 375)
    wide = js("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    case("one to six frames no sideways scroll at 375 with Pick and Note", wide[0] <= wide[1],
         "%s: the page is %d px wide in a %d px viewport" % (name, wide[0], wide[1]))
    frames = js(FRAMES)
    names = [[b["name"] for b in f["buttons"]] for f in frames]
    want = [["Focus", "Pick variant " + L, "Note on variant " + L] for L in LETTERS[:n]]
    case("%s Pick and Note" % EACH[n - 1], len(frames) == n and all(set(w) <= set(g) for w, g in zip(want, names)),
         "%s: want %s in the titles, got %s" % (name, want, names))
    jumps = js(JUMPS)
    case("one to six frames each have a jump link reading their letter", jumps == [[L, i] for i, L in enumerate(LETTERS[:n])],
         "%s: got [text, frame position] %s" % (name, jumps))
    inner = js(INNER)
    boxes = [f["box"] for f in frames]
    stacked = all(b["width"] >= inner - 1 for b in boxes) and all(b["top"] >= a["bottom"] for a, b in zip(boxes, boxes[1:]))
    case("frames stack one per row at 375", stacked,
         "%s: the row is %d px wide, frames are at %s" % (name, inner, [[round(b["left"]), round(b["top"]), round(b["width"])] for b in boxes]))


def rows_at_1280():
    open_page("layout-6.html", 1280)
    tops = [round(f["box"]["top"]) for f in js(FRAMES)]
    case("six frames share rows at 1280", len(tops) == 6 and len(set(tops)) < 6, "frame tops: %s" % tops)


def title_rows(frame):
    """How many rows a frame's badge and title buttons take: 1 while every button shares the title's first line."""
    rows, bottom = 0, float("-inf")
    for box in sorted([frame["line"]] + [b["box"] for b in frame["buttons"]], key=lambda box: box["top"]):
        if box["top"] >= bottom - 0.5:
            rows += 1
        bottom = max(bottom, box["bottom"])
    return rows


def inside_title(frame):
    """Whether every title button of a frame lies inside its title's box."""
    return all(b["box"]["bottom"] <= frame["title"]["bottom"] + 0.5 and b["box"]["left"] >= frame["title"]["left"] - 0.5
               and b["box"]["right"] <= frame["title"]["right"] + 0.5 for b in frame["buttons"])


def widths(frame):
    return [round(b["box"]["width"], 1) for b in frame["buttons"]]


def wrapped_title():
    # The third frame's label cannot fold (see build_pages), so its buttons have to wrap.
    open_page("layout-3.html", 375)
    frames = js(FRAMES)
    plain, tight = frames[0], frames[2]
    rows = [title_rows(tight), title_rows(plain)]
    case("title buttons that wrap stay inside the title at full width at 375",
         rows[0] > 1 and rows[1] == 1 and inside_title(tight) and widths(tight) == widths(plain),
         "rows the badge and buttons take %d (want over 1) against %d where the label is short (want 1), inside the title %s, widths %s against %s;"
         " title bottom %.1f, button bottoms %s"
         % (rows[0], rows[1], inside_title(tight), widths(tight), widths(plain), tight["title"]["bottom"],
            [round(b["box"]["bottom"], 1) for b in tight["buttons"]]))


def pick_states():
    """Each frame's Pick button as [text, aria-pressed], in frame order."""
    return [[b["text"], b["pressed"]] for f in js(FRAMES) for b in f["buttons"] if b["name"].startswith("Pick")]


def middle_frame_removed():
    # Frames by id are a, b, d, e, f here: a letter that followed the id would skip C.
    open_page("layout-gap.html", 1280)
    seen = [[f["badge"]] + [b["name"] for b in f["buttons"] if b["name"] != "Focus"] for f in js(FRAMES)]
    jumps = js(JUMPS)
    case("with a middle frame removed the frames still read A to E in order",
         seen == [[L, "Pick variant " + L, "Note on variant " + L] for L in "ABCDE"] and jumps == [[L, i] for i, L in enumerate("ABCDE")],
         "got [badge, Pick, Note] %s and jump links %s" % (seen, jumps))
    click('#vd-e button[aria-label^="Pick"]')
    marked = wait("document.querySelector('#vd-e button[aria-label^=\"Pick\"]').getAttribute('aria-pressed') === 'true'")
    picks = [r["variant"] for r in rows("layout-gap.html") if r["kind"] == "pick"]
    state = pick_states()
    case("a pick on the fourth frame stores D and shows Picked there only",
         marked and picks == ["D"] and state == [["Picked", "true"] if i == 3 else ["Pick", "false"] for i in range(5)],
         "stored picks %s, Pick buttons %s" % (picks, state))


def pick_b(name):
    """Pick the second frame of the open page; returns whether B then reads Picked, and the page's stored picks as [letter, pass]."""
    click(PICK_B)
    shown = wait("document.querySelector(%s).getAttribute('aria-pressed') === 'true'" % json.dumps(PICK_B))
    return shown, [[r["variant"], r.get("pass")] for r in rows(name) if r["kind"] == "pick"]


def posts_the_pass(name, number):
    shown, picks = pick_b(name)
    case("pick posts the pass number", shown and picks[-1:] == [["B", number]],
         "%s is marked pass %d: stored picks as [letter, pass] %s, B reads Picked: %s" % (name, number, picks, shown))


def pick_on_pass_one():
    # The feedback file started with a pick of A for this page that has no pass key (written beside the pages).
    open_page("layout-2.html", 1280)
    state = pick_states()
    case("a stored pick that has no pass is not picked on a page marked pass 1", state == [PICK] * 2, "Pick buttons %s" % state)
    posts_the_pass("layout-2.html", 1)


def a_new_pass():
    # A pass is written over the path of the one before and rows are kept by path: the earlier round's pick is still stored under this page.
    seed_pick("pass-2.html", "B", 1)
    open_page("pass-2.html", 1280)
    state = pick_states()
    case("pass 2 opens with nothing picked", state == [PICK] * 3, "the one stored pick is B on pass 1; Pick buttons %s" % state)
    posts_the_pass("pass-2.html", 2)
    seed_pick("pass-2.html", "A", 1)
    open_page("pass-2.html", 1280)
    state = pick_states()
    case("a newer pick from another pass leaves nothing picked", state == [PICK] * 3,
         "stored picks are B on pass 1, B on pass 2, then A on pass 1; Pick buttons on the pass 2 page %s" % state)


def note_on_pass_two():
    open_page("pass-2.html", 1280)
    click('#vd-a button[aria-label^="Note on variant"]')
    typing = wait("document.activeElement === document.getElementById('vd-fb-text')")
    key("n")
    click('#vd-fb-box button[type="submit"]')
    sent = wait("document.getElementById('vd-fb-box').hidden")
    notes = [[r["variant"], r["text"], r.get("pass")] for r in rows("pass-2.html") if r["kind"] == "note"]
    case("a note posts the pass number", typing and sent and notes == [["A", "n", 2]],
         "stored notes as [letter, text, pass] %s; the note box took focus: %s, closed after Send: %s" % (notes, typing, sent))


def an_unmarked_page():
    # The feedback file started with a pick of B for this page that has no pass key (written beside the pages).
    open_page("pass-none.html", 1280)
    state = pick_states()
    case("a page with no pass mark shows a stored pick that has no pass", state == [PICK, PICKED, PICK], "Pick buttons %s" % state)


def pick_on_a_refused_mark():
    # serve.py stores a pass outside 1 to 9 as none: a page that kept 12 as its own pass would never match the row its pick left.
    open_page("pass-12.html", 1280)
    shown, picks = pick_b("pass-12.html")
    case("a pick on a page marked pass 12 is stored with no pass and reads Picked", shown and picks == [["B", None]],
         "stored picks as [letter, pass] %s, B reads Picked: %s" % (picks, shown))


def number_keys():
    open_page("layout-6.html", 1280)
    for n in range(1, 7):
        key(str(n))
        got = js(FOCUSED)
        case("key %d focuses the %s frame" % (n, NTH[n - 1]), got == n - 1, "focus is on frame position %d (-1: on no frame)" % got)


def key_past_the_last():
    open_page("layout-3.html", 375)
    key("2")
    before = js("[%s, scrollY]" % FOCUSED)
    key("5")
    after = js("[%s, scrollY]" % FOCUSED)
    case("a key past the last frame does nothing", before[0] == 1 and after == before,
         "[focused frame position, scrollY] was %s after key 2, then %s after key 5 on three frames" % (before, after))


def flip_mode():
    # Flip shows one frame at a time, so a jump link cannot scroll to its frame: the link has to show it.
    open_page("layout-6.html", 1280)
    click('[data-vd-set-mode="flip"]')
    click('nav[aria-label="Jump to variant"] a:nth-of-type(4)')
    shown = [i for i, L in enumerate("abcdef") if style("#vd-" + L, "display") != "none"]
    focused = js(FOCUSED)
    case("in Flip mode a jump link shows and focuses its frame", shown == [3] and focused == 3,
         "frames shown %s, focus on frame position %d" % (shown, focused))


LOOK = "look-5.html"
# Per frame: its content's paper and ink, its nav bar's fill and text, its button's corner, its font. Then the shell's own parts: the header's paper, ink, rule, font and a control's corner, and per frame its paper, title, badge, caption, tradeoff list and corner.
LOOK_PROBE = """(() => {
  const css = (el, p) => getComputedStyle(el).getPropertyValue(p);
  const frames = Array.from(document.querySelectorAll('.vd-frame')), header = document.getElementById('vd-header');
  return {
    look: ['palette', 'style', 'type'].map(k => document.documentElement.getAttribute('data-vd-' + k)),
    frames: frames.map(f => { const c = f.querySelector('.vd-content'), nav = c.querySelector('.vd-nav');
      return { colours: [css(c, 'background-color'), css(c, 'color'), css(nav, 'background-color'), css(nav, 'color')],
               corner: css(c.querySelector('.vd-btn'), 'border-top-left-radius'), font: css(c, 'font-family') }; }),
    shell: [css(header, 'background-color'), css(header, 'color'), css(header, 'border-bottom-color'), css(header, 'font-family'),
            css(header.querySelector('.vd-seg'), 'border-top-left-radius')].concat(frames.flatMap(f => {
      const h = f.querySelector('h2'), cap = f.querySelector('.vd-caption'), t = f.querySelector('.vd-tradeoffs');
      return [css(f, 'background-color'), css(f, 'border-top-left-radius'), css(h, 'background-color'), css(h.querySelector('.vd-badge'), 'background-color'),
              css(cap, 'color'), css(cap, 'font-family'), css(t, 'background-color'), css(t, 'color'), css(t, 'font-family')]; }))
  };
})()"""
# Each switcher in page order: its kind, role, accessible name, the text drawn just left of it, its box, and its options as [name, text, aria-pressed].
SWITCHERS = """Array.from(document.querySelectorAll('[data-vd-switcher]')).map(g => { const r = g.getBoundingClientRect();
  return { kind: g.dataset.vdSwitcher, role: g.getAttribute('role'), name: g.getAttribute('aria-label'),
           label: document.elementFromPoint(r.left - 14, r.top + r.height / 2).textContent, left: r.left, top: r.top,
           options: Array.from(g.querySelectorAll('button')).map(b => [b.dataset.vdOption, b.textContent, b.getAttribute('aria-pressed')]) }; })"""
# The switcher button that has focus as [kind, option], or null when focus is anywhere else.
AT_OPTION = """(() => { const a = document.activeElement, g = a && a.closest('[data-vd-switcher]');
  return g && a.localName === 'button' ? [g.dataset.vdSwitcher, a.dataset.vdOption] : null; })()"""
# A frame's content paper, ink, nav bar and nav text under the shell's neutrals and under the palettes build_pages writes.
NEUTRAL = ["rgb(255, 255, 255)", "rgb(24, 24, 27)", "rgb(24, 24, 27)", "rgb(255, 255, 255)"]
BERRY = ["rgb(255, 245, 248)", "rgb(59, 10, 31)", "rgb(131, 24, 67)", "rgb(255, 245, 248)"]
BERRY_DARK = ["rgb(31, 10, 20)", "rgb(253, 231, 238)", "rgb(74, 13, 40)", "rgb(253, 231, 238)"]
MOSS = ["rgb(247, 250, 245)", "rgb(20, 35, 15)", "rgb(26, 46, 20)", "rgb(247, 250, 245)"]
SERIF = 'Georgia, "Times New Roman", serif'
OPTIONS = [["palette", ["Neutral", "Berry", "Moss"]], ["style", ["Soft", "Sharp"]], ["type", ["Sans", "Serif"]]]
# The last palette of look-24.html, as build_pages names it.
NAMES_LAST = "Paper_lantern_at_evening"
# The first palette of look-25.html, as build_pages names it: only its length refuses it.
NAME_25 = "Paper lantern at evenings"


def switch(kind, name):
    """Click one option of one switcher."""
    click('[data-vd-switcher="%s"] [data-vd-option="%s"]' % (kind, name))


def listed(switchers=None):
    """Switchers as [kind, option names] in page order: the open page's, or those of a SWITCHERS answer already read."""
    return [[s["kind"], [o[0] for o in s["options"]]] for s in (js(SWITCHERS) if switchers is None else switchers)]


def colours(probe):
    return [f["colours"] for f in probe["frames"]]


def moved(before, after):
    """The positions of the shell's own values that differ between two probes."""
    return [i for i, (a, b) in enumerate(zip(before["shell"], after["shell"])) if a != b]


# What the open page says is active: the five values on <html>, each switcher's pressed options, the two toggles' labels.
ACTIVE = """(() => { const root = document.documentElement;
  return [['data-vd-palette', 'data-vd-style', 'data-vd-type', 'data-vd-scheme', 'dir'].map(a => root.getAttribute(a)),
          Array.from(document.querySelectorAll('[data-vd-switcher]')).map(g =>
            Array.from(g.querySelectorAll('[aria-pressed="true"]')).map(b => b.dataset.vdOption)),
          ['vd-scheme-toggle', 'vd-dir-toggle'].map(id => document.getElementById(id).textContent)]; })()"""
AS_ACTIVE = "as [html's palette, style, type, scheme and dir; pressed options per switcher; toggle labels]"


def showing(palette, style, kind, scheme="light", direction="ltr"):
    """What ACTIVE answers when <html>, the pressed options and the toggle labels all say these five values."""
    return [[palette, style, kind, scheme, direction], [[palette], [style], [kind]], ["Scheme, " + scheme, "Direction, " + direction.upper()]]


CHOSEN, DEFAULTS = showing("Berry", "Sharp", "Serif", "dark", "rtl"), showing("Neutral", "Soft", "Sans")


def choose_all():
    """Choose Berry, Sharp, Serif, the dark scheme and RTL on the open page."""
    for kind, name in (("palette", "Berry"), ("style", "Sharp"), ("type", "Serif")):
        switch(kind, name)
    click("#vd-scheme-toggle")
    click("#vd-dir-toggle")


def palette_restyles():
    open_page(LOOK, 1280)
    before = js(LOOK_PROBE)
    switch("palette", "Berry")
    after = js(LOOK_PROBE)
    pressed = [o[2] for o in js(SWITCHERS)[0]["options"]]
    case("palette restyles every frame and not the header",
         colours(before) == [NEUTRAL] * 5 and colours(after) == [BERRY] * 5 and not moved(before, after)
         and after["look"][0] == "Berry" and pressed == ["false", "true", "false"],
         "per frame [paper, ink, nav bar, nav text] was %s, under Berry %s (want %s); shell values that moved: %s; html says %s, options pressed %s"
         % (colours(before), colours(after), BERRY, moved(before, after), after["look"], pressed))
    click("#vd-scheme-toggle")
    dark = js(LOOK_PROBE)
    case("a palette's dark set paints the frames under the dark scheme", colours(dark) == [BERRY_DARK] * 5 and dark["shell"][0] == "rgb(27, 27, 31)",
         "per frame %s (want %s); the header's paper is %s (want the shell's dark neutral)" % (colours(dark), BERRY_DARK, dark["shell"][0]))


def style_and_type():
    open_page(LOOK, 1280)
    soft = js(LOOK_PROBE)
    switch("style", "Sharp")
    sharp = js(LOOK_PROBE)
    switch("type", "Serif")
    serif = js(LOOK_PROBE)
    corners = [[f["corner"] for f in p["frames"]] for p in (soft, sharp)]
    fonts = [[f["font"] for f in p["frames"]] for p in (sharp, serif)]
    own = soft["shell"][3]
    case("style and type restyle frames only",
         corners == [["12px"] * 5, ["0px"] * 5] and fonts == [[own] * 5, [SERIF] * 5] and own != SERIF
         and not moved(soft, sharp) and not moved(soft, serif) and serif["look"] == ["Neutral", "Sharp", "Serif"],
         "button corners per frame under Soft then Sharp %s; content fonts under Sans then Serif %s against the header's %s; shell values that moved: %s under Sharp, %s under Serif; html says %s"
         % (corners, fonts, own, moved(soft, sharp), moved(soft, serif), serif["look"]))


def labelled_in_order():
    # 2560 wide: a row with no line of its own would fit beside the first row's controls here.
    open_page(LOOK, 2560)
    got = js(SWITCHERS)
    look = js(LOOK_PROBE)["look"]
    first_row = js("document.querySelector('[data-vd-set-mode]').getBoundingClientRect().bottom")
    shown = [[s["kind"], s["role"], s["name"], s["label"]] for s in got]
    lefts, tops = [s["left"] for s in got], [s["top"] for s in got]
    first = [[o[2] for o in s["options"]] for s in got]
    case("switchers are labelled groups in a second row in the order Palette, Style, Type with the first option active",
         shown == [["palette", "group", "Palette", "Palette"], ["style", "group", "Style", "Style"], ["type", "group", "Type", "Type"]]
         and lefts == sorted(lefts) and len(set(tops)) == 1 and tops[0] >= first_row and listed(got) == OPTIONS
         and all(o[0] == o[1] for s in got for o in s["options"])
         and first == [["true", "false", "false"], ["true", "false"], ["true", "false"]] and look == ["Neutral", "Soft", "Sans"],
         "[kind, role, name, text beside it] %s at left edges %s and tops %s, the first row's controls end at %s; options %s; html says %s"
         % (shown, lefts, tops, first_row, [s["options"] for s in got], look))


def by_keyboard():
    open_page(LOOK, 1280)
    stops, kept = [], []
    for _ in range(60):
        key("Tab")
        at = js(AT_OPTION)
        if not at:
            if stops:
                break
            continue
        stops.append(at)
        how = {"Berry": "Enter", "Moss": "Space"}.get(at[1])
        if how:
            js("void (window.vdHeld = document.activeElement)")
            key(how)
            kept.append([how] + js("[document.documentElement.getAttribute('data-vd-palette'), document.activeElement.getAttribute('aria-pressed'),"
                                   " document.activeElement === window.vdHeld]"))
    case("switcher operated by keyboard keeps focus",
         stops == [[kind, name] for kind, names in OPTIONS for name in names]
         and kept == [["Enter", "Berry", "true", True], ["Space", "Moss", "true", True]],
         "Tab stopped on %s; each press as [key, html palette after it, the focused button's aria-pressed, focus still on that button] %s" % (stops, kept))


def no_reload():
    open_page(LOOK, 1280)
    js("void (window.vdStayed = true)")
    was = js("[location.href, history.length]")
    cdp.loaded = False
    for kind, name in (("palette", "Berry"), ("style", "Sharp"), ("type", "Serif")):
        switch(kind, name)
    # A reload asked for by a click replaces the document a few milliseconds later, so the mark is read after that window.
    gone = wait("window.vdStayed !== true", 300)
    now = js("[location.href, history.length]")
    look = js(LOOK_PROBE)["look"]
    case("option change does not reload", look == ["Berry", "Sharp", "Serif"] and not gone and not cdp.loaded and now == was,
         "html says %s; the mark set before the clicks is gone: %s; a load event fired: %s; [address, history length] was %s, is %s"
         % (look, gone, cdp.loaded, was, now))


def one_option():
    open_page("look-one.html", 1280)
    probe = js(LOOK_PROBE)
    got = [listed(), js("document.querySelectorAll('#vd-header > .vd-controls').length"), probe["look"], [c[0] for c in colours(probe)]]
    case("one-option switcher hidden", got == [[], 1, ["Berry", "Sharp", "Serif"], [BERRY[0]] * 3],
         "Berry, Sharp and Serif are each the one option of their kind: switchers shown %s, control rows in the header %s (want the first row alone),"
         " html says %s, paper per frame %s (want Berry's)" % tuple(got))


def creative_pass():
    open_page("look-creative.html", 1280)
    got = listed()
    case("a creative pass shows the switcher with two options and none for a kind with no options", got == [["palette", ["Neutral", "Berry"]]],
         "two palettes, no style and no type are authored: switchers shown %s" % got)


def another_pass_kind():
    # The page carries look-5's presets and no pass marks, and its second frame alone sets its own radius, as a theme-axis pass does.
    open_page("look-other.html", 1280)
    probe = js(LOOK_PROBE)
    got = [listed(), probe["look"]]
    case("a page of another pass kind shows no switcher row", got == [[], [None, None, None]], "switchers shown %s, html says %s" % tuple(got))
    corners = [f["corner"] for f in probe["frames"]]
    case("a per-frame preset still turns one frame only", corners == ["8px", "0px", "8px"], "button corners per frame %s" % corners)


def static_page():
    open_page(LOOK, 1280, static=True)
    got = listed()
    case("a page loaded with ?static=1 lists its switchers", got == OPTIONS, "switchers shown %s" % got)
    before = js(LOOK_PROBE)
    js("document.documentElement.setAttribute('data-vd-palette', 'Moss')")
    after = js(LOOK_PROBE)
    case("static page honours the palette attribute", colours(before) == [NEUTRAL] * 5 and colours(after) == [MOSS] * 5 and not moved(before, after),
         "per frame [paper, ink, nav bar, nav text] was %s, with data-vd-palette set to Moss %s (want %s); shell values that moved: %s"
         % (colours(before), colours(after), MOSS, moved(before, after)))


def survives_reload():
    open_page("kept.html", 1280, stream=False)
    choose_all()
    reload()
    got = [js(ACTIVE), colours(js(LOOK_PROBE))]
    case("look survives reload", got == [CHOSEN, [BERRY_DARK] * 5],
         "Berry, Sharp, Serif, dark and RTL were chosen, then the tab reloaded: %s %s, per frame [paper, ink, nav bar, nav text] %s (want Berry's dark set)"
         % (AS_ACTIVE, got[0], got[1]))
    next_pass("kept.html")
    got = [js("document.body.dataset.vdPass"), js(ACTIVE)]
    case("look survives the reload a new pass causes", got == ["2", CHOSEN],
         "pass 2 was written over the open page, which now says pass %s: %s %s" % (got[0], AS_ACTIVE, got[1]))


def stored_option_gone():
    open_page("fewer.html", 1280, stream=False)
    for kind, name in (("palette", "Moss"), ("style", "Sharp"), ("type", "Serif")):
        switch(kind, name)
    next_pass("fewer.html")
    got = [listed()[0], js(ACTIVE)]
    case("missing stored option falls back to first", got == [["palette", ["Neutral", "Berry"]], showing("Neutral", "Sharp", "Serif")],
         "Moss, Sharp and Serif were chosen, then a pass with no Moss was written over the page: its palettes are %s, %s %s" % (got[0], AS_ACTIVE, got[1]))


def second_tab():
    open_page(LOOK, 1280)
    choose_all()
    first = js(ACTIVE)
    # The first tab stays open beside the second: tab() closes only the one it knows.
    held, cdp.target = cdp.target, None
    try:
        open_page(LOOK, 1280)
        got = js(ACTIVE)
    finally:
        cdp.call("Target.closeTarget", {"targetId": held}, tab=False)
    case("second tab starts from defaults", first == CHOSEN and got == DEFAULTS,
         "%s: the first tab, after its choices, %s; a second tab on the same page %s" % (AS_ACTIVE, first, got))


def authored_look():
    open_page("look-authored.html", 1280)
    got = [js(ACTIVE), colours(js(LOOK_PROBE))]
    case("authored look opens active", got == [CHOSEN, [BERRY_DARK] * 5],
         "the page's html tag says Berry, Sharp, Serif, dark and dir rtl: %s %s, per frame [paper, ink, nav bar, nav text] %s (want Berry's dark set)"
         % (AS_ACTIVE, got[0], got[1]))
    open_page("look-authored-gone.html", 1280)
    got = js(ACTIVE)
    case("an authored option the page lacks opens on the first", got == DEFAULTS,
         "the page's html tag says palette Plum, which it does not declare: %s %s" % (AS_ACTIVE, got))


def another_path_or_title():
    open_page("retitled.html", 1280, stream=False)
    choose_all()
    open_page(LOOK, 1280, fresh=False)
    elsewhere = js(ACTIVE)
    open_page("retitled.html", 1280, fresh=False)
    back = js(ACTIVE)
    case("a kept look stays with its page path", elsewhere == DEFAULTS and back == CHOSEN,
         "%s: after the choices the tab went to a page of the same title and options, which shows %s, then back, which shows %s" % (AS_ACTIVE, elsewhere, back))
    next_pass("retitled.html")
    got = [js("document.title"), js(ACTIVE)]
    case("a kept look does not outlive its decision title", got == ["Which invoice list ships?", DEFAULTS],
         "another decision was written over the open page, whose title is now %s: %s %s" % (got[0], AS_ACTIVE, got[1]))


def static_after_choices():
    open_page(LOOK, 1280)
    choose_all()
    open_page(LOOK, 1280, static=True, fresh=False)
    static = js(ACTIVE)
    open_page(LOOK, 1280, fresh=False)
    live = js(ACTIVE)
    case("a page loaded with ?static=1 ignores the look the tab keeps", static == DEFAULTS and live == CHOSEN,
         "%s: after the choices the tab loaded the page with ?static=1, which shows %s, then without, which shows %s" % (AS_ACTIVE, static, live))


def storage_refused():
    open_page(LOOK, 1280)
    # What Chrome does with site data blocked: reading window.sessionStorage itself throws.
    cdp.call("Page.addScriptToEvaluateOnNewDocument", {"source": "window.vdThrown = []; addEventListener('error', e => window.vdThrown.push(e.message));"
             " Object.defineProperty(window, 'sessionStorage', { get() { throw new DOMException('refused', 'SecurityError'); } });"})
    reload()
    refused = js("(() => { try { return !window.sessionStorage; } catch { return true; } })()")
    opened = js(ACTIVE)
    choose_all()
    got = [js(ACTIVE), colours(js(LOOK_PROBE)), js("window.vdThrown")]
    case("storage that throws leaves the page working from its defaults", refused and opened == DEFAULTS and got == [CHOSEN, [BERRY_DARK] * 5, []],
         "sessionStorage throws on this page: %s; %s it opened %s, after the five choices %s with frames %s; uncaught errors %s"
         % (refused, AS_ACTIVE, opened, got[0], got[1], got[2]))


THEMED = "themed.html"
THEMED_OPTIONS = [[kind, ["Project", "Neutral"]] for kind in ("palette", "style", "type")]
# A frame's content under the Project palette build_pages writes (its own ink, the shell's paper and nav bar), and under the shell's dark neutrals.
PROJECT = ["rgb(255, 255, 255)", "rgb(19, 78, 74)", "rgb(24, 24, 27)", "rgb(255, 255, 255)"]
NEUTRAL_DARK = ["rgb(27, 27, 31)", "rgb(244, 244, 245)", "rgb(44, 44, 51)", "rgb(244, 244, 245)"]
NO_DARK_SET = "Project has no dark set"
# The Scheme toggle as [disabled, label]; the note it is described by as [text, role], and whether that note is drawn on the toggle's line, after it; html's scheme.
SCHEME = """(() => { const t = document.getElementById('vd-scheme-toggle'), n = document.getElementById(t.getAttribute('aria-describedby'));
  const a = t.getBoundingClientRect(), b = n ? n.getBoundingClientRect() : null;
  return { toggle: [t.disabled, t.textContent], note: n ? [n.textContent, n.getAttribute('role')] : null,
           beside: !!b && b.width > 0 && b.left >= a.right && b.top < a.bottom && b.bottom > a.top,
           scheme: document.documentElement.getAttribute('data-vd-scheme') }; })()"""


def scheme_is(disabled, value, note=""):
    """What SCHEME answers for a toggle in this state on this scheme, with this note beside it or an empty one that is not drawn."""
    return {"toggle": [disabled, "Scheme, " + value], "note": [note, "status"], "beside": bool(note), "scheme": value}


def themed_project():
    open_page(THEMED, 1280)
    got = [listed(), js(ACTIVE), colours(js(LOOK_PROBE)),
           js("Array.from(document.querySelectorAll('#vd-header button')).map(b => b.textContent).filter(t => /^Theme/.test(t))"),
           js("document.documentElement.getAttribute('data-vd-theme')")]
    case("Project is the first palette and no Theme toggle", got == [THEMED_OPTIONS, showing("Project", "Project", "Project"), [PROJECT] * 3, [], None],
         "switchers %s; %s %s; per frame [paper, ink, nav bar, nav text] %s (want %s); header buttons whose text starts with Theme, drawn or hidden: %s;"
         " html's data-vd-theme: %s" % (got[0], AS_ACTIVE, got[1], got[2], PROJECT, got[3], got[4]))


def scheme_without_dark_set():
    open_page(THEMED, 1280)
    project = js(SCHEME)
    switch("palette", "Neutral")
    neutral = js(SCHEME)
    click("#vd-scheme-toggle")
    dark = [js(SCHEME), colours(js(LOOK_PROBE))]
    case("Scheme disabled without a dark set",
         project == scheme_is(True, "light", NO_DARK_SET) and neutral == scheme_is(False, "light") and dark == [scheme_is(False, "dark"), [NEUTRAL_DARK] * 3],
         "the Project palette has no dark rule: the Scheme toggle under it %s, under Neutral %s, then after a click %s with frames %s (want the shell's dark neutrals)"
         % (project, neutral, dark[0], dark[1]))
    switch("palette", "Project")
    probe = js(LOOK_PROBE)
    held = [js(SCHEME), colours(probe), probe["shell"][0]]
    switch("palette", "Neutral")
    back = js(SCHEME)
    case("the dark scheme gives way to light while Project is active and returns under Neutral",
         held == [scheme_is(True, "light", NO_DARK_SET), [PROJECT] * 3, "rgb(255, 255, 255)"] and back == scheme_is(False, "dark"),
         "dark was chosen under Neutral, then Project: the Scheme toggle %s, frames %s (want %s), the header's paper %s; then Neutral again: %s"
         % (held[0], held[1], PROJECT, held[2], back))


# A frame's paper and ink under the Day palette build_pages writes, and under its dark rule.
DAY, DAY_DARK = ["rgb(255, 251, 235)", "rgb(31, 41, 55)"], ["rgb(17, 24, 39)", "rgb(249, 250, 251)"]
# Whether a palette is light only by the rule scripts/preview-check.sh's check reads: among #vd-presets' top-level style rules and those directly inside an @media screen block, as the sheet stands after the shell's script ran, its first rule sets a value and it has no dark rule.
LIGHT_ONLY = """(name => { const styled = r => r instanceof CSSStyleRule;
  const rules = Array.from(document.getElementById('vd-presets').sheet.cssRules).flatMap(r => (styled(r) ? [r]
    : r instanceof CSSMediaRule && r.media.mediaText === 'screen' ? Array.from(r.cssRules).filter(styled) : []));
  const own = 'html[data-vd-palette="' + name + '"]', first = rules.find(r => r.selectorText === own + ' .vd-content');
  return !!first && first.style.length > 0 && !rules.some(r => r.selectorText === own + '[data-vd-scheme="dark"] .vd-content'); })(%s)"""


def paper_and_ink():
    return [c[:2] for c in colours(js(LOOK_PROBE))]


def dark_set_rule():
    by_rule = []
    for where, said in (("top", "at the top level"), ("screen", "authored inside @media screen")):
        open_page("scheme-%s.html" % where, 1280)
        light = [js(SCHEME), paper_and_ink()]
        by_rule.append([where, js(LIGHT_ONLY % '"Day"'), light[0]["toggle"][0]])
        click("#vd-scheme-toggle")
        dark = [js(SCHEME), paper_and_ink()]
        cdp.call("Emulation.setEmulatedMedia", {"media": "print"})
        printed = paper_and_ink()
        cdp.call("Emulation.setEmulatedMedia", {"media": ""})
        case("a dark rule %s is a dark set: Scheme works, its values paint the frames on screen and not in print" % said,
             light == [scheme_is(False, "light"), [DAY] * 3] and dark == [scheme_is(False, "dark"), [DAY_DARK] * 3] and printed == [DAY] * 3,
             "the Scheme toggle and per frame [paper, ink] on load %s, after a click on the toggle %s (want %s), under print media %s (want %s)"
             % (light, dark, DAY_DARK, printed, DAY))
    for where in ("print", "supports", "screen-wide", "nested"):
        open_page("scheme-%s.html" % where, 1280)
        got = [js(SCHEME), paper_and_ink()]
        by_rule.append([where, js(LIGHT_ONLY % '"Day"'), got[0]["toggle"][0]])
        case("a dark rule inside any other block is no dark set (%s): the palette is held light" % where,
             got == [scheme_is(True, "light", "Day has no dark set"), [DAY] * 3], "the Scheme toggle and per frame [paper, ink] %s (want %s)" % (got, DAY))
    open_page("scheme-first-empty.html", 1280)
    light = js(SCHEME)
    by_rule.append(["first-empty", js(LIGHT_ONLY % '"Twice"'), light["toggle"][0]])
    click("#vd-scheme-toggle")
    dark = [js(SCHEME), [c[1] for c in colours(js(LOOK_PROBE))]]
    case("a palette whose first rule is empty keeps its Scheme toggle, though a later rule of its name sets a value",
         light == scheme_is(False, "light") and dark == [scheme_is(False, "dark"), [NEUTRAL_DARK[1]] * 3],
         "the Scheme toggle on load %s, after a click %s with ink per frame %s (want the shell's dark ink)" % (light, dark[0], dark[1]))
    want = [["top", False, False], ["screen", False, False]] + [[w, True, True] for w in ("print", "supports", "screen-wide", "nested")] + [["first-empty", False, False]]
    case("the Scheme toggle is disabled exactly where the rule the render check reads says light only", by_rule == want,
         "per page as [where the dark rule stands, light only by that rule, toggle disabled] %s (want %s)" % (by_rule, want))


def theme_in_context():
    pick_a = '#vd-a button[aria-label^="Pick"]'
    open_page(THEMED, 1280)
    click(PICK_B)
    first = wait("document.querySelector(%s).getAttribute('aria-pressed') === 'true'" % json.dumps(PICK_B))
    switch("palette", "Neutral")
    click("#vd-scheme-toggle")
    click(pick_a)
    second = wait("document.querySelector(%s).getAttribute('aria-pressed') === 'true'" % json.dumps(pick_a))
    themes = [[r["variant"], r["context"]["theme"]] for r in rows(THEMED) if r["kind"] == "pick"][-2:]
    case("a pick stores the active palette and scheme as its context theme", first and second and themes == [["B", "Project light"], ["A", "Neutral dark"]],
         "B was picked under Project, then A under Neutral on the dark scheme: stored picks as [letter, context theme] %s; each read Picked: %s, %s"
         % (themes, first, second))
    # Dark stays the person's choice while Project, which has no dark set, holds the frames light.
    switch("palette", "Project")
    third = pick(PICK_B)
    schemes = [[r["variant"], r["context"].get("scheme")] for r in rows(THEMED) if r["kind"] == "pick"][-3:]
    case("a pick stores the scheme its frames are drawn in as its own field", third and schemes == [["B", "light"], ["A", "dark"], ["B", "light"]],
         "B was picked under Project, A under Neutral on the dark scheme, then B under Project with dark still chosen: stored picks as [letter, context scheme] %s;"
         " the third read Picked: %s" % (schemes, third))
    open_page("layout-3.html", 1280)
    shown, _ = pick_b("layout-3.html")
    theme = [[r["context"]["theme"], r["context"].get("scheme")] for r in rows("layout-3.html") if r["kind"] == "pick"][-1:]
    case("a pick on a page with no palette stores baseline as its theme", shown and theme == [["baseline light", "light"]],
         "the page declares no palette: its newest pick's context as [theme, scheme] %s, B reads Picked: %s" % (theme, shown))


PICK_D = '#vd-d button[aria-label^="Pick"]'
# What a picked frame's button reads on look-wordy.html.
WORDY = "Picked with Harbour morning at dawn, Comfortable and rounded, Humanist sans serif"
AS_BUTTON = "as [text, accessible name, aria-pressed]"


def computed(selector, what):
    """The accessible name or description the browser computes for the first element matching the selector; "" when it has none."""
    node = cdp.call("Runtime.evaluate", {"expression": "document.querySelector(%s)" % json.dumps(selector)})["result"]["objectId"]
    return cdp.call("Accessibility.getPartialAXTree", {"objectId": node, "fetchRelatives": False})["nodes"][0].get(what, {}).get("value", "")


def reads(selector):
    """A button as [text, the accessible name the browser computes for it, aria-pressed]."""
    text, pressed = js("(b => [b.textContent, b.getAttribute('aria-pressed')])(document.querySelector(%s))" % json.dumps(selector))
    return [text, computed(selector, "name"), pressed]


def pick(selector):
    """Click a Pick button; True once it reads as pressed."""
    click(selector)
    return wait("document.querySelector(%s).getAttribute('aria-pressed') === 'true'" % json.dumps(selector))


def looks(name, kind="pick"):
    """A page's stored picks (or notes) as [letter, switchers], oldest first; a row with no switchers key reads None."""
    return [[r["variant"], r.get("switchers")] for r in rows(name) if r["kind"] == kind]


def look_of(palette, style="Soft", kind="Serif"):
    return {"palette": palette, "style": style, "type": kind}


def recorded_look():
    open_page(LOOK, 1280)
    switch("palette", "Berry")
    switch("type", "Serif")
    shown = pick(PICK_D)
    stored = looks(LOOK)
    case("pick stores the active look", shown and stored == [["D", look_of("Berry")]],
         "D was picked under Berry, Soft and Serif: stored picks as [letter, switchers] %s, D reads as pressed: %s" % (stored, shown))
    picked, states = reads(PICK_D), pick_states()
    case("the picked frame's button reads Picked with the recorded look",
         picked == ["Picked with Berry, Soft, Serif", "Picked with Berry, Soft, Serif, variant D", "true"] and states == [PICK] * 3 + [picked[::2]] + [PICK],
         "D's button %s %s; every Pick button as [text, aria-pressed] %s" % (AS_BUTTON, picked, states))
    switch("palette", "Moss")
    differs, states = reads(PICK_D), pick_states()
    switch("palette", "Berry")
    back = reads(PICK_D)
    case("button reads Pick with current look after a palette change",
         differs == ["Pick with current look", "Pick with current look, variant D", "false"] and states == [PICK] * 3 + [differs[::2]] + [PICK] and back == picked,
         "D was picked under Berry: under Moss its button %s %s with every Pick button as [text, aria-pressed] %s; under Berry again %s (want %s)"
         % (AS_BUTTON, differs, states, back, picked))
    others = []
    for kind, other, recorded in (("style", "Sharp", "Soft"), ("type", "Sans", "Serif")):
        switch(kind, other)
        others.append(reads(PICK_D)[::2])
        switch(kind, recorded)
    back = reads(PICK_D)
    case("button reads Pick with current look after a style or a type change", others == [["Pick with current look", "false"]] * 2 and back == picked,
         "D was picked under Berry, Soft and Serif: its button as [text, aria-pressed] under Sharp, then under Sans, %s; under the recorded look again %s %s"
         % (others, AS_BUTTON, back))
    switch("palette", "Moss")
    again = pick(PICK_D)
    stored, now = looks(LOOK), reads(PICK_D)
    case("pressing Pick with current look stores a second pick with the new palette",
         again and stored == [["D", look_of("Berry")], ["D", look_of("Moss")]] and now[0] == "Picked with Moss, Soft, Serif",
         "D read Pick with current look under Moss and was pressed: stored picks as [letter, switchers] %s; its button now %s %s" % (stored, AS_BUTTON, now))


REGIONS = """document.querySelectorAll('[role="status"], [role="alert"], [aria-live]')"""
# From here on, each text one of the open page's status regions is given is kept, oldest first, in window.vdSaid: a region given the words it already holds counts again.
LISTEN = """(() => { window.vdSaid = []; %s.forEach(region => new MutationObserver(() => window.vdSaid.push(region.textContent))
  .observe(region, { childList: true, characterData: true, subtree: true })); })()""" % REGIONS
UNMATCHED, MATCHED = "Variant B: the look no longer matches your pick", "Variant B: the look matches your pick again"


def look_change_said():
    open_page("look-said.html", 1280)
    js(LISTEN)
    switch("palette", "Berry")
    switch("palette", "Neutral")
    unpicked = js("window.vdSaid")
    case("a look change on a page with nothing picked is not announced", unpicked == [], "no frame is picked and the palette went to Berry and back: status regions were given %s" % unpicked)
    picked = pick(PICK_B)
    js("void (window.vdSaid = [])")
    switch("palette", "Berry")
    away = [js("window.vdSaid"), js(AT_OPTION), reads(PICK_B)[0]]
    # Each of these leaves the look unlike the pick's, as it already was.
    for kind, option in (("style", "Sharp"), ("palette", "Moss"), ("style", "Soft")):
        switch(kind, option)
    still = js("window.vdSaid")
    switch("palette", "Neutral")
    back = [js("window.vdSaid"), js(AT_OPTION), reads(PICK_B)[0]]
    case("a look change that stops matching the pick is announced once, naming the frame, with focus left on the switcher",
         picked and away == [[UNMATCHED], ["palette", "Berry"], "Pick with current look"] and still == [UNMATCHED],
         "B was picked under Neutral, Soft and Sans, then Berry was chosen: [status regions were given, the focused option, B's button] %s (want %s once);"
         " after Sharp, Moss and Soft, none of which matches the pick either, status regions were given %s in all" % (away, UNMATCHED, still))
    case("a look change that matches the pick again is announced",
         back == [[UNMATCHED, MATCHED], ["palette", "Neutral"], "Picked with Neutral, Soft, Sans"],
         "then Neutral was chosen again: [status regions were given, the focused option, B's button] %s (want %s added)" % (back, MATCHED))
    # The tab keeps Serif, so the page opens on a look that is not its pick's.
    switch("type", "Serif")
    reload()
    opened = [reads(PICK_B)[0], js("Array.from(%s, region => region.textContent).filter(text => text.includes('your pick'))" % REGIONS)]
    case("a page that opens on a look other than its pick's announces nothing", opened == ["Pick with current look", []],
         "the tab reloaded with Serif kept, B picked under Sans: [B's button, status regions that speak of the pick] %s" % opened)


def note_with_look():
    open_page("look-6.html", 1280)
    for kind, name in (("palette", "Moss"), ("style", "Sharp"), ("type", "Serif")):
        switch(kind, name)
    click("#vd-scheme-toggle")
    click('#vd-a button[aria-label^="Note on variant"]')
    typing = wait("document.activeElement === document.getElementById('vd-fb-text')")
    key("n")
    click('#vd-fb-box button[type="submit"]')
    sent = wait("document.getElementById('vd-fb-box').hidden")
    notes = looks("look-6.html", "note")
    case("note stores the active look", typing and sent and notes == [["A", look_of("Moss", "Sharp")]],
         "a note on A was sent under Moss, Sharp and Serif: stored notes as [letter, switchers] %s; the note box took focus: %s, closed after Send: %s"
         % (notes, typing, sent))
    schemes = [r["context"].get("scheme") for r in rows("look-6.html") if r["kind"] == "note"]
    case("a note stores the scheme its frames are drawn in as its own field", schemes == ["dark"],
         "the note was sent under Moss on the dark scheme: stored notes' context scheme %s" % schemes)


def kinds_a_page_lacks_or_hides():
    open_page("look-creative.html", 1280)
    shown = pick(PICK_B)
    stored = looks("look-creative.html")
    case("a pick on a page with no type option stores no type key", shown and stored == [["B", {"palette": "Neutral"}]],
         "the page declares two palettes, no style and no type: stored picks as [letter, switchers] %s, B reads as pressed: %s" % (stored, shown))
    open_page("look-one.html", 1280)
    shown = pick(PICK_B)
    stored, drawn_switchers = looks("look-one.html"), listed()
    case("a pick stores a kind's one option though no switcher shows it", shown and drawn_switchers == [] and stored == [["B", look_of("Berry", "Sharp")]],
         "Berry, Sharp and Serif are each the one option of their kind: switchers shown %s, stored picks as [letter, switchers] %s, B reads as pressed: %s"
         % (drawn_switchers, stored, shown))


def refused_name():
    # serve.py keeps the row and stores the name as none: a page that compared its own R&D with that would never read Picked.
    open_page("look-refused.html", 1280)
    shown = pick(PICK_B)
    stored, under = looks("look-refused.html"), reads(PICK_B)
    switch("palette", "Neutral")
    away = reads(PICK_B)
    case("a pick under an option name the server refuses still reads Picked",
         shown and stored == [["B", {"palette": None}]] and under == ["Picked", "Picked, variant B", "true"] and away[::2] == ["Pick with current look", "false"],
         "B was picked under the palette R&D: stored picks as [letter, switchers] %s; its button %s %s, then under Neutral %s" % (stored, AS_BUTTON, under, away))
    open_page("look-25.html", 1280)
    active = js("document.documentElement.getAttribute('data-vd-palette')")
    shown = pick(PICK_B)
    stored, under = looks("look-25.html"), reads(PICK_B)
    case("a pick under an option name of 25 characters, one past what the server stores, still reads Picked",
         len(NAME_25) == 25 and active == NAME_25 and shown and stored == [["B", {"palette": None}]] and under == ["Picked", "Picked, variant B", "true"],
         "B was picked under the palette %r (%d characters, active on the page: %r): stored picks as [letter, switchers] %s; its button %s %s"
         % (NAME_25, len(NAME_25), active, stored, AS_BUTTON, under))


# Which title button has focus, as Focus, Pick or Note whatever the Pick button reads, or null when focus is anywhere else.
TABBED = """(a => { if (!a || !a.closest('.vd-frame > h2')) return null; const name = a.getAttribute('aria-label') || a.textContent;
  return name.startsWith('Pick') ? 'Pick' : name.split(' ')[0]; })(document.activeElement)"""


def title_order_on(page, width, rows):
    """One page's part of the title-order case: every frame's title buttons read Focus, Pick, Note on screen and by Tab, on one row where rows says 1 and on that many or more where it says more."""
    frames = js(FRAMES)
    on_screen = [["Pick" if b["name"].startswith("Pick") else b["name"].split(" ")[0]
                  for b in sorted(f["buttons"], key=lambda b: (round(b["box"]["top"]), b["box"]["left"]))] for f in frames]
    took = [title_rows(f) for f in frames]
    by_tab = []
    for n in range(1, len(frames) + 1):
        # A number key lands on the frame itself, so the next three Tab stops are its title's.
        key(str(n))
        stops = []
        for _ in range(3):
            key("Tab")
            stops.append(js(TABBED))
        by_tab.append(stops)
    want = [["Focus", "Pick", "Note"]] * len(frames)
    case("title buttons read Focus, Pick, Note on screen and by Tab",
         on_screen == want and by_tab == want and all(t == r if r == 1 else t >= r for t, r in zip(took, rows)),
         "%s at %d: on screen, row by row and left to right, %s; by Tab %s; rows each title's badge and buttons take %s (want %s, or more where over 1)"
         % (page, width, on_screen, by_tab, took, rows))


def title_order():
    open_page("layout-3.html", 1280)
    title_order_on("layout-3.html", 1280, [1, 1, 1])
    # The third frame's label cannot fold (see build_pages): its title wraps beside two that do not.
    open_page("layout-3.html", 375)
    title_order_on("layout-3.html", 375, [1, 1, 2])
    # The picked frame's label is wider than its title row (see build_pages): Focus, the label and Note wrap among themselves.
    open_page("look-wordy.html", 375)
    pick('#vd-a button[aria-label^="Pick"]')
    title_order_on("look-wordy.html", 375, [3, 1, 2])


def picked_label_wraps():
    # 2560 wide, a title has room for its label and every button on one row; at 375 the picked frame's label fits a row alone, not beside Focus and Note.
    open_page("look-harbour.html", 2560)
    shown = pick(PICK_B)
    roomy = js(FRAMES)[1]
    open_page("look-harbour.html", 375)
    tight = js(FRAMES)[1]
    page = js("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    names = [b["text"] for b in tight["buttons"]]
    case("a Picked label wraps the title's buttons to a second row at 375 before any shrinks",
         shown and names == ["Focus", "Picked with Harbour morning, Soft, Serif", "Note"] and title_rows(roomy) == 1 and title_rows(tight) > 1
         and widths(tight) == widths(roomy) and inside_title(tight) and page[0] <= page[1],
         "B is picked and its buttons read %s: rows its badge and buttons take at 2560 %d (want 1), at 375 %d (want over 1); widths at 375 %s against %s at 2560;"
         " inside the title %s; the page is %d px wide in a %d px viewport"
         % (names, title_rows(roomy), title_rows(tight), widths(tight), widths(roomy), inside_title(tight), page[0], page[1]))
    # The label is wider than its title row (see build_pages), so it has to fold inside its button.
    open_page("look-wordy.html", 375)
    shown = pick(PICK_B)
    frame = js(FRAMES)[1]
    page = js("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    names = [b["text"] for b in frame["buttons"]]
    heights = [round(b["box"]["bottom"] - b["box"]["top"], 1) for b in frame["buttons"]]
    case("a Picked label longer than the title row folds inside its button at 375",
         shown and names == ["Focus", WORDY, "Note"] and inside_title(frame) and heights[1] > heights[0] and page[0] <= page[1],
         "B is picked and its buttons read %s: inside the title %s (the title spans %.1f to %.1f, the buttons %s), button heights %s (want the label's over Focus's);"
         " the page is %d px wide in a %d px viewport"
         % (names, inside_title(frame), frame["title"]["left"], frame["title"]["right"],
            [[round(b["box"]["left"], 1), round(b["box"]["right"], 1)] for b in frame["buttons"]], heights, page[0], page[1]))


def title_targets():
    harbour = "Picked with Harbour morning, Soft, Serif"
    small, counts, labels, stacked = [], [], [], 0
    # A page with no look, then one whose picked frame's label wraps its title's buttons into rows (see build_pages).
    for page in ("layout-3.html", "look-harbour.html"):
        for width in (375, 768, 1280):
            open_page(page, width)
            if (page, width) == ("look-harbour.html", 375):
                pick(PICK_B)
            frames = js(FRAMES)
            buttons = [b for f in frames for b in f["buttons"]]
            counts.append(len(buttons))
            small += ["%s at %d: %s %.1fx%.1f" % (page, width, b["text"], b["box"]["width"], b["box"]["bottom"] - b["box"]["top"])
                      for b in buttons if min(b["box"]["width"], b["box"]["bottom"] - b["box"]["top"]) < 24]
            if page == "look-harbour.html":
                labels.append(frames[1]["buttons"][1]["text"])
                if width == 375:
                    stacked = len({round(b["box"]["top"]) for b in frames[1]["buttons"]})
    case("title buttons are at least 24 px in both directions at 375, 768 and 1280",
         not small and counts == [9] * 6 and labels == [harbour] * 3 and stacked > 1,
         "under 24 px wide or tall, as page at width: text and size, %s; buttons measured per page and width %s (want 9 each);"
         " on look-harbour.html B's second button reads %s at the three widths (want %s each) and its buttons take %d rows at 375 (want over 1)"
         % (list(dict.fromkeys(small)), counts, labels, harbour, stacked))


# The first frame's primary button as [fill, text], then the bar of its info alert.
ACCENTS = """(() => { const css = (el, p) => getComputedStyle(el).getPropertyValue(p), c = document.querySelector('.vd-content'), b = c.querySelector('.vd-btn.vd-primary');
  return [css(b, 'background-color'), css(b, 'color'), css(c.querySelector('.vd-alert'), 'border-inline-start-color')]; })()"""
BERRY_ACCENTS = ["rgb(190, 24, 93)", "rgb(255, 255, 255)", "rgb(190, 24, 93)"]
NEUTRAL_ACCENTS = ["rgb(37, 99, 235)", "rgb(255, 255, 255)", "rgb(37, 99, 235)"]


def print_in_light():
    open_page(LOOK, 1280)
    # No fixture frame holds an alert, whose info bar follows the primary colour.
    js("(() => { const a = document.createElement('div'); a.className = 'vd-alert'; a.textContent = 'Two invoices are overdue.';"
       " document.querySelector('.vd-content').append(a); })()")
    click("#vd-scheme-toggle")
    seen = []
    for palette in ("Berry", "Neutral"):
        switch("palette", palette)
        on_screen = colours(js(LOOK_PROBE))
        cdp.call("Emulation.setEmulatedMedia", {"media": "print"})
        seen.append([on_screen, colours(js(LOOK_PROBE)), js(ACCENTS)])
        cdp.call("Emulation.setEmulatedMedia", {"media": ""})
    case("print renders frame content in the light set under the dark scheme",
         seen == [[[BERRY_DARK] * 5, [BERRY] * 5, BERRY_ACCENTS], [[NEUTRAL_DARK] * 5, [NEUTRAL] * 5, NEUTRAL_ACCENTS]],
         "on the dark scheme, under Berry then Neutral, as [frames on screen, frames under print media, the first frame's primary button fill and text and its info alert's bar]:"
         " %s (want Berry's dark set then its light set and %s; the shell's dark neutrals then its light ones and %s)" % (seen, BERRY_ACCENTS, NEUTRAL_ACCENTS))


# The header's drawn disclosure controls as [text, aria-expanded] and whether one has focus; each drawn switcher's kind, top and right edge, [scrollWidth, clientWidth, scrollLeft] and option names; the header's height, the viewport as [width, height], the page as [scrollWidth, clientWidth, scrollX].
FOLD = """(() => { const drawn = el => el.getClientRects().length > 0, header = document.getElementById('vd-header'), root = document.documentElement;
  const controls = Array.from(header.querySelectorAll('button[aria-expanded]')).filter(drawn);
  return { controls: controls.map(b => [b.textContent, b.getAttribute('aria-expanded')]), focused: controls.includes(document.activeElement),
           switchers: Array.from(document.querySelectorAll('[data-vd-switcher]')).filter(drawn).map(g => { const r = g.getBoundingClientRect();
             return { kind: g.dataset.vdSwitcher, top: r.top, right: r.right, inner: [g.scrollWidth, g.clientWidth, g.scrollLeft],
                      options: Array.from(g.querySelectorAll('button')).map(b => b.dataset.vdOption) }; }),
           header: header.getBoundingClientRect().height, viewport: [innerWidth, innerHeight], page: [root.scrollWidth, root.clientWidth, scrollX] }; })()"""
LOOK_CONTROL = "#vd-header button[aria-expanded]"
CLOSED, OPEN = [["Look", "false"]], [["Look", "true"]]
AS_FOLD = "as [disclosure controls drawn in the header as [text, aria-expanded]; switchers drawn]"


def drawn(fold):
    """What a FOLD answer shows: its disclosure controls, and its switchers as [kind, option names]."""
    return [fold["controls"], [[s["kind"], s["options"]] for s in fold["switchers"]]]


def look_by_click():
    open_page(LOOK, 375)
    closed = js(FOLD)
    case("at 375 the switcher row is one closed Look control", drawn(closed) == [CLOSED, []], "%s %s" % (AS_FOLD, drawn(closed)))
    click(LOOK_CONTROL)
    opened = js(FOLD)
    tops = [s["top"] for s in opened["switchers"]]
    switch("palette", "Berry")
    chosen = [colours(js(LOOK_PROBE)), drawn(js(FOLD))]
    click(LOOK_CONTROL)
    shut = js(FOLD)
    case("Look disclosure opens and closes by click at 375 and shows every switcher stacked",
         drawn(opened) == [OPEN, OPTIONS] and all(a < b for a, b in zip(tops, tops[1:])) and opened["page"][0] <= opened["page"][1]
         and drawn(shut) == [CLOSED, []],
         "%s after one click %s with switcher tops %s on a page %d px wide in a %d px viewport, after a second click %s"
         % (AS_FOLD, drawn(opened), tops, opened["page"][0], opened["page"][1], drawn(shut)))
    case("an option chosen inside Look at 375 restyles every frame and leaves Look open", chosen == [[BERRY] * 5, [OPEN, OPTIONS]],
         "Berry was clicked with Look open: per frame [paper, ink, nav bar, nav text] %s (want %s), then %s %s" % (chosen[0], BERRY, AS_FOLD, chosen[1]))


def groups_stack():
    # At 375 these options take a line per group however the row is laid out; at 430 Style and Type would fit on one.
    open_page(LOOK, 430)
    click(LOOK_CONTROL)
    got = js(FOLD)
    tops = [s["top"] for s in got["switchers"]]
    case("open Look stacks its groups one per line at 430", drawn(got) == [OPEN, OPTIONS] and all(a < b for a, b in zip(tops, tops[1:])),
         "%s %s with switcher tops %s" % (AS_FOLD, drawn(got), tops))


def look_by_enter():
    open_page(LOOK, 375)
    reached = False
    for _ in range(40):
        key("Tab")
        if js(FOLD)["focused"]:
            reached = True
            break
    states = []
    # Enter on whatever else had focus would press that instead.
    for _ in range(2 if reached else 0):
        key("Enter")
        got = js(FOLD)
        states.append(drawn(got) + [got["focused"]])
    case("Look disclosure opens by Enter at 375", states == [[OPEN, OPTIONS, True], [CLOSED, [], True]],
         "Tab reached a disclosure control: %s; after each Enter %s and whether focus is still on the control: %s" % (reached, AS_FOLD, states))


def version_picker():
    """True once the version picker shows: it fills in after the feedback controls, and at 375 adds a line to the header."""
    return wait("!document.getElementById('vd-versions').hidden")


def closed_header():
    open_page("look-6.html", 375)
    listed_versions = version_picker()
    got = js(FOLD)
    frames = js("document.querySelectorAll('.vd-frame').length")
    case("closed header under 40 percent at 375", listed_versions and frames == 6 and drawn(got) == [CLOSED, []] and got["header"] <= 0.4 * got["viewport"][1],
         "the header is %.1f px in a viewport %d px tall (%.1f%%, want 40%% at most) on %d frames; the version picker is showing: %s; %s %s"
         % (got["header"], got["viewport"][1], 100 * got["header"] / got["viewport"][1], frames, listed_versions, AS_FOLD, drawn(got)))


def no_look_when_wide():
    for width in (768, 1280):
        open_page(LOOK, width)
        got = js(FOLD)
        tops = [s["top"] for s in got["switchers"]]
        case("no Look control and the switchers inline at 768 and 1280", drawn(got) == [[], OPTIONS] and len(set(tops)) == 1,
             "at %d: %s %s with switcher tops %s (want one line)" % (width, AS_FOLD, drawn(got), tops))


# The window's width, the page as [scrollWidth, clientWidth], and each drawn switcher: its kind, [scrollWidth, clientWidth, scrollLeft], and per option its name, left and right edge, top, height, aria-pressed, and whether it lies inside the switcher's box.
WRAPPED = """(() => { const root = document.documentElement;
  return { window: innerWidth, page: [root.scrollWidth, root.clientWidth],
           switchers: Array.from(document.querySelectorAll('[data-vd-switcher]')).filter(g => g.getClientRects().length > 0).map(g => { const box = g.getBoundingClientRect();
             return { kind: g.dataset.vdSwitcher, inner: [g.scrollWidth, g.clientWidth, g.scrollLeft], options: Array.from(g.querySelectorAll('button')).map(b => {
               const r = b.getBoundingClientRect();
               return { name: b.dataset.vdOption, left: r.left, right: r.right, top: r.top, height: r.height, pressed: b.getAttribute('aria-pressed'),
                        inside: r.left >= box.left - .5 && r.right <= box.right + .5 && r.top >= box.top - .5 && r.bottom <= box.bottom + .5 }; }) }; }) }; })()"""


def lines(switcher):
    """How many lines a WRAPPED switcher's options take."""
    return len({round(o["top"]) for o in switcher["options"]})


def misfits(got):
    """What a WRAPPED answer shows out of place, in words: a switcher or a page with something to scroll sideways, an option outside its switcher or the window, an option under 24 px tall."""
    out = ["the page is %d px wide in %d" % tuple(got["page"])] if got["page"][0] > got["page"][1] else []
    for s in got["switchers"]:
        if s["inner"][0] > s["inner"][1] or s["inner"][2]:
            out.append("%s holds %d px in %d, scrolled %d" % (s["kind"], s["inner"][0], s["inner"][1], s["inner"][2]))
        for o in s["options"]:
            if not o["inside"] or o["left"] < -0.5 or o["right"] > got["window"] + 0.5:
                out.append("%s spans %.1f to %.1f in a window %d wide, inside its switcher: %s" % (o["name"], o["left"], o["right"], got["window"], o["inside"]))
            if o["height"] < 24:
                out.append("%s is %.1f px tall" % (o["name"], o["height"]))
    return out


def switchers_wrap():
    # Every name on this page is 24 characters, four per kind (see build_pages).
    for width in (320, 375):
        open_page("look-24.html", width)
        click(LOOK_CONTROL)
        got = js(WRAPPED)
        took = [[s["kind"], len(s["options"]), lines(s)] for s in got["switchers"]]
        case("four 24-character options wrap inside their switcher at 320 and 375: nothing scrolls sideways, each option in the window and 24 px tall",
             [t[:2] for t in took] == [["palette", 4], ["style", 4], ["type", 4]] and all(t[2] > 1 for t in took) and not misfits(got),
             "at %d: switchers as [kind, options, lines they take] %s (want four options on more than one line each); out of place: %s" % (width, took, misfits(got)))
    switch("palette", NAMES_LAST)
    got = js(WRAPPED)
    pressed = [o["name"] for o in got["switchers"][0]["options"] if o["pressed"] == "true"]
    active = js("document.documentElement.getAttribute('data-vd-palette')")
    case("the last option of a wrapped switcher is clicked where it is drawn and shows pressed in the window",
         pressed == [NAMES_LAST] and active == NAMES_LAST and not misfits(got),
         "at 375 a click on %s: pressed options of the palette switcher %s, html says %s; out of place: %s" % (NAMES_LAST, pressed, active, misfits(got)))
    # Four palettes whose names fit a line each, not one line together (see build_pages).
    open_page("look-long.html", 375)
    click(LOOK_CONTROL)
    got = js(WRAPPED)
    palette = got["switchers"][0]
    case("a switcher too wide for 375 wraps onto further lines", len(palette["options"]) == 4 and lines(palette) > 1 and not misfits(got),
         "the palette switcher's four options take %d lines (want over 1); out of place: %s" % (lines(palette), misfits(got)))
    # The shell's own text makes an option 28 px tall: smaller text shows whether 24 px is a floor or an accident of the font.
    js("document.head.insertAdjacentHTML('beforeend', '<style>[data-vd-switcher] button { font-size: 8px; line-height: 1; padding-block: 2px; }</style>')")
    heights = sorted({round(o["height"], 1) for o in js(WRAPPED)["switchers"][0]["options"]})
    case("an option whose text and padding come to under 24 px is still a 24 px target at 375", heights == [24],
         "with 8 px text and 2 px of padding above and below, the palette options are %s px tall (want 24)" % heights)


# For the frame at this position: the header's bottom edge, the frame's title row as [top, bottom], the viewport's height, and how much further the page could scroll once the frame's top met the viewport's top (under 0: it cannot get there, so nothing could cover it).
REACHED = """(i => { const f = document.querySelectorAll('.vd-frame')[i], t = f.querySelector('h2').getBoundingClientRect(), root = document.documentElement;
  return { header: document.getElementById('vd-header').getBoundingClientRect().bottom, title: [t.top, t.bottom], viewport: innerHeight,
           room: root.scrollHeight - innerHeight - (f.getBoundingClientRect().top + scrollY) }; })(%d)"""


def clears_header():
    # 500 tall at 1280: at 800 the second row of frames cannot reach the top of the viewport.
    for width, height, by_key, by_link in ((375, 800, 2, 4), (1280, 500, 5, 6)):
        open_page("look-6.html", width, height=height)
        version_picker()
        # Two animation frames: whatever the header's last change of height set off has run.
        js("new Promise(done => requestAnimationFrame(() => requestAnimationFrame(done)))")
        key(str(by_key))
        seen = [["key %d" % by_key, js(FOCUSED) == by_key - 1, js(REACHED % (by_key - 1))]]
        js("scrollTo(0, 0)")
        click('nav[aria-label="Jump to variant"] a:nth-of-type(%d)' % by_link)
        seen.append(["jump link %s" % LETTERS[by_link - 1], js("location.hash") == "#vd-" + LETTERS[by_link - 1].lower(), js(REACHED % (by_link - 1))])
        for how, arrived, at in seen:
            case("a frame reached by key or jump link clears the sticky header",
                 arrived and at["room"] >= 0 and at["header"] <= at["title"][0] and at["title"][1] <= at["viewport"],
                 "at %d by %d, %s: it got there: %s; the header ends at %.1f and the frame's title row spans %s in a viewport %d tall;"
                 " the page could scroll %.1f px past the frame's top (under 0: this page cannot prove it)"
                 % (width, height, how, arrived, at["header"], [round(v, 1) for v in at["title"]], at["viewport"], at["room"]))


TWO_FRAMES = "new Promise(done => requestAnimationFrame(() => requestAnimationFrame(done)))"
TO_THE_END = "scrollTo(0, document.documentElement.scrollHeight)"
# The header's top edge and height, whether it is laid out to stick, the room frames leave for it (--vd-header-h), how far the page is scrolled and the window's height.
HEADER = """(() => { const h = document.getElementById('vd-header');
  return { top: h.getBoundingClientRect().top, height: h.offsetHeight, sticky: getComputedStyle(h).position === 'sticky',
           room: getComputedStyle(document.documentElement).getPropertyValue('--vd-header-h').trim(), scrolled: scrollY, viewport: innerHeight }; })()"""
# The header as [laid out to stick, --vd-header-h, its height, the window's height] on each of six animation frames, from the second one on.
SETTLED = """new Promise(done => { const h = document.getElementById('vd-header'), seen = []; let n = 0;
  (function next() { requestAnimationFrame(() => { n += 1;
    if (n >= 2) seen.push([getComputedStyle(h).position === 'sticky', getComputedStyle(document.documentElement).getPropertyValue('--vd-header-h').trim(), h.offsetHeight, innerHeight]);
    if (n < 7) next(); else done(seen); }); })(); })"""


def window_height(width, height):
    """Resize the open page's window, as a person dragging its edge does; True once the page sees the new height."""
    cdp.call("Emulation.setDeviceMetricsOverride", {"width": width, "height": height, "deviceScaleFactor": 1, "mobile": False})
    return wait("innerHeight === %d" % height)


def stuck(header):
    """Whether a HEADER answer read on a scrolled page shows the header at the window's top with its whole height kept clear for it."""
    return header["scrolled"] > 0 and header["top"] == 0 and header["sticky"] and header["room"] == "%dpx" % header["height"]


def tall_header():
    open_page("look-6.html", 320, height=480)
    version_picker()
    click(LOOK_CONTROL)
    js(TWO_FRAMES)
    key("2")
    focused, at, header = js(FOCUSED), js(REACHED % 1), js(HEADER)
    case("at 320 by 480 with Look open a frame reached by a number key shows its title in the window and holds focus",
         focused == 1 and at["room"] >= 0 and 0 <= at["title"][0] and at["title"][1] <= at["viewport"] and at["header"] <= at["title"][0]
         and header["room"] == "0px" and header["top"] < 0 and 20 * header["height"] > 11 * header["viewport"],
         "key 2 put focus on frame position %d (want 1); its title row spans %s in a window %d tall, the header ends at %.1f; the header is %d px tall, its top at %.1f"
         " (want above the window: it scrolled away), --vd-header-h %r (want '0px')"
         % (focused, [round(v, 1) for v in at["title"]], at["viewport"], at["header"], header["height"], header["top"], header["room"]))
    for width, height in ((375, 800), (1280, 800)):
        open_page("look-6.html", width, height=height)
        version_picker()
        js(TWO_FRAMES)
        js(TO_THE_END)
        header = js(HEADER)
        case("a header at most half the window's height still sticks, at 375 by 800 with six frames and Look closed and at 1280 by 800",
             stuck(header) and header["height"] <= height / 2,
             "at %d by %d, scrolled to the page's end: %s (want top 0, sticky, --vd-header-h its height)" % (width, height, header))


def header_threshold():
    open_page("look-6.html", 375, height=800)
    version_picker()
    # 297 px is 55% of a 540 px window and 45% of a 660 px one: both thresholds fall on a whole pixel.
    js("document.head.insertAdjacentHTML('beforeend', '<style>#vd-header { block-size: 297px; }</style>')")
    js(TWO_FRAMES)
    tall = js(HEADER)["height"]
    steps = [(540, True), (539, False), (659, False), (660, True), (600, True), (539, False), (600, False)]
    seen = []
    for height, _ in steps:
        resized = window_height(375, height)
        seen.append([resized, js(SETTLED)])
    want = [[True, [[sticks, "297px" if sticks else "0px", 297, height]] * 6] for height, sticks in steps]
    case("the header unsticks over 55% of the window's height and sticks again at 45%, to the pixel, keeps its state between the two, and settles in two animation frames",
         tall == 297 and seen == want, "the header is held %d px tall (want 297) and starts stuck in a window 800 tall; per window height %s, as [the page saw the resize,"
         " per animation frame from the second to the seventh [laid out to stick, --vd-header-h, the header's height, the window's height]]: %s (want %s)"
         % (tall, [height for height, _ in steps], seen, want))


def static_header():
    # A screenshot's page first sees a window shorter than the one it is captured in: what it was there must not show in the picture.
    open_page("look-6.html", 375, static=True, height=800)
    js("document.head.insertAdjacentHTML('beforeend', '<style>#vd-header { block-size: 297px; }</style>')")
    js(TWO_FRAMES)
    tall = js(HEADER)["height"]
    seen = []
    for height in (539, 600):
        resized = window_height(375, height)
        seen.append([resized, js(SETTLED)])
    want = [[True, [[False, "0px", 297, 539]] * 6], [True, [[True, "297px", 297, 600]] * 6]]
    case("a page loaded with ?static=1 keeps no header state: unstuck in one window, it sticks in the next where a page that loads there sticks",
         tall == 297 and seen == want, "the header is held %d px tall (want 297); in a window 539 tall, then 600, where a live page would stay unstuck, as [the page saw"
         " the resize, per animation frame from the second to the seventh [laid out to stick, --vd-header-h, the header's height, the window's height]]: %s (want %s)"
         % (tall, seen, want))


HEADER_BUTTON = '[data-vd-set-mode="side"]'


def focus_in_header_then_scroll():
    """Click a header button, which keeps focus, then scroll the page to its third frame; True when focus is still on that button."""
    press_where_drawn(HEADER_BUTTON)
    js("document.querySelectorAll('.vd-frame')[2].scrollIntoView()")
    js(TWO_FRAMES)
    return js("document.activeElement === document.querySelector(%s)" % json.dumps(HEADER_BUTTON))


def url_bar():
    # A 375 by 667 phone: its window is 628 px tall with the URL bar slid away and 553 with it showing.
    open_page("look-6.html", 375, height=628)
    version_picker()
    js(TWO_FRAMES)
    focused = focus_in_header_then_scroll()
    first = js(HEADER)
    tall, seen = first["height"], []
    for height in (553, 628, 553, 628):
        resized = window_height(375, height)
        js(TWO_FRAMES)
        header = js(HEADER)
        seen.append([height, resized, header["sticky"], header["scrolled"]])
    case("a window stepped 628, 553, 628, 553, 628 px tall under a focused header button leaves the header in one state and the page where it was scrolled",
         focused and 553 < 2 * tall <= 628 and stuck(first) and all(s[1] for s in seen) and len({s[2] for s in seen}) == 1
         and all(s[3] == first["scrolled"] for s in seen),
         "the header is %d px tall (want over half of 553 and at most half of 628, so one threshold at half would flip it), a header button has focus: %s;"
         " at 628 on load, scrolled to the third frame: %s (want stuck); per step as [window height, the page saw the resize, laid out to stick, scrollY] %s"
         " (want one stuck state and scrollY %s throughout)" % (tall, focused, first, seen, first["scrolled"]))


def window_made_shorter():
    open_page("look-6.html", 375, height=800)
    version_picker()
    js(TWO_FRAMES)
    focused = focus_in_header_then_scroll()
    before = js(HEADER)
    tall = before["height"]
    resized = window_height(375, 480)
    js(TWO_FRAMES)
    after = js(HEADER)
    case("a window made shorter until the header is over 55% of it unsticks the header and leaves the page where it was scrolled, a header button focused",
         focused and resized and 20 * tall > 11 * 480 and stuck(before) and not after["sticky"] and after["room"] == "0px" and after["top"] < 0
         and after["scrolled"] == before["scrolled"],
         "a header button has focus: %s; at 375 by 800, scrolled to the third frame: %s (want stuck); at 375 by 480: %s"
         " (want not sticky, --vd-header-h 0px, its top above the window and scrollY %s)" % (focused, before, after, before["scrolled"]))
    resized = window_height(375, 2 * tall)
    js(TWO_FRAMES)
    between = js(HEADER)
    taller = window_height(375, 800)
    js(TWO_FRAMES)
    again = js(HEADER)
    case("an unstuck header stays unstuck in a window that leaves it between 45% and 55%, and sticks again in one that leaves it at most 45%",
         resized and taller and 20 * tall <= 9 * 800 and not between["sticky"] and between["room"] == "0px" and stuck(again),
         "the header is %d px tall and unstuck at 375 by 480; at 375 by %d, where it is half the window: %s (want not sticky, --vd-header-h 0px);"
         " at 375 by 800: %s (want top 0, sticky, --vd-header-h its height)" % (tall, 2 * tall, between, again))


# The Look control's top and bottom edge in the window, whether it has focus, and its aria-expanded.
LOOK_AT = """(b => { const r = b.getBoundingClientRect(); return { span: [r.top, r.bottom], focused: document.activeElement === b, open: b.getAttribute('aria-expanded') }; })
  (document.querySelector('#vd-header button[aria-expanded]'))"""


def press_where_drawn(selector):
    """A real mouse click on the first element matching the selector, where it is drawn now: click() would first scroll it to the window's middle."""
    at = js("(r => [r.left + r.width / 2, r.top + r.height / 2])(document.querySelector(%s).getBoundingClientRect())" % json.dumps(selector))
    for kind in ("mousePressed", "mouseReleased"):
        cdp.call("Input.dispatchMouseEvent", {"type": kind, "x": at[0], "y": at[1], "button": "left", "clickCount": 1})


def header_follows_look():
    open_page("look-6.html", 375, height=800)
    version_picker()
    js(TWO_FRAMES)
    closed = js(HEADER)["height"]
    js(TO_THE_END)
    press_where_drawn(LOOK_CONTROL)
    js(TWO_FRAMES)
    roomy, look = js(HEADER), js(LOOK_AT)
    opened = roomy["height"]
    case("Look opened on a scrolled page at 375 by 800 leaves the header stuck: open, it is at most 55% of the window",
         closed < opened and 20 * opened <= 11 * 800 and stuck(roomy) and look["open"] == "true" and look["focused"]
         and 0 <= look["span"][0] and look["span"][1] <= roomy["viewport"],
         "closed the header is %d px, open %d px, in a window 800 tall. Scrolled to the page's end, after a click on Look: %s (want top 0, sticky,"
         " --vd-header-h its height); the Look control spans %s, has focus: %s, aria-expanded %s"
         % (closed, opened, roomy, [round(v, 1) for v in look["span"]], look["focused"], look["open"]))
    press_where_drawn(LOOK_CONTROL)
    js(TWO_FRAMES)
    # A window in which the closed header is at most 45% and the open one over 55%.
    low, high = -(-20 * closed // 9), (20 * opened - 1) // 11
    height = (low + high) // 2
    resized = low <= high and window_height(375, height)
    js(TO_THE_END)
    js(TWO_FRAMES)
    before = js(HEADER)
    press_where_drawn(LOOK_CONTROL)
    js(TWO_FRAMES)
    open_now, look = js(HEADER), js(LOOK_AT)
    js(TO_THE_END)
    away = js(HEADER)
    click(LOOK_CONTROL)
    js(TWO_FRAMES)
    js(TO_THE_END)
    again = js(HEADER)
    case("the header stops sticking when Look opens it past 55% of the window, and sticks again once Look is closed and it is at most 45%",
         resized and closed < opened and stuck(before) and before["height"] == closed and not open_now["sticky"] and open_now["room"] == "0px"
         and open_now["height"] == opened and away["top"] < 0 and stuck(again) and again["height"] == closed,
         "closed the header is %d px, open %d px, in a window %d tall (any from %d to %d leaves it at most 45%% closed and over 55%% open)."
         " Scrolled to the page's end with Look closed: %s; after a click on Look: %s;"
         " scrolled to the end again: %s (want its top above the window); after Look is closed, scrolled to the end: %s"
         % (closed, opened, height, low, high, before, open_now, away, again))
    case("Look opened on a scrolled page stays in the window, with focus, when its header stops sticking",
         before["scrolled"] > 0 and look["open"] == "true" and look["focused"] and -0.5 <= look["span"][0] and look["span"][1] <= open_now["viewport"] + 0.5,
         "the page was scrolled %d px with the header stuck when Look was clicked: the Look control then spans %s in a window %d tall (want inside it, to half a pixel),"
         " has focus: %s, aria-expanded %s" % (before["scrolled"], [round(v, 1) for v in look["span"]], open_now["viewport"], look["focused"], look["open"]))


class Refuser:
    """A second server for the docroot's pages, on a free port. POST /_feedback answers self.status, with self.body as self.kind when a body is set, and keeps the row only when the status is 200; GET /_feedback answers the rows kept, and GET /_checks an unchecked page, in the shapes the shell reads from serve.py."""

    def __init__(self):
        stub = self
        self.status, self.rows, self.posts, self.body, self.kind = 400, [], 0, None, "application/json"

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def answer(self, status, body, kind="application/json"):
                self.send_response(status)
                self.send_header("Content-Type", kind)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def do_GET(self):
                path, _, query = self.path.partition("?")
                file = os.path.join(docroot, os.path.basename(path))
                if path == "/_feedback":
                    page = parse_qs(query).get("page", [""])[0]
                    self.answer(200, json.dumps({"rows": [r for r in stub.rows if r["page"] == page]}).encode("utf-8"))
                elif path == "/_checks":
                    self.answer(200, b'{"checked": false, "findings": 0}')
                elif path.endswith(".html") and os.path.isfile(file):
                    with open(file, "rb") as handle:
                        self.answer(200, handle.read(), "text/html; charset=utf-8")
                else:
                    self.answer(404, b"")

            def do_POST(self):
                row = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                if stub.status == 200:
                    stub.rows.append(dict(row, status="open"))
                self.answer(stub.status, json.dumps({"recorded": stub.status == 200}).encode("utf-8") if stub.body is None else stub.body, stub.kind)
                # Counted once answered: a caller that waits for the count may then set the next answer.
                stub.posts += 1

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.base = "http://127.0.0.1:%d/" % self.server.server_address[1]
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def stop(self):
        self.server.shutdown()
        self.server.server_close()


def refusing(body):
    """A group's body run against a Refuser of its own, stopped afterwards."""
    def run():
        stub = Refuser()
        try:
            body(stub)
        finally:
            stub.stop()
    return run


REFUSED = "Not recorded: the server answered 400"
STOPPED = "Not recorded: the server did not answer"
SEND = '#vd-fb-box button[type="submit"]'
# Each text on the page that starts "Not recorded" and is drawn where a pointer reaches it, as [text, px its words lie beside the control, px above or below it, inside the container]; 0 px where the two overlap on that axis. The live region holds such a text and is not drawn.
MESSAGES = """((control, within) => { const c = document.querySelector(control).getBoundingClientRect(), w = document.querySelector(within).getBoundingClientRect();
  const words = el => { const range = document.createRange(); range.selectNodeContents(el); return range.getBoundingClientRect(); };
  return Array.from(document.querySelectorAll('body *')).filter(el => !el.children.length && el.textContent.startsWith('Not recorded'))
    .map(el => [el, words(el)])
    .filter(([el, r]) => r.width > 1 && r.height > 1 && document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2) === el)
    .map(([el, r]) => [el.textContent, Math.round(Math.max(r.left - c.right, c.left - r.right, 0)), Math.round(Math.max(r.top - c.bottom, c.top - r.bottom, 0)),
                       r.left >= w.left && r.right <= w.right && r.top >= w.top && r.bottom <= w.bottom]); })(%s, %s)"""
AS_MESSAGES = "as [text, px beside the control, px above or below it, inside %s]"


def messages(control, within, ms=0, text=None):
    """The refusal messages drawn on the open page, placed against a control and a container; with ms, after waiting that long at most for one to show, or with text for one that reads it."""
    probe = MESSAGES % (json.dumps(control), json.dumps(within))
    if ms:
        wait(probe + (".length > 0" if text is None else ".some(m => m[0] === %s)" % json.dumps(text)), ms)
    return js(probe)


def under_pick(got, text):
    """Whether got is one message reading text inside its title, its words on the line under the Pick button: no px to either side of it, 12 at most below."""
    return len(got) == 1 and got[0][0] == text and got[0][1] == 0 and got[0][2] <= 12 and got[0][3]


def on_send_row(got, text):
    """Whether got is one message reading text inside the note box, its words on Send note's row."""
    return len(got) == 1 and got[0][0] == text and got[0][2] == 0 and got[0][3]


def refused_pick(stub):
    title = "#vd-b > h2"
    open_page("layout-5.html", 1280, at=stub.base)
    js("void (window.vdRegions = Array.from(document.querySelectorAll('[role=\"status\"], [role=\"alert\"], [aria-live]')))")
    click(PICK_B)
    got, states = messages(PICK_B, title, 3000), pick_states()
    case("refused pick shows a visible message and is not marked Picked", under_pick(got, REFUSED) and states == [PICK] * 5,
         "B's pick was answered 400: messages drawn %s %s (want one reading %s under the Pick button, 12 px below at most); Pick buttons %s"
         % (AS_MESSAGES % "B's title", got, REFUSED, states))
    regions = js("window.vdRegions.filter(el => el.isConnected).map(el => el.textContent)")
    case("refused post is announced", REFUSED in regions,
         "B's pick was answered 400: the live regions the page had before the pick read %s (want one reading %s)" % (regions, REFUSED))
    case("a refused pick is posted once", posted(stub, 1) and stub.posts == 1, "the server refused B's pick and answered %d posts" % stub.posts)
    said = computed(PICK_B, "description")
    case("a refused post's message is its control's accessible description", said == REFUSED,
         "the browser computes B's Pick button the description %r (want %r)" % (said, REFUSED))
    cdp.call("Emulation.setEmulatedMedia", {"media": "print"})
    printed = messages(PICK_B, title)
    cdp.call("Emulation.setEmulatedMedia", {"media": ""})
    case("a refused pick's message is not printed", printed == [], "under print media, where no Pick button is drawn, messages drawn %s" % printed)
    stub.status = 200
    stored = pick(PICK_B)
    got, states = messages(PICK_B, title), pick_states()
    case("a refused pick's message is gone once the next pick from that control is stored", stored and got == [] and states == [PICK, PICKED] + [PICK] * 3,
         "B's pick was answered 400, then 200: messages drawn %s (want none); Pick buttons %s" % (got, states))


def refused_note(stub):
    open_page("layout-5.html", 1280, at=stub.base)
    seen = []
    # Both ways into the one note box: the frame's own Note button, then Point & note on an element of that frame.
    for opened_by in ("Note on variant B", "Point & note"):
        if opened_by == "Point & note":
            click("#vd-fb-toggle")
            click("#vd-b .vd-content h3")
        else:
            click('#vd-b button[aria-label="Note on variant B"]')
        typing = wait("document.activeElement === document.getElementById('vd-fb-text')")
        on_open = messages(SEND, "#vd-fb-box")
        key("n")
        click(SEND)
        seen.append([typing, on_open, messages(SEND, "#vd-fb-box", 3000), js("document.getElementById('vd-fb-box').hidden"), computed(SEND, "description")])
        click("#vd-fb-cancel")
    (typing, _, got, closed, said), (pointing, on_open, pointed, pointed_closed, _) = seen
    detail = "a note on B was answered 400: the note box took focus: %s, closed: %s; messages drawn %s %s (want one reading %s on Send note's row)"
    case("refused note shows a visible message", typing and not closed and on_send_row(got, REFUSED),
         detail % (typing, closed, AS_MESSAGES % "the note box", got, REFUSED))
    case("a refused note sent from Point & note shows a visible message", pointing and not pointed_closed and on_send_row(pointed, REFUSED),
         "from Point & note, " + detail % (pointing, pointed_closed, AS_MESSAGES % "the note box", pointed, REFUSED))
    case("a refused post's message is its control's accessible description", said == REFUSED,
         "the browser computes Send note the description %r (want %r)" % (said, REFUSED))
    case("a note box opened after a refused note starts with no message", on_open == [],
         "the first note was refused and its box cancelled: the next box opened with messages drawn %s" % on_open)


def refused_pick_at_375(stub):
    pick_c, title = '#vd-c button[aria-label^="Pick"]', "#vd-c > h2"
    # The third frame's label cannot fold (see build_pages): its title's buttons wrap before the message joins them.
    open_page("layout-3.html", 375, at=stub.base)
    before = js(FRAMES)[2]
    click(pick_c)
    got, after = messages(pick_c, title, 3000), js(FRAMES)[2]
    page = js("[document.documentElement.scrollWidth, document.documentElement.clientWidth]")
    case("a refused pick's message at 375 leaves the title's buttons at full width with no sideways scroll",
         under_pick(got, REFUSED) and widths(after) == widths(before) and inside_title(after) and page[0] <= page[1],
         "C's pick was answered 400: messages drawn %s %s; button widths %s against %s before the pick; buttons inside the title %s;"
         " the page is %d px wide in a %d px viewport" % (AS_MESSAGES % "C's title", got, widths(after), widths(before), inside_title(after), page[0], page[1]))


# serve.py's sentence for a full feedback file; markup a page that wrote it as HTML would run; a sentence past the 200 characters the page shows, cut inside a word.
FULL = ".feedback.jsonl has reached its 2 MiB cap; move it aside to record more"
MARKUP = '<img src="x" onerror="window.vdRan = 1"><b>bold</b>'
LONG = "The disk that holds the feedback file is full. " * 7


def posted(stub, n, seconds=3):
    """True once the stub has answered n posts in all."""
    until = time.monotonic() + seconds
    while stub.posts < n and time.monotonic() < until:
        time.sleep(0.01)
    return stub.posts >= n


# The note box's top and bottom edge and its sides in the window, its [scrollWidth, clientWidth], the left and right edge of the refusal's words, Send note's width, whether Send note's centre is in the window with nothing over it once the box has scrolled to it as it does for Tab, and the window's height.
NOTE_BOX = """(() => { const box = document.getElementById('vd-fb-box'), b = box.getBoundingClientRect(), send = box.querySelector('button[type="submit"]');
  send.scrollIntoView({ block: 'nearest' });
  const range = document.createRange(); range.selectNodeContents(document.getElementById('vd-fb-box-refused'));
  const w = range.getBoundingClientRect(), s = send.getBoundingClientRect(), x = s.left + s.width / 2, y = s.top + s.height / 2;
  return { span: [b.top, b.bottom], sides: [b.left, b.right], inner: [box.scrollWidth, box.clientWidth], words: [w.left, w.right], send: s.width,
           reachable: x >= 0 && x <= innerWidth && y >= 0 && y <= innerHeight && document.elementFromPoint(x, y) === send, window: innerHeight }; })()"""


def refused_note_in_a_short_window(stub):
    # 320 by 256 is a 1280 by 1024 screen at 400% zoom; at 320 by 480 the box opens under the title, in the window's lower half.
    seen = {}
    for name, height, sentence in (("words", 256, LONG[:200]), ("token", 256, "W" * 200), ("low", 480, LONG[:200])):
        stub.status, stub.body, sent = 400, json.dumps({"error": sentence}).encode("utf-8"), stub.posts
        open_page("layout-3.html", 320, at=stub.base, height=height)
        click('#vd-b button[aria-label="Note on variant B"]')
        typing = wait("document.activeElement === document.getElementById('vd-fb-text')")
        opened = js(NOTE_BOX)
        key("n")
        click(SEND)
        shown = posted(stub, sent + 1) and wait("document.getElementById('vd-fb-box-refused').textContent === %s" % json.dumps("Not recorded: %s (400)" % sentence), 3000)
        refused = js(NOTE_BOX)
        if refused["reachable"]:
            press_where_drawn(SEND)
        seen[name] = [typing and shown, opened, refused, posted(stub, sent + 2) if refused["reachable"] else False]

    def inside(box):
        return 0 <= box["span"][0] and box["span"][1] <= box["window"]

    ready, opened, refused, sent_again = seen["words"]
    case("a 200-character refusal at 320 by 256 leaves the note box inside the window with Send note reachable",
         ready and inside(refused) and refused["reachable"] and sent_again,
         "a note on B was answered 400 with a sentence of 200 characters and the message drawn: %s; the note box then %s (want its top and bottom edge inside"
         " a window %d tall and Send note's centre in the window with nothing over it); a click on Send note sent a second post: %s"
         % (ready, refused, refused["window"], sent_again))
    ready, opened, refused, sent_again = seen["token"]
    case("a refusal that is one unbroken token of 200 characters wraps inside the note box at 320 by 256",
         ready and inside(refused) and refused["sides"][0] <= refused["words"][0] and refused["words"][1] <= refused["sides"][1]
         and refused["inner"][0] <= refused["inner"][1] and refused["send"] == opened["send"] and sent_again,
         "a note on B was answered 400 with 200 letters and no space and the message drawn: %s; the note box then %s (want the words' edges inside its sides,"
         " nothing to scroll sideways, and Send note %s px wide as before the refusal); a click on Send note sent a second post: %s"
         % (ready, refused, opened["send"], sent_again))
    ready, opened, refused, sent_again = seen["low"]
    grown = refused["span"][1] - refused["span"][0]
    case("a note box that opened low in a 320 by 480 window moves up by what a 200-character refusal adds, and stays inside the window",
         ready and opened["span"][0] + grown > opened["window"] and inside(refused) and refused["reachable"] and sent_again,
         "the box opened spanning %s in a window %d tall and is %.1f px tall with the message (want it too tall for where it opened: the case proves nothing otherwise);"
         " the message was drawn: %s; the note box then %s; a click on Send note sent a second post: %s"
         % ([round(v, 1) for v in opened["span"]], opened["window"], grown, ready, refused, sent_again))


def refusal_in_words(stub):
    title = "#vd-b > h2"
    open_page("layout-5.html", 1280, at=stub.base)
    js("void (window.vdRegions = Array.from(document.querySelectorAll('[role=\"status\"], [role=\"alert\"], [aria-live]')))")
    # A status of its own per answer: the shell leaves a refusal drawn until a post is stored, so two answers that read alike would pass on the first one's message.
    answers = [("the server's sentence", 507, {"error": FULL}, FULL + " (507)"),
               ("no JSON", 500, "<html><body><h1>500</h1><p>Internal error</p></body></html>", "the server answered 500"),
               ("markup", 400, {"error": MARKUP}, MARKUP + " (400)"),
               ("a long sentence", 413, {"error": LONG}, LONG[:200] + " (413)"),
               ("no sentence", 403, {"error": "  "}, "the server answered 403"),
               ("an error that is no string", 409, {"error": {"code": 7}}, "the server answered 409"),
               ("JSON that is no object", 422, None, "the server answered 422")]
    seen, answered = {}, []
    for count, (name, status, body, want) in enumerate(answers, 1):
        stub.status, stub.kind = status, "application/json" if not isinstance(body, str) else "text/html; charset=utf-8"
        stub.body = body.encode("utf-8") if isinstance(body, str) else json.dumps(body).encode("utf-8")
        click(PICK_B)
        answered.append(posted(stub, count))
        seen[name] = [messages(PICK_B, title, 3000, "Not recorded: " + want), "Not recorded: " + want]
        if name == "markup":
            made = js("[document.images.length, document.querySelectorAll('#vd-b > h2 b, [role=\"status\"] b').length, typeof window.vdRan]")
            regions = js("window.vdRegions.filter(el => el.isConnected).map(el => el.textContent)")
    states = pick_states()
    detail = "B's pick was answered %s: messages drawn %s %s (want one reading %s under the Pick button)"

    def shown(name):
        got, want = seen[name]
        return under_pick(got, want), detail % (name, AS_MESSAGES % "B's title", got, want)

    ok, said = shown("the server's sentence")
    case("a refusal that carries a sentence shows it with the status", ok and states == [PICK] * 5, "a 507 with %s; Pick buttons %s" % (said, states))
    ok, said = shown("no JSON")
    case("a refusal with no JSON body shows the status alone", ok, "a 500 with an HTML body; " + said)
    ok, said = shown("markup")
    case("a refusal's sentence is drawn as text, never as markup", ok and made == [0, 0, "undefined"] and seen["markup"][1] in regions,
         "a 400 whose sentence is %s; %s; the page holds [img elements, b elements in B's title and the status regions, typeof the mark its onerror would set] %s"
         " (want [0, 0, 'undefined']); the status regions read %s" % (MARKUP, said, made, regions))
    ok, said = shown("a long sentence")
    case("a refusal's sentence is cut at 200 characters", ok and len(LONG) > 200 and LONG[199:201].isalpha(), "a 413 whose sentence is %d characters; %s" % (len(LONG), said))
    for name, what in (("no sentence", "whose JSON sentence is blank"), ("an error that is no string", "whose JSON error is no string"),
                       ("JSON that is no object", "whose JSON is no object")):
        ok, said = shown(name)
        case("a refusal %s shows the status alone" % what, ok, said)
    case("each refused pick is posted once", all(answered) and stub.posts == len(answers),
         "%d picks were refused and the server answered %d posts; each was answered before its message was read: %s" % (len(answers), stub.posts, answered))


def server_stopped(stub):
    open_page("layout-5.html", 1280, at=stub.base)
    stub.stop()
    click(PICK_B)
    got, states = messages(PICK_B, "#vd-b > h2", 3000), pick_states()
    case("a pick sent to a stopped server shows a visible message and is not marked Picked", under_pick(got, STOPPED) and states == [PICK] * 5,
         "the server stopped before B's pick: messages drawn %s %s (want one reading %s under the Pick button, 12 px below at most); Pick buttons %s"
         % (AS_MESSAGES % "B's title", got, STOPPED, states))


@contextlib.contextmanager
def lock_held():
    """serve.py's feedback lock held from this process: inside the block the server takes a post and answers nothing."""
    fd = os.open(os.path.join(docroot, ".feedback.lock"), os.O_WRONLY | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


NO_ANSWER = "Not recorded: no answer from the server in 10 s"
# The browser's AbortSignal.timeout hands back a 250 ms signal whatever it is asked for, and keeps what it was asked for, in ms, in window.vdWaits: the wait is lowered here, not in the shell.
SHORT_WAIT = """(() => { const real = AbortSignal.timeout.bind(AbortSignal); window.vdWaits = [];
  AbortSignal.timeout = ms => { window.vdWaits.push(ms); return real(250); }; })()"""


def no_answer():
    open_page("layout-4.html", 1280)
    js(SHORT_WAIT)
    with lock_held():
        click(PICK_B)
        got, states = messages(PICK_B, "#vd-b > h2", 3000), pick_states()
    asked = js("window.vdWaits")
    case("a pick that gets no answer says so and is not marked Picked", under_pick(got, NO_ANSWER) and states == [PICK] * 4 and asked == [10000],
         "serve.py's lock was held over B's pick: messages drawn %s %s (want one reading %s under the Pick button, 12 px below at most); Pick buttons %s;"
         " waits the page asked the browser for, in ms, %s (want one of 10000)" % (AS_MESSAGES % "B's title", got, NO_ANSWER, states, asked))
    open_page("layout-4.html", 1280)
    js(SHORT_WAIT)
    click('#vd-b button[aria-label="Note on variant B"]')
    typing = wait("document.activeElement === document.getElementById('vd-fb-text')")
    key("n")
    with lock_held():
        click(SEND)
        got = messages(SEND, "#vd-fb-box", 3000)
    box = js("[document.querySelector(%s).disabled, document.getElementById('vd-fb-text').value, document.getElementById('vd-fb-box').hidden]" % json.dumps(SEND))
    asked = js("window.vdWaits")
    case("a note that gets no answer says so, with Send note usable and its text kept",
         typing and on_send_row(got, NO_ANSWER) and box == [False, "n", False] and asked == [10000],
         "serve.py's lock was held over a note on B: messages drawn %s %s (want one reading %s on Send note's row); the note box as [Send note disabled, its text, hidden] %s"
         " (want [False, 'n', False]); it took focus: %s; waits the page asked the browser for, in ms, %s (want one of 10000)"
         % (AS_MESSAGES % "the note box", got, NO_ANSWER, box, typing, asked))


# The page as a browser from before mid-2022 runs it, with no AbortSignal.timeout: a timer asked for 10 s runs for this many ms, and what was asked for, in ms, is kept in window.vdWaits: the wait is lowered here, not in the shell.
NO_TIMEOUT = """(() => { delete AbortSignal.timeout; const real = window.setTimeout; window.vdWaits = [];
  window.setTimeout = (run, ms, ...rest) => { if (ms === 10000) { window.vdWaits.push(ms); ms = %d; } return real(run, ms, ...rest); }; })()"""


def without_abort_timeout():
    open_page("layout-6.html", 1280)
    js(NO_TIMEOUT % 10000)
    gone = js("typeof AbortSignal.timeout")
    shown, picks = pick_b("layout-6.html")
    asked = js("window.vdWaits")
    case("with no AbortSignal.timeout a pick is stored and reads Picked, under a 10 s timer", gone == "undefined" and shown and picks == [["B", 1]] and asked == [10000],
         "typeof AbortSignal.timeout on the page: %s; stored picks as [letter, pass] %s, B reads Picked: %s; timers the page asked for 10 s, in ms, %s (want one)"
         % (gone, picks, shown, asked))
    open_page("layout-5.html", 1280)
    js(NO_TIMEOUT % 250)
    with lock_held():
        click(PICK_B)
        got, states = messages(PICK_B, "#vd-b > h2", 3000), pick_states()
    asked = js("window.vdWaits")
    case("with no AbortSignal.timeout a pick that gets no answer says so in the same words and is not marked Picked",
         under_pick(got, NO_ANSWER) and states == [PICK] * 5 and asked == [10000],
         "serve.py's lock was held over B's pick: messages drawn %s %s (want one reading %s under the Pick button, 12 px below at most); Pick buttons %s;"
         " timers the page asked for 10 s, in ms, %s (want one, which the case ran for 250 ms)" % (AS_MESSAGES % "B's title", got, NO_ANSWER, states, asked))


cdp = None
try:
    cdp = Browser()
    for n in range(1, 7):
        group("layout-%d.html at 375" % n, lambda: each_count(n))
    group("six frames at 1280", rows_at_1280)
    group("wrapped title buttons", wrapped_title)
    group("a middle frame removed", middle_frame_removed)
    group("a pick on pass 1", pick_on_pass_one)
    group("a new pass", a_new_pass)
    group("a note on pass 2", note_on_pass_two)
    group("a page with no pass mark", an_unmarked_page)
    group("a pass mark outside 1 to 9", pick_on_a_refused_mark)
    group("number keys", number_keys)
    group("a key past the last frame", key_past_the_last)
    group("Flip mode", flip_mode)
    group("palette restyles every frame and not the header", palette_restyles)
    group("style and type restyle frames only", style_and_type)
    group("switchers are labelled groups in order", labelled_in_order)
    group("switcher operated by keyboard keeps focus", by_keyboard)
    group("option change does not reload", no_reload)
    group("one-option switcher hidden", one_option)
    group("a creative pass", creative_pass)
    group("a page of another pass kind", another_pass_kind)
    group("static page honours the palette attribute", static_page)
    group("look survives reload", survives_reload)
    group("missing stored option falls back to first", stored_option_gone)
    group("second tab starts from defaults", second_tab)
    group("authored look opens active", authored_look)
    group("a kept look stays with its path and title", another_path_or_title)
    group("a page loaded with ?static=1 after choices", static_after_choices)
    group("storage that throws", storage_refused)
    group("a themed project's page", themed_project)
    group("Scheme without a dark set", scheme_without_dark_set)
    group("where a palette's dark rule stands", dark_set_rule)
    group("a pick's context theme", theme_in_context)
    group("a pick's recorded look", recorded_look)
    group("a look change against the pick", look_change_said)
    group("a note's recorded look", note_with_look)
    group("kinds a page lacks or hides", kinds_a_page_lacks_or_hides)
    group("an option name the server refuses", refused_name)
    group("title button order", title_order)
    group("a Picked label at 375", picked_label_wraps)
    group("title button target size", title_targets)
    group("print under the dark scheme", print_in_light)
    group("Look disclosure opens and closes by click at 375", look_by_click)
    group("open Look stacks its groups one per line at 430", groups_stack)
    group("Look disclosure opens by Enter at 375", look_by_enter)
    group("closed header under 40 percent at 375", closed_header)
    group("no Look control and the switchers inline at 768 and 1280", no_look_when_wide)
    group("switchers too wide for the window", switchers_wrap)
    group("a frame reached by key or jump link clears the sticky header", clears_header)
    group("a header over half the window's height", tall_header)
    group("the header around its two thresholds", header_threshold)
    group("a static page's header", static_header)
    group("a phone's URL bar sliding in and out", url_bar)
    group("a window made shorter, then taller", window_made_shorter)
    group("the header's height changed by Look", header_follows_look)
    group("a refused pick", refusing(refused_pick))
    group("a refused note", refusing(refused_note))
    group("a refused pick at 375", refusing(refused_pick_at_375))
    group("a refused note in a short window", refusing(refused_note_in_a_short_window))
    group("a refusal in the server's words", refusing(refusal_in_words))
    group("a pick sent to a stopped server", refusing(server_stopped))
    group("a post that gets no answer", no_answer)
    group("a browser with no AbortSignal.timeout", without_abort_timeout)
except Exception as exc:
    case("browser start", False, "%s: %s" % (type(exc).__name__, exc))
finally:
    if cdp:
        cdp.close()

print("shell-controls tests: %d passed, %d failed" % (passed, failed))
sys.exit(1 if failed else 0)
PY
