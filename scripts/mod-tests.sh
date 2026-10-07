#!/usr/bin/env bash
# mod-tests.sh — run `claude plugin test` on every mod: each plugins/*/ whose
# hooks/hooks.json has `modules`, plus templates/mods/kit-harness (the shared kit's tests).
#
# WHAT IT CATCHES: a failing mod test; a mod with no *.test.ts or *.test.tsx (the CLI exits
# 1); a host with hooks modules turned off (disableAllHooks exits 1, measured on 2.1.291) —
# the "hooks modules are turned off" text is matched too, so an off run that exits 0 still
# FAILs instead of passing on zero tests.
# WHAT IT DOES NOT: it runs tests; it proves nothing a test does not assert — a module branch
# no test reaches passes. No typecheck (tsc is a spec non-goal). Whether each `modules` entry
# exists and exports register is validate.sh's (pc_mod_modules); kit copies, pc_mod_kit.
#
# Standing: gate (a named, fail-capable CI step after the CLI install) — and a local pre-push check.
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
