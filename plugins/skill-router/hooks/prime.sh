#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
# SessionStart primer. Sniffs the repo's manifests directly and injects a
# one-line index of the skills relevant to this stack, filtered to installed
# plugins. Does NOT read stack-scan — that is a conversational skill with no
# persisted output a hook could read. Fail-open: any error exits silently.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  [ -d "$cwd" ] || exit 0

  plugins_dir=""
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && plugins_dir="$(dirname "$CLAUDE_PLUGIN_ROOT")"
  installed() { # $1 owning_plugin — include-if-uncertain
    [ -z "$plugins_dir" ] && return 0
    [ -d "$plugins_dir/$1" ] && return 0
    return 1
  }

  skills=""
  add() { # $1 skill, $2 owning_plugin
    installed "$2" || return 0
    case " $skills " in *" $1 "*) return 0 ;; esac
    skills="$skills $1"
  }

  # Bounded checks — maxdepth caps cost, -print -quit stops at the first hit.
  has()     { find "$cwd" -maxdepth 3 -name "$1" -print -quit 2>/dev/null | grep -q . ; }
  has_dir() { find "$cwd" -maxdepth 3 -type d -name "$1" -print -quit 2>/dev/null | grep -q . ; }

  [ -f "$cwd/composer.json" ] && add package-hygiene packages
  [ -f "$cwd/package.json" ]  && add package-hygiene packages
  if has '*.sql' || has_dir migrations; then add sql-best-practices sql; fi
  if has '*.tsx' || has '*.jsx'; then add ui-ux-stack ui-ux; add a11y-audit a11y; fi
  if [ -f "$cwd/package.json" ] && grep -qE '"(react|vue|@?tailwind)' "$cwd/package.json" 2>/dev/null; then
    add ui-ux-stack ui-ux
  fi
  if has 'Dockerfile*' || has 'docker-compose*.yml' || has 'compose*.yml'; then add docker-best-practices dev-env; fi
  if has_dir tests || has '*.test.*' || has '*.spec.*'; then add testing-best-practices testing; fi

  skills="${skills# }"
  [ -n "$skills" ] || exit 0
  csv=$(printf '%s' "$skills" | tr ' ' ',' | sed 's/,/, /g')
  printf '[skill-router] Repo-relevant skills this session: %s. Load each when you touch its surface.\n' "$csv"
} 2>/dev/null
exit 0
