#!/usr/bin/env bash
# Fixture tests for scan.sh — a synthetic project proves the table rows, the
# red flags, and the not-covered honesty line.
#
# WHY THE STUBBED node. The engines-floor branch (scan.sh: the `inst == v*` guard)
# only runs when `node -v` SUCCEEDS inside the fixture. Version managers that
# honour package.json engines — lerd, volta, fnm with auto-switch — exit 1 there
# instead, because the fixture asks for a node that is not installed:
#
#   $ cd <fixture>; node -v
#   error: Requested version v99.x.x is not currently installed   # rc=1
#
# `inst` then reads "not installed", the guard is false, and the assertion this
# test exists to make silently never runs. GitHub Actions' setup-node lays down a
# plain binary with no shim, so CI stayed green while the check was dead on every
# developer machine using a shim. The fixture now OWNS its runtime: a stub `node`
# on PATH makes both directions deterministic everywhere.
set -u
SCAN="$(cd "$(dirname "$0")/.." && pwd)/scan.sh"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

# stub_node <version> — a `node` on PATH that reports exactly <version>, with no
# opinion about package.json. Echoed so the caller can prepend it to PATH.
stub_node() {
  local dir="$T/stub-$1"
  mkdir -p "$dir"
  printf '#!/bin/sh\necho %s\n' "$1" > "$dir/node"
  chmod +x "$dir/node"
  printf '%s' "$dir"
}

expect() { # expect <name> <grep>
  if grep -q "$2" <<<"$OUT"; then pass=$((pass+1));
  else echo "FAIL $1: missing '$2'"; fail=$((fail+1)); fi
}

# Fixture 1: node project, two lockfiles, engines floor above any real node, go.mod.
mkdir -p "$T/a"
cat > "$T/a/package.json" <<'EOF'
{ "engines": { "node": ">=99" },
  "dependencies": { "react": "^19.0.0", "vite": "^8.0.0" } }
EOF
touch "$T/a/package-lock.json" "$T/a/yarn.lock" "$T/a/go.mod"
printf 'FROM node:latest\n' > "$T/a/Dockerfile"
OUT=$(PATH="$(stub_node v18.0.0):$PATH" bash "$SCAN" "$T/a")
expect "node row"        "node runtime"
expect "engines floor"   "below the engines floor"
expect "floor names both" "node v18.0.0 is below the engines floor"
expect "multi-lock flag" "MULTIPLE js lockfiles"
expect "react row"       "| react | ^19.0.0 |"
expect "unpinned image"  "unpinned image"
expect "not-covered"     "go.mod present — ecosystem not covered"

# Fixture 1b: NEGATIVE CONTROL — same project, an installed node that SATISFIES
# the floor. Without this the suite cannot tell "the flag fires correctly" from
# "the flag fires always"; the bug this fixture set shipped with was the mirror
# case, a branch that never fired at all.
refute() { # refute <name> <grep>
  if grep -q "$2" <<<"$OUT"; then echo "FAIL $1: unexpected '$2'"; fail=$((fail+1));
  else pass=$((pass+1)); fi
}
OUT=$(PATH="$(stub_node v99.1.0):$PATH" bash "$SCAN" "$T/a")
expect "control: node row"    "| node runtime | >=99 | v99.1.0 |"
refute "control: no floor flag" "below the engines floor"
refute "control: no red flag for node" "node v99.1.0 is below"

# Fixture 1c: a 2026 JS stack the framework loop did not name. An Astro-, Svelte- or
# Angular-only repo scanned as "node + a lockfile" and produced no framework row at all
# (panel 2026-09-22, WEB 12) — the report was not wrong, it was empty, which reads the
# same as a repo with no framework.
mkdir -p "$T/d"
cat > "$T/d/package.json" <<'EOF'
{ "dependencies": { "astro": "^5.2.0", "svelte": "^5.16.0", "@sveltejs/kit": "^2.15.0",
                    "@angular/core": "^19.0.0", "@remix-run/react": "^2.15.0",
                    "react-router": "^7.1.0", "hono": "^4.6.0",
                    "@prisma/client": "^6.1.0", "drizzle-orm": "^0.38.0" } }
