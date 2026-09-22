#!/usr/bin/env bash
# Drives system-extract.py over three fixture sources and asserts the output
# shape: DTCG keys/types/modes in tokens.json, the `## Design system` block and
# component rows in DESIGN-SYSTEM.md, one @dsCard marker per kit.html card, URL
# mode against a local static server, brand-dir mode on svg + md, and
# byte-identical output on a second run. It does not open a browser.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
ex="$here/system-extract.py"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"; if [ -n "${srv:-}" ]; then { kill "$srv" && wait "$srv"; } 2>/dev/null || true; fi' EXIT

fail() { echo "FAIL: $*"; exit 1; }

repo="$tmp/repo"
mkdir -p "$repo/src/styles" "$repo/src/components/ui" "$repo/resources/views/components" "$repo/stories"
cat > "$repo/package.json" <<'EOF'
{ "name": "fixture", "dependencies": { "tailwindcss": "^3.4.0" } }
EOF
cat > "$repo/components.json" <<'EOF'
{ "style": "new-york", "tailwind": { "baseColor": "zinc", "cssVariables": true, "css": "src/styles/globals.css" } }
EOF
cat > "$repo/src/styles/globals.css" <<'EOF'
/* fixture */
@import "tailwindcss";
@theme {
  --color-brand: #0f766e;
  --font-display: "Fraunces";
  --radius-lg: 12px;
  --spacing-gutter: 24px;
  --ease-out-soft: cubic-bezier(0.2, 0.8, 0.2, 1);
}
:root {
  --background: #ffffff;
  --foreground: #0a0a0a;
  --primary: 222.2 47.4% 11.2%;
  --radius: 0.5rem;
  --duration-fast: 150ms;
  --font-sans: "Inter", ui-sans-serif, sans-serif;
  --shadow-card: 0 1px 2px rgba(0,0,0,.1);
}
.dark {
  --background: #0a0a0a;
  --foreground: #fafafa;
  --primary: 210 40% 98%;
}
@font-face { font-family: "Fraunces"; src: url(/fonts/fraunces.woff2); }
body { font-family: "Inter", sans-serif; color: #0a0a0a; }
.accent { color: #0f766e; }
EOF
cat > "$repo/tailwind.config.js" <<'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: "hsl(var(--primary))", foreground: "#ffffff" },
        brand: "#0f766e",
      },
      borderRadius: { xl: "1rem" },
      fontFamily: { sans: ["Inter", "sans-serif"] },
    },
  },
};
EOF
cat > "$repo/src/components/ui/button.tsx" <<'EOF'
import { cva } from "class-variance-authority";
const buttonVariants = cva("btn", {
  variants: {
    variant: { default: "a", outline: "b", ghost: "c" },
    size: { sm: "x", lg: "y" },
  },
});
export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "default" | "outline" | "ghost";
  size?: "sm" | "lg";
  asChild?: boolean;
}
export function Button(props: ButtonProps) { return null; }
EOF
cat > "$repo/src/components/StatTile.vue" <<'EOF'
<script setup lang="ts">
defineProps<{ label: string; value: number; trend?: "up" | "down" }>()
</script>
<template><div>{{ label }}</div></template>
EOF
cat > "$repo/resources/views/components/alert.blade.php" <<'EOF'
@props(['type' => 'info', 'dismissible' => false])
<div {{ $attributes }}>{{ $slot }}</div>
EOF
cat > "$repo/stories/Button.stories.tsx" <<'EOF'
export default { title: "Button" };
export const Primary = {};
export const Outline = {};
EOF

out="$tmp/out"
python3 "$ex" "$repo" --out "$out" --project-name fixture >/dev/null || fail "repo run exited non-zero"
[ -f "$out/tokens.json" ] && [ -f "$out/DESIGN-SYSTEM.md" ] && [ -f "$out/kit.html" ] || fail "outputs missing"

python3 - "$out/tokens.json" <<'EOF' || exit 1
import json, sys
t = json.load(open(sys.argv[1]))
def get(path):
    cur = t
    for p in path.split("."):
        cur = cur[p]
    return cur
