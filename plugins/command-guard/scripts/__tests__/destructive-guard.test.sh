#!/usr/bin/env bash
# Tests plugins/command-guard/hooks/destructive-guard.sh.
#
# Picked up automatically by the repo's "Plugin author-time lint + harness tests"
# CI step, which globs plugins/*/scripts/__tests__/*.test.sh.
#
# Four sections, in the order the guard can fail a user:
#   1. CLASSIFICATION — a corpus of commands with the tier each must get. The
#      ALLOW rows are the important half: a guard that fires on `git commit -m
#      "remove the drop table step"` gets switched off within a day, and then it
#      guards nothing.
#   2. EVASION — the same destructive command wearing quotes, a wrapper, extra
#      whitespace, a heredoc. Each must land on the same verdict as the plain
#      form, or the deny is decorative.
#   3. HOOK PROTOCOL — real PreToolUse stdin: the JSON shape, the tool_name
#      filter, the allow-file branch on Write/Edit, the env modes.
#   4. FAIL-OPEN — no jq, malformed JSON, empty input. The guard must stay
#      silent and exit 0; a guard that breaks the session is uninstalled.
#
# The harness snapshots `git status --porcelain` before and after and asserts it
# is byte-identical: these tests drive a script whose entire subject matter is
# destroying things, so proving it touched nothing is part of the test.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GUARD="$here/../../hooks/destructive-guard.sh"
repo_root=$(cd "$here" && git rev-parse --show-toplevel 2>/dev/null || echo "")
BASH_BIN="$(command -v bash)"

[ -f "$GUARD" ] || { printf 'FAIL: guard not found at %s\n' "$GUARD"; exit 1; }
[ -x "$GUARD" ] || { printf 'FAIL: %s is not executable\n' "$GUARD"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0
git_snap() { [ -n "$repo_root" ] && ( cd "$repo_root" && git status --porcelain ) || true; }
SNAP_BEFORE=$(git_snap)

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

# tier of a command via CLI mode: exit 0 allow, 1 ask, 2 deny
tier_of() { "$BASH_BIN" "$GUARD" --check "$1" >/dev/null 2>&1; case $? in 0) echo allow ;; 1) echo ask ;; 2) echo deny ;; *) echo error ;; esac; }

expect() { # expected-tier command
  local want="$1" cmd="$2" got
  got=$(tier_of "$cmd")
  [ "$got" = "$want" ] && ok || bad "want $want, got $got" "$cmd"
}

# ---------------------------------------------------------------------------
# 1. CLASSIFICATION
# ---------------------------------------------------------------------------
printf '== classification: deny\n'
expect deny 'php artisan migrate:fresh'                         # the incident this plugin exists for
expect deny 'php artisan migrate:fresh --seed --force'
expect deny 'php artisan db:wipe'
expect deny 'php artisan migrate:refresh'
expect deny 'bin/rails db:drop'
expect deny 'rake db:reset'
expect deny 'python manage.py flush'
expect deny 'npx prisma migrate reset'
expect deny 'npx prisma db push --accept-data-loss'
expect deny 'supabase db reset'
expect deny 'alembic downgrade base'
expect deny 'php bin/console doctrine:schema:drop --force'
expect deny 'php bin/console doctrine:fixtures:load'
expect deny 'flyway clean'
expect deny 'mysql -u root -e "DROP DATABASE app"'
expect deny 'psql -c "truncate table users"'
expect deny 'dropdb production'
expect deny 'redis-cli FLUSHALL'
expect deny 'mongosh --eval "db.dropDatabase()"'
expect deny 'rm -rf /'
expect deny 'rm -rf ~'
expect deny 'rm -rf "$HOME"'
expect deny 'rm -rf .'
expect deny 'rm -rf /etc'
expect deny 'rm .env'
expect deny 'rm -f .env.local'
expect deny 'git clean -fdx'
expect deny 'git push --force origin main'
expect deny 'git push origin --delete feature'
# a leading + on the refspec is the same force push wearing git's other syntax
expect deny 'git push origin +main'
expect deny 'git push origin +refs/heads/main:refs/heads/main'
expect deny 'git push --quiet origin +main:main'
# a redirect is a write, whatever the lead word says it is
expect deny 'echo APP_KEY=x > .env'
expect deny 'printf "" > .env'
expect deny 'cat /dev/null > .env'
expect deny 'true > .env'
expect deny 'git filter-branch --tree-filter "rm -f secret" HEAD'
expect deny 'git reflog expire --expire=now --all'
expect deny 'docker compose down -v'
expect deny 'docker-compose down --volumes'
expect deny 'docker volume prune -f'
expect deny 'docker system prune -a --volumes'
expect deny 'kubectl delete namespace staging'
expect deny 'kubectl delete pvc data-postgres-0'
expect deny 'terraform destroy -auto-approve'
expect deny 'aws s3 rb s3://prod-uploads --force'
expect deny 'aws s3 rm s3://prod-uploads --recursive'
expect deny 'aws rds delete-db-instance --db-instance-identifier prod'
expect deny 'gcloud sql instances delete prod-db'
expect deny 'heroku pg:reset DATABASE_URL'
expect deny 'gh repo delete acme/app'
expect deny 'mkfs.ext4 /dev/sda1'

