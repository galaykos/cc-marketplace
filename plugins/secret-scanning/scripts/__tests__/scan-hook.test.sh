#!/usr/bin/env bash
# scan-hook.test.sh — fixture cases for hooks/scan.sh: every deny pattern denies, placeholders and clean or out-of-scope text pass, the Bash
#   write path names its file, fail-open stays open, a missing or malformed hooks/patterns.tsv denies (run on a temp copy of the hook).
#   Secret shapes are assembled at runtime: the guard would deny a write of this file.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/scripts/__tests__/scan-hook.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/scan.sh"
pass=0; fail=0

AWS="AKIA""ABCDEFGHIJKLMNOP"
PKEY="-----BEGIN RSA PRIVATE ""KEY-----"
GH="ghp""_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
SLACK="xoxb""-1234567890-abcdef"
GOOG="AIza""SyA1234567890abcdefghijklmnopqrstuv"
STRIPE="sk_live""_abcdefghijklmnopqrstuvwx"
ASSIGNED="$(printf 'api_%s = "%s"' 'key' 'aVeryLongSecretValue1234567890abcd')"
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
deny "six name segments after the keyword" "$(printf 'SECRET_KEY_BASE_FOR_RAILS_PRODUCTION_%s=%s' 'APP' "$LONGVAL")"
allow "seven name segments after the last keyword (the stated bound)" Write \
  "$(printf 'SECRET_KEY_BASE_FOR_RAILS_PRODUCTION_APP_%s=%s' 'V2' "$LONGVAL")"

allow "clean content"   Write 'const x = 1; // nothing secret here'
allow "short value"     Write 'pw = "hunter2"'
allow "lowercased AKIA"  Write 'x = "akia""abcdefghijklmnop"'
allow "lowercased AIza"  Write 'g = "aiza""sya1234567890abcdefghijklmnopqrstuv"'
allow "camelCase prefix" Write 'tokenizerConfig = "aVeryLongConfigValue1234567890"'
allow "secretive prose"  Write 'const secretiveNote = "aVeryLongCommentValue123456"'
allow "non-write tool"  Glob  "$AWS"
allow "empty content"   Write ''

AWS_DOC="AKIA""IOSFODNN7EXAMPLE"                       # AWS's own documented example key
AWS_DOC2="AKIA""I44QH8DHBEXAMPLE"
allow "AWS doc key (EXAMPLE suffix)"     Write "aws_ref = \"$AWS_DOC\""
allow "second AWS doc key"               Write "k = \"$AWS_DOC2\""
allow ".env.example x-run"               Write "$(printf 'STRIPE_%s=sk_%s_%s' 'SECRET' 'test' 'xxxxxxxxxxxxxxxxxxxxxxxx')"
allow "changeme value"                   Write "$(printf 'API_%s=changeme_changeme_changeme_now' 'KEY')"
allow "your- value"                      Write "$(printf 'API_%s=your-api-key-goes-here-1234567890' 'KEY')"
allow "single repeated char"             Write "$(printf 'PASSWORD=%s' '00000000000000000000000000000000')"
allow "ghp_ of x's"                      Write "$(printf 'gh%s_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' 'p')"
deny  "EXAMPLE in the NAME only"         "$(printf 'EXAMPLE_%s = "%s"' 'TOKEN' "$LONGVAL")"
deny  "placeholder + real key together"  "a = \"$AWS_DOC\"; b = \"$AWS\""
deny  "base64 padding is not a name"     "$(printf 'PASSWORD=%s==' "$LONGVAL")"

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
allow "DSN with \${VAR} password"  Write "$(printf 'DATABASE_URL=postgres://admin:${DB_PASS}@db/app')"
allow "DSN with a Helm template"   Write 'url: postgres://u:{{.Values.db.pass}}@db/app'
allow "DSN with no password"       Write 'REDIS_URL=redis://localhost:6379/0'
allow "DSN with an empty password" Write 'DATABASE_URL=postgres://admin:@db/app'
allow "port then a mail query"     Write 'see https://host.example.com:8080/mail?to=a@b.com'
allow "changeme DSN"               Write 'DATABASE_URL=postgres://user:changeme@localhost/db'
allow "webhook of x-runs"          Write "$(printf 'https://hooks.slack.com/services/T00000000/B00000000/%s' 'xxxxxxxxxxxxxxxxxxxxxxxx')"
allow "ssh remote, not a DSN"      Write 'git clone git@github.com:org/repo.git'

