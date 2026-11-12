#!/usr/bin/env bash
# config-guard.test.sh — asserts hooks/config-guard.sh asks on Edit and Bash writes to existing listed configs and on a Bash removal of
#   command-guard-strict, stays silent on the rest, and checks its marketplace self-exemption, both off-switches and fail-open.
# Why, limits, history: rationale/derivations/plugin-command-guard.md § plugins/command-guard/scripts/__tests__/config-guard.test.sh
set -u
HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/config-guard.sh"
BASH_BIN="${BASH:-bash}"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

ok()  { pass=$((pass+1)); printf 'PASS  %s\n' "$1"; }
bad() { fail=$((fail+1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

fire() { # path [tool]
  python3 -c "
import json,sys
print(json.dumps({'session_id':'cg','cwd':sys.argv[2],'tool_name':sys.argv[3],
  'tool_input':{'file_path':sys.argv[1],'old_string':'a','new_string':'b'}}))
" "$1" "$T" "${2:-Edit}" | "$BASH_BIN" "$HOOK" 2>/dev/null
}
asks()   { out=$(fire "$1"); case "$out" in *'"permissionDecision":"ask"'*) ok "$2" ;; *) bad "$2" "expected ask, got: ${out:-<silent>}" ;; esac; }
allows() { out=$(fire "$1"); [ -z "$out" ] && ok "$2" || bad "$2" "expected silence, got: $out"; }

mkdir -p "$T/.claude" "$T/hooks" "$T/plugins/x/.claude-plugin" "$T/src"
for f in .claude/settings.json .claude/settings.local.json hooks/hooks.json .eslintrc.json \
         tsconfig.json .rubocop.yml phpstan.neon .golangci.yml pytest.ini biome.json \
         plugins/x/.claude-plugin/plugin.json hooks/guard.sh src/app.ts README.md; do
  printf '{}\n' > "$T/$f"
done

asks "$T/.claude/settings.json"        "settings.json asks"
asks "$T/.claude/settings.local.json"  "settings.local.json asks"
asks "$T/hooks/hooks.json"             "a hooks manifest asks"
asks "$T/hooks/guard.sh"               "a hook script asks"
asks "$T/plugins/x/.claude-plugin/plugin.json" "a plugin manifest asks"
asks "$T/.eslintrc.json"               "eslint config asks"
asks "$T/tsconfig.json"                "tsconfig asks"
asks "$T/.rubocop.yml"                 "rubocop config asks"
asks "$T/phpstan.neon"                 "phpstan config asks"
asks "$T/.golangci.yml"                "golangci config asks"
asks "$T/pytest.ini"                   "pytest config asks"
asks "$T/biome.json"                   "biome config asks"
r=$(fire "$T/tsconfig.json" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
[ "$r" = 'command-guard: editing a lint, type-check or test config (`tsconfig.json`). Confirm this is a real config change, not a way around a failing check. CC_CONFIG_GUARD=off turns this prompt off.' ] \
  && ok "the ask names the file, its kind and one off switch" \
  || bad "the ask names the file, its kind and one off switch" "$r"

# 0.9.4: test, coverage, CI and git-hook configs, which lane.tsv named and config_kind did not
mkdir -p "$T/.github/workflows" "$T/.husky" "$T/.git/hooks"
for f in phpunit.xml phpunit.xml.dist jest.config.js vitest.config.ts .mocharc.yml karma.conf.js .coveragerc .nycrc.json \
         codecov.yml mypy.ini .stylelintrc.json .github/workflows/ci.yml .github/workflows/release.yaml .gitlab-ci.yml \
         .pre-commit-config.yaml lefthook.yml .husky/pre-commit .git/hooks/pre-commit .github/dependabot.yml jest.setup.js; do
  printf 'x\n' > "$T/$f"
done
for f in phpunit.xml phpunit.xml.dist jest.config.js vitest.config.ts .mocharc.yml karma.conf.js .coveragerc .nycrc.json \
         codecov.yml mypy.ini .stylelintrc.json .github/workflows/ci.yml .github/workflows/release.yaml .gitlab-ci.yml \
         .pre-commit-config.yaml lefthook.yml .husky/pre-commit .git/hooks/pre-commit; do
  asks "$T/$f" "$f asks"
done
allows "$T/.github/dependabot.yml" "a .github file outside workflows/ is silent"
allows "$T/jest.setup.js"          "a test setup file is not its config: silent"

allows "$T/src/app.ts"      "ordinary source is silent"
allows "$T/README.md"       "a README is silent"
allows "$T/.prettierrc"     "an unlisted config is silent (the list is literal)"
allows "$T/.claude/settings.json.new" "a path that only resembles a target is silent"

# creating a config is not relaxing one
rm -f "$T/.flake8"
allows "$T/.flake8" "a config that does not exist yet is silent (nothing to weaken)"

fire_bash() { # command
  python3 -c "
import json,sys
print(json.dumps({'session_id':'cg','cwd':sys.argv[2],'tool_name':'Bash','tool_input':{'command':sys.argv[1]}}))
" "$1" "$T" | "$BASH_BIN" "$HOOK" 2>/dev/null
}
bash_asks()   { out=$(fire_bash "$1"); case "$out" in *'"permissionDecision":"ask"'*"(\`$3\`)"*) ok "$2" ;; *) bad "$2" "expected ask naming $3, got: ${out:-<silent>}" ;; esac; }
bash_allows() { out=$(fire_bash "$1"); [ -z "$out" ] && ok "$2" || bad "$2" "expected silence, got: $out"; }

