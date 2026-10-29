#!/bin/bash
# no-ai-trailer.sh — PreToolUse: denies a git commit/merge/tag/notes/rebase/cherry-pick/am or gh pr/release/repo create/merge/edit/comment at a command position whose text holds a `Co-Authored-By: Claude …` trailer or a "Generated with Claude Code" line, and a Write/Edit planting one in a git message file. Off: CLAUDE_AI_TRAILER=allow for that one command — or for good, by a user who wants the trailer. Fails open. `--check '<command>'`: exit 0 allow, 2 deny.
# Misses: a message file written by an unmatched tool, `git commit -F` on an existing file, `git config trailer.*` or prepare-commit-msg trailers, filter-repo rewrites, commits outside the session. Denies on purpose: prose quoting a full trailer line, and a `(` in quoted text before one.
# Why, limits, history: rationale/derivations/plugin-git-workflow.md § plugins/git-workflow/hooks/no-ai-trailer.sh

set -u

# LC_ALL=C matches the emoji as bytes; grep reads line by line, so `.*` never crosses a newline.
export LC_ALL=C
TRAILER_RE='co-authored-by:.*(claude|anthropic)|generated with \[?claude code|🤖 generated with'
# A path prefix must end in `/`; the option run between git and the verb takes dash, path-like and assignment tokens, never a bare word (`git log | grep commit` passes).
GIT_WRITE_RE='(^|[;&|`()]|\$\()[[:space:]]*(([a-z_][a-z0-9_]*=[^[:space:]]*|bash|sh|zsh|dash|ksh|eval|exec|command|sudo|doas|env|nohup|timeout|nice|time|xargs|then|do|else|elif|if|while|until|-[-a-z0-9]*|[0-9]+|"|'"'"')[[:space:]]*)*(([^[:space:]]*/)?git([[:space:]]+(-[^[:space:]]*|[/.~][^[:space:]]*|[^[:space:]]*=[^[:space:]]*))*[[:space:]]+(commit|merge|tag|notes|rebase|cherry-pick|am)|([^[:space:]]*/)?gh[[:space:]]+(pr|release|repo)[[:space:]]+(create|merge|edit|comment))([[:space:]]|$)'

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# 0 = clean, 1 = trailer present in a git-writing command
classify_command() {
  local c; c=$(lc "$1")
  printf '%s' "$c" | grep -qE "$TRAILER_RE" || return 0
  # Keep the quote tokens in GIT_WRITE_RE's prefix: dropping them opens `bash -c "git commit …"` and `eval` as bypasses and leaves the `(` false deny.
  printf '%s' "$c" | tr '\n' ';' | grep -qE "$GIT_WRITE_RE" || return 0
  return 1
}

# 0 = clean, 1 = trailer written into a git message file
classify_file() { # path content
  local p; p=$(lc "$1")
  case "$p" in
    */.git/*|*/commit_editmsg|*/merge_msg|*/squash_msg|*/tag_editmsg|*/pullreq_editmsg|commit_editmsg|merge_msg) ;;
    *) return 0 ;;
  esac
  lc "$2" | grep -qE "$TRAILER_RE" || return 0
  return 1
}

reason() {
  printf '%s' 'git-workflow blocked AI attribution in this commit, merge, tag or PR: remove the "Co-Authored-By: Claude …" trailer and any "Generated with Claude Code" line, then run the same command again (not through a message file). CLAUDE_AI_TRAILER=allow, set by the user, turns this guard off.'
}

emit_deny() {
  jq -cn --arg r "$(reason)" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
}

if [ "${1:-}" = "--check" ]; then
  if classify_command "${2:-}"; then printf 'ALLOW\n'; exit 0; fi
  printf 'DENY  %s\n' "$(reason)"; exit 2
fi

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  [ "$(lc "${CLAUDE_AI_TRAILER:-}")" = "allow" ] && exit 0
  local input tool cmd path content
  input=$(cat 2>/dev/null) || exit 0
  [ -n "$input" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit)
      path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
      [ -n "$path" ] || exit 0
      content=$(printf '%s' "$input" | jq -r '
        [ .tool_input.content // empty,
          .tool_input.new_string // empty,
          ((.tool_input.edits // []) | map(.new_string // empty) | join("\n")) ]
        | map(select(. != "")) | join("\n")' 2>/dev/null) || exit 0
      classify_file "$path" "$content" && exit 0
      emit_deny; exit 0 ;;
    *)
      cmd=$(printf '%s' "$input" | jq -r '
        [ .tool_input.command // empty,
          .tool_input.script // empty,
          .tool_input.cmd // empty ] | map(select(. != "")) | join(" ; ")' 2>/dev/null) || exit 0
      [ -n "$cmd" ] || exit 0
      classify_command "$cmd" && exit 0
      emit_deny; exit 0 ;;
  esac
}

main
exit 0
