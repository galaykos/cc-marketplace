#!/usr/bin/env python3
"""artifact-bundle.py — make ONE self-contained HTML artifact, versioned.

    artifact-bundle.py <page.html | page.md | dir> [--name slug]
                       [--out-dir .design-kit/artifacts] [--shell page-shell.html]
                       [--zip] [--json]

WHAT IT DOES (each a gate the harness drives):
  - inlines every LOCAL <link rel=stylesheet>, <script src>, <img src>, <source src>,
    <video/audio src>, and CSS url(...) target (images, fonts) as text or a data URI,
    resolved relative to the file that referenced it;
  - leaves absolute http(s) references in place and REPORTS each one as `network:` —
    an artifact that needs the network says so instead of pretending;
  - reports every relative <a href> to another file as `unresolved-link:` (a single
    page has nothing beside it; use in-page anchors);
  - refuses input that is not strict UTF-8, naming byte offset, line and column;
  - stamps <meta name="design-kit-artifact" content="<slug> v<N> <ISO date>">;
  - writes <out-dir>/<slug>.html, keeps every prior version at
    <out-dir>/.versions/<slug>/v<N>.html, and appends to <out-dir>/<slug>.versions.json;
  - warns (exit 0) when the result is over 16 MiB; `--zip` also writes <slug>.zip.
  A `.md` input is rendered through the shell with a small stdlib converter:
  ATX headings, paragraphs, one-level `-`/`1.` lists, blockquotes, `---` rules,
  fenced code, pipe tables, links, images, inline code, **bold**, *italic*. NOT
  supported: nested lists, reference-style links, footnotes, setext headings,
  task lists; raw HTML passes through untouched.

WHAT IT DOES NOT DO. It does not execute scripts, so a page that loads assets
from JavaScript at runtime keeps those references and they are not reported.
`srcset` attributes are reported as unsupported, not rewritten. A `../` or absolute
local ref that resolves outside the input's directory tree is never read: it is left
in the page as-is and reported as a warning, so nothing outside the tree is inlined.
"""
import argparse
import base64
import datetime as _dt
import hashlib
import html
import json
import mimetypes
import os
import re
import sys
import zipfile

MAX_BYTES = int(os.environ.get("DESIGN_KIT_MAX_BYTES", str(16 * 1024 * 1024)))  # env override exists for the harness only
ABS_RE = re.compile(r"^(?:[a-z][a-z0-9+.-]*:|//)", re.I)
DATA_RE = re.compile(r"^data:", re.I)


class Report:
    def __init__(self):
        self.inlined = []
        self.network = []
        self.unresolved = []
        self.warnings = []

    def as_dict(self):
        return {
            "inlined": self.inlined,
            "network": self.network,
            "unresolved_links": self.unresolved,
            "warnings": self.warnings,
        }


def fail(msg, code=2):
    print(f"artifact-bundle: {msg}", file=sys.stderr)
    sys.exit(code)


def read_utf8(path):
    raw = open(path, "rb").read()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        prefix = raw[: exc.start]
        line = prefix.count(b"\n") + 1
        col = exc.start - (prefix.rfind(b"\n") + 1) + 1
        fail(f"{path} is not valid UTF-8 at byte {exc.start} (line {line}, column {col})")


def slugify(s):
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s or "artifact"


INPUT_ROOT = None  # set once per run: the input page's directory; nothing above it is ever read


def _resolve(base_dir, ref):
    """A local path resolved against base_dir (the referring file's directory), or
    None when it escapes INPUT_ROOT — a `../` or absolute ref that leaves the input
    page's tree stays external and is reported. A stylesheet in css/ may still reach
    ../fonts/ because that is inside the page's tree."""
    ref = ref.split("#", 1)[0].split("?", 1)[0]
    root = os.path.realpath(INPUT_ROOT or base_dir)
    target = os.path.realpath(os.path.join(base_dir, ref))
    if target != root and not target.startswith(root + os.sep):
        return None
    return target


def _data_uri(path):
    mime = mimetypes.guess_type(path)[0] or "application/octet-stream"
    if path.lower().endswith(".woff2"):
        mime = "font/woff2"
    elif path.lower().endswith(".woff"):
        mime = "font/woff"
    with open(path, "rb") as fh:
        return f"data:{mime};base64,{base64.b64encode(fh.read()).decode()}"


