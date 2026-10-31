#!/bin/bash
# track-read.sh — PostToolUse on Read: while an overseer program is open in the project, appends "<epoch>\t<session_id>\t<physical path>" per regular file read to <project>/.claude/overseer/.reads, the ledger `program.sh evidence add --file` checks. Prints nothing; silent with no program, an unresolved path, a missing file or any error.
# Misses: whether a judgment was made on what was read (agent-graded); a subagent's Read counts for its parent's session, on purpose; a kill (timeout 5s) loses the row, and program.sh then calls the gate inactive.
# Why, limits, history: rationale/derivations/plugin-overseer.md § plugins/overseer/hooks/track-read.sh

# context-key-ok: session_id is recorded as a ledger FIELD that program.sh matches against
# CLAUDE_CODE_SESSION_ID; no one-shot marker is keyed on it.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  # The matcher's `.*read_file` (an IDE MCP read) carries the same `file_path` key.
  f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$f" ] && [ -n "$sid" ] && [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
  [ -s "$root/.claude/overseer/program.json" ] || exit 0
  case "$f" in /*) ;; *) f="$cwd/$f";; esac
  [ -f "$f" ] || exit 0
  d=$(cd "$(dirname "$f")" 2>/dev/null && pwd -P) || exit 0
  printf '%s\t%s\t%s/%s\n' "$(date +%s)" "$sid" "$d" "$(basename "$f")" >> "$root/.claude/overseer/.reads"
} >/dev/null 2>&1
exit 0
