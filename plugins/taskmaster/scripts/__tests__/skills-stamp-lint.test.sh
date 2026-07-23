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

# --- reachability probe (WARN-only, CLAUDE_PLUGIN_ROOT-gated) ---
cache=$(mktemp -d); trap 'rm -f "$tmp_fw" "$tmp_ok" "$tmp_nostamp"; rm -rf "$cache"' EXIT
mkdir -p "$cache/taskmaster" "$cache/laravel/skills/laravel-best-practices"
printf -- '---\nname: laravel-best-practices\n---\n' > "$cache/laravel/skills/laravel-best-practices/SKILL.md"

# reachable skill: no warning, exit 0
set +e
out=$(CLAUDE_PLUGIN_ROOT="$cache/taskmaster" "$lint" --line 'laravel-best-practices' --files 'app/Models/User.php' 2>&1); rc=$?
set -e
if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q unreachable-skill; then
  printf 'PASS: reachable skill emits no warning (rc=%s)\n' "$rc"; pass=$((pass+1))
else
  printf 'FAIL: reachable skill emits no warning (rc=%s out=<%s>)\n' "$rc" "$out"; fail=$((fail+1))
fi

# unreachable skill: warning on stderr, exit STILL 0 (warn-only)
set +e
out=$(CLAUDE_PLUGIN_ROOT="$cache/taskmaster" "$lint" --line 'vue3-best-practices' --files 'resources/js/App.vue' 2>&1); rc=$?
set -e
if [ "$rc" = 0 ] && printf '%s' "$out" | grep -q 'unreachable-skill: "vue3-best-practices"'; then
  printf 'PASS: unreachable skill warns but exits 0 (rc=%s)\n' "$rc"; pass=$((pass+1))
else
  printf 'FAIL: unreachable skill warns but exits 0 (rc=%s out=<%s>)\n' "$rc" "$out"; fail=$((fail+1))
fi

# no CLAUDE_PLUGIN_ROOT: probe silently skipped
set +e
out=$(env -u CLAUDE_PLUGIN_ROOT "$lint" --line 'vue3-best-practices' --files 'resources/js/App.vue' 2>&1); rc=$?
set -e
if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q unreachable-skill; then
  printf 'PASS: probe skipped without CLAUDE_PLUGIN_ROOT (rc=%s)\n' "$rc"; pass=$((pass+1))
else
  printf 'FAIL: probe skipped without CLAUDE_PLUGIN_ROOT (rc=%s out=<%s>)\n' "$rc" "$out"; fail=$((fail+1))
fi

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
