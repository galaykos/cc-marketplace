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

# --- --card extraction, role-tagged shape ---
tmp_t_none=$(mktemp); tmp_t_ok=$(mktemp); tmp_t_two=$(mktemp); tmp_t_absent=$(mktemp)
trap 'rm -f "$tmp_fw" "$tmp_ok" "$tmp_nostamp" "$tmp_t_none" "$tmp_t_ok" "$tmp_t_two" "$tmp_t_absent"' EXIT
printf '# 04\n<card id="04">\n<facts>\n<file path="app/Policies/PostPolicy.php" line="3" mode="edit">x</file>\n</facts>\n<must>\n<skill name="none"/>\n</must>\n</card>\n' > "$tmp_t_none"
printf '# 04\n<card id="04">\n<facts>\n<file path="app/Policies/PostPolicy.php" line="3" mode="edit">x</file>\n</facts>\n<must>\n<skill name="laravel-best-practices"/>\n</must>\n</card>\n' > "$tmp_t_ok"
printf '# 04\n<card id="04">\n<facts>\n<file path="resources/js/Modal.vue" mode="create"/>\n</facts>\n<must>\n<skill name="vue-best-practices"/>\n<skill name="inertia-best-practices"/>\n</must>\n</card>\n' > "$tmp_t_two"
printf '# 04\n<card id="04">\n<facts>\n<file path="app/Policies/PostPolicy.php" line="3" mode="edit">x</file>\n</facts>\n<must>\n<change>y</change>\n</must>\n</card>\n' > "$tmp_t_absent"
run_case "tagged: framework file + name=none -> block"  2 "framework-card-no-skill" --card "$tmp_t_none"
run_case "tagged: framework file + laravel -> ok"       0 ""                        --card "$tmp_t_ok"
run_case "tagged: two <skill> elements -> ok"           0 ""                        --card "$tmp_t_two"
run_case "tagged: no <skill> element -> missing-stamp"  2 "missing-stamp"           --card "$tmp_t_absent"

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

# no CLAUDE_PLUGIN_ROOT (a Bash call by path): the probe resolves from the script's own
# plugin. A copy of the lint inside the fixture cache, so its siblings are the fixture's.
mkdir -p "$cache/taskmaster/scripts"
cp "$lint" "$here/../card-lint-record.sh" "$cache/taskmaster/scripts/"
bypath="$cache/taskmaster/scripts/skills-stamp-lint.sh"
for c in "unreachable|vue3-best-practices|resources/js/App.vue|1" \
         "reachable|laravel-best-practices|app/Models/User.php|0" \
         "none|none|src/util.py|0"; do
  IFS='|' read -r d st fl want <<EOF2
$c
EOF2
  set +e
  out=$(env -u CLAUDE_PLUGIN_ROOT "$bypath" --line "$st" --files "$fl" 2>&1); rc=$?
  set -e
  hit=0; printf '%s' "$out" | grep -q unreachable-skill && hit=1
  if [ "$rc" = 0 ] && [ "$hit" = "$want" ]; then
    printf 'PASS: no CLAUDE_PLUGIN_ROOT, %s stamp: probe from the script location (warned=%s)\n' "$d" "$hit"; pass=$((pass+1))
  else
    printf 'FAIL: no CLAUDE_PLUGIN_ROOT, %s stamp (rc=%s warned=%s want=%s out=<%s>)\n' "$d" "$rc" "$hit" "$want" "$out"; fail=$((fail+1))
  fi
done

# --- framework-card-no-skill names a qualified example ---
run_case "no-skill message suggests the plugin:skill form" 2 "e.g. laravel:laravel-best-practices" \
  --line 'none' --files 'app/Models/User.php'

# --- shadow probe (WARN-only): a bare stamp a project skill shadows ---
check_warn() { # desc present|absent substring cmd...
  local desc=$1 want=$2 sub=$3 out rc hit=0; shift 3
  set +e; out=$("$@" 2>&1); rc=$?; set -e
  printf '%s' "$out" | grep -qF -- "$sub" && hit=1
  if [ "$rc" = 0 ] && { { [ "$want" = present ] && [ "$hit" = 1 ]; } || { [ "$want" = absent ] && [ "$hit" = 0 ]; }; }; then
    printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"; pass=$((pass+1))
  else
    printf 'FAIL: %s (rc=%s out=<%s>)\n' "$desc" "$rc" "$out"; fail=$((fail+1))
  fi
}
proj="$cache/proj"   # a project carrying Boost-style skills; inside $cache so the trap clears it
for s in laravel-best-practices inertia-react-development tailwindcss-development house-rules; do
  mkdir -p "$proj/.claude/skills/$s"; printf -- '---\nname: %s\n---\n' "$s" > "$proj/.claude/skills/$s/SKILL.md"
done
bare=(env CLAUDE_PLUGIN_ROOT="$cache/taskmaster" CLAUDE_PROJECT_DIR="$proj" "$lint")
check_warn "shadowed bare stamp warns with the qualified name" present \
  'shadowed-skill: "laravel-best-practices" resolves to the project copy .claude/skills/laravel-best-practices/SKILL.md, not the marketplace skill — stamp "laravel:laravel-best-practices"' \
  "${bare[@]}" --line 'laravel-best-practices' --files 'app/Models/User.php'
