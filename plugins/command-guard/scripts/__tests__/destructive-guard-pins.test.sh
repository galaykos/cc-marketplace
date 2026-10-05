#!/usr/bin/env bash
# destructive-guard-pins.test.sh — pins the paths of hooks/destructive-guard.sh's family helpers that destructive-guard.test.sh does not reach.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GUARD="$here/../../hooks/destructive-guard.sh"
BASH_BIN="$(command -v bash)"

[ -x "$GUARD" ] || { printf 'FAIL: %s is missing or not executable\n' "$GUARD"; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
unset CLAUDE_DESTRUCTIVE_GUARD CLAUDE_PLUGIN_OPTION_CLAUDE_DESTRUCTIVE_GUARD GUARD_SQL_CTX
export HOME="$WS/home" CLAUDE_PROJECT_DIR="$WS"
mkdir -p "$HOME"
pass=0; fail=0

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

check_out() { "$BASH_BIN" "$GUARD" --check "$1" 2>/dev/null; }

# check_is <label> <exit> <first line> <second-line prefix or ""> <command>
check_is() {
  local out rc l1 l2
  out=$(check_out "$5"); rc=$?
  l1=$(printf '%s\n' "$out" | sed -n 1p); l2=$(printf '%s\n' "$out" | sed -n 2p)
  if [ "$rc" = "$2" ] && [ "$l1" = "$3" ] && { [ -z "$4" ] || [ "${l2#"$4"}" != "$l2" ]; }; then ok
  else bad "$1" "rc=$rc out=$out"; fi
}

tool_json() { jq -cn --arg t "$1" --argjson i "$2" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:$i}'; }

decision() { # payload [env-assignments...] -> deny | ask | silent
  local json="$1" out; shift
  out=$(cd "$WS" && printf '%s' "$json" | env "$@" "$BASH_BIN" "$GUARD" 2>/dev/null)
  [ -n "$out" ] || { echo silent; return 0; }
  printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "unparsed"'
}

decision_is() { # label want payload [env...]
  local label="$1" want="$2" got; shift 2
  got=$(decision "$@")
  [ "$got" = "$want" ] && ok || bad "$label" "want $want, got $got"
}

ALLOW_FILE=/p/.claude/destructive-guard-allow

printf '== strip_git_global_options\n'
check_is 'git --no-pager and a spaced --work-tree are stripped before the table' 1 \
  'ASK    git reset --hard ' '' 'git --no-pager --work-tree /x reset --hard'
check_is 'an unknown git global option stays, so the table never sees the subcommand' 0 \
  'ALLOW git --no-such-option reset --hard' '' 'git --no-such-option reset --hard'
for o in -p -P --paginate --no-replace-objects --no-lazy-fetch --no-advice --glob-pathspecs --noglob-pathspecs \
  --icase-pathspecs --exec-path=/x --config-env=core.pager=X '--config-env core.pager=X' --attr-source=HEAD \
  '--attr-source HEAD' --super-prefix=x/ '--shallow-file x' --shallow-file=x; do
  check_is "git $o is stripped: the force push behind it denies" 2 'DENY   git push --force ' '' "git $o push --force"
done
for c in 'git -P log' 'git -p status' 'git --no-pager log' 'git -c core.pager=less log' 'git -P clean -n'; do
  check_is "a stripped global option leaves a read a read: $c" 0 "ALLOW $c" '' "$c"
done
check_is 'an option added since 5c8ea5b1 is stripped only where git leads: prose in a gh title stays a read' 0 \
  'ALLOW gh pr create --title "fix git -P push --force docs"' '' 'gh pr create --title "fix git -P push --force docs"'
check_is 'git led by sudo is still git: sudo git -P push --force denies' 2 'DENY   sudo git push --force ' '' 'sudo git -P push --force'
check_is 'git led by env is still git: env git -P push --force denies' 2 'DENY   env git push --force ' '' 'env git -P push --force'
check_is 'the 5c8ea5b1 options are stripped inside another command too: bash -c "git -C /x push --force" denies' 2 \
  'DENY   bash -c git push --force ' '' 'bash -c "git -C /x push --force"'

printf '== lead_word: env\n'
check_is 'env is a wrapper: env rm -rf / denies as rm -rf / does' 2 'DENY   env rm -rf / ' '' 'env rm -rf /'
check_is 'env -i is a wrapper: terraform destroy behind it denies' 2 \
  'DENY   env -i terraform destroy ' '' 'env -i terraform destroy'
check_is 'env is a wrapper: artisan migrate:fresh behind it denies' 2 \
  'DENY   env php artisan migrate:fresh ' '' 'env php artisan migrate:fresh'
check_is 'env by path is a wrapper too' 2 'DENY   /usr/bin/env rm -rf / ' '' '/usr/bin/env rm -rf /'
for c in 'env' 'env | grep PATH' 'env FOO=1 npm test' 'env -i PATH=/usr/bin ls' 'env GIT_PAGER=cat git log' \
  'env -u FOO grep "rm -rf /" f' 'env -C /tmp grep "rm -rf /" f' 'env -P /usr/bin grep "rm -rf /" f' \
  "env -S 'grep \"rm -rf /\" f'" '/usr/bin/env grep "rm -rf /" f' 'env -a foo grep "rm -rf /" f' \
  'env --argv0 foo grep "rm -rf /" f'; do
  check_is "env and its option values are skipped, so the reader behind stays a read: $c" 0 "ALLOW $c" '' "$c"
done
check_is 'env -a takes a value: the rm behind it is judged' 2 'DENY   env -a cat rm -rf / ' '' 'env -a cat rm -rf /'

printf '== git clean dry run\n'
check_is 'a -n that is -e'"'"'s argument is no dry run: git clean -fdx -e -n denies' 2 \
  'DENY   git clean -fdx -e -n ' '' 'git clean -fdx -e -n'
check_is 'a -n attached to -e is its argument: git clean -fdx -en denies' 2 \
  'DENY   git clean -fdx -en ' '' 'git clean -fdx -en'
check_is 'a cluster ending in e takes the next word: git clean -fde -n asks' 1 \
  'ASK    git clean -fde -n ' '' 'git clean -fde -n'
check_is 'the word after --exclude is its argument: git clean -fd --exclude -n asks' 1 \
  'ASK    git clean -fd --exclude -n ' '' 'git clean -fd --exclude -n'
for c in 'git clean -n -e foo' 'git clean -nfd' 'git clean --dry-run -e node_modules' 'git clean -fne build' \
  'git clean -e foo -n'; do
  check_is "a real -n or --dry-run stays a dry run: $c" 0 "ALLOW $c" '' "$c"
done
check_is 'a -n after -- is a path: git clean -f -- -n asks' 1 'ASK    git clean -f -- -n ' '' 'git clean -f -- -n'
for c in 'git clean -n -- foo' 'sudo -- git clean -n' 'git clean -n --exclude=foo' 'git clean --no-dry-run -n'; do
  check_is "a -- before the -n, or before git, an --exclude= word, or an earlier --no-dry-run leaves the dry run: $c" 0 "ALLOW $c" '' "$c"
done
for c in 'git clean -fdx --dry' 'git clean -fdx --d' 'git clean -fdx --dry-run' 'git clean -fdx -n --no-'; do
  check_is "a --dry-run abbreviation is a dry run, and an ambiguous --no- cancels nothing: $c" 0 "ALLOW $c" '' "$c"
done
for c in 'git clean -fdx --exc -n' 'git clean -fdx -n --no-dry-run' 'git clean -fdx -n --no-dry' 'git clean -fdx -n --no-d'; do
  check_is "an --exc abbreviation takes the -n, and a later --no-dry-run cancels it: $c" 2 "DENY   $c " '' "$c"
done
check_is 'flags before git clean are not its: sudo -n git clean -fd asks' 1 'ASK    sudo -n git clean -fd ' '' 'sudo -n git clean -fd'
check_is 'flags before git clean are not its: sudo -n git clean -fdx denies' 2 'DENY   sudo -n git clean -fdx ' '' 'sudo -n git clean -fdx'

printf '== the git clean -x row\n'
for c in 'git clean -fdx' 'git clean -f -x' 'git clean -xdf' 'git clean --force -x'; do
  check_is "a short-flag cluster holding x denies: $c" 2 "DENY   $c " '' "$c"
done
check_is 'a short-flag cluster holding X denies, matched lowercased: git clean -fX' 2 'DENY   git clean -fx ' '' 'git clean -fX'
check_is 'the x in --exclude is no -x: git clean --exclude=foo -f asks' 1 \
  'ASK    git clean --exclude=foo -f ' '' 'git clean --exclude=foo -f'
check_is 'an x after e in a cluster is -e'"'"'s pattern: git clean -fdex asks' 1 'ASK    git clean -fdex ' '' 'git clean -fdex'
check_is 'an -x after an -e pattern and another word is a flag: git clean -f -e foo -x denies' 2 \
  'DENY   git clean -f -e foo -x ' '' 'git clean -f -e foo -x'
for c in 'git clean -f --exclude=foo -x' 'git clean -f -e node -x'; do
  check_is "an attached --exclude= value or a pattern ending in e leaves the -x after it a flag: $c" 2 "DENY   $c " '' "$c"
done
check_is 'an -x after -- is a path, wherever the -- sits: git clean -f -- foo -x asks' 1 \
  'ASK    git clean -f -- foo -x ' '' 'git clean -f -- foo -x'
for c in 'git clean -f -e foo' 'git clean -f --exclude foo' 'git clean -f -e -x' 'git clean -f -- -x' 'git clean -f --exc -x'; do
  check_is "an -e pattern or a path shaped like -x is no -x: $c" 1 "ASK    $c " '' "$c"
done

printf '== lead_word: wrapper option values\n'
for o in '-u bob' '-g x' '-h x' '-p x' '-C 3' '-D /x' '-r x' '-t x' '-U x' '-T 5' '-Eu bob' '--user bob' \
  '--group x' '--host x' '--prompt x' '--chdir /x'; do
  check_is "sudo $o: the value is skipped, so the reader behind stays a read" 0 \
    "ALLOW sudo $o grep \"rm -rf /\" f" '' "sudo $o grep \"rm -rf /\" f"
done
for c in 'env sudo -u bob' 'doas -u bob' 'doas -C x' 'doas -a x' 'nice -n 10' 'env nice -n 10' 'nice --adjustment 5' 'ionice -c 3' \
  'ionice -n 7' 'ionice -p 1' 'time -f %e' 'time -o out.txt' 'exec -a x'; do
  check_is "$c: the value is skipped, so the reader behind stays a read" 0 \
    "ALLOW $c grep \"rm -rf /\" f" '' "$c grep \"rm -rf /\" f"
done
for c in 'ionice -c 3 cat f' 'sudo -ubob grep "rm -rf /" f' 'sudo -uroot grep "rm -rf /" f' 'sudo --user=bob grep "rm -rf /" f' \
  'sudo -E grep "rm -rf /" f' 'nice --adjustment=5 grep "rm -rf /" f' 'ionice -t grep "rm -rf /" f'; do
  check_is "a glued value or a value-less flag skips nothing: $c" 0 "ALLOW $c" '' "$c"
done
for c in 'sudo -u bob rm -rf /' 'nice -n 10 rm -rf /' 'env sudo -u bob rm -rf /' 'sudo rm -rf /' \
  'doas -u bob rm -rf /' 'sudo -u rm -rf /' 'doas -a cat rm -rf /'; do
  check_is "the command behind a wrapper value is still judged: $c" 2 "DENY   $c " '' "$c"
done

printf '== match_rule_table\n'
check_is 'an uppercase rule matches the case-preserved segment: git branch -D asks' 1 \
  'ASK    git branch -D feature/old ' '' 'git branch -D feature/old'
check_is 'an uppercase rule is case-sensitive: git branch -d is allowed' 0 \
  'ALLOW git branch -d feature/old' '' 'git branch -d feature/old'
check_is 'a lowercase rule reports the lowercased segment' 2 \
  'DENY   php artisan migrate:fresh ' '' 'php artisan MIGRATE:FRESH'
check_is 'an ask in an earlier segment does not stop the scan: a later rails db:drop still denies' 2 \
  'DENY   rails db:drop ' '' 'git reset --hard && rails db:drop'

printf '== check_cli\n'
check_is '--check prints ALLOW and the command, exit 0' 0 'ALLOW npm run build' '' 'npm run build'
check_is '--check prints ASK, the match and an indented reason, exit 1' 1 \
  'ASK    git reset --hard ' '      command-guard: this command discards every uncommitted change' 'git reset --hard'
check_is '--check prints DENY, the match and an indented reason, exit 2' 2 \
  'DENY   php artisan migrate:fresh ' '      BLOCKED by command-guard — this command drops every table' 'php artisan migrate:fresh'

printf '== guard_file_write\n'
decision_is 'MultiEdit on the allow-file is denied' deny \
  "$(tool_json MultiEdit "$(jq -cn --arg f "$ALLOW_FILE" '{file_path:$f}')")"
decision_is 'an apply_patch whose patch key names the allow-file is denied' deny \
  "$(tool_json mcp__x__apply_patch '{"patch":"*** Update File: .claude/destructive-guard-allow\n+x"}')"
decision_is 'the allow-file Write deny holds under CLAUDE_DESTRUCTIVE_GUARD=ask' deny \
  "$(tool_json Write "$(jq -cn --arg f "$ALLOW_FILE" '{file_path:$f,content:"x"}')")" CLAUDE_DESTRUCTIVE_GUARD=ask
printf 'APP_KEY=base64:abc\n' > "$WS/.env"
decision_is 'a Write over an existing .env still asks under CLAUDE_DESTRUCTIVE_GUARD=ask' ask \
  "$(tool_json Write '{"file_path":".env","content":"A=1"}')" CLAUDE_DESTRUCTIVE_GUARD=ask
rm -f "$WS/.env"

printf '== guard_command\n'
decision_is 'the cmd field of an MCP run_command tool is classified' deny \
  "$(tool_json mcp__x__run_command '{"cmd":"php artisan migrate:fresh"}')"
decision_is 'the script field is classified beside the command field' deny \
  "$(tool_json Bash '{"command":"echo ok","script":"php artisan migrate:fresh"}')"
decision_is 'an execute_sql_query tool is SQL by its name, with no query or sql field' deny \
  "$(tool_json mcp__db__execute_sql_query '{"script":"DROP DATABASE prod"}')"
decision_is 'an sql field makes a run_command payload SQL' deny \
  "$(tool_json mcp__x__run_command '{"sql":"DROP TABLE users"}')"
decision_is 'a shell_command tool is guarded' deny \
  "$(tool_json mcp__x__shell_command '{"command":"php artisan migrate:fresh"}')"
decision_is 'a run_in_terminal tool is guarded' deny \
  "$(tool_json mcp__x__run_in_terminal '{"command":"php artisan migrate:fresh"}')"
decision_is 'GUARD_SQL_CTX in the hook environment does not turn SQL rules on' silent \
  "$(tool_json Bash '{"command":"DROP TABLE users"}')" GUARD_SQL_CTX=1

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
