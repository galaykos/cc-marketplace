#!/usr/bin/env python3
"""board-build.py — render a design board (2–4 artboards on one canvas) from a spec.

WHAT IT DOES. Reads a JSON or markdown spec (shape: skills/design/references/
spec-format.md), fills skills/design/assets/board-shell.html, writes
.design-kit/boards/YYYY-MM-DD-<slug>.html and prints the path. Theme defaults come
from --tokens (default design-system/tokens.json when it exists): a DTCG file is
walked for an accent colour, a base spacing, a corner radius and a body font
family, each by path-name heuristic, each falling back to the shell's neutral
default when absent. Standing: scripts/__tests__/board-build.test.sh.

WHAT IT GATES (exit 2). Fewer than 2 or more than 4 artboards; an empty body;
"lorem ipsum" anywhere in a body; any external reference in a body (`http(s)://`
in src/href/url()/@import, a <link>, a <script src>) — the board must render with
the network off. WHAT IT DOES NOT CATCH: content that is realistic-looking but
wrong, an artboard that is a palette swap of its neighbour (the skill's rule,
agent-graded), and accessibility of the bodies (the shell's primitives carry the
floor; a hand-written body can undo it).
"""
import argparse
import datetime as _dt
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHELL = os.path.join(HERE, "..", "skills", "design", "assets", "board-shell.html")
DEVICES = {"phone": (375, 812), "tablet": (768, 1024), "desktop": (1280, 800)}
NEUTRAL = {"font": "system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif",
           "accent": (222, 62, 46), "space": 8, "radius": 10}
EXTERNAL = re.compile(r"""(src|href)\s*=\s*["']?\s*(https?:)?//|url\(\s*["']?\s*(https?:)?//|@import\b|<link\b|<script[^>]+\bsrc=""", re.I)


def fail(msg):
    print(f"board-build: {msg}", file=sys.stderr)
    sys.exit(2)


def slugify(text):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:48] or "board"



def parse_markdown(text):
    spec = {"title": "", "brief": "", "device": None, "boards": []}
    cur = None
    fence = None
    for line in text.splitlines():
        if fence is not None:
            if line.strip().startswith("```"):
                cur["body"] = "\n".join(fence).strip()
                fence = None
            else:
                fence.append(line)
            continue
        m = re.match(r"^#\s+(.+)$", line)
        if m and not spec["title"]:
            spec["title"] = m.group(1).strip()
            continue
        m = re.match(r"^##\s+Board:\s*(.+)$", line, re.I)
        if m:
            cur = {"title": m.group(1).strip(), "tradeoff": "", "device": None, "body": ""}
            spec["boards"].append(cur)
            continue
        m = re.match(r"^(Brief|Device|Trade-?off):\s*(.+)$", line, re.I)
        if m:
            key = m.group(1).lower().replace("-", "")
            key = "tradeoff" if key == "tradeoff" else key
            (cur if cur is not None and key != "brief" else spec)[key] = m.group(2).strip()
            continue
        if line.strip().startswith("```") and cur is not None:
            fence = []
    return spec


def load_spec(path):
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    if path.lower().endswith(".json"):
        try:
            return json.loads(text)
        except json.JSONDecodeError as exc:
            fail(f"spec is not valid JSON: {exc}")
    return parse_markdown(text)



def _walk(node, trail, out):
    if isinstance(node, dict):
        if "$value" in node:
            out.append(("/".join(trail).lower(), node.get("$type"), node["$value"]))
            return
        for k, v in node.items():
            if k.startswith("$"):
                continue
            _walk(v, trail + [str(k)], out)


def _hex_to_hsl(value):
    m = re.fullmatch(r"#?([0-9a-f]{6})", str(value).strip(), re.I)
    if not m:
        return None
    r, g, b = (int(m.group(1)[i:i + 2], 16) / 255 for i in (0, 2, 4))
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2
    if mx == mn:
        return (0, 0, round(l * 100))
    d = mx - mn
    s = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
    if mx == r:
        h = (g - b) / d + (6 if g < b else 0)
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return (round(h * 60) % 360, round(s * 100), round(l * 100))


def _px(value):
    m = re.match(r"^\s*([0-9.]+)\s*(px|rem)?", str(value))
    if not m:
        return None
    n = float(m.group(1))
    return round(n * 16) if m.group(2) == "rem" else round(n)


