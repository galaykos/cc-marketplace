#!/bin/bash
# route.sh — PostToolUse, and PostToolUseFailure on a Bash call that exited non-zero; fails open: matches the edited file, each existing file a Bash command wrote under the project root (named by
# the command, or — after an interpreter, cp, mv, install or patch run — changed in git since this hook's previous call), and the
# command itself against rules.tsv; prints one additionalContext envelope of at most NUDGE_CAP `high` nudges naming plugin:skill, each skill
# once per context and none the context already loaded; queues other content matches as pending_low, none from a doc or style file.
# Speaks about no target outside the root, under taskmaster-docs/ or .claude/, or ignored by git.
# Off: CC_REMIND=off, or unset with the /config option cc_remind off. CC_ROUTE is not read here: it silences route-prompt.sh, the tool-fit check and the flush of what this hook queues.
# Misses: two concurrent calls can drop a pending_low entry; a payload cwd of `/` or `$HOME` outside git is taken for the project root;
# a directory row matches only the directory name it spells (in any case); a command row routes an unquoted mention of its CLI
# and misses a CLI run through a script or an npm alias; a Bash command's write targets past the eighth (MAX_BASH_TARGETS) are not read,
# nor changed files past the eighth (MAX_BASH_EFFECTS); the bash-write-effects block's own misses apply, and a file anything else changed
# between this hook's calls (an IDE, a parallel agent) is read as that run's write.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/route.sh
MAX_BASH_TARGETS=8
MAX_BASH_EFFECTS=8

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
# route_cmd_mask <command> prints the command as command rows see it: quoted text as `_`, heredoc bodies blank, `$(…)` live.
route_cmd_mask() {
  printf '%s\n' "$1" | awk '
    BEGIN { st = "U"; nq = 0; qh = 1 }
    qh <= nq {
      t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (t == hq[qh]) qh++
      print ""; next
    }
    {
      line = $0; out = ""; n = length(line)
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1); two = substr(line, i, 2); top = substr(st, length(st), 1)
        if (top == "S") {
          if (c == "\047") { st = substr(st, 1, length(st) - 1); out = out c } else out = out "_"
          continue
        }
        if (top == "D") {
          if (c == "\\") { out = out "__"; i++ }
          else if (c == "\"") { st = substr(st, 1, length(st) - 1); out = out c }
          else if (two == "$(") { st = st "C"; out = out two; i++ }
          else out = out "_"
          continue
        }
        if (c == "\\") { out = out "__"; i++; continue }
        if (c == "\047") { st = st "S"; out = out c; continue }
        if (c == "\"") { st = st "D"; out = out c; continue }
        if (top == "C" && c == ")") { st = substr(st, 1, length(st) - 1); out = out c; continue }
        if (two == "$(") { st = st "C"; out = out two; i++; continue }
        if (substr(line, i, 3) == "<<<") { out = out "<<<"; i += 2; continue }
        if (two == "<<" && match(substr(line, i + 2), /^-?[ \t]*["\047\\]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
          w = substr(line, i + 2, RLENGTH); sub(/^-?[ \t]*["\047\\]?/, "", w); sub(/["\047]$/, "", w)
          hq[++nq] = w; out = out substr(line, i, RLENGTH + 2); i += RLENGTH + 1; continue
        }
        out = out c
      }
      print out
    }'
}
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  rules="${CLAUDE_PLUGIN_ROOT}/rules.tsv"
  [ -f "$rules" ] || exit 0
  # A failed Bash call fires PostToolUseFailure, whose envelope must name that event.
  { IFS= read -r cwd; IFS= read -r sess; IFS= read -r hev; } < <(printf '%s' "$input" \
    | jq -r '.cwd // "", .session_id // "", if .hook_event_name == "PostToolUseFailure" then .hook_event_name else "PostToolUse" end' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0
  state_dir=$(cc_plugin_state "$root" skill-router)
  effects_mark="$state_dir/bash-effects.mark"
  bash_targets=""; bash_effects=""; cmd_hits=""
  if [ "$tool" = Bash ]; then
    bash_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$bash_cmd" ] || exit 0
    # Every shape cc_bash_write_targets returns holds one of these words, so a miss skips its awk safely.
    case "$bash_cmd" in
      *'>'*|*tee*|*sed*|*perl*) bash_targets=$(cc_bash_write_targets "$bash_cmd" | head -n "$MAX_BASH_TARGETS") ;;
    esac
    cmd_masked=""; masked=0
    while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
      [ "${conf%$'\r'}" = high ] || continue
      printf '%s' "$bash_cmd" | grep -qE "$pattern" 2>/dev/null || continue
      [ "$masked" = 1 ] || { cmd_masked=$(route_cmd_mask "$bash_cmd"); masked=1; }
      m=$(printf '%s' "$cmd_masked" | grep -m1 -oE "$pattern" 2>/dev/null) || continue
      # An empty marker is spelled `-`: a tab-IFS `read` collapses an empty field and would shift the matched text into it.
      m="${m%%$'\n'*}"; marker="${marker%$'\r'}"; [ -n "$marker" ] || marker=-
      cmd_hits="${cmd_hits}${skill}"$'\t'"${plugin}"$'\t'"${marker}"$'\t'"${m}"$'\n'
    done < <(grep "^command"$'\t' "$rules" 2>/dev/null)
    bash_effects=$(cc_bash_write_effects "$root" "$effects_mark" "$bash_cmd" "$MAX_BASH_EFFECTS" "$sess")
  fi
  # Every call dates the marker, an Edit or a command that wrote nothing too, so a run's effects are only what changed after the
  # previous call. The tool has finished before PostToolUse runs, so dating it here equals dating it as the hook exits.
  cc_bash_effects_mark "$root" "$effects_mark" "$sess"
  [ "$tool" != Bash ] || [ -n "$bash_targets" ] || [ -n "$bash_effects" ] || [ -n "$cmd_hits" ] || exit 0

  # Context key, not session key: a subagent shares its parent's session_id but has its own transcript.
  session_id=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null) || exit 0
  file_path=""
  if [ "$tool" != Bash ]; then
    # pathInProject: the JetBrains MCP create_new_file key.
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null) || exit 0
    [ -n "$file_path" ] || exit 0
  fi
  [ -n "$session_id" ] || exit 0

  # route_target_ok <path> — a file worth a rubric: under the project root, outside taskmaster-docs/ and .claude/, not ignored by git.
  # Nudges fired on gitignored scratch scripts, taskmaster-docs evidence files and vendored copies, where nobody applies one.
  # Misses: an ignored file outside any git repo routes; a committed vendored tree routes; a path spelled through another symlink than the root's reads as outside.
  route_target_ok() {
    case "$1" in "$root"/*) ;; *) return 1 ;; esac
    case "/${1#"$root"/}" in */taskmaster-docs/*|*/.claude/*) return 1 ;; esac
    ! git -C "$root" check-ignore -q -- "$1" 2>/dev/null
  }

  # Two parallel arrays per target: rec, the spelling pending_low records; abs, the file on disk.
  rec=(); abs=()
  if [ "$tool" = Bash ]; then
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      case "$t" in /*) p="$t" ;; *) p="$cwd/$t" ;; esac
      pd="${p%/*}"; [ -n "$pd" ] || pd=/
      pd=$(CDPATH= cd -- "$pd" 2>/dev/null && pwd) || continue
      p="${pd%/}/${p##*/}"
      [ -f "$p" ] || continue
      route_target_ok "$p" || continue
      for q in "${abs[@]}"; do [ "$q" = "$p" ] && continue 2; done
      rec+=("$p"); abs+=("$p")
    done <<EOF_TARGETS
