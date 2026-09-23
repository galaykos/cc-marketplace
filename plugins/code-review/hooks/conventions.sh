#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even
# under a stripped/broken PATH, where `env bash` itself exits 127.
#
# PostToolUse on the first code write of a session. Emits additionalContext naming
# the PATHS of the config files that define this project's conventions, and the CI
# command that actually enforces them. One-shot per session, fail-silent.
#
# WHY PATHS AND NOT RULES. The defect is not that the model does not know what
# `.editorconfig` means. It is that it does not OPEN it before writing a new file —
# it emits its own defaults (2-space, single quotes, ~100 cols) into a repo
# configured for tabs, double quotes and 120, and the next `npm run format` churns
# the whole file. That is a not-looking deficit, and a hook fixes it.
#
# It is deliberately NOT a digest. An earlier design emitted "the three settings
# most often violated" — a distilled checklist injected before the model reads the
# source. That is the precise shape rationale/stack-skill-baselines.md measured as
# making review WORSE: the treatment agent read three bullets and returned findings
# that were a strict subset of what the blind control found by reading the file. A
# summary substitutes for a read. So this emits locations, and the model opens
# them.
#
# CI IS AUTHORITATIVE, and that is the one judgment here worth stating: a formatter
# config that CI never invokes is decoration, and a repo with two formatters
# configured has one that wins and one that fights. Both are named in the output
# because neither is discoverable from any single file.
#
# Off switches: CC_REMIND=off silences every advisory nudge in this marketplace;
# CC_CONVENTIONS=off silences only this one.
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  case "${CC_CONVENTIONS:-on}" in off) exit 0 ;; esac

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac

  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
  [ -n "$file" ] || exit 0
  # Code only. A markdown or JSON edit is not where formatter churn happens, and
  # firing on every doc write is how a nudge gets tuned out.
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte|*.php|*.py|*.go|*.rb|*.rs|*.java|*.kt|*.cs|*.css|*.scss) ;;
    *) exit 0 ;;
  esac

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0

  # ONCE PER SESSION. The paths do not change mid-session, and a second copy costs
  # the same tokens for no new information.
  # CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
  # subagents at all, and a subagent shares its parent's session_id while getting its
  # own transcript. Keying a one-shot on session_id therefore dedups the worker against
  # nudges only the PARENT ever saw, so the context where most fan-out code is written
  # is the one context this never speaks in. Pattern and rationale: the context-key one-shot in hooks/scan.sh.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // "nosession"' 2>/dev/null)
  seen="${TMPDIR:-/tmp}/cc-conventions-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
  mkdir "$seen" 2>/dev/null || exit 0
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-conventions-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null

  found=""
  add() { [ -e "$cwd/$1" ] && found="$found $1"; }
  # detection order: editor → formatter → linter → pre-commit
  add .editorconfig
  for f in .prettierrc .prettierrc.json .prettierrc.yml .prettierrc.js prettier.config.js prettier.config.mjs \
           biome.json biome.jsonc rustfmt.toml .rustfmt.toml .php-cs-fixer.php .php-cs-fixer.dist.php pint.json \
           .rubocop.yml; do add "$f"; done
  for f in eslint.config.js eslint.config.mjs eslint.config.ts .eslintrc .eslintrc.json .eslintrc.js \
           ruff.toml .ruff.toml phpstan.neon phpstan.neon.dist psalm.xml .golangci.yml .golangci.yaml \
           tslint.json stylelint.config.js .stylelintrc; do add "$f"; done
  for f in .pre-commit-config.yaml lefthook.yml .husky .lintstagedrc .lintstagedrc.json; do add "$f"; done
  # pyproject/package.json only count when they actually carry tool config
  [ -f "$cwd/pyproject.toml" ] && grep -qE '^\[tool\.(ruff|black|isort|mypy)' "$cwd/pyproject.toml" 2>/dev/null \
    && found="$found pyproject.toml"

  # The CI lint invocation — authoritative, and not derivable from any config file.
  #
  # SIX FORMATS, because only one of them was ever read. Scanning `.github/workflows/`
  # alone meant every GitLab, CircleCI, Jenkins, Azure and Bitbucket repo got the configs
  # half of this message and no `CI runs:` line — and the paragraph below still told the
  # reader that whatever CI invokes is the standard, while naming nothing. The keyword
  # list is shared; only the PREFIX differs, because each format spells "this is a shell
  # command" its own way (`run:`, `script:`, `command:`, `sh '…'`, or a bare list item).
  #
  # WHAT THIS DOES NOT CATCH: any other runner (Drone, Buildkite, Tekton, Woodpecker,
  # Travis, Bamboo, a Makefile target CI calls); a GitHub composite action or reusable
  # workflow called from the job that does the linting; a command built from a variable;
  # and anything after the FIRST hit — one line is named, not the pipeline.
  ci=""
  ci_try() { # $1 file  $2 ERE for what precedes the command on its line
    [ -n "$ci" ] && return 0
    [ -f "$1" ] || return 1
    line=$(grep -nE "^[[:space:]]*$2.*(lint|format|fmt|pint|rubocop|ruff|biome|prettier|phpstan|psalm|vet)" "$1" 2>/dev/null | head -1)
    [ -n "$line" ] || return 1
    cmd=$(printf '%s' "${line#*:}" | sed -E "s/^[[:space:]]*$2//; s/^[[:space:]]*//; s/[[:space:]]*\$//; s/^['\"]//; s/['\"]\$//")
    ci="${1#$cwd/}:${line%%:*} — $cmd"
  }
  # `- run:` as a list item is the common GitHub shape; without the optional dash this
  # matched nothing in a real workflow and the CI half silently never fired.
  for w in "$cwd"/.github/workflows/*.yml "$cwd"/.github/workflows/*.yaml; do
    ci_try "$w" '-?[[:space:]]*run:[[:space:]]*'
  done
  ci_try "$cwd/.gitlab-ci.yml"          '(-[[:space:]]*|script:[[:space:]]*)'
  ci_try "$cwd/.gitlab-ci.yaml"         '(-[[:space:]]*|script:[[:space:]]*)'
  ci_try "$cwd/.circleci/config.yml"    '-?[[:space:]]*(run|command):[[:space:]]*'
  ci_try "$cwd/Jenkinsfile"             'sh[[:space:]]+'
  ci_try "$cwd/azure-pipelines.yml"     '-?[[:space:]]*script:[[:space:]]*'
  ci_try "$cwd/azure-pipelines.yaml"    '-?[[:space:]]*script:[[:space:]]*'
  ci_try "$cwd/bitbucket-pipelines.yml" '-[[:space:]]*'

  [ -n "$found" ] || [ -n "$ci" ] || exit 0

  msg="[code-review] This project defines its own conventions. Read these before writing more code — the files, not a summary of them:"
  [ -n "$found" ] && msg="$msg$(printf '\n  configs:%s' "$found")"
  [ -n "$ci" ] && msg="$msg$(printf '\n  CI runs: %s' "$ci")"
  msg="$msg$(printf '\n  Whatever CI actually invokes is the standard; a configured tool CI never runs is decoration. If two formatters are configured, exactly one owns formatting — do not add a third, and never add a second linter to a repo that already has one.')"

  jq -cn --arg m "$msg" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$m}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
