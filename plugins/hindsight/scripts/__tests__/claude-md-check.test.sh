#!/usr/bin/env bash
# Fixture tests for claude-md-check.sh — a stale path and a stale npm script are
# reported with their line numbers; live ones are not; prose paths are never read;
# no CLAUDE.md is a clean exit; nested files are found.
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/claude-md-check.sh"
root="$(mktemp -d)"; trap 'rm -rf "$root"' EXIT
pass=0; fail=0
expect()  { if grep -q -- "$2" <<<"$OUT"; then pass=$((pass+1)); else echo "FAIL $1: missing '$2'"; echo "$OUT"; fail=$((fail+1)); fi; }
reject()  { if grep -q -- "$2" <<<"$OUT"; then echo "FAIL $1: unexpected '$2'"; echo "$OUT"; fail=$((fail+1)); else pass=$((pass+1)); fi; }

OUT=$(bash "$SCRIPT" "$root"); expect "empty repo" "no CLAUDE.md"

mkdir -p "$root/scripts" "$root/packages/api"
touch "$root/scripts/live.sh"
printf '{"scripts":{"build":"tsc"}}' > "$root/package.json"
printf 'lint:\n\techo ok\n' > "$root/Makefile"
cat > "$root/CLAUDE.md" <<'MD'
# Project
Run `npm run build` then `npm run deploy`.
Live: `scripts/live.sh`. Gone: `scripts/gone.sh`.
Prose mention of scripts/also-gone.sh without backticks.
`make lint` works; `make release` does not exist.
`composer install` is never checked. Variable `$ROOT/x.sh` skipped.
MD
printf 'See `handler.php` and `../missing.md`.\n' > "$root/packages/api/CLAUDE.md"
touch "$root/packages/api/handler.php"

OUT=$(bash "$SCRIPT" "$root")
expect "root listed"        "./CLAUDE.md"
expect "stale npm script"   'L2  stale script  npm run deploy'
reject "live npm script"    'npm run build'
expect "stale path + line"  'L3  stale path    scripts/gone.sh'
reject "live path"          'stale path    scripts/live.sh'
reject "prose not read"     'also-gone'
expect "stale make target"  'stale script  make release'
reject "live make target"   'make lint'
reject "composer install"   'composer install'
reject "variable skipped"   'x.sh'
expect "nested file found"  "./packages/api/CLAUDE.md"
reject "relative live"      'stale path    handler.php'
expect "relative stale"     'stale path    ../missing.md'
expect "total line"         "stale references: 4"
expect "residual stated"    "prose references and architecture claims are not"

echo "claude-md-check tests: $pass passed, $fail failed"
exit $((fail > 0))
