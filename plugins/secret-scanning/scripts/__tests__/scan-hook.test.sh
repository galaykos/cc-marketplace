#!/usr/bin/env bash
# Fixture tests for hooks/scan.sh — the deny path of the marketplace's only
# secret guard finally gets a harness: every deny pattern proven to deny, clean
# and out-of-scope inputs proven to pass, fail-open proven to stay open.
#
# Trigger strings are ASSEMBLED AT RUNTIME (concatenation / printf) so this file
# never contains a secret-shaped literal — the guard denies shape-matching
# writes even in fixtures, by design, including a write of this very file.
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/scan.sh"
pass=0; fail=0

# Runtime-assembled shapes (split so no source literal matches any pattern).
AWS="AKIA""ABCDEFGHIJKLMNOP"
PKEY="-----BEGIN RSA PRIVATE ""KEY-----"
GH="ghp""_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
SLACK="xoxb""-1234567890-abcdef"
GOOG="AIza""SyA1234567890abcdefghijklmnopqrstuv"
STRIPE="sk_live""_abcdefghijklmnopqrstuvwx"
ASSIGNED="$(printf 'api_%s = "%s"' 'key' 'aVeryLongSecretValue1234567890abcd')"

run() { # run <tool> <content>  -> hook stdout
  jq -cn --arg t "$1" --arg c "$2" \
    '{tool_name:$t, tool_input:{file_path:"/tmp/x.txt", content:$c}}' | bash "$HOOK"
}

deny() { # deny <name> <content>
  out=$(run Write "$2")
  if grep -q '"permissionDecision":"deny"' <<<"$out"; then pass=$((pass+1));
  else echo "FAIL $1: expected deny, got: ${out:-<empty>}"; fail=$((fail+1)); fi
}
allow() { # allow <name> <tool> <content>
  out=$(run "$2" "$3")
  if [[ -z "$out" ]]; then pass=$((pass+1));
  else echo "FAIL $1: expected silence, got: $out"; fail=$((fail+1)); fi
}

deny "AWS key"          "aws_ref = \"$AWS\""
deny "private key"      "$PKEY"
deny "GitHub token"     "gh auth: $GH"
deny "Slack token"      "SLACK=$SLACK"
deny "Google key"       "g=$GOOG"
deny "Stripe live"      "$STRIPE"
deny "assigned literal" "$ASSIGNED"

allow "clean content"   Write 'const x = 1; // nothing secret here'
allow "short value"     Write 'pw = "hunter2"'
allow "non-write tool"  Bash  "$AWS"
allow "empty content"   Write ''

# Fail-open: malformed JSON must not deny (and must exit 0).
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then pass=$((pass+1));
else echo "FAIL fail-open: rc=$rc out=$out"; fail=$((fail+1)); fi

# Edit tool shape (new_string) must also be scanned.
out=$(jq -cn --arg s "$AWS" '{tool_name:"Edit", tool_input:{file_path:"/tmp/x", old_string:"a", new_string:$s}}' | bash "$HOOK")
if grep -q '"permissionDecision":"deny"' <<<"$out"; then pass=$((pass+1));
else echo "FAIL edit-shape: expected deny, got: ${out:-<empty>}"; fail=$((fail+1)); fi

echo "secret-scan hook tests: $pass passed, $fail failed"
exit $((fail > 0))