$bash_targets
$bash_effects
EOF_TARGETS
    [ "${#abs[@]}" -gt 0 ] || [ -n "$cmd_hits" ] || exit 0
  else
    p="$cwd/$file_path"
    case "$file_path" in /*) p="$file_path" ;; esac
    # Resolved only to test the root prefix (`../`); a directory that does not exist keeps the spelling it was given.
    pd=$(CDPATH= cd -- "${p%/*}" 2>/dev/null && pwd) && pt="${pd%/}/${p##*/}" || pt="$p"
    route_target_ok "$pt" || exit 0
    rec+=("$file_path"); abs+=("$p")
  fi

  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$(dirname "$0")/plugins-dir.sh" 2>/dev/null
  command -v pr_resolve_plugins_dir >/dev/null 2>&1 && pr_resolve_plugins_dir

  # Hashed: the context key is usually an absolute path, and a raw one names a file whose parent directories never exist.
  ctx=$(printf '%s' "$session_id" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  state_file="$state_dir/fired-$ctx.json"
  fired=""
  # `loaded` holds skills the transcript showed loaded before any nudge: skipped like fired ones, but kept out of `fired`, which the
  # SessionEnd ledger reports as surfaced by this router.
  [ -r "$state_file" ] && fired=$(jq -r '((.fired // []) + (.loaded // []))[]' "$state_file" 2>/dev/null)

  # set_target <i> — the globals every matcher below reads, for target i.
  set_target() {
    file_path="${rec[$1]}"; target="${abs[$1]}"
    base=$(basename "$file_path")
    rel="$file_path"
    case "$target" in "$root"/*) rel="${target#"$root"/}" ;; esac
  }

  # A code or style file, the only kind a `content`+`high` row fires inline on (nudge_high_matches).
  inline_ext() {
    case "$base" in
      *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte|*.astro|*.css|*.scss|*.sass|*.less|*.html|*.php|*.twig|*.erb) return 0 ;;
    esac
    return 1
  }

  plugin_installed() { # $1 owning_plugin — fire-if-uncertain
    command -v pr_plugin_installed >/dev/null 2>&1 || return 0
    pr_plugin_installed "$1"
  }
  already_fired() { printf '%s\n' "$fired" | grep -qxF "$1"; }

  match_glob() { # $1 pattern
    # Case-insensitive: scaffolders ship one framework directory as both `Pages` and `pages`.
    local pat="$1" rc=1 nocase_was_off=1
    shopt -q nocasematch && nocase_was_off=0
    shopt -s nocasematch
    case "$pat" in
      '**/'*'/**')
        local mid="${pat#**/}"; mid="${mid%/**}"
        case "/$rel" in *"/$mid/"*) rc=0 ;; esac ;;
      *)
        case "$base" in $pat) rc=0 ;; esac ;;
    esac
    [ "$nocase_was_off" -eq 1 ] && shopt -u nocasematch
    return "$rc"
  }

  marker_ok() { # $1 stack_marker — 0 = fire, 1 = suppress
    local list="$1" alt m neg req manifest regex mcontent rc
    [ -z "$list" ] || [ "$list" = "-" ] && return 0
    while [ -n "$list" ]; do
      alt="${list%%||*}"
      if [ "$alt" = "$list" ]; then list=""; else list="${list#*||}"; fi
      m="$alt"; neg=0; req=0
      case "$m" in '?'*) req=1; m="${m#'?'}" ;; esac
      case "$m" in '!'*) neg=1; m="${m#!}" ;; esac
      manifest="${m%%~*}"
      regex="${m#*~}"
      [ "$manifest" = "$m" ] && continue
      [ -n "$manifest" ] && [ -n "$regex" ] || continue
      if [ "$manifest" = "@base" ]; then
        mcontent="$base"
      elif [ "$manifest" = "@path" ]; then
        mcontent="$rel"
      elif [ -f "$root/$manifest" ] && [ -r "$root/$manifest" ] \
           && mcontent=$(head -c 65536 "$root/$manifest" 2>/dev/null); then
        :
      else
        [ "$req" -eq 1 ] && return 1
        continue
      fi
      printf '%s' "$mcontent" | grep -qE "$regex" 2>/dev/null
      rc=$?
      [ "$rc" -ge 2 ] && continue
      [ "$neg" -eq 1 ] && rc=$((1 - rc))
      return "$rc"
    done
    return 0
  }

  nudges=""
  emit_nudge() { # $1 skill, $2 owning_plugin, $3 its root or empty, $4 subject — accumulates; delivered once below.
    # Qualified: a bare name loaded a project's own .claude/skills copy of the same name instead of this plugin's file.
    # A subagent has no Skill tool, so the nudge names the SKILL.md path to Read when one is found.
    local sp=""
    [ -n "$3" ] && [ -f "$3/skills/$1/SKILL.md" ] && sp=" (or Read $3/skills/$1/SKILL.md)"
    nudges="${nudges}$(printf '[skill-router] Load the `%s:%s` skill for %s%s and check your change against it.' "$2" "$1" "$4" "$sp")"$'\n'
  }

  # At most NUDGE_CAP nudges per call: arriving several at once (seven on one vendored copy) they were almost never followed, 0 of 25
  # and 0 of 14 in two measured sessions. Rank 0, an import or command row (the edit named that library or CLI), beats rank 1, any other
  # row, which beats rank 2, the skills rules.tsv's `# nudge-last:` line names: they match every file of their language, so the next
  # such edit draws them again, where a path-specific skill may not recur. Ties keep target and rules.tsv order. A skill left over is
  # not marked fired, so a later edit can carry it.
  NUDGE_CAP=2
  last_skills=$(sed -n 's/^# nudge-last:[[:space:]]*//p' "$rules" 2>/dev/null | tr -d '\r' | tr ' \t' '\n\n')
  cands=""; cand_skills=""; seq=0
  add_cand() { # $1 rank, $2 skill, $3 owning_plugin, $4 subject — a skill matched again keeps its lowest rank, with that match's place and subject
    local pr="" old
    printf '%s\n' "$last_skills" | grep -qxF "$2" && set -- 2 "$2" "$3" "$4"
    if printf '%s\n' "$cand_skills" | grep -qxF "$2"; then
      old=$(printf '%s' "$cands" | awk -F'\t' -v s="$2" '$3 == s {print $1; exit}')
      [ "$1" -lt "${old:-0}" ] || return 0
      cands=$(printf '%s' "$cands" | awk -F'\t' -v s="$2" '$3 != s'); [ -z "$cands" ] || cands="$cands"$'\n'
    else
      cand_skills="${cand_skills}$2"$'\n'
    fi
    command -v pr_plugin_root >/dev/null 2>&1 && pr=$(pr_plugin_root "$3")
    [ -n "$pr" ] || pr=- # a tab-IFS `read` collapses an empty field
    seq=$((seq + 1))
    cands="${cands}$1"$'\t'"$seq"$'\t'"$2"$'\t'"$3"$'\t'"$pr"$'\t'"$4"$'\n'
  }

  # A skill whose own file is already in this context: the "Base directory for this skill: <dir>" line a Skill call writes, a Read of
  # its SKILL.md, or a qualified Skill call. One fixed-string grep over the whole transcript, only while a candidate exists: 32 ms on
  # the largest local transcript (56 MB), about 1 ms at the median (0.7 MB). A tail read would miss a skill loaded at session start,
  # the common case. A project's copy of the same bare name is another path and never counts. Misses: a load the host has not yet
  # written to the file; a cache path from before a mid-session plugin update. Counts: a load a compaction has since summarised away.
  loaded=""
  scan_loaded() {
    local pats="" r s sk pl pr subj
    [ -n "$cands" ] && [ -f "$session_id" ] && [ -r "$session_id" ] || return 0
    while IFS=$'\t' read -r r s sk pl pr subj; do
      [ -n "$sk" ] || continue
      pats="${pats}\"skill\":\"$pl:$sk\""$'\n'
      [ "$pr" != - ] && pats="${pats}Base directory for this skill: $pr/skills/$sk\\n"$'\n'"\"file_path\":\"$pr/skills/$sk/SKILL.md\""$'\n'
    done <<< "$cands"
    loaded=$(printf '%s' "$pats" | grep -oF -f /dev/stdin -- "$session_id" 2>/dev/null | sort -u)
  }
  is_loaded() { # $1 skill, $2 owning_plugin, $3 its root or empty
    [ -n "$loaded" ] || return 1
    printf '%s\n' "$loaded" | grep -qxF -e "\"skill\":\"$2:$1\"" -e "Base directory for this skill: $3/skills/$1\\n" -e "\"file_path\":\"$3/skills/$1/SKILL.md\""
  }

  nudge_high_matches() {
    fired_now=""; loaded_now=""
    hcs=()
    i=0
    while [ "$i" -lt "${#abs[@]}" ]; do
      set_target "$i"; i=$((i + 1))
      hc=""; [ -r "$target" ] && hc=$(head -c 65536 "$target" 2>/dev/null)
      hcs+=("$hc")
      inline=0; inline_ext && inline=1
      while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
        case "$stype" in ''|'#'*) continue ;; esac
        conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
        [ "$conf" = high ] || continue
        case "$stype" in
          glob) match_glob "$pattern" || continue; rank=1 ;;
          content)
            [ "$inline" = 1 ] && [ -n "$hc" ] || continue
            already_fired "$skill" && continue
            printf '%s' "$hc" | grep -qE "$pattern" 2>/dev/null || continue; rank=0 ;;
          *) continue ;;
        esac
        plugin_installed "$plugin" || continue
        marker_ok "$marker" || continue
        already_fired "$skill" && continue
        add_cand "$rank" "$skill" "$plugin" "$base"
      done < "$rules"
    done
    # A command row has no file, so `@base` and `@path` markers see an empty string.
    base=""; rel=""
    while IFS=$'\t' read -r skill plugin marker frag; do
      [ -n "$skill" ] || continue
      plugin_installed "$plugin" || continue
      marker_ok "$marker" || continue
      already_fired "$skill" && continue
      add_cand 0 "$skill" "$plugin" "\`${frag}\`"
    done <<EOF_CMD