check_warn "qualified stamp is not shadowed" absent shadowed-skill \
  "${bare[@]}" --line 'laravel:laravel-best-practices' --files 'app/Models/User.php'
check_warn "known twin maps inertia-react-development" present 'stamp "laravel:inertia-best-practices"' \
  "${bare[@]}" --line 'inertia-react-development' --files 'resources/js/Pages/Index.tsx'
check_warn "known twin maps tailwindcss-development" present 'stamp "ui-ux:tailwind-best-practices"' \
  "${bare[@]}" --line 'laravel:laravel-best-practices, tailwindcss-development' --files 'resources/js/Pages/Index.tsx'
check_warn "a project-only skill no plugin ships is not a shadow" absent shadowed-skill \
  "${bare[@]}" --line 'house-rules' --files 'app/Models/User.php'
check_warn "no project copy, no shadow warning" absent shadowed-skill \
  env CLAUDE_PLUGIN_ROOT="$cache/taskmaster" CLAUDE_PROJECT_DIR="$cache/taskmaster" "$lint" --line 'laravel-best-practices' --files 'app/Models/User.php'

# the installed cache nests a version dir: <marketplace>/<plugin>/<version>/
mkdir -p "$cache/mkt/taskmaster/0.48.1" "$cache/mkt/laravel/0.10.1/skills/laravel-best-practices"
printf -- '---\nname: laravel-best-practices\n---\n' > "$cache/mkt/laravel/0.10.1/skills/laravel-best-practices/SKILL.md"
check_warn "cache layout: the shadow names the plugin, not a version" present 'stamp "laravel:laravel-best-practices"' \
  env CLAUDE_PLUGIN_ROOT="$cache/mkt/taskmaster/0.48.1" CLAUDE_PROJECT_DIR="$proj" "$lint" --line 'laravel-best-practices' --files 'app/Models/User.php'
check_warn "cache layout: a cached sibling skill is reachable" absent unreachable-skill \
  env CLAUDE_PLUGIN_ROOT="$cache/mkt/taskmaster/0.48.1" CLAUDE_PROJECT_DIR="$proj" "$lint" --line 'laravel-best-practices' --files 'app/Models/User.php'

# --card: the project is the card's git toplevel, wherever the lint runs from
if command -v git >/dev/null 2>&1; then
  git init -q "$proj" 2>/dev/null
  mkdir -p "$proj/taskmaster-docs/tasks/demo"
  cp "$tmp_t_ok" "$proj/taskmaster-docs/tasks/demo/04-add-policy.md"
  check_warn "card: shadow found from the card's git toplevel" present 'shadowed-skill: "laravel-best-practices"' \
    env -u CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT="$cache/taskmaster" "$lint" --card "$proj/taskmaster-docs/tasks/demo/04-add-policy.md"
fi

# no CLAUDE_PLUGIN_ROOT (the model runs the script by path): siblings come from the
# script's own location, so this repo's plugins/laravel answers
check_warn "no CLAUDE_PLUGIN_ROOT: siblings from the script's location" present 'stamp "laravel:laravel-best-practices"' \
  env -u CLAUDE_PLUGIN_ROOT CLAUDE_PROJECT_DIR="$proj" "$lint" --line 'laravel-best-practices' --files 'app/Models/User.php'

# --- reachability of a qualified plugin:skill stamp: probed in the named plugin alone ---
repo_tm=$(cd "$here/../.." && pwd)
check_warn "qualified: an absent plugin warns unreachable-skill" present 'unreachable-skill: "ghost:ghost-best-practices"' \
  env CLAUDE_PLUGIN_ROOT="$repo_tm" "$lint" --line 'ghost:ghost-best-practices' --files 'app/Models/User.php'
check_warn "qualified: a plugin in this checkout is reachable" absent unreachable-skill \
  env CLAUDE_PLUGIN_ROOT="$repo_tm" "$lint" --line 'laravel:laravel-best-practices' --files 'app/Models/User.php'
check_warn "qualified: another plugin shipping the skill does not count" present 'unreachable-skill: "ghost:laravel-best-practices"' \
  env CLAUDE_PLUGIN_ROOT="$cache/taskmaster" "$lint" --line 'ghost:laravel-best-practices' --files 'app/Models/User.php'
check_warn "qualified: the plugin present without that skill warns" present 'unreachable-skill: "laravel:vue3-best-practices"' \
  env CLAUDE_PLUGIN_ROOT="$cache/taskmaster" "$lint" --line 'laravel:vue3-best-practices' --files 'resources/js/App.vue'
check_warn "qualified, cache layout: a cached plugin is reachable" absent unreachable-skill \
  env CLAUDE_PLUGIN_ROOT="$cache/mkt/taskmaster/0.48.1" "$lint" --line 'laravel:laravel-best-practices' --files 'app/Models/User.php'
check_warn "qualified, cache layout: an absent plugin warns" present 'unreachable-skill: "ghost:ghost-best-practices"' \
  env CLAUDE_PLUGIN_ROOT="$cache/mkt/taskmaster/0.48.1" "$lint" --line 'ghost:ghost-best-practices' --files 'app/Models/User.php'
check_warn "qualified, no CLAUDE_PLUGIN_ROOT: an absent plugin still warns" present 'unreachable-skill: "ghost:ghost-best-practices"' \
  env -u CLAUDE_PLUGIN_ROOT "$lint" --line 'ghost:ghost-best-practices' --files 'app/Models/User.php'

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
