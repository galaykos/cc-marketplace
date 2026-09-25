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
allow "non-write tool"  Glob  "$AWS"
allow "empty content"   Write ''

# 0.5.0 PLACEHOLDER EXEMPTION. A matched VALUE that announces itself as fake is
# released; the deny is unbounded and has no allow-file, so before this the AWS
# documentation key and an .env.example line were refused on every retry.
AWS_DOC="AKIA""IOSFODNN7EXAMPLE"                       # AWS's own documented example key
AWS_DOC2="AKIA""I44QH8DHBEXAMPLE"
allow "AWS doc key (EXAMPLE suffix)"     Write "aws_ref = \"$AWS_DOC\""
allow "second AWS doc key"               Write "k = \"$AWS_DOC2\""
allow ".env.example x-run"               Write "$(printf 'STRIPE_%s=sk_%s_%s' 'SECRET' 'test' 'xxxxxxxxxxxxxxxxxxxxxxxx')"
allow "changeme value"                   Write "$(printf 'API_%s=changeme_changeme_changeme_now' 'KEY')"
allow "your- value"                      Write "$(printf 'API_%s=your-api-key-goes-here-1234567890' 'KEY')"
allow "single repeated char"             Write "$(printf 'PASSWORD=%s' '00000000000000000000000000000000')"
allow "ghp_ of x's"                      Write "$(printf 'gh%s_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' 'p')"
# The exemption reads the VALUE, never the name, and every match is checked.
deny  "EXAMPLE in the NAME only"         "$(printf 'EXAMPLE_%s = "%s"' 'TOKEN' "$LONGVAL")"
deny  "placeholder + real key together"  "a = \"$AWS_DOC\"; b = \"$AWS\""
deny  "base64 padding is not a name"     "$(printf 'PASSWORD=%s==' "$LONGVAL")"

# 0.8.0 URL-EMBEDDED CREDENTIALS. A DSN in a .env, tfvars, compose or Helm values file
# is neither a provider key nor an `assigned secret literal` — the trigger word is the
# scheme, not a `password=` operator — so every shape below was written to disk silently.
# Assembled at runtime, same reason as every other trigger in this file.
DSN_PG="$(printf 'DATABASE_URL=postgres://admin:%s@db.internal:5432/app' 'Sup3rS3cretVal')"
DSN_MONGO="$(printf 'MONGO=mongodb+srv://svc:%s@cluster0.mongodb.net/db' 'Hunter2Hunter2')"
DSN_AMQP="$(printf 'AMQP_URL: amqps://rabbit:%s@mq:5671/' 'Pr0dRabbitPass')"
DSN_MYSQL="$(printf 'db_url = "mysql://root:%s@10.0.0.4/prod"' 'T3rraf0rmPass')"
DSN_HTTPS="$(printf 'FEED=https://svc:%s@api.example.com/feed' 'Gk39dkLwq2x')"
HOOK_URL="$(printf 'SLACK=https://hooks.slack.com/services/T01ABCD2EF/B09XYZ12345/%s' 'abcdefghijklmnopqrstuvwx')"
deny "postgres DSN"        "$DSN_PG"
deny "mongodb+srv DSN"     "$DSN_MONGO"
deny "amqps DSN in compose" "$DSN_AMQP"
deny "mysql DSN in tfvars" "$DSN_MYSQL"
deny "https basic-auth URL" "$DSN_HTTPS"
deny "Slack webhook URL"   "$HOOK_URL"
# The shapes that must stay allowed, or the rule denies correct code on every retry.
# The runtime-substitution one is the CORRECT way to write a DSN; a deny there has no
# satisfiable fix. `/?#` exclusion is what keeps an ordinary URL with a mailto-ish query
# out; the placeholder escape still applies to the whole match.
allow "DSN with \${VAR} password"  Write "$(printf 'DATABASE_URL=postgres://admin:${DB_PASS}@db/app')"
allow "DSN with a Helm template"   Write 'url: postgres://u:{{.Values.db.pass}}@db/app'
allow "DSN with no password"       Write 'REDIS_URL=redis://localhost:6379/0'
allow "DSN with an empty password" Write 'DATABASE_URL=postgres://admin:@db/app'
allow "port then a mail query"     Write 'see https://host.example.com:8080/mail?to=a@b.com'
allow "changeme DSN"               Write 'DATABASE_URL=postgres://user:changeme@localhost/db'
allow "webhook of x-runs"          Write "$(printf 'https://hooks.slack.com/services/T00000000/B00000000/%s' 'xxxxxxxxxxxxxxxxxxxxxxxx')"
allow "ssh remote, not a DSN"      Write 'git clone git@github.com:org/repo.git'

# Fail-open: malformed JSON must not deny (and must exit 0).
out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then pass=$((pass+1));
else echo "FAIL fail-open: rc=$rc out=$out"; fail=$((fail+1)); fi

