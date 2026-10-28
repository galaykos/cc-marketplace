#!/bin/bash
# PostToolUse, once per context: at the first code write (Write, Edit, a Bash write, an interpreter run's changed file) names the convention configs, standards docs and CI lint line as paths, not a digest.
# Misses: CI other than GitHub, GitLab, CircleCI, Jenkins, Azure, Bitbucket; any lint line after the first; Bash writes the pasted blocks miss. Off: CC_REMIND, CC_CONVENTIONS.
# Why, limits, history: rationale/derivations/plugin-code-review.md § plugins/code-review/hooks/conventions.sh

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

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# A non-empty variable beats the option: the environment is shared, so one export before launch
# switches every plugin that reads it.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

# Shared block templates/blocks/bash-write-targets.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-targets.md
# cc_bash_write_targets <command> prints each path the command writes through `>`/`>>`, `[sudo] tee` or `sed -i`/`perl -i`,
# one per line as spelled; heredoc bodies and quoted text never match. A path guard keeps existing files under its root.
# BSD sed's -I always takes the next word as its backup suffix, so that word is never a target; after a bare sed -i,
# a `''` or `.`-led word is read as one too, unless it would be the only file.
# Misses: interpreter writes, cp/mv/install, a path in a variable, a glob, a `\` line continuation, a digit- or &-led
# redirect and `>&`, sed/perl/tee behind another command word (gsed, /usr/bin/sed, env, xargs, sudo -u), a `-`-led
# operand with no `/` or `.`, operands cut short by a `&` inside `$(( ))`/`${ }`, every line after a `<<\EOF` opener.
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
    function segment(ms, os,   rest, off, tok, w, k, j, st, en, word, n, ws, we, x, c, a, inp, scr, eo, sfx, nf, f) {
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
      } else if (word == "sed" || word == "perl") {
        inp = 0; scr = 0; eo = 0; sfx = ""; nf = 0
        for (k = k + 1; k <= n; k++) {
          w = substr(os, ws[k], we[k] - ws[k] + 1); x = substr(ms, ws[k], we[k] - ws[k] + 1)
          if (x ~ /[<>]/) {
            a = substr(w, 1, match(x, /[<>]/) - 1)
            if (a !~ /^[0-9&]*$/) f[++nf] = a
            if (x ~ /[<>][&|]?$/) k++
            continue
          }
          if (eo || x !~ /^-./) { f[++nf] = w; if (word == "perl") eo = 1; continue }
          if (x == "--") { eo = 1; continue }
          if (x ~ /^--/) {
            if (word == "sed" && x ~ /^--in-place(=|$)/) inp = 1
            if (word == "sed" && x ~ /^--(expression|file)(=|$)/) { scr = 1; if (x !~ /=/) k++ }
            continue
          }
          for (j = 2; j <= length(x); j++) {
            c = substr(x, j, 1)
            if (c == "i" || word == "sed" && c == "I") {
              inp = 1
              if (word == "sed" && j == length(x) && k < n) {
                a = substr(os, ws[k + 1], we[k + 1] - ws[k + 1] + 1); gsub(/^["\047]|["\047]$/, "", a)
                if (c == "I") k++
                else if (a == "" || a ~ /^\.[^\/<>]*$/) { k++; sfx = a }
              }
              break
            }
            if (c == "e" || c == (word == "sed" ? "f" : "E")) { scr = 1; if (j == length(x)) k++; break }
            if (c == (word == "sed" ? "l" : "I")) { if (j == length(x)) k++; break }
            if (word == "perl" && c ~ /[MmFxdDVC]/) break
            if (word == "perl" && c ~ /[l0]/) while (substr(x, j + 1, 1) ~ /[0-7]/) j++
          }
        }
        if (!inp) return
        for (j = scr ? 1 : 2; j <= nf; j++) if (f[j] !~ /^-/ || eo) { emit(f[j]); sfx = "" }
        if (sfx != "") emit(sfx)
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
        if (i > length(m) || c == ";" || c == "|" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>]/) {
          if (i > st) segment(substr(m, st, i - st), substr(line, st, i - st))
          if (c2 == "&&" || c2 == "||" || c2 == "|&") i++
          st = i + 1
        }
      }
    }' | awk '!seen[$0]++'
}

