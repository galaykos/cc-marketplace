#!/bin/bash
# prime.sh — SessionStart, fails open: prints one line naming the skills whose sr_repo_skills rows hold at the project root, filtered to
#   installed plugins. Sourced (subagent-skills.sh), it only defines functions, sr_repo_skills and cc_state_root among them.
# Misses: a CI other than GitHub Actions; a MariaDB outside an image line of a root docker-compose.yml or compose.yml (a single-quoted or variable image value, a .yaml spelling,
#   a subdirectory, a networked server); a workspace's own manifests, read at the repo root instead.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/prime.sh

# Shared block templates/blocks/state-root.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/state-root.md
# cc_state_root <cwd> prints the root that holds hook state: the git toplevel above <cwd>, else
# CLAUDE_PROJECT_DIR when <cwd> is under it, else <cwd>. A <cwd> that no longer exists: no output, status 1.
# --show-cdup, not --show-toplevel: git resolves a symlinked /tmp there, breaking the caller's path-prefix compares.
cc_state_root() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  local up pd="${CLAUDE_PROJECT_DIR:-}"; pd="${pd%/}"
  if up=$(git -C "$1" rev-parse --show-cdup 2>/dev/null); then
    [ -n "$up" ] || { printf '%s\n' "$1"; return 0; }
    (CDPATH= cd -- "$1/$up" 2>/dev/null && pwd) && return 0
  fi
  if [ -n "$pd" ] && [ -d "$pd" ]; then
    case "$1/" in "$pd"/*) printf '%s\n' "$pd"; return 0 ;; esac
  fi
  printf '%s\n' "$1"
}

has()     { find "$SR_ROOT" -maxdepth 3 -name "$1" -print -quit 2>/dev/null | grep -q . ; }
has_dir() { find "$SR_ROOT" -maxdepth 3 -type d -name "$1" -print -quit 2>/dev/null | grep -q . ; }
dep() { # $1 manifest under SR_ROOT, $2 ERE
  [ -f "$SR_ROOT/$1" ] && grep -qE "$2" "$SR_ROOT/$1" 2>/dev/null
}

# sr_repo_skills <project-root> calls the caller's `add <skill> <owning_plugin>` once per row whose evidence holds.
# The rows stay in this file, where pc_prime_coverage and validate.sh read them by path, and mirror coding-entry/references/skill-map.md.
sr_repo_skills() {
  SR_ROOT="$1"
  [ -f "$SR_ROOT/composer.json" ] && add package-hygiene stack-scan
  [ -f "$SR_ROOT/package.json" ]  && add package-hygiene stack-scan
  if has '*.sql' || has_dir migrations; then add sql-best-practices database; fi
  if has '*.tsx' || has '*.jsx'; then add a11y-audit ui-ux; fi

  if dep composer.json '"laravel/framework"'; then add laravel-best-practices laravel
  fi
  { dep composer.json '"inertiajs/inertia-laravel"' || dep package.json '"@inertiajs/'; } \
    && add inertia-best-practices laravel

  if dep package.json '"react-native"'; then add react-native-best-practices web-dev
  fi

  if dep package.json '"next"'; then add nextjs-best-practices web-dev
  fi
  if dep package.json '"vite"'; then add vite-best-practices web-dev
  fi

  if dep package.json '"tailwindcss"' || has 'tailwind.config.*'; then
    add tailwind-best-practices ui-ux
  fi
  [ -f "$SR_ROOT/components.json" ] && add shadcn-best-practices ui-ux
  if has 'Dockerfile*' || has 'docker-compose*.yml' || has 'compose*.yml'; then add docker-best-practices devops; fi
  [ -d "$SR_ROOT/.github/workflows" ] && add devops-practices devops
  { dep docker-compose.yml 'image:[[:space:]]*"?[a-z0-9./-]*mariadb' \
    || dep compose.yml 'image:[[:space:]]*"?[a-z0-9./-]*mariadb'; } \
    && add mariadb-best-practices database
  if has_dir tests || has '*.test.*' || has '*.spec.*'; then add testing-best-practices testing; fi
}

# Sourced (subagent-skills.sh): stop here, with the functions defined and stdin untouched.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$(dirname "$0")/plugins-dir.sh" 2>/dev/null
  command -v pr_resolve_plugins_dir >/dev/null 2>&1 && pr_resolve_plugins_dir
  installed() { # $1 owning_plugin — include-if-uncertain
    command -v pr_plugin_installed >/dev/null 2>&1 || return 0
    pr_plugin_installed "$1"
  }

  skills=""
  add() { # $1 skill, $2 owning_plugin
    installed "$2" || return 0
    case " $skills " in *" $1 "*) return 0 ;; esac
    skills="$skills $1"
  }
  sr_repo_skills "$root"

  skills="${skills# }"
  [ -n "$skills" ] || exit 0
  csv=$(printf '%s' "$skills" | tr ' ' ',' | sed 's/,/, /g')
  printf '[skill-router] Repo-relevant skills this session: %s. Load each when you touch its surface.\n' "$csv"
} 2>/dev/null
exit 0
