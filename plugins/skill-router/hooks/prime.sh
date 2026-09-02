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

  # Both the flat and the versioned-cache layouts — see hooks/plugins-dir.sh.
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

  # Bounded checks — maxdepth caps cost, -print -quit stops at the first hit.
  has()     { find "$cwd" -maxdepth 3 -name "$1" -print -quit 2>/dev/null | grep -q . ; }
  has_dir() { find "$cwd" -maxdepth 3 -type d -name "$1" -print -quit 2>/dev/null | grep -q . ; }

  # Rows below mirror coding-entry/references/skill-map.md, which is the documented
  # manifest-shaped map. Keep the two in step; skill-map.md's own header warns that
  # "two copies of one matcher guarantees that one goes stale", and this file WAS the
  # unacknowledged third copy. Generating this table from that file is the follow-up
  # (it needs a fifth chassis type — scripts/generate.sh:216-221 dispatches four and
  # dies on anything else), so until then the comment is the only thing holding them
  # together, which is a `recorded` tier and stated as such.
  dep() { # $1 manifest, $2 ERE — a dependency-name match, not a substring anywhere
    [ -f "$cwd/$1" ] && grep -qE "$2" "$cwd/$1" 2>/dev/null
  }

  [ -f "$cwd/composer.json" ] && add package-hygiene stack-scan
  [ -f "$cwd/package.json" ]  && add package-hygiene stack-scan
  if has '*.sql' || has_dir migrations; then add sql-best-practices database; fi
  if has '*.tsx' || has '*.jsx'; then add a11y-audit ui-ux; fi

  # PHP side. laravel and plain php are stack-EXCLUSIVE per skill-map.md — a Laravel
  # rules.tsv applies via its `!composer.json~laravel/framework` markers.
  if dep composer.json '"laravel/framework"'; then add laravel-best-practices laravel
  fi
  { dep composer.json '"inertiajs/inertia-laravel"' || dep package.json '"@inertiajs/'; } \
    && add inertia-best-practices laravel

  # JS side. react-native and react are exclusive the same way.
  if dep package.json '"react-native"'; then add react-native-best-practices web-dev
  fi

  # Tailwind requires an actual Tailwind signal. This line previously read
  # grep -qE '"(react|vue|@?tailwind)' — so ANY React or Vue dependency asserted
  # tailwind-best-practices on a repo with no Tailwind in it. That is the falsehood
  # this card exists to remove: it was emitted in the session's FIRST line, and every
  # blocking gate passed it, because no gate reads this map.
  if dep package.json '"tailwindcss"' || has 'tailwind.config.*'; then
    add tailwind-best-practices ui-ux
  fi
  [ -f "$cwd/components.json" ] && add shadcn-best-practices ui-ux
  if has 'Dockerfile*' || has 'docker-compose*.yml' || has 'compose*.yml'; then add docker-best-practices devops; fi
  if has_dir tests || has '*.test.*' || has '*.spec.*'; then add testing-best-practices testing; fi

  skills="${skills# }"
  [ -n "$skills" ] || exit 0
  csv=$(printf '%s' "$skills" | tr ' ' ',' | sed 's/,/, /g')
  printf '[skill-router] Repo-relevant skills this session: %s. Load each when you touch its surface.\n' "$csv"
} 2>/dev/null
exit 0