# Shared block templates/blocks/plugin-state.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/plugin-state.md
# cc_plugin_state <root> <name> prints the plugin's own state dir for <root>, a cc_state_root result:
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.claude/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.claude/%s\n' "$1" "$2"
  fi
  return 0
}

# Shared block templates/blocks/bash-write-effects.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-effects.md
# cc_bash_effects_mark <root> <marker> <session> rewrites <marker> to hold <session>'s cksum when <root> holds a .git, and gives its
# directory a `*` .gitignore when it has none. Call it on EVERY call the hook sees (Write, Edit, Bash, a failed Bash too), after
# cc_bash_write_effects read <marker>: the tool has finished when the hook runs, so <marker> then post-dates every write of that call.
# cc_bash_write_effects <root> <marker> <command> <max> <session> prints at most <max> absolute paths, one per line: files `git status`
# under <root> reports changed or untracked and newer than <marker> (a plugin state dir stays out by its `*` .gitignore). It runs git
# only when <command> holds python, node, php, ruby, perl (any version suffix or directory), nodejs, deno, bun, cp, mv, install or
# patch as a word, <marker> holds <session>'s cksum (another session's marker reads as none), <root> is not $HOME and
# status.showUntrackedFiles is not no. Misses: writers it does not name, gitignored files, submodules, no git, each session's first
# call, a file written then reverted, a mv or cp -p destination (it keeps the source's mtime), files past <max>. Reads too much: any
# change since <marker> — an IDE, a parallel agent, a job, a state file another tool keeps in a .claude/ dir git does not ignore.
cc_bash_effects_mark() {
  [ -e "$1/.git" ] || return 0
  local d="${2%/*}" k
  { [ -d "$d" ] || mkdir -p "$d"; } 2>/dev/null || return 0
  { [ -e "$d/.gitignore" ] || printf '*\n' > "$d/.gitignore"; k=$(printf '%s' "$3" | cksum) && printf '%s\n' "${k%% *}" > "$2"; } 2>/dev/null
  return 0
}
cc_bash_write_effects() {
  local LC_ALL=C re='(^|[;&|(`[:space:]])([^[:space:];&|()`<>]*/)?((python|php|ruby|perl|node)[0-9.]*|nodejs|deno|bun|cp|mv|install|patch)([[:space:];&|)`<>]|$)' k m f
  [ -f "$2" ] && [ "$1" != "${HOME%/}" ] && [[ $3 =~ $re ]] && IFS= read -r m < "$2" && k=$(printf '%s' "$5" | cksum) && [ "$m" = "${k%% *}" ] || return 0
  case "$(git -C "$1" config status.showUntrackedFiles 2>/dev/null)" in no|false|off|0) return 0 ;; esac
  # One find over the whole list, each path led by ./ so a name like -delete stays a path; the cap counts only what find kept.
  while IFS= read -r f; do printf '%s\n' "$1/${f#./}"; done < <(exec 2>/dev/null; cd -- "$1" && GIT_OPTIONAL_LOCKS=0 git status --porcelain -z \
    --untracked-files=all --no-renames --ignore-submodules=all | tr '\0' '\n' | sed -e 's|^...|./|' \
    | tr '\n' '\0' | xargs -0 sh -c 'exec find "$@" -prune -newer "$0" -type f -print' "$2" | head -n "$4")
  return 0
}

