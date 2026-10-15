#!/bin/bash
# scan.sh (PreToolUse on Write, Edit, MultiEdit, NotebookEdit, MCP apply_patch/create_new_file and Bash; payload on stdin) — denies a write whose new text
#   (for apply_patch, the whole patch), Bash heredoc body or echo/printf argument landing in a file carries a high-confidence, non-placeholder secret,
#   and a Bash write of redact.ts's [REDACTED: marker unless CC_SECRET_REDACT is off (Write/Edit carrying it are redact.ts's to refuse).
#   PostToolUse on the same tools (hook_event_name), warning only: after a python, node, php, ruby, perl, deno, bun, cp, mv, install or patch run,
#   on the same patterns in what each file git reports changed since this lane's previous call added (the whole file when HEAD lacks it, else its
#   `+` lines against HEAD, so a line any uncommitted edit added is judged again). State: that lane's marker in the plugin's data dir
#   (CLAUDE_PLUGIN_DATA), else <root>/.claude/secret-scanning/ behind a `*` .gitignore.
# Off: CC_SECRET_SCAN=off. Fails open: a timeout, a missing jq or any error but a bad pattern file allows the write.
# Fails closed: a missing or malformed hooks/patterns.tsv, the pattern source, denies every write with text to scan (the PostToolUse lane stays silent).
# CC_SECRET_SCAN unset: the /config option cc_secret_scan decides.
# Misses: a URL password under 6 characters or led by `$` or `{`, a URL scheme not listed, a webhook URL other than Slack's; a real value holding a
#   placeholder word; an MCP write tool with other key names; on Bash, a command with no write target, interpreter writes and cp/mv before they
#   land, sed/perl -i text and what cc_bash_write_chunks misses; a command that outruns the hook timeout (no per-call cap). After the fact: changed
#   files past the eighth (MAX_BASH_EFFECTS), text past 1 MiB per file, the redaction marker, and the bash-write-effects block's misses; a file
#   anything else changed since the lane's previous call (an IDE, a parallel agent) is read as that run's write.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/hooks/scan.sh

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

# Shared block templates/blocks/bash-write-effects.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/bash-write-effects.md
# cc_bash_effects_mark <root> <marker> rewrites <marker> when <root> holds a .git, making its directory with a `*` .gitignore.
# Call it on EVERY tool call the hook sees (Write, Edit, Bash alike), after cc_bash_write_effects read <marker>: the tool has
# finished before PostToolUse runs, so <marker> then post-dates every write of the last call this hook saw.
# cc_bash_write_effects <root> <marker> <command> <max> prints at most <max> absolute paths, one per line: files `git status`
# under <root> reports changed or untracked AND newer than <marker>. It runs git only when <command> holds python, node, php,
# ruby, perl (any version suffix or directory), nodejs, deno, bun, cp, mv, install or patch as a word, and <marker> exists.
# Misses: writers it does not name, gitignored files, no git, a file written then reverted, a mv or cp -p destination (it
# keeps the source's mtime), files past <max>. Reads too much: any change since <marker> — an IDE, a parallel agent, a job.
cc_bash_effects_mark() {
  [ -e "$1/.git" ] || return 0
  local d="${2%/*}"
  [ -d "$d" ] || { mkdir -p "$d" && printf '*\n' > "$d/.gitignore"; } 2>/dev/null || return 0
  printf '%s\n' "$$" > "$2" 2>/dev/null
  return 0
}
cc_bash_write_effects() {
  local re='(^|[;&|(`[:space:]])([^[:space:];&|()`<>]*/)?((python|php|ruby|perl|node)[0-9.]*|nodejs|deno|bun|cp|mv|install|patch)[[:space:]<]'
  local e f n=0
  local -a c
  [ -f "$2" ] && [[ $3 =~ $re ]] || return 0
  while [ "$n" -lt "$4" ] && IFS= read -r -d '' e; do
    f="$1/${e:3}"
    [ -f "$f" ] && ! [ "$2" -nt "$f" ] || continue
    c[n]=$f; n=$((n + 1))
  done < <(GIT_OPTIONAL_LOCKS=0 git -C "$1" status --porcelain -z --untracked-files=all --no-renames --ignore-submodules=all 2>/dev/null)
  [ "$n" -gt 0 ] && find "${c[@]}" -prune -newer "$2" -print 2>/dev/null
  return 0
}

