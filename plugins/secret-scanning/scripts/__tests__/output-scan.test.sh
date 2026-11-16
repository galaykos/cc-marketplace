#!/usr/bin/env bash
# Harness for hooks/output-scan.sh: the PostToolUse flag that replaced output masking in 0.19.0. Load-bearing pairs: the
# same shape fires and stays silent on one changed fact (a placeholder, an existing directory, base64, the off switch),
# and no context line ever carries the value. Secret shapes are assembled at runtime: the write guard denies them literally.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/hooks/output-scan.sh"
[ -x "$HOOK" ] || { echo "FAIL: hooks/output-scan.sh not executable"; exit 1; }
command -v jq >/dev/null || { echo "FAIL: jq is required"; exit 1; }
unset CC_SECRET_OUTPUT_SCAN CLAUDE_PLUGIN_OPTION_CC_SECRET_OUTPUT_SCAN
# No dot in the path: an assigned value stops at one, and the absolute-path case must match whole.
TMP=$(mktemp -d "${TMPDIR:-/tmp}/outscanXXXXXX"); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()  { echo "PASS $1"; pass=$((pass+1)); }
bad() { echo "FAIL $1"; fail=$((fail+1)); }

AWS="AKIA""ABCDEFGHIJKLMNOP"
AWS_DOC="AKIA""IOSFODNN7EXAMPLE"
GH="ghp""_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
LONGVAL='aVeryLongSecretValue1234567890abcd'
SLASHVAL='Kq7Zt9Wm2Rp4/Lx8Vn3Bc6Qz1Yw5Tu0Xs'
PROJ="$TMP/proj"; mkdir -p "$PROJ/plugins/secret-scanning/hooks"

# payload <event> <tool> <jq expression for tool_response, or for error on a failure>
payload() {
  local key=tool_response; [ "$1" = PostToolUseFailure ] && key=error
  jq -cn --arg ev "$1" --arg t "$2" --arg cwd "$PROJ" --argjson v "$3" \
    '{session_id:"s1", transcript_path:"/tmp/t.jsonl", cwd:$cwd, hook_event_name:$ev, tool_name:$t, tool_input:{}} + {("'"$key"'"):$v}'
}
stdout_of() { jq -cn --arg s "$1" '{stdout:$s, stderr:"", interrupted:false}'; }
run() { out=$(payload "$@" | env "${ENVS[@]}" "$HOOK" 2>&1); }
ENVS=()

# fires <name> <labels> <event> <tool> <response> [<secret that must not appear>]
fires() {
  run "$3" "$4" "$5"
  local c; c=$(jq -r '.hookSpecificOutput.additionalContext // empty' <<<"$out" 2>/dev/null)
  local ev; ev=$(jq -r '.hookSpecificOutput.hookEventName // empty' <<<"$out" 2>/dev/null)
  if [ "$ev" = "$3" ] && grep -qF -- "holds what looks like $2. It reached you unmasked" <<<"$c" \
     && { [ -z "${6:-}" ] || ! grep -qF -- "$6" <<<"$out"; }; then ok "$1"; else bad "$1 (got: ${out:-<empty>})"; fi
}
silent() { run "$2" "$3" "$4"; [ -z "$out" ] && ok "$1" || bad "$1 (got: $out)"; }

fires  "a Bash stdout key is named by label, never by value" "an AWS access key ID" PostToolUse Bash "$(stdout_of "export KEY=$AWS")" "$AWS"
fires  "two rows name both labels in pattern-file order" "an AWS access key ID, a GitHub token" PostToolUse Bash \
       "$(stdout_of "token $GH
key $AWS")" "$GH"
silent "a clean output stays silent" PostToolUse Bash "$(stdout_of 'total 0')"
silent "a placeholder key stays silent" PostToolUse Bash "$(stdout_of "KEY=$AWS_DOC")"
fires  "a Read result's file content is scanned" "an assigned secret literal" PostToolUse Read \
       "$(jq -cn --arg c "$(printf 'API_%s=%s' KEY "$LONGVAL")" '{type:"text", file:{filePath:"/p/.env", content:$c}}')" "$LONGVAL"
fires  "an MCP text block holding JSON is read past its escaped quotes" "an assigned secret literal" PostToolUse mcp__x__get \
       "$(jq -cn --arg t "$(printf '{"api_%s": "%s"}' key "$LONGVAL")" '[{type:"text", text:$t}]')"
silent "base64 media bytes are left out" PostToolUse Read \
       "$(jq -cn --arg b "${AWS}AAAA" '{type:"image", file:{base64:$b, type:"image/png"}}')"
fires  "a failed call's error is scanned, under its own event" "a GitHub token" PostToolUseFailure Bash "$(jq -cn --arg e "fatal: auth $GH" '$e')" "$GH"

# The 2026-11-16 false positive: an echoed `secret-…: <path>` line read as an assigned secret.
PATHLINE="$(printf 'secret-%s: plugins/secret-scanning/hooks/patterns' scanning)"
silent "an echoed secret-name: <path> line whose directory exists stays silent" PostToolUse Bash "$(stdout_of "$PATHLINE")"
fires  "the same shape with a value whose directory does not exist still fires" "an assigned secret literal" PostToolUse Bash \
       "$(stdout_of "$(printf 'secret_%s: %s' key "$SLASHVAL")")" "$SLASHVAL"
fires  "a path-shaped value under a directory that is not there fires" "an assigned secret literal" PostToolUse Bash \
       "$(stdout_of "$(printf 'secret-%s: plugins/missing-dir/hooks/patterns' scanning)")"
silent "an absolute path value whose directory exists stays silent" PostToolUse Bash \
       "$(stdout_of "$(printf 'secret_%s=%s/plugins/secret-scanning/hooks/patterns' file "$PROJ")")"

ENVS=(CC_SECRET_OUTPUT_SCAN=off)
silent "CC_SECRET_OUTPUT_SCAN=off silences it" PostToolUse Bash "$(stdout_of "$AWS")"
ENVS=(CLAUDE_PLUGIN_OPTION_CC_SECRET_OUTPUT_SCAN=false)
silent "the /config option off silences it" PostToolUse Bash "$(stdout_of "$AWS")"
ENVS=(CLAUDE_PLUGIN_OPTION_CC_SECRET_OUTPUT_SCAN=false CC_SECRET_OUTPUT_SCAN=on)
fires  "the variable wins over the option" "an AWS access key ID" PostToolUse Bash "$(stdout_of "$AWS")"
ENVS=()

# Fail-open: a copy of the hooks with a malformed pattern file says nothing and exits 0.
mkdir -p "$TMP/broken/hooks"; cp "$ROOT/hooks/output-scan.sh" "$ROOT/hooks/patterns.sh" "$TMP/broken/hooks/"
printf 'secret\tonly three\tfields\n' > "$TMP/broken/hooks/patterns.tsv"
out=$(payload PostToolUse Bash "$(stdout_of "$AWS")" | "$TMP/broken/hooks/output-scan.sh" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok "a malformed patterns.tsv fails open, silent" || bad "malformed patterns.tsv (rc=$rc out=$out)"
out=$(printf 'not json' | "$HOOK" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && ok "a payload that is not JSON exits 0, silent" || bad "non-JSON payload (rc=$rc out=$out)"

echo "output-scan: $pass passed, $fail failed"
[ "$fail" = 0 ]
