#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
#
# clarify-gate.sh — OPT-IN PreToolUse gate on Edit|Write|MultiEdit. OFF BY
# DEFAULT: does nothing unless CC_CLARIFY_GATE=block is set. When enabled, it
# denies the FIRST code write of a session in which remind.sh saw a work-shaped
# prompt (the cc-workprompt marker), once per session, forcing one turn of
# clarify-or-declare-trivial before code exists. The deny is the reflection
# mechanism itself — the gate does not (cannot) verify a question round
# actually happened; it buys one deliberate turn, nothing more. Standing when
# enabled: gate. Standing when disabled (the default): unenforceable, and this
# header says so on purpose.
#
# Doctrine note: command-guard reserves deny for irreversible loss; a first
# code edit is reversible, which is why this ships OFF and opt-in — the owner
# chooses the stricter contract, it is not imposed. Under hands-off goal runs
# the model should state assumptions instead of asking (see reason text).
# Pattern: comment-discipline/hooks/scan.sh — the once-per-session bound is
# recorded BEFORE the deny; a bound that cannot be recorded means no block.
# Fail-open everywhere; CC_REMIND=off also silences it. Honest limitation:
# hook input cannot distinguish main-session from subagent edits, so when the
# main model's first move is to delegate, the one deny can land on a worker's
# first write instead of the main session's.
# CC_CLARIFY_GATE / CC_REMIND unset: the /config options cc_clarify_gate / cc_remind decide.

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

{
  case "$(cc_option CC_CLARIFY_GATE off)" in block) : ;; *) exit 0 ;; esac
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null) || exit 0
  [ -n "$sid" ] || exit 0
  sidh=$(printf '%s' "$sid" | cksum | cut -d' ' -f1)

  pending="${TMPDIR:-/tmp}/cc-workprompt-$sidh"
  [ -d "$pending" ] || exit 0

  gated="${TMPDIR:-/tmp}/cc-clarify-gated-$sidh"
  mkdir "$gated" 2>/dev/null || exit 0
  rmdir "$pending" 2>/dev/null
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-clarify-gated-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null

  jq -cn --arg r '[taskmaster] First code write on a work-shaped prompt with no clarification round. Before re-applying this edit: run one batched AskUserQuestion round on the open unknowns — or, if the task is genuinely trivial or this is a hands-off goal run, state the assumptions you are proceeding on in one line. This gate fires once per session (opt-in via CC_CLARIFY_GATE=block).' \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
} 2>/dev/null
exit 0
