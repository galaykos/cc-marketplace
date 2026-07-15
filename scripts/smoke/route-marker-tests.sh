#!/usr/bin/env bash
# Smoke tests for skill-router route.sh stack_marker evaluation: marker match
# fires / mismatch suppresses / absent manifest fires (fail-open) / negation /
# malformed regex fires / markerless rows unchanged / hook stays fail-open.
# Uses a scratch CLAUDE_PLUGIN_ROOT and scratch cwds — never the live rules.tsv
# or any real .claude state.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROUTE="$ROOT/plugins/skill-router/hooks/route.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PR="$TMP/proot/skill-router"
mkdir -p "$PR" "$TMP/proot/vue3" "$TMP/proot/vue2" "$TMP/proot/php" "$TMP/proot/misc"

# Scratch rules: vue3/vue2 markered pair, negated php row, malformed-regex row,
# markered row whose manifest never exists, and a markerless 5-column row.
printf 'glob\t*.vue\tvue3-canary\tvue3\thigh\tpackage.json~"vue"[[:space:]]*:[[:space:]]*"[~^>=v ]*3[."]\n' > "$PR/rules.tsv"
printf 'glob\t*.vue\tvue2-canary\tvue2\thigh\tpackage.json~"vue"[[:space:]]*:[[:space:]]*"[~^>=v ]*2[."]\n' >> "$PR/rules.tsv"
printf 'glob\t*.php\tphp-canary\tphp\thigh\t!composer.json~laravel/framework\n' >> "$PR/rules.tsv"
printf 'glob\t*.php\tbadre-canary\tmisc\thigh\tpackage.json~([bad\n' >> "$PR/rules.tsv"
printf 'glob\t*.md\tghost-canary\tmisc\thigh\tnosuchfile.json~anything\n' >> "$PR/rules.tsv"
printf 'glob\t*.css\tplain-canary\tmisc\thigh\n' >> "$PR/rules.tsv"

mkdir -p "$TMP/vue3cwd" "$TMP/vue2cwd" "$TMP/emptycwd" "$TMP/laravelcwd"
echo '{"dependencies":{"vue":"^3.2.4"}}'   > "$TMP/vue3cwd/package.json"
echo '{"dependencies":{"vue":"^2.7.16"}}'  > "$TMP/vue2cwd/package.json"
echo '{"require":{"laravel/framework":"^11.0"}}' > "$TMP/laravelcwd/composer.json"

rc=0
route() { # $1 cwd, $2 file — fresh session id per call so dedup never interferes
  printf '{"session_id":"s%s","cwd":"%s","tool_input":{"file_path":"%s"}}' "$RANDOM$RANDOM" "$1" "$2" \
    | CLAUDE_PLUGIN_ROOT="$PR" bash "$ROUTE"
  rm -rf "$1/.claude"
}
expect() { # $1 label, $2 output, $3 must-contain ('' = none), $4 must-not-contain ('' = skip)
  local label="$1" out="$2" yes="$3" no="$4" ok=1
  if [ -n "$yes" ]; then case "$out" in *"$yes"*) ;; *) ok=0 ;; esac; fi
  if [ -n "$no"  ]; then case "$out" in *"$no"*)  ok=0 ;; esac; fi
  if [ "$ok" -eq 1 ]; then echo "PASS: $label"; else echo "FAIL: $label — got: ${out:-<empty>}"; rc=1; fi
}

out=$(route "$TMP/vue3cwd" App.vue)
expect "marker match fires (vue3 on ^3.2.4 — colliding digit)" "$out" 'vue3-canary' ''
expect "marker mismatch suppresses (vue2 on ^3.2.4)" "$out" '' 'vue2-canary'

out=$(route "$TMP/vue2cwd" App.vue)
expect "vue2 fires on ^2.7.16, vue3 suppressed" "$out" 'vue2-canary' 'vue3-canary'

out=$(route "$TMP/emptycwd" App.vue)
expect "absent manifest fires both (fail-open)" "$out" 'vue3-canary' ''
expect "absent manifest fires both (vue2 too)" "$out" 'vue2-canary' ''

out=$(route "$TMP/laravelcwd" foo.php)
expect "negated marker suppresses when manifest matches" "$out" '' 'php-canary'
out=$(route "$TMP/emptycwd" foo.php)
expect "negated marker fires when manifest absent" "$out" 'php-canary' ''

out=$(route "$TMP/vue3cwd" foo.php)
expect "malformed marker regex fires (grep exit 2 fail-open)" "$out" 'badre-canary' ''

out=$(route "$TMP/emptycwd" note.md)
expect "markered row with absent manifest fires (6-field read guard)" "$out" 'ghost-canary' ''

out=$(route "$TMP/emptycwd" a.css)
expect "markerless 5-column row fires unchanged" "$out" 'plain-canary' ''

out=$(echo '{}' | CLAUDE_PLUGIN_ROOT="$PR" bash "$ROUTE") && e=$? || e=$?
if [ "$e" -eq 0 ] && [ -z "$out" ]; then echo "PASS: empty tool_input exits 0 silently"; else echo "FAIL: fail-open on '{}' (exit=$e out=$out)"; rc=1; fi
out=$(printf '' | CLAUDE_PLUGIN_ROOT="$PR" bash "$ROUTE") && e=$? || e=$?
if [ "$e" -eq 0 ] && [ -z "$out" ]; then echo "PASS: empty stdin exits 0 silently"; else echo "FAIL: fail-open on empty stdin (exit=$e out=$out)"; rc=1; fi

[ "$rc" -eq 0 ] && echo "All route-marker smoke tests passed."
exit "$rc"
