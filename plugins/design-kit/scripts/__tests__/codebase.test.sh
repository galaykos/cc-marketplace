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
printf 'import "./index.css";\nimport { x } from "./x";\n' > src/main.tsx; echo '@tailwind base;' > src/index.css
out="$(bash "$scaffold" --create filled --brief 'Acme')"
[ "$(cat src/index.css)" = '@tailwind base;' ] || fail "a Tailwind v3 stylesheet got an @source line: $(cat src/index.css)"
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
# a routes file with no final newline: the appended route used to join its last line, and
# cleanup then deleted that real route with it
printf '<?php\nRoute::get("/", fn () => view("welcome"));' > routes/web.php; cp routes/web.php "$tmp/lar.web"
mkdir -p resources/css; printf "@import 'tailwindcss';\n@source '../views';\n" > resources/css/app.css; cp resources/css/app.css "$tmp/lar.css"
out="$(bash "$scaffold" --create pricing)"
grep -qx 'Route::get("/", fn () => view("welcome"));' routes/web.php || fail "the appended route joined the last real line: $(cat routes/web.php)"
grep -qx '@source "../views/__design-kit__"; /\* __design-kit__ scratch — removed by codebase-cleanup.sh \*/' resources/css/app.css || fail "blade: no marked @source line: $(cat resources/css/app.css)"
grep -q '^appended=resources/css/app.css$' <<<"$out" || fail "blade: appended= css line: $out"
bash "$cleanup" >/dev/null
cmp -s routes/web.php "$tmp/lar.web" || fail "cleanup left routes/web.php changed: $(od -c routes/web.php | tail -3)"
cmp -s resources/css/app.css "$tmp/lar.css" || fail "cleanup left the blade stylesheet changed"

# --- Laravel + Inertia (stock starter-kit shape, synthetic): React page, Route::inertia, APP_URL ---
ine="$tmp/inertia"; mkdir -p "$ine/resources/views" "$ine/resources/js/pages" "$ine/resources/js/components/ui" "$ine/resources/css" "$ine/routes"
touch "$ine/artisan"; echo '{}' > "$ine/tsconfig.json"
echo '{ "require": { "php": "^8.3", "inertiajs/inertia-laravel": "^3.0", "laravel/framework": "^13.0" } }' > "$ine/composer.json"
echo '{ "dependencies": { "@inertiajs/react": "^3.0.0", "react": "^19.0.0", "tailwindcss": "^4.0.0" } }' > "$ine/package.json"
echo '<html><head>@vite(["resources/css/app.css", "resources/js/app.tsx"])</head><body><x-inertia::app /></body></html>' > "$ine/resources/views/app.blade.php"
printf "@import 'tailwindcss';\n\n@source '../views';\n\n@theme {\n    --color-primary: var(--primary);\n}" > "$ine/resources/css/app.css"
printf "<?php\n\nuse Illuminate\\\\Support\\\\Facades\\\\Route;\n\nRoute::inertia('/', 'welcome')->name('home');\n" > "$ine/routes/web.php"
printf 'APP_NAME=Fixture\nAPP_KEY=fixture-key-EXAMPLE\nAPP_URL="https://fx-shop.test/"\nDB_PASSWORD=not-for-output-EXAMPLE\n' > "$ine/.env"
cd "$ine"; cp resources/css/app.css "$tmp/ine.css"; cp routes/web.php "$tmp/ine.web"
det="$(bash "$scaffold" --detect)"
grep -q '^stack=laravel-inertia-react$' <<<"$det" || fail "inertia react detect: $det"
grep -q '^dev_url=https://fx-shop.test$' <<<"$det" || fail "dev_url from .env APP_URL: $det"
out="$(bash "$scaffold" --create hero 2>&1)"
grep -q 'EXAMPLE' <<<"$det$out" && fail ".env values other than APP_URL were printed"
p=resources/js/pages/__design-kit__/hero.tsx
[ -f "$p" ] || fail "inertia page missing: $out"
[ -e resources/views/__design-kit__ ] && fail "an Inertia app got a Blade scratch view"
head -1 "$p" | grep -q '__design-kit__ scratch' || fail "inertia page marker line 1"
grep -q '^export default function DesignKitScratch()' "$p" || fail "inertia page default export"
grep -qx 'DesignKitScratch.layout = \[Bare\];' "$p" || fail "the page must name its own layout to opt out of the app's default: $(cat "$p")"
grep -q 'function Bare({ children }: { children: ReactNode })' "$p" || fail "typed bare layout"
grep -qx "Route::inertia('/__design-kit__/hero', '__design-kit__/hero'); // __design-kit__ scratch — removed by codebase-cleanup.sh" routes/web.php || fail "Route::inertia line: $(tail -1 routes/web.php)"
grep -q 'Route::view' routes/web.php && fail "an Inertia app got a Route::view"
grep -qx '@source "../js/pages/__design-kit__"; /\* __design-kit__ scratch — removed by codebase-cleanup.sh \*/' resources/css/app.css || fail "marked @source line: $(tail -2 resources/css/app.css)"
grep -q '^open=https://fx-shop.test/__design-kit__/hero$' <<<"$out" || fail "inertia open url: $out"
bash "$scaffold" --create hero-b >/dev/null
[ "$(grep -c '@source "../js/pages/__design-kit__"' resources/css/app.css)" = 1 ] || fail "a second scratch page repeated the @source line"
bash "$cleanup" --verify >/dev/null 2>&1 && fail "verify should fail while the @source line remains"
vout="$(bash "$cleanup" --verify 2>/dev/null || true)"
grep -q '^leftover=resources/css/app.css (1 marked line(s))$' <<<"$vout" || fail "verify names the stylesheet: $vout"
bash "$cleanup" >/dev/null
cmp -s resources/css/app.css "$tmp/ine.css" || fail "cleanup did not restore the stylesheet byte-for-byte: $(od -c resources/css/app.css | tail -3)"
cmp -s routes/web.php "$tmp/ine.web" || fail "cleanup did not restore routes/web.php byte-for-byte"
bash "$cleanup" --verify >/dev/null || fail "inertia verify after cleanup"
# with the inventory: alias imports from tsconfig paths, the layout line kept
printf '{ "compilerOptions": { "paths": { "@/*": ["./resources/js/*"] } } }\n' > tsconfig.json; mkdir -p design-system
echo '{"components":[{"name":"Button","source":"resources/js/components/ui/button.tsx","export":"named","props":[],"variants":{},"stories":[],"gaps":[]}]}' > design-system/components.json
out="$(bash "$scaffold" --create filled)"
grep -q '^filled=design-system/components.json$' <<<"$out" || fail "inertia filled=: $out"
grep -q '^import { Button } from "@/components/ui/button";$' resources/js/pages/__design-kit__/filled.tsx || fail "inertia alias import"
grep -qx 'DesignKitScratch.layout = \[Bare\];' resources/js/pages/__design-kit__/filled.tsx || fail "filled inertia page lost its layout line"
bash "$cleanup" >/dev/null
# composer has the Laravel adapter but no React/Vue adapter is installed: still Blade
echo '{ "dependencies": { "tailwindcss": "^4.0.0" } }' > package.json
grep -q '^stack=laravel$' <<<"$(bash "$scaffold" --detect)" || fail "inertia-laravel without a client adapter should stay laravel"

