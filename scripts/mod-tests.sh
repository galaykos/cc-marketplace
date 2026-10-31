#!/usr/bin/env bash
# mod-tests.sh — `claude plugin test` on every mod (plugins/*/ whose hooks.json has `modules`) and templates/mods/kit-harness: FAILs a red test, a mod with no *.test.ts(x), hooks modules turned off (exit 1 or that text).
# Misses: a module branch no test reaches, types (no tsc), whether each `modules` entry exists and exports register (validate.sh: pc_mod_modules, pc_mod_kit). Standing: gate, a CI step and a pre-push check.
# Why, limits, history: rationale/derivations/scripts.md § scripts/mod-tests.sh
set -u
cd "$(dirname "$0")/.." || exit 2

command -v claude >/dev/null 2>&1 || { echo "FAIL: claude CLI not on PATH"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "FAIL: jq not on PATH — cannot read hooks.json modules"; exit 1; }

targets=()
for hj in plugins/*/hooks/hooks.json; do
  [ -f "$hj" ] || continue
  jq -e 'has("modules")' "$hj" >/dev/null 2>&1 && targets+=("${hj%/hooks/hooks.json}")
done
targets+=(templates/mods/kit-harness)

out="$(mktemp)" || exit 2
trap 'rm -f "$out"' EXIT
rc=0
for d in "${targets[@]}"; do
  if claude plugin test "$d" </dev/null >"$out" 2>&1 && ! grep -qF "hooks modules are turned off" "$out"; then
    echo "PASS $d"
  else
    echo "FAIL $d"; tail -n 20 "$out"; rc=1
  fi
done
exit $rc
