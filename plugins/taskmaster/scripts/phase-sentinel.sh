#!/bin/bash
# phase-sentinel.sh — the one SCRIPT writer of the arc phase sentinel,
# `<project root>/.claude/cc-phase.json`.
#
# WHY THIS EXISTS. The sentinel had four PROSE writers (taskmaster:task,
# task-runner:run, code-architecture:coding-task, git-workflow:finish), no script
# writer, and seven readers — AR 11 of the 2026-09-22 specialist panel, open since the
# endgame review's residual 3. Four hand-written JSON literals in four command bodies
# is four chances to mistype a key or a phase name, and the reader
# (`templates/blocks/phase-guard.md`) fails SILENTLY on both: an unknown phase scores 0
# in its ordering table and every guard proceeds, which looks exactly like no sentinel
# at all. Nothing anywhere told you it had happened.
#
# So the vocabulary is checked HERE, once, at write time — the one moment a typo is
# still cheap. `write` refuses an unknown phase with exit 3 instead of leaving a file
# that reads as absence.
#
# ANCHORED AT THE PROJECT ROOT, not $PWD (2026-09-25). The model's shell follows its
# `cd`, and so does every hook payload's cwd (finding 2 of
# rationale/2026-09-25-session-plugin-usage-review.md). Written under $PWD, a command run
# from app/Models put the sentinel where no reader at the root looked; read from the
# payload cwd, a sentinel at the root was invisible to a hook fired from app/Models —
# both read as "no sentinel", which silently means every voice is eligible.
# Writer and readers now resolve the same root through the shared state-root block
# (pasted below, byte-identical to templates/blocks/state-root.md — pc_shared_blocks).
#
# USAGE
#   phase-sentinel.sh write <phase> --owner <plugin:command> [--session <id>] [--cwd <dir>]
#   phase-sentinel.sh clear [--cwd <dir>]
#
#   <phase>     one of: understand shape decide plan build verify review ship
#   --owner     the command declaring the phase, e.g. task-runner:run (required on write)
#   --session   this session's id. OPTIONAL and you should pass it: the reader compares
#               it before standing down, so without it a sentinel written by one session
#               silences reminder hooks in every other session sharing the .claude/ dir.
#               Omitting it draws a warning on stderr rather than a failure, because a
#               caller that genuinely cannot resolve its session id is better off with a
#               session-blind sentinel than with none.
#   --cwd       any directory of the project (default: $PWD); must already exist. The
#               sentinel lands at its root: the git toplevel, else CLAUDE_PROJECT_DIR
#               when the directory is under it, else the directory itself.
#
# Exit: 0 wrote/cleared (clearing an absent sentinel is success), 3 usage.
#
# WHAT IT DOES NOT DO, stated because the finding it closes is about a gap between a
# mechanism and what people believe it covers:
#   - It does not CLEAR anything on its own. Each entry command still owns removing the
#     sentinel it wrote, on every path including abandonment; the reader's 120-minute
#     mtime TTL is the only backstop and it is a backstop, not a lifecycle.
#   - It does not check that the CALLER owns the phase it is writing, or that the phase
#     it is clearing is its own. One writer stamping over another's is invisible here.
#   - It is not a gate. No check makes any command call this instead of writing the JSON
#     by hand; the four command bodies naming it is the whole of the enforcement.
#     **Standing: recorded.**
#   - The reader-side half — whether a hook that reads the sentinel actually honours the
#     verdict on every branch — is agent-graded, as `pc_phase_guard`'s header says.

# --- state root ----------------------------------------------------------------
# Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
# 2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
# its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
# at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
# the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
# the caller's spelling and path-prefix comparisons still hold); outside git,
# CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
# nothing and status 1 — the caller exits rather than resurrect a deleted project.
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

PROG=phase-sentinel
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }

# The arc, in order. Must stay identical to cc_phase_ix in templates/blocks/phase-guard.md
# — that function is the reader, this list is the writer, and a phase in one and not the
# other is a sentinel that silently means nothing.
PHASES="understand shape decide plan build verify review ship"

cmd="${1:-}"; shift 2>/dev/null || true
phase=""; owner=""; session=""; cwd="$PWD"

case "$cmd" in
  write)
    phase="${1:-}"; shift 2>/dev/null || true
    [ -n "$phase" ] || usage "write requires a phase (one of: $PHASES)"
    case "$phase" in -*) usage "write requires a phase before its flags (got: $phase)" ;; esac
    ;;
  clear) ;;
  ""|-h|--help)
    printf 'usage: %s write <phase> --owner <plugin:command> [--session <id>] [--cwd <dir>]\n' "$PROG" >&2
    printf '       %s clear [--cwd <dir>]\n' "$PROG" >&2
    printf '       phases: %s\n' "$PHASES" >&2
    exit 3 ;;
  *) usage "unknown subcommand: $cmd (want write|clear)" ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --owner)   shift; [ $# -gt 0 ] || usage "--owner requires a value"; owner="$1"; shift ;;
    --owner=*)   owner="${1#--owner=}"; shift ;;
    --session) shift; [ $# -gt 0 ] || usage "--session requires a value"; session="$1"; shift ;;
    --session=*) session="${1#--session=}"; shift ;;
    --cwd)     shift; [ $# -gt 0 ] || usage "--cwd requires a value"; cwd="$1"; shift ;;
    --cwd=*)     cwd="${1#--cwd=}"; shift ;;
    *) usage "unknown argument: $1" ;;
  esac
done

[ -d "$cwd" ] || usage "--cwd is not a directory: $cwd"
root=$(cc_state_root "$cwd") || usage "cannot resolve a project root from: $cwd"
sentinel="$root/.claude/cc-phase.json"

if [ "$cmd" = clear ]; then
  rm -f "$sentinel" 2>/dev/null
  printf '%s: cleared %s\n' "$PROG" "$sentinel" >&2
  exit 0
fi

ok=0
for p in $PHASES; do [ "$phase" = "$p" ] && ok=1; done
# A refusal, not a silent write. An unknown phase scores 0 in the reader's ordering
# table and disables turn-taking without saying so — the failure this check exists for.
[ "$ok" = 1 ] || usage "unknown phase '$phase' (want one of: $PHASES)"
[ -n "$owner" ] || usage "write requires --owner <plugin:command>"

[ -n "$session" ] || printf '%s: no --session given; the sentinel will apply to every session sharing %s/.claude/\n' "$PROG" "$root" >&2

mkdir -p "$root/.claude" 2>/dev/null || usage "cannot create $root/.claude"

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null) || started_at=""

# Written with printf and %s substitution rather than jq: this runs from a command body
# on a machine that may not have jq, and the four values are short flat strings. Quotes
# and backslashes in them would break the JSON, so they are stripped — a phase is from a
# closed list, and an owner or session id carrying a quote is a caller bug, not a value
# worth preserving into a file the reader must be able to parse.
scrub() { printf '%s' "$1" | tr -d '"\\' | tr -d '\000-\037'; }
{
  printf '{"phase":"%s","owner":"%s"' "$(scrub "$phase")" "$(scrub "$owner")"
  [ -n "$session" ]    && printf ',"session_id":"%s"' "$(scrub "$session")"
  [ -n "$started_at" ] && printf ',"started_at":"%s"' "$started_at"
  printf '}\n'
} > "$sentinel" 2>/dev/null || usage "cannot write $sentinel"

printf '%s: wrote %s (phase=%s owner=%s)\n' "$PROG" "$sentinel" "$phase" "$owner" >&2
exit 0
