#!/usr/bin/env python3
"""system-extract.py — extract a design system from a repo, a live URL, or a brand
asset directory into design-system/: tokens.json (DTCG-shaped), DESIGN-SYSTEM.md
(the plain `## Design system` block plus a component inventory) and kit.html (a
UI-kit page whose every card carries an `@dsCard` marker).

WHAT IT CATCHES. Every token it emits points back to a source line; nothing is
invented. A value that is not in the source does not appear, which is the rule
the model gets wrong from memory — it "remembers" a palette the repo never had.
Deterministic: same input, byte-identical output, so a diff of design-system/
after a re-run is a real change in the source.

WHAT IT DOES NOT CATCH. Repo mode reads text with regexes — no JS evaluation, so
a Tailwind config built from imports or functions yields only its literal
entries. URL mode fetches HTML and linked stylesheets without running JS, so
styles injected at runtime (CSS-in-JS, Tailwind CDN builds) are invisible; it says
so in the output. Naming (which of two primaries is THE primary) is the
reader's judgment, flagged, never decided here. Component "approximations" in
kit.html are static HTML carrying the real component's name, path and props —
they are not the component.

Standing: scripts/__tests__/system-extract.test.sh drives the three sources on
fixtures and asserts the output shape; the determinism claim is asserted by
running twice and comparing bytes.

Usage:
  system-extract.py <repo-dir | https://url | brand-dir> [--source repo|url|brand]
                    [--out design-system] [--kit-shell path] [--project-name X]
                    [--dry-run]
"""
import argparse
import datetime as _dt
import collections
import html
import json
import os
import re
import sys
import urllib.parse
import urllib.request


HEX_RE = re.compile(r"#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b")
COLOR_FN_RE = re.compile(r"\b(?:rgba?|hsla?|oklch|oklab|lab|lch|hwb|color)\([^;)]*\)")
VAR_REF_RE = re.compile(r"var\(\s*(--[A-Za-z0-9_-]+)\s*(?:,[^)]*)?\)")
NAMED_COLORS = {
    "white", "black", "transparent", "currentcolor", "red", "blue", "green", "gray",
    "grey", "silver", "navy", "teal", "orange", "yellow", "purple", "pink",
}
COLOR_WORDS = (
    "color", "colour", "background", "foreground", "primary", "secondary", "accent",
    "muted", "destructive", "border", "ring", "card", "popover", "chart", "sidebar",
    "surface", "ink", "brand", "success", "warning", "danger", "info", "error",
    "text", "fill", "stroke", "bg", "fg", "neutral", "slate", "zinc", "stone",
)
RADIUS_WORDS = ("radius", "rounded")
SPACING_WORDS = ("spacing", "space", "gap", "inset", "size")
FONT_WORDS = ("font", "family", "typeface")
DURATION_WORDS = ("duration", "transition-time", "speed")
EASING_WORDS = ("ease", "easing", "timing")
SHADOW_WORDS = ("shadow", "elevation")

TIME_RE = re.compile(r"^\d*\.?\d+(?:ms|s)$")
DIM_RE = re.compile(r"^-?\d*\.?\d+(?:px|rem|em|%|vh|vw|ch|pt)$")
BEZIER_RE = re.compile(r"cubic-bezier\(\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*,\s*([\d.-]+)\s*\)")
NAMED_EASE = {"ease", "ease-in", "ease-out", "ease-in-out", "linear", "step-start", "step-end"}


def looks_like_color(value):
    v = value.strip()
    if HEX_RE.fullmatch(v) or COLOR_FN_RE.fullmatch(v):
        return True
    if v.lower() in NAMED_COLORS:
        return True
    # shadcn v3 HSL triplets: "222.2 47.4% 11.2%"
    if re.fullmatch(r"\d*\.?\d+\s+\d*\.?\d+%\s+\d*\.?\d+%", v):
        return True
    return False


def classify(name, value):
    """Return a DTCG $type for a custom property or config key, or None to skip."""
    n = name.lower().lstrip("-$")
    v = value.strip()
    if VAR_REF_RE.fullmatch(v) or v.startswith("{"):
        ref = VAR_REF_RE.fullmatch(v)
        inner = ref.group(1).lower().lstrip("-") if ref else v
        if any(w in n for w in FONT_WORDS) or any(w in inner for w in FONT_WORDS):
            return "fontFamily"
        if any(w in n for w in RADIUS_WORDS + SPACING_WORDS):
            return "dimension"
        return "color"
    if looks_like_color(v):
        return "color"
    if any(w in n for w in FONT_WORDS) and not DIM_RE.fullmatch(v):
        return "fontFamily"
    if any(w in n for w in DURATION_WORDS) or TIME_RE.fullmatch(v):
        return "duration" if TIME_RE.fullmatch(v) else None
    if any(w in n for w in EASING_WORDS) or BEZIER_RE.fullmatch(v) or v in NAMED_EASE:
        return "cubicBezier" if (BEZIER_RE.fullmatch(v) or v in NAMED_EASE) else None
    if any(w in n for w in SHADOW_WORDS):
        return "shadow"
    if any(w in n for w in RADIUS_WORDS + SPACING_WORDS) and (DIM_RE.fullmatch(v) or v == "0"):
        return "dimension"
    if any(w in n for w in COLOR_WORDS) and not DIM_RE.fullmatch(v):
        return "color"
    return None


def group_for(name, ttype):
    n = name.lower().lstrip("-$")
    if ttype == "color":
        return "color"
    if ttype == "fontFamily":
        return "typography.family"
    if ttype == "dimension":
        return "radius" if any(w in n for w in RADIUS_WORDS) else "spacing"
    if ttype == "duration":
        return "motion.duration"
    if ttype == "cubicBezier":
        return "motion.easing"
    if ttype == "shadow":
        return "elevation"
    return "other"


