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
# ||-chain rows: installed node_modules version first (authoritative), then
# the declared package.json range — first decisive alternative wins
printf 'glob\t*.svelte\tchain3-canary\tmisc\thigh\tnode_modules/svelte/package.json~"version"[[:space:]]*:[[:space:]]*"3[."]||package.json~"svelte"[[:space:]]*:[[:space:]]*"[~^>=v ]*3[."]\n' >> "$PR/rules.tsv"
printf 'glob\t*.svelte\tchain2-canary\tmisc\thigh\tnode_modules/svelte/package.json~"version"[[:space:]]*:[[:space:]]*"2[."]||package.json~"svelte"[[:space:]]*:[[:space:]]*"[~^>=v ]*2[."]\n' >> "$PR/rules.tsv"
# CRLF-terminated rows: markered and markerless, both must behave as LF rows
printf 'glob\t*.rs\tcrlf-canary\tmisc\thigh\tpackage.json~"crlfdep"\r\n' >> "$PR/rules.tsv"
printf 'glob\t*.go\tcrlfplain-canary\tmisc\thigh\r\n' >> "$PR/rules.tsv"
# Uppercase directory glob: the casing rules.tsv actually ships for inertia
# (`**/resources/js/Pages/**`). Both casings of the real directory must fire.
printf 'glob\t**/Pages/**\tcase-canary\tmisc\thigh\n' >> "$PR/rules.tsv"

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

# ||-chain: workspace:* declared version is indecisive for the semver alt; the
# installed node_modules version must decide the pair
mkdir -p "$TMP/wscwd/node_modules/svelte"
echo '{"dependencies":{"svelte":"workspace:*"}}' > "$TMP/wscwd/package.json"
echo '{"name":"svelte","version":"3.59.2"}' > "$TMP/wscwd/node_modules/svelte/package.json"
out=$(route "$TMP/wscwd" App.svelte)
expect "chain: installed version fires the right major" "$out" 'chain3-canary' ''
expect "chain: installed version suppresses the wrong major" "$out" '' 'chain2-canary'

# ||-chain: declared range and installed major disagree (">=2.0.0" installed
# as 3.x) — the node_modules alternative is first, so it is decisive and the
# looser declared range never co-fires the wrong major
mkdir -p "$TMP/rangecwd/node_modules/svelte"
echo '{"dependencies":{"svelte":">=2.0.0"}}' > "$TMP/rangecwd/package.json"
echo '{"name":"svelte","version":"3.59.2"}' > "$TMP/rangecwd/node_modules/svelte/package.json"
out=$(route "$TMP/rangecwd" App.svelte)
expect "chain: installed major beats looser declared range" "$out" 'chain3-canary' ''
expect "chain: loose range does not co-fire the wrong major" "$out" '' 'chain2-canary'

# ||-chain: workspace:* with no node_modules — the declared-range alt cleanly
# fails and nothing else is decisive: both suppress (documented limitation,
# asserted so a behavior change is deliberate)
mkdir -p "$TMP/wsbare"
echo '{"dependencies":{"svelte":"workspace:*"}}' > "$TMP/wsbare/package.json"
out=$(route "$TMP/wsbare" App.svelte)
expect "chain: undetectable major suppresses v3 (documented)" "$out" '' 'chain3-canary'
expect "chain: undetectable major suppresses v2 (documented)" "$out" '' 'chain2-canary'

mkdir -p "$TMP/crlfcwd"
echo '{"dependencies":{"crlfdep":"1.0.0"}}' > "$TMP/crlfcwd/package.json"
out=$(route "$TMP/crlfcwd" main.rs)
expect "CRLF markered row fires on match" "$out" 'crlf-canary' ''
out=$(route "$TMP/emptycwd" main.go)
expect "CRLF markerless row fires (conf survives \\r strip)" "$out" 'crlfplain-canary' ''

