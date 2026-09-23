#!/usr/bin/env bash
# detect-analyzers.sh — report which static analyzers a project ACTUALLY has,
# how to invoke them, what they suppress, and how strictly they are configured.
# Usage: detect-analyzers.sh [project-root]   (default: .)
#
# WHY THIS EXISTS. rationale/stack-skill-baselines.md measured four
# best-practice checklists for these same stacks at zero-to-negative delta
# against a blind control: restating public documentation is what a model
# already does. What a blind model has no route to is the project's OWN
# configuration — which analyzer is authoritative, what its baseline already
# forgives, and which rules are switched off. This script emits that, so an
# expert agent grades against the project instead of against memory.
#
# Output lines, one record per line, stable and greppable:
#   analyzer  <lang> <tool> <config|-> <baseline|-> <invocation>
#   formatter <lang> <tool> <config>            # reported, never graded
#   strictness <tool> <key> <value>             # the config-gap evidence
#   ci <workflow> <tool>                        # tool named in a CI workflow
#   none      <reason>
#
# Exit 0: at least one analyzer detected. Exit 1: none — the caller must say so
# and stop, NOT fall back to a remembered checklist. Exit 2: bad usage.
#
# HONEST LIMITATION. Detection is by config-file presence and manifest
# grep — it does not resolve monorepo workspaces, per-package configs below the
# root, or a tool invoked only through a wrapper script it cannot read. A tool
# reported here may still fail to run (missing vendor/, node_modules/); the
# caller runs it and reports the real exit code. Absence of a `ci` line means
# "not found by grep in .github/workflows", never "not enforced".
set -u

root="${1:-.}"
[ -d "$root" ] || { printf 'detect-analyzers: not a directory: %s\n' "$root" >&2; exit 2; }

found=0