out=$(printf 'not json' | bash "$HOOK"); rc=$?
if [[ $rc -eq 0 && -z "$out" ]]; then pass=$((pass+1));
else echo "FAIL fail-open: rc=$rc out=$out"; fail=$((fail+1)); fi

out=$(jq -cn --arg s "$AWS" '{tool_name:"Edit", tool_input:{file_path:"/tmp/x", old_string:"a", new_string:$s}}' | bash "$HOOK")
if grep -q '"permissionDecision":"deny"' <<<"$out"; then pass=$((pass+1));
else echo "FAIL edit-shape: expected deny, got: ${out:-<empty>}"; fail=$((fail+1)); fi

nb_run() { # nb_run <new_source> [edit_mode] -> hook stdout; the host requires new_source on a delete too, and ignores it there
  jq -cn --arg s "$1" --arg m "${2-}" \
    '{tool_name:"NotebookEdit", tool_input:({notebook_path:"/tmp/n.ipynb", cell_id:"c1", new_source:$s}
      + if $m == "" then {} else {edit_mode:$m} end)}' | bash "$HOOK"
}
nb_allow() { # nb_allow <name> <new_source> [edit_mode]
  local n=$1; shift
  out=$(nb_run "$@")
  if [[ -z "$out" ]]; then pass=$((pass+1));
  else echo "FAIL $n: expected silence, got: $out"; fail=$((fail+1)); fi
}
out=$(nb_run "key = '$AWS'")
if grep -q '"permissionDecision":"deny"' <<<"$out" && grep -qF '(file: /tmp/n.ipynb)' <<<"$out"; then pass=$((pass+1));
else echo "FAIL notebook cell, real AKIA: expected deny naming /tmp/n.ipynb, got: ${out:-<empty>}"; fail=$((fail+1)); fi
nb_allow "notebook cell, AWS doc key"          "key = '$AWS_DOC'"
nb_allow "notebook cell, no secret"            'import pandas as pd'
nb_allow "notebook cell delete repeating the old key"  "key = '$AWS'" delete
out=$(jq -cn --arg s "key = '$AWS'" '{tool_name:"Write", tool_input:{file_path:"/tmp/x.py", content:"print(1)", new_source:$s}}' | bash "$HOOK")
if [[ -z "$out" ]]; then pass=$((pass+1));
else echo "FAIL Write with a stray key-bearing new_source: expected silence, got: $out"; fail=$((fail+1)); fi
out=$(jq -cn --arg s "key = '$AWS'" '{tool_name:"Write", tool_input:{file_path:"/tmp/x.py", content:$s, new_source:["x"]}}' | bash "$HOOK")
if grep -q '"permissionDecision":"deny"' <<<"$out"; then pass=$((pass+1));
else echo "FAIL Write key beside an array new_source: expected deny, got: ${out:-<empty>}"; fail=$((fail+1)); fi

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
bash_deny  "heredoc | tee -a"                         "$(printf "cat <<'EOF' | tee -a deploy.env\nK=%s\nEOF" "$AWS")" deploy.env
bash_deny  "printf > file"                            "printf '%s\\n' '$GH' > token.txt" token.txt
bash_deny  "second heredoc names ITS file"            "$(printf "cat > a.txt <<'A'\nclean\nA\ncat > b.php <<'B'\nk = '%s'\nB" "$AWS")" b.php
bash_allow "heredoc to stdout only"                   "$(printf "cat <<'EOF'\n%s\nEOF" "$AWS")"
bash_allow "echo of a \$VAR into .env"                'echo "API_KEY=$API_KEY" >> .env'
if [ -z "$(find "$REPO" -name .claude 2>/dev/null)" ]; then pass=$((pass+1));
else echo "FAIL no state: a .claude/ dir appeared under $REPO"; fail=$((fail+1)); fi