def token_name(raw):
    n = raw.strip().lstrip("-$").lower()
    for prefix in ("color-", "colour-", "font-", "radius-", "spacing-", "space-", "duration-", "ease-", "shadow-"):
        if n.startswith(prefix) and len(n) > len(prefix):
            n = n[len(prefix):]
            break
    return re.sub(r"[^a-z0-9.-]+", "-", n).strip("-") or raw.strip("-$")


def to_dtcg_value(ttype, value):
    v = value.strip()
    ref = VAR_REF_RE.fullmatch(v)
    if ref:
        return "{" + token_path_from_var(ref.group(1)) + "}"
    if ttype == "cubicBezier":
        m = BEZIER_RE.fullmatch(v)
        if m:
            return [float(x) for x in m.groups()]
        return v
    if ttype == "fontFamily":
        return v.split(",")[0].strip().strip("'\"")
    return v


def token_path_from_var(var):
    name = var.lstrip("-").lower()
    if any(w in name for w in FONT_WORDS):
        return "typography.family." + token_name(var)
    if any(w in name for w in RADIUS_WORDS):
        return "radius." + token_name(var)
    if any(w in name for w in SPACING_WORDS):
        return "spacing." + token_name(var)
    return "color." + token_name(var)



DARK_SELECTORS = (".dark", "[data-theme=dark]", "[data-theme=\"dark\"]", "[data-theme='dark']",
                  "[data-mode=dark]", "[data-mode=\"dark\"]", "html.dark", ":root.dark", ".theme-dark")
LIGHT_SELECTORS = (":root", "html", ":host", "@theme", ".light", "[data-theme=light]", "[data-theme=\"light\"]")


def strip_comments(css):
    return re.sub(r"/\*.*?\*/", "", css, flags=re.S)


def iter_blocks(css):
    """Yield (selector, body, line) for top-level and one-level-nested blocks, brace-balanced."""
    i, n = 0, len(css)
    stack = []
    line = 1
    sel_start = 0
    while i < n:
        c = css[i]
        if c == "\n":
            line += 1
        if c == "{":
            selector = re.split(r"[};]", css[sel_start:i])[-1].strip()
            stack.append((selector, i + 1, line))
        elif c == "}":
            if stack:
                selector, start, sline = stack.pop()
                yield selector, css[start:i], sline
            sel_start = i + 1
        i += 1


def custom_props(body, base_line):
    out = []
    for m in re.finditer(r"(--[A-Za-z0-9_-]+)\s*:\s*([^;{}]+?)\s*(?:;|\Z)", body):
        line = base_line + body[:m.start()].count("\n")
        out.append((m.group(1), m.group(2).strip(), line))
    return out


def mode_of(selector):
    s = " ".join(selector.split())
    sl = s.lower()
    if "prefers-color-scheme: dark" in sl or "prefers-color-scheme:dark" in sl:
        return "dark"
    for d in DARK_SELECTORS:
        if d in sl:
            return "dark"
    for l in LIGHT_SELECTORS:
        if sl == l or sl.startswith(l + " ") or sl.startswith(l + ",") or sl.startswith(l + "{"):
            return "light"
    if sl.startswith("@media") and "dark" in sl:
        return "dark"
    return None


class Extraction:
    def __init__(self):
        self.tokens = collections.OrderedDict()   # path -> dict
        self.fonts = collections.Counter()        # family -> uses
        self.font_sources = {}
        self.literal_colors = collections.Counter()
        self.components = []
        self.notes = []
        self.sources = []

    def add(self, name, value, ttype, source, mode="light"):
        path = group_for(name, ttype) + "." + token_name(name)
        entry = self.tokens.get(path)
        val = to_dtcg_value(ttype, value)
        if entry is None:
            entry = {"$type": ttype, "modes": {}, "sources": []}
            self.tokens[path] = entry
        if mode not in entry["modes"]:
            entry["modes"][mode] = val
        if source not in entry["sources"]:
            entry["sources"].append(source)

    def add_font(self, family, source):
        fam = family.strip().strip("'\"").strip()
        if not fam or fam.lower() in ("inherit", "initial", "unset", "var"):
            return
        self.fonts[fam] += 1
        self.font_sources.setdefault(fam, source)


def scan_css_text(css, rel, ex, default_mode="light"):
    css = strip_comments(css)
    for selector, body, line in iter_blocks(css):
        sel = selector.strip()
        if sel.startswith("@font-face"):
            m = re.search(r"font-family\s*:\s*([^;]+);", body)
            if m:
                ex.add_font(m.group(1), f"{rel}:{line}")
            continue
        mode = mode_of(sel)
        if sel.startswith("@theme"):
            mode = "light"
        if mode is None and default_mode == "dark":
            mode = "dark"
        for name, value, vline in custom_props(body, line):
            ttype = classify(name, value)
            if ttype and mode:
                ex.add(name, value, ttype, f"{rel}:{vline}", mode)
        for m in re.finditer(r"font-family\s*:\s*([^;}]+)", body):
            for fam in m.group(1).split(","):
                fam = fam.strip().strip("'\"")
                if fam and not fam.startswith("var(") and fam.lower() not in (
                    "sans-serif", "serif", "monospace", "system-ui", "ui-sans-serif",
                    "ui-serif", "ui-monospace", "cursive", "fantasy", "inherit", "initial"):
                    ex.add_font(fam, f"{rel}:{line}")
    for m in HEX_RE.finditer(css):
        ex.literal_colors[m.group(0).lower()] += 1
    for m in re.finditer(r"(\$[A-Za-z][A-Za-z0-9_-]*)\s*:\s*([^;!]+)\s*(?:!default)?\s*;", css):
        ttype = classify(m.group(1), m.group(2))
        if ttype:
            line = css[:m.start()].count("\n") + 1
            ex.add(m.group(1), m.group(2), ttype, f"{rel}:{line}", "light")



