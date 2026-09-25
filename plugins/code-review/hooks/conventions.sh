#!/bin/bash
# Absolute-path shebang (not `env bash`): the fail-open guarantee must hold even
# under a stripped/broken PATH, where `env bash` itself exits 127.
#
# PostToolUse on the first code write of a session. Emits additionalContext naming
# the PATHS of the config files that define this project's conventions, and the CI
# command that actually enforces them. One-shot per session, fail-silent.
#
# A WRITE IS A WRITE, WHATEVER THE TOOL (0.23.0). This matched Write|Edit|MultiEdit only,
# and the host steers file writes through Bash: measured 2026-09-25
# (rationale/2026-09-25-session-plugin-usage-review.md, finding 1), 233 of 238 main-thread
# writes in one session were `cat > file <<EOF`, so the first code write of that session —
# and of every session like it — never reached this hook. It now also matches Bash and
# fires when cc_bash_write_targets (the shared block below) names at least one existing
# code file under the project root. Same one-shot, same context key. What the block does
# NOT parse — interpreter writes (python open(), php file_put_contents), cp/mv
# destinations, a path held in a variable — still goes unseen; its own header lists them.
#
# CONFIGS ARE READ AT THE PROJECT ROOT, not the payload cwd. The cwd is the shell's and
# follows the model's `cd` (same review, finding 2), so a session that had `cd app/Enums`
# looked for `.editorconfig` in app/Enums, found nothing, and spent its one-shot silent.
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

