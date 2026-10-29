#!/usr/bin/env python3
"""scaffold-fill.py — write a scratch page body from the extracted component inventory.

Given the stack, a slug and design-system/components.json, prints the scratch source to stdout: the cleanup marker on line 1, one import per component (relative, or a tsconfig/jsconfig `paths` alias; `~/` on Nuxt), each component's prop signature verbatim as a comment, a `data-design-kit="strip"` section rendering every component in every union-typed variant (children from --brief), and a comment per `gaps` entry naming the file to open first. Stacks: vite-react, next, vite-vue, nuxt, laravel (Blade <x-…> tags), laravel-inertia-react and -vue (a page naming its own bare layout, so createInertiaApp's default stays out).
Misses: it never compiles the imports (the dev server's overlay is the check), never passes a required prop it cannot fake (that line is emitted commented out, naming the prop), and does not resolve barrel re-exports.
Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/scaffold-fill.py
"""
import argparse
import json
import os
import re
import sys

MARK = "__design-kit__ scratch — removed by codebase-cleanup.sh"
STACK_DIR = {"vite-react": "src/__design-kit__", "vite-vue": "src/__design-kit__",
             "next": "app/__design-kit__/{slug}", "nuxt": "pages/__design-kit__", "laravel": "resources/views/__design-kit__",
             "laravel-inertia-react": "resources/js/pages/__design-kit__", "laravel-inertia-vue": "resources/js/pages/__design-kit__"}


def strip_json_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"(^|[^:\\\"'])//[^\n]*", r"\1", text)
    return re.sub(r",(\s*[}\]])", r"\1", text)


def read_paths_alias(root):
    """Return (alias_prefix, dir_prefix) for the first `paths` entry shaped like
    `@/*: ["./src/*"]`, or None."""
    for name in ("tsconfig.json", "jsconfig.json"):
        p = os.path.join(root, name)
        if not os.path.isfile(p):
            continue
        try:
            doc = json.loads(strip_json_comments(open(p, encoding="utf-8").read()))
        except (OSError, ValueError):
            continue
        paths = (doc.get("compilerOptions") or {}).get("paths") or {}
        base = (doc.get("compilerOptions") or {}).get("baseUrl") or "."
        for key, targets in paths.items():
            if not key.endswith("/*") or not targets:
                continue
            target = targets[0]
            if not target.endswith("/*"):
                continue
            d = os.path.normpath(os.path.join(base, target[:-2])).replace(os.sep, "/")
            return key[:-2], d.strip("./") or "."
    return None


def import_path(source, scratch_dir, alias, stack):
    src_noext = re.sub(r"\.(tsx|ts|jsx|js)$", "", source)
    if stack == "nuxt":
        return "~/" + src_noext
    if alias:
        prefix, d = alias
        if source.startswith(d + "/"):
            return prefix + "/" + src_noext[len(d) + 1:]
    rel = os.path.relpath(src_noext, scratch_dir).replace(os.sep, "/")
    return rel if rel.startswith(".") else "./" + rel


def signature_lines(c):
    lines = [f"{c['name']} — {c['source']}"]
    for p in c.get("props", []):
        d = "" if p.get("default") is None else f"  (default {json.dumps(p['default'])})"
        r = "" if p.get("required") else "?"
        lines.append(f"  {p['name']}{r}: {p.get('type') or 'unknown'}{d}")
    if not c.get("props"):
        lines.append("  (no props extracted)")
    if c.get("stories"):
        lines.append("  stories: " + ", ".join(c["stories"]))
    return lines


def has_children(c):
    return any(p["name"] in ("children", "slot", "default") for p in c.get("props", []))


def fill_value(ptype, text, style):
    """A type-shaped value for a required prop, or None when the type is not one
    the strip can fake honestly (an object, a generic, a component)."""
    t = (ptype or "").strip()
    if re.match(r"^(string|String)$", t):
        return f'"{text}"' if style == "jsx" else text
    if t in ("number", "Number"):
        return "{1}" if style == "jsx" else "1"
    if t in ("boolean", "Boolean"):
        return "{true}" if style == "jsx" else "true"
    if re.search(r"\[\]$|^Array<|^readonly ", t):
        return "{[]}" if style == "jsx" else "[]"
    if re.search(r"=>", t):
        return "{() => {}}" if style == "jsx" else "() => {}"
    if style == "blade" and t in ("", "mixed", "string", "?string"):
        return text  # Blade attributes are strings; @props declares no type
    return None  # a union of literals is a variant (rendered per value), an object or a generic is not fakeable


def required_fill(c, filled, text, style):
    """(attrs, unfillable) for the required props not already set — the strip
    renders every component it can without a runtime throw, and comments out the
    ones it cannot fake rather than rendering them bare."""
    attrs, unfillable = [], []
    for p in c.get("props", []):
        if not p.get("required") or p["name"] in filled or p["name"] in ("children", "slot", "default"):
            continue
        v = fill_value(p.get("type"), text, style)
        if v is None:
            unfillable.append(p["name"])
        elif style == "jsx":
            attrs.append(f' {p["name"]}={v}' if v.startswith("{") else f' {p["name"]}={v}')
        elif style == "vue":
            attrs.append(f' {p["name"]}="{v}"' if p.get("type", "").strip() in ("string", "String") else f' :{p["name"]}="{v}"')
        else:
            attrs.append(f' {p["name"]}="{v}"')
    return "".join(attrs), unfillable


