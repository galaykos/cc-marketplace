#!/usr/bin/env bash
# capability-scan.sh — which installed plugins cover which pipeline phase, for THIS project,
# plus the CI facts the Discover step kept missing.
#
# Unions three sources because each alone lies: `claude plugin list --json` filtered to
# user scope or this project's path (the CLI is machine-wide); `enabledPlugins` in
# .claude/settings.json, .claude/settings.local.json and ~/.claude/settings.json (a
# --persist or hand-edited entry the CLI does not always report). Without the `claude`
# CLI the installed column reads `unknown` and every preferred plugin is listed as missing
# with its install command — the scan never guesses. The preferred column names only
# plugins this marketplace ships; official plugins (playwright) are not install hints.
# The CI block lists every workflow file, the branches it triggers on, and flags a trigger
# that does not name the base branch — the mismatch that made one simulation's CI never run.
# Exit 0 always; report-only.
#
# Usage: capability-scan.sh [--root <project>] [--json]
# Output (TSV): phase<TAB>installed<TAB>missing<TAB>fallback, then `# ci:` lines
set -u
root=""; json=0
while [ $# -gt 0 ]; do case "$1" in --root) root="${2:-}"; shift 2;; --json) json=1; shift;; *) shift;; esac; done
[ -n "$root" ] || root=$(git rev-parse --show-toplevel 2>/dev/null) || root="$PWD"
root=$(cd "$root" 2>/dev/null && pwd -P) || root="$PWD"

# phase|preferred marketplace plugins|fallback
MAP='understand|stack-scan,brain|read manifests, lockfiles, routes, pages, models, tests, CI workflows directly
shape|taskmaster,approaches,ui-ux|write the spec inline: goal, criteria, non-goals, ASCII wireframe
decide|approaches|one paragraph per option + pick + kill-trigger in decisions.md
plan|taskmaster,code-architecture|write cards inline: file set, verify command, done-criterion each
build|task-runner,laravel,web-dev,ui-ux,database,security,testing,craft-layer|dispatch scope-locked general-purpose workers with the discipline preamble
verify|testing,code-architecture,task-runner|run the suite yourself; browser via the official playwright plugin, Chrome MCP, or npx playwright
review|code-review,ui-ux,security,laravel,web-dev,resilience,api-design,database|one read-only reviewer subagent per diff
ship|git-workflow|offer three spelled-out destinations via AskUserQuestion — merge locally (into the base branch, no review), push and open a PR (for review), keep the branch open (leave it, come back); headless keeps the branch
guard|command-guard,secret-scanning,candor|none — say in the charter that no destructive-command guard is active'

installed=""
cli=0
if command -v claude >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  cli=1
  installed=$(claude plugin list --json 2>/dev/null | jq -r --arg root "$root" \
    '[.[] | select(.enabled and (.scope=="user" or .projectPath==$root))] | .[].id' 2>/dev/null)
fi
if command -v jq >/dev/null 2>&1; then
  for f in "$root/.claude/settings.json" "$root/.claude/settings.local.json" "$HOME/.claude/settings.json"; do
    [ -f "$f" ] || continue
    installed="$installed
$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value) | .key' "$f" 2>/dev/null)"
  done
fi
# bare plugin names (strip @marketplace), unique
names=$(printf '%s\n' "$installed" | sed 's/@.*$//' | sed '/^$/d' | sort -u)
proj_skills=$(ls -d "$root"/.claude/skills/*/ 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ',' | sed 's/,$//')

rows=""
while IFS='|' read -r phase pref fb; do
  [ -n "$phase" ] || continue
  have=""; miss=""
  for p in $(printf '%s' "$pref" | tr ',' ' '); do
    if printf '%s\n' "$names" | grep -qx "$p"; then have="$have,$p"; else miss="$miss,$p"; fi
  done
  have=${have#,}; miss=${miss#,}
  [ "$cli" -eq 0 ] && [ -z "$have" ] && have="unknown"
  rows="$rows$phase	${have:--}	${miss:--}	$fb
"
done <<EOF2
$MAP
EOF2

# CI: workflow files, their push/pull_request branches, and whether the base branch is among them
base=$(git -C "$root" branch --show-current 2>/dev/null); [ -n "$base" ] || base=main
ci=""
for wf in "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml "$root"/.gitlab-ci.yml; do
  [ -f "$wf" ] || continue
  # branches named anywhere under on: push/pull_request — a flat grep, good enough to spot a mismatch, not a YAML parse
  branches=$(sed -n '/^on:/,/^[a-z]/p' "$wf" | grep -E '^\s*-\s*[A-Za-z0-9_./*-]+\s*$|branches:\s*\[' | sed -E 's/.*\[//; s/\].*//; s/^[[:space:]]*-[[:space:]]*//; s/["'"'"' ]//g' | tr ',' '\n' | sed '/^$/d' | sort -u | tr '\n' ',' | sed 's/,$//')
  flag=""
  if [ -n "$branches" ] && ! printf '%s\n' "$branches" | tr ',' '\n' | grep -qx "$base"; then flag="  ← does not trigger on base '$base'"; fi
  ci="$ci${wf#$root/}	${branches:-<all branches>}$flag
"
done

if [ "$json" -eq 1 ] && command -v jq >/dev/null 2>&1; then
  printf '%s' "$rows" | jq -R -s --arg ps "$proj_skills" --argjson cli "$cli" --arg ci "$ci" --arg base "$base" '
    {cli_available: ($cli==1), base_branch: $base, project_skills: ($ps|split(",")|map(select(.!=""))),
     ci: ($ci|split("\n")|map(select(.!=""))|map(split("\t")|{workflow:.[0], branches:(.[1]|sub("  ← .*$";"")), triggers_on_base:(.[1]|test("← does not")|not)})),
     phases: (split("\n")|map(select(.!=""))|map(split("\t")|{phase:.[0],installed:(.[1]|split(",")|map(select(.!="-" and .!="unknown"))),missing:(.[2]|split(",")|map(select(.!="-"))),fallback:.[3]}))}'
else
  printf 'phase\tinstalled\tmissing\tfallback\n%s' "$rows"
  [ "$cli" -eq 0 ] && echo "# claude CLI not found: installed-state unknown; settings files only" >&2
  [ -n "$proj_skills" ] && printf '# project skills (.claude/skills): %s\n' "$proj_skills"
  miss_all=$(printf '%s' "$rows" | cut -f3 | tr ',' '\n' | grep -v '^-$' | sort -u | tr '\n' ' ')
  [ -n "$miss_all" ] && printf '# install: /plugin install <name>@cc-plugins-marketplace  (missing: %s) then /reload-plugins\n' "$miss_all"
  if [ -n "$ci" ]; then printf '# ci (base: %s):\n%s' "$base" "$(printf '%s' "$ci" | sed 's/^/#   /')"; echo; else echo "# ci: no workflow files found — suggest one in the charter"; fi
fi
exit 0
