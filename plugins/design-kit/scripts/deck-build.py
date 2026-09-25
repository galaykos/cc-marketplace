#!/usr/bin/env python3
"""deck-build.py — outline markdown → one self-contained HTML deck.

WHAT IT DOES. Reads an outline (grammar: skills/slides/references/outline-format.md),
renders every slide into skills/slides/assets/deck-shell.html, inlines local images
as data URIs, applies theme tokens from design-system/tokens.json or
design-system/DESIGN-SYSTEM.md when either exists, and writes
.design-kit/decks/YYYY-MM-DD-<slug>.html (or --out) — .design-kit/ at the git root,
or $DESIGN_KIT_DIR when set. Stdlib only.

WHAT IT CHECKS (exit 2 on any): a deck title (`# `) exists; at least one slide;
no slide body over --max-lines (default 6) visible lines — the rule the model
breaks most, so the script holds it rather than the prose; the output contains
no external `src=`/`href=` (self-containment is what makes the PDF and the LAN
path work). `--allow-long` downgrades the line rule to a warning.

WHAT IT DOES NOT CHECK. Whether the headline states a claim, whether numbers
belong in a figure — those stay agent-graded in the skill.
"""
import argparse
import base64
import datetime as _dt
import html
import json
import mimetypes
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.join(HERE, "..", "skills", "slides", "assets", "deck-shell.html")

INLINE_RE = re.compile(r"(`[^`]+`)|(\*\*[^*]+\*\*)|(\*[^*]+\*)|(\[([^\]]+)\]\(([^)]+)\))")


def dk_dir():
    """$DESIGN_KIT_DIR (dk.sh exports it, anchored at the project root), else .design-kit
    at the git root — never under a subdirectory the shell had cd'd into, which scattered
    a second .design-kit/ (finding 2 of the marketplace's
    rationale/2026-09-25-session-plugin-usage-review.md)."""
    import subprocess
    if os.environ.get("DESIGN_KIT_DIR"):
        return os.environ["DESIGN_KIT_DIR"]
    try:
        r = subprocess.run(["git", "rev-parse", "--show-cdup"], capture_output=True, text=True, timeout=5)
        up = r.stdout.strip() if r.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        up = ""
    return os.path.join(up, ".design-kit")


def inline(text):
    out = []
    pos = 0
    for m in INLINE_RE.finditer(text):
        out.append(html.escape(text[pos:m.start()]))
        if m.group(1):
            out.append("<code>%s</code>" % html.escape(m.group(1)[1:-1]))
        elif m.group(2):
            out.append("<strong>%s</strong>" % html.escape(m.group(2)[2:-2]))
        elif m.group(3):
            out.append("<em>%s</em>" % html.escape(m.group(3)[1:-1]))
        else:
            out.append("<a href=\"%s\">%s</a>" % (html.escape(m.group(6)), html.escape(m.group(5))))
        pos = m.end()
    out.append(html.escape(text[pos:]))
    return "".join(out)


def data_uri(path, base):
    full = path if os.path.isabs(path) else os.path.join(base, path)
    if not os.path.isfile(full):
        return None
    mime = mimetypes.guess_type(full)[0] or "application/octet-stream"
    with open(full, "rb") as fh:
        return "data:%s;base64,%s" % (mime, base64.b64encode(fh.read()).decode("ascii"))


def slugify(s):
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s[:60] or "deck"