EOF
touch "$T/d/package-lock.json"
OUT=$(bash "$SCAN" "$T/d")
for dep in astro svelte "@sveltejs/kit" "@angular/core" "@remix-run/react" react-router \
           hono "@prisma/client" drizzle-orm; do
  expect "framework row $dep" "| $dep | \^"
done

# Fixture 2: php project, no lock.
mkdir -p "$T/b"
cat > "$T/b/composer.json" <<'EOF'
{ "require": { "php": "^8.3", "laravel/framework": "^12.0" } }
EOF
OUT=$(bash "$SCAN" "$T/b")
expect "php row"       "php runtime"
expect "laravel row"   "laravel/framework"
expect "no-lock flag"  "NO composer.lock"

# Fixture 2b: game engines and Blender. A Godot + Blender repo printed an empty table
# (2026-11-06), the silent zero this script promises never to give.
mkdir -p "$T/g/art" "$T/u/ProjectSettings" "$T/u/Assets" "$T/r" "$T/n/ProjectSettings"
printf 'config_version=5\n[application]\nconfig/features=PackedStringArray("4.7", "Forward Plus")\n' > "$T/g/project.godot"
touch "$T/g/art/knight.blend"
OUT=$(bash "$SCAN" "$T/g")
expect "godot row"   "| godot | 4.7 |"
# Stubbed engine binaries pin the --version branch both ways, as stub_node does for node.
mkdir -p "$T/stub-godot-ok" "$T/stub-godot-bad"
printf '#!/bin/sh\necho 4.7.stable\n' > "$T/stub-godot-ok/godot"; printf '#!/bin/sh\nexit 1\n' > "$T/stub-godot-bad/godot"
chmod +x "$T/stub-godot-ok/godot" "$T/stub-godot-bad/godot"
OUT=$(PATH="$T/stub-godot-ok:$PATH" bash "$SCAN" "$T/g")
expect "godot installed from --version" "| godot | 4.7 | 4.7.stable |"
OUT=$(PATH="$T/stub-godot-bad:$PATH" bash "$SCAN" "$T/g")
expect "godot --version failure named" "| godot | 4.7 | on PATH, --version failed |"
expect "blender row" "| blender | — |"
printf 'm_EditorVersion: 6000.0.23f1\nm_EditorVersionWithRevision: 6000.0.23f1 (abc)\n' > "$T/u/ProjectSettings/ProjectVersion.txt"
OUT=$(bash "$SCAN" "$T/u")
expect "unity row"   "| unity | 6000.0.23f1 |"
printf '{ "FileVersion": 3, "EngineAssociation": "5.4" }\n' > "$T/r/Game.uproject"
OUT=$(bash "$SCAN" "$T/r")
expect "unreal row"  "| unreal | 5.4 |"
printf 'import bpy\n' > "$T/r/build.py"
OUT=$(bash "$SCAN" "$T/r")
expect "bpy import is blender evidence" "| blender | — |"

# Fixture 2c: NEGATIVE CONTROLS — evidence signals.md says is not enough. A ProjectVersion.txt
# with no Assets/ beside it, a lone .glb (every three.js repo has one), a .py without bpy.
printf 'm_EditorVersion: 6000.0.23f1\n' > "$T/n/ProjectSettings/ProjectVersion.txt"
touch "$T/n/model.glb"; printf 'import os\n' > "$T/n/tool.py"
mkdir -p "$T/n/vendor" "$T/n/a/b/c"; touch "$T/n/vendor/pack.blend" "$T/n/a/b/c/deep.blend"
OUT=$(bash "$SCAN" "$T/n")
refute "control: no unity without Assets/" "| unity |"
refute "control: no blender from .glb, plain .py, vendor/ or depth 4" "| blender |"
OUT=$(bash "$SCAN" "$T/b")
for eng in godot unity unreal blender; do refute "control: laravel has no $eng row" "| $eng |"; done

# Fixture 3: empty dir — still a report, exit 0, no flags beyond none-line.
mkdir -p "$T/c"
OUT=$(bash "$SCAN" "$T/c"); rc=$?
if [[ $rc -eq 0 ]]; then pass=$((pass+1)); else echo "FAIL empty rc=$rc"; fail=$((fail+1)); fi
expect "none line" "none detected by the mechanical pass"

echo "stack-scan tests: $pass passed, $fail failed"
exit $((fail > 0))