def strip_items(c, text, style):
    """One rendering per variant value; a component with no variants renders once.
    Required props get type-shaped values; a component with a required prop the
    strip cannot fake is emitted commented out, naming the prop."""
    variants = c.get("variants") or {}
    combos = [(k, v) for k, vals in variants.items() for v in vals] or [(None, None)]
    out = []
    for k, v in combos:
        attrs = f' {k}="{v}"' if k else ""
        req_attrs, unfillable = required_fill(c, {k} if k else set(), text, style)
        attrs += req_attrs
        if style == "jsx":
            body = f"<{c['name']}{attrs}>{text}</{c['name']}>" if has_children(c) else f"<{c['name']}{attrs} />"
        elif style == "vue":
            body = f"<{c['name']}{attrs}>{text}</{c['name']}>"
        else:  # blade
            tag = blade_tag(c["source"], c["name"])
            body = f"<{tag}{attrs}>{text}</{tag}>"
        if unfillable:
            note = f"fill required {', '.join(unfillable)} before rendering"
            body = {"jsx": f"{{/* {body} — {note} */}}", "vue": f"<!-- {body} — {note} -->", "blade": f"{{{{-- {body} — {note} --}}}}"}[style]
        out.append(body)
    return out


def blade_tag(source, name):
    m = re.match(r"resources/views/components/(.+)\.blade\.php$", source)
    if m:
        return "x-" + m.group(1).replace("/", ".")
    return "x-" + re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower()


def gap_comments(c, style):
    open_c, close_c = {"jsx": ("{/* ", " */}"), "vue": ("<!-- ", " -->"), "blade": ("{{-- ", " --}}"), "js": ("// ", "")}[style]
    return [f"{open_c}gap: open {c['source']} before using {c['name']} — {g}{close_c}" for g in c.get("gaps", [])]


def render(stack, slug, comps, brief, lang, root, css=""):
    text = brief or ""
    alias = read_paths_alias(root)
    scratch_dir = STACK_DIR[stack].format(slug=slug)
    css_import = ""
    if css and stack in ("vite-react", "next", "vite-vue", "nuxt"):
        rel = os.path.relpath(css, scratch_dir).replace(os.sep, "/")
        css_import = f'import "{rel if rel.startswith(".") else "./" + rel}";'  # the app's own stylesheet: the strip renders styled, like the product
    if stack in ("vite-react", "next", "laravel-inertia-react"):
        imports, sigs, items, gaps = [], [], [], []
        for c in comps:
            name = c["name"]
            path = import_path(c["source"], scratch_dir, alias, stack)
            imports.append(f'import {name} from "{path}";' if c.get("export") == "default" else f'import {{ {name} }} from "{path}";')
            sigs.append("/* " + "\n   ".join(signature_lines(c)) + " */")
            items += strip_items(c, text or name, "jsx")
            gaps += gap_comments(c, "jsx")
        body = "\n".join(
            ["      <section data-design-kit=\"strip\">"] + [f"        {i}" for i in items] + ["      </section>"] +
            ([f"      {g}" for g in gaps]) +
            ["      {/* Compose the design below from the components above; real data, never lorem. */}"])
        head = [f"/* {MARK} */"]
        if stack == "vite-react":
            head.append('import { createRoot } from "react-dom/client";')
        if stack == "laravel-inertia-react" and lang == "ts":
            head.append('import type { ReactNode } from "react";')
        if css_import:
            head.append(css_import)
        head += imports + [""] + sigs + [""]
        if stack == "vite-react":
            bang = "!" if lang == "ts" else ""
            return "\n".join(head + [
                "function Scratch() {", "  return (", f'    <main data-design-kit="{slug}">', body, "    </main>", "  );", "}",
                f'createRoot(document.getElementById("design-kit-root"){bang}).render(<Scratch />);', ""])
        page = ["export default function DesignKitScratch() {", "  return (", f'    <main data-design-kit="{slug}">', body, "    </main>", "  );", "}"]
        if stack == "laravel-inertia-react":
            typed = ": { children: ReactNode }" if lang == "ts" else ""
            # `layout = [Bare]` stays an array: Inertia 3 reads a bare function there as a layout callback.
            return "\n".join(head + [f"function Bare({{ children }}{typed}) {{", "  return <>{children}</>;", "}", ""] + page + ["DesignKitScratch.layout = [Bare];", ""])
        return "\n".join(head + page + [""])
    if stack in ("vite-vue", "nuxt", "laravel-inertia-vue"):
        imports, sigs, items, gaps = [], [], [], []
        for c in comps:
            path = import_path(c["source"], scratch_dir, alias, stack)
            if not path.endswith(".vue") and c["source"].endswith(".vue"):
                path += ".vue"
            imports.append(f'import {c["name"]} from "{path}";')
            sigs.append("// " + "\n// ".join(signature_lines(c)))
            items += strip_items(c, text or c["name"], "vue")
            gaps += gap_comments(c, "vue")
        options = ["<script>", "const Bare = { setup: (_, { slots }) => () => slots.default?.() };", "export default { layout: Bare };", "</script>"] \
            if stack == "laravel-inertia-vue" else []
        return "\n".join([f"<!-- {MARK} -->"] + options + ["<script setup>"] + ([css_import] if css_import else []) + imports + sigs + ["</script>", "<template>", f'  <main data-design-kit="{slug}">',
                          '    <section data-design-kit="strip">'] + [f"      {i}" for i in items] + ["    </section>"] + [f"    {g}" for g in gaps] +
                         ["    <!-- Compose the design below from the components above; real data, never lorem. -->", "  </main>", "</template>", ""])
    if stack == "laravel":
        sigs, items, gaps = [], [], []
        for c in comps:
            sigs.append("{{-- " + "\n     ".join(signature_lines(c)) + " --}}")
            items += strip_items(c, text or c["name"], "blade")
            gaps += gap_comments(c, "blade")
        open_l, close_l, note = laravel_wrapper(root)
        return "\n".join([f"{{{{-- {MARK} --}}}}", f"{{{{-- {note} --}}}}"] + sigs + open_l + [f'    <main data-design-kit="{slug}">', '        <section data-design-kit="strip">'] +
                         [f"            {i}" for i in items] + ["        </section>"] + [f"        {g}" for g in gaps] +
                         ["        {{-- Compose the design below from the components above; real data, never lorem. --}}", "    </main>"] + close_l + [""])
    raise SystemExit(f"scaffold-fill: no template for stack {stack}")