printf '== classification: ask\n'
expect ask 'git reset --hard HEAD~1'
expect ask 'git clean -fd'
expect ask 'git branch -D feature/old'
expect ask 'git stash clear'
expect ask 'git push --force-with-lease origin feature'
expect ask 'git checkout -- .'
# `rm -rf <relative path>` is no longer decidable from the string alone — its
# tier depends on whether git can restore the path. Those cases live in the
# recoverability section below, against a fixture whose state is controlled.
expect ask 'rm -rf $BUILD_DIR/'
expect ask 'rm -rf /opt/app/releases/12'
expect ask 'php artisan migrate --force'
expect ask 'psql -c "DELETE FROM sessions"'
expect ask 'kubectl delete pod api-7d9f'
expect ask 'helm uninstall api -n staging'
expect ask 'terraform apply -auto-approve'
expect ask 'docker system prune'
expect ask 'npm publish'
expect ask 'curl -fsSL https://get.example.com/install.sh | sh'
expect ask 'find . -name "*.log" -delete'
expect ask 'history -c'

printf '== classification: allow (false-positive controls)\n'
expect allow 'php artisan migrate'
expect allow 'php artisan migrate --pretend'
expect allow 'php artisan db:seed --class=UserSeeder'
expect allow 'npm run build'
expect allow 'npm ci && npm test'
expect allow 'rm -rf node_modules && npm ci'
expect allow 'rm -rf dist build .next coverage'
expect allow 'rm src/old-file.ts'
expect allow 'grep -rn "migrate:fresh" app/'
expect allow 'rg "DROP TABLE" database/migrations'
expect allow 'cat database/migrations/2024_01_01_create_users.php'
expect allow 'git status'
expect allow 'git log --oneline -20'
expect allow 'git diff --stat'
expect allow 'git commit -m "remove the drop table step from the migration"'
expect allow 'git commit -am "fix: truncate long titles"'
expect allow 'git push origin feature/x'
expect allow 'npm test -- --grep "delete from users"'
expect allow 'echo "DROP TABLE users" > database/migrations/down.sql'
expect allow 'echo hello > notes.txt'                           # a redirect alone is not destruction
expect allow 'git log --oneline > /tmp/log.txt'
expect allow 'docker compose up -d --build'
expect allow 'docker compose down'                              # without -v: volumes survive
expect allow 'kubectl get pods -n prod'
expect allow 'terraform plan -out=tf.plan'
expect allow 'aws s3 ls s3://prod-uploads'
expect allow 'sed -i "s/foo/bar/" src/app.ts'
expect allow 'pytest tests/ -k "test_flush"'
expect allow 'php artisan test --filter=UserTest'

