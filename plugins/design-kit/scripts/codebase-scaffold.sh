#!/usr/bin/env bash
# codebase-scaffold.sh — detect the project's UI stack and stand up a scratch entry
# that renders a design with the project's OWN components on its OWN dev server.
#
# WHAT IT DOES.
#   --detect          prints key=value lines: stack, dev_cmd, dev_url, components,
#                     lang. Every value is read from files on disk; nothing is
#                     recalled. `stack=unknown` when no signal matches.
#   --create <slug>   writes the scratch files for the detected stack, each marked
#                     on line 1 with `__design-kit__ scratch — removed by
#                     codebase-cleanup.sh` in that file type's comment syntax, and
#                     prints `wrote=<path>` per file plus `open=<url>`.
#                     Laravel also appends ONE marked Route::view line to
#                     routes/web.php; Laravel + Inertia (composer inertia-laravel plus
#                     @inertiajs/react or @inertiajs/vue3) gets a page under
#                     resources/js/pages/__design-kit__/ that names its own layout, so
#                     the app's default one (createInertiaApp `layout`) stays out, and a
#                     Route::inertia line. dev_url for Laravel is .env's APP_URL — the only
#                     key read from .env, and no other value is printed — else
#                     http://127.0.0.1:8000. A value with characters outside a URL's
#                     (quote, `;`, `#`, `$`, space) is refused, and no value reaches a shell.
#                     When the app's entry stylesheet imports Tailwind v4, one marked
#                     `@source` line naming the scratch dir is appended to it: dk.sh
#                     gitignores __design-kit__/, and v4's automatic detection skips
#                     gitignored paths, so the page rendered half-styled in a real session.
#                     Every appended line keeps the file's own final-newline state, so
#                     cleanup restores it byte for byte.
#
#                     When design-system/components.json exists (system-extract.py
#                     wrote it), the component-bearing scratch file is filled by
#                     scaffold-fill.py: real imports, prop signatures, a variant
#                     strip and a gap comment per extractor blind spot. Without it
#                     the plain template is written. --brief "<text>" seeds the
#                     strip's children text; --components <path> overrides the file.
# Misses: a two-stack project resolves to Laravel (artisan outranks vite.config.*; --stack overrides) and Inertia + Svelte stays laravel; an APP_URL the app is not served on prints as is; a Tailwind v4 entry stylesheet it cannot find gets no @source line. It never starts the dev server or composes the design; the strip proves only that the imports resolve.
# Why, limits, history: rationale/derivations/plugin-design-kit.md § plugins/design-kit/scripts/codebase-scaffold.sh
set -euo pipefail

MARK="__design-kit__ scratch — removed by codebase-cleanup.sh"
HERE="$(cd "$(dirname "$0")" && pwd)"
mode=""; slug=""; force_stack=""; brief=""; components="design-system/components.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --detect) mode=detect ;;
    --create) mode=create; slug="${2:-}"; shift ;;
    --brief) brief="${2:-}"; shift ;;
    --components) components="${2:-}"; shift ;;
    --stack) case "${2:-}" in vite-react|vite-vue|next|nuxt|laravel|laravel-inertia-react|laravel-inertia-vue) force_stack="$2" ;; *) echo "codebase-scaffold.sh: --stack must be vite-react|vite-vue|next|nuxt|laravel|laravel-inertia-react|laravel-inertia-vue" >&2; exit 2 ;; esac; shift ;;
    -h|--help) sed -n '2,34p' "$0"; exit 0 ;;
    *) echo "codebase-scaffold.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$mode" ] || { echo "codebase-scaffold.sh: --detect or --create <slug> required" >&2; exit 2; }

has_dep() { [ -f package.json ] && grep -Eq "\"$1\"[[:space:]]*:" package.json; }
first_dir() { for d in "$@"; do [ -d "$d" ] && { echo "$d"; return; }; done; echo "-"; }
app_url() {  # .env's APP_URL alone, unquoted, no trailing slash; empty when unset, interpolated or not a plain URL
  [ -f .env ] || return 0
  sed -n -E 's/^[[:space:]]*APP_URL[[:space:]]*=[[:space:]]*//p' .env | head -1 \
    | sed -E "s/[[:space:]]+#.*\$//; s/^[\"']//; s/[\"'][[:space:]]*\$//; s#/+\$##" | grep -E '^https?://[][A-Za-z0-9._~:/?&=%@+,!-]+$' || true
}

