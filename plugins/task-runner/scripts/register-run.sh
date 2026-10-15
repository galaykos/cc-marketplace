#!/usr/bin/env bash
# register-run.sh — register a task-runner run; the one writer of
# .claude/task-runner/active-run.json.
#
# Usage:
#   register-run.sh [--index <00-INDEX.md>] [--slug <name>] [--session <id>] [--fresh]
#
# WHY A SCRIPT. Registration was prose in /task-runner:run step 1 only. A handoff that
# invoked the task-execution skill directly skipped it: no active-run.json, so the review
# observer recorded 0 of 22 reviews, candor's completion clause never armed, and the run
# closed over a red behavioral-gate verdict. /task-runner:run step 1, the task-execution
# skill's step 1 and /task-runner:plan's "Run now" all call this now;
# scripts/__tests__/register-run.test.sh pins the three call sites.
#
# WHAT IT DOES:
#   1. RESUME. An index run's active-run.json on this branch with the same slug and index is
#      kept untouched: its mtime is the cutoff every completion-gate record is counted from, so
#      re-registering a run already under way would discard the records of its done cards.
#      --fresh registers anew anyway. An inline run (no --index) always registers anew: its
#      slug is only a name, `run` when none is given, and a match would adopt an abandoned
#      run's records.
#   2. FRESH. Deletes gate-pass.json, bg/bg-<HEAD>.json and closed-run.json (candor's gate
#      trusts the first two when they name HEAD, whatever their age), creates rv/ rt/ bg/
#      nc/ reductions/ (each arms one completion-gate check by existing) and a .gitignore of
#      `*`, then writes {"slug","base","branch","start_sha"[,"index_path"]}. base is the
#      merge-base with the default branch; start_sha is HEAD now, the range a stacked branch
#      actually adds, which the run-close range review reads.
#   3. Writes the arc phase sentinel `build` with taskmaster's phase-sentinel.sh (the
#      source-checkout sibling, else the newest installed copy), else by hand.
#   4. Seeds env-notes.md when absent, kept across runs: the environment facts every worker
#      reads first (the discipline preamble names it). Dispatches each re-pasted a ~1.5k-char
#      environment block, and four that lacked "never read .env" grepped it (2026-10-13 retro).
#
# Exit: 0 registered or resumed, 3 usage, 5 not a git work tree or not writable.
# Misses: whether the model runs the line it reads (agent-graded); a sentinel written by
# hand, which carries no start_sha and so does not arm the range-review check.
set -euo pipefail

