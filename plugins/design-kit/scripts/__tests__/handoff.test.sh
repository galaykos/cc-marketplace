#!/usr/bin/env bash
# Drives handoff-drift.py on a fixture bundle against a fixture repo: a colour that
# matches a CSS token, one that is near, one with no token, a font that matches
# and one that does not; oklch and tailwind.config and tokens.json sources; an
# empty repo yields all no-token rows; exit is 0 throughout.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
drift="$here/handoff-drift.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

bundle="$tmp/bundle"; mkdir -p "$bundle"
echo "# Handoff from Claude Design" > "$bundle/README.md"
cat > "$bundle/screen.html" <<'EOF'
<html><head><style>
body { background:#f8fafc; color:#1a4d8f; font-family: Inter, sans-serif }
.cta { background:#1a4d92; color:#ff00aa; font-family:"Space Grotesk", sans-serif }
.hero { color: rgb(26, 77, 143); border-color: oklch(70% 0.1 250) }
</style></head><body><h1 style="color:#1a4d8f">x</h1></body></html>
EOF

repo="$tmp/repo"; mkdir -p "$repo/src/styles" "$repo/design-system"
cat > "$repo/src/styles/globals.css" <<'EOF'
@theme { --color-brand: #1a4d8f; }
:root { --surface: #f8fafc; --font-sans: Inter, ui-sans-serif, system-ui; }
EOF
echo "module.exports = { theme: { extend: { colors: { accent: '#0ea5e9' } } } }" > "$repo/tailwind.config.js"
cat > "$repo/design-system/tokens.json" <<'EOF'
{ "color": { "sky": { "$type": "color", "$value": "oklch(70% 0.1 250)" } },
  "font": { "mono": { "$type": "fontFamily", "$value": ["JetBrains Mono", "monospace"] } } }
EOF

out="$(python3 "$drift" "$bundle" --repo "$repo")"
grep -q '^| colour | #1a4d8f | 3 | --color-brand | #1a4d8f | match |$' <<<"$out" || fail "hex match row (hex + rgb() + inline count as one value):
$out"
grep -q '^| colour | #1a4d92 | 1 | --color-brand | #1a4d8f | near (Δ3) |$' <<<"$out" || fail "near row:
$out"
grep -q '^| colour | #ff00aa | 1 | .* | no token |$' <<<"$out" || fail "no-token colour row:
$out"
grep -q '^| colour | #f8fafc | 1 | --surface | #f8fafc | match |$' <<<"$out" || fail "surface match row:
$out"
grep -q '^| colour | oklch(70% 0.1 250) | 1 | color.sky | .* | match |$' <<<"$out" || fail "oklch tokens.json match row:
$out"
grep -q '^| font | Inter | 1 | --font-sans | Inter | match |$' <<<"$out" || fail "font match row:
$out"
grep -q '^| font | Space Grotesk | 1 | - | - | no token |$' <<<"$out" || fail "font no-token row:
$out"
grep -q '^summary: match=4 near=1 no-token=2$' <<<"$out" || fail "summary line:
$out"

empty="$tmp/empty"; mkdir -p "$empty"
out2="$(python3 "$drift" "$bundle" --repo "$empty")"
grep -q 'no-token=7' <<<"$out2" || fail "empty repo should yield all no-token rows:
$out2"
python3 "$drift" "$tmp/nope" --repo "$repo" >/dev/null 2>&1 || fail "missing bundle must still exit 0"
echo "PASS handoff.test.sh"
