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
# UPPERCASE twins. Env-var names are uppercase by convention, so these are the
# COMMON real shapes for an assigned literal, not edge cases — and every one of
# them passed the guard until the rule was made case-insensitive. Lowercase-only
# coverage is what hid that: the rule denied, in the one casing anyone tested.
LONGVAL='aVeryLongSecretValue1234567890abcd'
UP_SECRET="$(printf 'SECRET=%s' "$LONGVAL")"
UP_APIKEY="$(printf 'API_%s=%s' 'KEY' "$LONGVAL")"
UP_TOKEN="$(printf 'TOKEN=%s' "$LONGVAL")"
UP_PASSWORD="$(printf 'PASSWORD=%s' "$LONGVAL")"
UP_MIDNAME="$(printf 'AWS_SECRET_ACCESS_%s=%s' 'KEY' "$LONGVAL")"
MIXED_CASE="$(printf 'Api%s: %s' 'Key' "$LONGVAL")"

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
deny "SECRET= (upper)"  "$UP_SECRET"
deny "API_KEY= (upper)" "$UP_APIKEY"
deny "TOKEN= (upper)"   "$UP_TOKEN"
deny "PASSWORD="        "$UP_PASSWORD"
deny "trigger mid-name" "$UP_MIDNAME"
deny "mixed case"       "$MIXED_CASE"

allow "clean content"   Write 'const x = 1; // nothing secret here'
allow "short value"     Write 'pw = "hunter2"'
# The -i applies to the generic rule ONLY; a lowercased provider prefix must still
# pass, or the loosening this fix introduces has leaked into the provider tier.
allow "lowercased AKIA"  Write 'x = "akia""abcdefghijklmnop"'
allow "lowercased AIza"  Write 'g = "aiza""sya1234567890abcdefghijklmnopqrstuv"'
# The separator tail must not swallow camelCase: a trigger word that merely PREFIXES
# a longer identifier is not an assignment of that secret. Guards the widening.
allow "camelCase prefix" Write 'tokenizerConfig = "aVeryLongConfigValue1234567890"'
allow "secretive prose"  Write 'const secretiveNote = "aVeryLongCommentValue123456"'
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