# ---- the dedup ledger, on the payload the host actually sends -------------------
# `route()` above deliberately uses a fresh session id per call AND wipes .claude, so
# nothing in this harness ever exercised the `fired` ledger — the property at route.sh:118
# that the same skill is not re-nudged on a later edit. That mattered: route.sh reads
# `.transcript_path // .session_id`, transcript_path is an absolute PATH, and
# `fired-$session_id.json` named a nested file whose parents are never created. Every
# write failed, `fired` was empty on every call, and every edit re-injected directives the
# model already had — unmetered repeat tokens, with this harness green.
sticky() { # $1 cwd, $2 file — one fixed context, state PRESERVED between calls
  jq -n --arg fp "$2" --arg cwd "$1" \
    '{session_id:"11111111-2222-3333-4444-555555555555",
      transcript_path:"/Users/x/.claude/projects/-Users-x-proj/abcdef01-2345-6789.jsonl",
      cwd:$cwd,tool_input:{file_path:$fp}}' \
    | CLAUDE_PLUGIN_ROOT="$PR" bash "$ROUTE"
}
mkdir -p "$TMP/dedupcwd"; echo '{"dependencies":{"vue":"^3.2.4"}}' > "$TMP/dedupcwd/package.json"
first=$(sticky "$TMP/dedupcwd" App.vue)
expect "transcript_path: first edit nudges" "$first" 'vue3-canary' ''
second=$(sticky "$TMP/dedupcwd" App.vue)
expect "transcript_path: the same skill is not re-nudged on a later edit" "$second" '' 'vue3-canary'
if [ -n "$(find "$TMP/dedupcwd/.claude/skill-router" -name 'fired-*.json' -type f 2>/dev/null)" ]
then echo "PASS: transcript_path: the fired ledger actually landed on disk"
else echo "FAIL: transcript_path: the fired ledger actually landed on disk — none written"; rc=1; fi
rm -rf "$TMP/dedupcwd/.claude"

# ---- delivery channel: nudges must arrive as ONE PostToolUse additionalContext
# envelope. Plain stdout with exit 0 from a PostToolUse hook never reaches the
# executing model (channel doctrine: task-runner/hooks/scope.sh,
# comment-discipline/hooks/scan.sh) — these assertions exist so a rewrite back
# to bare printf fails CI instead of silently disconnecting the router.
out=$(route "$TMP/emptycwd" App.vue)
if printf '%s' "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null 2>&1; then
  echo "PASS: nudge output is a PostToolUse JSON envelope"
else
  echo "FAIL: nudge output is not a PostToolUse envelope — got: ${out:-<empty>}"; rc=1
fi
ctx=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
case "$ctx" in
  *vue3-canary*vue2-canary*|*vue2-canary*vue3-canary*) echo "PASS: both nudges ride one additionalContext payload" ;;
  *) echo "FAIL: additionalContext missing a nudge — got: ${ctx:-<empty>}"; rc=1 ;;
esac
envelopes=$(printf '%s\n' "$out" | grep -c 'hookSpecificOutput' || true)
if [ "$envelopes" -eq 1 ]; then
  echo "PASS: exactly one envelope per invocation"
else
  echo "FAIL: expected 1 envelope, got $envelopes"; rc=1
fi

out=$(echo '{}' | CLAUDE_PLUGIN_ROOT="$PR" bash "$ROUTE") && e=$? || e=$?
if [ "$e" -eq 0 ] && [ -z "$out" ]; then echo "PASS: empty tool_input exits 0 silently"; else echo "FAIL: fail-open on '{}' (exit=$e out=$out)"; rc=1; fi
out=$(printf '' | CLAUDE_PLUGIN_ROOT="$PR" bash "$ROUTE") && e=$? || e=$?
if [ "$e" -eq 0 ] && [ -z "$out" ]; then echo "PASS: empty stdin exits 0 silently"; else echo "FAIL: fail-open on empty stdin (exit=$e out=$out)"; rc=1; fi

# Case-insensitive directory match. `**/Pages/**` is inertia's ONLY routing row,
# and Laravel's current starter kits scaffold `resources/js/pages/` lowercase —
# under the case-SENSITIVE test this shipped with, that project routed nothing.
# Both assertions must hold: the lowercase path is the regression, the uppercase
# path proves the fix did not trade one casing for the other.
mkdir -p "$TMP/casecwd"
out=$(route "$TMP/casecwd" "resources/js/pages/Users/Show.vue")
expect "lowercase dir matches an uppercase **/Dir/** glob" "$out" 'case-canary' ''
out=$(route "$TMP/casecwd" "resources/js/Pages/Users/Show.vue")
expect "uppercase dir still matches" "$out" 'case-canary' ''
out=$(route "$TMP/casecwd" "src/components/Widget.vue")
expect "unrelated dir does not match" "$out" '' 'case-canary'

[ "$rc" -eq 0 ] && echo "All route-marker smoke tests passed."

exit "$rc"