def parse(text):
    """Return (title, subtitle_lines, slides). slides: list of dict(title, blocks, notes, plain)."""
    title, subtitle, slides = None, [], []
    cur = None
    in_code, code_lang, code_buf = False, "", []
    lines = text.splitlines()
    for raw in lines:
        line = raw.rstrip("\n")
        if in_code:
            if line.strip().startswith("```"):
                in_code = False
                (cur["blocks"] if cur else subtitle).append(("code", code_lang, "\n".join(code_buf)))
                code_buf = []
            else:
                code_buf.append(line)
            continue
        if line.strip().startswith("```"):
            in_code, code_lang, code_buf = True, line.strip()[3:].strip(), []
            continue
        if line.startswith("# ") and title is None:
            title = line[2:].strip()
            continue
        if line.startswith("## "):
            cur = {"title": line[3:].strip(), "blocks": [], "notes": [], "fragments": False}
            slides.append(cur)
            continue
        if cur is None:
            if line.strip():
                subtitle.append(("p", line.strip()))
            continue
        s = line.strip()
        if not s:
            continue
        low = s.lower()
        if low.startswith("> notes:"):
            cur["notes"].append(s[8:].strip())
        elif s.startswith("> ") and cur["notes"]:
            cur["notes"].append(s[2:].strip())
        elif low.startswith("=> "):
            value, _, caption = s[3:].partition("|")
            cur["blocks"].append(("figure", value.strip(), caption.strip()))
        elif low == "fragments":
            cur["fragments"] = True
        elif s.startswith("### "):
            cur["blocks"].append(("h3", s[4:].strip()))
        elif re.match(r"^!\[[^\]]*\]\([^)]+\)$", s):
            m = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)$", s)
            cur["blocks"].append(("img", m.group(1), m.group(2)))
        elif re.match(r"^[-*] ", line.lstrip()) or re.match(r"^\d+\. ", line.lstrip()):
            indent = len(line) - len(line.lstrip())
            ordered = bool(re.match(r"^\d+\. ", line.lstrip()))
            item = re.sub(r"^([-*]|\d+\.) ", "", line.lstrip())
            cur["blocks"].append(("li", indent, ordered, item))
        else:
            cur["blocks"].append(("p", s))
    if in_code:
        (cur["blocks"] if cur else subtitle).append(("code", code_lang, "\n".join(code_buf)))
    return title, subtitle, slides


def render_list(items, frag):
    """items: list of (indent, ordered, text). Nested by indent; one <ul>/<ol> per level."""
    def level(pos, indent):
        tag = "ol" if items[pos][1] else "ul"
        out = ["<%s>" % tag]
        while pos < len(items) and items[pos][0] == indent:
            out.append("<li%s>%s" % (frag, inline(items[pos][2])))
            pos += 1
            if pos < len(items) and items[pos][0] > indent:
                sub, pos = level(pos, items[pos][0])
                out.append(sub)
            out.append("</li>")
        out.append("</%s>" % tag)
        return "\n".join(out), pos
    html_out, _ = level(0, items[0][0])
    return html_out


def render_blocks(blocks, base, fragments):
    """Return (html, plain_text, visible_line_count) for one slide body."""
    out, plain, visible = [], [], 0
    frag = ' class="fragment"' if fragments else ""
    i = 0
    while i < len(blocks):
        kind = blocks[i][0]
        if kind == "li":
            items = []
            while i < len(blocks) and blocks[i][0] == "li":
                _, indent, ordered, text = blocks[i]
                items.append((indent, ordered, text))
                plain.append(text)
                i += 1
            top = items[0][0]
            visible += sum(1 for it in items if it[0] == top)
            out.append(render_list(items, frag))
            continue
        b = blocks[i]
        if kind == "p":
            out.append("<p%s>%s</p>" % (frag, inline(b[1])))
            plain.append(b[1])
            visible += 1
        elif kind == "h3":
            out.append("<h3>%s</h3>" % inline(b[1]))
            plain.append(b[1])
        elif kind == "code":
            lang = (' class="language-%s"' % html.escape(b[1])) if b[1] else ""
            out.append("<pre><code%s>%s</code></pre>" % (lang, html.escape(b[2])))
            plain.append(b[2])
            visible += 1
        elif kind == "figure":
            out.append('<div class="figure"><div class="value">%s</div><div class="caption">%s</div></div>' % (inline(b[1]), inline(b[2])))
            plain.append("%s %s" % (b[1], b[2]))
            visible += 1
        elif kind == "img":
            src = data_uri(b[2], base)
            if src is None:
                print("deck-build: image not found, skipped: %s" % b[2], file=sys.stderr)
            else:
                out.append('<img alt="%s" src="%s">' % (html.escape(b[1]), src))
                visible += 1
        i += 1
    return "\n".join(out), "\n".join(plain), visible


