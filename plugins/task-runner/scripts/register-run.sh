#!/usr/bin/env bash
# register-run.sh — the one writer of .claude/task-runner/active-run.json: resumes a same branch+slug+index run untouched (its mtime is where gate records count from; --fresh, or no --index, registers anew); else deletes stale gate records, arms rv/ rt/ bg/ nc/ reductions/, writes slug, base, branch, start_sha. Sets phase build; seeds env-notes.md.
# Misses: whether the model runs the line it reads (agent-graded); a sentinel written by hand, which carries no start_sha and so does not arm the range-review check; without the CLI or a taskmaster in its own marketplace, a cache-wide phase-sentinel.sh that may not be the loaded copy (said on stderr).
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/register-run.sh (marketplace repository)

# Usage:
#   register-run.sh [--index <00-INDEX.md>] [--slug <name>] [--session <id>] [--fresh]
#
# Exit: 0 registered or resumed, 3 usage, 5 not a git work tree or not writable.
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

TOP=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
ROOT=$(cd "$TOP" && pwd -P)
HEAD=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null) || die "no commit at HEAD"
# symbolic-ref, not --abbrev-ref (a same-named tag printed `heads/<branch>`); exit 1 is a detached head, any other failure records no branch, which every reader takes as a match.
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
if [ ! -f "$PS" ] && command -v claude >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  # the enabled install for this project, else user scope: overseer's scripts/skill-path.sh, copied (plugins cannot import each other)
  p=$(claude plugin list --json 2>/dev/null | jq -r --arg r "$TOP" --arg rp "$ROOT" '
    [.[] | select(.enabled and (.id | startswith("taskmaster@")))]
    | (map(select(.scope != "user" and (.projectPath == $r or .projectPath == $rp))) + map(select(.scope == "user")))
    | .[0].installPath // empty' 2>/dev/null || true)
  [ -z "$p" ] || PS="$p/scripts/phase-sentinel.sh"
fi
if [ ! -f "$PS" ]; then
  # sort -V on the version directory alone: over full cache paths it orders by marketplace name first.
  mk="$here/../../../taskmaster"
  v=$(for d in "$mk"/*/; do [ -f "$d/scripts/phase-sentinel.sh" ] && basename "$d"; done 2>/dev/null | sort -V | tail -1 || true)
  [ -z "$v" ] || PS="$mk/$v/scripts/phase-sentinel.sh"
fi
if [ ! -f "$PS" ]; then
  PS=$(find "$HOME/.claude/plugins/cache" -path '*/taskmaster/*/scripts/phase-sentinel.sh' 2>/dev/null | sort -V | tail -1 || true)
  [ -z "$PS" ] || printf '%s: using %s from a cache-wide search; it may not be the copy Claude Code loaded\n' "$PROG" "$PS" >&2
fi
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
