#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# PostToolUse: append each state-mutating action to the ledger, one row per action. A row carries
# NO seq — an action's seq is its 1-based ordinal among action rows, assigned at read time; a
# single short-line append is POSIX-atomic under O_APPEND, so concurrent tool calls need no lock
# (portable; macOS has no flock). Never logs the model's own writes to the state dir (regress
# guard). Fail-open: any error or a missing jq exits 0.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  [ -n "$tool" ] || exit 0
  agent=$(printf '%s' "$input" | jq -r '.agent_id // "main"' 2>/dev/null)

  dir="$cwd/.claude/intent-guard"

  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
      # Regress guard: never log a write to the state dir (the model's own attest.json write).
      case "$fp" in
        "$dir"/*|"$dir") exit 0 ;;
      esac
      target="$fp"
      ;;
    Bash)
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      first=${cmd%%[[:space:]]*}; first=${first##*/}
      case "$first" in
        ls|cat|grep|rg|find|pwd|echo|which|head|tail|wc) exit 0 ;;
        git)
          sub=$(printf '%s' "$cmd" | awk '{print $2}')
          case "$sub" in status|log|diff|show|branch|remote) exit 0 ;; esac
          ;;
      esac
      target=$(printf '%s' "$cmd" | cut -c1-120)
      ;;
    Agent)
      target=$(printf '%s' "$input" | jq -r '(.tool_input.subagent_type // .tool_input.description // "subagent")' 2>/dev/null)
      ;;
    *) exit 0 ;;
  esac
  [ -n "$target" ] || target="$tool"

  mkdir -p "$dir" 2>/dev/null || exit 0
  ledger="$dir/ledger.jsonl"
  attest="$dir/attest.json"

  # Atomic single-line append (O_APPEND); no seq field, no lock.
  row=$(jq -cn --arg t "$tool" --arg g "$target" --arg a "$agent" \
    '{kind:"action",tool:$t,target:$g,agent_id:$a}' 2>/dev/null) || exit 0
  printf '%s\n' "$row" >> "$ledger" 2>/dev/null

  # Conditional nudge every 5th unattested action (seq count = action-row count).
  maxseq=$(grep -c '"kind":"action"' "$ledger" 2>/dev/null || echo 0)
  through=0
  if [ -f "$attest" ] && jq empty "$attest" 2>/dev/null; then
    through=$(jq -r '(.through_seq // 0)' "$attest" 2>/dev/null)
  fi
  unatt=$(( maxseq - through ))
  if [ "$unatt" -gt 0 ] 2>/dev/null && [ $(( unatt % 5 )) -eq 0 ]; then
    printf 'intent-guard: %s actions await attestation vs the declared intent.\n' "$unatt"
  fi
} 2>/dev/null
exit 0