# ---------------------------------------------------------------------------
# 1b. rm -rf RECOVERABILITY — the ask tier's biggest source of prompts. A path
# git can restore is not a loss; one with untracked or ignored content under it
# is. Driven against a real throwaway repo because the check shells out to git,
# and a mocked git would be testing the mock.
# ---------------------------------------------------------------------------
printf '== rm -rf recoverability\n'
FIX="$WS/repo"
mkdir -p "$FIX/src" "$FIX/keep"
printf 'x\n' > "$FIX/src/a.txt"; printf 'y\n' > "$FIX/keep/b.txt"
( cd "$FIX" \
  && git init -q . \
  && git -c user.email=t@t -c user.name=t add -A \
  && git -c user.email=t@t -c user.name=t commit -qm init ) >/dev/null 2>&1

# tier of a command as evaluated from inside $FIX
tier_in() { ( cd "$FIX" && "$BASH_BIN" "$GUARD" --check "$1" >/dev/null 2>&1; case $? in 0) echo allow ;; 1) echo ask ;; 2) echo deny ;; *) echo error ;; esac ); }
expect_in() { local want="$1" cmd="$2" got; got=$(tier_in "$cmd"); [ "$got" = "$want" ] && ok || bad "want $want, got $got (in fixture repo)" "$cmd"; }

if [ -d "$FIX/.git" ]; then
  expect_in allow 'rm -rf src'                  # tracked and clean: git restore returns it
  expect_in allow 'rm -rf ./keep'
  expect_in allow 'rm -rf never-existed'        # deleting nothing is not a loss
  expect_in ask   'rm -rf src/*'                # a glob's expansion is unknown
  expect_in ask   'rm -rf ../elsewhere'         # leaves the repo the check consults
  expect_in ask   'rm -rf /etc/nginx'           # absolute: never recoverable-by-git
  printf 'draft\n' > "$FIX/src/untracked.txt"
  expect_in ask   'rm -rf src'                  # untracked work under it: a real loss
  rm -f "$FIX/src/untracked.txt"
  printf 'secret\n' > "$FIX/keep/.env"
  printf '.env\n' > "$FIX/.gitignore"
  ( cd "$FIX" && git -c user.email=t@t -c user.name=t add .gitignore \
    && git -c user.email=t@t -c user.name=t commit -qm ignore ) >/dev/null 2>&1
  expect_in ask   'rm -rf keep'                 # IGNORED content is the .env case
  # storage/app/public: exists, tracked, but holds ignored uploads
  mkdir -p "$FIX/storage/app/public"
  printf 'kept\n' > "$FIX/storage/app/public/.gitkeep"
  printf 'upload\n' > "$FIX/storage/app/public/user-1.png"
  printf '.env\nstorage/app/public/*\n!storage/app/public/.gitkeep\n' > "$FIX/.gitignore"
  ( cd "$FIX" && git -c user.email=t@t -c user.name=t add -A \
    && git -c user.email=t@t -c user.name=t commit -qm storage ) >/dev/null 2>&1
  expect_in ask   'rm -rf ./storage/app/public'
  # cwd is not the rm's cwd once the command moves: never trust the check then
  expect_in ask   'cd /elsewhere && rm -rf src'
  expect_in ask   'cd sub; rm -rf src'
  # a deny must not be softened by any of this
  expect_in deny  'rm -rf /'
  expect_in deny  'cd /tmp && rm -rf /'
else
  bad "recoverability fixture" "could not create a git repo in $FIX"
fi

