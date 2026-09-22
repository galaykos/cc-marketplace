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
#                     routes/web.php.
#
# WHAT IT DOES NOT CATCH. A project with two stacks (Laravel + a separate Vite SPA)
# resolves to Laravel because `artisan` outranks `vite.config.*`; pass --stack to
# override. It never starts the dev server and never fills the scratch page — the
# model does both. Standing: scripts/__tests__/codebase.test.sh drives --detect
# and --create on a Vite React fixture and a Laravel fixture.
set -euo pipefail

MARK="__design-kit__ scratch — removed by codebase-cleanup.sh"
mode=""; slug=""; force_stack=""
while [ $# -gt 0 ]; do
  case "$1" in
    --detect) mode=detect ;;
    --create) mode=create; slug="${2:-}"; shift ;;
    --stack) case "${2:-}" in vite-react|vite-vue|next|nuxt|laravel) force_stack="$2" ;; *) echo "codebase-scaffold.sh: --stack must be vite-react|vite-vue|next|nuxt|laravel" >&2; exit 2 ;; esac; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "codebase-scaffold.sh: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done
[ -n "$mode" ] || { echo "codebase-scaffold.sh: --detect or --create <slug> required" >&2; exit 2; }

has_dep() { [ -f package.json ] && grep -Eq "\"$1\"[[:space:]]*:" package.json; }
first_dir() { for d in "$@"; do [ -d "$d" ] && { echo "$d"; return; }; done; echo "-"; }

detect() {
  stack=unknown; dev_cmd="-"; dev_url="-"; lang=js
  [ -f tsconfig.json ] && lang=ts
  if [ -n "$force_stack" ]; then stack="$force_stack"
  elif [ -f artisan ] && grep -rlq --include='*.blade.php' '@vite' resources/views 2>/dev/null; then stack=laravel
  elif ls next.config.* >/dev/null 2>&1 && [ -d app ]; then stack=next
  elif ls nuxt.config.* >/dev/null 2>&1; then stack=nuxt
  elif ls vite.config.* >/dev/null 2>&1; then
    if has_dep vue; then stack=vite-vue; elif has_dep react; then stack=vite-react; else stack=vite; fi
  fi
  case "$stack" in
    laravel) dev_cmd="php artisan serve & npm run dev"; dev_url="http://127.0.0.1:8000" ;;
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
eval "$(detect | sed 's/^/d_/; s/=/=\x27/; s/$/\x27/')"

write() { mkdir -p "$(dirname "$1")"; cat > "$1"; echo "wrote=$1"; }
case "$d_stack" in
  vite-react)
    ext=jsx; [ "$d_lang" = ts ] && ext=tsx
    write "__design-kit__/$slug.html" <<EOF
<!-- $MARK -->
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>design-kit: $slug</title></head>
<body><div id="design-kit-root"></div><script type="module" src="/src/__design-kit__/$slug.$ext"></script></body></html>
EOF
    write "src/__design-kit__/$slug.$ext" <<EOF
/* $MARK */
import { createRoot } from "react-dom/client";
// Import the project's real components and providers here — never restyle a copy.
function Scratch() { return <main data-design-kit="$slug">Fill me with real components.</main>; }
createRoot(document.getElementById("design-kit-root")!).render(<Scratch />);
EOF
    [ "$d_lang" = ts ] || sed -i.bak 's/)!)/))/' "src/__design-kit__/$slug.$ext" && rm -f "src/__design-kit__/$slug.$ext.bak"
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
    write "src/__design-kit__/$slug.vue" <<EOF
<!-- $MARK -->
<script setup>
// Import the project's real components here — never restyle a copy.
</script>
<template><main data-design-kit="$slug">Fill me with real components.</main></template>
EOF
    echo "open=$d_dev_url/__design-kit__/$slug.html" ;;
  next)
    write "app/__design-kit__/$slug/page.tsx" <<EOF
/* $MARK */
// Import the project's real components here — never restyle a copy.
export default function DesignKitScratch() { return <main data-design-kit="$slug">Fill me with real components.</main>; }
EOF
    echo "open=$d_dev_url/__design-kit__/$slug" ;;
  nuxt)
    write "pages/__design-kit__/$slug.vue" <<EOF
<!-- $MARK -->
<script setup>
// Import the project's real components here — never restyle a copy.
</script>
<template><main data-design-kit="$slug">Fill me with real components.</main></template>
EOF
    echo "open=$d_dev_url/__design-kit__/$slug" ;;
  laravel)
    write "resources/views/__design-kit__/$slug.blade.php" <<EOF
{{-- $MARK --}}
{{-- Extend the project's real layout and use its real components — never restyle a copy. --}}
<x-app-layout>
    <main data-design-kit="$slug">Fill me with real components.</main>
</x-app-layout>
EOF
    [ -f routes/web.php ] || { mkdir -p routes; echo "<?php" > routes/web.php; echo "wrote=routes/web.php"; }
    printf "Route::view('/__design-kit__/%s', '__design-kit__.%s'); // %s\n" "$slug" "$slug" "$MARK" >> routes/web.php
    echo "appended=routes/web.php"
    echo "open=$d_dev_url/__design-kit__/$slug" ;;
  *) echo "codebase-scaffold.sh: stack=$d_stack has no scratch template — pass --stack vite-react|vite-vue|next|nuxt|laravel" >&2; exit 3 ;;
esac