PAT="$(dirname "$HOOK")/patterns.tsv"
PH=$(mktemp -d); trap 'rm -rf "$REPO" "$PH"' EXIT
cp "$HOOK" "$PH/scan.sh"
WRITE_CLEAN=$(jq -cn '{tool_name:"Write", tool_input:{file_path:"/tmp/x.txt", content:"const x = 1;"}}')
BASH_WRITE=$(jq -cn '{tool_name:"Bash", cwd:"/tmp", tool_input:{command:"echo hello > notes.txt"}}')
BASH_READ=$(jq -cn '{tool_name:"Bash", cwd:"/tmp", tool_input:{command:"ls -la && git status"}}')
pat_case() { # pat_case <name> deny|allow <payload> <reason text> [env...] — runs the hook copy in $PH; prints "ok <name>" on a pass
  local n=$1 want=$2 p=$3 x=$4 ok=0; shift 4
  out=$(printf '%s' "$p" | env "$@" bash "$PH/scan.sh")
  case $want in
    allow) [[ -z "$out" ]] && ok=1 ;;
    deny) grep -q '"permissionDecision":"deny"' <<<"$out" && grep -qF "$PH/patterns.tsv" <<<"$out" \
            && grep -qF "($x" <<<"$out" && grep -qF 'CC_SECRET_SCAN=off' <<<"$out" && ok=1 ;;
  esac
  if [[ $ok -eq 1 ]]; then pass=$((pass+1)); echo "ok $n";
  else echo "FAIL $n: expected $want naming $PH/patterns.tsv and \"$x\", got: ${out:-<empty>}"; fail=$((fail+1)); fi
}
pat_case "missing patterns file denies a clean Write" deny "$WRITE_CLEAN" "missing or unreadable"
pat_case "missing patterns file denies a Bash write"  deny "$BASH_WRITE"  "missing or unreadable"
pat_case "missing patterns file passes a Bash command that writes no file" allow "$BASH_READ" ""
pat_case "missing patterns file passes under CC_SECRET_SCAN=off" allow "$WRITE_CLEAN" "" CC_SECRET_SCAN=off
T=$'\t'; LAST=$(( $(wc -l < "$PAT") + 1 ))
for bad in "3 fields|has 3 fields|secret${T}x${T}-" "unknown kind|has kind|secrets${T}x${T}-${T}abc" \
           "unknown flag|has flags|secret${T}x${T}I${T}abc" "empty pattern|has an empty|secret${T}x${T}-${T}" \
           "dialect [[:class:]]|uses|secret${T}x${T}-${T}a[[:digit:]]b" "dialect [:class:] later in a bracket|uses|secret${T}x${T}-${T}[^@[:space:]]+" \
           "dialect [[.|uses|secret${T}x${T}-${T}a[[.-.]]b" "dialect [[=|uses|secret${T}x${T}-${T}a[[=e=]]b" \
           "dialect backreference|uses|secret${T}x${T}-${T}(ab)\\1" "dialect lookahead|uses|secret${T}x${T}-${T}ab(?=cd)" \
           "escape \\d|escapes a character|secret${T}x${T}-${T}xapp-\\d-[A-Z0-9]+-\\d+-[a-z0-9]+" \
           "trailing space|has a pattern that starts or ends with a space|secret${T}x${T}-${T}abc "; do
  IFS='|' read -r label frag row <<<"$bad"
  { cat "$PAT"; printf '%s\n' "$row"; } > "$PH/patterns.tsv"
  pat_case "malformed patterns file denies: $label" deny "$WRITE_CLEAN" "line $LAST $frag"
done
grep -v "^secret$T" "$PAT" > "$PH/patterns.tsv"
pat_case "malformed patterns file denies: no secret row" deny "$WRITE_CLEAN" "no secret row"
SL=$(grep -n "^secret${T}a Stripe" "$PAT" | cut -d: -f1)
sed "${SL}s/\\]{24,}\$/{24,}/" "$PAT" > "$PH/patterns.tsv"
pat_case "malformed patterns file denies: a row that compiles only when joined to the next" deny "$WRITE_CLEAN" \
  "line $SL has a pattern grep -E cannot compile"
sed 's/$/\r/' "$PAT" > "$PH/patterns.tsv"
pat_case "malformed patterns file denies: CRLF line endings" deny "$WRITE_CLEAN" "line 1 carries a carriage return"
PW=$(grep -n "^placeholder${T}a placeholder word" "$PAT" | cut -d: -f1)
sed "${PW}s/\$/|/" "$PAT" > "$PH/patterns.tsv"
pat_case "malformed patterns file denies: a placeholder row matching the empty string" deny "$WRITE_CLEAN" \
  "line $PW has a pattern that matches the empty string"
sed "${PW}s/\$/|.../" "$PAT" > "$PH/patterns.tsv"
pat_case "malformed patterns file denies: a placeholder row ending |..." deny "$WRITE_CLEAN" \
  "line $PW: a placeholder row matches a secret-shaped value"
sed "${PW}s/\$/|\\\\b/" "$PAT" > "$PH/patterns.tsv"
pat_case "malformed patterns file denies: a placeholder row ending |\\b" deny "$WRITE_CLEAN" "line $PW escapes a character"

echo "secret-scan hook tests: $pass passed, $fail failed"
exit $((fail > 0))
