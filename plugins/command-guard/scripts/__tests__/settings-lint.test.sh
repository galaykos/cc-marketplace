#!/usr/bin/env bash
# settings-lint.test.sh — asserts scripts/settings-lint.sh flags each risky setting with its file and key path, stays silent on the nearest
#   safe one, keeps its exit codes, writes nothing, that its samples are ask-tier in destructive-guard.sh and its switches are in the root README.
# Why, limits, history: rationale/derivations/plugin-command-guard.md § plugins/command-guard/scripts/__tests__/settings-lint.test.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
LINT="$here/../settings-lint.sh"
GUARD="$here/../../hooks/destructive-guard.sh"
README="$here/../../../../README.md"
BASH_BIN="$(command -v bash)"
command -v jq >/dev/null 2>&1 || { printf 'SKIP: jq not installed\n'; exit 0; }
[ -x "$LINT" ] || { printf 'FAIL: %s is missing or not executable\n' "$LINT"; exit 1; }
unset CLAUDE_CONFIG_DIR CLAUDE_PROJECT_DIR
pass=0; fail=0
ok()  { pass=$((pass + 1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
P="$T/proj"; H="$T/home"; mkdir -p "$P/.claude" "$H/.claude"

lint() { HOME="$H" "$BASH_BIN" "$LINT" --project "$P" "$@" 2>/dev/null; }
has()  { case "$out" in *"$1"*) ok "$2" ;; *) bad "$2" "no line containing: $1" ;; esac; }
lacks() { case "$out" in *"$1"*) bad "$2" "unexpected line containing: $1" ;; *) ok "$2" ;; esac; }
lacks_at() { printf '%s\n' "$out" | awk -v s="$1" 'index($0, s) == 1 { f = 1 } END { exit !f }' && bad "$2" "unexpected line starting: $1" || ok "$2"; }

cat > "$P/.claude/settings.json" <<'EOF'
{"permissions":{"allow":["Bash(*)","Bash(git reset:*)","Bash(git *)","Bash(gh pr *)","Bash(rm -rf *)","Bash(git status)","Bash(npm run *)","Bash(git log *)","Read(./src/**)"],
 "defaultMode":"bypassPermissions","additionalDirectories":["/","~/","../docs"]},
 "disableAllHooks":true,
 "env":{"CC_CONFIG_GUARD":"off","CC_SECRET_SCAN":"on","CLAUDE_AI_TRAILER":"allow","CLAUDE_DESTRUCTIVE_GUARD":"deny-only","CC_REMIND":"off"},
 "pluginConfigs":{"command-guard@m":{"options":{"cc_config_guard":false}}}}
EOF
cat > "$H/.claude/settings.json" <<'EOF'
{"permissions":{"allow":["Bash"],"defaultMode":"acceptEdits","additionalDirectories":["HOMEDIR/","HOMEDIR/work"]},
 "disableAllHooks":false,
 "env":{"CLAUDE_DESTRUCTIVE_GUARD":"deny-only","CC_DB_GUARD":"off","CC_WORKFLOW_GUARD":"on"},
 "pluginConfigs":{"command-guard@m":{"options":{"cc_config_guard":false,"claude_destructive_guard":"deny"}},"x@m":{"options":{"cc_secret_redact":"off"}}}}
EOF
sed -i.bak "s#HOMEDIR#$H#g" "$H/.claude/settings.json" && rm -f "$H/.claude/settings.json.bak"
before=$(cat "$P/.claude/settings.json" "$H/.claude/settings.json" | cksum)

out=$(lint); rc=$?
[ "$rc" = 1 ] && ok "findings exit 1" || bad "findings exit 1" "rc=$rc"
has '.claude/settings.json: permissions.allow[0] "Bash(*)": allows every shell command' "Bash(*) is flagged with its file and index"
has '~/.claude/settings.json: permissions.allow[0] "Bash": allows every shell command' "a bare Bash allow in the user file is flagged, shown under ~"
has 'permissions.allow[1] "Bash(git reset:*)": allows "git reset --hard HEAD"' "a :* rule covering git reset --hard is flagged"
has 'permissions.allow[2] "Bash(git *)": allows "git reset --hard HEAD" and' "a git * rule names the first command it covers and counts the rest"
has 'permissions.allow[3] "Bash(gh pr *)": allows "gh pr review 1 --approve"' "a gh pr * rule covers publishing review text"
has 'permissions.allow[4] "Bash(rm -rf *)"' "an rm -rf * rule is flagged"
lacks 'permissions.allow[5]' "Bash(git status) is silent"
lacks 'permissions.allow[6]' "Bash(npm run *) is silent"
lacks 'permissions.allow[7]' "Bash(git log *) is silent: a read-only subcommand"
lacks 'permissions.allow[8]' "a Read rule is silent"
has '.claude/settings.json: permissions.defaultMode: bypassPermissions: ignored from project settings' "bypassPermissions in project settings is flagged with the CLI-version caveat"
lacks '~/.claude/settings.json: permissions.defaultMode' "acceptEdits is silent"
has 'permissions.additionalDirectories[0] "/": opens the whole filesystem' "additionalDirectories / is flagged"
has 'permissions.additionalDirectories[1] "~/": opens the whole home folder' "additionalDirectories ~/ is flagged"
lacks 'additionalDirectories[2]' "a sibling directory is silent"
has "~/.claude/settings.json: permissions.additionalDirectories[0] \"$H/\": opens the whole home folder" "the home folder by absolute path is flagged"
lacks '~/.claude/settings.json: permissions.additionalDirectories[1]' "a folder under home is silent"
has '.claude/settings.json: disableAllHooks: turns off every hook, command-guard included, in this project' "disableAllHooks true is flagged"
lacks '~/.claude/settings.json: disableAllHooks' "disableAllHooks false is silent"
has '.claude/settings.json: env.CC_CONFIG_GUARD: turns off' "a guard's env off switch is flagged"
lacks 'env.CC_SECRET_SCAN' "a guard switch set on is silent"
lacks 'env.CC_REMIND' "an off switch that is not a guard is silent"
has '.claude/settings.json: env.CLAUDE_AI_TRAILER: lets an AI attribution trailer through' "CLAUDE_AI_TRAILER=allow set in settings is flagged"
lacks_at '.claude/settings.json: env.CLAUDE_DESTRUCTIVE_GUARD' "deny-only in project settings is silent (the README's automation profile)"
has '~/.claude/settings.json: env.CLAUDE_DESTRUCTIVE_GUARD: deny-only drops' "deny-only in the user file is flagged"
has '~/.claude/settings.json: env.CC_DB_GUARD: turns off' "a user-level guard off switch is flagged"
lacks 'env.CC_WORKFLOW_GUARD' "a guard switch set on in the user file is silent"
has '~/.claude/settings.json: pluginConfigs["command-guard@m"].options.cc_config_guard: turns off' "a /config option set false is flagged"
has 'pluginConfigs["x@m"].options.cc_secret_redact: turns off' "a /config option set off is flagged"
lacks 'options.claude_destructive_guard' "a /config option left on is silent"
lacks_at '.claude/settings.json: pluginConfigs' "pluginConfigs in project settings is silent: the host ignores it there"
[ "$(printf '%s\n' "$out" | grep -c .)" = 17 ] && ok "one line per finding, 17 in all" || bad "one line per finding, 17 in all" "$(printf '%s\n' "$out" | grep -c .) lines"
after=$(cat "$P/.claude/settings.json" "$H/.claude/settings.json" | cksum)
[ "$before" = "$after" ] && ok "the linter writes nothing" || bad "the linter writes nothing" "a settings file changed"

