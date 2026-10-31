#!/usr/bin/env bash
# skill-path.sh — print the absolute SKILL.md path of an installed plugin skill, for pinning in a dispatch prompt.
#
# Resolves through `claude plugin list --json`: the installPath of the ENABLED install that belongs to this project
# (`projectPath` = --project root, else the git toplevel of the cwd, else the cwd) or is user-scope, never another
# project's. Misses: without the CLI, the newest cache dir by version, which may not be the one loaded (said on stderr).
# Why, limits, history: rationale/derivations/plugin-overseer.md § plugins/overseer/scripts/skill-path.sh (marketplace repository)
#
# Usage: skill-path.sh <plugin> <skill> [--project <root>]   # project root: also checks <root>/.claude/skills/<skill>
# Exit: 0 printed a path that exists · 1 not found · 4 jq missing when the CLI route is used
set -u
plugin="${1:-}"; skill="${2:-}"; root=""
[ -n "$plugin" ] && [ -n "$skill" ] || { sed -n '2,10p' "$0" >&2; exit 1; }
shift 2; while [ $# -gt 0 ]; do case "$1" in --project) root="${2:-}"; shift 2;; *) shift;; esac; done
if [ -n "$root" ] && [ -f "$root/.claude/skills/$skill/SKILL.md" ] && [ "$plugin" = project ]; then
  printf '%s\n' "$root/.claude/skills/$skill/SKILL.md"; exit 0
fi
if command -v claude >/dev/null 2>&1; then
  command -v jq >/dev/null 2>&1 || { echo "skill-path.sh: jq is required" >&2; exit 4; }
  # the registry stores the path the CLI was launched from; match it logical and physical (macOS /var → /private/var)
  here="$root"; [ -n "$here" ] || here=$(git rev-parse --show-toplevel 2>/dev/null) || here=$(pwd)
  herep=$(cd "$here" 2>/dev/null && pwd -P) || herep="$here"
  p=$(claude plugin list --json 2>/dev/null | jq -r --arg n "$plugin" --arg r "$here" --arg rp "$herep" '
    [.[] | select(.enabled and (.id | startswith($n + "@")))]
    | (map(select(.scope != "user" and (.projectPath == $r or .projectPath == $rp))) + map(select(.scope == "user")))
    | .[0].installPath // empty')
  if [ -n "$p" ] && [ -f "$p/skills/$skill/SKILL.md" ]; then printf '%s\n' "$p/skills/$skill/SKILL.md"; exit 0; fi
fi
best=""
for d in "$HOME"/.claude/plugins/cache/*/"$plugin"/*/; do
  [ -f "$d/skills/$skill/SKILL.md" ] || continue
  v=$(basename "$d")
  # sort -V on basenames only: over full cache paths it is not a version sort.
  if [ -z "$best" ] || [ "$(printf '%s\n%s\n' "$(basename "$best")" "$v" | sort -V | tail -1)" = "$v" ]; then best="$d"; fi
done
if [ -n "$best" ]; then echo "skill-path.sh: CLI route unavailable, using newest cache dir $(basename "$best")" >&2; printf '%s\n' "${best%/}/skills/$skill/SKILL.md"; exit 0; fi
echo "skill-path.sh: no installed skill $plugin/$skill" >&2; exit 1
