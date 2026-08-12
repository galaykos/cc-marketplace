#!/usr/bin/env bash
# Fixture tests for hooks/write-scan.sh — each warn pattern proven to warn once,
# dedup proven, clean/off/malformed inputs proven silent.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/write-scan.sh"
export TMPDIR="$(mktemp -d)"; trap 'rm -rf "$TMPDIR"' EXIT
pass=0; fail=0
n=0

run() { # run <session> <tool> <content>
  jq -cn --arg s "$1" --arg t "$2" --arg c "$3" \
    '{tool_name:$t, session_id:$s, tool_input:{file_path:"/tmp/f.php", content:$c}}' | bash "$HOOK"
}

warns() { # warns <name> <content> <expect-slug>
  n=$((n+1)); out=$(run "s$n" Write "$2")
  if grep -q "$3" <<<"$out"; then pass=$((pass+1));
  else echo "FAIL $1: expected [$3], got: ${out:-<empty>}"; fail=$((fail+1)); fi
}
silent() { # silent <name> <session> <tool> <content>
  out=$(run "$2" "$3" "$4")
  if [[ -z "$out" ]]; then pass=$((pass+1));
  else echo "FAIL $1: expected silence, got: $out"; fail=$((fail+1)); fi
}

warns "empty guarded"      'protected $guarded = [];'                        "mass-assignment-open"
warns "blade unescaped"    '<div>{!! $user->bio !!}</div>'                   "blade-unescaped"
warns "vite secret"        'VITE_STRIPE_SECRET=sk_test_x'                    "vite-client-secret"
warns "whereRaw interp"    '->whereRaw("id = {$id}")'                        "raw-sql-interpolation"
warns "whereRaw concat"    "->whereRaw('id = ' . \$id)"                      "raw-sql-interpolation"
warns "raw html sink"      '<div dangerouslySetInnerHTML={{__html: bio}} />' "raw-html-sink"

# Dedup: same session + file + finding warns once.
out1=$(run dedup Write 'protected $guarded = [];')
out2=$(run dedup Write 'protected $guarded = [];')
if [[ -n "$out1" && -z "$out2" ]]; then pass=$((pass+1));
else echo "FAIL dedup: first='${out1:0:40}' second='${out2:0:40}'"; fail=$((fail+1)); fi

silent "clean file"      sc Write 'const a = 1;'
out=$(jq -cn --arg c 'protected $guarded = [];' \
  '{tool_name:"Write", session_id:"soff", tool_input:{file_path:"/tmp/f.php", content:$c}}' \
  | CC_SECURITY_SCAN=off bash "$HOOK")
if [[ -z "$out" ]]; then pass=$((pass+1)); else echo "FAIL off-switch: $out"; fail=$((fail+1)); fi
# Same payload with the switch ON must warn — proves the off test tested the switch.
out=$(jq -cn --arg c 'protected $guarded = [];' \
  '{tool_name:"Write", session_id:"son", tool_input:{file_path:"/tmp/f.php", content:$c}}' | bash "$HOOK")
if grep -q "mass-assignment-open" <<<"$out"; then pass=$((pass+1));
else echo "FAIL on-control: ${out:-<empty>}"; fail=$((fail+1)); fi
silent "non-write tool"  sn Bash  'protected $guarded = [];'
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then pass=$((pass+1));
else echo "FAIL fail-open: rc=$rc out=$out"; fail=$((fail+1)); fi

echo "write-scan tests: $pass passed, $fail failed"
exit $((fail > 0))
