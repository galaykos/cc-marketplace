#!/bin/bash
# model-gate.sh — PreToolUse on Agent/Task: while an overseer program is open in the project, denies a call whose prompt carries a `MODEL: <m>` line (a dispatch file) when the model it will run differs: `model` as passed, else the agent type's frontmatter default when every installed copy agrees; `MODEL: inherit` needs neither to name a model. One line, the deny JSON; silent otherwise.
# Misses: a prompt with no MODEL: line (taskmaster's and task-runner's own seats), a frontmatter it cannot find (the call must then pass model: itself), and any Agent call the host runs no hook for. Fails open on any error or a kill (timeout 5s).
# Why, limits, history: rationale/derivations/plugin-overseer.md § plugins/overseer/hooks/model-gate.sh
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Agent|Task) ;; *) exit 0 ;; esac
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || root="$cwd"
  [ -s "$root/.cc-artifacts/overseer/program.json" ] || exit 0
  # The same reading as program.sh dispatch check: the first line-start MODEL:, a sentence-ending period dropped.
  want=$(printf '%s' "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null | grep -m1 -oE '^MODEL: *[a-z0-9.-]+' | sed -E 's/^MODEL: *//; s/\.+$//')
  [ -n "$want" ] || exit 0
  passed=$(printf '%s' "$input" | jq -r '.tool_input.model // empty' 2>/dev/null)
  type=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)
  fm=""
  if [ -z "$passed" ] && [ -n "$type" ]; then
    # An agent file with no model: key inherits; copies that disagree (two cached versions) leave the default unknown.
    fm=$(case "$type" in
          *:*) ls "$HOME"/.claude/plugins/cache/*/"${type%%:*}"/*/agents/"${type#*:}".md 2>/dev/null ;;
          *) ls "$root/.claude/agents/$type.md" "$HOME/.claude/agents/$type.md" 2>/dev/null ;;
         esac | while IFS= read -r a; do
           awk '/^---[[:space:]]*$/ { c++; if (c == 2) exit; next } c == 1 && /^model:/ { sub(/^model:[[:space:]]*/, ""); gsub(/["\047[:space:]]/, ""); print; m = 1; exit } END { if (!m) print "inherit" }' "$a"
         done | sort -u)
    [ "$(printf '%s\n' "$fm" | sed '/^$/d' | wc -l | tr -d ' ')" = 1 ] || fm=""
  fi
  if [ "$want" = inherit ]; then
    [ -z "$passed" ] && { [ -z "$fm" ] || [ "$fm" = inherit ]; } && exit 0
    if [ -n "$passed" ]; then said="the Agent call passes model: $passed"; fix="pass no model in the Agent call"
    else said="$type pins model: $fm in its frontmatter"; fix="send it to an agent type that inherits, or set MODEL: $fm and re-run dispatch check"; fi
  else
    [ "${passed:-$fm}" = "$want" ] && exit 0
    if [ -n "$passed" ]; then said="the Agent call passes model: $passed"
    elif [ -n "$fm" ]; then said="the Agent call passes no model, so $type runs its frontmatter default ($fm)"
    else said="the Agent call passes no model and ${type:-the default agent}'s frontmatter default could not be read"; fi
    fix="pass model: \"$want\" in the Agent call"
  fi
  reason="overseer: this dispatch's MODEL: line says $want, but $said — $fix (dispatch-prompts.md § The model per seat)."
  jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
