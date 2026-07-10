#!/usr/bin/env bash
# Shared per-plugin checks, sourced by validate.sh (full sweep) and
# authoring-guard.sh (single edited file). Pure: sourcing runs no code, functions
# close over no caller globals (no err/fail/allow_md), and take all inputs as args.

# pc_skill_budget <skill_md_path>
# On a body-length violation: prints "budget <path> <n>" and returns 1.
# Clean or missing file: prints nothing, returns 0.
pc_skill_budget() {
  local f="$1" n
  [ -f "$f" ] || return 0
  n=$(awk '/^---$/{c++; next} c>=2' "$f" | wc -l | tr -d ' ')
  if [ "$n" -lt 100 ] || [ "$n" -gt 150 ]; then
    printf 'budget %s %s\n' "$f" "$n"
    return 1
  fi
  return 0
}

# pc_doc_location <plugins_relative_md> <allow_regex>
# $1 is a repo-relative path beginning "plugins/<name>/…". Mirrors validate.sh:
# strips "plugins/*/" and greps the caller-supplied allow regex.
# On violation: prints "doc-location <path>" and returns 1. Clean: returns 0.
pc_doc_location() {
  local mdf="$1" allow="$2" rel
  rel=${mdf#plugins/*/}
  printf '%s\n' "$rel" | grep -qE "$allow" && return 0
  printf 'doc-location %s\n' "$mdf"
  return 1
}
