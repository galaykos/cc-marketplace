#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even under a
# stripped or broken PATH, where `env bash` itself exits 127.
#
# Review-debt nudge. ADVISORY: one line of additionalContext on a user prompt when the
# code changed since this context's last review is big enough, or sensitive enough, that
# an independent pass is worth asking for. It never blocks and it never reviews.
#
# WHY THIS EXISTS. Measured 2026-09-25 (rationale/2026-09-25-session-plugin-usage-review.md,
# finding 7): one inline session shipped ~40 task-list items over 22 days — a second auth
# guard, impersonation with an audit trail, invite and API tokens, encrypted credentials —
# and dispatched ZERO reviewer agents. Its tests, PHPStan and CI were green on every item.
# In the same weeks a sibling session's pipeline reviewers caught what those tools had
# passed: API keys in logs, a race that overwrote a failure with "succeeded", a refusal
# detector firing on ordinary words. That session lacked the prompt, not the tools: its
# prompts ("proceed next recommended") carry no keyword a prompt router can match, and the
# per-edit nudges never saw its writes (finding 1). So this measures the DIFF, not the words.
#
# THE RULE, per context (keyed on cksum(transcript_path)):
#   - base: `<root>/.claude/code-review/review-base-<ctx>` holds a commit. The first prompt
#     with no base records HEAD and says nothing — the nudge counts only what THIS context
#     wrote, never the history it walked into.
#   - changed = `git diff --name-only <base>` (commits since base plus the working tree),
#     minus *.md, lockfiles, `.claude/`, `taskmaster-docs/` and generated/vendor dirs.
#   - speak when changed >= 8 files, or >= 1 path matches the auth-surface pattern below.
#   - ONCE PER HEAD: re-fire only after HEAD moves AND the count grew past what last fired.
#   - a review moves the base to HEAD: an Agent/Task dispatch whose subagent_type ends in
#     `reviewer` or sits in `security:` / `code-review:`, a Skill call of code-review:review,
#     security:review or the host's built-in code-review / security-review, or a prompt the
#     user typed as one of those slash commands (a typed command never reaches PostToolUse,
#     and without this the user who ran the review this nudge asks for would be nudged again).
#
# WHY UserPromptSubmit, not Stop as the review table first proposed: a Stop hook reaches the
# model only by blocking, and blocking on review debt would repeat finding 4 (a completion
# gate blocking a correctly-waiting turn). A prompt-time line costs nothing when ignored.
#
# SILENT, and why:
#   - outside a git work tree, or before the first commit — there is no diff to measure;
#   - under an active task-runner run (`<root>/.claude/task-runner/active-run.json`): runs
#     carry their own reviewer discipline, so each prompt there also moves the base to HEAD,
#     or the whole run's diff would be charged to the first prompt after it;
#   - off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
#     CC_REVIEW_NUDGE=off silences only this one.
#
# CHEAP ON THE SILENT PATH: the state root (one `git rev-parse`), HEAD (a second), a stat of
# the run marker and two one-line reads. The diff runs at most once per HEAD. Git runs with
# GIT_OPTIONAL_LOCKS=0 so it never contends with the model's own `git` for index.lock.
#
# LIMITATION (honest scope — the four laws, see
# .claude/skills/authoring-skills/SKILL.md (in the marketplace repository) "The four laws"):
#   - COMMIT-DRIVEN. The diff is evaluated once per HEAD, so work that stays uncommitted is
#     seen only at the next commit; a session that commits once at the end is nudged once,
#     at the end. The measured session committed per item, which is the shape this serves.
#   - A review is recognised by NAME, not by what it covered. A reviewer dispatched on one
#     file moves the base past twenty; a review done outside these channels (a PR review,
#     a manual read) is invisible and the nudge still fires.
#   - The auth-surface pattern is a path regex: `tokens.css` (design tokens) matches it,
#     and an auth bug in `app/Services/Billing.php` does not.
#   - A base that stops being an ancestor of HEAD (branch switch, rebase, amend) is reset to
#     HEAD silently rather than diffed across branches — an amended commit's changes are lost
#     to the count.
#   - A stale active-run.json (a crashed run) keeps this silent until the file is removed.
#   - Whether a nudged review was WORTH it is agent-graded; nothing here reads the verdict.
#
# FAIL-OPEN: missing jq/git, unreadable state, or any error exits 0 with no output.

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

