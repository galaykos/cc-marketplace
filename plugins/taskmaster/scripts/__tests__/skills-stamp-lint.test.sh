#!/usr/bin/env bash
# Tests for skills-stamp-lint.sh — the framework-card stamp lint.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lint="$here/../skills-stamp-lint.sh"
[ -x "$lint" ] || { printf 'FAIL: lint not executable at %s\n' "$lint"; exit 1; }

pass=0; fail=0
run_case() {
  desc="$1"; exp_rc="$2"; exp_sub="$3"; shift 3
  set +e; out=$("$lint" "$@" 2>&1); rc=$?; set -e
  ok=1
  [ "$rc" = "$exp_rc" ] || ok=0
  [ -n "$exp_sub" ] && { printf '%s' "$out" | grep -q -- "$exp_sub" || ok=0; }
  if [ "$ok" = 1 ]; then printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"; pass=$((pass+1))
  else printf 'FAIL: %s (rc=%s want=%s; out=<%s>)\n' "$desc" "$rc" "$exp_rc" "$out"; fail=$((fail+1)); fi
}

# --- parts form: framework source signals ---
run_case ".php + none detected -> block" 2 "framework-card-no-skill" \
  --line 'none detected' --files 'src/Http/Controllers/UserController.php'
run_case ".php + laravel skill -> ok" 0 "" \
  --line 'laravel-best-practices' --files 'src/Http/Controllers/UserController.php'
run_case ".blade.php + none -> block" 2 "framework-card-no-skill" \
  --line 'none' --files 'resources/views/user/edit.blade.php'
run_case ".vue + none detected -> block" 2 "framework-card-no-skill" \
  --line 'none detected' --files 'resources/js/components/Modal.vue'
run_case ".tsx + react skill -> ok" 0 "" \
  --line 'react-best-practices' --files 'src/components/Modal.tsx'
run_case "empty stamp on framework card -> block" 2 "framework-card-no-skill" \
  --line '' --files 'app/Models/User.php'

# --- parts form: NON-framework cards must NOT false-positive ---
run_case ".ts generic + none detected -> ok (no false positive)" 0 "" \
  --line 'none detected' --files 'src/config/env.ts'
run_case ".py + none detected -> ok (no python plugin here)" 0 "" \
  --line 'none detected' --files 'scripts/migrate.py'
run_case ".md/.json docs + none -> ok" 0 "" \
  --line 'none detected' --files 'README.md package.json'

# --- --card extraction ---
tmp_fw=$(mktemp); tmp_ok=$(mktemp); tmp_nostamp=$(mktemp)
trap 'rm -f "$tmp_fw" "$tmp_ok" "$tmp_nostamp"' EXIT
printf '# 04 — add policy\n\n**Context:**\n- Files: `app/Policies/PostPolicy.php`\n\n**Skills to apply:** none detected\n' > "$tmp_fw"
printf '# 04 — add policy\n\n**Context:**\n- Files: `app/Policies/PostPolicy.php`\n\n**Skills to apply:** laravel-best-practices\n' > "$tmp_ok"
printf '# 04 — add policy\n\n**Context:**\n- Files: `app/Policies/PostPolicy.php`\n\n**Agent:** backend\n' > "$tmp_nostamp"
run_case "card: framework file + none detected -> block" 2 "framework-card-no-skill" --card "$tmp_fw"
run_case "card: framework file + laravel skill -> ok"   0 ""                        --card "$tmp_ok"
run_case "card: missing stamp line -> block"            2 "missing-stamp"           --card "$tmp_nostamp"

# --- usage ---
run_case "usage: no args" 3 "usage"

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
