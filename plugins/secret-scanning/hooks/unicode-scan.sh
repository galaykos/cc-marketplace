#!/bin/bash
# unicode-scan.sh (PostToolUse on file writes and reads, Bash included, and PostToolUseFailure on Bash; payload on stdin) — warns once per project,
#   file and day (again the same day only when the file's invisible characters change), never blocks,
#   naming line and codepoint, when a file the call wrote or read holds a zero-width, bidi, soft-hyphen, mid-file BOM or Unicode tag character
#   (a lone BOM leading a `*.log` line, or a tab-separated field of one, is a CI step's encoding and skipped);
#   after a python, node, php, ruby, perl, deno, bun, cp, mv, install or patch run, also each file git reports changed since this hook's previous call.
# Off: CC_UNICODE_SCAN=off or CC_REMIND=off. Fails open on every error path; its one-shot markers live in $TMPDIR, its one bash-effects marker in
#   the plugin's data dir (CLAUDE_PLUGIN_DATA), else <root>/.claude/secret-scanning/ behind a `*` .gitignore.
# CC_UNICODE_SCAN / CC_REMIND unset: the /config options cc_unicode_scan / cc_remind decide.
# Misses: homoglyphs; intent (presence only); a file over 2 MB or not valid UTF-8; hits past the sixth in a file; a file the session never touched;
#   a second session or subagent the same day on a file holding the same characters (the one-shot is per project and day, not per session);
#   a character stored as a JSON backslash-u escape (a .ipynb or .json the session only read); an MCP apply_patch (no single path); on Bash, a
#   target past the eighth, outside the project root, not an existing regular file or relative after an in-command cd, and cc_bash_write_targets' misses;
#   after an interpreter run, changed files past the eighth (MAX_BASH_EFFECTS) and the bash-write-effects block's misses. Reads too much: a file
#   anything else changed since this hook's previous call (an IDE, a parallel agent) is read as that run's write.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/hooks/unicode-scan.sh

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
# under <root> reports changed or untracked, outside any .claude/ dir and newer than <marker>. It runs git only when <command> holds
# python, node, php, ruby, perl (any version suffix or directory), nodejs, deno, bun, cp, mv, install or patch as a word, <marker>
# holds <session>'s cksum (another session's marker reads as none), <root> is not $HOME and status.showUntrackedFiles is not no.
# Misses: writers it does not name, gitignored files, submodules, no git, each session's first call, a file written then reverted, a
# mv or cp -p destination (it keeps the source's mtime), files past <max>. Reads too much: any change since <marker> — an IDE, a
# parallel agent, a job.
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
    --untracked-files=all --no-renames --ignore-submodules=all | tr '\0' '\n' | sed -e '/^...\.claude\//d' -e '/\/\.claude\//d' -e 's|^...|./|' \
    | tr '\n' '\0' | xargs -0 sh -c 'exec find "$@" -prune -newer "$0" -type f -print' "$2" | head -n "$4")
  return 0
}

