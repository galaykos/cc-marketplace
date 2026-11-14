#!/usr/bin/env bash
# mark-deliberated.sh write --task <slug> [--shape "<pick>"] [--why "<one line>"] [--kill-trigger "<…>"] [--by <who>] | check --task <slug> — the one writer and reader of <project root>/.cc-artifacts/approaches/deliberated.json, the double-run marker (an older project's .claude/approaches/ is copied over once). check exits 0 when an unexpired marker (120 min, the compact-recovery TTL) names <slug>, 1 otherwise; write exits 0; 3 is a usage error.
# Misses: whether a deliberation actually ran before write, a marker written by hand, and a second task in the same project overwriting the first (one marker per project by design).
# Why, limits, history: rationale/derivations/plugin-approaches.md § plugins/approaches/scripts/mark-deliberated.sh

# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

PROG=mark-deliberated
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
command -v jq >/dev/null 2>&1 || usage "jq is required"
cmd="${1:-}"; shift 2>/dev/null || true
case "$cmd" in write | check) ;; *) usage "want write|check (got: ${cmd:-nothing})" ;; esac
task=""; shape=""; why=""; kill=""; by="approach-deliberation"; cwd="$PWD"
while [ $# -gt 0 ]; do
  case "$1" in
    --task) [ $# -ge 2 ] || usage "--task needs a value"; task=$2; shift 2 ;;
    --shape) [ $# -ge 2 ] || usage "--shape needs a value"; shape=$2; shift 2 ;;
    --why) [ $# -ge 2 ] || usage "--why needs a value"; why=$2; shift 2 ;;
    --kill-trigger) [ $# -ge 2 ] || usage "--kill-trigger needs a value"; kill=$2; shift 2 ;;
    --by) [ $# -ge 2 ] || usage "--by needs a value"; by=$2; shift 2 ;;
    --cwd) [ $# -ge 2 ] || usage "--cwd needs a value"; cwd=$2; shift 2 ;;
    *) usage "unknown argument: $1" ;;
  esac
done
printf '%s' "$task" | grep -Eq '^[a-z0-9][a-z0-9-]{0,79}$' || usage "--task must be a short kebab-case slug (got: ${task:-nothing})"
root=$(cc_state_root "$cwd") || usage "cannot resolve a project root from $cwd"
dir="$root/.cc-artifacts/approaches"; old="$root/.claude/approaches"
marker="$dir/deliberated.json"
# Plugins before 2026-11-14 kept this state in .claude/approaches/; copy it over once, then use only the new dir.
if [ ! -d "$dir" ] && [ -d "$old" ]; then mkdir -p "$dir" && cp -Rp "$old/." "$dir/"; fi

if [ "$cmd" = check ]; then
  [ -f "$marker" ] || exit 1
  [ -z "$(find "$marker" -maxdepth 0 -mmin +120 2>/dev/null)" ] || exit 1
  [ "$(jq -r '.task // empty' "$marker" 2>/dev/null)" = "$task" ] || exit 1
  printf '%s: %s already deliberated (%s)\n' "$PROG" "$task" "$(jq -r '.at // "no time"' "$marker" 2>/dev/null)"
  exit 0
fi

mkdir -p "$dir" || usage "cannot create $dir"
jq -n --arg task "$task" --arg by "$by" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg shape "$shape" --arg why "$why" --arg kill "$kill" \
  '{task: $task, by: $by, at: $at} + (if $shape != "" then {shape: $shape} else {} end)
   + (if $why != "" then {why: $why} else {} end) + (if $kill != "" then {kill_trigger: $kill} else {} end)' > "$marker" \
  || usage "cannot write $marker"
printf '%s: wrote %s (task=%s)\n' "$PROG" "$marker" "$task"
