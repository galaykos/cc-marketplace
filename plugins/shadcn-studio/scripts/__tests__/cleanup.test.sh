#!/usr/bin/env bash
# Fixture tests for cleanup.sh — deletion happens only on a provable scratch
# tree; every refusal path proven.
set -u
CLEAN="$(cd "$(dirname "$0")/.." && pwd)/cleanup.sh"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

mkscratch() {
  rm -rf "$T/s"; mkdir -p "$T/s"
  echo '{}' > "$T/s/components.json"
  printf 'export default {} // serves /__studio marker\n' > "$T/s/vite.config.ts"
  mkdir -p "$T/s/node_modules/x"
}

mkscratch
out=$(bash "$CLEAN" "$T/s"); rc=$?
if [[ $rc -eq 0 && ! -e "$T/s" ]]; then pass=$((pass+1));
else echo "FAIL delete: rc=$rc, exists=$([[ -e $T/s ]] && echo y || echo n): $out"; fail=$((fail+1)); fi

mkdir -p "$T/notstudio"; echo hi > "$T/notstudio/f"
out=$(bash "$CLEAN" "$T/notstudio"); rc=$?
if [[ $rc -eq 3 && -e "$T/notstudio/f" ]]; then pass=$((pass+1));
else echo "FAIL refuse-nonstudio: rc=$rc: $out"; fail=$((fail+1)); fi

mkscratch; mkdir "$T/s/.git"
out=$(bash "$CLEAN" "$T/s"); rc=$?
if [[ $rc -eq 3 && -e "$T/s" ]]; then pass=$((pass+1));
else echo "FAIL refuse-gittree: rc=$rc: $out"; fail=$((fail+1)); fi

mkscratch; rm "$T/s/components.json"
out=$(bash "$CLEAN" "$T/s"); rc=$?
if [[ $rc -eq 3 && -e "$T/s" ]]; then pass=$((pass+1));
else echo "FAIL refuse-nocomponents: rc=$rc: $out"; fail=$((fail+1)); fi

out=$(bash "$CLEAN" "$T/gone-$RANDOM"); rc=$?
if [[ $rc -eq 0 ]] && grep -q "already clean" <<<"$out"; then pass=$((pass+1));
else echo "FAIL missing-dir: rc=$rc: $out"; fail=$((fail+1)); fi

out=$(bash "$CLEAN" ""); rc=$?
if [[ $rc -eq 2 ]]; then pass=$((pass+1)); else echo "FAIL usage: rc=$rc"; fail=$((fail+1)); fi

echo "shadcn-studio cleanup tests: $pass passed, $fail failed"
exit $((fail > 0))