bg = get("color.background")
assert bg["$type"] == "color" and bg["$value"] == "#ffffff", bg
assert bg["$extensions"]["design-kit"]["modes"]["dark"] == "#0a0a0a", bg
assert any(s.startswith("src/styles/globals.css:") for s in bg["$extensions"]["design-kit"]["sources"]), bg
assert get("color.brand")["$value"] == "#0f766e"
assert get("color.primary")["$extensions"]["design-kit"]["modes"]["dark"] == "210 40% 98%"
assert get("color.primary-foreground")["$value"] == "#ffffff"
assert get("radius.radius")["$type"] == "dimension" and get("radius.radius")["$value"] == "0.5rem"
assert get("radius.lg")["$value"] == "12px"
assert get("radius.xl")["$value"] == "1rem"
assert get("spacing.gutter")["$value"] == "24px"
assert get("motion.duration.fast")["$type"] == "duration" and get("motion.duration.fast")["$value"] == "150ms"
assert get("motion.easing.out-soft")["$value"] == [0.2, 0.8, 0.2, 1]
assert get("elevation.card")["$type"] == "shadow"
fams = t["typography"]["family"]
assert any(v.get("$value") == "Inter" for k, v in fams.items() if not k.startswith("$")), fams
assert any(v.get("$value") == "Fraunces" for k, v in fams.items() if not k.startswith("$")), fams
lits = t["$extensions"]["design-kit"]["literalColors"]
assert lits[0]["value"] in ("#0a0a0a", "#0f766e", "#ffffff"), lits
print("tokens.json OK")
EOF

md="$out/DESIGN-SYSTEM.md"
grep -q '^## Design system$' "$md" || fail "no ## Design system block"
grep -q '^- Colors: .*background #ffffff (dark #0a0a0a)' "$md" || fail "colors line: $(grep '^- Colors' "$md")"
grep -q '^- Typography: .*Inter' "$md" || fail "typography line"
grep -q '^- Radius: .*radius 0.5rem' "$md" || fail "radius line"
grep -q '^| Button | `src/components/ui/button.tsx` | variant, size, asChild | .*variant: default, outline, ghost.*stories: Primary, Outline' "$md" || fail "Button row: $(grep '| Button' "$md")"
grep -q '^| StatTile | `src/components/StatTile.vue` | label, value, trend | trend: up, down' "$md" || fail "StatTile row: $(grep StatTile "$md")"
grep -q '^| Alert | `resources/views/components/alert.blade.php` | type, dismissible |' "$md" || fail "Alert row: $(grep Alert "$md")"
grep -q 'components.json: style=new-york, baseColor=zinc' "$md" || fail "components.json note"
grep -q '^## Not found' "$md" || fail "Not found section"

kit="$out/kit.html"
cards=$(grep -c '<article class="dk-card">' "$kit")
markers=$(grep -o '<!-- @dsCard group="[^"]*" name="[^"]*" -->' "$kit" | wc -l | tr -d ' ')
[ "$cards" -gt 0 ] && [ "$cards" -eq "$markers" ] || fail "cards=$cards markers=$markers"
grep -q '<!-- @dsCard group="Colors" name="background" -->' "$kit" || fail "background card marker"
grep -q '<!-- @dsCard group="Components" name="Button" -->' "$kit" || fail "Button card marker"
grep -q 'variants: variant: default, outline, ghost' "$kit" || fail "Button variants in kit"
grep -q '<title>UI kit — fixture</title>' "$kit" || fail "title slot"
grep -q 'SLOT:' "$kit" && fail "unfilled slot remains"

cj="$out/components.json"
[ -f "$cj" ] || fail "components.json missing"
python3 - "$cj" <<'PY' || fail "components.json shape"
import json, sys
d = json.load(open(sys.argv[1]))
by = {c["name"]: c for c in d["components"]}
b = by["Button"]
assert b["source"] == "src/components/ui/button.tsx" and b["export"] == "named", b
assert [p["name"] for p in b["props"]] == ["variant", "size", "asChild"], b["props"]
assert b["props"][0]["type"] == '"default" | "outline" | "ghost"' and b["props"][0]["required"] is False
assert b["variants"] == {"variant": ["default", "outline", "ghost"], "size": ["sm", "lg"]} and b["stories"] == ["Primary", "Outline"]
assert any("extends React.ButtonHTMLAttributes" in g for g in b["gaps"]), b["gaps"]
st = by["StatTile"]
assert st["export"] == "default" and st["props"][0] == {"name": "label", "type": "string", "default": None, "required": True}, st["props"]
al = by["Alert"]
assert al["props"] == [{"name": "type", "type": "mixed", "default": "info", "required": False}, {"name": "dismissible", "type": "mixed", "default": False, "required": False}], al["props"]
PY

out2="$tmp/out2"
python3 "$ex" "$repo" --out "$out2" --project-name fixture >/dev/null
cmp -s "$out/tokens.json" "$out2/tokens.json" && cmp -s "$out/kit.html" "$out2/kit.html" && cmp -s "$md" "$out2/DESIGN-SYSTEM.md" && cmp -s "$cj" "$out2/components.json" || fail "second run differs"