{
  MAX_BASH_EFFECTS=8   # changed files read after an interpreter, cp, mv, install or patch run, in git's path order
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac
  case "$(cc_option CC_CONVENTIONS on)" in off) exit 0 ;; esac

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit|Bash) ;; *) exit 0 ;; esac
  [ "$tool" = Bash ] && { cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0; }

  # Once per context, keyed on transcript_path: a subagent shares its parent's session_id.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // "nosession"' 2>/dev/null)
  seen="${TMPDIR:-/tmp}/cc-conventions-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"

  # Read effects with the old marker, then date it on every call, the one-shot spent too: the marker is per project.
  { IFS= read -r cwd; IFS= read -r sess; IFS= read -r hev; } < <(printf '%s' "$input" \
    | jq -r '.cwd // "", .session_id // "", if .hook_event_name == "PostToolUseFailure" then .hook_event_name else "PostToolUse" end' 2>/dev/null)
  effects=""; root=""
  if [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(cc_state_root "$cwd"); then
    emark="$(cc_plugin_state "$root" code-review)/bash-effects-conventions.mark"
    [ "$tool" = Bash ] && [ ! -d "$seen" ] && effects=$(cc_bash_write_effects "$root" "$emark" "$cmd" "$MAX_BASH_EFFECTS" "$sess")
    cc_bash_effects_mark "$root" "$emark" "$sess"
  fi
  [ -d "$seen" ] && exit 0

  is_code() {
    case "$1" in
      *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.vue|*.svelte|*.php|*.py|*.go|*.rb|*.rs|*.java|*.kt|*.cs|*.css|*.scss) return 0 ;;
    esac
    return 1
  }

  # Every write form the targets block recognises needs one of these; most commands carry none.
  tw=0
  if [ "$tool" = "Bash" ]; then
    case "$cmd" in *'>'*|*tee*|*sed*|*perl*) tw=1 ;; *) [ -n "$effects" ] || exit 0 ;; esac
  else
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
    [ -n "$file" ] || exit 0
    is_code "$file" || exit 0
  fi

  [ -n "$cwd" ] && [ -d "$cwd" ] && [ -n "$root" ] || exit 0

  # A relative Bash target resolves against the payload cwd and must land under the project root; at most 8 targets.
  if [ "$tool" = "Bash" ]; then
    hit=""; n=0; tgts=""
    [ "$tw" = 1 ] && tgts=$(cc_bash_write_targets "$cmd")
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
$tgts
EOF
    while [ -z "$hit" ] && IFS= read -r t; do [ -n "$t" ] && is_code "$t" && hit=1; done <<EOF_E
$effects
EOF_E
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
  [ -f "$root/pyproject.toml" ] && grep -qE '^\[tool\.(ruff|black|isort|mypy)' "$root/pyproject.toml" 2>/dev/null \
    && found="$found pyproject.toml"
  # Kept apart from $found: a prose doc is not a tool, so it never earns the CI paragraph.
  std=""
  for f in CONTRIBUTING.md .github/CONTRIBUTING.md docs/CONTRIBUTING.md CODING_STANDARDS.md \
           docs/CODING_STANDARDS.md STYLEGUIDE.md; do [ -f "$root/$f" ] && std="$std $f"; done

  # The CI lint line is authoritative and not derivable from any config; the six formats differ only in the command prefix.
  ci=""
  ci_try() { # $1 file  $2 ERE for what precedes the command on its line
    [ -n "$ci" ] && return 0
    [ -f "$1" ] || return 1
    line=$(grep -nE "^[[:space:]]*$2.*(lint|format|fmt|pint|rubocop|ruff|biome|prettier|phpstan|psalm|vet)" "$1" 2>/dev/null | head -1)
    [ -n "$line" ] || return 1
    cmd=$(printf '%s' "${line#*:}" | sed -E "s/^[[:space:]]*$2//; s/^[[:space:]]*//; s/[[:space:]]*\$//; s/^['\"]//; s/['\"]\$//")
    ci="${1#$root/}:${line%%:*} — $cmd"
  }
  # The optional dash matters: `- run:` as a list item is the common GitHub shape.
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

  [ -n "$found" ] || [ -n "$ci" ] || [ -n "$std" ] || exit 0

  msg="[code-review] This project defines its own conventions. Read these before writing more code — the files, not a summary of them:"
  [ -n "$found" ] && msg="$msg$(printf '\n  configs:%s' "$found")"
  [ -n "$std" ] && msg="$msg$(printf '\n  standards:%s (a source for naming, structure and idiom only, never for comment volume or docblock style)' "$std")"
  [ -n "$ci" ] && msg="$msg$(printf '\n  CI runs: %s' "$ci")"
  [ -n "$found$ci" ] && msg="$msg$(printf '\n  Whatever CI actually invokes is the tooling standard; a configured tool CI never runs is decoration. If two formatters are configured, exactly one owns formatting — do not add a third, and never add a second linter to a repo that already has one.')"

  jq -cn --arg m "$msg" --arg ev "${hev:-PostToolUse}" \
    '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$m}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
