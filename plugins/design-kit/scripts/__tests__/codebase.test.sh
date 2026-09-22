#!/usr/bin/env bash
# Drives codebase-scaffold.sh and codebase-cleanup.sh on a Vite React fixture and a
# Laravel fixture: --detect names the stack, --create writes marked files,
# --verify fails while they exist and passes after cleanup, routes/web.php keeps
# its own lines.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
scaffold="$here/codebase-scaffold.sh"; cleanup="$here/codebase-cleanup.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

# --- Vite React (TypeScript) ---
vite="$tmp/vite"; mkdir -p "$vite/src/components"
cat > "$vite/package.json" <<'EOF'
{ "name": "fx", "scripts": { "dev": "vite" }, "dependencies": { "react": "^18.3.0", "react-dom": "^18.3.0" } }
EOF
echo 'export default { server: { port: 5180 } }' > "$vite/vite.config.ts"
echo '{}' > "$vite/tsconfig.json"
echo 'export function Button() {}' > "$vite/src/components/Button.tsx"
cd "$vite"
det="$(bash "$scaffold" --detect)"
grep -q '^stack=vite-react$' <<<"$det" || fail "vite detect: $det"
grep -q '^dev_url=http://localhost:5180$' <<<"$det" || fail "vite port from config: $det"
grep -q '^components=src/components$' <<<"$det" || fail "vite components: $det"
grep -q '^lang=ts$' <<<"$det" || fail "vite lang: $det"
out="$(bash "$scaffold" --create hero)"
[ -f "__design-kit__/hero.html" ] || fail "vite html scratch missing"
[ -f "src/__design-kit__/hero.tsx" ] || fail "vite tsx scratch missing"
head -1 "__design-kit__/hero.html" | grep -q '__design-kit__ scratch' || fail "html marker line 1"
head -1 "src/__design-kit__/hero.tsx" | grep -q '__design-kit__ scratch' || fail "tsx marker line 1"
grep -q '^open=http://localhost:5180/__design-kit__/hero.html$' <<<"$out" || fail "vite open url: $out"
bash "$scaffold" --create 'Bad Slug' >/dev/null 2>&1 && fail "slug validation"
bash "$cleanup" --verify >/dev/null 2>&1 && fail "verify should fail while scratch exists"
bash "$cleanup" >/dev/null
bash "$cleanup" --verify >/dev/null || fail "verify should pass after cleanup"
[ -e "__design-kit__" ] && fail "scratch dir survived cleanup"
[ -f "src/components/Button.tsx" ] || fail "cleanup touched a real file"
grep -q 'Fill me with real components' "$(bash "$scaffold" --create plain | sed -n 's/^wrote=\(.*tsx\)$/\1/p')" || fail "plain template without components.json"
bash "$cleanup" >/dev/null

