#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a stripped PATH.
# PostToolUse on Read for the `overseer` plugin — the read ledger behind the read-before-record
# gate. While a program is open in the session's project, every Read of a regular file appends
# one row, "<epoch>\t<session_id>\t<physical path>", to <project>/.claude/overseer/.reads.
# `program.sh evidence add --file X` then refuses a file no Read in THIS session touched since
# X last changed: a screenshot nobody opened proves nothing, and before this ledger "the file
# exists, not what it shows" was the plugin's own unenforceable row. Lifted from the
# verify-gate in anthropics/cwc-long-running-agents (a PreToolUse deny unless the evidence
# file was Read first); here the deny sits in program.sh, which is where accept already lives.
# Prints NOTHING on stdout — zero context cost per Read. Silent when no program is open in
# the project (every non-overseer project pays nothing), on a relative path that does not
# resolve, on a missing file, and on any error. Killed (timeout 5s): the row is lost and
# program.sh says the gate is inactive for the session, never that the file was read.
# LIMITATION: a Read proves the bytes reached a context, not that a judgment was made on
# them; that half stays agent-graded. A subagent shares the parent's session_id, so a
# browser-tester's Read counts for the session that dispatched it — intended: the walk may
# be delegated, the look must happen somewhere in this session.
# context-key-ok: session_id is recorded as a ledger FIELD that program.sh matches against
# CLAUDE_CODE_SESSION_ID; no one-shot marker is keyed on it.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
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