THEME_USED = {"path": None}  # the theme file theme_css() actually read, for the stamp


def theme_css(theme_path, cwd):
    """Map design-system output to --dk-* variables. Returns css lines (may be empty)."""
    cands = [theme_path] if theme_path else [os.path.join(cwd, "design-system", "tokens.json"), os.path.join(cwd, "design-system", "DESIGN-SYSTEM.md")]
    THEME_USED["path"] = None
    for p in cands:
        if not p or not os.path.isfile(p):
            continue
        vals = {}
        if p.endswith(".json"):
            try:
                doc = json.load(open(p, encoding="utf-8"))
            except (OSError, ValueError):
                continue
            flat = {}

            def walk(node, path):
                if isinstance(node, dict):
                    if "$value" in node:
                        flat[".".join(path)] = node["$value"]
                    else:
                        for k, v in node.items():
                            walk(v, path + [k])
            walk(doc, [])
            for key, val in flat.items():
                k = key.lower()
                if not isinstance(val, str):
                    continue
                if "color" in k or "colour" in k:
                    if re.search(r"(^|\.)(background|bg|surface\.?(base|0|default)?|canvas)$", k) and "dk-bg" not in vals:
                        vals["dk-bg"] = val
                    elif re.search(r"(^|\.)(text|foreground|ink)(\.default|\.primary|\.base)?$", k) and "dk-fg" not in vals:
                        vals["dk-fg"] = val  # anchored: brand-ink / primary-ink are ON-colours, not the page text
                    elif re.search(r"(muted|secondary|subtle)", k) and "dk-muted" not in vals:
                        vals["dk-muted"] = val
                    elif re.search(r"(border|line|outline)", k) and "dk-line" not in vals:
                        vals["dk-line"] = val
                elif ("font" in k and "family" in k) or k.endswith("fontfamily"):
                    if "mono" in k or "code" in k:
                        vals.setdefault("dk-mono", val)
                    else:
                        vals.setdefault("dk-font", val)
            # accent: primary before brand before accent — the product colour, not the highlight
            def _rank(item):
                k = item[0].lower()
                return 0 if "primary" in k else 1 if "brand" in k else 2
            for key, val in sorted(flat.items(), key=_rank):
                k = key.lower()
                if isinstance(val, str) and ("color" in k or "colour" in k) and re.search(r"(^|\.)(primary|accent|brand)(\.default|\.base|\.500)?$", k):
                    vals.setdefault("dk-accent", val)
                    break
        else:
            text = open(p, encoding="utf-8", errors="replace").read()
            for m in re.finditer(r"(primary|accent|brand|surface|background|text|ink|foreground|muted|border)\s*[:=]?\s*(#[0-9a-fA-F]{3,8}|oklch\([^)]*\)|hsl\([^)]*\)|rgb\([^)]*\))", text, re.I):
                name, val = m.group(1).lower(), m.group(2)
                slot = {"primary": "dk-accent", "accent": "dk-accent", "brand": "dk-accent", "surface": "dk-bg", "background": "dk-bg", "text": "dk-fg", "ink": "dk-fg", "foreground": "dk-fg", "muted": "dk-muted", "border": "dk-line"}[name]
                vals.setdefault(slot, val)
            m = re.search(r"([A-Z][\w ]+?)\s+for\s+body", text)
            if m:
                vals.setdefault("dk-font", '"%s", system-ui, sans-serif' % m.group(1).strip())
            m = re.search(r"([A-Z][\w ]+?)\s+for\s+code", text)
            if m:
                vals.setdefault("dk-mono", '"%s", ui-monospace, monospace' % m.group(1).strip())
        if vals:
            THEME_USED["path"] = p
            print("deck-build: theme from %s (%s)" % (os.path.relpath(p, cwd), ", ".join(sorted(vals))), file=sys.stderr)
            return "\n".join("  --%s:%s;" % (k, v) for k, v in vals.items())
    return ""