printf '{"permissions":{"allow":["Bash(git status)"]}}\n' > "$P/.claude/settings.json"; printf '{}\n' > "$H/.claude/settings.json"
out=$(lint); rc=$?
{ [ "$rc" = 0 ] && [ -z "$out" ]; } && ok "clean settings exit 0 and print nothing" || bad "clean settings exit 0 and print nothing" "rc=$rc out=$out"
printf '{"permissions":' > "$P/.claude/settings.local.json"
out=$(lint); rc=$?
{ [ "$rc" = 2 ] && [ "$out" = '.claude/settings.local.json: (file): not a JSON object, so nothing in it was checked' ]; } \
  && ok "an unparseable file exits 2 and says so on one line" || bad "an unparseable file exits 2 and says so on one line" "rc=$rc out=$out"
printf '[1]\n' > "$P/.claude/settings.local.json"
out=$(lint); rc=$?
[ "$rc" = 2 ] && ok "a JSON array is not a settings object: exit 2" || bad "a JSON array is not a settings object: exit 2" "rc=$rc out=$out"
rm -f "$P/.claude/settings.local.json"
mkdir -p "$T/cfg"; printf '{"disableAllHooks":true}\n' > "$T/cfg/settings.json"
out=$(CLAUDE_CONFIG_DIR="$T/cfg" lint); rc=$?
{ [ "$rc" = 1 ] && case "$out" in *"$T/cfg/settings.json: disableAllHooks: turns off every hook, command-guard included, in every project"*) true ;; *) false ;; esac; } \
  && ok "CLAUDE_CONFIG_DIR moves the user file" || bad "CLAUDE_CONFIG_DIR moves the user file" "rc=$rc out=$out"
out=$(HOME="$H" "$BASH_BIN" "$LINT" --bogus 2>/dev/null); rc=$?
[ "$rc" = 64 ] && ok "an unknown argument exits 64" || bad "an unknown argument exits 64" "rc=$rc"
NOJQ="$T/nojq"; mkdir -p "$NOJQ"
for u in cat sed awk tr head printf; do p=$(command -v "$u" 2>/dev/null) && ln -s "$p" "$NOJQ/$u"; done
err=$(HOME="$H" PATH="$NOJQ" "$BASH_BIN" "$LINT" --project "$P" 2>&1 >/dev/null); rc=$?
{ [ "$rc" = 3 ] && case "$err" in *'jq not found'*) true ;; *) false ;; esac; } && ok "no jq: says so and exits 3" || bad "no jq: says so and exits 3" "rc=$rc err=$err"

# The samples are the commands an allow rule must not cover; each has to stay a command destructive-guard.sh asks on.
G="$T/g"; mkdir -p "$G"
while IFS= read -r s; do
  [ -n "$s" ] || continue
  ( cd "$G" && CLAUDE_PROJECT_DIR="$G" HOME="$H" "$BASH_BIN" "$GUARD" --check "$s" >/dev/null 2>&1 ); rc=$?
  [ "$rc" = 1 ] && ok "sample is ask-tier in destructive-guard: $s" || bad "sample is ask-tier in destructive-guard: $s" "--check exit $rc"
done < <(sed -n "/^SAMPLES='/,/'\$/p" "$LINT" | sed -e "s/^SAMPLES='//" -e "s/'\$//")
if [ -f "$README" ]; then
  while IFS= read -r n; do
    grep -q "^| \`$n\` |" "$README" && ok "switch $n is in the root README's off-switch table" \
      || bad "switch $n is in the root README's off-switch table" "not found in $README"
  done < <(sed -n "/^GUARD_SWITCHES='/,/'\$/p" "$LINT" | sed -e "s/^GUARD_SWITCHES='//" | cut -f1)
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