# Shared block templates/blocks/heredoc-bodies.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/heredoc-bodies.md
# cc_strip_heredoc_bodies <mode> <command> [<reader ERE>] prints the command without the heredoc bodies the scan can place,
# their terminators dropped with them. Mode all drops every such body. Mode inert keeps a body a reader may run: its opener's line
# names a shell (rbash, mksh too), ssh, su, sudo -i/-s, runuser, chroot, exec, xargs, eval, source or `.`, or matches <reader ERE>
# (tested lowercased, unquoted, space-padded), or the reader can sit off that line: a `\` continuation, a trailing | ( { do then
# else, an unquoted $( ) ( ) <( ) but x=$( ), an fd number, a $ or quoted command word, a done/fi/esac/}/) lead. Once it drops a
# body, inert keeps every line if a later line pipes into a reader (other words may sit before it; `.`, source, eval or a $ command
# word first), or runs eval, a shell's -c or a $ command word after an x=$( ) or "$( )" body. Mode cd is inert with eval, source,
# `.` and the ERE the only named readers, for a cd test: a body this shell runs is kept, one a named subshell runs is not. Every
# mode keeps every line after a `<<` the scan cannot place (quoted, after a #, in arithmetic, ${ } or $[ ], an odd delimiter, a
# quote or ${ open across its line, a backtick, $$', an unmatched ), a terminator with stray blanks) and a body with no terminator.
# Misses: inert drops a body fed to anything else (python3 -, node, at, a function, alias or coproc), written to a script a later
# line runs, or read into a variable by read; a case pattern's ) inside $( ) closes it early.
cc_strip_heredoc_bodies() {
  printf '%s\n' "$2" | heredoc_readers="${3:-}" LC_ALL=C awk -v how="$1" '
    BEGIN {
      rd = ENVIRON["heredoc_readers"]; sw = "((ba|z|da|k|c|tc|a|rba|mk|ok|ya)?sh|fish)"; hr = "[ /](eval|source|\\.) "
      sh = "[ /](" sw "|ssh|su|runuser|chroot|exec|xargs) |[ /](sudo|doas) ([^;&|()]* )?(-[a-z]*[is][a-z]*|--login|--shell) "
      shc = "[ /]" sw "( -[-a-z]+)* -[a-z]*c "
    }
    function reads(w) { return rd != "" && w ~ rd || w ~ hr || how != "cd" && w ~ sh }
    function norm(s) { s = tolower(s); gsub(/\\[^a-z0-9_]/, "", s); gsub(/["\047\\]/, "", s); gsub(/[<>|;&()]/, " & ", s); gsub(/[ \t]+/, " ", s); return " " s " " }
    function delim(s, j,   c, q, w) {
      q = ""; w = ""
      for (; j <= length(s); j++) {
        c = substr(s, j, 1)
        if (q != "") { if (c == q) q = ""; else w = w c; continue }
        if (c ~ /[ \t;&|<>()]/) break
        if (c == "\\") { j++; w = w substr(s, j, 1) } else if (c == "\047" || c == "\"") q = c; else w = w c
      }
      return q == "" ? w : ""
    }
    # One physical line; quote and $( ) state (st: p plain, v after =, q in "", a/b arithmetic, e ${, s $[) carry across lines. 1 = ends in \.
    function scan(s,   n, i, c, nx, d, t, w, j) {
      n = length(s); cc = 0
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); nx = substr(s, i + 1, 1); d = dl; dl = 0
        if (sq) {
          if (c == "<" && nx == "<") { off = 1; return 0 }
          if (c == "\\" && ans) i++; else if (c == "\047") sq = 0
          continue
        }
        if (c == "\\") { if (i == n) { dl = d; return 1 }; i++; pc = "x"; cs = 0; continue }
        if (dq) {
          if (c == "\"") { dq = 0; pc = c }
          else if (c == "`" || c == "<" && nx == "<") { off = 1; return 0 }
          else if (c == "$" && nx == "(") {
            if (substr(s, i + 2, 1) == "(") { st = st "b"; i += 2 } else { st = st "q"; i++ }
            dq = 0; pc = "("; cs = 1
          }
          continue
        }
        if (cs && c !~ /[ \t]/) {
          if (c ~ /[$"`\047]/) cw = 1
          else if (c == ")" || match(substr(s, i, 6), /^(done|fi|esac|[}])([ \t;&|<>)]|$)/)) cl = 1
          else if (match(substr(s, i, 7), /^([{!]|then|do|else|elif|if|while|until)[ \t]/)) { i += RLENGTH - 1; pc = " "; continue }
          cs = 0
        }
        if (c == "\047") { if (d > 1) { off = 1; return 0 }; sq = 1; ans = (d == 1); pc = c; continue }
        if (c == "\"") { dq = 1; pc = c; continue }
        if (c == "`") { off = 1; return 0 }
        if (c == "#") {
          if (pc ~ /[ \t\n;&|()<>]/) { cc = i; if (index(substr(s, i), "<<") || substr(s, n, 1) == "\\") off = 1; return 0 }
          hash = 1
        }
        if (c == "$") {
          dl = d + 1
          if (nx == "(") {
            if (substr(s, i + 2, 1) == "(") { st = st "a"; i += 2 } else { st = st (pc == "=" ? "v" : "p"); i++ }
            pc = "("; cs = 1; continue
          }
          if (nx ~ /[{[]/) { st = st (nx == "{" ? "e" : "s"); i++; pc = nx; continue }
        }
        t = substr(st, length(st))
        if (c ~ /[]}[]/ && t == (c == "}" ? "e" : "s")) { if (c == "[") st = st t; else { st = substr(st, 1, length(st) - 1); pc = "x" }; continue }
        if (c == "(") { if (nx == "(") { st = st "a"; i++ } else st = st "p"; pc = c; cs = 1; continue }
        if (c == ")") {
          if (t ~ /^[es]?$/) { off = 1; return 0 }
          if (t ~ /[ab]/) { if (nx != ")") { off = 1; return 0 }; i++ }
          st = substr(st, 1, length(st) - 1); if (t ~ /[qb]/) dq = 1
          pc = "x"; continue
        }
        if (c == "<" && nx == "<") {
          if (substr(s, i + 2, 1) == "<") { i += 2; pc = "<"; continue }
          if (hash || st ~ /[abes]/) { off = 1; return 0 }
          if (st ~ /p/ || sd0 != "" || substr(s, i - 1, 1) ~ /[0-9]/) k2 = 1
          j = i + 2; t = (substr(s, j, 1) == "-"); j += t
          while (substr(s, j, 1) ~ /[ \t]/) j++
          w = delim(s, j)
          if (w !~ /^[A-Za-z0-9_.-]+$/) { off = 1; return 0 }
          term[++nc] = w; tdash[nc] = t
          i++; pc = "<"; continue
        }
        if (c ~ /[;&|]/) cs = 1
        pc = c
      }
      return 0
    }
    { all[++na] = $0 }
    mode == 2 { out[++no] = $0; next }
    mode == 1 {
      t = $0; if (tdash[qi]) sub(/^\t+/, "", t)
      if (t == term[qi]) { if (keep) out[++no] = $0; else held[++nh] = $0; if (++qi > nc) { mode = 0; if (!keep) cut = 1; nh = 0 }; next }
      t = $0; gsub(/^[ \t]+|[ \t]+$/, "", t)
      if (t == term[qi]) { for (k = 1; k <= nh; k++) out[++no] = held[k]; nh = 0; out[++no] = $0; mode = 2; next }
      if (keep) out[++no] = $0; else held[++nh] = $0
      next
    }
    {
      out[++no] = $0
      if (cont) cflag = 1
      else { sd0 = st; startq = sq || dq; nc = 0; hash = 0; cw = 0; cl = 0; k2 = 0; cflag = 0; pc = "\n"; cs = 1; lw = ""; dl = 0 }
      lw = lw " " $0
      cont = scan($0)
      if (off) { mode = 2; next }
      if (cont || !nc) next
      if (startq || sq || dq || st ~ /[es]/) { mode = 2; next }
      t = cc ? substr($0, 1, cc - 1) : $0; sub(/[ \t]+$/, "", t)
      keep = how != "all" && (k2 || cw || cl || cflag || st ~ /[pab]/ || t ~ /(\|&?|[({]|(^|[ \t;&|])(do|then|else|elif))$/ || reads(norm(lw)))
      if (!keep && !c0) c0 = no; if (!keep && st ~ /[vq]/) cv = 1
      qi = 1; mode = 1; nh = 0
      next
    }
    END {
      if (mode == 1 && !keep) for (k = 1; k <= nh; k++) out[++no] = held[k]
      for (k = c0; cut && how != "all" && k <= no; k++) {
        t = out[k]; if (t ~ /[|(]&?[ \t]*$/ && k < no) t = t " " out[k + 1]
        u = t = norm(t); r = cv && (t ~ / eval |(^|[;&|]) \$/ || how != "cd" && t ~ shc)
        while (!r && match(u, /\|/)) { u = substr(u, RSTART + 1); p = u; sub(/^( [&(])+ /, " ", p); sub(/[;&|()].*/, " ", p); r = rd != "" && p ~ rd || how != "cd" && p ~ sh || p ~ /^ (\$[a-z_{]|(\.|source|eval) )/ }
        if (r) { for (k = 1; k <= na; k++) print all[k]; exit }
      }
      for (k = 1; k <= no; k++) print out[k]
    }'
}

MARKER_TTL_MIN=1440
MAX_BASH_TARGETS=8
MAX_BASH_EFFECTS=8
{
  [ "$(cc_option CC_UNICODE_SCAN on)" = "off" ] && exit 0
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit|Read|Bash) ;;
    *apply_patch|*create_new_file|*read_file) ;;
    *) exit 0 ;;
  esac

  # Interpreter writes: read the effects with the old marker, then date it, on EVERY call this hook sees (a Read too), so a
  # file an Edit changed or a command that wrote nothing is never read as the next run's write. A failed Bash call fires
  # PostToolUseFailure, whose envelope must name that event.
  # context-key-ok: session_id is only the effects marker's content; the warning's one-shot is per project, file and day, not per context.
  { IFS= read -r cwd; IFS= read -r sess; IFS= read -r hev; } < <(printf '%s' "$input" \
    | jq -r '.cwd // "", .session_id // "", if .hook_event_name == "PostToolUseFailure" then .hook_event_name else "PostToolUse" end' 2>/dev/null)
  root=""; cmd=""; effects=""
  if [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(cc_state_root "$cwd"); then
    emark="$(cc_plugin_state "$root" secret-scanning)/bash-effects-unicode.mark"
    if [ "$tool" = Bash ]; then
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      effects=$(cc_bash_write_effects "$root" "$emark" "$cmd" "$MAX_BASH_EFFECTS" "$sess")
    fi
    cc_bash_effects_mark "$root" "$emark" "$sess"
  fi

  # report_file <path> — prints the file's warning, or nothing when it is clean, too big, unreadable or already reported.
  report_file() {
    local file=$1 bytes key mark report kind body base
    [ -f "$file" ] || return 0
    # tr -d: BSD wc pads its count, which the numeric test below would reject, disabling the hook.
    bytes=$(wc -c < "$file" 2>/dev/null | tr -d '[:space:]' || echo 0)
    case "$bytes" in ''|*[!0-9]*) return 0 ;; esac
    [ "$bytes" -gt 2000000 ] && return 0

    find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-unicode-*' -type d -mmin +"$MARKER_TTL_MIN" -exec rmdir {} + 2>/dev/null

    report=$(python3 - "$file" <<'PY' 2>/dev/null
import sys, unicodedata
NAMED = {
    0x200B: "ZERO WIDTH SPACE", 0x200C: "ZERO WIDTH NON-JOINER",
    0x200D: "ZERO WIDTH JOINER", 0x2060: "WORD JOINER",
    0xFEFF: "ZERO WIDTH NO-BREAK SPACE (BOM)", 0x00AD: "SOFT HYPHEN",
    0x202A: "LEFT-TO-RIGHT EMBEDDING", 0x202B: "RIGHT-TO-LEFT EMBEDDING",
    0x202C: "POP DIRECTIONAL FORMATTING", 0x202D: "LEFT-TO-RIGHT OVERRIDE",
    0x202E: "RIGHT-TO-LEFT OVERRIDE", 0x2066: "LEFT-TO-RIGHT ISOLATE",
    0x2067: "RIGHT-TO-LEFT ISOLATE", 0x2068: "FIRST STRONG ISOLATE",
    0x2069: "POP DIRECTIONAL ISOLATE",
}
BIDI = set(range(0x202A, 0x202F)) | set(range(0x2066, 0x206A))
try:
    with open(sys.argv[1], "r", encoding="utf-8") as fh:
        lines = fh.readlines()
except Exception:
    sys.exit(0)

def hidden(cp):
    return cp in NAMED or 0xE0000 <= cp <= 0xE007F

LOG = sys.argv[1].lower().endswith(".log")
hits = []
for lineno, line in enumerate(lines, 1):
    for col, ch in enumerate(line, 1):
        cp = ord(ch)
        if cp == 0xFEFF and lineno == 1 and col == 1:
            continue                      # a leading BOM is a file encoding, not a hider
        # A CI log carries a BOM where each step's output starts: at a line's start, or after `gh run view --log`'s job and step fields.
        if cp == 0xFEFF and LOG and (col == 1 or line[col - 2] == "\t") and not hidden(ord(line[col:col + 1] or "\n")):
            continue
        if hidden(cp):
            name = NAMED.get(cp) or unicodedata.name(ch, "UNICODE TAG CHARACTER")
            hits.append((lineno, col, cp, name, cp in BIDI))
        if len(hits) >= 6:
            break
    if len(hits) >= 6:
        break

if not hits:
    sys.exit(0)
bidi = any(h[4] for h in hits)
out = []
for lineno, col, cp, name, _ in hits:
    out.append(f"line {lineno}, col {col}: U+{cp:04X} {name}")
print(("BIDI\n" if bidi else "PLAIN\n") + "\n".join(out))
PY
    )
    [ -n "$report" ] || return 0
    kind=$(printf '%s' "$report" | head -1)
    body=$(printf '%s' "$report" | tail -n +2)
    # One warning per project, file and day while the file holds the same invisible characters (codepoints in order, positions
    # dropped): a per-session key let every subagent repeat it. Claimed only after a hit, so a clean touch keeps the file's one
    # warning; mkdir is atomic, so one of two racing hooks reports.
    key=$(printf '%s|%s|%s|%s' "$(date +%F)" "$root" "$file" "$(printf '%s\n' "$body" | sed 's/^line [0-9]*, col [0-9]*: //')" \
      | cksum 2>/dev/null | cut -d' ' -f1)
    mark="${TMPDIR:-/tmp}/cc-unicode-$key"
    mkdir "$mark" 2>/dev/null || return 0
    base=$(basename "$file")

    if [ "$kind" = "BIDI" ]; then
      printf '%s\n' "secret-scanning: \`$base\` contains BIDIRECTIONAL OVERRIDE characters. These reorder how source is DISPLAYED without changing how it executes, so what you and a reviewer read is not what the compiler runs — the Trojan Source class (CVE-2021-42574). Treat this file's visible content as unverified until the characters are removed or explained."
    else
      printf '%s\n' "secret-scanning: \`$base\` contains ZERO-WIDTH or invisible characters. They do not render and survive copy-paste; in text that reaches a model they can carry instructions a human reviewer cannot see. Legitimate in emoji sequences and in Arabic/Persian/Indic text — decide which this is."
    fi
    printf '%s\n' "$body"
  }

  if [ "$tool" = Bash ]; then
    [ -n "$cmd" ] && [ -n "$root" ] || exit 0
    targets=$(cc_bash_write_targets "$cmd" | head -n "$MAX_BASH_TARGETS")
    [ -n "$targets" ] || [ -n "$effects" ] || exit 0
    # A cd inside a heredoc body moves nothing, so bodies are dropped before the cd test.
    hascd=0
    [ -n "$targets" ] && cc_strip_heredoc_bodies cd "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*(cd|pushd)([[:space:];&|)]|$)' && hascd=1
    files=""
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      # A relative target resolves against the payload cwd, the shell's cwd when the command starts; after a cd it is skipped.
      case "$p" in /*) ;; *) [ "$hascd" = 0 ] || continue; p="$cwd/$p" ;; esac
      # Logical cd && pwd, not pwd -P: the prefix test must compare in cc_state_root's spelling.
      d=$(CDPATH= cd -- "$(dirname -- "$p")" 2>/dev/null && pwd) || continue
      p="$d/$(basename -- "$p")"
      case "$p" in "$root"/*) ;; *) continue ;; esac
      [ -f "$p" ] && files="$files$p
"
    done <<EOF_T
$targets
EOF_T
    # A file the run changed that no target names: absolute, under the root, read whole as a Write's file is.
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "
$files" in *"
$p
"*) continue ;; esac
      files="$files$p
"
    done <<EOF_E
$effects
EOF_E
  else
    files=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // .tool_input.notebook_path // empty' 2>/dev/null)
  fi
  [ -n "$files" ] || exit 0

  msg=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    r=$(report_file "$f")
    [ -n "$r" ] && msg="$msg$r
"
  done <<EOF_F
$files
EOF_F
  [ -n "$msg" ] || exit 0

  jq -cn --arg c "${msg}Silence with CC_UNICODE_SCAN=off. This warns once per file a day, again only when its invisible characters change, and never blocks." --arg ev "${hev:-PostToolUse}" \
    '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