$cmd_hits
EOF_CMD
    scan_loaded
    n=0
    while IFS=$'\t' read -r r s skill plugin pr subj; do
      [ -n "$skill" ] || continue
      [ "$pr" != - ] || pr=""
      # Recorded as loaded: otherwise every later edit routing it greps the whole transcript again.
      is_loaded "$skill" "$plugin" "$pr" && { loaded_now="${loaded_now}${skill}"$'\n'; continue; }
      emit_nudge "$skill" "$plugin" "$pr" "$subj"
      fired_now="${fired_now}${skill}"$'\n'
      n=$((n + 1)); [ "$n" -lt "$NUDGE_CAP" ] || break
    done < <(printf '%s' "$cands" | sort -t $'\t' -k1,1n -k2,2n)
  }

  deliver_nudges() {
    if [ -n "$nudges" ]; then
      jq -cn --arg ctx "${nudges%$'\n'}" --arg ev "$hev" \
        '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$ctx}}'
    fi
  }

  # Reads hcs, the one head per target nudge_high_matches read.
  # Doc and style files queue nothing: `token` in a spec or a CSS file queued security-review. Same exemption as database's guard.sh;
  # the cost is a doc that really is about the concern (a security runbook) drawing no signal.
  queue_low_matches() {
    pending_adds=""
    i=0
    while [ "$i" -lt "${#abs[@]}" ]; do
      set_target "$i"; content="${hcs[$i]}"; i=$((i + 1))
      [ -n "$content" ] || continue
      case "$target" in *.md|*.mdx|*.markdown|*.txt|*.rst|*.css|*/taskmaster-docs/*) continue ;; esac
      inline=0; inline_ext && inline=1
      while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
        case "$stype" in ''|'#'*) continue ;; esac
        conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
        [ "$stype" = content ] || continue
        [ "$conf" = high ] && [ "$inline" = 1 ] && continue
        plugin_installed "$plugin" || continue
        marker_ok "$marker" || continue
        if printf '%s' "$content" | grep -qE "$pattern" 2>/dev/null; then
          pending_adds="${pending_adds}${skill}"$'\t'"${plugin}"$'\t'"${file_path}"$'\n'
        fi
      done < "$rules"
    done
  }

  persist_state() {
    if [ -n "$fired_now" ] || [ -n "$loaded_now" ] || [ -n "$pending_adds" ]; then
      mkdir -p "$state_dir" 2>/dev/null || exit 0
      [ -e "$state_dir/.gitignore" ] || printf '*\n' > "$state_dir/.gitignore" 2>/dev/null
      json='{"fired":[],"loaded":[],"pending_low":[]}'
      if [ -r "$state_file" ]; then
        existing=$(cat "$state_file" 2>/dev/null)
        printf '%s' "$existing" | jq empty 2>/dev/null && json="$existing"
      fi
      if [ -n "$fired_now" ]; then
        while IFS= read -r fskill; do
          [ -n "$fskill" ] || continue
          json=$(printf '%s' "$json" | jq --arg s "$fskill" \
            'if (.fired | index($s) | not) then .fired += [$s] else . end' 2>/dev/null) || exit 0
        done <<EOF_FIRED
$fired_now
EOF_FIRED
      fi
      if [ -n "$loaded_now" ]; then
        while IFS= read -r lskill; do
          [ -n "$lskill" ] || continue
          json=$(printf '%s' "$json" | jq --arg s "$lskill" \
            'if ((.loaded // []) | index($s) | not) then .loaded = ((.loaded // []) + [$s]) else . end' 2>/dev/null) || exit 0
        done <<EOF_LOADED
$loaded_now
EOF_LOADED
      fi
      if [ -n "$pending_adds" ]; then
        while IFS=$'\t' read -r pskill pplug pfile; do
          [ -n "$pskill" ] || continue
          json=$(printf '%s' "$json" | jq --arg sk "$pskill" --arg pl "$pplug" --arg f "$pfile" \
            'if (.pending_low | any(.skill==$sk and .file==$f)) then . else .pending_low += [{skill:$sk,plugin:$pl,file:$f}] end' 2>/dev/null) || break
        done <<EOF
$pending_adds
EOF
      fi
      printf '%s\n' "$json" > "$state_file" 2>/dev/null || exit 0
    fi
  }

  nudge_high_matches
  # Before persist_state: an unwritable state dir must not swallow a nudge the model should have seen.
  deliver_nudges
  queue_low_matches
  persist_state
} 2>/dev/null
exit 0