python3 "$ex" "$repo" --out "$out" --check >/dev/null || fail "--check should exit 0 when nothing moved"
cp "$repo/src/styles/globals.css" "$tmp/globals.bak"
sed -i.bak 's/--background: #ffffff;/--background: #fffff0;/' "$repo/src/styles/globals.css"; rm -f "$repo/src/styles/globals.css.bak"
chk="$(python3 "$ex" "$repo" --out "$out" --check)" && fail "--check should exit 1 on drift"
grep -q '^check: color.background #ffffff → #fffff0 (src/styles/globals.css:11)$' <<<"$chk" || fail "check line: $chk"
[ "$(echo "$chk" | wc -l | tr -d ' ')" = 1 ] || fail "one moved token, one line: $chk"
cmp -s "$out/tokens.json" "$out2/tokens.json" || fail "--check wrote tokens.json"
cp "$tmp/globals.bak" "$repo/src/styles/globals.css"

dry="$(python3 "$ex" "$repo" --dry-run)"
echo "$dry" | grep -q $'^color.background\tcolor\t#ffffff\tdark=#0a0a0a\t' || fail "dry-run row: $(echo "$dry" | head -3)"
[ -d "$tmp/design-system" ] && fail "dry-run wrote files"

site="$tmp/site"; mkdir -p "$site/css"
cat > "$site/index.html" <<'EOF'
<!doctype html><html><head>
<link rel="stylesheet" href="css/site.css">
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500&display=swap" rel="stylesheet">
<style>:root{--accent:#ff4d00}</style>
</head><body style="color:#222222"><h1 style="color:#ff4d00">Hi</h1></body></html>
EOF
cat > "$site/css/site.css" <<'EOF'
:root { --surface: #fafafa; --ink: #111111; --radius-pill: 999px; }
h1 { font-family: "Space Grotesk", sans-serif; color: #ff4d00; }
a { color: #ff4d00; }
EOF
port=$(( 20000 + RANDOM % 10000 ))
( cd "$site" && python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 ) & srv=$!
sleep 0.6
outu="$tmp/outu"
python3 "$ex" "http://127.0.0.1:$port/" --out "$outu" >/dev/null || fail "url run exited non-zero"
python3 - "$outu/tokens.json" <<'EOF' || exit 1
import json, sys
t = json.load(open(sys.argv[1]))
assert t["color"]["accent"]["$value"] == "#ff4d00"
assert t["color"]["surface"]["$value"] == "#fafafa"
assert t["radius"]["pill"]["$value"] == "999px"
fams = {v["$value"] for k, v in t["typography"]["family"].items() if not k.startswith("$")}
assert "Space Grotesk" in fams, fams
lits = t["$extensions"]["design-kit"]["literalColors"]
assert lits[0]["value"] == "#ff4d00", lits
print("url tokens OK")
EOF
grep -q 'without running JavaScript' "$outu/DESIGN-SYSTEM.md" || fail "url mode caveat missing"
{ kill "$srv" && wait "$srv"; } 2>/dev/null || true; srv=""

brand="$tmp/brand"; mkdir -p "$brand"
cat > "$brand/logo.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg"><rect fill="#123456"/><path stroke="#abcdef" style="fill:#123456"/></svg>
EOF
cat > "$brand/BRAND.md" <<'EOF'
# Brand
- Primary blue: #123456
- Sky: #abcdef
Typeface: Manrope for everything
EOF
outb="$tmp/outb"
python3 "$ex" "$brand" --out "$outb" >/dev/null || fail "brand run exited non-zero"
python3 - "$outb/tokens.json" <<'EOF' || exit 1
import json, sys
t = json.load(open(sys.argv[1]))
assert t["color"]["primary-blue"]["$value"] == "#123456", t["color"]
assert t["color"]["sky"]["$value"] == "#abcdef"
fams = {v["$value"] for k, v in t["typography"]["family"].items() if not k.startswith("$")}
assert "Manrope" in fams, fams
lits = {d["value"]: d["uses"] for d in t["$extensions"]["design-kit"]["literalColors"]}
assert lits["#123456"] == 3, lits
print("brand tokens OK")
EOF

empty="$tmp/empty"; mkdir -p "$empty/src"; echo '{}' > "$empty/package.json"
oute="$tmp/oute"
python3 "$ex" "$empty" --out "$oute" >/dev/null || fail "empty repo run exited non-zero"
grep -q '^- colour tokens' "$oute/DESIGN-SYSTEM.md" || fail "empty repo should list colour tokens as not found"
grep -q 'Nothing found in the source' "$oute/kit.html" || fail "empty kit sections"

echo "PASS system-extract.test.sh"