# ---------------------------------------------------------------------------
# 2. EVASION — same command, different clothes. Each must stay deny.
# ---------------------------------------------------------------------------
printf '== evasion\n'
expect deny 'php artisan "migrate:fresh"'
expect deny "php artisan mig'rate:fresh'"
expect deny 'php  artisan     migrate:fresh'
expect deny 'bash -c "php artisan migrate:fresh"'
expect deny 'eval "php artisan migrate:fresh"'
expect deny 'cd /var/www/app && php artisan migrate:fresh'
expect deny 'true; php artisan migrate:fresh'
expect deny 'docker compose exec -T app php artisan migrate:fresh'
expect deny 'echo "rm -rf /" | sh'                              # reader exemption is off under a pipe-to-shell
expect deny 'mysql -u root <<SQL
DROP TABLE users;
SQL'
# self-protection: the opt-out file is only an opt-out if the model cannot write it
expect deny 'echo "^php artisan" >> .claude/destructive-guard-allow'
expect deny 'sed -i "" "1i\\x" .claude/destructive-guard-allow'
expect allow 'cat .claude/destructive-guard-allow'              # reading it is fine
expect allow 'grep artisan .claude/destructive-guard-allow'

# ---------------------------------------------------------------------------
# 3. HOOK PROTOCOL
# ---------------------------------------------------------------------------
printf '== hook protocol\n'
hook() { # json [env-assignments...]  -> stdout
  local json="$1"; shift
  printf '%s' "$json" | env "$@" "$BASH_BIN" "$GUARD" 2>/dev/null
}
bash_json() { jq -cn --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }

out=$(hook "$(bash_json 'php artisan migrate:fresh')")
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "Bash deny: wrong decision" "$out"
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" = "PreToolUse" ] \
  && ok || bad "Bash deny: wrong hookEventName" "$out"
printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecisionReason | length > 80' >/dev/null \
  && ok || bad "deny reason too short to be actionable" "$out"
# the reason must tell the model not to rephrase, or the next turn is a retry
printf '%s' "$out" | grep -qi 'do not retry' \
  && ok || bad "deny reason lacks the no-retry instruction" "$out"

out=$(hook "$(bash_json 'git reset --hard')")
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "ask" ] \
  && ok || bad "Bash ask: wrong decision" "$out"

out=$(hook "$(bash_json 'npm run build')")
[ -z "$out" ] && ok || bad "allow must be silent" "$out"

# tool filter: a Read is not a command
out=$(hook '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/x/rm -rf /"}}')
[ -z "$out" ] && ok || bad "non-command tool must be ignored" "$out"

# MCP terminal executors are the same hole wearing a different tool name
out=$(hook '{"hook_event_name":"PreToolUse","tool_name":"mcp__phpstorm__execute_terminal_command","tool_input":{"command":"php artisan migrate:fresh"}}')
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "MCP terminal tool not gated" "$out"

# Write/Edit branch: the allow-file is the user's
out=$(hook '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/p/.claude/destructive-guard-allow","content":"x"}}')
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "Write to allow-file must be denied" "$out"
out=$(hook '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/p/src/app.ts","content":"rm -rf /"}}')
[ -z "$out" ] && ok || bad "ordinary Write must be untouched" "$out"

# env modes
out=$(hook "$(bash_json 'php artisan migrate:fresh')" CLAUDE_DESTRUCTIVE_GUARD=off)
[ -z "$out" ] && ok || bad "CLAUDE_DESTRUCTIVE_GUARD=off must disable the guard" "$out"
out=$(hook "$(bash_json 'php artisan migrate:fresh')" CLAUDE_DESTRUCTIVE_GUARD=ask)
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "ask" ] \
  && ok || bad "CLAUDE_DESTRUCTIVE_GUARD=ask must downgrade deny to ask" "$out"

# deny-only: hard stops stay, the ask tier goes quiet. The pairing is the test —
# asserting only the silence would pass on a guard that had stopped working.
out=$(hook "$(bash_json 'php artisan migrate:fresh')" CLAUDE_DESTRUCTIVE_GUARD=deny-only)
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "deny-only must keep denying" "$out"
out=$(hook "$(bash_json 'git reset --hard')" CLAUDE_DESTRUCTIVE_GUARD=deny-only)
[ -z "$out" ] && ok || bad "deny-only must suppress the ask tier" "$out"
out=$(hook "$(bash_json 'git reset --hard')" CLAUDE_DESTRUCTIVE_GUARD=DENYONLY)
[ -z "$out" ] && ok || bad "deny-only spelling/case variants must be accepted" "$out"
# --check reports the true tier regardless of mode: it is a classifier probe
CLAUDE_DESTRUCTIVE_GUARD=deny-only "$BASH_BIN" "$GUARD" --check 'git reset --hard' >/dev/null 2>&1
[ $? -eq 1 ] && ok || bad "--check must still report ask under deny-only" "git reset --hard"