PROG=register-run
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
die() { printf '%s: %s\n' "$PROG" "$1" >&2; exit 5; }
esc() { printf '%s' "$1" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'; }

INDEX=""; SLUG=""; SESSION=""; FRESH=0
while [ $# -gt 0 ]; do
  case "$1" in
    --index) [ $# -ge 2 ] || usage "--index needs an argument"; INDEX="$2"; shift 2 ;;
    --slug) [ $# -ge 2 ] || usage "--slug needs an argument"; SLUG="$2"; shift 2 ;;
    --session) [ $# -ge 2 ] || usage "--session needs an argument"; SESSION="$2"; shift 2 ;;
    --fresh) FRESH=1; shift ;;
    -h | --help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument: $1" ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
ROOT=$(cd "$ROOT" && pwd -P)
HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null) || die "no commit at HEAD"
# symbolic-ref, not --abbrev-ref: a tag with the branch's name made that print `heads/<branch>`.
# Exit 1 is a detached head; any other failure records no branch, which every reader takes as a match.
BRANCH=$(git -C "$ROOT" symbolic-ref -q HEAD 2>/dev/null) && rc=0 || rc=$?
case $rc in 0) BRANCH=${BRANCH#refs/heads/} ;; 1) BRANCH=HEAD ;; *) BRANCH="" ;; esac

IDX_REL=""
if [ -n "$INDEX" ]; then
  [ -f "$INDEX" ] || usage "--index names no file: $INDEX"
  abs="$(cd "$(dirname "$INDEX")" && pwd -P)/$(basename "$INDEX")"
  case "$abs" in "$ROOT"/*) IDX_REL=${abs#"$ROOT"/} ;; *) IDX_REL=$abs ;; esac
  [ -n "$SLUG" ] || SLUG=$(basename "$(dirname "$abs")")
fi
[ -n "$SLUG" ] || SLUG=run

TR="$ROOT/.claude/task-runner"
SENT="$TR/active-run.json"
mkdir -p "$TR/rv" "$TR/rt" "$TR/bg" "$TR/nc" "$TR/reductions" 2>/dev/null || die "cannot create $TR"
[ -e "$TR/.gitignore" ] || printf '*\n' > "$TR/.gitignore"
[ -e "$TR/env-notes.md" ] || printf '%s\n' '# Run environment notes' '' \
  'Every worker reads this before its first command. Add a fact here once; do not paste it into each dispatch.' '' \
  '- Never read, grep or print `.env` or a `.env.*` file other than `.env.example`: they hold credentials.' > "$TR/env-notes.md" || die "cannot write $TR/env-notes.md"

resumed=0
if [ "$FRESH" = 0 ] && [ -n "$IDX_REL" ] && [ -r "$SENT" ] && command -v jq >/dev/null 2>&1; then
  if [ "$(jq -r '[.branch // "", .slug // "", .index_path // ""] | join("\t")' "$SENT" 2>/dev/null)" \
       = "$(printf '%s\t%s\t%s' "$BRANCH" "$SLUG" "$IDX_REL")" ]; then
    resumed=1
  fi
fi

if [ "$resumed" = 0 ]; then
  DEF=$(git -C "$ROOT" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
  for c in main master origin/main origin/master; do
    [ -z "$DEF" ] || break
    git -C "$ROOT" rev-parse -q --verify "$c^{commit}" >/dev/null 2>&1 && DEF=$c
  done
  BASE=""
  [ -z "$DEF" ] || BASE=$(git -C "$ROOT" merge-base HEAD "$DEF" 2>/dev/null || true)
  [ -n "$BASE" ] || { BASE=$HEAD; printf '%s: no default branch to merge-base with; base is HEAD\n' "$PROG" >&2; }

  rm -f "$TR/gate-pass.json" "$TR/bg/bg-$HEAD.json" "$TR/closed-run.json"
  idx_json=""
  [ -z "$IDX_REL" ] || idx_json=$(printf ',"index_path":"%s"' "$(esc "$IDX_REL")")
  printf '{"slug":"%s","base":"%s","branch":"%s","start_sha":"%s"%s}\n' \
    "$(esc "$SLUG")" "$BASE" "$(esc "$BRANCH")" "$HEAD" "$idx_json" > "$SENT.tmp" && mv "$SENT.tmp" "$SENT" \
    || die "cannot write $SENT"
fi

here=$(cd "$(dirname "$0")" && pwd)
PS="$here/../../taskmaster/scripts/phase-sentinel.sh"
[ -f "$PS" ] || PS=$(find "$HOME/.claude/plugins/cache" -path '*/taskmaster/*/scripts/phase-sentinel.sh' 2>/dev/null | sort -V | tail -1 || true)
if [ -n "$PS" ] && [ -f "$PS" ]; then
  bash "$PS" write build --owner task-runner:run --cwd "$ROOT" ${SESSION:+--session "$SESSION"} >/dev/null
else
  printf '{"phase":"build","owner":"task-runner:run","session_id":"%s","started_at":"%s"}\n' \
    "$(esc "$SESSION")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ROOT/.claude/cc-phase.json"
fi

if [ "$resumed" = 1 ]; then
  printf 'resumed %s on %s, registered at start_sha=%s (--fresh registers anew)\n' "$SLUG" "${BRANCH:-an unknown branch}" "$(jq -r '.start_sha // "none" | .[0:12]' "$SENT")"
else
  printf 'registered %s on %s start_sha=%s\n' "$SLUG" "${BRANCH:-an unknown branch}" "${HEAD:0:12}"
fi
