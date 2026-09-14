#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a broken PATH.
#
# PreToolUse guard against AI ATTRIBUTION in git history. It denies a `git
# commit` / `git merge` / `git tag` / `gh pr create|merge` / `gh release` whose
# message carries a `Co-Authored-By: Claude …` trailer or a "Generated with
# Claude Code" line, and a Write/Edit that plants the same text into a git
# message file (`COMMIT_EDITMSG`, `MERGE_MSG`, anything under `.git/`).
#
# The failure it exists for: the host setting `attribution.commit: ""` in
# ~/.claude/settings.json is honoured by the host's OWN trailer injection and by
# nothing else. The model still writes the trailer from habit — observed on
# Claude Code 2.1.266 on 2026-09-09 with the setting present since 2026-09-03 —
# and prose in a skill ("never add AI attribution", the since-dropped terse-commit) did not stop
# it. A rule with no reader is recorded, not enforced; this is the reader.
#
# Tiering (deny, never ask): the trailer is never what the user wants when they
# installed this, the fix is mechanical (drop the lines, re-run), and an `ask`
# would hand the human the same click the setting was supposed to remove.
#
# What it does NOT catch, stated: a message read from a file the model wrote
# with a tool this hook is not matched on, `git commit -F` on a pre-existing
# file, a trailer added by `git config trailer.*` or a `prepare-commit-msg` hook
# in the repo, a rewrite via `git filter-repo`, and any commit made outside the
# session. Silence means "no known shape matched", not "history is clean".
#
# CLAUDE_AI_TRAILER, read from the hook's own environment:
#   unset   deny, as above
#   allow   disabled — for a user who WANTS the trailer (then also clear the
#           host setting; this hook and that setting agree by default)
#
# Fail-open by construction: missing jq, unparseable input, any internal error
# allows the call. A guard that breaks the session gets uninstalled.
#
# CLI mode for tests and manual checks:
#   no-ai-trailer.sh --check '<command>'   exit 0 allow, exit 2 deny

set -u

# grep reads one line at a time, so `.*` never crosses a newline here.
# LC_ALL=C: the emoji is matched as a byte sequence, locale-independent.
export LC_ALL=C
TRAILER_RE='co-authored-by:.*(claude|anthropic)|generated with \[?claude code|🤖 generated with'
GIT_WRITE_RE='(^|[^a-z0-9_-])(git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+|[[:space:]]+-[cC][^[:space:]]*)*[[:space:]]+(commit|merge|tag|notes|rebase|cherry-pick|am)|gh[[:space:]]+(pr|release|repo)[[:space:]]+(create|merge|edit|comment))([[:space:]]|$)'

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# 0 = clean, 1 = trailer present in a git-writing command
classify_command() {
  local c; c=$(lc "$1")
  printf '%s' "$c" | grep -qE "$TRAILER_RE" || return 0
  printf '%s' "$c" | grep -qE "$GIT_WRITE_RE" || return 0
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
  printf '%s' 'AI attribution refused by git-workflow: no "Co-Authored-By: Claude …" trailer and no "Generated with Claude Code" line goes into a commit, merge, tag or PR. Drop those lines from the message and run the same command again. Do not move the message into a file to route around this.'
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
