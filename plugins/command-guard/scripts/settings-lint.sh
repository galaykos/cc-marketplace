#!/bin/bash
# Reads the project's .claude/settings.json and settings.local.json and the user settings.json as data, never writing, and prints "<file>: <key path>: <risk>" per bare Bash allow, allow rule matching a command command-guard asks on, bypassPermissions, disableAllHooks, global CLAUDE_AI_TRAILER=allow, additionalDirectories on / or ~, or a guard's off switch in env or pluginConfigs.
# Misses managed and --settings files, rules spelled another way than the samples, and any guard not in GUARD_SWITCHES. Exit: 0 nothing found, 1 findings, 2 a file is not a JSON object (the rest still read), 3 no jq, 64 usage.
# Why, limits, history: rationale/derivations/plugin-command-guard.md § plugins/command-guard/scripts/settings-lint.sh

usage() { printf 'usage: settings-lint.sh [--project DIR] [--user FILE]\n' >&2; exit 64; }

project="${CLAUDE_PROJECT_DIR:-$PWD}"
user="${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}/settings.json"
while [ $# -gt 0 ]; do
  case "$1" in
    --project) [ $# -ge 2 ] || usage; project=$2; shift 2 ;;
    --user) [ $# -ge 2 ] || usage; user=$2; shift 2 ;;
    *) usage ;;
  esac
done
command -v jq >/dev/null 2>&1 || { printf 'settings-lint: jq not found; no settings file was read\n' >&2; exit 3; }

# Commands destructive-guard.sh asks on; settings-lint.test.sh holds each to that tier.
SAMPLES='git reset --hard HEAD
git clean -fd
git checkout -- .
git branch -D old
git stash clear
git push --force-with-lease origin main
git commit --no-verify -m wip
rm -rf /opt/data
find . -name x -delete
docker system prune
kubectl delete pod api
helm uninstall api
terraform apply -auto-approve
npm publish
gh pr review 1 --approve
gh pr comment 1 --body x
gh api -X DELETE repos/o/r/labels/x
crontab -r'

# NAME<TAB>what turning it off removes; settings-lint.test.sh holds each name to the root README's off-switch table.
GUARD_SWITCHES='CLAUDE_DESTRUCTIVE_GUARD	command-guard'"'"'s destructive-command deny and ask
CC_CONFIG_GUARD	command-guard'"'"'s ask before a config write
CC_SECRET_SCAN	secret-scanning'"'"'s refusal of a secret written to disk
CC_SECRET_REDACT	secret-scanning'"'"'s masking of secrets in tool output
CC_SECRET_PROMPT	secret-scanning'"'"'s check of a secret typed into the prompt
CC_UNICODE_SCAN	secret-scanning'"'"'s hidden-character warning
CC_SECURITY_SCAN	security'"'"'s dangerous-sink warning
CC_DB_GUARD	database'"'"'s ask before destructive SQL
CC_WORKFLOW_GUARD	devops'"'"'s refusal of a workflow that hands secrets to untrusted code
CC_PREVIEW_GUARD	the ask before a page is published remotely
CC_MERGE_CHECKS	git-workflow'"'"'s ask before merging with failing checks
CC_PROTECT_TESTS	testing'"'"'s refusal of a skipped or emptied test
CC_ELISION_GUARD	code-review'"'"'s refusal of elided code
CC_PROBE_GUARD	debugging'"'"'s ask before committing a debug probe'

samples=$(printf '%s\n' "$SAMPLES" | jq -R . | jq -sc .)
switches=$(printf '%s\n' "$GUARD_SWITCHES" | jq -R 'split("\t") | {(.[0]): .[1]}' | jq -sc add)

# A Bash rule's * matches any text; a lone trailing " *" (or ":*") also matches the bare command (code.claude.com/docs/en/permissions).
PROGRAM='
def esc: gsub("(?<c>[.^$|?+()\\[\\]{}\\\\])"; "\\\(.c)");
def rule_re: (if endswith(":*") then .[:-2] + " *" else . end) as $s
  | if ($s | endswith(" *")) and ([$s | scan("\\*")] | length) == 1
    then "^" + ($s[:-2] | esc) + "( .*)?$"
    else "^" + ($s | split("*") | map(esc) | join(".*")) + "$" end;