printf 'x\n' > "$T/notes.txt"
bash_asks $'cat > tsconfig.json <<\'EOF\'\n{}\nEOF' "bash: heredoc overwrite of an existing tsconfig asks" tsconfig.json
bash_asks "sed -i '' 's/a/b/' .eslintrc.json" "bash: sed -i on an existing eslint config asks" .eslintrc.json
bash_asks "sed -i 's/a/b/' .eslintrc.json 2>/dev/null" "bash: sed -i with a trailing 2>/dev/null onto an existing eslint config asks" .eslintrc.json
bash_allows "ls -la && git status" "bash: non-write command is silent"
bash_allows $'cat > notes.txt <<\'EOF\'\necho {} > tsconfig.json\nEOF' "bash: a config path only inside a heredoc body is silent"
rm -f "$T/.flake8"
bash_allows "echo '[flake8]' > .flake8" "a Bash write creating a config is silent (nothing to weaken)"
bash_asks "echo x > .flake8; sed -i '' s/a/b/ tsconfig.json" "a missing config target does not hide a later existing one" tsconfig.json
bash_asks "echo x & sed -i s/a/b/ tsconfig.json" "bash: a config written after a lone & asks" tsconfig.json
bash_allows "sed -i s/a/b/ notes.txt & cat tsconfig.json" "bash: a config only named after a lone & is allowed"
bash_asks "echo 'exit 0' > .git/hooks/pre-commit" "bash: a redirect over an existing git hook asks" pre-commit
bash_asks "sed -i 's/npm test/true/' .github/workflows/ci.yml" "bash: sed -i on an existing CI workflow asks" ci.yml
bash_asks "printf 'x' | tee .husky/pre-commit" "bash: tee over an existing husky hook asks" pre-commit
mkdir -p "$T/home/.claude" && printf '{}\n' > "$T/home/.claude/settings.json"
HOME="$T/home" bash_asks "echo '{}' > ~/.claude/settings.json" "a ~/ target expands to HOME" settings.json

# 0.9.5: analyzer baselines, as files and as the flags that write their entries
for f in phpstan-baseline.neon phpstan-baseline.neon.dist phpstan-baseline.php psalm-baseline.xml eslint-suppressions.json baseline.md; do
  printf 'x\n' > "$T/$f"
done
for f in phpstan-baseline.neon phpstan-baseline.neon.dist phpstan-baseline.php psalm-baseline.xml eslint-suppressions.json; do
  asks "$T/$f" "$f asks"
