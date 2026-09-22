#!/usr/bin/env python3
"""handoff-drift.py — how far a Claude Design handoff bundle drifts from the repo's tokens.

WHAT IT CATCHES. Every colour (hex, rgb(), hsl(), oklch()) and font-family the
bundle's .html/.css files use, against every token the repo declares: `--name:`
custom properties in CSS under src/, resources/, app/, styles/ and the repo root
(this covers Tailwind v4 `@theme` blocks), `key: '#hex'` pairs in tailwind.config.*,
and `$value`s in design-system/tokens.json. Prints one DRIFT TABLE row per distinct
bundle value: nearest token, distance, verdict `match` (exact), `near` (RGB
distance <= --near, default 24) or `no token`. Exit 0 always — the table is the
output; a `no token` row is a question for the user, not a failure.

WHAT IT DOES NOT CATCH. Spacing, radius and shadow drift (not extracted); colours
computed at runtime; a font loaded by @import but never declared in font-family;
semantic misuse (the right hex on the wrong role). Standing:
scripts/__tests__/handoff.test.sh drives match, near and no-token rows.
"""
import argparse
import glob
import json
import math
import os
import re
import sys

HEX = re.compile(r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\b")
RGB = re.compile(r"rgba?\(\s*([\d.]+)\s*[, ]\s*([\d.]+)\s*[, ]\s*([\d.]+)")
HSL = re.compile(r"hsla?\(\s*([\d.]+)(?:deg)?\s*[, ]\s*([\d.]+)%\s*[, ]\s*([\d.]+)%")
OKLCH = re.compile(r"oklch\(\s*([\d.]+)%?\s+([\d.]+)\s+([\d.]+)")
FONT = re.compile(r"font-family\s*:\s*([^;}]+)", re.I)
CUSTOM_PROP = re.compile(r"(--[\w-]+)\s*:\s*([^;}]+)")
TW_PAIR = re.compile(r"['\"]?([\w-]+)['\"]?\s*:\s*['\"](#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}))['\"]")
GENERIC = {"serif", "sans-serif", "monospace", "system-ui", "ui-sans-serif", "ui-serif", "ui-monospace",
           "cursive", "fantasy", "inherit", "initial", "unset"}


def _read(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def _hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _hsl_to_rgb(h, s, l):
    h, s, l = float(h) % 360 / 360, float(s) / 100, float(l) / 100
    if s == 0:
        v = round(l * 255)
        return (v, v, v)
    q = l * (1 + s) if l < 0.5 else l + s - l * s
    p = 2 * l - q

    def chan(t):
        t %= 1
        if t < 1 / 6:
            return p + (q - p) * 6 * t
        if t < 1 / 2:
            return q
        if t < 2 / 3:
            return p + (q - p) * (2 / 3 - t) * 6
        return p
    return tuple(round(chan(h + d) * 255) for d in (1 / 3, 0, -1 / 3))


def _oklch_to_rgb(L, C, H):
    L, C, H = float(L), float(C), float(H)
    if L > 1:
        L /= 100
    a, b = C * math.cos(math.radians(H)), C * math.sin(math.radians(H))
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    def gam(c):
        c = max(0.0, min(1.0, c))
        c = 1.055 * c ** (1 / 2.4) - 0.055 if c > 0.0031308 else 12.92 * c
        return round(max(0.0, min(1.0, c)) * 255)
    return (gam(r), gam(g), gam(bl))


def colours_in(text):
    """Yield (literal, rgb) for every colour literal in text."""
    for m in HEX.finditer(text):
        yield m.group(0).lower(), _hex_to_rgb(m.group(0))
    for m in RGB.finditer(text):
        yield m.group(0) + ")", tuple(min(255, round(float(x))) for x in m.groups())
    for m in HSL.finditer(text):
        yield m.group(0) + ")", _hsl_to_rgb(*m.groups())
    for m in OKLCH.finditer(text):
        yield m.group(0) + ")", _oklch_to_rgb(*m.groups())


def fonts_in(text):
    for m in FONT.finditer(text):
        for fam in m.group(1).split(","):
            fam = fam.strip().strip("'\"").strip()
            if fam and fam.lower() not in GENERIC and not fam.startswith("var("):
                yield fam


def bundle_values(bundle):
    colours, fonts = {}, {}
    for path in sorted(glob.glob(os.path.join(bundle, "**", "*"), recursive=True)):
        if not path.lower().endswith((".html", ".htm", ".css")):
            continue
        text = _read(path)
        for lit, rgb in colours_in(text):
            colours.setdefault(rgb, [lit, 0])[1] += 1
        for fam in fonts_in(text):
            colours_key = fam.lower()
            fonts.setdefault(colours_key, [fam, 0])[1] += 1
    return colours, fonts


def repo_tokens(repo):
    """Return ({rgb: name}, {family_lower: name}) from the repo's token sources."""
    colours, fonts = {}, {}
    css_files = []
    for root in ("src", "resources", "app", "styles", "."):
        base = os.path.join(repo, root)
        pattern = os.path.join(base, "*.css") if root == "." else os.path.join(base, "**", "*.css")
        css_files += [p for p in glob.glob(pattern, recursive=True)
                      if "node_modules" not in p and "vendor" not in p and ".design-kit" not in p]
    for path in sorted(set(css_files)):
        for name, value in CUSTOM_PROP.findall(_read(path)):
            for _lit, rgb in colours_in(value):
                colours.setdefault(rgb, name)
            if "font" in name.lower():
                for fam in fonts_in("font-family:" + value):
                    fonts.setdefault(fam.lower(), name)
    for path in glob.glob(os.path.join(repo, "tailwind.config.*")):
        for name, hexv in TW_PAIR.findall(_read(path)):
            colours.setdefault(_hex_to_rgb(hexv), f"tailwind:{name}")
    tokens_json = os.path.join(repo, "design-system", "tokens.json")
    if os.path.isfile(tokens_json):
        try:
            data = json.loads(_read(tokens_json))
        except ValueError:
            data = {}
        _walk_dtcg(data, [], colours, fonts)
    return colours, fonts


def _walk_dtcg(node, path, colours, fonts):
    if isinstance(node, dict):
        if "$value" in node:
            name = ".".join(path)
            val = node["$value"]
            if isinstance(val, str):
                for _lit, rgb in colours_in(val):
                    colours.setdefault(rgb, name)
                if node.get("$type") == "fontFamily":
                    fonts.setdefault(val.strip().lower(), name)
            elif isinstance(val, list) and node.get("$type") == "fontFamily" and val:
                fonts.setdefault(str(val[0]).strip().lower(), name)
            return
        for k, v in node.items():
            if not k.startswith("$"):
                _walk_dtcg(v, path + [k], colours, fonts)


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("bundle")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--near", type=float, default=24.0, help="RGB distance that still counts as near")
    args = ap.parse_args(argv)
    if not os.path.isdir(args.bundle):
        print(f"handoff-drift.py: {args.bundle} is not a directory", file=sys.stderr)
        return 0
    b_col, b_font = bundle_values(args.bundle)
    r_col, r_font = repo_tokens(args.repo)
    rows = []
    for rgb, (lit, n) in sorted(b_col.items(), key=lambda kv: -kv[1][1]):
        if not r_col:
            rows.append(("colour", lit, n, "-", "-", "no token"))
            continue
        best = min(r_col.items(), key=lambda kv: dist(rgb, kv[0]))
        d = dist(rgb, best[0])
        hexv = "#%02x%02x%02x" % best[0]
        verdict = "match" if d == 0 else (f"near (Δ{d:.0f})" if d <= args.near else "no token")
        rows.append(("colour", lit, n, best[1], hexv, verdict))
    for key, (fam, n) in sorted(b_font.items(), key=lambda kv: -kv[1][1]):
        if key in r_font:
            rows.append(("font", fam, n, r_font[key], fam, "match"))
        else:
            rows.append(("font", fam, n, "-", "-", "no token"))
    print(f"DRIFT TABLE — bundle {os.path.abspath(args.bundle)} vs repo tokens "
          f"({len(r_col)} colours, {len(r_font)} fonts declared)")
    print("| kind | bundle value | uses | nearest token | token value | verdict |")
    print("|---|---|---|---|---|---|")
    for kind, lit, n, name, val, verdict in rows:
        print(f"| {kind} | {lit} | {n} | {name} | {val} | {verdict} |")
    if not rows:
        print("| - | (no colours or fonts found in the bundle) | 0 | - | - | - |")
    counts = {"match": 0, "near": 0, "no token": 0}
    for r in rows:
        counts["near" if r[5].startswith("near") else r[5]] += 1
    print(f"summary: match={counts['match']} near={counts['near']} no-token={counts['no token']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
