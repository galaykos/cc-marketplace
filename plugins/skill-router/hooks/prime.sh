#!/bin/bash
# Absolute-path shebang (not `/usr/bin/env bash`): the fail-open guarantee must
# hold even under a stripped/broken PATH.
# SessionStart primer. Sniffs the repo's manifests directly and injects a
# one-line index of the skills relevant to this stack, filtered to installed
# plugins. Does NOT read stack-scan — that is a conversational skill with no
# persisted output a hook could read. Fail-open: any error exits silently.
#
# MANIFESTS ARE READ AT THE PROJECT ROOT (0.20.0), through the shared `cc_state_root`
# block below — the same root route.sh reads its stack markers at. The payload cwd follows
# the model's `cd` (rationale/2026-09-25-session-plugin-usage-review.md, finding 2), and
# SessionStart fires again on resume and compact, so a session compacted while `cd`-ed
# into `app/Enums` was re-primed from THAT directory: no composer.json there, and the
# index dropped laravel-best-practices mid-session. Same trade route.sh states: a session
# started inside a monorepo workspace used to be primed from that workspace's manifests
# and is now primed from the repo root's.
#
# TWO CALLERS, ONE TABLE. The evidence rows live in `sr_repo_skills` below, and
# hooks/subagent-skills.sh SOURCES this file to call it: a subagent is handed the skills
# its frontmatter declares only where these same rows find the stack. The rows stay in
# THIS file because two gates read them here by path — pc_prime_coverage and
# validate.sh's skill-resolution loop both grep prime.sh for `add <skill>` — so moving
# them to a separate library would blind both. The hook body at the bottom runs only
# when the file is executed; a caller that sources it gets the functions and nothing else.
# --- state root ----------------------------------------------------------------
# Canonical copy: templates/blocks/state-root.md. Every hook defining cc_state_root must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# The payload's `cwd` is the SHELL's cwd and follows the model's `cd` — measured
# 2026-09-25: app/Enums, then app/Models, then the repo root in one session, each leaving
# its own `.claude/` state dir and each re-firing a "once per session" nudge. State lives
# at the project root instead (pc_state_root refuses a raw `$cwd/.claude` path in a hook):
# the git toplevel reached by walking UP from cwd (`--show-cdup`, so a symlinked /tmp keeps
# the caller's spelling and path-prefix comparisons still hold); outside git,
# CLAUDE_PROJECT_DIR when cwd sits under it; else cwd. A cwd that no longer exists yields
# nothing and status 1 — the caller exits rather than resurrect a deleted project.
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

# Bounded checks against $SR_ROOT — maxdepth caps cost, -print -quit stops at the first hit.
has()     { find "$SR_ROOT" -maxdepth 3 -name "$1" -print -quit 2>/dev/null | grep -q . ; }
has_dir() { find "$SR_ROOT" -maxdepth 3 -type d -name "$1" -print -quit 2>/dev/null | grep -q . ; }
dep() { # $1 manifest, $2 ERE — a dependency-name match, not a substring anywhere
  [ -f "$SR_ROOT/$1" ] && grep -qE "$2" "$SR_ROOT/$1" 2>/dev/null
}

# sr_repo_skills <project-root> — calls `add <skill> <owning_plugin>` once per row whose
# evidence holds. `add` is the CALLER's: the hook body below filters it to installed
# plugins and dedups; subagent-skills.sh records the pair and intersects it with an
# agent's declared list.
#
# Rows below mirror coding-entry/references/skill-map.md, which is the documented
# manifest-shaped map. Keep the two in step; skill-map.md's own header warns that
# "two copies of one matcher guarantees that one goes stale", and this file WAS the
# unacknowledged third copy. Generating this table from that file is the follow-up
# (it needs a fifth chassis type — scripts/generate.sh:216-221 dispatches four and
# dies on anything else), so until then the comment is the only thing holding them
# together, which is a `recorded` tier and stated as such.
sr_repo_skills() {
  SR_ROOT="$1"
  [ -f "$SR_ROOT/composer.json" ] && add package-hygiene stack-scan
  [ -f "$SR_ROOT/package.json" ]  && add package-hygiene stack-scan
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

  # next and vite: declared in skill-map.md's Frontend table since it was written and
  # absent here, so a Next + Vite + Tailwind repo was primed with package-hygiene,
  # a11y-audit and tailwind-best-practices and told nothing about the two skills whose
  # whole subject is those two tools. pc_prime_coverage only checks this file against
  # the map, never the map against this file, so the gap was structurally invisible.
  # NOT exclusive of each other: a Next app can carry vite for its test runner, and both
  # skills are wanted then.
  if dep package.json '"next"'; then add nextjs-best-practices web-dev
  fi
  if dep package.json '"vite"'; then add vite-best-practices web-dev
  fi

  # Tailwind requires an actual Tailwind signal. This line previously read
  # grep -qE '"(react|vue|@?tailwind)' — so ANY React or Vue dependency asserted
  # tailwind-best-practices on a repo with no Tailwind in it. That is the falsehood
  # this card exists to remove: it was emitted in the session's FIRST line, and every
  # blocking gate passed it, because no gate reads this map.
  if dep package.json '"tailwindcss"' || has 'tailwind.config.*'; then
    add tailwind-best-practices ui-ux
  fi
  [ -f "$SR_ROOT/components.json" ] && add shadcn-best-practices ui-ux
  if has 'Dockerfile*' || has 'docker-compose*.yml' || has 'compose*.yml'; then add docker-best-practices devops; fi
  # The two rows skill-map.md declared and this file never primed — both were standing
  # `map-unprimed` WARNs from pc_prime_coverage, and both are file-presence sniffs of the
  # same shape as the rows above. LIMITATION: `.github/workflows/` is the GitHub signal
  # only, so a GitLab, CircleCI, Jenkins or Buildkite pipeline primes nothing; and the
  # MariaDB sniff reads the two canonical compose filenames at the repo root, so a
  # `.yaml` spelling, a compose file in a subdirectory, or a MariaDB reached over the
  # network is missed — the same known misses rules.tsv's mariadb rows carry.
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
  sr_repo_skills "$root"

  skills="${skills# }"
  [ -n "$skills" ] || exit 0
  csv=$(printf '%s' "$skills" | tr ' ' ',' | sed 's/,/, /g')
  printf '[skill-router] Repo-relevant skills this session: %s. Load each when you touch its surface.\n' "$csv"
} 2>/dev/null
exit 0