done
r=$(fire "$T/phpstan-baseline.neon" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
[ "$r" = 'command-guard: editing an analyzer baseline (`phpstan-baseline.neon`). Confirm this is a real config change, not a way around a failing check. CC_CONFIG_GUARD=off turns this prompt off.' ] \
  && ok "the baseline ask names its kind and the file" || bad "the baseline ask names its kind and the file" "$r"
r=$(fire "$T/phpstan.neon" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
case "$r" in *'editing a lint, type-check or test config (`phpstan.neon`)'*) ok "phpstan.neon keeps its lint-config ask" ;;
  *) bad "phpstan.neon keeps its lint-config ask" "${r:-<silent>}" ;; esac
allows "$T/baseline.md" "a file merely named baseline.md is silent"
bash_asks "cat new.neon > phpstan-baseline.neon" "bash: a redirect over an existing baseline asks" phpstan-baseline.neon
bash_allows "echo x > baseline.md" "bash: a write to baseline.md is silent"
bash_asks "vendor/bin/phpstan analyse --generate-baseline" "bash: phpstan --generate-baseline asks" --generate-baseline
bash_asks "php -d memory_limit=1G vendor/bin/phpstan analyse -b" "bash: phpstan's short -b asks" "phpstan -b"
bash_asks "composer phpstan -- --generate-baseline=phpstan-baseline.php" "bash: --generate-baseline through a composer script asks" --generate-baseline
bash_asks "vendor/bin/psalm --set-baseline=psalm-baseline.xml" "bash: psalm --set-baseline asks" --set-baseline
bash_asks "npx eslint . --suppress-all" "bash: eslint --suppress-all asks" --suppress-all
bash_asks "npx eslint src --suppress-rule no-unused-vars" "bash: eslint --suppress-rule asks" --suppress-rule
bash_asks "npm run lint -- --suppress-all" "bash: --suppress-all through an npm script asks" --suppress-all
r=$(fire_bash "vendor/bin/phpstan analyse --generate-baseline" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
[ "$r" = 'command-guard: regenerating an analyzer baseline (`--generate-baseline`). Confirm this is a real config change, not a way around a failing check. CC_CONFIG_GUARD=off turns this prompt off.' ] \
  && ok "the regenerate ask names the flag" || bad "the regenerate ask names the flag" "$r"
bash_allows "vendor/bin/phpstan analyse" "bash: phpstan analyse without the flag is silent"
bash_allows "vendor/bin/phpstan analyse -c phpstan.neon --memory-limit=1G" "bash: phpstan with other flags is silent"
bash_allows "vendor/bin/psalm --update-baseline" "bash: psalm --update-baseline (drops fixed entries only) is silent"
bash_allows "npx eslint . --prune-suppressions" "bash: eslint --prune-suppressions (drops fixed entries only) is silent"
bash_allows "grep -b phpstan composer.json" "bash: a -b before any phpstan word is silent"
bash_allows 'git commit -m "phpstan: stop running --generate-baseline in CI"' "bash: a regenerate flag inside quotes is silent"
bash_allows $'cat > notes.txt <<\'EOF\'\nnpx eslint . --suppress-all\nEOF' "bash: a regenerate flag inside a heredoc body is silent"
bash_allows "vendor/bin/phpstan analyse # add --generate-baseline later" "bash: a regenerate flag after a # comment is silent"
bash_allows $'git commit -m "$(cat <<\'EOF\'\nci: stop running --generate-baseline\n\nIt hid new findings.\nEOF\n)"' "bash: a regenerate flag in a \$(cat <<'EOF') commit message is silent"
bash_allows $'git commit -m "ci: lint\n\nStop running --generate-baseline in CI."' "bash: a regenerate flag on a later line of a quoted message is silent"
bash_asks $'docker compose exec -T app sh <<\'EOF\'\nvendor/bin/phpstan analyse --generate-baseline\nEOF' "bash: a regenerate flag in a heredoc a shell reads asks" --generate-baseline
bash_asks $'cat > notes.txt <<\'EOF\'\nnotes\nEOF\nnpx eslint . --suppress-all' "bash: a regenerate flag after a heredoc terminator asks" --suppress-all
bash_asks $'# don\'t keep the old baseline\nnpx eslint . --suppress-all' "bash: a quote inside a # comment does not mask the next line" --suppress-all
out=$(CC_CONFIG_GUARD=off fire_bash "npx eslint . --suppress-all")
[ -z "$out" ] && ok "CC_CONFIG_GUARD=off silences the regenerate ask" || bad "CC_CONFIG_GUARD=off silences the regenerate ask" "$out"

# 0.10.0: the strictness file only adds asks and denies, so creating it is silent; editing an existing one (which can drop a line) asks.
rm -f "$T/.claude/command-guard-strict"
allows "$T/.claude/command-guard-strict" "creating command-guard-strict is silent (it can only add strictness)"
printf 'ask ^npm publish\n' > "$T/.claude/command-guard-strict"
asks "$T/.claude/command-guard-strict" "an Edit of an existing command-guard-strict asks"
out=$(fire "$T/.claude/command-guard-strict" Write)
case "$out" in *'"permissionDecision":"ask"'*"command-guard's strictness file"*) ok "a Write over an existing command-guard-strict asks, naming its kind" ;;
  *) bad "a Write over an existing command-guard-strict asks, naming its kind" "${out:-<silent>}" ;; esac