# --- Vite React with the extracted inventory (components.json) ---
mkdir -p design-system
cat > design-system/components.json <<'EOF'
{"generated":"2026-09-22","source":"repo `fx`","components":[
 {"name":"Button","source":"src/components/Button.tsx","export":"named",
  "props":[{"name":"variant","type":"'a' | 'b'","default":"a","required":false},{"name":"children","type":"ReactNode","default":null,"required":true}],
  "variants":{"variant":["a","b"]},"stories":["Primary"],"gaps":[]},
 {"name":"Modal","source":"src/components/Modal.tsx","export":"default",
  "props":[{"name":"open","type":"boolean","default":null,"required":true}],
  "variants":{},"stories":[],"gaps":["generic interface ModalProps<T> — the type parameter's members are not listed"]},
 {"name":"Chart","source":"src/components/Chart.tsx","export":"named",
  "props":[{"name":"series","type":"Series","default":null,"required":true},{"name":"height","type":"number","default":null,"required":true}],
  "variants":{},"stories":[],"gaps":[]}
]}
EOF
printf 'import "./index.css";\nimport { x } from "./x";\n' > src/main.tsx; echo 'body{}' > src/index.css
out="$(bash "$scaffold" --create filled --brief 'Acme')"
grep -q '^filled=design-system/components.json$' <<<"$out" || fail "filled= line: $out"
f=src/__design-kit__/filled.tsx
head -1 "$f" | grep -q '__design-kit__ scratch' || fail "filled marker line 1"
grep -q '^import "../index.css";$' "$f" || fail "app stylesheet import: $(grep import "$f")"
grep -q '^import { Button } from "../components/Button";$' "$f" || fail "named relative import: $(grep import "$f")"
grep -q '^import Modal from "../components/Modal";$' "$f" || fail "default relative import"
grep -q "variant?: 'a' | 'b'  (default \"a\")" "$f" || fail "prop signature comment"
[ "$(grep -c '<Button variant=' "$f")" -eq 2 ] || fail "strip count: $(grep -c '<Button variant=' "$f")"
grep -q '<Button variant="a">Acme</Button>' "$f" || fail "brief as children"
grep -q '<Modal open={true} />' "$f" || fail "required boolean filled: $(grep Modal "$f" | head -2)"
grep -q '<Button variant="a">Acme</Button>' "$f" || fail "required children filled from brief"
grep -q 'gap: open src/components/Modal.tsx before using Modal — generic interface' "$f" || fail "gap comment"
grep -q '{/\* <Chart height={1} /> — fill required series before rendering \*/}' "$f" || fail "unfillable required prop is commented out: $(grep Chart "$f" | tail -1)"
grep -q 'stories: Primary' "$f" || fail "stories line"
grep -q 'createRoot(document.getElementById("design-kit-root")!)' "$f" || fail "ts bang kept"
bash "$cleanup" >/dev/null
# alias from tsconfig paths (with a comment and trailing commas)
cat > tsconfig.json <<'EOF'
{ // fixture
  "compilerOptions": { "baseUrl": ".", "paths": { "@/*": ["./src/*"], }, },
}
EOF
bash "$scaffold" --create aliased >/dev/null
grep -q '^import { Button } from "@/components/Button";$' src/__design-kit__/aliased.tsx || fail "alias import: $(grep import src/__design-kit__/aliased.tsx)"
bash "$cleanup" >/dev/null; echo '{}' > tsconfig.json; rm -rf design-system

# --- Laravel ---
lar="$tmp/laravel"; mkdir -p "$lar/resources/views/layouts" "$lar/routes"
touch "$lar/artisan"
echo '<html>@vite(["resources/css/app.css"])</html>' > "$lar/resources/views/layouts/app.blade.php"
printf '<?php\nRoute::get("/", fn () => view("welcome"));\n' > "$lar/routes/web.php"
cd "$lar"
det="$(bash "$scaffold" --detect)"
grep -q '^stack=laravel$' <<<"$det" || fail "laravel detect: $det"
grep -q '^dev_url=http://127.0.0.1:8000$' <<<"$det" || fail "laravel url: $det"
out="$(bash "$scaffold" --create pricing)"
[ -f "resources/views/__design-kit__/pricing.blade.php" ] || fail "blade scratch missing"
head -1 "resources/views/__design-kit__/pricing.blade.php" | grep -q '__design-kit__ scratch' || fail "blade marker"
grep -q '@vite(\["resources/css/app.css"\])' "resources/views/__design-kit__/pricing.blade.php" || fail "blade standalone page should carry the layout's @vite"
grep -q '<x-app-layout>' "resources/views/__design-kit__/pricing.blade.php" && fail "no <x-app-layout> is defined in this fixture; it must not be assumed"
mkdir -p app/View/Components && printf '<?php\nnamespace App\\View\\Components;\nclass AppLayout {}\n' > app/View/Components/AppLayout.php
bash "$scaffold" --create pricing2 >/dev/null || fail "laravel create 2"
grep -q '<x-app-layout>' "resources/views/__design-kit__/pricing2.blade.php" || fail "with AppLayout.php the scratch should wrap in <x-app-layout>"
rm -rf app/View/Components/AppLayout.php
grep -q "Route::view('/__design-kit__/pricing'" routes/web.php || fail "route line not appended"
grep -q '^open=http://127.0.0.1:8000/__design-kit__/pricing$' <<<"$out" || fail "laravel open url: $out"
bash "$cleanup" --verify >/dev/null 2>&1 && fail "laravel verify should fail"
bash "$cleanup" >/dev/null
bash "$cleanup" --verify >/dev/null || fail "laravel verify should pass after cleanup"
grep -q '__design-kit__' routes/web.php && fail "route line survived"
grep -q 'Route::get("/"' routes/web.php || fail "cleanup removed a real route"

# --- unknown stack ---
mkdir -p "$tmp/empty"; cd "$tmp/empty"
grep -q '^stack=unknown$' <<<"$(bash "$scaffold" --detect)" || fail "empty dir should be unknown"
bash "$scaffold" --create x >/dev/null 2>&1 && fail "create on unknown stack should exit non-zero"
echo "PASS codebase.test.sh"
