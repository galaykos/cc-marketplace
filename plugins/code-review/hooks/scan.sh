#!/bin/bash
# Comment-noise guard on added text: PreToolUse denies a restating comment, commented-out code, a signature-echo doc tag and code replaced by a placeholder; PostToolUse warns on the rest.
# Misses: echo/printf and sed -i text, a heredoc not fed to cat/tee, interpreter writes before they land; each deny stops at two per file per session. Off: CC_COMMENT_GUARD, CC_ELISION_GUARD, CC_REMIND (warn).
# Why, limits, history: rationale/derivations/plugin-code-review.md § plugins/code-review/hooks/scan.sh

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
# A backup suffix is never a target: the word after BSD sed's -I, or a `''` or `.`-led word after a bare sed -i unless it is the only file.
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

# Shared block templates/blocks/bash-write-chunks.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-chunks.md
# cc_bash_write_chunks <command> prints a \036 + WRITER line, then the text as written, per heredoc body and echo/printf
# argument list, any `> file` redirect kept (never anchor a match); the caller resolves WRITER with cc_bash_write_targets.
# mask() repeats the one in cc_bash_write_targets: a byte-locked block's awk program cannot call another block's functions.
# Misses: `{ echo …; } > f`, here-strings, printf's substituted output, a string or `\` continuation spanning lines,
# two heredocs on one line, text after a `&` inside `$(( ))`/`${ }`.
cc_bash_write_chunks() {
  printf '%s\n' "$1" | awk '
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
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
    function echo_args(p, mp,   i, st, seg, out) {
      out = ""; st = 1
      for (i = 1; i <= length(mp) + 1; i++) {
        if (i > length(mp) || substr(mp, i, 1) == "|") {
          seg = substr(mp, st, i - st)
          if (match(seg, /^[ \t]*(echo|printf)[ \t]/)) out = out substr(p, st + RLENGTH, i - st - RLENGTH) "\n"
          st = i + 1
        }
      }
      return out
    }
    inbody { if (trim($0) == term) inbody = 0; else print; next }
    {
      line = $0; m = mask(line); st = 1; opener = ""
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c2 == "||" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>|]/) {
          if (i > st) {
            p = substr(line, st, i - st); mp = substr(m, st, i - st)
            a = echo_args(p, mp)
            if (a != "") printf "\036%s\n%s", p, a
            if (opener == "" && match(mp, /(^|[^<])<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
              t = substr(p, RSTART, RLENGTH)
              sub(/^[^<]*<<-?[ \t]*["\047]?/, "", t); sub(/^\\/, "", t); sub(/[^A-Za-z0-9_].*$/, "", t)
              if (t != "") { opener = p; term = t }
            }
          }
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1
        }
      }
      if (opener != "") { printf "\036%s\n", opener; inbody = 1 }
    }'
}