def _classify(ref):
    if not ref or DATA_RE.match(ref) or ref.startswith("#"):
        return "skip"
    if ABS_RE.match(ref):
        return "network"
    return "local"


def inline_css_urls(css, base_dir, report, origin):
    def repl(m):
        quote, ref = m.group(1), m.group(2).strip()
        kind = _classify(ref)
        if kind == "network":
            report.network.append(ref)
            return m.group(0)
        if kind == "skip":
            return m.group(0)
        path = _resolve(base_dir, ref)
        if path is None:
            report.warnings.append(f"{origin}: url({ref}) resolves outside the input tree, left external")
            return m.group(0)
        if not os.path.isfile(path):
            report.warnings.append(f"{origin}: url({ref}) not found")
            return m.group(0)
        report.inlined.append({"kind": "css-url", "ref": ref})
        return f"url({quote}{_data_uri(path)}{quote})"

    return re.sub(r"url\(\s*(['\"]?)([^'\")]+)\1\s*\)", repl, css)


def _attr(tag, name):
    m = re.search(r"\b" + name + r"\s*=\s*(\"([^\"]*)\"|'([^']*)'|([^\s>]+))", tag, re.I)
    if not m:
        return None
    return m.group(2) if m.group(2) is not None else (m.group(3) if m.group(3) is not None else m.group(4))


def inline_html(doc, base_dir, report):
    # <link rel="stylesheet" href="...">
    def link_repl(m):
        tag = m.group(0)
        rel = (_attr(tag, "rel") or "").lower()
        href = _attr(tag, "href")
        if "stylesheet" not in rel or not href:
            return tag
        kind = _classify(href)
        if kind == "network":
            report.network.append(href)
            return tag
        if kind == "skip":
            return tag
        path = _resolve(base_dir, href)
        if path is None:
            report.warnings.append(f"{href}: resolves outside the input tree, left external")
            return tag
        if not os.path.isfile(path):
            report.warnings.append(f"stylesheet {href} not found")
            return tag
        css = inline_css_urls(read_utf8(path), os.path.dirname(path), report, href)
        report.inlined.append({"kind": "css", "ref": href})
        return f"<style data-inlined=\"{html.escape(href)}\">\n{css}\n</style>"

    doc = re.sub(r"<link\b[^>]*>", link_repl, doc, flags=re.I)

    # <script src="..."></script>
    def script_repl(m):
        tag, inner = m.group(1), m.group(2)
        src = _attr(tag, "src")
        if not src:
            return m.group(0)
        kind = _classify(src)
        if kind == "network":
            report.network.append(src)
            return m.group(0)
        if kind == "skip":
            return m.group(0)
        path = _resolve(base_dir, src)
        if path is None:
            report.warnings.append(f"{src}: resolves outside the input tree, left external")
            return tag
        if not os.path.isfile(path):
            report.warnings.append(f"script {src} not found")
            return m.group(0)
        js = read_utf8(path)
        if "</script" in js.lower():
            report.warnings.append(f"script {src} contains '</script' and was left external")
            return m.group(0)
        report.inlined.append({"kind": "js", "ref": src})
        attrs = re.sub(r"\bsrc\s*=\s*(\"[^\"]*\"|'[^']*'|[^\s>]+)", "", tag[7:-1]).strip()
        attrs = (" " + attrs) if attrs else ""
        return f"<script{attrs} data-inlined=\"{html.escape(src)}\">\n{js}\n</script>"

    doc = re.sub(r"(<script\b[^>]*>)(.*?)</script>", script_repl, doc, flags=re.I | re.S)

    # <img|source|video|audio|embed src="...">
    def media_repl(m):
        tag = m.group(0)
        src = _attr(tag, "src")
        if _attr(tag, "srcset"):
            report.warnings.append("srcset attribute is not rewritten (unsupported)")
        if not src:
            return tag
        kind = _classify(src)
        if kind == "network":
            report.network.append(src)
            return tag
        if kind == "skip":
            return tag
        path = _resolve(base_dir, src)
        if path is None:
            report.warnings.append(f"{src}: resolves outside the input tree, left external")
            return tag
        if not os.path.isfile(path):
            report.warnings.append(f"media {src} not found")
            return tag
        report.inlined.append({"kind": "media", "ref": src})
        return re.sub(r"\bsrc\s*=\s*(\"[^\"]*\"|'[^']*'|[^\s>]+)", f'src="{_data_uri(path)}"', tag, count=1)

    doc = re.sub(r"<(?:img|source|video|audio|embed)\b[^>]*>", media_repl, doc, flags=re.I)

    # inline <style> blocks and style="" attributes
    doc = re.sub(
        r"(<style\b[^>]*>)(.*?)(</style>)",
        lambda m: m.group(1) + inline_css_urls(m.group(2), base_dir, report, "<style>") + m.group(3),
        doc, flags=re.I | re.S,
    )
    doc = re.sub(
        r"style\s*=\s*\"([^\"]*)\"",
        lambda m: 'style="' + inline_css_urls(m.group(1), base_dir, report, "style attr") + '"',
        doc, flags=re.I,
    )

    # relative <a href> to another file
    for m in re.finditer(r"<a\b[^>]*>", doc, flags=re.I):
        href = _attr(m.group(0), "href")
        kind = _classify(href)
        if kind == "network":
            report.network.append(href)
        elif kind == "local" and not href.startswith("#"):
            report.unresolved.append(href)
    return doc