# --- bash write targets --------------------------------------------------------
# Canonical copy: templates/blocks/bash-write-targets.md. Every hook defining
# cc_bash_write_targets must carry this block byte-for-byte (pc_shared_blocks).
# The host steers file writes through Bash (auto mode `bashFirst`); in one measured session
# 233 of 238 main-thread writes were `cat > file <<EOF`, invisible to a hook matching
# Write|Edit.
# Prints one target path per line, as spelled in the command (relative or absolute).
# Heredoc BODIES are dropped and quoted text is masked before matching, so PHP `->`/`=>`,
# HTML `>` and a sed script's `s|a|b|` never read as redirects or pipes; a here-string
# (`<<<`) is not a heredoc. Catches `>`/`>>` onto a path (cat, echo, printf, any command),
# `[sudo] tee [-a] <paths>`, and the last operand of `sed -i` / `perl -i`. Does NOT catch:
# interpreter writes (python open(), php file_put_contents), cp/mv/install destinations,
# `{ …; } > f` groups, a path held in a variable (`> "$f"` is skipped, never guessed).
# The caller filters to existing files under its root.
cc_bash_write_targets() {
  printf '%s\n' "$1" | awk '
    function emit(p) {
      gsub(/^["\047]|["\047]$/, "", p)
      if (p == "" || p ~ /^\/dev\// || p ~ /[$`*?]/ || p ~ /^[&0-9-]/ && p !~ /[\/.]/) return
      print p
    }
    function mask(s,   i, c, q, out, esc) {
      q = ""; out = ""; esc = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (esc) { out = out "_"; esc = 0; continue }
        if (q == "") {
          if (c == "\\") { esc = 1; out = out "_"; continue }
          if (c == "\047" || c == "\"") q = c
          out = out c
        } else if (c == q) { q = ""; out = out c }
        else { if (q == "\"" && c == "\\") esc = 1; out = out "_" }
      }
      return out
    }
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, last) {
      rest = ms; off = 0
      while (match(rest, /(^|[^0-9&=<>-])>>?[ \t]*("[^"]*"|\047[^\047]*\047|[^ \t&|;<>()"\047]+)/)) {
        tok = substr(os, off + RSTART, RLENGTH)
        off += RSTART + RLENGTH - 1; rest = substr(ms, off + 1)
        sub(/^[^>]*>>?[ \t]*/, "", tok)
        emit(tok)
      }
      n = 0; j = 1
      while (j <= length(ms)) {
        while (j <= length(ms) && substr(ms, j, 1) ~ /[ \t]/) j++
        if (j > length(ms)) break
        st = j; while (j <= length(ms) && substr(ms, j, 1) !~ /[ \t]/) j++
        n++; ws[n] = st; we[n] = j - 1
      }
      if (n == 0) return
      k = 1; word = substr(os, ws[1], we[1] - ws[1] + 1)
      if (word == "sudo" && n > 1) { k = 2; word = substr(os, ws[2], we[2] - ws[2] + 1) }
      if (word == "tee") {
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1)
          if (w == "<" || w == "<<<") { k++; continue }
          if (w !~ /^-/ && w !~ /^[<>0-9]/) emit(w)
        }
      } else if ((word == "sed" || word == "perl") && ms ~ /[ \t]-[a-zA-Z0-9]*i/) {
        last = substr(os, ws[n], we[n] - ws[n] + 1)
        if (n > 2 && last !~ /^-/ && substr(ms, ws[n], 1) !~ /["\047]/) emit(last)
      }
    }
    skip { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); if (t == term) skip = 0; next }
    {
      line = $0; m = mask(line)
      if (match(m, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
        if (substr(m, RSTART, 1) != "<") { RSTART++; RLENGTH-- }
        term = substr(line, RSTART, RLENGTH + 1)
        sub(/^<<-?[ \t]*["\047]?/, "", term); sub(/[^A-Za-z0-9_].*$/, "", term)
        skip = 1
      }
      st = 1
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c == "|" || c2 == "&&") {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  case "${CC_REMIND:-on}" in off) exit 0 ;; esac
  case "${CC_CONVENTIONS:-on}" in off) exit 0 ;; esac

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit|Bash) ;; *) exit 0 ;; esac

  # ONCE PER SESSION. The paths do not change mid-session, and a second copy costs
  # the same tokens for no new information.
  # CONTEXT KEY, not session key. PostToolUse is the only hook channel that reaches
  # subagents at all, and a subagent shares its parent's session_id while getting its
  # own transcript. Keying a one-shot on session_id therefore dedups the worker against
  # nudges only the PARENT ever saw, so the context where most fan-out code is written
  # is the one context this never speaks in. Pattern and rationale: the context-key one-shot in hooks/scan.sh.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // "nosession"' 2>/dev/null)
  seen="${TMPDIR:-/tmp}/cc-conventions-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
  # CHEAP EXIT FIRST: with Bash in the matcher this runs after every shell command, and
  # once the one-shot is spent nothing below can change the answer.
  [ -d "$seen" ] && exit 0

  # Code only. A markdown or JSON edit is not where formatter churn happens, and
  # firing on every doc write is how a nudge gets tuned out.
  is_code() {
    case "$1" in
      *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte|*.php|*.py|*.go|*.rb|*.rs|*.java|*.kt|*.cs|*.css|*.scss) return 0 ;;
    esac
    return 1
  }

  if [ "$tool" = "Bash" ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    # Every write form the block recognises needs one of these; most commands carry none.
    case "$cmd" in *'>'*|*tee*|*sed*|*perl*) ;; *) exit 0 ;; esac
  else
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
    [ -n "$file" ] || exit 0
    is_code "$file" || exit 0
  fi

  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  # BASH: a relative target resolves against the payload cwd — the Bash tool's own cwd,
  # which is the one place that cwd is exactly right. Kept only when it lands under the
  # project root and is now an existing code file. At most 8 targets per call, so a
  # mass-write command cannot make one hook call slow.
  if [ "$tool" = "Bash" ]; then
    hit=""; n=0
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      n=$((n + 1)); [ "$n" -le 8 ] || break
      case "$t" in /*) abs="$t" ;; *) abs="$cwd/$t" ;; esac
      is_code "$abs" || continue
      d=$(CDPATH= cd -- "$(dirname -- "$abs")" 2>/dev/null && pwd) || continue
      abs="$d/${abs##*/}"
      case "$abs" in "$root"/*) ;; *) continue ;; esac
      [ -f "$abs" ] && { hit=1; break; }
    done <<EOF
$(cc_bash_write_targets "$cmd")
EOF
    [ -n "$hit" ] || exit 0
  fi

  mkdir "$seen" 2>/dev/null || exit 0
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-conventions-*' -type d -mmin +1440 -exec rmdir {} + 2>/dev/null

  found=""
  add() { [ -e "$root/$1" ] && found="$found $1"; }
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
  [ -f "$root/pyproject.toml" ] && grep -qE '^\[tool\.(ruff|black|isort|mypy)' "$root/pyproject.toml" 2>/dev/null \
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
    ci="${1#$root/}:${line%%:*} — $cmd"
  }
  # `- run:` as a list item is the common GitHub shape; without the optional dash this
  # matched nothing in a real workflow and the CI half silently never fired.
  for w in "$root"/.github/workflows/*.yml "$root"/.github/workflows/*.yaml; do
    ci_try "$w" '-?[[:space:]]*run:[[:space:]]*'
  done
  ci_try "$root/.gitlab-ci.yml"          '(-[[:space:]]*|script:[[:space:]]*)'
  ci_try "$root/.gitlab-ci.yaml"         '(-[[:space:]]*|script:[[:space:]]*)'
  ci_try "$root/.circleci/config.yml"    '-?[[:space:]]*(run|command):[[:space:]]*'
  ci_try "$root/Jenkinsfile"             'sh[[:space:]]+'
  ci_try "$root/azure-pipelines.yml"     '-?[[:space:]]*script:[[:space:]]*'
  ci_try "$root/azure-pipelines.yaml"    '-?[[:space:]]*script:[[:space:]]*'
  ci_try "$root/bitbucket-pipelines.yml" '-[[:space:]]*'

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