# --- Laravel + Inertia Vue: an SFC whose options block names the layout; no .env → artisan serve ---
inv="$tmp/inertia-vue"; mkdir -p "$inv/resources/views" "$inv/resources/js/pages" "$inv/resources/css" "$inv/routes"
touch "$inv/artisan"
echo '{ "require": { "inertiajs/inertia-laravel": "^3.0" } }' > "$inv/composer.json"
echo '{ "dependencies": { "@inertiajs/vue3": "^3.0.0", "vue": "^3.5.0" } }' > "$inv/package.json"
echo '<html><head>@vite(["resources/js/app.ts"])</head></html>' > "$inv/resources/views/app.blade.php"
printf '@import "tailwindcss" source("../");\n' > "$inv/resources/css/app.css"
cd "$inv"; cp resources/css/app.css "$tmp/inv.css"
det="$(bash "$scaffold" --detect)"
grep -q '^stack=laravel-inertia-vue$' <<<"$det" || fail "inertia vue detect: $det"
grep -q '^dev_url=http://127.0.0.1:8000$' <<<"$det" || fail "no .env keeps the artisan-serve url: $det"
bash "$scaffold" --create hero >/dev/null
v=resources/js/pages/__design-kit__/hero.vue
[ -f "$v" ] && head -1 "$v" | grep -q '__design-kit__ scratch' || fail "inertia vue page"
grep -q '^export default { layout: Bare };$' "$v" && grep -q '^<script setup>$' "$v" || fail "vue page must name its own layout: $(cat "$v")"
grep -q "Route::inertia('/__design-kit__/hero', '__design-kit__/hero');" routes/web.php || fail "vue Route::inertia"
grep -q '@source "../js/pages/__design-kit__";' resources/css/app.css || fail "vue: marked @source line"
bash "$cleanup" >/dev/null
cmp -s resources/css/app.css "$tmp/inv.css" || fail "vue stylesheet not restored"

# --- unknown stack ---
mkdir -p "$tmp/empty"; cd "$tmp/empty"
grep -q '^stack=unknown$' <<<"$(bash "$scaffold" --detect)" || fail "empty dir should be unknown"
bash "$scaffold" --create x >/dev/null 2>&1 && fail "create on unknown stack should exit non-zero"
echo "PASS codebase.test.sh"