# first_file <path…> — print the first path that exists, relative to $root.
first_file() {
  local p
  for p in "$@"; do
    [ -f "$root/$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

# manifest_has <manifest> <needle> — literal grep inside a manifest file.
manifest_has() {
  [ -f "$root/$1" ] && grep -qF "$2" "$root/$1" 2>/dev/null
}

emit() { printf '%s\n' "$*"; found=1; }

# ---------------------------------------------------------------- PHP
if [ -f "$root/composer.json" ]; then
  if cfg=$(first_file phpstan.neon phpstan.neon.dist phpstan.dist.neon) \
     || manifest_has composer.json phpstan; then
    cfg="${cfg:--}"
    base=$(first_file phpstan-baseline.neon phpstan-baseline.neon.dist) || base='-'
    emit "analyzer php phpstan ${cfg} ${base} 'vendor/bin/phpstan analyse --no-progress --error-format=raw'"
    if [ "$cfg" != '-' ]; then
      lvl=$(grep -oE '^[[:space:]]*level:[[:space:]]*[0-9]+' "$root/$cfg" 2>/dev/null | grep -oE '[0-9]+' | head -1)
      [ -n "${lvl:-}" ] && printf 'strictness phpstan level %s\n' "$lvl"
    fi
  fi
  if cfg=$(first_file psalm.xml psalm.xml.dist); then
    base=$(first_file psalm-baseline.xml) || base='-'
    emit "analyzer php psalm ${cfg} ${base} 'vendor/bin/psalm --no-progress --output-format=text'"
    lvl=$(grep -oE 'errorLevel="[0-9]+"' "$root/$cfg" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -n "${lvl:-}" ] && printf 'strictness psalm errorLevel %s\n' "$lvl"
  fi
  if cfg=$(first_file phpcs.xml phpcs.xml.dist .phpcs.xml .phpcs.xml.dist); then
    emit "analyzer php phpcs ${cfg} - 'vendor/bin/phpcs --report=emacs'"
  fi
  if cfg=$(first_file rector.php); then
    emit "analyzer php rector ${cfg} - 'vendor/bin/rector process --dry-run'"
  fi
  if cfg=$(first_file .php-cs-fixer.php .php-cs-fixer.dist.php .php_cs .php_cs.dist); then
    printf 'formatter php php-cs-fixer %s\n' "$cfg"
  fi
  if cfg=$(first_file pint.json); then
    printf 'formatter php pint %s\n' "$cfg"
  fi
fi

# ------------------------------------------------------------- JS / TS
if [ -f "$root/package.json" ]; then
  if cfg=$(first_file tsconfig.json tsconfig.base.json); then
    # vue-tsc supersedes tsc when the project has .vue single-file components:
    # plain tsc cannot parse them, so reporting tsc here would send the caller
    # at a command that fails for a reason unrelated to the code under review.
    # svelte-check and `astro check` are the same case for .svelte and .astro:
    # measured 2026-09-22, a SvelteKit project carrying svelte-check in
    # devDependencies was reported as `npx tsc --noEmit`, which parses none of
    # its components. Does NOT catch a project mixing two of these frameworks
    # (Astro with a Svelte integration reports astro only, the first branch
    # that matches), a framework with no branch here (it still falls through to
    # plain tsc), or a JS-only project whose config is jsconfig.json.
    if manifest_has package.json '"vue-tsc"'; then
      emit "analyzer vue vue-tsc ${cfg} - 'npx vue-tsc --noEmit'"
    elif manifest_has package.json '"astro"'; then
      emit "analyzer astro astro-check ${cfg} - 'npx astro check'"
    elif manifest_has package.json '"svelte"'; then
      emit "analyzer svelte svelte-check ${cfg} - 'npx svelte-check --tsconfig ./${cfg}'"
    else
      emit "analyzer ts tsc ${cfg} - 'npx tsc --noEmit'"
    fi

    # tsconfig.json is JSONC, and the file tsc scaffolds is ~100 lines of
    # COMMENTED-OUT flags with explanatory text. Grepping it raw reports those
    # as enabled — measured 2026-09-15 against a real project, where this
    # claimed noUncheckedIndexedAccess and exactOptionalPropertyTypes were on
    # when `tsc --showConfig` resolves both as absent. For a detector whose
    # entire job is naming what the checker CANNOT see, a false "covered" is
    # worse than no record at all, so strip comments before matching.
    ts_src=$(sed -e 's#^[[:space:]]*//.*##' -e 's#/\*[^*]*\*/##g' "$root/$cfg" 2>/dev/null)

    # `extends` means flags can arrive from a base config this grep never opens.
    printf '%s' "$ts_src" | grep -qE '"extends"[[:space:]]*:' \
      && printf 'strictness tsconfig extends present\n'

    strict_on=0
    if printf '%s' "$ts_src" | grep -qE '"strict"[[:space:]]*:[[:space:]]*true'; then
      printf 'strictness tsconfig strict true\n'; strict_on=1
    elif printf '%s' "$ts_src" | grep -qE '"strict"[[:space:]]*:'; then
      printf 'strictness tsconfig strict false\n'
    else
      printf 'strictness tsconfig strict absent\n'
    fi

    # Flags `strict: true` turns on implicitly. Reporting these as `absent`
    # when strict is on would send a reader hunting null-safety gaps that are
    # already covered; reporting the NON-implied ones as covered would hide
    # the real ones. The split is the content.
    for k in strictNullChecks noImplicitAny strictFunctionTypes noImplicitThis; do
      v=$(printf '%s' "$ts_src" | grep -oE "\"$k\"[[:space:]]*:[[:space:]]*(true|false)" | grep -oE '(true|false)$' | head -1)
      if [ -n "${v:-}" ]; then
        printf 'strictness tsconfig %s %s\n' "$k" "$v"
      elif [ "$strict_on" -eq 1 ]; then
        printf 'strictness tsconfig %s true-via-strict\n' "$k"
      else
        printf 'strictness tsconfig %s absent\n' "$k"
      fi
    done
    # NOT implied by strict — these stay off unless named explicitly, which is
    # what makes them the highest-value gap in an otherwise-strict project.
    for k in noUncheckedIndexedAccess exactOptionalPropertyTypes noImplicitReturns \
             noFallthroughCasesInSwitch noUnusedLocals noUnusedParameters; do
      v=$(printf '%s' "$ts_src" | grep -oE "\"$k\"[[:space:]]*:[[:space:]]*(true|false)" | grep -oE '(true|false)$' | head -1)
      printf 'strictness tsconfig %s %s\n' "$k" "${v:-absent}"
    done
    printf '%s' "$ts_src" | grep -qE '"skipLibCheck"[[:space:]]*:[[:space:]]*true' \
      && printf 'strictness tsconfig skipLibCheck true\n'
  fi
  if cfg=$(first_file eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts \
                      .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml .eslintrc) \
     || manifest_has package.json '"eslintConfig"'; then
    cfg="${cfg:-package.json#eslintConfig}"
    base=$(first_file .eslintcache) || base='-'
    emit "analyzer js eslint ${cfg} ${base} 'npx eslint .'"
    # The single highest-value config gap in a React codebase: the rule that
    # catches stale-closure and missing-dependency bugs is frequently present
    # but demoted to a warning, so CI stays green while the defect ships.
    if [ -f "$root/$cfg" ]; then
      if grep -qE 'exhaustive-deps' "$root/$cfg" 2>/dev/null; then
        sev=$(grep -oE 'exhaustive-deps"?[^,}]*' "$root/$cfg" 2>/dev/null | grep -oE '(error|warn|off)' | head -1)
        printf 'strictness eslint react-hooks/exhaustive-deps %s\n' "${sev:-unparsed}"
      fi
      grep -qE 'react-hooks' "$root/$cfg" 2>/dev/null && printf 'strictness eslint react-hooks-plugin present\n'
      grep -qE 'plugin:vue|eslint-plugin-vue|pluginVue' "$root/$cfg" 2>/dev/null && printf 'strictness eslint vue-plugin present\n'
    fi
  fi
  if cfg=$(first_file biome.json biome.jsonc); then
    emit "analyzer js biome ${cfg} - 'npx biome check .'"
  fi
  if cfg=$(first_file .oxlintrc.json); then
    emit "analyzer js oxlint ${cfg} - 'npx oxlint'"
  fi
  if cfg=$(first_file .stylelintrc .stylelintrc.json .stylelintrc.js .stylelintrc.cjs stylelint.config.js stylelint.config.cjs stylelint.config.mjs); then
    emit "analyzer ui stylelint ${cfg} - 'npx stylelint \"**/*.{css,scss,vue}\"'"
  fi
  if cfg=$(first_file .pa11yci .pa11yci.json pa11yci.json); then
    emit "analyzer ui pa11y ${cfg} - 'npx pa11y-ci'"
  fi
  if cfg=$(first_file lighthouserc.js lighthouserc.json lighthouserc.yml .lighthouserc.json); then
    emit "analyzer ui lighthouse-ci ${cfg} - 'npx lhci autorun'"
  fi
  manifest_has package.json '"@axe-core/cli"' \
    && emit "analyzer ui axe - - 'npx axe <url>'"
  manifest_has package.json '"@axe-core/playwright"' \
    && printf 'strictness axe harness playwright\n' && found=1
  if cfg=$(first_file .prettierrc .prettierrc.json .prettierrc.js prettier.config.js prettier.config.cjs); then
    printf 'formatter js prettier %s\n' "$cfg"
  fi
fi

# ------------------------------------------------------- CI cross-check
# Which of the above CI actually runs. A repo can carry three configs and
# enforce one; the enforced one is the authoritative rubric, and nothing but
# the workflow file says which it is.
#
# Workflows rarely name the tool directly. `run: composer ci:check` hides
# phpstan two levels down a composer script chain, and `npm run types:check`
# hides tsc one level down package.json. Grepping the workflow alone reports
# "not enforced" for a repo that enforces everything — measured against a real
# Laravel + Inertia project on 2026-09-15, where the first version of this
# script missed phpstan, tsc, eslint and prettier, all four of them enforced.
# So resolve script references transitively, bounded at depth 4, and say which
# reading produced each record.

# script_body <manifest> <script-name> — print a script's definition text,
# handling both the scalar ("lint": "eslint .") and array (composer) shapes.
script_body() {
  [ -f "$root/$1" ] || return 0
  awk -v want="\"$2\":" '
    index($0, want) && !found {
      found = 1
      rest = substr($0, index($0, want) + length(want))
      # A bare "[" opens a multi-line array; anything else is the value itself,
      # which may be a scalar OR a single-line array. Both shapes ship in the
      # wild — the single-line one was missed until a fixture caught it.
      if (rest ~ /^[[:space:]]*\[[[:space:]]*$/) { arr = 1; next }
      print
      if (rest ~ /\[/ && rest !~ /\]/) { arr = 1; next }
      exit
    }
    found && arr {
      if ($0 ~ /^[[:space:]]*\][,]?[[:space:]]*$/) exit
      print
    }
  ' "$root/$1"
}

# script_refs — read text on stdin, print every script name it invokes.
script_refs() {
  {
    grep -oE '(composer|npm run|pnpm run|yarn run|pnpm|yarn) [a-z@][a-zA-Z0-9:_.-]*' || true
    grep -oE '"@[a-z][a-zA-Z0-9:_.-]*"' || true
  } | sed -e 's/.*[[:space:]]//' -e 's/"//g' -e 's/^@//' | sort -u
}

if [ -d "$root/.github/workflows" ]; then
  for wf in "$root/.github/workflows"/*; do
    [ -f "$wf" ] || continue
    direct=$(cat "$wf")
    blob="$direct"
    queue=$(printf '%s' "$direct" | script_refs)
    seen=' '
    depth=0
    while [ -n "$queue" ] && [ "$depth" -lt 4 ]; do
      next=''
      for name in $queue; do
        case "$seen" in *" $name "*) continue ;; esac
        seen="$seen$name "
        body=$(script_body composer.json "$name"; script_body package.json "$name")
        [ -n "$body" ] || continue
        blob="$blob
$body"
        next="$next $(printf '%s' "$body" | script_refs)"
      done
      queue="$next"
      depth=$((depth + 1))
    done
    for tool in phpstan psalm phpcs rector pint tsc vue-tsc svelte-check astro-check eslint biome oxlint stylelint pa11y lhci axe prettier; do
      # `astro check` is two words wherever a script invokes it, while the
      # analyzer record above names it astro-check; match both spellings rather
      # than rename the record. Bare `astro` is deliberately not a token: it
      # would label `astro build` as an analyzer step.
      case "$tool" in
        astro-check) pat="(^|[^a-zA-Z-])astro[ -]check([^a-zA-Z-]|$)" ;;
        *)           pat="(^|[^a-zA-Z-])${tool}([^a-zA-Z-]|$)" ;;
      esac
      if printf '%s' "$direct" | grep -qE "$pat"; then
        printf 'ci %s %s direct\n' "${wf#"$root/"}" "$tool"
      elif printf '%s' "$blob" | grep -qE "$pat"; then
        printf 'ci %s %s via-script\n' "${wf#"$root/"}" "$tool"
      fi
    done
  done
fi

if [ "$found" -eq 0 ]; then
  printf 'none no analyzer config found under %s\n' "$root"
  exit 1
fi
exit 0
