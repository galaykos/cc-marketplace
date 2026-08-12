#!/usr/bin/env bash
# Fixture tests for cleanup.sh — builds a fake project tree with every scratch
# artifact shape the skill names, proves removal + verification + the residual.
set -u
CLEAN="$(cd "$(dirname "$0")/.." && pwd)/cleanup.sh"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

mk() { # fresh fixture project
  rm -rf "$T/p"; mkdir -p "$T/p/src/__design-preview__" "$T/p/routes" "$T/p/resources/views"
  echo '<html>' > "$T/p/__design-preview__.html"
  echo 'import x' > "$T/p/src/__design-preview__/main.tsx"
  echo '<div>' > "$T/p/resources/views/__design-preview__.blade.php"
  echo '<?php' > "$T/p/routes/__design-preview__.php"
  printf '<?php\nRoute::get("/");\nrequire __DIR__."/__design-preview__.php"; // __design-preview__\n' > "$T/p/routes/web.php"
  echo 'real file' > "$T/p/src/app.tsx"
}

mk
out=$(bash "$CLEAN" --verify "$T/p"); rc=$?
if [[ $rc -eq 1 ]] && grep -q "REMAIN" <<<"$out"; then pass=$((pass+1));
else echo "FAIL verify-dirty: rc=$rc"; echo "$out" | tail -3; fail=$((fail+1)); fi

out=$(bash "$CLEAN" "$T/p"); rc=$?
if [[ $rc -eq 0 ]] && grep -q "verified clean" <<<"$out"; then pass=$((pass+1));
else echo "FAIL remove: rc=$rc"; echo "$out" | tail -5; fail=$((fail+1)); fi

if [[ -f "$T/p/src/app.tsx" && ! -e "$T/p/src/__design-preview__" && ! -f "$T/p/__design-preview__.html" ]]; then pass=$((pass+1));
else echo "FAIL post-state: real file gone or scratch left"; fail=$((fail+1)); fi

if ! grep -q "__design-preview__" "$T/p/routes/web.php" && grep -q 'Route::get' "$T/p/routes/web.php"; then pass=$((pass+1));
else echo "FAIL web.php: marker line not stripped or real route lost"; fail=$((fail+1)); fi

out=$(bash "$CLEAN" --verify "$T/p"); rc=$?
if [[ $rc -eq 0 ]]; then pass=$((pass+1)); else echo "FAIL verify-clean: rc=$rc"; fail=$((fail+1)); fi

echo "design-preview cleanup tests: $pass passed, $fail failed"
exit $((fail > 0))