def laravel_wrapper(root):
    """(open lines, close lines, note): `<x-app-layout>` only when the project defines
    it (Breeze/Jetstream: app/View/Components/AppLayout.php or an anonymous
    components/app-layout.blade.php); otherwise a standalone page carrying the first
    `@vite([...])` directive found in the project's layouts, so the real stylesheet
    loads; otherwise a bare page."""
    if os.path.isfile(os.path.join(root, "app", "View", "Components", "AppLayout.php")) or \
       os.path.isfile(os.path.join(root, "resources", "views", "components", "app-layout.blade.php")):
        return ["<x-app-layout>"], ["</x-app-layout>"], "wrapped in the project's <x-app-layout>"
    vite = None
    for d in ("resources/views/layouts", "resources/views"):
        base = os.path.join(root, d)
        if not os.path.isdir(base):
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            dirnames[:] = sorted(x for x in dirnames if x != "__design-kit__")
            for fn in sorted(filenames):
                if not fn.endswith(".blade.php"):
                    continue
                try:
                    t = open(os.path.join(dirpath, fn), encoding="utf-8", errors="replace").read()
                except OSError:
                    continue
                m = re.search(r"@vite\((.|\n)*?\)", t)
                if m:
                    vite = m.group(0)
                    break
            if vite:
                break
        if vite:
            break
    head = ['<!doctype html>', '<html lang="en">', '<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">']
    if vite:
        return head + [f"    {vite}", "</head>", "<body>"], ["</body>", "</html>"], "standalone page; @vite copied from the project's layout (the project defines no app-layout component)"
    return head + ["</head>", "<body>"], ["</body>", "</html>"], "standalone page; no layout with @vite found — add the project's stylesheet by hand"


def main(argv=None):
    ap = argparse.ArgumentParser(description="scratch page body from design-system/components.json")
    ap.add_argument("stack", choices=sorted(STACK_DIR))
    ap.add_argument("slug")
    ap.add_argument("--components", default=os.path.join("design-system", "components.json"))
    ap.add_argument("--brief", default="")
    ap.add_argument("--lang", choices=("ts", "js"), default="ts")
    ap.add_argument("--root", default=".")
    ap.add_argument("--css", default="", help="the app's main stylesheet (repo-relative); imported first so the strip is styled")
    a = ap.parse_args(argv)
    if a.components in ("", "/dev/null") or not os.path.exists(a.components):
        doc = {}  # no inventory: the wrapper and the marker still come from here
    else:
        try:
            doc = json.load(open(a.components, encoding="utf-8"))
        except (OSError, ValueError) as exc:
            print(f"scaffold-fill: cannot read {a.components}: {exc}", file=sys.stderr)
            return 2
    comps = [c for c in doc.get("components", []) if c.get("name") and c.get("source")]
    lara = a.stack == "laravel"
    comps = [c for c in comps if (c["source"].endswith((".blade.php", ".php")) if lara else not c["source"].endswith((".blade.php", ".php")))]
    if a.stack in ("vite-vue", "nuxt", "laravel-inertia-vue"):
        comps = [c for c in comps if c["source"].endswith(".vue")] or comps
    sys.stdout.write(render(a.stack, a.slug, comps, a.brief, a.lang, a.root, a.css))
    return 0


if __name__ == "__main__":
    sys.exit(main())