{
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v git >/dev/null 2>&1 || exit 0
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  case "${CC_REVIEW_NUDGE:-on}" in off) exit 0 ;; esac

  input=$(cat)
  # The event name is read, and inferred from the payload's shape when absent, so one
  # missing field cannot silently disable both halves.
  event=$(printf '%s' "$input" | jq -r '.hook_event_name
    // (if .tool_name then "PostToolUse" elif has("prompt") then "UserPromptSubmit" else empty end)' 2>/dev/null) || exit 0

  # Is this a review? Decided before any git call: almost every Agent and Skill call is not.
  reviewed=0
  case "$event" in
    PostToolUse)
      tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
      case "$tool" in
        Agent|Task)
          who=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
          case "$who" in *reviewer|security:*|code-review:*) ;; *) exit 0 ;; esac ;;
        Skill)
          who=$(printf '%s' "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)
          case "${who#/}" in code-review:review|security:review|code-review|security-review) ;; *) exit 0 ;; esac ;;
        *) exit 0 ;;
      esac
      reviewed=1 ;;
    UserPromptSubmit)
      prompt=$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null)
      case "$prompt" in
        /code-review:review|"/code-review:review "*|/security:review|"/security:review "*) reviewed=1 ;;
        /code-review|"/code-review "*|/security-review|"/security-review "*) reviewed=1 ;;
      esac ;;
    *) exit 0 ;;
  esac

  tp=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$tp" ] || exit 0
  # A subagent's own dispatches belong to a context no prompt ever reads back.
  case "$tp" in */subagents/*) exit 0 ;; esac
  ctx=$(printf '%s' "$tp" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  export GIT_OPTIONAL_LOCKS=0
  # Not a work tree, or no commit yet: nothing to diff, and no state is written.
  head=$(git -C "$root" rev-parse --verify -q HEAD 2>/dev/null) || exit 0
  [ -n "$head" ] || exit 0

  dir="$root/.claude/code-review"
  base_f="$dir/review-base-$ctx"
  seen_f="$dir/review-seen-$ctx"
  # seen_f is "<last HEAD evaluated> <count that last fired>"; base_f is the base commit.
  record() {
    mkdir -p "$dir" 2>/dev/null || exit 0
    [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself
    printf '%s\n' "$1" > "$base_f" 2>/dev/null
    printf '%s 0\n' "$1" > "$seen_f" 2>/dev/null
    find "$dir" -maxdepth 1 -name 'review-*' -type f -mtime +14 -exec rm -f {} + 2>/dev/null
  }

  [ "$reviewed" = 1 ] && { record "$head"; exit 0; }
  [ -e "$root/.claude/task-runner/active-run.json" ] && { record "$head"; exit 0; }

  base=""; seen_head=""; fired=0
  [ -r "$base_f" ] && read -r base _ < "$base_f"
  [ -n "$base" ] || { record "$head"; exit 0; }               # first prompt: baseline, silent
  [ -r "$seen_f" ] && read -r seen_head fired _ < "$seen_f"
  [ "$seen_head" = "$head" ] && exit 0                         # this HEAD is already judged
  case "$fired" in ''|*[!0-9]*) fired=0 ;; esac

  # A base off HEAD's history (branch switch, rebase, amend) would diff across branches.
  git -C "$root" merge-base --is-ancestor "$base" "$head" 2>/dev/null || { record "$head"; exit 0; }

  changed=$(git -C "$root" -c core.quotepath=off diff --name-only "$base" -- 2>/dev/null \
    | grep -vE '\.md$|(^|/)\.claude/|(^|/)taskmaster-docs/|(^|/)(node_modules|vendor|dist|build|\.next|coverage|generated|__generated__)/' \
    | grep -vE '(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|composer\.lock|Gemfile\.lock|Cargo\.lock|poetry\.lock|Pipfile\.lock|uv\.lock|go\.sum|bun\.lockb?|mix\.lock|flake\.lock)$')
  count=$(printf '%s\n' "$changed" | grep -c .)
  # `auth` but not `author`: a publishing app's AuthorController is not an auth surface.
  auth=$(printf '%s\n' "$changed" \
    | grep -iE 'auth([^o]|$)|authori[sz]|login|passw|token|secret|credential|polic|permission|role|guard|middleware|impersonat|session|oauth|webhook|payment|crypt|(^|/)migrations/')
  nauth=$(printf '%s\n' "$auth" | grep -c .)

  if { [ "$count" -ge 8 ] || [ "$nauth" -ge 1 ]; } && [ "$count" -gt "$fired" ]; then
    printf '%s %s\n' "$head" "$count" > "$seen_f" 2>/dev/null || exit 0
  else
    printf '%s %s\n' "$head" "$fired" > "$seen_f" 2>/dev/null
    exit 0
  fi

  short=$(git -C "$root" rev-parse --short "$base" 2>/dev/null) || short="$base"
  paths=""
  if [ "$nauth" -ge 1 ]; then
    paths=$(printf '%s\n' "$auth" | head -3 | paste -sd, - | sed 's/,/, /g')
    [ "$nauth" -gt 3 ] && paths="$paths, +$((nauth - 3)) more"
    paths=" (auth-surface: $paths)"
  fi
  [ "$count" -eq 1 ] && noun="file has" || noun="files have"
  msg="[code-review] $count changed $noun had no review in this session since $short$paths. Run /code-review:review $short..HEAD, or say in one line why not. CC_REVIEW_NUDGE=off silences this nudge."

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$m}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
