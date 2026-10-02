#!/usr/bin/env bash
# mod-tests.sh — run `claude plugin test` for every plugin that ships a mod: a
# hooks/hooks.json naming a hooks module under `modules` (CLI 2.1.287+), the TypeScript
# Claude Code loads into its own process.
#
# WHAT IT CATCHES that nothing else here does. validate.sh reads no TypeScript.
# official-validate.sh's `plugin validate --strict` analyses a module statically (the
# events it hooks, the `$` calls it makes, the env it reads) but runs none of it. The
# plugin-harness CI step globs `scripts/__tests__/*.test.sh` only. This runs the
# module's own `*.test.ts` / `*.test.tsx` files through the engine's test kit, and FAILS
# a plugin that ships a module with no such file: a mod nothing exercises.
#
# WHAT IT DOES NOT CATCH. The kit stands for the engine beneath the plugin: it paints no
# surface, calls no model, and says nothing about the module beside another plugin's mod
# (their order is the person's install order). It does not type-check; the kit strips
# types. A test that asserts nothing passes.
#
# VERSION. The kit moved with the mods release: on 2.1.282 `test(name, { options }, body)`
# ignored `options`, and one of design-kit's ten cases failed there while all ten pass on
# 2.1.287 (measured 2026-10-02). A CLI older than MIN is refused rather than trusted.
#
# EGRESS. As official-validate.sh: throwaway HOME, auto-updater and non-essential traffic
# off, stdin closed. The kit needs no sign-in and no network.
#
# Standing: gate (the named, fail-capable CI step "Mod tests", after the official
# validator, where `claude` reaches PATH) — and a local pre-push check.
set -u
cd "$(dirname "$0")/.." || exit 2
ROOT="$PWD"
MIN="2.1.287"

command -v claude >/dev/null 2>&1 || { echo "FAIL: claude CLI not on PATH (CI installs it in the official-validator step)"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not on PATH"; exit 1; }
have="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
if [ -z "$have" ] || [ "$(printf '%s\n%s\n' "$MIN" "$have" | sort -V | head -1)" != "$MIN" ]; then
  echo "FAIL: claude ${have:-unknown} is older than $MIN, the first release whose test kit these suites are written for"
  exit 1
fi
export HOME; HOME="$(mktemp -d)" || exit 2
export DISABLE_AUTOUPDATER=1 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
trap 'rm -rf "$HOME"' EXIT

rc=0 ran=0
out="$HOME/test.out"
for hj in plugins/*/hooks/hooks.json; do
  [ -f "$hj" ] || continue
  [ "$(jq -r '(.modules // []) | length' "$hj" 2>/dev/null)" -gt 0 ] 2>/dev/null || continue
  dir="$(dirname "$(dirname "$hj")")"
  if [ -z "$(find "$dir" -type f \( -name '*.test.ts' -o -name '*.test.tsx' \) -not -path '*/node_modules/*' | head -1)" ]; then
    echo "FAIL: $dir ships a hooks module and no *.test.ts — add one beside it (claude plugin test runs every file under the plugin)"
    rc=1; continue
  fi
  ran=$((ran + 1))
  if (cd "$ROOT/$dir" && claude plugin test . </dev/null >"$out" 2>&1); then
    echo "ok: $dir — $(grep -E '^ *[0-9]+ pass' "$out" | tr -s ' ' | sed 's/^ //')"
  else
    echo "FAIL: $dir"; cat "$out"; rc=1
  fi
done
[ "$rc" -eq 0 ] && echo "OK: mod tests passed in $ran plugin(s) shipping a hooks module (claude $have)"
exit $rc