# MCP SQL: the payload IS the statement, with no client name to sniff
sql_json() { jq -cn --arg q "$1" '{hook_event_name:"PreToolUse",tool_name:"mcp__phpstorm__execute_sql_query",tool_input:{query:$q}}'; }
out=$(hook "$(sql_json 'DROP DATABASE prod')")
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "bare SQL through an MCP SQL tool must be gated" "$out"
out=$(hook "$(sql_json 'TRUNCATE TABLE users')")
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "bare TRUNCATE through an MCP SQL tool must be gated" "$out"
out=$(hook "$(sql_json 'DELETE FROM users')")
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "ask" ] \
  && ok || bad "bare DELETE FROM through an MCP SQL tool must ask" "$out"
out=$(hook "$(sql_json 'SELECT count(*) FROM users')")
[ -z "$out" ] && ok || bad "a SELECT must stay silent" "$out"
# the sniffed path must not have regressed: prose is not SQL
out=$(hook "$(bash_json 'git commit -m "remove the drop table step"')")
[ -z "$out" ] && ok || bad "a commit message naming SQL must not be read as SQL" "$out"

# a command string cannot set the guard's own environment
out=$(hook "$(bash_json 'CLAUDE_DESTRUCTIVE_GUARD=off php artisan migrate:fresh')")
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "inline env assignment must not disable the guard" "$out"

# project allow-file releases a deny (and only for the pattern it names)
PROJ="$WS/proj"; mkdir -p "$PROJ/.claude"
printf '# user opt-out\nartisan migrate:fresh --env=testing\n' > "$PROJ/.claude/destructive-guard-allow"
out=$(hook "$(bash_json 'php artisan migrate:fresh --env=testing')" "CLAUDE_PROJECT_DIR=$PROJ" "HOME=$WS/nohome")
[ -z "$out" ] && ok || bad "allow-file entry must release the deny" "$out"
out=$(hook "$(bash_json 'php artisan migrate:fresh')" "CLAUDE_PROJECT_DIR=$PROJ" "HOME=$WS/nohome")
[ "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision')" = "deny" ] \
  && ok || bad "allow-file must not release commands it does not name" "$out"

# ---------------------------------------------------------------------------
# 4. FAIL-OPEN
# ---------------------------------------------------------------------------
printf '== fail-open\n'
NOJQ="$WS/nojq"; mkdir -p "$NOJQ"
for u in cat grep sed awk tr head cut env sh printf sort uniq; do
  p="$(command -v "$u" 2>/dev/null)" && ln -s "$p" "$NOJQ/$u" 2>/dev/null
done
if PATH="$NOJQ" command -v jq >/dev/null 2>&1; then
  bad "fail-open harness" "could not build a jq-free PATH"
else
  out=$(printf '%s' "$(bash_json 'php artisan migrate:fresh')" | PATH="$NOJQ" "$BASH_BIN" "$GUARD" 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ "$rc" -eq 0 ]; } && ok || bad "no jq: must be silent and exit 0" "rc=$rc out=$out"
fi
for junk in '' 'not json at all' '{"tool_name":' '{}' '{"tool_name":"Bash"}' '{"tool_name":"Bash","tool_input":{}}'; do
  out=$(printf '%s' "$junk" | "$BASH_BIN" "$GUARD" 2>/dev/null); rc=$?
  { [ -z "$out" ] && [ "$rc" -eq 0 ]; } && ok || bad "malformed input must fail open" "input=<$junk> rc=$rc out=$out"
