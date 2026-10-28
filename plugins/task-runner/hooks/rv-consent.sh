#!/bin/bash
# PreToolUse on Write/Edit/MultiEdit/Bash in a registered (or just-closed) run: asks the user before a discretionary reduction is recorded: an rv-skip-*.json or reductions/*.json write, a redirect into rv-skip-*.json, review-skip.sh or reduction-record.sh with --reason. --exempt never asks.
# Misses: a record name held in a variable or a nested $(…). Unverified under auto-accept, bypassPermissions or headless -p, where the ask may deny the record write. Fails open (allow, no prompt).
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/hooks/rv-consent.sh

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

{
  command -v jq >/dev/null 2>&1 || exit 0

  input=$(cat)
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  case "$tool" in Write | Edit | MultiEdit | Bash) ;; *) exit 0 ;; esac

  # Only inside a run, its sentinel read at the project root: an ask outside one trains the click-through it exists to prevent.
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  [ -r "$root/.claude/task-runner/active-run.json" ] || [ -r "$root/.claude/task-runner/closed-run.json" ] || exit 0

  blob=$(printf '%s' "$input" | jq -r '.tool_input // {} | tostring' 2>/dev/null)
  discretionary=0
  # A record being written, or the recorder (which never names the file) run with a reason; `grep` or `rm` of a record is neither.
  case "$tool" in
    Write | Edit | MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      case "$fp" in *rv-skip-*.json | */reductions/*.json) discretionary=1 ;; esac
      ;;
    Bash)
      cmdline=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      if printf '%s' "$cmdline" | grep -qE '(review-skip|reduction-record)\.sh' &&
         printf '%s' "$cmdline" | grep -q -- '--reason'; then
        discretionary=1
      fi
      # Any expansion can build the record name, so it runs to `.json` short of a pipe or separator outside a $(…) or backtick span.
      span='([^|;&]|\$\([^)]*\)|`[^`]*`)*'
      printf '%s' "$cmdline" | grep -qE ">[[:space:]]*${span}rv-skip-${span}\\.json" && discretionary=1
      ;;
  esac
  printf '%s' "$blob" | grep -q -- '--exempt' && discretionary=0
  [ "$discretionary" -eq 1 ] || exit 0

  # `tostring` backslash-escapes inner quotes; unescape only those, or a Windows path or regex in the shown reason is mangled.
  flat=$(printf '%s' "$blob" | sed 's/\\"/"/g')

  # The id class takes `$ { } :` so a shell-built id such as `bg-${H:0:12}` is shown as written.
  card=$(printf '%s' "$flat" | grep -oE -- '--(card|id) *"?[a-zA-Z0-9._{}:$-]{1,64}' | head -1 |
    sed -E 's/^--(card|id) *"?//')
  if [ -z "$card" ]; then
    card=$(printf '%s' "$flat" | grep -oE 'rv-skip-[a-zA-Z0-9._{}:$-]{1,64}' | head -1 |
      sed -E 's/^rv-skip-//; s/\.json$//')
  fi
  [ -n "$card" ] || card="(unnamed)"

  # {1,201}: BSD grep rejects an interval above 255, silently here. No closing quote, so a long reason is cut at 200, not lost.
  reason=$(printf '%s' "$flat" | grep -oE -- "--reason *\"[^\"]{1,201}|--reason *'[^']{1,201}" | head -1 |
    sed -E "s/^--reason *[\"']//")
  [ "${#reason}" -le 200 ] || reason="${reason:0:200}…"
  [ -n "$reason" ] || reason="no reason given in the command"

  what="the reviewer pass for card"
  printf '%s' "$flat" | grep -q 'reduction-record\.sh' && what="a declared step for"
  msg=$(printf 'Reducing %s %s. Reason: %s\n\nApproving records the reduction and lets the run continue; the completion report must still disclose it. Denying means the full step runs.' "$what" "$card" "$reason")

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$m}}' 2>/dev/null
} 2>/dev/null
exit 0