detect() {
  stack=unknown; dev_cmd="-"; dev_url="-"; lang=js
  [ -f tsconfig.json ] && lang=ts
  if [ -n "$force_stack" ]; then stack="$force_stack"
  elif [ -f artisan ] && grep -rlq --include='*.blade.php' '@vite' resources/views 2>/dev/null; then stack=laravel
    if [ -f composer.json ] && grep -Eq '"inertiajs/inertia-laravel"[[:space:]]*:' composer.json; then
      if has_dep @inertiajs/react; then stack=laravel-inertia-react; elif has_dep @inertiajs/vue3; then stack=laravel-inertia-vue; fi
    fi
  elif ls next.config.* >/dev/null 2>&1 && [ -d app ]; then stack=next
  elif ls nuxt.config.* >/dev/null 2>&1; then stack=nuxt
  elif ls vite.config.* >/dev/null 2>&1; then
    if has_dep vue; then stack=vite-vue; elif has_dep react; then stack=vite-react; else stack=vite; fi
  fi
  case "$stack" in
    laravel*) dev_cmd="php artisan serve & npm run dev"; dev_url="$(app_url)"; dev_url="${dev_url:-http://127.0.0.1:8000}" ;;
    next|nuxt) dev_cmd="npm run dev"; dev_url="http://localhost:3000" ;;
    vite*) dev_cmd="npm run dev"
      port=$(grep -hoE 'port[[:space:]]*:[[:space:]]*[0-9]+' vite.config.* 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
      dev_url="http://localhost:${port:-5173}" ;;
  esac
  components=$(first_dir src/components components resources/js/Components resources/js/components app/components resources/views/components)
  printf 'stack=%s\ndev_cmd=%s\ndev_url=%s\ncomponents=%s\nlang=%s\n' "$stack" "$dev_cmd" "$dev_url" "$components" "$lang"
}

if [ "$mode" = detect ]; then detect; exit 0; fi

[ -n "$slug" ] || { echo "codebase-scaffold.sh: --create needs a slug" >&2; exit 2; }
case "$slug" in *[!a-z0-9-]*) echo "codebase-scaffold.sh: slug must be [a-z0-9-]" >&2; exit 2 ;; esac
# a cloned repo's .env is untrusted: detect's values are assigned, never re-parsed by a shell
while IFS= read -r kv; do
  case "${kv%%=*}" in stack|dev_cmd|dev_url|components|lang) printf -v "d_${kv%%=*}" '%s' "${kv#*=}" ;; esac
done < <(detect)

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "wrote=$1"; }
# mark_line <file> <line>: append once, after a newline only when the file ends without one, so cleanup never deletes a joined last line
mark_line() {
  python3 - "$1" "$2" <<'PY'
import sys
p, line = sys.argv[1], sys.argv[2].encode()
b = open(p, "rb").read()
if line not in b.splitlines():
    open(p, "wb").write(b + (line + b"\n" if not b or b.endswith(b"\n") else b"\n" + line))
PY
}
tw_source() {  # tw_source <scratch dir>: the marked @source line in a Tailwind v4 entry stylesheet
  local css
  case "$d_stack" in laravel*) css=resources/css/app.css ;; *) css="$(app_css)" ;; esac
  [ -n "$css" ] && [ -f "$css" ] && grep -Eq "@import[[:space:]]+[\"']tailwindcss(/utilities\.css)?[\"']" "$css" || return 0
  mark_line "$css" "@source \"$(python3 -c 'import os,sys;r=os.path.relpath(sys.argv[1],os.path.dirname(sys.argv[2]));print(r if r.startswith(".") else "./"+r)' "$1" "$css")\"; /* $MARK */"
  echo "appended=$css"
}
# fill <path>: the inventory-driven body when components.json exists, else the heredoc on stdin
app_css() {  # the first stylesheet the app's own entry imports — repo-relative, or empty
  local entry imp
  for entry in src/main.tsx src/main.ts src/main.jsx src/main.js src/index.tsx src/index.jsx app/layout.tsx app/layout.jsx app/globals.css; do
    [ -f "$entry" ] || continue
    case "$entry" in *.css) echo "$entry"; return ;; esac
    imp=$(grep -oE "import ['\"][^'\"]+\.(css|scss|sass|less)['\"]" "$entry" | head -1 | sed -E "s/import ['\"](.*)['\"]/\1/")
    [ -n "$imp" ] || continue
    case "$imp" in
      ./*|../*) ( cd "$(dirname "$entry")" && python3 -c "import os,sys;print(os.path.normpath(os.path.join(os.getcwd(),sys.argv[1])))" "$imp" ) | sed "s#^$PWD/##" ;;
      @/*) echo "src/${imp#@/}" ;;
      /*) echo "${imp#/}" ;;
      *) echo "$imp" ;;
    esac
    return
  done
}
fill() {
  if [ -f "$components" ]; then
    mkdir -p "$(dirname "$1")"
    css="$(app_css)"
    python3 "$HERE/scaffold-fill.py" "$d_stack" "$slug" --components "$components" --brief "$brief" --lang "$d_lang" ${css:+--css "$css"} > "$1"
    cat >/dev/null; echo "wrote=$1"; echo "filled=$components"
  else
    write "$1"
  fi
}
case "$d_stack" in
  vite-react)
    ext=jsx; [ "$d_lang" = ts ] && ext=tsx
    write "__design-kit__/$slug.html" <<EOF
<!-- $MARK -->
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>design-kit: $slug</title></head>
<body><div id="design-kit-root"></div><script type="module" src="/src/__design-kit__/$slug.$ext"></script></body></html>
EOF
    fill "src/__design-kit__/$slug.$ext" <<EOF
/* $MARK */
import { createRoot } from "react-dom/client";
// Import the project's real components and providers here — never restyle a copy.
function Scratch() { return <main data-design-kit="$slug">Fill me with real components.</main>; }
createRoot(document.getElementById("design-kit-root")!).render(<Scratch />);
EOF
    if [ "$d_lang" != ts ]; then sed -i.bak 's/)!)/))/' "src/__design-kit__/$slug.$ext"; rm -f "src/__design-kit__/$slug.$ext.bak"; fi
    tw_source src/__design-kit__
    echo "open=$d_dev_url/__design-kit__/$slug.html" ;;
  vite-vue)
    ext=js; [ "$d_lang" = ts ] && ext=ts
    write "__design-kit__/$slug.html" <<EOF