done

# ---------------------------------------------------------------------------
# 5. NO SELF-EXEMPTION -- the guard must not carve a hole for its own CLI
# ---------------------------------------------------------------------------
# A self-exemption was added twice and reverted twice. The motivating problem is
# real and is now stated as a limitation in commands/check.md instead: this guard
# denies the exact invocation /command-guard:check tells the model to type,
# because that invocation carries the deny-tier target as an argument.
#
# Both attempts leaked. 0.2.0 matched the three tokens as substrings anywhere in
# the segment, and `bash -c PAYLOAD name arg...` runs PAYLOAD while demoting the
# appended magic words to $0/$1. 0.2.1 matched by argv POSITION, which closed
# that, and was still bypassed three ways: an exemption that `continue`s past
# classification skips the WHOLE segment, and a shell segment carries side
# effects the shell evaluates independently of argv -- command substitution,
# backticks, and redirection.
#
# These assertions pin every known vector as DENY. They pass with no exemption
# present; they FAIL against 0.2.0 and 0.2.1. If someone adds a third exemption,
# this section is what should stop it.
printf '== no self-exemption\n'

# The plain invocation the CLI documents: denied, and that IS the limitation.
expect deny "bash /x/hooks/destructive-guard.sh --check 'php artisan migrate:fresh'"
expect deny "sh destructive-guard.sh --check 'php artisan migrate:fresh'"
expect deny 'bash -c "php artisan migrate:fresh" hooks/destructive-guard.sh --check y'
expect deny 'sh -c "php artisan migrate:fresh" hooks/destructive-guard.sh --check y'
expect deny 'bash -c "php artisan migrate:fresh" /opt/hooks/destructive-guard.sh --check y'
expect deny 'eval "php artisan migrate:fresh" destructive-guard.sh --check y'

# Shell-evaluated side effects inside an otherwise exemption-shaped segment
# (bypassed 0.2.1). The payload runs before or beside the classifier that
# argv says is all that happens.
expect deny 'bash "/x/hooks/destructive-guard.sh" --check "$(php artisan migrate:fresh)"'
expect deny 'sh destructive-guard.sh --check `php artisan migrate:fresh`'
expect deny 'bash /x/hooks/destructive-guard.sh --check foo > /dev/sda'

# Controls: the same payloads with no exemption-shaped tail must also deny.
expect deny 'php artisan migrate:fresh'
expect deny 'bash -c "php artisan migrate:fresh"'

# HOOK MODE, not just CLI mode. Everything above drives `--check`, which reaches
# classify() directly. An exemption added in the HOOK path instead — a `case` on
# the raw command string before classify() is ever called — is invisible to all
# of it: a reviewer built exactly that (the 0.2.0 substring bug, relocated one
# layer up) and this section still passed clean while the hole was live. That is
# the same CLI-mode/hook-mode composition gap that let the original defect ship,
# reappearing in the tests written to close it. These drive the real PreToolUse
# entry point, so a third exemption is caught wherever it is placed.
for v in \
  "bash /x/hooks/destructive-guard.sh --check 'php artisan migrate:fresh'" \
  'bash -c "php artisan migrate:fresh" hooks/destructive-guard.sh --check y' \
  'bash "/x/hooks/destructive-guard.sh" --check "$(php artisan migrate:fresh)"' \
  "bash /x/hooks/destructive-guard.sh --check foo > /dev/sda"; do
  out=$(printf '%s' "$(bash_json "$v")" | "$BASH_BIN" "$GUARD" 2>/dev/null)
  d=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)
  [ "$d" = "deny" ] && ok || bad "hook mode must deny an exemption-shaped payload" "verdict=${d:-<silent>} cmd=$v"
done

# ---------------------------------------------------------------------------
SNAP_AFTER=$(git_snap)
[ "$SNAP_BEFORE" = "$SNAP_AFTER" ] && ok || bad "the guard mutated the working tree" "git status changed"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