def read_tokens(path):
    theme = dict(NEUTRAL)
    if not path or not os.path.isfile(path):
        return theme, []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"board-build: tokens unreadable ({exc}); using neutral defaults", file=sys.stderr)
        return theme, []
    flat = []
    _walk(data, [], flat)
    used = []
    for want in ("primary", "brand", "accent"):  # the product colour first; "accent" is often the highlight, not the brand
        for p, t, v in flat:
            hsl = _hex_to_hsl(v) if (t in (None, "color")) else None
            if want in p and hsl:
                theme["accent"] = hsl
                used.append(f"accent ← {p}")
                break
        if any(u.startswith("accent") for u in used):
            break
    for p, t, v in flat:
        if "radius" in p and _px(v) is not None and ("md" in p or "base" in p or "default" in p or p.endswith("radius")):
            theme["radius"] = _px(v)
            used.append(f"radius ← {p}")
            break
    for p, t, v in flat:
        if ("space" in p or "spacing" in p) and _px(v) is not None and re.search(r"(base|unit|md|/2$|/2\b)", p):
            theme["space"] = _px(v)
            used.append(f"space ← {p}")
            break
    for p, t, v in flat:
        if ("font" in p and ("family" in p or "body" in p or "sans" in p)) and isinstance(v, (str, list)):
            fam = v if isinstance(v, str) else ", ".join(v)
            theme["font"] = fam.replace('"', "'")
            used.append(f"font ← {p}")
            break
    return theme, used



def esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;"))


def build(spec, theme, device_default):
    boards = spec.get("boards") or []
    if not 2 <= len(boards) <= 4:
        fail(f"a board holds 2–4 artboards; spec has {len(boards)}")
    html_boards, metas, scopes = [], [], ['<option value="all">All artboards</option>']
    for i, b in enumerate(boards, 1):
        body = (b.get("body") or "").strip()
        if not body:
            fail(f"artboard {i} has an empty body")
        if re.search(r"lorem\s+ipsum", body, re.I):
            fail(f"artboard {i} contains lorem ipsum — write the real content")
        m = EXTERNAL.search(body)
        if m:
            fail(f"artboard {i} references an external resource ({m.group(0).strip()!r}); inline it or drop it")
        dev = (b.get("device") or spec.get("device") or device_default or "desktop").lower()
        if dev not in DEVICES:
            fail(f"artboard {i}: unknown device {dev!r} (phone|tablet|desktop)")
        w, h = DEVICES[dev]
        title = b.get("title") or f"Direction {i}"
        html_boards.append(
            f'<section class="dk-board" id="board-{i}" data-title="{esc(title)}" data-device="{dev}" '
            f'style="--dk-w:{w}px;--dk-h:{h}px">\n'
            f'  <header><h2>{i}. {esc(title)}</h2><p>{esc(b.get("tradeoff") or "")}</p>'
            f'<button type="button" data-act="pick">Pick this</button></header>\n'
            f'  <div class="dk-frame"><div class="dk-screen">\n{body}\n  </div></div>\n</section>'
        )
        metas.append(f'<meta name="design-kit-board" content="{i}:{w}x{h}">')
        scopes.append(f'<option value="{i}">Artboard {i}</option>')
    hh, ss, ll = theme["accent"]
    defaults = {"space": theme["space"], "radius": theme["radius"], "hue": hh, "type": 1, "density": 1, "scheme": "light"}
    with open(SHELL, "r", encoding="utf-8") as fh:
        shell = fh.read()
    fills = {
        "TITLE": esc(spec.get("title") or "Design board"),
        "BRIEF": esc(spec.get("brief") or ""),
        "META": "\n".join(metas),
        "FONT": theme["font"],
        "ACCENT_H": str(hh), "ACCENT_S": str(ss), "ACCENT_L": str(ll),
        "SPACE": str(theme["space"]), "RADIUS": str(theme["radius"]),
        "EXTRA_CSS": spec.get("css") or "",
        "SCOPE_OPTIONS": "".join(scopes),
        "BOARDS": "\n".join(html_boards),
        "DEFAULTS_JSON": json.dumps(defaults),
    }
    for k, v in fills.items():
        shell = shell.replace("{{" + k + "}}", v)
    left = re.findall(r"\{\{[A-Z_]+\}\}", shell)
    if left:
        fail(f"shell slots unfilled: {sorted(set(left))}")
    return shell


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


def main(argv=None):
    ap = argparse.ArgumentParser(description="render a design board from a spec")
    ap.add_argument("spec", help="spec .json or .md (see references/spec-format.md)")
    ap.add_argument("--out", help="output .html (default .design-kit/boards/YYYY-MM-DD-<slug>.html)")
    ap.add_argument("--tokens", default=None, help="DTCG tokens.json (default design-system/tokens.json if present)")
    ap.add_argument("--device", choices=sorted(DEVICES), default=None, help="frame for artboards that name none")
    ap.add_argument("--docroot", default=".design-kit")
    args = ap.parse_args(argv)

    spec = load_spec(args.spec)
    tokens = args.tokens if args.tokens is not None else ("design-system/tokens.json" if os.path.isfile("design-system/tokens.json") else None)
    theme, used = read_tokens(tokens)
    html = with_stamp(build(spec, theme, args.device), tokens if (tokens and os.path.isfile(tokens)) else None)
    out = args.out or os.path.join(args.docroot, "boards", f"{_dt.date.today():%Y-%m-%d}-{slugify(spec.get('title') or 'board')}.html")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(html)
    print(out)
    if used:
        print("tokens: " + "; ".join(used), file=sys.stderr)
    elif tokens:
        print(f"tokens: nothing usable found in {tokens}; neutral defaults", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