bash_asks "printf '' > .claude/command-guard-strict" "bash: truncating an existing command-guard-strict asks" command-guard-strict
bash_asks "sed -i '/npm publish/d' .claude/command-guard-strict" "bash: sed -i on an existing command-guard-strict asks" command-guard-strict
printf 'x\n' > "$T/.claude/command-guard-strict.bak"
allows "$T/.claude/command-guard-strict.bak" "a file only named like it is silent"
bash_allows "cat .claude/command-guard-strict" "bash: reading command-guard-strict is silent"
# 0.10.0 review: removing it only loosens, and its deny reason names it, so rm, unlink, mv, git rm and git mv of it ask.
for c in "rm .claude/command-guard-strict" "rm -f ./.claude/command-guard-strict" "sudo rm .claude/command-guard-strict" \
         "unlink .claude/command-guard-strict" "mv .claude/command-guard-strict /tmp/cg-old" "git rm .claude/command-guard-strict" \
         "git -C . mv .claude/command-guard-strict x" "rm '$T/.claude/command-guard-strict'"; do
  bash_asks "$c" "bash: $c asks" command-guard-strict
done
out=$(fire_bash "rm .claude/command-guard-strict" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null)
case "$out" in 'command-guard: removing command-guard'"'"'s strictness file (`command-guard-strict`).'*) ok "the removal ask says removing" ;;
  *) bad "the removal ask says removing" "${out:-<silent>}" ;; esac
for c in "rm .claude/command-guard-strict.bak" "cp .claude/command-guard-strict /tmp/cg-copy" 'echo "rm .claude/command-guard-strict"' \
         'git commit -m "x; rm .claude/command-guard-strict"' $'cat > notes.txt <<\'EOF\'\nrm .claude/command-guard-strict\nEOF' \
         "ls # rm .claude/command-guard-strict"; do
  bash_allows "$c" "bash: $c is silent"
done
mv "$T/.claude/command-guard-strict" "$T/strict.keep"
bash_allows "rm .claude/command-guard-strict" "bash: removing an absent command-guard-strict is silent"
bash_allows "printf 'ask ^npm publish\\n' > .claude/command-guard-strict" "bash: creating command-guard-strict is silent"
bash_asks "rm .claude/command-guard-strict; sed -i s/a/b/ tsconfig.json" "bash: an absent strict file does not hide a later write" tsconfig.json
mv "$T/strict.keep" "$T/.claude/command-guard-strict"

printf '{}\n' > "$T/.claude-plugin-marker-absent"
mkdir -p "$T/.claude-plugin" && printf '{"plugins":[]}\n' > "$T/.claude-plugin/marketplace.json"
out=$(fire "$T/.claude/settings.json")
[ -z "$out" ] && ok "silent inside a marketplace repo (it edits these files as its product)" \
  || bad "silent inside a marketplace repo" "asked anyway: $out"