# Shared block templates/blocks/bash-write-effects.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-effects.md
# cc_bash_effects_mark <root> <marker> <session> rewrites <marker> to hold <session>'s cksum when <root> holds a .git, and gives its
# directory a `*` .gitignore when it has none. Call it on EVERY call the hook sees (Write, Edit, Bash, a failed Bash too), after
# cc_bash_write_effects read <marker>. cc_bash_write_effects <root> <marker> <command> <max> <session> prints at most <max> absolute
# paths, one per line: files `git status` under <root> reports changed or untracked and newer than <marker> (a plugin state dir stays out
# by its `*` .gitignore). It runs git only when <command> holds python, node, php, ruby, perl (any version suffix or directory), nodejs,
# deno, bun, cp, mv, install or patch as a word, <marker> holds <session>'s cksum (another session's marker reads as none), <root> is not
# $HOME and status.showUntrackedFiles is not no. Misses: writers it does not name, gitignored files, submodules, no git, each session's
# first call, a file written then reverted, a mv or cp -p destination (it keeps the source's mtime), files past <max>. Reads too much:
# any change since <marker> — an IDE, a parallel agent, a job, a state file another tool keeps in a .claude/ dir git does not ignore.
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
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0
  MAX_BASH_EFFECTS=8   # changed files read after an interpreter, cp, mv, install or patch run, in git's path order

  input=$(cat)
  # Absent event name = PostToolUse; a failed Bash call's PostToolUseFailure takes that lane, its envelope naming the event (hev).
  event=""; sess=""
  { IFS= read -r event; IFS= read -r sess; } < <(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse", .session_id // ""' 2>/dev/null)
  [ -n "$event" ] || exit 0
  hev=PostToolUse; [ "$event" = PostToolUseFailure ] && { hev=$event; event=PostToolUse; }
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Edit|Write|MultiEdit|Bash) ;; *) exit 0 ;; esac
  [ "$tool" = Bash ] && { cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0; }
  # CC_REMIND silences the WARN lane only: a deny is not an advisory, so an env var must not turn a block into a pass.
  remind=$(cc_option CC_REMIND on)
  [ "$event" = "PostToolUse" ] && [ "$remind" = "off" ] && exit 0
  # Read effects with the old marker, then date it on every call this lane sees, or an Edit's file reads as the next run's write.
  effects=""; root=""
  if [ "$event" = "PostToolUse" ]; then
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    if [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(cc_state_root "$cwd"); then
      emark="$(cc_plugin_state "$root" comment-discipline)/bash-effects-scan.mark"
      [ "$tool" = Bash ] && effects=$(cc_bash_write_effects "$root" "$emark" "$cmd" "$MAX_BASH_EFFECTS" "$sess")
      cc_bash_effects_mark "$root" "$emark" "$sess"
    fi
  fi
  if [ "$tool" = Bash ]; then
    # A command with very long lines is not parsed (the blocks are quadratic per line); files an interpreter run changed are still judged.
    tgts=""
    [ "${#cmd}" -gt 32768 ] && printf '%s\n' "$cmd" | awk 'length($0) > 2000 { s += length($0) } length($0) > 8192 || s > 32768 { f = 1; exit } END { exit !f }' \
      || tgts=$(cc_bash_write_targets "$cmd")
    [ -n "$tgts" ] || [ -n "$effects" ] || exit 0
  fi
  [ "$event" = "PostToolUse" ] || cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  # Two denies, two switches: CC_COMMENT_GUARD=off stops the comment deny, CC_ELISION_GUARD=off turns only the elision deny into a warning.
  cguard=on; elide=off
  if [ "$event" = "PreToolUse" ]; then
    cguard=$(cc_option CC_COMMENT_GUARD on); elide=$(cc_option CC_ELISION_GUARD on)
    [ "$cguard" = off ] && [ "$elide" = off ] && [ "$remind" = off ] && exit 0
  fi

  # Code only, build files included (a Dockerfile is a step list); YAML and prose formats use comments to navigate. The list: cd_governed in paths.sh.
  . "$(dirname "$0")/paths.sh" 2>/dev/null

  scan_judge() {
  fp=$1 added=$2 msg=""
  [ -n "$fp" ] || return 1
  cd_governed "$fp" || return 1

  # Generated, vendored and tooling paths are exempt, tested on the logical path (worktree prefix stripped); a missing paths.sh judges nothing.
  root=$(cc_state_root "$cwd") || root=""   # no root is not a marketplace: the file is still judged
  command -v cd_path_exempt >/dev/null 2>&1 || return 1
  cd_path_exempt "$fp" "$root" && return 1

  [ -n "$added" ] || return 1

  cd_lang "$fp"
  raw=$(printf '%s\n' "$added" | scan_awk)
  scan_verdict
  }

  # scan_awk [elision|elision-lines]: `elision` prints elision_n's count, EO and EL; `elision-lines` each line elision_n would name, at most 64.
  scan_awk() { awk -v lang="${cd_lang_key:-}" -v only="${1:-}" '
  function add_tok(set, w,   x) {
    if (w == "") return
    x = tolower(w)
    if (length(x) < 2) return
    set[x] = 1
    if (length(x) > 3 && substr(x, length(x)) == "s") set[substr(x, 1, length(x) - 1)] = 1
  }
  # A name says a word only once camelCase and snake_case are split back into words.
  function split_ident(w, set,   i, c, cur) {
    cur = ""
    for (i = 1; i <= length(w); i++) {
      c = substr(w, i, 1)
      if (c == "_" || c == "$" || c == "-") { add_tok(set, cur); cur = ""; continue }
      if (c ~ /[A-Z]/ && cur != "" && substr(cur, length(cur)) ~ /[a-z0-9]/) {
        add_tok(set, cur); cur = c; continue
      }
      cur = cur c
    }
    add_tok(set, cur)
  }
  function code_tokens(l, set,   n, arr, i, w) {
    n = split(l, arr, /[^A-Za-z0-9_$]+/)
    for (i = 1; i <= n; i++) {
      w = arr[i]
      if (w == "") continue
      add_tok(set, w)
      split_ident(w, set)
    }
  }
  # Operators say in symbols what a restating comment says in words: "increment the counter" over counter++.
  function op_tokens(l, set) {
    if (l ~ /\+\+/)   { add_tok(set, "increment"); add_tok(set, "increase"); add_tok(set, "bump"); add_tok(set, "count") }
    if (l ~ /--/)     { add_tok(set, "decrement"); add_tok(set, "decrease"); add_tok(set, "subtract") }
    if (l ~ /\+=/)    { add_tok(set, "add"); add_tok(set, "increment"); add_tok(set, "append"); add_tok(set, "increase") }
    if (l ~ /-=/)     { add_tok(set, "subtract"); add_tok(set, "decrease") }
    if (l ~ /=/)      { add_tok(set, "set"); add_tok(set, "assign"); add_tok(set, "store"); add_tok(set, "save"); add_tok(set, "update"); add_tok(set, "initialize"); add_tok(set, "init"); add_tok(set, "define"); add_tok(set, "declare"); add_tok(set, "value") }
    if (l ~ /(^|[^A-Za-z])return([^A-Za-z]|$)/) { add_tok(set, "return"); add_tok(set, "result"); add_tok(set, "output"); add_tok(set, "give") }
    if (l ~ /(^|[^A-Za-z])if([^A-Za-z]|$)/)     { add_tok(set, "check"); add_tok(set, "handle"); add_tok(set, "test") }
    if (l ~ /(^|[^A-Za-z])(for|while|forEach|foreach|map)([^A-Za-z]|$)/) { add_tok(set, "loop"); add_tok(set, "iterate"); add_tok(set, "over"); add_tok(set, "through"); add_tok(set, "every") }
    if (l ~ /(^|[^A-Za-z])new([^A-Za-z]|$)/)    { add_tok(set, "create"); add_tok(set, "make"); add_tok(set, "instantiate"); add_tok(set, "build"); add_tok(set, "construct") }
    if (l ~ /(^|[^A-Za-z])(throw|raise)([^A-Za-z]|$)/) { add_tok(set, "throw"); add_tok(set, "raise"); add_tok(set, "error"); add_tok(set, "fail") }
    if (l ~ /(^|[^A-Za-z])(delete|remove|unset|splice|drop)([^A-Za-z]|$)/) { add_tok(set, "delete"); add_tok(set, "remove"); add_tok(set, "drop"); add_tok(set, "clear") }
    if (l ~ /(^|[^A-Za-z])(push|append|insert|add)([^A-Za-z]|$)/) { add_tok(set, "add"); add_tok(set, "append"); add_tok(set, "insert") }
    if (l ~ /(^|[^A-Za-z])(import|require|include|use)([^A-Za-z]|$)/) { add_tok(set, "import"); add_tok(set, "load"); add_tok(set, "require"); add_tok(set, "include") }
    if (l ~ /(^|[^A-Za-z])(log|print|echo|puts|printf|println)([^A-Za-z]|$)/) { add_tok(set, "log"); add_tok(set, "print"); add_tok(set, "output"); add_tok(set, "debug"); add_tok(set, "write"); add_tok(set, "show") }
    if (l ~ /(^|[^A-Za-z])(await|async)([^A-Za-z]|$)/) { add_tok(set, "wait"); add_tok(set, "await"); add_tok(set, "async") }
    if (l ~ /(^|[^A-Za-z])(try|catch|except|rescue)([^A-Za-z]|$)/) { add_tok(set, "try"); add_tok(set, "catch"); add_tok(set, "handle"); add_tok(set, "error"); add_tok(set, "guard") }
    if (l ~ /(^|[^A-Za-z])(null|nil|None|undefined)([^A-Za-z]|$)/) { add_tok(set, "clear"); add_tok(set, "reset"); add_tok(set, "empty"); add_tok(set, "blank") }
    if (l ~ /(^|[^A-Za-z])true([^A-Za-z]|$)/)  { add_tok(set, "enable"); add_tok(set, "allow"); add_tok(set, "on") }
    if (l ~ /(^|[^A-Za-z])false([^A-Za-z]|$)/) { add_tok(set, "disable"); add_tok(set, "block"); add_tok(set, "off") }
    if (l ~ /(length|count|size)/)  { add_tok(set, "count"); add_tok(set, "length"); add_tok(set, "size"); add_tok(set, "number"); add_tok(set, "total") }
    if (l ~ /sort/)   { add_tok(set, "sort"); add_tok(set, "order"); add_tok(set, "rank") }
    if (l ~ /filter/) { add_tok(set, "filter"); add_tok(set, "keep"); add_tok(set, "select"); add_tok(set, "exclude") }
    if (l ~ /(function|=>|def )/) { add_tok(set, "define"); add_tok(set, "declare"); add_tok(set, "function"); add_tok(set, "helper") }
    if (l ~ /\+/) { add_tok(set, "add"); add_tok(set, "sum"); add_tok(set, "plus"); add_tok(set, "concat"); add_tok(set, "join"); add_tok(set, "combine") }
    if (l ~ /\*/) { add_tok(set, "multiply"); add_tok(set, "times"); add_tok(set, "product") }
    if (l ~ /\//) { add_tok(set, "divide"); add_tok(set, "ratio") }
    if (l ~ /%/)  { add_tok(set, "modulo"); add_tok(set, "remainder") }
    if (l ~ /[<>]/) { add_tok(set, "compare"); add_tok(set, "greater"); add_tok(set, "less"); add_tok(set, "than"); add_tok(set, "exceeds") }
    if (l ~ /(\?\?|\|\|)/) { add_tok(set, "default"); add_tok(set, "fallback") }
  }
  # Outside a block opened by a line starting /*, a *-led line is C, a shell case arm or a Markdown list.
  function cbody(l,   s, was, k) {
    s = l
    sub(/^[ \t]+/, "", s)
    was = blk; indoc = blk && dblk; dl = 0; opened = 0; cl = 0
    if (blk && (k = index(s, "*/"))) { blk = 0; if (substr(s, k + 2) ~ /[^ \t\r]/) { cl = 1; return "" } }
    if (s ~ /^#!/) return ""
    if (LS && s ~ /^\/\//)  { dl = (s ~ /^\/\/[\/!]/ && s !~ /^\/\/\/\//); sub(/^\/\/+[ \t]*/, "", s); return s }
    if (LB && s ~ /^\/\*/ && !(lang == "sql" && s ~ /^\/\*[+!]/)) {
      if (!was && (k = index(substr(s, 3), "*/")) && substr(s, k + 4) ~ /[^ \t\r]/) return ""
      if (!was) { blk = !k; dblk = (s ~ /^\/\*\*/ && s !~ /^\/\*\*\//); indoc = dblk; opened = 1 }
      sub(/^\/\*+[ \t]*/, "", s); sub(/[ \t]*\*\/[ \t]*$/, "", s); return s
    }
    if (was && s ~ /^\*/ && s !~ /^\*[A-Za-z0-9_(]/) { sub(/^\*+[ \t]*/, "", s); sub(/[ \t]*\*\/[ \t]*$/, "", s); return s }
    if (LH && (s ~ /^#[ \t]/ || s ~ /^##/)) { sub(/^#+[ \t]*/, "", s); return s }
    if (LD && s ~ /^-- /)   { sub(/^--[ \t]*/, "", s); return s }
    return ""
  }
  # The language-blind leaders: a line they read as a comment is never a restatement target.
  function obody(l,   s) {
    s = l
    sub(/^[ \t]+/, "", s)
    if (s ~ /^#!/) return ""
    if (s ~ /^\/\//)  { sub(/^\/\/+[ \t]*/, "", s); return s }
    if (s ~ /^\/\*/)  { sub(/^\/\*+[ \t]*/, "", s); sub(/[ \t]*\*\/[ \t]*$/, "", s); return s }
    if (s ~ /^\*/ && s !~ /^\*[A-Za-z0-9_(]/) { sub(/^\*+[ \t]*/, "", s); sub(/[ \t]*\*\/[ \t]*$/, "", s); return s }
    if (s ~ /^#[ \t]/ || s ~ /^##/) { sub(/^#+[ \t]*/, "", s); return s }
    if (s ~ /^-- /)   { sub(/^--[ \t]*/, "", s); return s }
    return ""
  }
  # Legal, machine-read and tool-directive comments are outside this rule.
  function exempt(b,   x) {
    x = tolower(b)
    if (x ~ /spdx|copyright|all rights reserved|licensed under|license:|licence:/) return 1
    if (x ~ /eslint-|tslint|jshint|ts-expect-error|ts-ignore|@ts-|type: *ignore|noqa|phpcs:|phpstan-|psalm-|prettier-ignore|biome-ignore|stylelint-|pylint:|rubocop:|nolint|golangci|istanbul ignore|c8 ignore|codecoverageignore|shellcheck|coverage:/) return 1
    if (lang == "dockerfile" && x ~ /^(syntax|escape|check)=/) return 1
    return 0
  }
  function is_banner(b,   c) {
    if (b !~ /^[=*#_~-][=*#_~-][=*#_~-]/ && b !~ /[=*#_~-][=*#_~-][=*#_~-][ \t]*$/) return 0
    c = b
    gsub(/[^A-Za-z0-9]/, "", c)
    return (length(c) <= 24)
  }
  function is_code(b) {
    if (b ~ /^[})\];]+[ \t]*;?[ \t]*$/) return 1
    if (b ~ /;[ \t]*$/ && b ~ /[=(]/) return 1
    if (b ~ /^(if|for|while|switch|foreach)[ \t]*\(/) return 1
    if (b ~ /^(return|const|let|var|def|class|function|import|export|public|private|protected|echo|print|new|await|async)[ \t]/ && b ~ /[=({:]/) return 1
    if (b ~ /^[A-Za-z_$][A-Za-z0-9_$.]*\(.*\)[ \t]*;?[ \t]*$/) return 1
    if (b ~ /^[$@]?[A-Za-z_][A-Za-z0-9_]*[ \t]*=[^=]/) return 1
    return 0
  }
  # Inside /** */ a line is code only with a token prose does not use, and not as a period-ended sentence of 3+ lowercase words (missed).
  function doc_code(b,   x, n, w, k, p) {
    if (b !~ /;|[$][A-Za-z_]|->|[A-Za-z_][A-Za-z0-9_]*[(]|(^|[^=!<>])=($|[^=>])|^(if|for|while|switch|foreach)[ \t]*[(]|^(import|export|return)[ \t].*[{]|[{[][ \t\r]*$/) return 0
    x = b; sub(/[ \t\r]+$/, "", x)
    if (x !~ /([A-Za-z0-9)]|[]])[.]$/) return 1
    n = split(x, w, /[ \t]+/); p = 0
    for (k = 1; k <= n; k++) { gsub(/^([(]|[[])+|([]]|[),.;:])+$/, "", w[k]); if (w[k] ~ /^[a-z][a-z]+$/) p++ }
    return p < 3
  }
  # Narration describes the edit, not the code; phrase cues, so warn-only. A ticket, issue or URL rescues the comment.
  function is_narration(b,   x) {
    if (b ~ /#[0-9]/ || b ~ /[A-Z][A-Z0-9]+-[0-9]/ || b ~ /https?:\/\//) return 0
    x = tolower(b)
    if (x ~ /^now that /) return 0
    if (x ~ /^(updated|new|changed):/) return 1
    if (x ~ /^(now|it now|this now|we now) /) return 1
    if (x ~ /(^| )now (correctly|properly) /) return 1
    if (x ~ /^(this|the) (fix|change|update|patch|refactor) (is|was|also|now|makes|ensures|addresses|fixes|resolves|prevents|handles|corrects|improves|adds|removes) /) return 1
    if (x ~ /^fix(ed)?(:| for )/) return 1
    if (x ~ /^(added|removed|renamed|moved|corrected|bugfix|hotfix)[ :]/) return 1
    if (x ~ /^fixes /) return 1
    if (x ~ /^no longer /) return 1
    if (x ~ /as requested|per (the )?review|review feedback|as discussed|addresses (the )?(review|comment|feedback)/) return 1
    if (x ~ /^(updated|changed|switched|migrated|converted|refactored|rewrote|reworked) (to|from|this|the) /) return 1
    if (x ~ /^previously,/) return 1
    if (x ~ /used to (be|return|use)/) return 1
    return 0
  }
  # -1: an owner in the leading marker is the keep-case form, so the rest of the line is not judged.
  function is_bare_todo(b) {
    if (b ~ /^(TODO|FIXME|XXX|HACK|todo|fixme)\([^()]*[A-Za-z][^()]*\)/) return -1
    if (b !~ /TODO|FIXME|XXX|HACK/ && b !~ /^(todo|fixme)([: ]|$)/) return 0
    if (b ~ /#[0-9]/) return -1
    if (b ~ /[A-Z][A-Z0-9]+-[0-9]/) return -1
    if (b ~ /https?:\/\//) return -1
    return 1
  }
  function is_marker(b, l) { return (l ~ /^[ \t]*\/\/([ \t]*#)?region([ \t]|$)/ || b ~ /^MARK:|^[Ss]tep[ \t]+[0-9]+:/) }
  # A stamp names a person: `Deprecated 2024-01-01` and `Since 2024-01-01` name an event.
  function is_stamp(b,   n, w, k) {
    if (tolower(b) ~ ("^modified by [^ \t].*" DATE)) return 1
    if (b !~ ("^[A-Za-z][A-Za-z.-]*([ \t]+[A-Za-z][A-Za-z.-]*)?,?[ \t]+" DATE "[ \t]*$")) return 0
    n = split(tolower(b), w, /[ \t,]+/)
    for (k = 1; k <= n; k++) { sub(/[.-]+$/, "", w[k]); if (w[k] ~ /^[a-z]/ && w[k] !~ DATECUE) return 1 }
    return 0
  }
  function mbody(s,   c, k) {
    sub(/^[ \t]+/, "", s)
    if (MH && substr(s, 1, 4) == "<!--") c = "-->"
    else if (lang == "blade" && substr(s, 1, 4) == "{{--") c = "--}}"
    else if (MJ && substr(s, 1, 3) == "{/*") c = "*/"
    else return ""
    s = substr(s, (c == "*/") ? 4 : 5)
    if (!(k = index(s, c))) return ""
    s = substr(s, 1, k - 1); sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
    return s
  }
  # Counts non-doc bodies an ellipsis opens or closes holding only a listed placeholder phrase and filler; EO counts ellipsis-only bodies, EL is the first line.
  function elision_n(   i, b, x, u, w, re, k, n, f, e) {
    n = EO = f = e = 0; EL = ""
    for (i = 1; i <= T; i++) {
      if (EX[i] || STR[i] || DOC[i] || DL[i]) continue
      b = (B[i] != "") ? B[i] : ((i in MK) ? MK[i] : "")
      if (b == "") continue
      x = tolower(b)
      while ((k = index(x, "…"))) x = substr(x, 1, k - 1) "..." substr(x, k + length("…"))
      u = x; sub(/[ \t\r]+$/, "", u)
      while (u ~ /^([(].*[)]|[[].*[]]|[{].*[}])$/) { u = substr(u, 2, length(u) - 2); sub(/^[ \t]+/, "", u); sub(/[ \t]+$/, "", u) }
      if (u ~ /^\.\.\.([^a-z0-9_$]|$)/) re = ELIDE
      else if (u ~ /\.\.\.$/) re = ELIDN
      else continue
      w = u; gsub(/\.\.\.+|[(]|[)]|[[]|[]]|[,;:]/, " ", w); gsub(/[ \t]+/, " ", w); sub(/^ /, "", w); sub(/[ .!]+$/, "", w)
      gsub(/[ \t]+/, " ", x)
      if (w ~ re) { if (!n++) f = i }
      else if (x ~ /^[ .\r]*$/) { if (!EO++) e = i }
    }
    if ((k = f ? f : e)) { EL = L[k]; sub(/^[ \t]+/, "", EL); sub(/[ \t\r]+$/, "", EL); EL = substr(EL, 1, 120) }
    return n
  }
  # STR: the line starts inside a multi-line string or heredoc; SS: what is open at line end. A wrong guess hides or exposes lines to the next delimiter.
  function str_line(l,   n, ch, i, c, t, d, top) {
    top = substr(SS, length(SS)); STR[T] = (SS != "" && top !~ /[*{]/)
    if (lang == "py") { if (SS == "" ? index(l, "\"\"\"") || index(l, "\047\047\047") : index(l, SS)) SS = py_scan(l, SS); return }
    if (substr(SS, 1, 2) == "<<") {
      t = l; if (substr(SS, 3, 1) == "-") { sub(/^\t+/, "", t); t = "-" t }
      if (t == substr(SS, 3)) SS = ""
      return
    }
    if (TL || TQ) {
      if (SS == "") { if (!index(l, "/*") && !(TL ? index(l, "`") : index(l, "\"\"\"") || index(l, "\047\047\047"))) return }
      else if (top == "*") { if (!index(l, "*/")) return }
      else if (top == "`") { if (!index(l, "`") && !index(l, "${")) return }
      else if (top != "{" && !index(l, SS)) return
      n = split(l, ch, "")
      for (i = 1; i <= n; i++) {
        c = ch[i]; top = substr(SS, length(SS))
        if (top == "*") { if (c == "*" && ch[i + 1] == "/") { SS = substr(SS, 1, length(SS) - 1); i++ } }
        else if (top == "`") {
          if (c == "\\" && lang != "go") i++
          else if (c == "`") SS = substr(SS, 1, length(SS) - 1)
          else if (c == "$" && ch[i + 1] == "{" && lang != "go") { SS = SS "{"; i++ }
        }
        else if (TQ && SS != "") { if (c == top && ch[i + 1] == c && ch[i + 2] == c) { SS = ""; i += 2 } }
        else if (c == "/" && ch[i + 1] == "/") return
        else if (c == "/" && ch[i + 1] == "*") { SS = SS "*"; i++ }
        else if (TL && c == "`") SS = SS "`"
        else if (TQ && (c == "\"" || c == "\047") && ch[i + 1] == c && ch[i + 2] == c) { SS = c c c; i += 2 }
        else if (c == "\"" || c == "\047") for (i++; i <= n && ch[i] != c; i++) { if (ch[i] == "\\") i++ }
        else if (top == "{" && c == "{") SS = SS "{"
        else if (top == "{" && c == "}") SS = substr(SS, 1, length(SS) - 1)
      }
      return
    }
    if (!SHQ || (SS == "" ? !index(l, "\047") && !index(l, "\"") && !index(l, "<<") : !index(l, substr(SS, length(SS))))) return
    n = split(l, ch, ""); t = ""
    for (i = 1; i <= n; i++) {
      c = ch[i]
      if (SS == "\047") { if (c == "\047") SS = "" }
      else if (SS != "") { if (c == "\\") i++; else if (c == substr(SS, length(SS))) SS = "" }
      else if (c == "\\") i++
      else if (c == "#" && (i == 1 || ch[i - 1] ~ /[ \t;&|(]/)) break
      else if (c == "\047") SS = (i > 1 && ch[i - 1] == "$") ? "$\047" : "\047"
      else if (c == "\"") SS = "\""
      else if (c == "<" && ch[i + 1] == "<" && ch[i + 2] == "<") i += 2
      else if (c == "<" && ch[i + 1] == "<" && t == "" && match(substr(l, i), /^<<-?[ \t]*[\\"\047]?[A-Za-z_][A-Za-z0-9_]*[\\"\047]?/)) {
        t = substr(l, i + 2, RLENGTH - 2); d = (substr(t, 1, 1) == "-"); gsub(/[-\\"\047 \t]/, "", t); t = (d ? "-" : "") t
        i += RLENGTH - 1
      }
    }
    if (t != "" && SS == "") SS = "<<" t
  }
  # Block grammar, conditional comments and template directives are read by a machine, not a person.
  function is_markup(b) {
    if (exempt(b) || b ~ /^\/?wp:|^\[if |<!\[endif\]|^#include|svelte-ignore|^\/?ko([ \t]|$)|@vite/) return 0
    return (b ~ /^<\/?[A-Za-z]/ || is_code(b))
  }
  function is_dead_tag(b, li,   t, n, arr, i, name, desc, seen, d, ty, tl, dead) {
    if (b ~ /^@returns?[ \t]+void[ \t.]*$/) return 1
    if (b ~ /^@returns?[ \t]*$/) return !cont(li, "")
    if (b ~ /^:param[ \t]/) { t = b; sub(/^:param[ \t]+/, "", t); sub(/:/, " ", t) }
    else if (b ~ /^@param[ \t]/) { t = b; sub(/^@param[ \t]+/, "", t) }
    else return 0
    n = split(t, arr, /[ \t]+/)
    name = ""; ty = 0; tl = (arr[1] ~ /[<{|?-]|\[/ || index(arr[1], "\\") > 0)
    for (i = 1; i <= n && i <= 2; i++) if (arr[i] ~ /^\$/) { name = substr(arr[i], 2); ty = (i == 2); break }
    if (name == "" && n >= 2 && arr[1] ~ /^[A-Za-z_|\\{<]/ && arr[2] ~ /^[A-Za-z_]/) {
      # Two plain words are a name and its one-word description: `@param value Value.`.
      if (n == 2 && !tl) name = arr[1]
      else { name = arr[2]; ty = 1 }
    }
    if (name == "" && n == 1) name = arr[1]
    if (name == "") return 0
    # A type the signature may not state (list<User>, non-empty-string, a class) is a fact, so the tag is not dead.
    if (ty && (arr[2] ~ /^\$/ || tl) && arr[1] !~ /^(int|float|string|bool|array|object|mixed|void|null|callable|iterable|self|static|number|boolean|any|unknown|never)$/) return 0
    seen = 0; desc = ""
    for (i = 1; i <= n; i++) {
      if (!seen && (arr[i] == name || arr[i] == ("$" name))) { seen = 1; continue }
      if (seen) desc = desc " " arr[i]
    }
    if (!seen) return 0
    d = tolower(desc)
    gsub(/[.,:]/, "", d)
    gsub(/^[ \t]+|[ \t]+$/, "", d)
    sub(/^(the|a|an)[ \t]+/, "", d)
    # A JDK tag wraps its description onto the next block line.
    if (d == "") dead = !cont(li, "")
    else { gsub(/[ \t]/, "", d); dead = (d == tolower(name)) }
    # A typed tag is the only place the type is stated unless the signature below types the parameter too.
    return dead && (!ty || typed(NC[li], name))
  }
  # Every content word must be recoverable from the code line: all of them, not a ratio, keeps this credible.
  function restates(b, j,   n, arr, i, w, ct, sing) {
    if (j != CJ) { split("", CS); code_tokens(L[j], CS); op_tokens(L[j], CS); CJ = j }
    n = split(b, arr, /[^A-Za-z0-9_]+/)
    ct = 0
    for (i = 1; i <= n; i++) {
      w = tolower(arr[i])
      if (w == "" || length(w) < 2) continue
      if (w in SW) continue
      ct++
      if (w in CS) continue
      sing = (length(w) > 3 && substr(w, length(w)) == "s") ? substr(w, 1, length(w) - 1) : ""
      if (sing != "" && (sing in CS)) continue
      return 0
    }
    return (ct > 0)
  }
  function covered(d, set,   n, arr, i, w, ct, sing) {
    n = split(d, arr, /[^A-Za-z0-9_]+/)
    ct = 0
    for (i = 1; i <= n; i++) {
      w = tolower(arr[i])
      if (w == "" || length(w) < 2 || (w in SW)) continue
      ct++
      sing = (length(w) > 3 && substr(w, length(w)) == "s") ? substr(w, 1, length(w) - 1) : ""
      if (!(w in set) && !(sing != "" && (sing in set))) return 0
    }
    return (ct > 0)
  }
  function padded(d, set) {
    sub(/^[ \t]*[-:][ \t]*/, "", d)
    if (d ~ /[0-9]/ || tolower(d) ~ FACT) return 0
    return covered(d, set)
  }
  function cont(i, kind) {
    if (kind != "") return ((i + 1) in DX) && DX[i + 1] && DI[i + 1] > DI[i]
    return OPEN[i] && B[i + 1] != "" && B[i + 1] != "/" && B[i + 1] !~ /^@/
  }
  # Every @return and typed tag above one long line asks for its signature, so each line is parsed once.
  function sig_of(c) {
    if (!(c in SV)) { SV[c] = sig_parse(c); SF[c] = FN; SR[c] = RT; SP[c] = PA }
    FN = SF[c]; RT = SR[c]; PA = SP[c]
    return SV[c]
  }
  # A signature whose parentheses are still open reads on: at most 50 lines and 4,000 bytes, and never into a comment, so each line is read for one signature.
  function sig_parse(c,   l, pre, s, i, ch, d, e) {
    FN = RT = PA = ""; l = L[c]
    if (!match(l, /[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) return 0
    FN = substr(l, RSTART, RLENGTH); sub(/[ \t]*\($/, "", FN)
    if (FN ~ /^(if|for|foreach|while|switch|catch|return|new|function|fn|func|fun|def|array|list|isset)$/) { FN = ""; return 0 }
    pre = substr(l, 1, RSTART - 1); s = substr(l, RSTART + RLENGTH); d = 1; i = 1; e = 0
    while (1) {
      for (; i <= length(s) && d > 0; i++) { ch = substr(s, i, 1); if (ch == "(") d++; else if (ch == ")") d-- }
      if (d <= 0 || e >= 50 || c + e >= T || length(s) > 4000 || B[c + e + 1] != "" || INB[c + e + 1]) break
      e++; s = s " " L[c + e]
    }
    if (d > 0) { PA = s; return 1 }
    PA = substr(s, 1, i - 2); s = substr(s, i)
    if (match(s, /^[ \t]*(:|->)[ \t]*\??[A-Za-z_\\][A-Za-z0-9_\\]*/)) { RT = substr(s, RSTART, RLENGTH); sub(/^[ \t]*(:|->)[ \t]*/, "", RT) }
    else if (match(pre, /[A-Za-z_][A-Za-z0-9_<>]*[ \t]+$/)) { RT = substr(pre, RSTART, RLENGTH); sub(/[ \t]+$/, "", RT) }
    if (RT ~ /^(public|private|protected|static|final|abstract|async|function|fn|func|fun|def|override|virtual|internal|open|export|default|synchronized|const|inline|suspend)$/) RT = ""
    return 1
  }
  # Typed: a type word stands before the parameter name, or a `:` type follows it.
  function typed(c, nm) {
    if (c > T || nm !~ /^[A-Za-z_][A-Za-z0-9_]*$/ || !sig_of(c)) return 0
    if (!(c in TM)) type_map(c)
    return ((c, nm) in TY) && TY[c, nm]
  }
  # Each tag above a signature asks about it, so it is read once, left to right; q: a word before the name is a type (a letter, not a bare modifier).
  function type_map(c,   n, a, k, x, len, i, s, j, nm, pre, q) {
    TM[c] = 1; n = split(PA, a, ",")
    for (k = 1; k <= n; k++) {
      x = a[k]; sub(/=.*$/, "", x); x = " " x " "; len = length(x); q = 0
      for (i = 2; i <= len; i++) {
        if (substr(x, i, 1) !~ /[A-Za-z0-9_]/) continue
        for (s = i; substr(x, i, 1) ~ /[A-Za-z0-9_]/; i++) ;
        nm = substr(x, s, i - s); pre = substr(x, s - 1, 1)
        if (nm ~ /^[A-Za-z_]/ && !((c, nm) in TY) && (pre != "$" || substr(x, s - 2, 1) !~ /[A-Za-z0-9_$]/)) {
          for (j = i; substr(x, j, 1) ~ /[ \t]/; j++) ;
          if (substr(x, j, 1) == "?") for (j++; substr(x, j, 1) ~ /[ \t]/; j++) ;
          TY[c, nm] = (q || substr(x, j, 1) == ":")
        }
        if (nm ~ /[A-Za-z_]/ && !(nm ~ /^(public|private|protected|readonly|final|var|val|const|mut|ref|out|in|params|this)$/ && pre ~ /[ \t.&*]/ && substr(x, i, 1) ~ /[ \t.&*]/)) q = 1
      }
    }
  }
  function pyparam(p, set) {
    sub(/^[ \t*]+/, "", p)
    if (match(p, /^[A-Za-z_][A-Za-z0-9_]*/)) { p = substr(p, 1, RLENGTH); add_tok(set, p); split_ident(p, set) }
  }
  function sig_tokens(h, set,   s, i, c, d, cur) {
    if (!match(h, /(def|class)[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) return
    s = substr(h, RSTART, RLENGTH)
    if (s ~ /^class/) { sub(/^class[ \t]+/, "", s); add_tok(set, s); split_ident(s, set); return }
    sub(/^def[ \t]+/, "", s); add_tok(set, s); split_ident(s, set)
    s = substr(h, RSTART + RLENGTH); d = 0; cur = ""
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (c == "(" || c == "[" || c == "{") { if (++d == 1) continue }
      else if (c == ")" || c == "]" || c == "}") { if (d == 1) pyparam(cur, set); if (--d <= 0) break; continue }
      else if (d == 1 && c == ",") { pyparam(cur, set); cur = ""; continue }
      if (d == 1) cur = cur c
    }
  }
  # An operator in the summary (`self + other`, a grammar rule) says what the name cannot.
  function sig_echo(i) { if (DB[i] ~ /[-+*%<>=&|^~;"]/ || index(DB[i], "/")) return 0; split("", PS); sig_tokens(DEFS[DG[i]], PS); return padded(DB[i], PS) }
  # Warn-only: a tag is padding when its name and native type (for @return and @var, the declaration) give back its words.
  function pads(b, i, kind,   x, w, n, k, j, nm, ty, c, s) {
    if (JSF || cont(i, kind)) return 0
    split("", PS); nm = ty = ""
    if (b ~ /^@returns?([ \t]|$)/) {
      c = NC[i]
      if (c > T || !sig_of(c)) return 0
      x = b; sub(/^@returns?[ \t]*/, "", x)
      if (x ~ /^\{/) return 0
      if (PHPF) { ty = x; sub(/[ \t].*$/, "", ty); x = substr(x, length(ty) + 1); if (tolower(ty) != tolower(RT)) return 0 }
      add_tok(PS, FN); split_ident(FN, PS); add_tok(PS, RT); split_ident(RT, PS)
      return padded(x, PS)
    }
    if (b ~ /^@var[ \t]/) {
      c = NC[i]
      for (j = i + 1; j < c; j++) if (L[j] ~ /^[ \t]*$/) return 0
      if (c > T || !match(L[c], /^[ \t]*((public|protected|private|readonly|static|var)[ \t]+)+\??[A-Za-z_\\][A-Za-z0-9_\\]*[ \t]+\$[A-Za-z_][A-Za-z0-9_]*/)) return 0
      s = substr(L[c], RSTART, RLENGTH); nm = s; sub(/^.*\$/, "", nm); sub(/[ \t]+\$[A-Za-z0-9_]*$/, "", s); sub(/^.*[ \t]/, "", s)
      x = b; sub(/^@var[ \t]+/, "", x); ty = x; sub(/[ \t].*$/, "", ty); x = substr(x, length(ty) + 1)
      if (index(x, "$") || tolower(ty) != tolower(s)) return 0
      add_tok(PS, nm); split_ident(nm, PS); add_tok(PS, ty)
      return padded(x, PS)
    }
    if (kind == "a") {
      match(b, /^[A-Za-z_][A-Za-z0-9_]*/); nm = substr(b, 1, RLENGTH); x = substr(b, RLENGTH + 1)
      if (match(x, /^[ \t]*\([^)]*\)/)) { ty = substr(x, 1, RLENGTH); x = substr(x, RLENGTH + 1); gsub(/^[ \t]*\(|\)$/, "", ty) }
      x = substr(x, 2)
    } else if (b ~ /^:param[ \t]/) {
      x = b; sub(/^:param[ \t]+/, "", x)
      if (!(k = index(x, ":"))) return 0
      n = split(substr(x, 1, k - 1), w, /[ \t]+/); x = substr(x, k + 1)
      if (n == 2) ty = w[1]; else if (n != 1) return 0
      nm = w[n]
    } else if (b ~ /^@param[ \t]/) {
      x = b; sub(/^@param[ \t]+/, "", x)
      n = split(x, w, /[ \t]+/); k = 1
      for (j = 1; j <= n; j++) if (index(w[j], "$")) { k = j; break }
      nm = w[k]; sub(/^\$/, "", nm)
      for (j = 1; j < k; j++) ty = ty (j > 1 ? " " : "") w[j]
      x = ""; for (j = k + 1; j <= n; j++) x = x " " w[j]
      if (ty != "" && !typed(NC[i], nm)) return 0
    } else return 0
    if (nm !~ /^[A-Za-z_][A-Za-z0-9_]*$/ || ty != "" && ty !~ NATIVE) return 0
    add_tok(PS, nm); split_ident(nm, PS); if (ty != "") add_tok(PS, ty)
    return padded(x, PS)
  }
  # py_scan and the header rule in py_line copy cd_classify in hooks/paths.sh: its awk is not reachable from here.
  function py_scan(t, open_quote,   i, n, c, inner) {
    comment_at = 0; n = length(t)
    for (i = 1; i <= n; i++) {
      c = substr(t, i, 1)
      if (open_quote != "") { if (substr(t, i, 3) == open_quote) { open_quote = ""; i += 2 } }
      else if (c == "#") { comment_at = i; break }
      else if (c == "\"" || c == "\047") {
        if (substr(t, i, 3) == c c c) { open_quote = c c c; i += 2 }
        else for (i++; i <= n && (inner = substr(t, i, 1)) != c; i++) if (inner == "\\") i++
      }
    }
    return open_quote
  }
  # Only the docstring that is the first statement after a def or class header is read.
  function py_line(t,   x, at, q, k, ind, colon) {
    x = t; sub(/^[ \t]+/, "", x); ind = length(t) - length(x); sub(/[ \t\r]+$/, "", x)
    if (pq != "") {
      if ((k = index(x, pq))) { x = substr(x, 1, k - 1); sub(/[ \t]+$/, "", x); pq = "" }
      DX[T] = (x != ""); DI[T] = ind
      if (pend) { if (x == "") DS[pend] = "s"; pend = 0 }
      if (x ~ /^(Args|Arguments):$/) { pargs = ind; pent = -1 }
      else {
        if (pargs >= 0 && (x == "" || ind <= pargs)) pargs = -1
        if (pargs >= 0 && (pent < 0 || ind == pent) && x ~ /^[A-Za-z_][A-Za-z0-9_]*([ \t]*\([^)]*\))?:([ \t]|$)/) { DS[T] = "a"; DB[T] = x; pent = ind }
        else if (x ~ /^:param[ \t]/) { DS[T] = "p"; DB[T] = x }
      }
      if (pq == "") pargs = -1
      return
    }
    if (x == "") return
    if (ps != "") { if (index(x, ps)) ps = py_scan(x, ps); return }
    if (x ~ /^#/) return
    if (!pyh && pya && x ~ /^[rRuU]?("""|\047\047\047)/) {
      at = (x ~ /^[rRuU]/) ? 2 : 1; q = substr(x, at, 3); x = substr(x, at + 3); pya = 0
      if ((k = index(x, q))) x = substr(x, 1, k - 1); else pq = q
      sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x)
      if (x != "") { DB[T] = x; DG[T] = nd; if (k) DS[T] = "s"; else pend = T }
      return
    }
    pya = 0
    if (index(x, "\"\"\"") || index(x, "\047\047\047")) ps = py_scan(x, "")
    if (ps != "") { pyh = 0; return }
    if (!pyh && x ~ /^(async[ \t]+def|def|class)[ \t]/) { pyh = 1; pyd = 0; hdr = "" }
    if (!pyh) return
    if (index(x, "#")) { py_scan(x, ""); if (comment_at) x = substr(x, 1, comment_at - 1) }
    sub(/[ \t]+$/, "", x); hdr = hdr " " x; colon = (substr(x, length(x)) == ":")
    pyd += gsub(/\(/, "", x) + gsub(/\[/, "", x) + gsub(/\{/, "", x) - gsub(/\)/, "", x) - gsub(/\]/, "", x) - gsub(/\}/, "", x)
    if (pyd <= 0) { pyh = 0; pya = colon; if (colon) DEFS[++nd] = hdr }
  }
  BEGIN {
    split("the a an to to of for and or is are was were be being been this that these those it its we you i they he she then now here there in on on at by with from as into each all any some if so do does did not no our your their and but when while where which who what how new old up down out off over under again very can will would should could may might must has have had", swl, " ")
    for (i in swl) SW[swl[i]] = 1
    split("restating the next line|section banner|commented-out code|bare TODO|docblock tag repeating the signature|change-narration (describes the edit, not the code)|docblock tag padding (restates its name or type)|docstring restating the signature|commented-out markup|comment paragraph (one line is the budget)|section marker|authorship stamp (git blame holds this)", CATS, "|")
    DATECUE = "^(since|until|till|before|after|from|through|between|starting|deprecated|expires?|expired|expiry|expiration|valid|effective|released?|added|removed|updated|created|modified|changed|fixed|last|due|deadline|sunset|eol|ends?|starts?|date|dated|today|version|revision|rev|build|built|introduced|scheduled|planned|retired|available|published|generated|tested|verified|checked|reviewed|accessed|retrieved|snapshot|cutoff|as|of|on|at|in|to|the)$"
    # JSDoc types are the only types a .js file has, so its tags are never padding.
    JSF = (lang ~ /^(js|mjs|cjs|jsx)$/); PHPF = (lang == "php" || lang == "blade"); pargs = -1
    MH = (lang ~ /^(vue|svelte|blade|php)$/); MJ = (lang ~ /^(jsx|tsx)$/)
    TL = (lang ~ /^(js|jsx|ts|tsx|mjs|cjs|vue|svelte|go)$/); SHQ = (lang ~ /^(sh|bash|zsh)$/)
    TQ = (lang ~ /^(kt|kts|java|swift|scala|groovy|dart|cs)$/)
    ELIDN = "existing (code|implementation|jsx|markup|template|html)" \
      "|rest of (the )?(code|file|class|function|method|component|implementation|template|markup|jsx|html)" \
      "|remaining (code|methods|functions|fields|cases)|(code|implementation|logic) unchanged|unchanged (code|implementation|logic)" \
      "|other (methods|functions|code|fields)"
    ELIDF = "( (unchanged|(remains?|stays?) ((the )?same|unchanged)|as (before|above|is)|goes here|here|omitted|elided|kept|for brevity|intact|(if|as) needed))*$"
    ELIDE = "^(the )?(" ELIDN "|same as (above|before)|omitted|previous (code|implementation)|keep (the )?existing( (code|implementation|logic))?)" ELIDF
    ELIDN = "^(" ELIDN ")" ELIDF
    DATE = "[0-9][0-9][0-9][0-9][-/][0-9][0-9]?[-/][0-9][0-9]?"
    NATIVE = "^(int|integer|string|str|bool|boolean|float|double|array|object|mixed|void|null|self|static|callable|iterable|never|true|false|number|any|unknown|bytes|list|dict|tuple|set)$"
    FACT = "(^|[^a-z])(null|none|nil|no|not|only|unless|until|when|if|must|may|default|defaults|optional|otherwise|fallback|throws?|thrown|raises?|exceptions?|errors?|example|e\\.g|i\\.e|ms|milliseconds?|seconds?|secs?|minutes?|hours?|days?|bytes?|kb|mb|gb|percent|pixels?|px|utc|caller|owns|owned|ownership|borrowed|lifetime|ttl|expires?|range|min|max|minimum|maximum|between|least|most|positive|negative|inclusive|exclusive|empty|this|new|old|same|fresh|copy)([^a-z]|$)"
    # A leader the language lacks is code there: `// count)` in Python, `# Usage` in a template literal.
    lead = "sbhd"; split("sb sbh b bd d h", FL, " ")
    nr = split("js jsx ts tsx mjs cjs vue svelte blade go rs java kt kts swift scala dart groovy c h cpp hpp cc cs m mm scss less|php tf|css|sql|lua|py rb sh bash zsh pl r jl ex exs graphql dockerfile make", ROW, "|")
    for (r = 1; r <= nr; r++) { nk = split(ROW[r], KEY, " "); for (k = 1; k <= nk; k++) if (KEY[k] == lang) lead = FL[r] }
    LS = index(lead, "s"); LB = index(lead, "b"); LH = index(lead, "h"); LD = index(lead, "d")
  }
  $0 == "\037" { blk = fence = exm = pyh = pya = pend = 0; pq = ps = SS = ""; pargs = -1; next }
  {
    wb = blk; L[++T] = $0; B[T] = b = cbody($0); OB[T] = (b != "" ? b : obody($0)); DOC[T] = indoc; OPEN[T] = blk; INB[T] = (wb || opened) && !cl
    if (only ~ /^elision/) { str_line($0); if (dl) DL[T] = 1 }
    if ((MH || MJ) && b == "" && (mk = mbody($0)) != "") MK[T] = mk
    t = $0; sub(/^[ \t]+/, "", t); sub(/\r$/, "", t); PK[T] = (LS && !dl && t ~ /^\/\//) || (LH && t ~ /^#([ \t#]|$)/)
    if (lang == "py") py_line($0)
    # Example code in a doc comment is not commented-out code.
    if (opened) fence = exm = 0
    if (indoc || dl) {
      if (b ~ /^```/) { fence = !fence; EX[T] = 1 }
      else if (fence) EX[T] = 1
      else if (indoc && b ~ /^@/) EX[T] = exm = (b ~ /^@example/)
      else if (indoc && exm) EX[T] = 1
      if (dl && lang == "rs") EX[T] = 1
    } else fence = exm = 0
  }
  END {
    if (only == "elision") { k = elision_n(); printf "%d %d %s\n", k, EO, EL; exit }
    if (only == "elision-lines") {
      for (j = 0; j < 64 && (elision_n() || EO); j++) {
        print EL
        for (i = 1; i <= T; i++) { t = L[i]; sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t); if (substr(t, 1, 120) == EL) EX[i] = 1 }
      }
      exit
    }
    # One backward pass: a forward re-scan per comment is quadratic in a run of comments.
    nx = nc = T + 1
    for (i = T; i >= 1; i--) {
      N[i] = nx; NC[i] = nc
      if (L[i] ~ /^[ \t]*$/) continue
      if (OB[i] == "") nx = i
      if (B[i] == "" && !INB[i]) nc = i
    }
    for (i = 1; i <= T; i++) {
      if (i in DS) {
        if (DS[i] == "s") { if (sig_echo(i)) { H[8]++; total++ } }
        else if (pads(DB[i], i, DS[i])) { H[7]++; total++ }
        continue
      }
      if ((i in MK) && is_markup(MK[i])) { H[9]++; total++; continue }
      b = B[i]
      if (b == "" || exempt(b)) continue
      if (is_banner(b))       { H[2]++; total++; continue }
      if ((td = is_bare_todo(b)) < 0) continue
      if (!EX[i] && is_code(b) && (!DOC[i] || doc_code(b))) { H[3]++; total++; continue }
      if (td > 0)             { H[4]++; total++; continue }
      if (is_dead_tag(b, i))  { H[5]++; total++; continue }
      if (is_narration(b))    { H[6]++; total++; continue }
      # A docblock tag names what the signature names; is_dead_tag and pads judge it.
      if (!EX[i] && !(DOC[i] && b ~ /^@/) && N[i] <= T && restates(b, N[i])) { H[1]++; total++; continue }
      if (is_marker(b, L[i])) { H[11]++; total++; continue }
      if (is_stamp(b))        { H[12]++; total++; continue }
      if (DOC[i] && pads(b, i, "")) { H[7]++; total++ }
    }
    # A licence, a Go doc comment and RDoc above a Ruby definition are documentation, not a paragraph.
    for (i = 1; i <= T + 1; i++) {
      if (i <= T && PK[i]) {
        b = B[i]; sub(/\r$/, "", b)
        if (tolower(b) ~ /copyright|spdx-|licen[sc]e|all rights reserved/) lic = 1
        if (b ~ /[A-Za-z0-9]/ && b !~ /^@/ && tolower(b) !~ /^shortcut:/ && !exempt(b) && (EX[i] || !is_code(b))) pc++
        continue
      }
      if (pc >= 3 && !lic && !(lang == "go" && L[i] ~ /[^ \t\r]/) && !(lang == "rb" && L[i] ~ /^[ \t]*((def|class|module)[ \t]|attr_)/)) { H[10]++; total++ }
      pc = lic = 0
    }
    if (total == 0) exit 0
    # Line 1 is machine-read by the shell: the count of BLOCKABLE findings (restatement, commented-out code, dead docblock tag).
    printf "%d\n", (1 in H ? H[1] : 0) + (3 in H ? H[3] : 0) + (5 in H ? H[5] : 0)
    parts = ""
    for (k = 1; k <= 12; k++) {
      if (!(k in H)) continue
      parts = parts (parts == "" ? "" : ", ") H[k] " " CATS[k]
    }
    printf "comment-discipline: %d added %s (%s) — check the routing table in the comment-discipline skill for where those facts belong.\n", total, (total == 1 ? "comment looks like noise" : "comments look like noise"), parts
  }'; }

  scan_verdict() {
  [ -n "$raw" ] || return 1
  blockable=$(printf '%s\n' "$raw" | head -1)
  warn=$(printf '%s\n' "$raw" | tail -n +2)
  [ -n "$warn" ] || return 1
  case "$blockable" in ''|*[!0-9]*) blockable=0 ;; esac

  if [ "$event" != "PreToolUse" ]; then
    # The switch is named here, not in $warn: the deny reuses that text, and CC_REMIND does not silence a deny.
    msg="$warn CC_REMIND=off silences these."; return 0
  fi

  # PreToolUse lane: deny, not ask (the model wrote it), at most twice per file; every input the bound needs is checked first, and one missing withholds the deny.
  [ "$blockable" -gt 0 ] || return 1

  # Generated output declares itself in its own header; its banners are deliberate.
  printf '%s\n' "$added" | awk '$0 != "\037"' | cd_generated && return 1

  # Keyed on the context (transcript_path first), not the session: a subagent shares its parent's session_id.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || return 1                   # cannot bound the deny → do not block
  # -d too: a gone cwd is nowhere to record the bound. State sits at the state root, shared with density.sh and verbosity.sh; re-rooting one alone splits the bound.
  [ -n "$cwd" ] && [ -d "$cwd" ] || return 1  # no cwd, or a cwd that is gone → nowhere to record the bound
  [ -n "$root" ] || return 1
  key=$(printf '%s' "$fp" | (command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
  [ -n "$key" ] || return 1
  # Hashed: .transcript_path is an absolute path, and raw it names a file whose parents never exist, so every deny is withheld.
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || return 1
  dir=$(cc_plugin_state "$root" comment-discipline)
  marker="$dir/blocked-$ctx-$key"
  # Two tries, not one: a sibling hook's deny (protect-tests, secret-scanning, command-guard) can block the write a try was spent on.
  DENY_CAP=2
  # A noclobber file per try (O_CREAT|O_EXCL): a counter races, and uutils mkdir(1) is not exclusive. -e: an old .dN dir or zero-byte marker counts as a try.
  tries=0
  [ -e "$marker" ] && tries=1
  i=1
  while [ "$i" -le "$DENY_CAP" ]; do [ -e "$marker.d$i" ] && tries=$i; i=$((i + 1)); done
  [ "$tries" -ge "$DENY_CAP" ] && return 1
  mkdir -p "$dir" 2>/dev/null || return 1
  # The state dir ignores itself, or each marker shows up untracked.
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  ( set -C; : > "$marker.d$((tries + 1))" ) 2>/dev/null || return 1 # lost the race → a sibling instance denied
  # Residual: a deny does not prove the write landed, so two co-firing siblings can spend both tries on writes that never happened.
  reason=$(printf '%s Write the edit again without them: a comment restating the next line, a line of commented-out code, or a docblock tag that only repeats the signature has no fact to carry — delete it or move the fact to a name, a type, or a test. The default is no comment; a docblock earns a line only for what the signature cannot state. Blocked at most twice per file; after that an edit goes through with a warning instead. CC_COMMENT_GUARD=off disables this block for the session (CC_REMIND=off silences the warning it falls back to).' "$warn")
  msg=$reason; return 0
  }

  # elision_state <file_path> [probe] sets edir and ekey; status 1 with no context, cwd or hashable path, or, given probe, no elision-warn- marker here.
  elision_state() {
    local sid root key ctx w
    sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
    [ -n "$sid" ] && [ -n "$cwd" ] && [ -d "$cwd" ] || return 1
    root=$(cc_state_root "$cwd") || return 1
    ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
    [ -n "$ctx" ] || return 1
    edir=$(cc_plugin_state "$root" comment-discipline)
    if [ -n "${2:-}" ]; then
      for w in "$edir/elision-warn-$ctx-"*; do break; done
      [ -e "$w" ] || return 1
    fi
    key=$(printf '%s' "$1" | (command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
    [ -n "$key" ] || return 1
    ekey="$ctx-$key"
  }

  # elision_fresh <replaced-text file> reads placeholder lines on stdin and prints the first that file holds no line of.
  elision_fresh() {
    awk 'NR == FNR { sub(/^[ \t]+/, ""); sub(/[ \t\r]+$/, ""); K[substr($0, 1, 120)] = 1; next } !($0 in K) { print; exit }' "$1" -
  }

  # elision_lost <replaced-text file> reads the new text on stdin; status 0 when a non-blank line of that file is not in it.
  elision_lost() {
    awk 'NR == FNR { sub(/^[ \t]+/, ""); sub(/[ \t\r]+$/, ""); K[$0] = 1; next }
      { sub(/^[ \t]+/, ""); sub(/[ \t\r]+$/, "") } $0 != "" && !($0 in K) { f = 1; exit } END { exit !f }' - "$1"
  }

  # elision_judge <file_path> <new text>: msg, status 0, when the text adds placeholders over what it replaces (an Edit: its old_strings and the whole file) and drops a line of it.
  # Ignores cd_path_exempt; two tries on elision-blocked- markers. A let-through placeholder leaves the elision-warn- marker elision_warn reads, unless CC_REMIND is off.
  ELISION_MAX=1048576
  elision_judge() {
    local new old oldtxt n o e eo line l size marker tries i cap=2 txt="$2" whole=0 agree=1 eol=keep
    [ "$event" = PreToolUse ] && [ -n "$1" ] || return 1
    [ "$elide" != off ] || [ "$remind" != off ] || return 1
    cd_governed "$1" || return 1
    case "$2" in *...*|*…*) ;; *) return 1 ;; esac
    printf '%s\n' "$2" | awk '$0 != "\037"' | cd_generated && return 1
    cd_lang "$1"
    # An Edit is also judged on the whole file after it (a new_string may start inside a string); CRLF reads as LF unless an old_string holds \r.
    if { [ "$tool" = Edit ] || [ "$tool" = MultiEdit ]; } && [ -f "$1" ] && size=$(wc -c < "$1") && [ $((size)) -le "$ELISION_MAX" ] \
       && txt=$(printf '%s' "$input" | jq -r --rawfile f "$1" '(.tool_input.edits // [.tool_input]) as $es
            | any($es[]; (.old_string // "") | contains("\r")) as $cr | (if $cr then "keep" else "lf" end) + "\n"
            + reduce ($es[] | select((.old_string // "") != "")) as $e (if $cr then $f else $f | split("\r\n") | join("\n") end;
              split($e.old_string) as $p
            | if ($p | length) < 2 then error("absent") elif $e.replace_all == true then $p | join($e.new_string // "")
              else $p[0] + ($e.new_string // "") + ($p[1:] | join($e.old_string)) end)' 2>/dev/null); then
      whole=1; eol=${txt%%$'\n'*}; txt=${txt#*$'\n'}
    else
      txt=$2
    fi
    new=$(printf '%s\n' "$txt" | scan_awk elision); n=${new%% *}; e=${new#* }; e=${e%% *}
    case "$n$e" in ''|*[!0-9]*) return 1 ;; esac
    [ "$n" -gt 0 ] || [ "$e" -gt 0 ] || return 1
    if [ "$tool" = Edit ] || [ "$tool" = MultiEdit ]; then
      oldtxt=$(printf '%s' "$input" | jq -r '[ .tool_input.old_string // empty,
        ( .tool_input.edits // [] | map(.old_string // empty) | join("\n\u001f\n") ) ] | join("\n")' 2>/dev/null) || return 1
    fi
    if [ "$whole" = 1 ]; then
      if [ "$eol" = lf ]; then old=$(awk '{ sub(/\r$/, "") } 1' "$1" | scan_awk elision); else old=$(scan_awk elision < "$1"); fi
    elif [ "$tool" = Edit ] || [ "$tool" = MultiEdit ]; then
      old=$(printf '%s\n' "$oldtxt" | scan_awk elision)
    elif [ -f "$1" ]; then
      size=$(wc -c < "$1") && [ $((size)) -le "$ELISION_MAX" ] || return 1
      old=$(scan_awk elision < "$1")
    else
      old="0 0"
    fi
    o=${old%% *}; eo=${old#* }; eo=${eo%% *}
    case "$o$eo" in ''|*[!0-9]*) return 1 ;; esac
    [ "$n" -gt "$o" ] || [ "$e" -gt "$eo" ] || return 1
    line=${new#* }; line=${line#* }
    if [ "$o" -gt 0 ] || [ "$eo" -gt 0 ] || [ "$whole" = 1 ]; then
      if [ "$whole" = 0 ] && { [ "$tool" = Edit ] || [ "$tool" = MultiEdit ]; }; then
        l=$(printf '%s\n' "$2" | scan_awk elision-lines | elision_fresh <(printf '%s\n' "$oldtxt"))
      else
        l=$(printf '%s\n' "$txt" | scan_awk elision-lines | elision_fresh "$1")
      fi
      [ -n "$l" ] && line=$l
    fi
    # Each comparison alone has refused a benign Edit (a misread string), so an Edit is denied only when both add one.
    if [ "$whole" = 1 ] && [ "$n" -gt "$o" ]; then
      agree=0
      [ -n "$l" ] && new=$(printf '%s\n' "$2" | scan_awk elision) && old=$(printf '%s\n' "$oldtxt" | scan_awk elision) \
        && [ "${new%% *}" -gt "${old%% *}" ] && agree=1
    fi
    [ "$agree" = 1 ] || return 1
    # A pure addition loses no code.
    if [ -f "$1" ] && grep -q '[^[:space:]]' "$1"; then
      if [ "$tool" = Edit ] || [ "$tool" = MultiEdit ]; then
        printf '%s\n' "$2" | elision_lost <(printf '%s\n' "$oldtxt") || return 1
      else
        printf '%s\n' "$2" | elision_lost "$1" || return 1
      fi
    fi
    elision_state "$1" || return 1
    marker="$edir/elision-blocked-$ekey"
    tries=0; i=1
    while [ "$i" -le "$cap" ]; do [ -e "$marker.d$i" ] && tries=$i; i=$((i + 1)); done
    mkdir -p "$edir" 2>/dev/null || return 1
    [ -e "$edir/.gitignore" ] || printf '*\n' > "$edir/.gitignore" 2>/dev/null
    # The noclobber claim of the comment deny above, for the same reason: mkdir(1) is not exclusive on uutils.
    if [ "$elide" != off ] && [ "$n" -gt "$o" ] && [ -f "$1" ] && grep -q '[^[:space:]]' "$1" && [ "$tries" -lt "$cap" ] \
       && ( set -C; : > "$marker.d$((tries + 1))" ) 2>/dev/null; then
      msg="elision-guard: this write would replace existing code with the placeholder comment \"$line\". Re-read the file and write it whole, or use Edit for a partial change. Blocked at most twice per file. CC_ELISION_GUARD=off disables this block for the session."
      return 0
    fi
    [ "$remind" = off ] || { printf '%s\n' "$line" > "$edir/elision-warn-$ekey" && wrote+=("$edir/elision-warn-$ekey"); } 2>/dev/null
    return 1
  }

  # elision_warn <file_path> <new text> consumes the file's elision-warn- marker into ew, dropping one whose line the text no longer holds.
  elision_warn() {
    local w line
    elision_state "$1" probe || return 1
    w="$edir/elision-warn-$ekey"
    [ -f "$w" ] || return 1
    IFS= read -r line < "$w"; rm -f "$w"
    [ -n "$line" ] || return 1
    case "$2" in *"$line"*) ;; *) return 1 ;; esac
    ew="${ew:+$ew }elision-guard: $(basename "$1") now holds the placeholder comment \"$line\" where code belongs. Restore the omitted code in its place."
  }

  # jq builds the envelope so any comment text stays valid JSON. A deny also removes this call's elision-warn- markers: no PostToolUse follows it.
  emit() {
    if [ "$event" = "PreToolUse" ]; then
      [ "${#wrote[@]}" -gt 0 ] && rm -f "${wrote[@]}"
      jq -cn --arg r "$msg$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    else
      jq -cn --arg ctx "${ew:+$ew }$msg$1" --arg ev "$hev" \
        '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$ctx}}'
    fi
  }

  if [ "$tool" = Bash ]; then
    chunks=""; [ -z "$tgts" ] || chunks=$(cc_bash_write_chunks "$cmd")
    [ -n "$chunks" ] || [ -n "$effects" ] || exit 0
    n=0; k=0
    while IFS= read -r l; do
      k=$((k + 1)); tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
      if [ -n "$tgt" ] && cd_governed "$tgt"; then n=$((n + 1)); ctgt[$n]=$tgt; chdr[$n]=${l#?}; cnum[$n]=$k; fi
    done <<EOF_C
$(printf '%s\n' "$chunks" | awk 'substr($0, 1, 1) == "\036"')
EOF_C
    [ "$n" -gt 0 ] || [ -n "$effects" ] || exit 0
    hascd=0; [ -n "$tgts" ] && cd_has_cd "$cmd" && hascd=1
    c=1
    while [ "$event" = PreToolUse ] && [ "$c" -le "$n" ]; do
      if [ "$(cd_chunk_mode "${chdr[$c]}")" = truncate ] && cd_target_whole "${chdr[$c]}" "${ctgt[$c]}" \
         && fp=$(cd_bash_target "${ctgt[$c]}" "$cwd" "$hascd") \
         && elision_judge "$fp" "$(cd_chunk_text "$chunks" "${cnum[$c]}")"; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
      c=$((c + 1))
    done
    ew=""; c=1
    while [ "$event" != PreToolUse ] && [ "$c" -le "$n" ]; do
      fp=$(cd_bash_target "${ctgt[$c]}" "$cwd" "$hascd") && elision_warn "$fp" "$(cd_chunk_text "$chunks" "${cnum[$c]}")"
      c=$((c + 1))
    done
    [ "$cguard" = off ] && exit 0
    c=1   # not `i`: scan_judge counts its deny markers with that name
    while [ "$c" -le "$n" ]; do
      if cd_chunk_mode "${chdr[$c]}" >/dev/null && cd_target_whole "${chdr[$c]}" "${ctgt[$c]}" \
         && fp=$(cd_bash_target "${ctgt[$c]}" "$cwd" "$hascd") \
         && scan_judge "$fp" "$(cd_chunk_text "$chunks" "${cnum[$c]}")"; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
      c=$((c + 1))
    done
    # A governed file the run changed that no target names: judged on the lines it added (cd_effect_added).
    while IFS= read -r fp; do
      [ -n "$fp" ] || continue
      if scan_judge "$fp" "$(cd_effect_added "$root" "$fp")"; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
    done <<EOF_E
$(cd_effect_files "$effects" "$tgts" "$cwd" "$hascd")
EOF_E
    [ -n "$ew" ] && { msg="CC_REMIND=off silences this."; emit ""; }
  else
    fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
    # A \037 line between edits: a /* left open in one edit must not reach the next.
    added=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content    // empty,
        .tool_input.new_string // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n\u001f\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    elision_judge "$fp" "$added" && { emit ""; exit 0; }
    ew=""; [ "$event" != PreToolUse ] && elision_warn "$fp" "$added"
    [ "$cguard" = off ] && exit 0
    if scan_judge "$fp" "$added"; then emit ""
    elif [ -n "$ew" ]; then msg="CC_REMIND=off silences this."; emit ""; fi
  fi
} 2>/dev/null
exit 0