MAX_BASH_EFFECTS=8
MAX_EFFECT_BYTES=1048576
{
  input=$(cat)
  [ "$(cc_option CC_SECRET_SCAN on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  tool=""; event=""
  { IFS= read -r tool; IFS= read -r event; } < <(printf '%s' "$input" | jq -r '.tool_name // "", .hook_event_name // ""' 2>/dev/null)
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    # The matcher in hooks.json and this case must widen together.
    *apply_patch|*create_new_file) ;;
    Bash) ;;
    *) exit 0 ;;
  esac

  hit=""
  pat_file=""; pat_loaded=""; pat_bad=""; pat_kind=(); pat_label=(); pat_flags=(); pat_re=(); ph_i=""; ph_c=""
  # deny <reason> — prints the PreToolUse deny and ends the run.
  deny() {
    jq -cn --arg r "$1" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
    exit 0
  }
  # load_patterns — reads pat_file, the patterns.tsv beside this script, into pat_* (secret and assigned rows, in file
  # order) and the ph_i/ph_c placeholder alternations; returns 1 with pat_bad set when the file is missing or malformed.
  load_patterns() {
    local line rest kind label flags re tabs n=0 nsecret=0 tab=$'\t' cr=$'\r'
    # Matched after dropping `\\` pairs, so an escaped backslash before a digit is not read as a backreference.
    local dialect='\[\[(:|\.|=)|\[:[[:alpha:]]+:\]|(^|[^\\])\(\?|\\[1-9]'
    # GNU grep reads \d as d and JavaScript as a digit; \b \B \w \W differ on non-ASCII letters, \s \S on U+00A0 and U+FEFF.
    local escape='\\[^].[+*?(){}|^$/-]'
    # No placeholder word, and every character class an assigned value can carry.
    local probe='Kq7Zt9_Wm2-Rp4/Lx8+Vn3=Bc6'
    pat_file="$(dirname "$0")/patterns.tsv"
    [ -f "$pat_file" ] && [ -r "$pat_file" ] || { pat_bad="missing or unreadable"; return 1; }
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      case "$line" in *"$cr"*) pat_bad="line $n carries a carriage return"; return 1 ;; '' | '#'*) continue ;; esac
      tabs=${line//[!$tab]/}
      [ "${#tabs}" -eq 3 ] || { pat_bad="line $n has $((${#tabs} + 1)) fields, not 4"; return 1; }
      kind=${line%%"$tab"*}; rest=${line#*"$tab"}
      label=${rest%%"$tab"*}; rest=${rest#*"$tab"}
      flags=${rest%%"$tab"*}; re=${rest#*"$tab"}
      [ -n "$label" ] && [ -n "$re" ] || { pat_bad="line $n has an empty label or pattern"; return 1; }
      case "$re" in ' '* | *' ') pat_bad="line $n has a pattern that starts or ends with a space; write an edge space as [ ]"; return 1 ;; esac
      case "$flags" in - | i) ;; *) pat_bad="line $n has flags '$flags', not - or i"; return 1 ;; esac
      case "$kind" in secret | assigned | placeholder) ;; *) pat_bad="line $n has kind '$kind', not secret, assigned or placeholder"; return 1 ;; esac
      [[ ${re//\\\\/} =~ $dialect ]] && { pat_bad="line $n uses [[:, [[., [[=, a [:class:], (? or a backreference, which grep and JavaScript read differently"; return 1; }
      [[ ${re//\\\\/} =~ $escape ]] && { pat_bad="line $n escapes a character other than ] . [ + * ? ( ) { } | ^ \$ / -, which grep and JavaScript read differently"; return 1; }
      grep -qE -- "$re" <<<'' 2>/dev/null
      case $? in
        0) pat_bad="line $n has a pattern that matches the empty string"; return 1 ;;
        1) ;;
        *) pat_bad="line $n has a pattern grep -E cannot compile"; return 1 ;;
      esac
      if [ "$kind" = placeholder ] && LC_ALL=C grep -qiE -- "$re" <<<"$probe" 2>/dev/null; then
        pat_bad="line $n: a placeholder row matches a secret-shaped value"; return 1
      fi
      case "$kind" in
        placeholder) if [ "$flags" = i ]; then ph_i="$ph_i${ph_i:+|}($re)"; else ph_c="$ph_c${ph_c:+|}($re)"; fi ;;
        *) [ "$kind" = secret ] && nsecret=$((nsecret + 1))
           pat_kind+=("$kind"); pat_label+=("$label"); pat_flags+=("$flags"); pat_re+=("$re") ;;
      esac
    done < "$pat_file"
    [ "$nsecret" -gt 0 ] || { pat_bad="no secret row"; return 1; }
    return 0
  }
  # placeholder <matched-value> — 0 when the value announces itself as fake.
  # LC_ALL=C: under UTF-8, grep -i also folds U+017F and U+212A into s and k.
  placeholder() {
    local v="$1"
    [ -n "$ph_i" ] && printf '%s' "$v" | LC_ALL=C grep -qiE -- "$ph_i" && return 0
    [ -n "$ph_c" ] && printf '%s' "$v" | grep -qE -- "$ph_c" && return 0
    [ "$(printf '%s' "$v" | fold -w1 | sort -u | wc -l | tr -d ' ')" -le 1 ] && return 0
    return 1
  }
  # detect <kind> <label> <flags> <ERE> — sets hit to <label> when a match of <ERE> in $text is no placeholder; a no-op once hit is set.
  # grep needs `--`: the private-key pattern starts with dashes, which grep would read as options.
  detect() {
    local m v opts=-oE
    [ -z "$hit" ] || return 0
    [ "$3" = i ] && opts=-oiE
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      v=$m
      # The placeholder test reads the value after the operator, never the variable name.
      [ "$1" = assigned ] && v=$(printf '%s' "$m" | sed -E 's/^[^:=]*[:=]["'"'"' ]*//')
      placeholder "${v:-$m}" || { hit="$2"; return 0; }
    done <<EOF_M
$(printf '%s' "$text" | grep "$opts" -- "$4" 2>/dev/null)
EOF_M
  }
  # scan_for_secret <text> — the one scanner for both paths: resets hit, then sets it to the first label whose match is no placeholder.
  # The first non-empty text loads $pat_file; an unusable one ends the run with a deny.
  scan_for_secret() {
    local k
    text=$1; hit=""
    [ -n "$text" ] || return 0
    if [ -z "$pat_loaded" ]; then
      load_patterns || deny "secret-scanning: the pattern file $pat_file is unusable ($pat_bad), so this write cannot be checked for secrets and is blocked. Reinstall or update the plugin to restore it. CC_SECRET_SCAN=off disables this guard for the session."
      pat_loaded=1
    fi
    for k in "${!pat_re[@]}"; do
      detect "${pat_kind[$k]}" "${pat_label[$k]}" "${pat_flags[$k]}" "${pat_re[$k]}"
    done
  }

  # The PostToolUse lane: the write has landed, so it warns and never denies. It reads what an interpreter, cp, mv, install or
  # patch run changed (the bash-write-effects block), each file judged on what it added: the whole file when HEAD lacks it, else
  # its `+` lines against HEAD. The effects are read with the old marker, then the marker is dated, on EVERY call this lane sees.
  if [ "$event" = PostToolUse ]; then
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(cc_state_root "$cwd") || exit 0
    emark="$(cc_plugin_state "$root" secret-scanning)/bash-effects-scan.mark"
    effects=""
    if [ "$tool" = Bash ]; then
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      effects=$(cc_bash_write_effects "$root" "$emark" "$cmd" "$MAX_BASH_EFFECTS")
    fi
    cc_bash_effects_mark "$root" "$emark"
    [ -n "$effects" ] || exit 0
    # An unusable pattern file is the PreToolUse lane's to refuse; a lane that cannot deny stays silent.
    load_patterns || exit 0
    pat_loaded=1; found=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rel="${f#"$root"/}"
      if git -C "$root" cat-file -e "HEAD:$rel" 2>/dev/null; then
        added=$(GIT_OPTIONAL_LOCKS=0 git -C "$root" diff --no-color --no-ext-diff -U0 HEAD -- ":(literal)$rel" 2>/dev/null \
          | awk '/^@@/ { h = 1; next } h && /^\+/ { print substr($0, 2) }' | head -c "$MAX_EFFECT_BYTES")
      else
        added=$(head -c "$MAX_EFFECT_BYTES" "$f" 2>/dev/null)
      fi
      scan_for_secret "$added"
      [ -z "$hit" ] || found="$found