def balanced(text, start):
    """Return the substring from text[start]=='{' to its matching '}' inclusive."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return text[start:]


def parse_js_object(obj, prefix=""):
    """Flatten `{ a: 'x', b: { c: 'y' } }` into [(a, x), (b-c, y)] by regex; no eval."""
    out = []
    i = 0
    body = obj.strip()[1:-1] if obj.strip().startswith("{") else obj
    key_re = re.compile(r"\s*['\"]?([A-Za-z0-9_$-]+)['\"]?\s*:\s*")
    while i < len(body):
        m = key_re.match(body, i)
        if not m:
            i += 1
            continue
        key = m.group(1)
        j = m.end()
        if j < len(body) and body[j] == "{":
            sub = balanced(body, j)
            out.extend(parse_js_object(sub, prefix + key + "-"))
            i = j + len(sub)
        else:
            k = j
            while k < len(body) and body[k] not in ",\n}":
                k += 1
            val = body[j:k].strip().strip("'\"`").strip()
            if val and not val.startswith("[") and not val.startswith("("):
                out.append((prefix + key, val))
            i = k + 1
    return out


def scan_tailwind_config(text, rel, ex):
    text = re.sub(r"//[^\n]*", "", text)
    m = re.search(r"extend\s*:\s*\{", text)
    scope = balanced(text, m.end() - 1) if m else None
    if scope is None:
        m = re.search(r"theme\s*:\s*\{", text)
        scope = balanced(text, m.end() - 1) if m else ""
    for section, ttype in (("colors", "color"), ("borderRadius", "dimension"), ("spacing", "dimension"),
                           ("fontFamily", "fontFamily"), ("transitionDuration", "duration"),
                           ("transitionTimingFunction", "cubicBezier"), ("boxShadow", "shadow")):
        sm = re.search(r"\b" + section + r"\s*:\s*\{", scope)
        if not sm:
            continue
        sub = balanced(scope, sm.end() - 1)
        line = text.count("\n", 0, text.find(sub)) + 1 if sub in text else 1
        for key, val in parse_js_object(sub):
            name = {"colors": "color-", "borderRadius": "radius-", "spacing": "spacing-", "fontFamily": "font-",
                    "transitionDuration": "duration-", "transitionTimingFunction": "ease-", "boxShadow": "shadow-"}[section] + key
            value = val
            vm = re.fullmatch(r"(?:hsl|rgb|oklch)\(\s*var\((--[A-Za-z0-9_-]+)\)[^)]*\)", val) or VAR_REF_RE.fullmatch(val)
            if vm:
                value = f"var({vm.group(1)})"
            if ttype == "fontFamily" and "," in val:
                value = val.split(",")[0].strip().strip("'\"")
            t = classify(name, value) or ttype
            ex.add(name, value, t, f"{rel}:{line}", "light")



COMPONENT_DIRS = ("src/components", "components", "resources/js/Components", "resources/js/components",
                  "resources/views/components", "app/View/Components", "src/lib/components", "lib/components")
STORY_GLOB = re.compile(r"\.stories\.(tsx|ts|jsx|js|mdx|vue)$")
COMPONENT_EXT = (".tsx", ".jsx", ".vue", ".svelte", ".blade.php", ".php", ".ts", ".js")
SKIP_FILE = re.compile(r"(\.test\.|\.spec\.|\.stories\.|\.d\.ts$|/index\.[tj]sx?$|__tests__/)")


def pascal(name):
    parts = re.split(r"[^A-Za-z0-9]+", name)
    return "".join(p[:1].upper() + p[1:] for p in parts if p)


def _ts_default_map(text):
    """Defaults from a destructured signature: `function X({ a = 1, b = "x" }: Props)`
    or `({ a = 1 }) =>`. Best-effort; a miss leaves default null."""
    out = {}
    m = re.search(r"\(\s*\{([^}]*)\}\s*(?::\s*[A-Za-z_$][\w$<>,\s.|&\[\]]*)?\s*\)", text)
    if not m:
        return out
    for part in re.split(r",(?![^(\[{]*[)\]}])", m.group(1)):
        dm = re.match(r"\s*([A-Za-z_$][\w$]*)\s*=\s*(.+?)\s*$", part.strip(), re.S)
        if dm:
            out[dm.group(1)] = _literal(dm.group(2).strip())
    return out


def _literal(raw):
    raw = raw.strip().rstrip(",")
    if re.match(r"^(['\"]).*\1$", raw):
        return raw[1:-1]
    if raw in ("true", "false"):
        return raw == "true"
    if raw in ("null", "undefined"):
        return None
    if re.match(r"^-?\d+(\.\d+)?$", raw):
        return float(raw) if "." in raw else int(raw)
    return raw


def _ts_decls(block):
    """Split an interface/type body into `name?: type` declarations, honouring
    nested braces and generics so a union of object literals does not split."""
    depth = 0; cur = ""; out = []
    for ch in block:
        if ch in "{(<[":
            depth += 1
        elif ch in "})>]":
            depth -= 1
        if ch in ";\n" and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def props_from_source(text, ext):
    """Return (names, variants, details, gaps). `details` is the components.json
    shape — {name, type, default, required} — and `gaps` says honestly why a prop
    set may be incomplete (a generic, an `extends`, an intersection, a spread)."""
    props, variants, details, gaps = [], collections.OrderedDict(), [], []
    def add(name, ptype, default=None, required=False):
        if name in props:
            return
        props.append(name)
        details.append({"name": name, "type": ptype, "default": default, "required": required})
    if ext in (".tsx", ".jsx", ".ts", ".js", ".vue", ".svelte"):
        defaults = _ts_default_map(text)
        found_block = False
        for m in re.finditer(r"(?:interface\s+(\w*Props\w*)(\s*<[^>]*>)?\s*(extends[^{]+)?\{|type\s+(\w*Props\w*)(\s*<[^>]*>)?\s*=\s*([^{=]+&\s*)?\{|defineProps<\s*\{)", text):
            found_block = True
            iname = m.group(1) or m.group(4) or "defineProps"
            generic = m.group(2) or m.group(5)
            if generic:
                gaps.append(f"generic interface {iname}{generic.strip()} — the type parameter's members are not listed")
            if m.group(3):
                gaps.append(f"{iname} {m.group(3).strip()} — inherited props are not listed")
            if m.group(6):
                gaps.append(f"{iname} is an intersection with {m.group(6).replace('&', '').strip()} — those members are not listed")
            block = balanced(text, m.end() - 1)
            for decl in _ts_decls(block[1:-1]):
                pm = re.match(r"\s*(?:readonly\s+)?([A-Za-z_$][A-Za-z0-9_$]*)(\??)\s*:\s*(.+)$", decl.strip(), re.S)
                if not pm:
                    if re.match(r"\s*\.\.\.", decl):
                        gaps.append(f"{iname} spreads another type — those members are not listed")
                    continue
                pname, opt, ptype = pm.group(1), pm.group(2), " ".join(pm.group(3).split()).rstrip(",")
                add(pname, ptype, defaults.get(pname), required=(opt == "" and pname not in defaults))
                lits = re.findall(r"['\"]([A-Za-z0-9_-]+)['\"]", ptype)
                if len(lits) >= 2 and "|" in ptype and pname not in variants:
                    variants[pname] = lits
        wd = re.search(r"withDefaults\s*\(\s*defineProps<[^(]*\(\)\s*,\s*\{", text)
        if wd:
            for key, val in parse_js_object(balanced(text, wd.end() - 1)):
                for d in details:
                    if d["name"] == key:
                        d["default"] = _literal(val) if isinstance(val, str) else val
                        d["required"] = False
        dm = re.search(r"defineProps\(\s*\{", text)
        if dm:
            found_block = True
            for key, val in parse_js_object(balanced(text, dm.end() - 1)):
                if "-" not in key:
                    add(key, str(val).strip() if val is not None else "unknown", None, False)
        cm = re.search(r"variants\s*:\s*\{", text)
        if cm:
            block = balanced(text, cm.end() - 1)
            for vm in re.finditer(r"^\s*([A-Za-z_$][A-Za-z0-9_$]*)\s*:\s*\{", block[1:-1], re.M):
                sub = balanced(block[1:], vm.end() - 1)
                keys = re.findall(r"^\s*['\"]?([A-Za-z0-9_-]+)['\"]?\s*:", sub[1:-1], re.M)
                if keys:
                    variants.setdefault(vm.group(1), keys)
        if not found_block and re.search(r"export\s+(?:default\s+)?(?:function|const)\s+[A-Z]", text):
            gaps.append("no props signature found by the extractor (no `*Props` interface/type or defineProps) — open the file")
    elif ext == ".blade.php":
        m = re.search(r"@props\(\s*\[", text)
        if m:
            block = text[m.end():]
            end = block.find("]")
            for part in block[:end if end > 0 else None].split(","):
                pm = re.match(r"\s*['\"]([A-Za-z0-9_-]+)['\"]\s*(?:=>\s*(.+))?\s*$", part.strip(), re.S)
                if pm:
                    default = _literal(pm.group(2)) if pm.group(2) else None
                    add(pm.group(1), "mixed", default, required=pm.group(2) is None)
        else:
            gaps.append("no @props([...]) — attributes pass through $attributes; open the file")
    elif ext == ".php":
        m = re.search(r"function\s+__construct\s*\(", text)
        if m:
            sig = text[m.end():text.find(")", m.end())]
            for pm in re.finditer(r"(?:public|protected|private)?\s*(?:readonly\s+)?([?\w|\\]+)?\s*\$([A-Za-z_][A-Za-z0-9_]*)\s*(?:=\s*([^,]+))?", sig):
                if pm.group(2):
                    add(pm.group(2), (pm.group(1) or "mixed").strip(), _literal(pm.group(3)) if pm.group(3) else None, required=pm.group(3) is None)
    return props, variants, details, gaps


def scan_components(root, ex):
    stories = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in ("node_modules", "vendor", ".git", "dist", "build", ".next", "storage")]
        for fn in filenames:
            if STORY_GLOB.search(fn):
                full = os.path.join(dirpath, fn)
                base = pascal(STORY_GLOB.sub("", fn))
                try:
                    txt = open(full, encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                names = re.findall(r"^export\s+const\s+([A-Z][A-Za-z0-9]*)", txt, re.M)
                stories[base] = [n for n in names if n not in ("Default",)] or names
    seen = set()
    for cdir in COMPONENT_DIRS:
        base = os.path.join(root, cdir)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = sorted(d for d in dirnames if d not in ("node_modules", "__tests__"))
            for fn in sorted(filenames):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, root).replace(os.sep, "/")
                if SKIP_FILE.search("/" + rel):
                    continue
                ext = ".blade.php" if fn.endswith(".blade.php") else os.path.splitext(fn)[1]
                if ext not in COMPONENT_EXT:
                    continue
                name = pascal(fn[:-len(ext)] if fn.endswith(ext) else os.path.splitext(fn)[0])
                if ext in (".ts", ".js"):
                    try:
                        head = open(full, encoding="utf-8", errors="replace").read(4000)
                    except OSError:
                        continue
                    if not re.search(r"export\s+(?:default\s+)?(?:function|const)\s+[A-Z]", head):
                        continue
                if name in seen:
                    continue
                try:
                    text = open(full, encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                props, variants, details, gaps = props_from_source(text, ext)
                if name in stories and "stories" not in variants:
                    variants["stories"] = stories[name]
                seen.add(name)
                export = "default" if re.search(r"export\s+default\b", text) and not re.search(r"export\s+(?:function|const|class)\s+" + re.escape(name) + r"\b", text) else "named"
                if ext in (".vue", ".svelte", ".blade.php", ".php"):
                    export = "default"
                ex.components.append({"name": name, "path": rel, "props": props,
                                      "variants": {k: v for k, v in variants.items()},
                                      "details": details, "gaps": gaps, "export": export})
    # A Blade view without @props may be the template of a class component
    # (app/View/Components/<Name>.php) whose promoted constructor parameters ARE
    # the props — Laravel's own convention; the Blade-first walk hid it (measured
    # 2026-09-22 on a fixture: Alert.php's type/message/dismissible read as "no props").
    for c in ex.components:
        if not c["path"].endswith(".blade.php") or c["props"]:
            continue
        cls = os.path.join(root, "app", "View", "Components", c["name"] + ".php")
        if not os.path.isfile(cls):
            continue
        try:
            ctext = open(cls, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        props, variants, details, gaps = props_from_source(ctext, ".php")
        if props:
            c["props"] = props
            c["details"] = details
            c["variants"].update(variants)
            c["gaps"] = [g for g in c["gaps"] if not g.startswith("no @props")]
    ex.components.sort(key=lambda c: (c["path"]))



CSS_DIRS = ("src", "resources", "app", "styles", "public", "assets", "css", "scss", "theme", "themes")
CSS_EXT = (".css", ".scss", ".sass", ".less", ".pcss")


def extract_repo(root, ex):
    root = os.path.abspath(root)
    css_paths = []
    cj = os.path.join(root, "components.json")
    if os.path.isfile(cj):
        try:
            data = json.load(open(cj, encoding="utf-8"))
            tw = data.get("tailwind", {})
            ex.notes.append(f"shadcn components.json: style={data.get('style', '?')}, baseColor={tw.get('baseColor', '?')}, cssVariables={tw.get('cssVariables', '?')}")
            if tw.get("css"):
                p = os.path.join(root, tw["css"])
                if os.path.isfile(p):
                    css_paths.append(p)
        except (OSError, ValueError) as exc:
            ex.notes.append(f"components.json unreadable: {exc}")
    for d in CSS_DIRS:
        base = os.path.join(root, d)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = sorted(x for x in dirnames if x not in ("node_modules", "vendor", "dist", "build", ".next"))
            for fn in sorted(filenames):
                if fn.endswith(CSS_EXT) and not fn.endswith(".min.css"):
                    css_paths.append(os.path.join(dirpath, fn))
    for cp in sorted(set(css_paths)):
        rel = os.path.relpath(cp, root).replace(os.sep, "/")
        try:
            scan_css_text(open(cp, encoding="utf-8", errors="replace").read(), rel, ex)
            ex.sources.append(rel)
        except OSError:
            continue
    for fn in ("tailwind.config.js", "tailwind.config.ts", "tailwind.config.cjs", "tailwind.config.mjs"):
        p = os.path.join(root, fn)
        if os.path.isfile(p):
            scan_tailwind_config(open(p, encoding="utf-8", errors="replace").read(), fn, ex)
            ex.sources.append(fn)
    scan_components(root, ex)
    if not ex.sources:
        ex.notes.append("no stylesheet or tailwind config found under " + ", ".join(CSS_DIRS))


def fetch(url, timeout=10):
    req = urllib.request.Request(url, headers={"User-Agent": "design-kit/0.1 (+system-extract)"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8", errors="replace")


def extract_url(url, ex):
    try:
        page = fetch(url)
    except Exception as exc:  # noqa: BLE001 — the message is the deliverable
        ex.notes.append(f"fetch failed for {url}: {exc}")
        return
    ex.sources.append(url)
    for m in re.finditer(r"<style[^>]*>(.*?)</style>", page, re.S | re.I):
        scan_css_text(m.group(1), url + "#style", ex)
    hrefs = re.findall(r"<link[^>]+rel=[\"'][^\"']*stylesheet[^\"']*[\"'][^>]*href=[\"']([^\"']+)[\"']", page, re.I)
    hrefs += re.findall(r"<link[^>]+href=[\"']([^\"']+)[\"'][^>]*rel=[\"'][^\"']*stylesheet[^\"']*[\"']", page, re.I)
    for href in list(dict.fromkeys(hrefs))[:20]:
        full = urllib.parse.urljoin(url, href)
        if "fonts.googleapis.com" in full:
            for fam in re.findall(r"family=([^&:]+)", full):
                ex.add_font(urllib.parse.unquote(fam).replace("+", " "), full)
            continue
        try:
            scan_css_text(fetch(full), full, ex)
            ex.sources.append(full)
        except Exception as exc:  # noqa: BLE001
            ex.notes.append(f"stylesheet skipped {full}: {exc}")
    for m in re.finditer(r"style=[\"']([^\"']+)[\"']", page):
        for h in HEX_RE.findall(m.group(1)):
            ex.literal_colors[h.lower()] += 1
    ex.notes.append("URL mode reads HTML and linked stylesheets without running JavaScript; styles injected at runtime are not seen.")


def extract_brand(root, ex):
    root = os.path.abspath(root)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        for fn in sorted(filenames):
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            low = fn.lower()
            try:
                text = open(full, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if low.endswith(CSS_EXT):
                scan_css_text(text, rel, ex)
                ex.sources.append(rel)
            elif low.endswith(".svg"):
                for m in re.finditer(r"(?:fill|stroke|stop-color)\s*[:=]\s*[\"']?(#[0-9a-fA-F]{3,8})", text):
                    ex.literal_colors[m.group(1).lower()] += 1
                ex.sources.append(rel)
            elif low.endswith((".md", ".txt")):
                for i, line in enumerate(text.splitlines(), 1):
                    for h in HEX_RE.findall(line):
                        ex.literal_colors[h.lower()] += 1
                        label = re.sub(r"[#:\-*|`]", " ", line.split(h)[0]).strip().split()
                        if label:
                            ex.add("color-" + "-".join(label[-2:]).lower(), h, "color", f"{rel}:{i}", "light")
                    km = re.search(r"(?:font|typeface|family)[^A-Za-z]*[:\-]\s*", line, re.I)
                    fm = re.match(r"([A-Z][A-Za-z0-9]+(?: [A-Z][A-Za-z0-9]+){0,2})", line[km.end():]) if km else None
                    if fm:
                        ex.add_font(fm.group(1), f"{rel}:{i}")
                ex.sources.append(rel)



def build_tokens(ex):
    out = collections.OrderedDict()
    for path in sorted(ex.tokens):
        entry = ex.tokens[path]
        modes = entry["modes"]
        light = modes.get("light", next(iter(modes.values())))
        node = collections.OrderedDict()
        node["$type"] = entry["$type"]
        node["$value"] = light
        ext = collections.OrderedDict()
        if "dark" in modes and modes["dark"] != light:
            ext["modes"] = {"dark": modes["dark"]}
        ext["sources"] = sorted(entry["sources"])
        node["$extensions"] = {"design-kit": ext}
        cur = out
        parts = path.split(".")
        for p in parts[:-1]:
            cur = cur.setdefault(p, collections.OrderedDict())
        cur[parts[-1]] = node
    fam = collections.OrderedDict()
    for family, uses in sorted(ex.fonts.items(), key=lambda kv: (-kv[1], kv[0])):
        key = re.sub(r"[^a-z0-9]+", "-", family.lower()).strip("-")
        if key in out.get("typography", {}).get("family", {}):
            continue
        fam[key] = collections.OrderedDict([("$type", "fontFamily"), ("$value", family),
                                            ("$extensions", {"design-kit": {"uses": uses, "sources": [ex.font_sources[family]]}})])
    if fam:
        out.setdefault("typography", collections.OrderedDict()).setdefault("family", collections.OrderedDict()).update(fam)
    if ex.literal_colors:
        top = ex.literal_colors.most_common(12)
        out["$extensions"] = {"design-kit": {"literalColors": [{"value": v, "uses": c} for v, c in sorted(top, key=lambda kv: (-kv[1], kv[0]))]}}
    return out


def build_components(ex, source_label):
    """The inventory as a machine-readable file beside tokens.json — the shape
    scaffold-fill.py reads. Deterministic: components sorted by path (already),
    props in declaration order, variants in declaration order."""
    comps = []
    for c in ex.components:
        comps.append(collections.OrderedDict([
            ("name", c["name"]),
            ("source", c["path"]),
            ("export", c.get("export", "named")),
            ("props", c.get("details", [])),
            ("variants", collections.OrderedDict((k, v) for k, v in c["variants"].items() if k != "stories")),
            ("stories", c["variants"].get("stories", [])),
            ("gaps", c.get("gaps", [])),
        ]))
    return collections.OrderedDict([("generated", _dt.date.today().isoformat()), ("source", source_label), ("components", comps)])


def check_tokens(fresh, committed_path):
    """Compare a fresh extraction against the committed tokens.json. Prints one
    `check:` line per moved, added or removed token; returns the line count."""
    try:
        committed = json.load(open(committed_path, encoding="utf-8"))
    except (OSError, ValueError):
        print(f"check: no readable {committed_path} — run /design-kit:system first")
        return 1
    def table(tokens):
        out = collections.OrderedDict()
        for path, node in flat(tokens):
            dk = node.get("$extensions", {}).get("design-kit", {})
            out[path] = (str(node.get("$value")), str(dk.get("modes", {}).get("dark", "")), (dk.get("sources") or [""])[0])
        return out
    a, b = table(committed), table(fresh)
    lines = 0
    for path in sorted(set(a) | set(b)):
        if path not in b:
            print(f"check: {path} {a[path][0]} → — (removed; was {a[path][2]})"); lines += 1
        elif path not in a:
            print(f"check: {path} — → {b[path][0]} ({b[path][2]})"); lines += 1
        elif a[path][0] != b[path][0]:
            print(f"check: {path} {a[path][0]} → {b[path][0]} ({b[path][2]})"); lines += 1
        elif a[path][1] != b[path][1]:
            print(f"check: {path} dark {a[path][1] or '—'} → {b[path][1] or '—'} ({b[path][2]})"); lines += 1
    return lines


def flat(tokens, prefix=""):
    for k, v in tokens.items():
        if k.startswith("$"):
            continue
        if isinstance(v, dict) and "$value" in v:
            yield prefix + k, v
        elif isinstance(v, dict):
            yield from flat(v, prefix + k + ".")


def build_markdown(ex, tokens, project, source_label):
    rows = list(flat(tokens))
    by = collections.defaultdict(list)
    for path, node in rows:
        by[path.split(".")[0]].append((path, node))
    lines = [f"# Design system — {project}", "",
             f"Extracted by design-kit from {source_label}. Every value below carries a `path:line` source in tokens.json; nothing here was invented. Re-run `/design-kit:system` after the source changes.", "",
             "## Design system", ""]
    colors = by.get("color", [])
    if colors:
        lines.append("- Colors: " + ", ".join(f"{p.split('.', 1)[1]} {n['$value']}" + (f" (dark {n['$extensions']['design-kit']['modes']['dark']})" if "modes" in n["$extensions"]["design-kit"] else "") for p, n in colors[:24]))
    fams = [(p, n) for p, n in by.get("typography", []) if ".family." in p]
    if fams:
        lines.append("- Typography: " + ", ".join(f"{n['$value']} ({p.split('.')[-1]})" for p, n in fams[:6]))
    sp = by.get("spacing", [])
    if sp:
        lines.append("- Spacing: " + ", ".join(f"{p.split('.', 1)[1]} {n['$value']}" for p, n in sp[:12]))
    rd = by.get("radius", [])
    if rd:
        lines.append("- Radius: " + ", ".join(f"{p.split('.', 1)[1]} {n['$value']}" for p, n in rd[:8]))
    mo = by.get("motion", [])
    if mo:
        lines.append("- Motion: " + ", ".join(f"{p.split('.', 2)[-1]} {n['$value']}" for p, n in mo[:8]))
    el = by.get("elevation", [])
    if el:
        lines.append("- Elevation: " + ", ".join(f"{p.split('.', 1)[1]} {n['$value']}" for p, n in el[:6]))
    if not (colors or fams or sp or rd or mo):
        lines.append("- (no tokens found — see below)")
    lines += ["", "## Components", ""]
    if ex.components:
        lines.append("| Component | Source | Props | Variants |")
        lines.append("|---|---|---|---|")
        for c in ex.components:
            var = "; ".join(f"{k}: {', '.join(v)}" for k, v in c["variants"].items()) or "—"
            lines.append(f"| {c['name']} | `{c['path']}` | {', '.join(c['props']) or '—'} | {var} |")
    else:
        lines.append("None found under " + ", ".join(COMPONENT_DIRS) + ".")
    lines += ["", "## Not found", ""]
    missing = []
    if not colors:
        missing.append("colour tokens (custom properties, Tailwind colors, SCSS variables)")
    elif not any("modes" in n["$extensions"]["design-kit"] for _, n in colors):
        missing.append("a dark mode (no `.dark`, `[data-theme=dark]` or `prefers-color-scheme: dark` block changed a colour)")
    if not fams:
        missing.append("a typeface (no @font-face, font-family, --font-* or Google Fonts link)")
    if not sp:
        missing.append("a spacing scale")
    if not rd:
        missing.append("a radius token")
    if not mo:
        missing.append("motion tokens (durations, easings)")
    if not ex.components:
        missing.append("a component inventory")
    lines += [f"- {m}" for m in missing] or ["- nothing — every section above has a source"]
    if ex.notes:
        lines += ["", "## Notes", ""] + [f"- {n}" for n in ex.notes]
    lines += ["", "## Sources", ""] + [f"- {s}" for s in sorted(set(ex.sources))]
    return "\n".join(lines) + "\n"


def card(group, name, inner, subtitle=""):
    sub = f"<div class=\"dk-sub\">{html.escape(subtitle)}</div>" if subtitle else ""
    return (f"<article class=\"dk-card\"><!-- @dsCard group=\"{html.escape(group, quote=True)}\" name=\"{html.escape(name, quote=True)}\" -->"
            f"<div class=\"dk-name\">{html.escape(name)}</div>{sub}<div class=\"dk-body\">{inner}</div></article>")


def component_sample(c):
    n = c["name"].lower()
    if "button" in n:
        return "<button class=\"dk-btn\">" + html.escape(c["name"]) + "</button>"
    if "input" in n or "field" in n or "textarea" in n:
        return "<input class=\"dk-input\" placeholder=\"" + html.escape(c["name"]) + "\">"
    if "badge" in n or "tag" in n or "chip" in n:
        return "<span class=\"dk-badge\">" + html.escape(c["name"]) + "</span>"
    if "card" in n or "panel" in n or "dialog" in n or "modal" in n:
        return "<div class=\"dk-box\"><strong>" + html.escape(c["name"]) + "</strong><p>Static stand-in for the real component.</p></div>"
    return "<div class=\"dk-ph\">" + html.escape(c["name"]) + "</div>"


def build_kit(ex, tokens, project, shell_path):
    shell = open(shell_path, encoding="utf-8").read()
    rows = list(flat(tokens))
    css_vars = []
    for path, node in rows:
        if node["$type"] in ("color", "dimension", "fontFamily", "duration", "shadow") and isinstance(node["$value"], str) and not node["$value"].startswith("{"):
            css_vars.append(f"--dk-{path.replace('.', '-')}: {node['$value']};")
    slots = {"project": html.escape(project), "vars": "\n".join(css_vars)}
    sections = collections.OrderedDict((k, []) for k in ("Colors", "Type", "Spacing", "Radius", "Motion", "Elevation", "Components"))
    for path, node in rows:
        top = path.split(".")[0]
        val = node["$value"]
        dk = node["$extensions"]["design-kit"]
        label = path.split(".", 1)[1] if "." in path else path
        if top == "color":
            dark = dk.get("modes", {}).get("dark")
            sw = f"<div class=\"dk-swatch\" style=\"background:{html.escape(str(val))}\"></div>"
            if dark:
                sw += f"<div class=\"dk-swatch dk-dark\" style=\"background:{html.escape(str(dark))}\"></div>"
            sections["Colors"].append(card("Colors", label, sw + f"<code>{html.escape(str(val))}</code>" + (f" <code>dark {html.escape(str(dark))}</code>" if dark else ""), ", ".join(dk["sources"][:1])))
        elif top == "typography":
            sections["Type"].append(card("Type", str(val), f"<p class=\"dk-specimen\" style=\"font-family:'{html.escape(str(val))}',sans-serif\">The quick brown fox jumps over the lazy dog 0123456789</p>", label))
        elif top == "spacing":
            sections["Spacing"].append(card("Spacing", label, f"<div class=\"dk-bar\" style=\"width:{html.escape(str(val))}\"></div><code>{html.escape(str(val))}</code>"))
        elif top == "radius":
            sections["Radius"].append(card("Radius", label, f"<div class=\"dk-box\" style=\"border-radius:{html.escape(str(val))}\"></div><code>{html.escape(str(val))}</code>"))
        elif top == "motion":
            v = html.escape(json.dumps(val) if isinstance(val, list) else str(val))
            sections["Motion"].append(card("Motion", label, f"<div class=\"dk-dot\" style=\"transition-duration:{html.escape(str(val)) if node['$type'] == 'duration' else '600ms'}\"></div><code>{v}</code>"))
        elif top == "elevation":
            sections["Elevation"].append(card("Elevation", label, f"<div class=\"dk-box\" style=\"box-shadow:{html.escape(str(val))}\"></div>"))
    for c in ex.components:
        props = ", ".join(c["props"]) or "no props found"
        var = "; ".join(f"{k}: {', '.join(v)}" for k, v in c["variants"].items())
        sections["Components"].append(card("Components", c["name"], component_sample(c) + f"<div class=\"dk-meta\"><code>{html.escape(c['path'])}</code><br>props: {html.escape(props)}" + (f"<br>variants: {html.escape(var)}" if var else "") + "</div>", "static stand-in — not the component"))
    for key, cards in sections.items():
        slots[key.lower()] = "\n".join(cards) if cards else "<p class=\"dk-empty\">Nothing found in the source.</p>"
    for k, v in slots.items():
        shell = shell.replace(f"<!-- SLOT: {k} -->", v)
    return shell


def guess_source(target):
    if re.match(r"https?://", target):
        return "url"
    if os.path.isdir(target):
        for marker in ("package.json", "composer.json", "src", "resources", "tailwind.config.js", "tailwind.config.ts", "components.json"):
            if os.path.exists(os.path.join(target, marker)):
                return "repo"
        return "brand"
    return "repo"


def main(argv=None):
    ap = argparse.ArgumentParser(description="Extract a design system into design-system/.")
    ap.add_argument("target", help="repo dir, https URL, or brand asset dir")
    ap.add_argument("--source", choices=("repo", "url", "brand"), default=None)
    ap.add_argument("--out", default="design-system")
    ap.add_argument("--kit-shell", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "skills", "system", "assets", "kit-shell.html"))
    ap.add_argument("--project-name", default=None)
    ap.add_argument("--dry-run", action="store_true", help="print the token table; write nothing")
    ap.add_argument("--check", action="store_true", help="compare against <out>/tokens.json: exit 1 and print `check:` lines on drift; writes nothing")
    args = ap.parse_args(argv)
    source = args.source or guess_source(args.target)
    ex = Extraction()
    if source == "repo":
        if not os.path.isdir(args.target):
            print(f"system-extract: {args.target} is not a directory", file=sys.stderr)
            return 2
        extract_repo(args.target, ex)
    elif source == "url":
        extract_url(args.target, ex)
    else:
        if not os.path.isdir(args.target):
            print(f"system-extract: {args.target} is not a directory", file=sys.stderr)
            return 2
        extract_brand(args.target, ex)
    project = args.project_name or (os.path.basename(os.path.abspath(args.target)) if source != "url" else urllib.parse.urlsplit(args.target).netloc)
    tokens = build_tokens(ex)
    if args.check:
        return 1 if check_tokens(tokens, os.path.join(args.out, "tokens.json")) else 0
    if args.dry_run:
        for path, node in flat(tokens):
            dk = node["$extensions"]["design-kit"]
            dark = dk.get("modes", {}).get("dark")
            print(f"{path}\t{node['$type']}\t{node['$value']}" + (f"\tdark={dark}" if dark else "") + f"\t{dk.get('sources', [''])[0]}")
        for c in ex.components:
            print(f"component\t{c['name']}\t{c['path']}\t{','.join(c['props'])}")
        for n in ex.notes:
            print("note\t" + n)
        return 0
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "tokens.json"), "w", encoding="utf-8") as fh:
        json.dump(tokens, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    label = os.path.basename(os.path.abspath(args.target)) if source in ("repo", "brand") else args.target
    with open(os.path.join(args.out, "DESIGN-SYSTEM.md"), "w", encoding="utf-8") as fh:
        fh.write(build_markdown(ex, tokens, project, f"{source} `{label}`"))
    with open(os.path.join(args.out, "kit.html"), "w", encoding="utf-8") as fh:
        fh.write(build_kit(ex, tokens, project, args.kit_shell))
    with open(os.path.join(args.out, "components.json"), "w", encoding="utf-8") as fh:
        json.dump(build_components(ex, f"{source} `{label}`"), fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    n_tokens = sum(1 for _ in flat(tokens))
    print(f"design-system/: {n_tokens} tokens, {len(ex.components)} components, {len(set(ex.sources))} sources → {args.out}/tokens.json, components.json, DESIGN-SYSTEM.md, kit.html")
    for n in ex.notes:
        print("note: " + n)
    return 0


if __name__ == "__main__":
    sys.exit(main())