# --- minimal markdown -------------------------------------------------------

def _inline_md(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"!\[([^\]]*)\]\(([^)\s]+)\)", r'<img alt="\1" src="\2">', text)
    text = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", r'<a href="\2">\1</a>', text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![*\w])\*([^*]+)\*(?!\w)", r"<em>\1</em>", text)
    return text


def md_to_html(md):
    out, i, lines = [], 0, md.splitlines()
    title = None
    while i < len(lines):
        ln = lines[i]
        if ln.startswith("```"):
            lang = ln[3:].strip()
            j = i + 1
            buf = []
            while j < len(lines) and not lines[j].startswith("```"):
                buf.append(lines[j]); j += 1
            cls = f' class="language-{html.escape(lang)}"' if lang else ""
            out.append(f"<pre><code{cls}>{html.escape(chr(10).join(buf))}</code></pre>")
            i = j + 1; continue
        m = re.match(r"^(#{1,6})\s+(.*)$", ln)
        if m:
            lvl = len(m.group(1)); text = m.group(2).strip()
            if lvl == 1 and title is None:
                title = text
            out.append(f"<h{lvl}>{_inline_md(text)}</h{lvl}>"); i += 1; continue
        if re.match(r"^\s*(-{3,}|\*{3,})\s*$", ln):
            out.append("<hr>"); i += 1; continue
        if ln.startswith("|") and i + 1 < len(lines) and re.match(r"^\|?\s*:?-{2,}", lines[i + 1]):
            head = [c.strip() for c in ln.strip().strip("|").split("|")]
            j = i + 2; rows = []
            while j < len(lines) and lines[j].startswith("|"):
                rows.append([c.strip() for c in lines[j].strip().strip("|").split("|")]); j += 1
            th = "".join(f"<th>{_inline_md(c)}</th>" for c in head)
            tb = "".join("<tr>" + "".join(f"<td>{_inline_md(c)}</td>" for c in r) + "</tr>" for r in rows)
            out.append(f"<table><thead><tr>{th}</tr></thead><tbody>{tb}</tbody></table>")
            i = j; continue
        if re.match(r"^\s*[-*]\s+", ln) or re.match(r"^\s*\d+\.\s+", ln):
            ordered = bool(re.match(r"^\s*\d+\.", ln)); items = []
            while i < len(lines) and (re.match(r"^\s*[-*]\s+", lines[i]) or re.match(r"^\s*\d+\.\s+", lines[i])):
                items.append(re.sub(r"^\s*(?:[-*]|\d+\.)\s+", "", lines[i])); i += 1
            tag = "ol" if ordered else "ul"
            out.append(f"<{tag}>" + "".join(f"<li>{_inline_md(t)}</li>" for t in items) + f"</{tag}>"); continue
        if ln.startswith(">"):
            buf = []
            while i < len(lines) and lines[i].startswith(">"):
                buf.append(lines[i][1:].strip()); i += 1
            out.append(f"<blockquote><p>{_inline_md(' '.join(buf))}</p></blockquote>"); continue
        if ln.strip() == "":
            i += 1; continue
        if ln.lstrip().startswith("<"):
            out.append(ln); i += 1; continue
        buf = []
        while i < len(lines) and lines[i].strip() and not lines[i].lstrip().startswith(("#", "```", "|", ">", "<")) \
                and not re.match(r"^\s*([-*]|\d+\.)\s+", lines[i]):
            buf.append(lines[i].strip()); i += 1
        out.append(f"<p>{_inline_md(' '.join(buf))}</p>")
    return title, "\n".join(out)