<!-- $MARK -->
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>design-kit: $slug</title></head>
<body><div id="design-kit-root"></div><script type="module" src="/src/__design-kit__/$slug.main.$ext"></script></body></html>
EOF
    write "src/__design-kit__/$slug.main.$ext" <<EOF
/* $MARK */
import { createApp } from "vue";
import Scratch from "./$slug.vue";
createApp(Scratch).mount("#design-kit-root");
EOF
    fill "src/__design-kit__/$slug.vue" <<EOF
<!-- $MARK -->
<script setup>
// Import the project's real components here — never restyle a copy.
</script>
<template><main data-design-kit="$slug">Fill me with real components.</main></template>
EOF
    tw_source src/__design-kit__
    echo "open=$d_dev_url/__design-kit__/$slug.html" ;;
  next)
    fill "app/__design-kit__/$slug/page.tsx" <<EOF
/* $MARK */
// Import the project's real components here — never restyle a copy.
export default function DesignKitScratch() { return <main data-design-kit="$slug">Fill me with real components.</main>; }
EOF
    tw_source app/__design-kit__
    echo "open=$d_dev_url/__design-kit__/$slug" ;;
  nuxt)
    fill "pages/__design-kit__/$slug.vue" <<EOF
<!-- $MARK -->
<script setup>
// Import the project's real components here — never restyle a copy.
</script>
<template><main data-design-kit="$slug">Fill me with real components.</main></template>
EOF
    echo "open=$d_dev_url/__design-kit__/$slug" ;;
  laravel)
    # the wrapper (<x-app-layout> or a standalone page) is evidence-based, so the plain template also goes through scaffold-fill.py
    target="resources/views/__design-kit__/$slug.blade.php"; mkdir -p "$(dirname "$target")"
    if [ -f "$components" ]; then fill "$target" </dev/null; else
      python3 "$HERE/scaffold-fill.py" laravel "$slug" --components /dev/null --brief "$brief" > "$target"; echo "wrote=$target"; fi
    [ -f routes/web.php ] || { mkdir -p routes; echo "<?php" > routes/web.php; echo "wrote=routes/web.php"; }
    mark_line routes/web.php "Route::view('/__design-kit__/$slug', '__design-kit__.$slug'); // $MARK"
    echo "appended=routes/web.php"; tw_source resources/views/__design-kit__
    echo "open=$d_dev_url/__design-kit__/$slug" ;;
  laravel-inertia-react|laravel-inertia-vue)
    pages=resources/js/pages; [ -d resources/js/Pages ] && [ ! -d resources/js/pages ] && pages=resources/js/Pages
    ext=vue; [ "$d_stack" = laravel-inertia-react ] && { ext=jsx; [ "$d_lang" = ts ] && ext=tsx; }
    target="$pages/__design-kit__/$slug.$ext"; mkdir -p "$(dirname "$target")"
    inv=/dev/null; [ -f "$components" ] && inv="$components"
    python3 "$HERE/scaffold-fill.py" "$d_stack" "$slug" --components "$inv" --brief "$brief" --lang "$d_lang" > "$target"
    echo "wrote=$target"; [ "$inv" = /dev/null ] || echo "filled=$inv"
    [ -f routes/web.php ] || { mkdir -p routes; echo "<?php" > routes/web.php; echo "wrote=routes/web.php"; }
    mark_line routes/web.php "Route::inertia('/__design-kit__/$slug', '__design-kit__/$slug'); // $MARK"
    echo "appended=routes/web.php"; tw_source "$pages/__design-kit__"
    echo "open=$d_dev_url/__design-kit__/$slug" ;;
  *) echo "codebase-scaffold.sh: stack=$d_stack has no scratch template — pass --stack vite-react|vite-vue|next|nuxt|laravel|laravel-inertia-react|laravel-inertia-vue" >&2; exit 3 ;;
esac