- $rel: $hit"
    done <<EOF_E
$effects
EOF_E
    [ -n "$found" ] || exit 0
    jq -cn --arg c "secret-scanning: a Bash command just wrote what looks like a secret through a write this guard cannot read before it lands (an interpreter, cp, mv, install or patch):$found
The value is on disk now. Move it to an environment variable or a secret store and take it out of the file before it is committed; if it is a deliberate fixture, make the value announce itself — end it in EXAMPLE, or use a placeholder word (example, placeholder, changeme, dummy, xxxx). CC_SECRET_SCAN=off disables this guard." \
      '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}' 2>/dev/null
    exit 0
  fi

  file=""
  if [ "$tool" = Bash ]; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$cmd" ] || exit 0
    # Cheap exit before any chunk is read: most Bash calls write no file.
    [ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0
    n=0; keep=0; sep=$(printf '\036')
    while IFS= read -r l; do
      case "$l" in
        "$sep"*)
          tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
          if [ -n "$tgt" ]; then n=$((n + 1)); ctgt[$n]=$tgt; ctext[$n]=""; keep=1; else keep=0; fi ;;
        *) [ "$keep" = 1 ] && ctext[$n]="${ctext[$n]}$l
" ;;
      esac
    done <<EOF_C
$(cc_bash_write_chunks "$cmd")
EOF_C
    # redact.ts masks a secret in tool output as [REDACTED:<label>] and refuses Write/Edit carrying it; through Bash, the
    # same write-back would replace the real value on disk. With redaction off no mask is ever shown, so the text is quoted.
    # off, 0 and false in any case, as redact.ts's switchOn reads the same variable.
    redact=$(cc_option CC_SECRET_REDACT on | tr '[:upper:]' '[:lower:]')
    if [ "$redact" != off ] && [ "$redact" != 0 ] && [ "$redact" != false ]; then
      i=1
      while [ "$i" -le "$n" ]; do
        case "${ctext[$i]}" in
          *'[REDACTED:'*) deny "secret-scanning: this command writes the redaction marker [REDACTED:…] to ${ctgt[$i]}. It may have come from a tool result secret-scanning redacted; if so, writing it would replace the real value on disk, so leave the value out of the write, or edit only the lines around it with the Edit tool. If the text quotes the marker on purpose, ask the user to set CC_SECRET_REDACT=off, which also stops redacting secrets in tool output." ;;
        esac
        i=$((i + 1))
      done
    fi
    i=1
    while [ "$i" -le "$n" ] && [ -z "$hit" ]; do
      scan_for_secret "${ctext[$i]}"; file=${ctgt[$i]}; i=$((i + 1))
    done
  else
    text=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        .tool_input.text // empty,
        .tool_input.input // empty,
        .tool_input.patch // empty,
        ( select(.tool_name == "NotebookEdit" and .tool_input.edit_mode != "delete") | .tool_input.new_source | strings ),
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // .tool_input.notebook_path // empty' 2>/dev/null)
    scan_for_secret "$text"
  fi
  [ -n "$hit" ] || exit 0

  reason="secret-scanning: this write appears to contain ${hit}. Blocked before it reaches disk. Move the value to an environment variable or a secret store and reference it by name; if this is a deliberate fixture, make the value announce itself — end it in EXAMPLE, or use a placeholder word (example, placeholder, changeme, dummy, xxxx) — and the guard lets it through."
  [ -n "$file" ] && reason="$reason (file: $file)"
  reason="$reason CC_SECRET_SCAN=off disables this guard for the session."
  deny "$reason"
} 2>/dev/null
exit 0