# Edit tool shape (new_string) must also be scanned.
out=$(jq -cn --arg s "$AWS" '{tool_name:"Edit", tool_input:{file_path:"/tmp/x", old_string:"a", new_string:$s}}' | bash "$HOOK")
if grep -q '"permissionDecision":"deny"' <<<"$out"; then pass=$((pass+1));
else echo "FAIL edit-shape: expected deny, got: ${out:-<empty>}"; fail=$((fail+1)); fi

# 0.9.0 BASH WRITES. The host steers file writes through Bash heredocs; in the measured
# session 233 of 238 main-thread writes went that way and never met this guard
# (rationale/2026-09-25-session-plugin-usage-review.md, finding 1). The Bash path scans
# heredoc bodies and echo/printf arguments whose pipeline writes a file, with the Write
# path's patterns and placeholder exemption. Payloads carry a real `cwd` inside a temp
# git repo so the last case can prove the hook leaves no state behind.
unset CLAUDE_PROJECT_DIR
REPO=$(mktemp -d); trap 'rm -rf "$REPO"' EXIT
git -C "$REPO" init -q 2>/dev/null; mkdir -p "$REPO/app/sub"
bash_run() { # bash_run <command> [env...] -> hook stdout
  local c=$1; shift
  jq -cn --arg c "$c" --arg d "$REPO/app/sub" \
    '{tool_name:"Bash", cwd:$d, tool_input:{command:$c}}' | env "$@" bash "$HOOK"
}
bash_deny() { # bash_deny <name> <command> [expected file]
  out=$(bash_run "$2")
  if grep -q '"permissionDecision":"deny"' <<<"$out" && grep -qF "(file: ${3:-})" <<<"$out" \
     && grep -qF 'CC_SECRET_SCAN=off' <<<"$out"; then pass=$((pass+1));
  else echo "FAIL $1: expected deny naming ${3:-a file} and the off switch, got: ${out:-<empty>}"; fail=$((fail+1)); fi
}
bash_allow() { # bash_allow <name> <command> [env...]
  local n=$1; shift
  out=$(bash_run "$@")
  if [[ -z "$out" ]]; then pass=$((pass+1));
  else echo "FAIL $n: expected silence, got: $out"; fail=$((fail+1)); fi
}
php_heredoc() { # php_heredoc <aws key> -> a `cat > config/aws.php <<'PHP'` command
  printf "cat > config/aws.php <<'PHP'\n<?php\nreturn [\n    'key' => '%s',\n    'region' => env('AWS_REGION'),\n];\nPHP" "$1"
}
STRIPE_REAL="sk_live""_$LONGVAL"
STRIPE_FAKE="sk_live""_xxxxxxxxxxxxxxxxxxxxxxxx"
bash_deny  "heredoc cat > config/aws.php, real AKIA"  "$(php_heredoc "$AWS")" config/aws.php
bash_allow "heredoc cat > config/aws.php, doc key"    "$(php_heredoc "$AWS_DOC")"
bash_deny  "echo >> .env.example, real sk_live"       "echo \"STRIPE_SECRET=$STRIPE_REAL\" >> .env.example" .env.example
bash_allow "echo >> .env.example, placeholder"        "echo \"STRIPE_SECRET=$STRIPE_FAKE\" >> .env.example"
bash_allow "curl -H bearer, no write target"          "curl -H \"Authorization: Bearer $GH\" https://x"
bash_allow "PHP -> and => in a body, no secret"       "$(printf "cat > app/Svc.php <<'PHP'\n<?php\n\$this->client->post(\$url, ['json' => \$body]);\n\$map = fn(\$x) => \$x->id;\nPHP")"
bash_allow "CC_SECRET_SCAN=off"                       "$(php_heredoc "$AWS")" CC_SECRET_SCAN=off
# Routes the extractor claims beyond the brief's list, each pinned once.
bash_deny  "heredoc | tee -a"                         "$(printf "cat <<'EOF' | tee -a deploy.env\nK=%s\nEOF" "$AWS")" deploy.env
bash_deny  "printf > file"                            "printf '%s\\n' '$GH' > token.txt" token.txt
bash_deny  "second heredoc names ITS file"            "$(printf "cat > a.txt <<'A'\nclean\nA\ncat > b.php <<'B'\nk = '%s'\nB" "$AWS")" b.php
bash_allow "heredoc to stdout only"                   "$(printf "cat <<'EOF'\n%s\nEOF" "$AWS")"
bash_allow "echo of a \$VAR into .env"                'echo "API_KEY=$API_KEY" >> .env'
# The guard writes no state: nothing may appear under the payload's cwd or the repo root.
if [ -z "$(find "$REPO" -name .claude 2>/dev/null)" ]; then pass=$((pass+1));
else echo "FAIL no state: a .claude/ dir appeared under $REPO"; fail=$((fail+1)); fi

echo "secret-scan hook tests: $pass passed, $fail failed"
exit $((fail > 0))
