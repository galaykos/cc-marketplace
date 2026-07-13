#!/bin/bash
# Absolute-path shebang: fail-open must hold under a stripped PATH.
# PostToolUse: append each state-mutating action's touched target to the ephemeral per-turn
# turn.log — one plain line per action. Read-only recon is skipped. Never logs the model's own
# writes to the state dir (regress guard). No nudge, no counting. Fail-open: any error or a
# missing jq exits 0.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  [ -n "$tool" ] || exit 0

  dir="$cwd/.claude/intent-guard"

  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)
      # Regress guard: never log a write to the state dir (the model's own state writes).
      case "$fp" in
        "$dir"/*|"$dir") exit 0 ;;
      esac
      target="$fp"
      ;;
    Bash)
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      # Peel a leading transparent command wrapper (e.g. a sandbox shim like `rtk`) so the
      # read-only skip-list matches the real command whether or not the wrapper is present —
      # the recorded command can arrive as `rtk git …` in one environment and `git …` in
      # another. Fail-safe: a wrapper carrying its own options just leaves the command logged
      # (over-log, never under-log). Add wrapper names to the case to cover other environments.
      cmd=${cmd#"${cmd%%[![:space:]]*}"}                       # ltrim
      case "${cmd%%[[:space:]]*}" in
        rtk|*/rtk)
          cmd=${cmd#*[[:space:]]}                              # drop the wrapper token
          cmd=${cmd#"${cmd%%[![:space:]]*}"}                   # ltrim the remainder
          ;;
      esac
      first=${cmd%%[[:space:]]*}; first=${first##*/}
      case "$first" in
        ls|cat|grep|rg|find|pwd|echo|which|head|tail|wc) exit 0 ;;
        git)
          # Subcommand is the first non-option token after 'git' — skip global options and
          # any values they take (git -C <path>, git -c <k=v>, --git-dir <path>, --no-pager,
          # …) so read-only recon like `git -C <path> status` stays out of the log.
          sub=$(printf '%s\n' "$cmd" | awk '{
            for (i=2; i<=NF; i++) {
              t=$i
              if (t=="-C"||t=="-c"||t=="--git-dir"||t=="--work-tree"||t=="--namespace"||t=="--exec-path"||t=="--super-prefix") { i++; continue }
              if (t ~ /^-/) continue
              print t; exit
            }
          }')
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
  turnlog="$dir/turn.log"

  # Atomic single-line append (O_APPEND under a short line); no seq, no lock, no nudge.
  printf '%s\n' "$target" >> "$turnlog" 2>/dev/null
} 2>/dev/null
exit 0