def off: (type == "boolean" and . == false) or (type == "string" and ascii_downcase == "off");
def line($k; $m): "\($k)\t\($m)";
(if type == "object" then . else error("not an object") end) as $root
| ($root.permissions | if type == "object" then . else {} end) as $p
| (($p.allow // []) | if type == "array" then . else [] end | to_entries[] | select(.value | type == "string")
    | .key as $i | .value as $r
    | if $r == "Bash" or ($r | test("^Bash\\([*: ]*\\)$")) then
        line("permissions.allow[\($i)] \($r | @json)"; "allows every shell command with no host prompt; only hooks such as command-guard still read them")
      elif ($r | test("^Bash\\(.*\\)$")) then
        ($r | .[5:-1] | rule_re) as $re
        | [$samples[] | select(test($re))] as $hit
        | select($hit | length > 0)
        | line("permissions.allow[\($i)] \($r | @json)"; "allows \($hit[0] | @json)\(if ($hit | length) > 1 then " and \(($hit | length) - 1) more" else "" end) with no host prompt, a command command-guard asks on; under deny-only or off nothing asks")
      else empty end),
  (select($p.defaultMode == "bypassPermissions")
    | line("permissions.defaultMode"; if $scope == "user" then "bypassPermissions starts every session with no permission prompt" else "bypassPermissions: ignored from project settings since CLI 2.1.257, applied by older CLIs" end)),
  (($p.additionalDirectories // []) | if type == "array" then . else [] end | to_entries[] | select(.value | type == "string")
    | .key as $i | (.value | sub("/+$"; "")) as $d
    | select($d == "" or $d == "~" or $d == "$HOME" or $d == "${HOME}" or ($home != "" and $d == $home))
    | line("permissions.additionalDirectories[\($i)] \(.value | @json)"; "opens \(if $d == "" then "the whole filesystem" else "the whole home folder" end) to file tools")),
  (select($root.disableAllHooks == true)
    | line("disableAllHooks"; "turns off every hook, command-guard included, \(if $scope == "user" then "in every project" else "in this project" end)")),
  (($root.env // {}) | if type == "object" then . else {} end | to_entries[] | . as $e
    | if $e.key == "CLAUDE_AI_TRAILER" and ($e.value | tostring | ascii_downcase) == "allow" then
        line("env.CLAUDE_AI_TRAILER"; "lets an AI attribution trailer through git-workflow on every command, not the one command the switch is for")
      elif $e.key == "CLAUDE_DESTRUCTIVE_GUARD" and ($e.value | tostring | ascii_downcase) == "deny-only" and $scope == "user" then
        line("env.CLAUDE_DESTRUCTIVE_GUARD"; "deny-only drops command-guard'"'"'s ask tier in every project, not only in automated runs")
      elif ($switches[$e.key] != null) and ($e.value | off) then
        line("env.\($e.key)"; "turns off \($switches[$e.key])")
      else empty end),
  (select($scope == "user") | ($root.pluginConfigs // {}) | if type == "object" then . else {} end | to_entries[] | .key as $pl
    | (.value.options // {}) | if type == "object" then . else {} end | to_entries[] | . as $o
    | ($switches | to_entries[] | select(.key | ascii_downcase == $o.key)) as $sw
    | select($o.value | off)
    | line("pluginConfigs[\($pl | @json)].options.\($o.key)"; "turns off \($sw.value)"))
'

found=0; bad=0; read_n=0
for spec in "project|$project/.claude/settings.json|.claude/settings.json" \
            "project|$project/.claude/settings.local.json|.claude/settings.local.json" \
            "user|$user|"; do
  scope=${spec%%|*}; rest=${spec#*|}; f=${rest%%|*}; shown=${rest#*|}
  [ -n "$shown" ] || { shown=$f; [ -n "${HOME:-}" ] && case "$f" in "$HOME"/*) shown="~/${f#"$HOME"/}" ;; esac; }
  [ -f "$f" ] || continue
  read_n=$((read_n + 1))
  if ! out=$(jq -r --arg scope "$scope" --arg home "${HOME%/}" --argjson samples "$samples" --argjson switches "$switches" "$PROGRAM" "$f" 2>/dev/null); then
    printf '%s: (file): not a JSON object, so nothing in it was checked\n' "$shown"
    bad=1; continue
  fi
  while IFS=$'\t' read -r key msg; do
    [ -n "$key" ] || continue
    printf '%s: %s: %s\n' "$shown" "$key" "$msg"
    found=$((found + 1))
  done <<EOF
$out
EOF
done
printf 'settings-lint: %s finding(s) in %s settings file(s) read\n' "$found" "$read_n" >&2
[ "$bad" -eq 0 ] || exit 2
[ "$found" -eq 0 ] || exit 1
exit 0
