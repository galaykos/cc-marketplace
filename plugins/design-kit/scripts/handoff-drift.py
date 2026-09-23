#!/usr/bin/env python3
"""handoff-drift.py — how far shipped code drifts from the repo's declared tokens.

TWO MODES, ONE TOKEN READER.

BUNDLE MODE (the default, `handoff-drift.py <dir>`) — how far a Claude Design
handoff bundle drifts. Every colour (hex, rgb(), hsl(), oklch()) and font-family
the bundle's .html/.css files use, against every token the repo declares: `--name:`
custom properties in CSS under src/, resources/, app/, styles/ and the repo root
(this covers Tailwind v4 `@theme` blocks), `key: '#hex'` pairs in tailwind.config.*,
and `$value`s in design-system/tokens.json. Prints one DRIFT TABLE row per distinct
bundle value: nearest token, distance, verdict `match` (exact), `near` (RGB
distance <= --near, default 24) or `no token`. Exit 0 always — the table is the
output; a `no token` row is a question for the user, not a failure.

SCAN MODE (`--scan PATH...`, what `dk drift` runs) — the same question asked of the
project's OWN components. Reads .tsx/.jsx/.vue/.blade.php/.css/.scss and reports
two hit kinds: a literal colour that resolves to no declared token, and a NAMED
TAILWIND PALETTE utility (`bg-indigo-500`, `text-slate-700/50`) whose palette name
is not a declared token name — the shape that bypasses the token layer entirely, so
`dk check` and the bundle table above both stay green while the components drift.
`--ci` exits 1 on any hit; without it the table is the output and the exit is 0.
No token source anywhere exits 2 (`not measured`) in either mode: a drift check
that cannot find the tokens has not cleared anything.

WHAT SCAN MODE DOES NOT CATCH, named rather than implied. Spacing, radius, shadow
and font drift (colour only here). A colour computed at runtime, or one arriving
through a CSS file the token reader already treats as a DECLARATION site — a
literal on a `--name:` or `$name:` line is the token being defined, never a hit.
An `href`/`to` attribute value is blanked before the scan, so a `#dad` anchor is
not read as a colour, but any other 3-hex-digit slug in other syntax still is.
`bg-primary` and `var(--primary)` are clean BY CONSTRUCTION — this check proves a
component went through the token layer, never that it picked the right token, and
semantic misuse (the right token on the wrong role) is invisible to it. A named
palette utility is judged on the class STRING, so a project that renamed a scale to
`indigo` in tailwind.config is reported unless tokens.json declares that name too.
Standing: scripts/__tests__/handoff.test.sh drives bundle mode, drift.test.sh
drives scan mode (hit, clean, --ci exit, not-measured).
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


SCAN_EXT = (".tsx", ".jsx", ".vue", ".blade.php", ".css", ".scss")
SCAN_SKIP = ("node_modules", "vendor", ".design-kit", "__design-kit__", "dist", "build", ".git")

# The Tailwind default palette scales. A utility naming one of these reaches a
# colour without passing the token layer at all, which is why the class STRING is
# the evidence here and no value lookup happens: `bg-indigo-500` resolves inside
# Tailwind, never inside design-system/tokens.json. `bg-primary`, `bg-brand-600`
# and any other semantic name are clean by construction — that is the whole point.
# black/white/transparent/current/inherit are deliberately absent: `text-white` on
# a dark button is not drift, and a row that fires on every real page is a row
# someone switches off within a day.
TW_SCALES = ("slate", "gray", "grey", "zinc", "neutral", "stone", "red", "orange", "amber",
             "yellow", "lime", "green", "emerald", "teal", "cyan", "sky", "blue", "indigo",
             "violet", "purple", "fuchsia", "pink", "rose")
TW_PREFIX = ("bg", "text", "border", "from", "via", "to", "ring", "fill", "stroke", "outline",
             "decoration", "shadow", "accent", "caret", "divide", "placeholder")
TW_UTIL = re.compile(
    r"(?<![\w-])(?:" + "|".join(TW_PREFIX) + r")-(" + "|".join(TW_SCALES) +
    r")-(\d{2,3})(?:/\d{1,3})?\b")
# A literal on a custom-property or SCSS-variable line is the token being DEFINED.
DECL_LINE = re.compile(r"^\s*(?:--[\w-]+|\$[\w-]+)\s*:")
# href/to values are blanked before the scan so `#dad` reads as an anchor, not a colour.
LINKY = re.compile(r"""\b(?:href|to)\s*=\s*(?:"[^"]*"|'[^']*')""")