def tokens_stamp(tokens_path):
    """`<meta name="design-kit-tokens" content="<sha12> <gitshort|none>">` — the
    tokens file this build actually read (first 12 hex of its sha256, or `none`)
    and the repo revision, so a gallery can tell a page built against tokens
    that have since moved. Reads the file bytes; never the git index."""
    import hashlib
    import subprocess
    sha = "none"
    if tokens_path and os.path.isfile(tokens_path):
        with open(tokens_path, "rb") as fh:
            sha = hashlib.sha256(fh.read()).hexdigest()[:12]
    short = "none"
    try:
        r = subprocess.run(["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True, timeout=5)
        if r.returncode == 0 and r.stdout.strip():
            short = r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return '<meta name="design-kit-tokens" content="%s %s">' % (sha, short)


def with_stamp(page, tokens_path):
    meta = tokens_stamp(tokens_path)
    page = re.sub(r'<meta\s+name="design-kit-tokens"[^>]*>\s*', "", page, flags=re.I)
    m = re.search(r"<head\b[^>]*>", page, flags=re.I)
    return page[: m.end()] + "\n" + meta + page[m.end():] if m else page


def build(outline_path, out_path, theme_path, max_lines, allow_long):
    cwd = os.getcwd()
    text = open(outline_path, encoding="utf-8").read()
    base = os.path.dirname(os.path.abspath(outline_path))
    title, subtitle, slides = parse(text)
    if not title:
        print("deck-build: the outline needs a `# Deck title` line", file=sys.stderr)
        return 2
    if not slides:
        print("deck-build: no `## Slide title` lines — nothing to render", file=sys.stderr)
        return 2
    parts, long_slides = [], []
    sub_html, sub_plain, _ = render_blocks(subtitle, base, False)
    parts.append('<section class="slide title" id="s1" data-title="%s" data-notes=""><h1>%s</h1><div class="subtitle">%s</div></section>' % (html.escape(title, quote=True), inline(title), sub_html))
    for k, s in enumerate(slides, start=2):
        body, plain, visible = render_blocks(s["blocks"], base, s["fragments"])
        if visible > max_lines:
            long_slides.append("%s (%d lines)" % (s["title"], visible))
        notes = "\n".join(s["notes"])
        parts.append('<section class="slide" id="s%d" data-title="%s" data-notes="%s"><h2>%s</h2>\n%s\n<aside class="notes">%s</aside></section>' % (
            k, html.escape(s["title"], quote=True), html.escape(notes, quote=True), inline(s["title"]), body, html.escape(notes)))
    if long_slides:
        msg = "deck-build: %d slide(s) over %d visible lines: %s" % (len(long_slides), max_lines, "; ".join(long_slides))
        if allow_long:
            print("WARN " + msg, file=sys.stderr)
        else:
            print(msg + " — split them, or pass --allow-long", file=sys.stderr)
            return 2
    shell = open(SHELL, encoding="utf-8").read()
    page = (shell.replace("{{TITLE_JSON}}", json.dumps(title))
                 .replace("{{TITLE}}", html.escape(title))
                 .replace("{{GENERATED}}", _dt.date.today().isoformat())
                 .replace("{{THEME_CSS}}", theme_css(theme_path, cwd))
                 .replace("{{SLIDES}}", "\n".join(parts)))
    page = with_stamp(page, THEME_USED["path"])
    ext = re.findall(r'(?:src|href)="(https?:)?//', page)
    if ext:
        print("deck-build: %d external src/href reference(s) — a deck must be self-contained" % len(ext), file=sys.stderr)
        return 2
    if not out_path:
        out_path = os.path.join(dk_dir(), "decks", "%s-%s.html" % (_dt.date.today().isoformat(), slugify(title)))
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(page)
    print("deck-build: %s — %d slides" % (out_path, len(slides) + 1))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="outline markdown → self-contained HTML deck")
    ap.add_argument("outline")
    ap.add_argument("--out")
    ap.add_argument("--theme", help="design-system/tokens.json or DESIGN-SYSTEM.md; auto-detected under ./design-system when omitted")
    ap.add_argument("--max-lines", type=int, default=6)
    ap.add_argument("--allow-long", action="store_true")
    a = ap.parse_args(argv)
    return build(a.outline, a.out, a.theme, a.max_lines, a.allow_long)


if __name__ == "__main__":
    sys.exit(main())