def render_shell(shell_path, title, body):
    shell = read_utf8(shell_path)
    shell = shell.replace("<!-- SLOT: title -->", html.escape(title))
    shell = shell.replace("<!-- SLOT: body -->", body)
    return shell


# --- versioning ---------------------------------------------------------------

def stamp(doc, slug, version, date):
    meta = f'<meta name="design-kit-artifact" content="{html.escape(slug)} v{version} {date}">'
    doc = re.sub(r"<meta\s+name=\"design-kit-artifact\"[^>]*>\s*", "", doc, flags=re.I)
    m = re.search(r"<head\b[^>]*>", doc, flags=re.I)
    if m:
        return doc[: m.end()] + "\n" + meta + doc[m.end():]
    return f"<!doctype html><html><head><meta charset=\"utf-8\">{meta}</head><body>{doc}</body></html>"


def main(argv=None):
    ap = argparse.ArgumentParser(description="make one self-contained HTML artifact")
    ap.add_argument("input")
    ap.add_argument("--name")
    ap.add_argument("--out-dir", default=os.path.join(".design-kit", "artifacts"))
    ap.add_argument("--shell", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skills", "artifact", "assets", "page-shell.html"))
    ap.add_argument("--zip", action="store_true")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)

    src = a.input
    if os.path.isdir(src):
        src = os.path.join(src, "index.html")
    if not os.path.isfile(src):
        fail(f"no such file: {a.input}")
    slug = slugify(a.name or os.path.splitext(os.path.basename(src))[0])
    base_dir = os.path.dirname(os.path.abspath(src))
    global INPUT_ROOT
    INPUT_ROOT = base_dir
    report = Report()

    if src.lower().endswith(".md"):
        title, body = md_to_html(read_utf8(src))
        doc = render_shell(a.shell, title or slug, body)
    else:
        doc = read_utf8(src)
    doc = inline_html(doc, base_dir, report)

    os.makedirs(a.out_dir, exist_ok=True)
    vdir = os.path.join(a.out_dir, ".versions", slug)
    os.makedirs(vdir, exist_ok=True)
    ledger_path = os.path.join(a.out_dir, f"{slug}.versions.json")
    ledger = {"slug": slug, "versions": []}
    if os.path.isfile(ledger_path):
        try:
            ledger = json.load(open(ledger_path, encoding="utf-8"))
        except (ValueError, OSError):
            report.warnings.append(f"{ledger_path} unreadable; starting a fresh ledger")
    version = len(ledger["versions"]) + 1
    date = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()
    doc = stamp(doc, slug, version, date)
    data = doc.encode("utf-8")
    out = os.path.join(a.out_dir, f"{slug}.html")
    with open(out, "wb") as fh:
        fh.write(data)
    with open(os.path.join(vdir, f"v{version}.html"), "wb") as fh:
        fh.write(data)
    ledger["versions"].append({"v": version, "date": date, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    with open(ledger_path, "w", encoding="utf-8") as fh:
        json.dump(ledger, fh, indent=1)
    if len(data) > MAX_BYTES:
        report.warnings.append(f"artifact is {len(data)} bytes, over the 16 MiB ceiling — embedded raster images are the usual cause")
    zip_path = None
    if a.zip:
        zip_path = os.path.join(a.out_dir, f"{slug}.zip")
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
            z.write(out, f"{slug}.html")

    result = {"out": out, "slug": slug, "version": version, "bytes": len(data), "zip": zip_path, **report.as_dict()}
    if a.json:
        print(json.dumps(result, indent=1))
    else:
        print(f"artifact: {out} v{version} {len(data)} bytes")
        kinds = {}
        for it in report.inlined:
            kinds[it["kind"]] = kinds.get(it["kind"], 0) + 1
        print("inlined: " + (", ".join(f"{k} {v}" for k, v in sorted(kinds.items())) or "nothing"))
        for n in sorted(set(report.network)):
            print(f"network: {n}")
        for u in sorted(set(report.unresolved)):
            print(f"unresolved-link: {u}")
        for w in report.warnings:
            print(f"WARN: {w}")
        if zip_path:
            print(f"zip: {zip_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