def scan_files(paths):
    """Every scannable file under the given files/dirs, de-duplicated, sorted."""
    out = []
    for p in paths:
        if os.path.isfile(p):
            if p.lower().endswith(SCAN_EXT):
                out.append(p)
        elif os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = [d for d in dirs if d not in SCAN_SKIP]
                for f in sorted(files):
                    if f.lower().endswith(SCAN_EXT):
                        out.append(os.path.join(root, f))
    return sorted(set(out))


def token_names(colours, fonts):
    """Lowercased name fragments of every declared token, for palette resolution."""
    names = set()
    for n in list(colours.values()) + list(fonts.values()):
        n = str(n).lower()
        names.add(n)
        names.update(part for part in re.split(r"[^a-z0-9]+", n) if part)
    return names


def scan_hits(paths, colours, names):
    """One row per hit: (path, line, kind, value, nearest-token-or-'-')."""
    rows, resolved = [], 0
    for path in scan_files(paths):
        text = LINKY.sub(lambda m: " " * len(m.group(0)), _read(path))
        lines = text.split("\n")
        for i, line in enumerate(lines, 1):
            is_decl = bool(DECL_LINE.match(line))
            for lit, rgb in colours_in(line):
                if is_decl:
                    continue
                if rgb in colours:
                    resolved += 1
                    continue
                if colours:
                    best = min(colours.items(), key=lambda kv: dist(rgb, kv[0]))
                    near = "%s (Δ%.0f)" % (best[1], dist(rgb, best[0]))
                else:
                    near = "-"
                rows.append((path, i, "literal", lit, near))
            for m in TW_UTIL.finditer(line):
                scale, shade = m.group(1), m.group(2)
                if scale in names or f"{scale}-{shade}" in names:
                    resolved += 1
                    continue
                rows.append((path, i, "tw-palette", m.group(0), "-"))
    return rows, resolved


def run_scan(args):
    colours, fonts = repo_tokens(args.repo)
    files = scan_files(args.paths)
    if not colours and not fonts:
        print("drift: no design-system/tokens.json, tailwind.config.* or `--token:` custom property "
              f"found under {os.path.abspath(args.repo)} — NOT MEASURED. Run /design-kit:system first; "
              "a drift check that cannot find the tokens has not cleared anything.")
        return 2
    if not files:
        print(f"drift: no {'/'.join(SCAN_EXT)} file among the given paths — nothing scanned")
        return 0
    rows, resolved = scan_hits(args.paths, colours, token_names(colours, fonts))
    print(f"DRIFT SCAN — {len(files)} file(s) vs {len(colours)} declared colour token(s) "
          f"in {os.path.abspath(args.repo)}")
    print("| file:line | kind | value | nearest token |")
    print("|---|---|---|---|")
    for path, line, kind, value, near in rows:
        print(f"| {path}:{line} | {kind} | {value} | {near} |")
    if not rows:
        print("| - | - | (no literal colour and no named palette utility) | - |")
    lit = sum(1 for r in rows if r[2] == "literal")
    print(f"summary: {len(rows)} hit(s) — {lit} literal colour, {len(rows) - lit} named palette "
          f"utility; {resolved} value(s) already resolved to a token")
    if rows and args.ci:
        print("drift: --ci — every hit above must become a token reference before this passes")
        return 1
    return 0


def dist(a, b):
    return math.sqrt(sum((x - y) ** 2 for x, y in zip(a, b)))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("paths", nargs="*", help="the bundle directory, or the files/dirs to --scan")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--near", type=float, default=24.0, help="RGB distance that still counts as near")
    ap.add_argument("--scan", action="store_true", help="component scan mode over tsx/jsx/vue/blade/css/scss")
    ap.add_argument("--ci", action="store_true", help="scan mode: exit 1 on any hit")
    args = ap.parse_args(argv)
    if args.scan:
        if not args.paths:
            args.paths = ["."]
        return run_scan(args)
    if len(args.paths) != 1:
        ap.error("bundle mode takes exactly one directory (or use --scan)")
    args.bundle = args.paths[0]
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