out=$(fire_bash "vendor/bin/phpstan analyse --generate-baseline")
[ -z "$out" ] && ok "a regenerate is silent inside a marketplace repo" || bad "a regenerate is silent inside a marketplace repo" "$out"
rm -rf "$T/.claude-plugin"

out=$(python3 -c "
import json
print(json.dumps({'session_id':'cg','cwd':'$T','tool_name':'Edit','tool_input':{'file_path':'$T/.claude/settings.json','old_string':'a','new_string':'b'}}))
" | CC_CONFIG_GUARD=off "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -z "$out" ] && ok "CC_CONFIG_GUARD=off silences it" || bad "CC_CONFIG_GUARD=off silences it" "$out"

for v in off deny-only DENY-ONLY Off; do
  out=$(python3 -c "
import json
print(json.dumps({'session_id':'cg','cwd':'$T','tool_name':'Edit','tool_input':{'file_path':'$T/.claude/settings.json','old_string':'a','new_string':'b'}}))
" | CLAUDE_DESTRUCTIVE_GUARD="$v" "$BASH_BIN" "$HOOK" 2>/dev/null)
  [ -z "$out" ] && ok "CLAUDE_DESTRUCTIVE_GUARD=$v silences config-guard" \
    || bad "CLAUDE_DESTRUCTIVE_GUARD=$v silences config-guard" "$out"
done
out=$(python3 -c "
import json
print(json.dumps({'session_id':'cg','cwd':'$T','tool_name':'Edit','tool_input':{'file_path':'$T/.claude/settings.json','old_string':'a','new_string':'b'}}))
" | CLAUDE_DESTRUCTIVE_GUARD=ask "$BASH_BIN" "$HOOK" 2>/dev/null)
[ -n "$out" ] && ok "CLAUDE_DESTRUCTIVE_GUARD=ask leaves config-guard running" \
  || bad "CLAUDE_DESTRUCTIVE_GUARD=ask leaves config-guard running" "silenced"

out=$(printf 'garbage' | "$BASH_BIN" "$HOOK" 2>/dev/null); rc=$?
[ "$rc" -eq 0 ] && [ -z "$out" ] && ok "fail-open on malformed input" || bad "fail-open on malformed input" "rc=$rc"
out=$(fire "$T/.claude/settings.json" Bash)
[ -z "$out" ] && ok "a Bash payload with no command is silent" || bad "a Bash payload with no command is silent" "$out"

# The entry run as the host runs it (/bin/sh -c, the root in the env) on a copy whose shebang names no interpreter:
# on a host without /bin/bash (NixOS) the path form errored and the ask never came.
HJ="$(dirname "$HOOK")/hooks.json"
SB="$T/noshebang"; mkdir -p "$SB/hooks"
{ printf '#!/nonexistent/bash\n'; tail -n +2 "$HOOK"; } > "$SB/hooks/config-guard.sh"; chmod +x "$SB/hooks/config-guard.sh"
n=0
while IFS= read -r c; do
  n=$((n+1))
  out=$(python3 -c "
import json,sys
print(json.dumps({'session_id':'cg','cwd':sys.argv[1],'tool_name':'Edit',
  'tool_input':{'file_path':sys.argv[1]+'/.claude/settings.json','old_string':'a','new_string':'b'}}))
" "$T" | CLAUDE_PLUGIN_ROOT="$SB" /bin/sh -c "$c" 2>/dev/null)
  case "$out" in *'"permissionDecision":"ask"'*) ok "hooks.json starts config-guard.sh through PATH bash, not its shebang" ;;
    *) bad "hooks.json starts config-guard.sh through PATH bash, not its shebang" "got: ${out:-<silent>} command=$c" ;; esac
done < <(jq -r '.hooks.PreToolUse[].hooks[] | select(.command | test("config-guard\\.sh")) | .command' "$HJ" 2>/dev/null)
[ "$n" -gt 0 ] || bad "hooks.json registers config-guard.sh" "no entry found in $HJ"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
