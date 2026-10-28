#!/bin/bash
# PostToolUse on Write, Edit, MultiEdit and Bash (PostToolUseFailure on Bash): warns, never denies, once per context, file and finding, on a security sink in a written line, a Bash-written file, or what an interpreter, cp, mv, install or patch run added; scratch outside the project is skipped.
# Misses a sink split across lines or aliased, cross-file flows, authz, raw SQL outside whereRaw, a client secret without a public prefix, Bash targets or changed files past the eighth or 256 KiB; warns on a guard on the next line and on files anything else changed. Fail-open. Off: CC_SECURITY_SCAN=off or CC_REMIND=off; unset, /config decides.
# Why, limits, history: rationale/derivations/plugin-security.md § plugins/security/hooks/write-scan.sh

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

# Shared block templates/blocks/write-scope.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/write-scope.md
# cc_scope_init <state root> sets the roots a written path is judged against, each symlink-resolved: CLAUDE_PROJECT_DIR, which the
# shell's cd does not move, <state root> (cc_state_root of the payload cwd, empty for none) and $TMPDIR (default /tmp).
# cc_scope_skip <path>: status 0 for scratch, a target under neither root or under the temp dir while the root holding it is not;
# a path not created yet is judged by its nearest existing directory (cc_scope_dir prints it resolved). cc_scope_root <dir> sets
# cc_scope_r to the root holding a resolved dir, the state root first; status 1 when neither does.
# Misses: a sibling repo or worktree written by absolute path from outside both roots is skipped; with no cwd and no
# CLAUDE_PROJECT_DIR only the temp-dir rule holds.
cc_scope_init() {
  cc_scope_pd=""; [ -z "${CLAUDE_PROJECT_DIR:-}" ] || cc_scope_pd=$(CDPATH= cd -- "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P) || cc_scope_pd=""
  cc_scope_sr=""; [ -z "${1:-}" ] || cc_scope_sr=$(CDPATH= cd -- "$1" 2>/dev/null && pwd -P) || cc_scope_sr=""
  cc_scope_tmp=$(CDPATH= cd -- "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P) || cc_scope_tmp=""
  cc_scope_pd=${cc_scope_pd%/}; cc_scope_sr=${cc_scope_sr%/}; cc_scope_tmp=${cc_scope_tmp%/}
}
cc_scope_dir() {
  local d
  d=$(dirname -- "$1")
  while [ ! -d "$d" ]; do d=$(dirname -- "$d"); done
  CDPATH= cd -- "$d" 2>/dev/null && pwd -P
}
cc_scope_root() {
  local r
  cc_scope_r=""
  for r in "$cc_scope_sr" "$cc_scope_pd"; do
    [ -n "$r" ] || continue
    case "$1/" in "$r"/*) cc_scope_r=$r; return 0 ;; esac
  done
  return 1
}
cc_scope_skip() {
  local d
  d=$(cc_scope_dir "$1") || return 1
  if cc_scope_root "$d"; then
    [ -n "$cc_scope_tmp" ] || return 1
    case "$cc_scope_r/" in "$cc_scope_tmp"/*) return 1 ;; esac
  elif [ -n "$cc_scope_sr$cc_scope_pd" ]; then
    return 0
  fi
  [ -n "$cc_scope_tmp" ] || return 1
  case "$d/" in "$cc_scope_tmp"/*) return 0 ;; esac
  return 1
}

# Shared block templates/blocks/heredoc-bodies.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/heredoc-bodies.md
# cc_strip_heredoc_bodies <mode> <command> [<reader ERE>] prints the command without the heredoc bodies the scan can place,
# their terminators dropped with them. Mode all drops every such body. Mode inert keeps a body a reader may run: its opener's line
# names a shell (rbash, mksh too), ssh, su, sudo -i/-s, runuser, chroot, exec, xargs, eval, source or `.`, or matches <reader ERE>
# (tested lowercased, unquoted, space-padded), or the reader can sit off that line: a `\` continuation, a trailing | ( { do then
# else, an unquoted $( ) ( ) <( ) but x=$( ), an fd number, a $ or quoted command word, a done/fi/esac/}/) lead. Once it drops a
# body, inert keeps every line if a later line pipes into a reader (other words may sit before it, but a grep or rg lead is a filter
# whatever its pattern names; `.`, source, eval or a $ command word first), or runs eval, a shell's -c or a $ command word after an
# x=$( ) or x="$( )" body. Mode cd is inert with eval, source, `.` and the ERE the only named readers, for a cd test: a body this
# shell runs is kept, one a named subshell runs is not. Every mode keeps every line after a `<<` the scan cannot place (quoted,
# after a #, in arithmetic, ${ } or $[ ], an odd delimiter, a quote or ${ open across its line, a backtick, $$', an unmatched ),
# a terminator with stray blanks) and a body with no terminator.
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
    # One physical line; quote and $( ) state (st: p plain, v after =, q in "", w in ="", a/b arithmetic, e ${, s $[) carry across lines. 1 = ends in \.
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
            if (substr(s, i + 2, 1) == "(") { st = st "b"; i += 2 } else { st = st (dq > 1 ? "w" : "q"); i++ }
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
        if (c == "\"") { dq = 1 + (pc == "="); pc = c; continue }
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
          st = substr(st, 1, length(st) - 1); if (t ~ /[qbw]/) dq = 1 + (t == "w")
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
      if (!keep && !c0) c0 = no; if (!keep && st ~ /[vw]/) cv = 1
      qi = 1; mode = 1; nh = 0
      next
    }
    END {
      if (mode == 1 && !keep) for (k = 1; k <= nh; k++) out[++no] = held[k]
      for (k = c0; cut && how != "all" && k <= no; k++) {
        t = out[k]; if (t ~ /[|(]&?[ \t]*$/ && k < no) t = t " " out[k + 1]
        u = t = norm(t); r = cv && (t ~ / eval |(^|[;&|]) \$/ || how != "cd" && t ~ shc)
        while (!r && match(u, /\|/)) { u = substr(u, RSTART + 1); p = u; sub(/^( [&(])+ /, " ", p); sub(/[;&|()].*/, " ", p); r = p !~ /^ ([ef]?grep|rg) / && (rd != "" && p ~ rd || how != "cd" && p ~ sh || p ~ /^ (\$[a-z_{]|(\.|source|eval) )/) }
        if (r) { for (k = 1; k <= na; k++) print all[k]; exit }
      }
      for (k = 1; k <= no; k++) print out[k]
    }'
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

MARKER_TTL_MIN=1440
MAX_BASH_TARGETS=8
MAX_BASH_EFFECTS=8
{
  [ "$(cc_option CC_SECURITY_SCAN on)" = "off" ] && exit 0
  [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Write|Edit|MultiEdit|Bash) ;; *) exit 0 ;; esac

  # Read the effects with the old marker, then mark, on EVERY call, so an Edit's file or a no-write command is never read as the next run's write; a failed Bash call answers as PostToolUseFailure.
  { IFS= read -r cwd; IFS= read -r sess; IFS= read -r hev; } < <(printf '%s' "$input" \
    | jq -r '.cwd // "", .session_id // "", if .hook_event_name == "PostToolUseFailure" then .hook_event_name else "PostToolUse" end' 2>/dev/null)
  sroot=""; effects=""
  if [ -n "$cwd" ] && [ -d "$cwd" ] && sroot=$(cc_state_root "$cwd"); then
    emark="$(cc_plugin_state "$sroot" security)/bash-effects.mark"
    if [ "$tool" = Bash ]; then
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      effects=$(cc_bash_write_effects "$sroot" "$emark" "$cmd" "$MAX_BASH_EFFECTS" "$sess")
    fi
    cc_bash_effects_mark "$sroot" "$emark" "$sess"
  fi

  if [ "$tool" = Bash ]; then
    [ -n "$sroot" ] || exit 0
    targets=$(cc_bash_write_targets "$cmd" | head -n "$MAX_BASH_TARGETS")
    [ -n "$targets" ] || [ -n "$effects" ] || exit 0
    # A cd in a heredoc body moves the shell only where this shell runs the body (`. /dev/stdin <<EOF`).
    hascd=0
    [ -n "$targets" ] && cc_strip_heredoc_bodies cd "$cmd" | grep -qE '(^|[;&|(])[[:space:]]*(cd|pushd)[[:space:]]' && hascd=1
  else
    text=$(printf '%s' "$input" | jq -r '
      [ .tool_input.content // empty,
        .tool_input.new_string // empty,
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    [ -n "$text" ] || exit 0
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // "unknown"' 2>/dev/null)
  fi
  cc_scope_init "$sroot"
  # Context key, not session: a subagent shares its parent's session_id but has its own transcript.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // "nosession"' 2>/dev/null)
  skey=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$skey" ] || skey=nosession
  lockroot="${TMPDIR:-/tmp}/cc-security-scan"
  find "$lockroot" -mindepth 1 -maxdepth 1 -type d -mmin +"$MARKER_TTL_MIN" -exec rm -rf {} + 2>/dev/null

  hits=""
  JS='js|jsx|ts|tsx|mjs|cjs|mts|cts|vue|svelte'
  PY='py|pyi|ipynb'
  PHP='php'
  MARKUP='html|htm|php|vue|jsx|tsx|twig|erb|ejs|hbs'
  CODE='[a-z0-9]+'
  scan_text() {
    lfile=$(printf '%s' "$file" | tr '[:upper:]' '[:lower:]')
    case "$lfile" in *.md|*.mdx|*.txt|*.rst|*.json|*.yaml|*.yml|*.lock) isdoc=1 ;; *) isdoc=0 ;; esac
    detect() { # detect <slug> <ERE> <one-line advice> [ext-alternation] [exclude-ERE]
      if [ -n "${4:-}" ]; then
        printf '%s' "$lfile" | grep -qE "\.(${4})$" || return 0
        [ "$isdoc" = 1 ] && return 0
      fi
      if [ -n "${5:-}" ]; then
        printf '%s' "$text" | grep -E "$2" | grep -vE "$5" | grep -q . || return 0
      else
        printf '%s' "$text" | grep -qE "$2" || return 0
      fi
      lock="${lockroot}/${skey}/$(printf '%s%s' "$file" "$1" | cksum | tr ' ' '_')"
      mkdir -p "${lockroot}/${skey}" 2>/dev/null || return 0
      mkdir "$lock" 2>/dev/null || return 0   # already warned for this file+finding
      hits="${hits}[security] ${1}: ${3}
"
    }

    detect "mass-assignment-open" \
      '\$guarded[[:space:]]*=[[:space:]]*\[[[:space:]]*\]' \
      "empty \$guarded disables mass-assignment protection — list guarded fields or use \$fillable"
    detect "blade-unescaped" \
      '\{!![[:space:]]*\$' \
      "{!! \$var !!} skips Blade escaping — use {{ }} unless this exact value is sanitized HTML"
    detect "client-bundle-secret" \
      '(^|[^A-Z0-9_])(VITE|NEXT_PUBLIC|NUXT_PUBLIC|EXPO_PUBLIC|PUBLIC|REACT_APP|GATSBY|VUE_APP)_[A-Z0-9_]*(SECRET|TOKEN|PASSWORD|PRIVATE|API_?KEY)' \
      "a public env prefix (VITE_, NEXT_PUBLIC_ and the like) compiles the value into the client bundle — a server secret must not carry one"
    detect "raw-sql-interpolation" \
      'whereRaw\((["'"'"'][^"'"'"')]*\{\$|[^,)]*\.[[:space:]]*\$)' \
      "variable inside whereRaw SQL — use ? placeholders with the bindings array"
    detect "raw-html-sink" \
      'dangerouslySetInnerHTML|v-html[[:space:]]*=|\{@html[[:space:]]|set:html[[:space:]]*=|\.(innerHTML|outerHTML)[[:space:]]*=|\.insertAdjacentHTML[[:space:]]*\(|document\.write(ln)?[[:space:]]*\(' \
      "raw HTML sink — sanitize upstream or render as text; XSS if any user data reaches it"

    detect "code-eval" \
      '(^|[^[:alnum:]_.$>])eval[[:space:]]*\(|new[[:space:]]+Function[[:space:]]*\(' \
      "eval()/new Function() runs a string as code — parse data with JSON or a literal parser; if eval is truly needed, say why in a one-line comment at the call" \
      "$CODE"
    detect "shell-string-exec" \
      'child_process\.exec(Sync)?[[:space:]]*\(|(^|[^[:alnum:]_.])execSync[[:space:]]*\(|(^|[^[:alnum:]_.$>])(shell_exec|passthru|popen|proc_open)[[:space:]]*\(|(^|[^[:alnum:]_.$>])(exec|system)[[:space:]]*\([[:space:]]*["'"'"'$]|os\.system[[:space:]]*\(|subprocess\.[A-Za-z_]+\(.*shell[[:space:]]*=[[:space:]]*True' \
      "shell-string execution — pass an argument array (execFile/spawn, subprocess.run([...]), escapeshellarg) so metacharacters in input are data, not commands" \
      "$JS|$PY|$PHP"
    detect "unsafe-deserialization" \
      '(^|[^[:alnum:]_])(pickle|cPickle|cloudpickle|dill|marshal)\.(load|loads|Unpickler)[[:space:]]*\(|joblib\.load[[:space:]]*\(|read_pickle[[:space:]]*\(|shelve\.open[[:space:]]*\(|allow_pickle[[:space:]]*=[[:space:]]*True|(^|[^[:alnum:]_>$])unserialize[[:space:]]*\([[:space:]]*\$' \
      "deserializing untrusted bytes constructs arbitrary objects — use JSON or a schema-validated decoder; PHP unserialize() takes allowed_classes" \
      "$PY|$PHP"
    detect "unsafe-yaml-load" \
      'yaml\.(load|unsafe_load)[[:space:]]*\(' \
      "yaml.load() without SafeLoader executes !!python/object tags — use yaml.safe_load()" \
      "$PY" 'SafeLoader|safe_load'
    detect "torch-unsafe-load" \
      'torch\.load[[:space:]]*\(' \
      "torch.load() unpickles arbitrary objects unless weights_only=True" \
      "$PY" 'weights_only[[:space:]]*=[[:space:]]*True'
    detect "xml-external-entities" \
      '(ElementTree|[^[:alnum:]_]ET|minidom|xml\.sax)\.(parse|fromstring|parseString|XML|make_parser)[[:space:]]*\(|libxml_disable_entity_loader[[:space:]]*\([[:space:]]*false|LIBXML_NOENT' \
      "XML parsed with entities enabled — XXE and billion-laughs; use defusedxml (Python) or keep entity loading off (PHP)" \
      "$PY|$PHP"
    detect "tls-verify-off" \
      'verify[[:space:]]*=[[:space:]]*False|rejectUnauthorized[[:space:]]*:[[:space:]]*false|InsecureSkipVerify[[:space:]]*:[[:space:]]*true|NODE_TLS_REJECT_UNAUTHORIZED[[:space:]]*=[[:space:]]*["'"'"']?0|CURLOPT_SSL_VERIFYPEER[[:space:]]*(=>|,)[[:space:]]*(false|0)[^.0-9]|["'"'"']verify["'"'"'][[:space:]]*=>[[:space:]]*false' \
      "TLS verification disabled — MITM-able; trust the dev CA instead of turning verification off" \
      "$CODE"
    detect "weak-cipher-mode" \
      'AES\.MODE_ECB|["'"'"']aes-[0-9]+-ecb["'"'"']|crypto\.(createCipher|createDecipher)[[:space:]]*\(' \
      "ECB mode leaks plaintext structure and createCipher derives keys without an IV — use AES-GCM via createCipheriv / modes.GCM" \
      "$CODE"
    detect "script-without-sri" \
      '<script[^>]*src[[:space:]]*=[[:space:]]*["'"'"'](https?:)?//' \
      "external <script> without integrity= — add an SRI hash and crossorigin, or self-host" \
      "$MARKUP" 'integrity[[:space:]]*='

    SYSKEY='role["'"'"']?[[:space:]]*(:|=>|=)[[:space:]]*["'"'"']system["'"'"']|(^|[^[:alnum:]_])["'"'"']?(system|system_?prompt|systemPrompt)["'"'"']?[[:space:]]*(:|=>|=)'
    INTERP='\$\{|\{\$|r?f["'"'"']{1,3}[^"'"'"']*\{|\.format[[:space:]]*\(|%s|["'"'"'`][[:space:]]*\+[[:space:]]*[A-Za-z_$]|[A-Za-z0-9_$][[:space:]]*\+[[:space:]]*["'"'"'`]|["'"'"'][[:space:]]*\.[[:space:]]*\$|\$[A-Za-z0-9_]+[[:space:]]*\.[[:space:]]*["'"'"']'
    detect "prompt-interpolation" \
      "(${SYSKEY}).*(${INTERP})" \
      "user input inside the system prompt — pass it as a user turn or a delimited data block, never into the instruction text" \
      "$JS|$PY|$PHP" '[=!]='
    LLMSRC='completion|choices\[0\]|(\.|->)(content|text)([^[:alnum:]_]|$)|(^|[^[:alnum:]_$])message([^[:alnum:]_]|$)'
    SINKCALL='(^|[^[:alnum:]_.$>])(eval|exec(Sync)?|system|shell_exec|passthru|proc_open|popen)[[:space:]]*|os\.system[[:space:]]*|new[[:space:]]+Function[[:space:]]*|child_process\.[A-Za-z]+[[:space:]]*|subprocess\.[A-Za-z_]+[[:space:]]*'
    detect "llm-output-exec" \
      "(${LLMSRC}).*(${SINKCALL})\(|(${SINKCALL})\((message([^[:alnum:]_]|$)|.*(${LLMSRC}))" \
      "model output executed as code — validate against a schema or allow-list first" \
      "$JS|$PY|$PHP"
    TRVAR='tool_?[Rr]esults?|retrieved[A-Za-z_]*|chunks|documents|context_docs'
    TRKEY='[Pp]rompt|messages|content["'"'"']?[[:space:]]*(:|=>)'
    TRINTERP='["'"'"'`][^"'"'"'`]*\$?\{([^}]*[^[:alnum:]_])?('"$TRVAR"')|\+[[:space:]]*\$?('"$TRVAR"')([^[:alnum:]_]|$)|(^|[^[:alnum:]_])\$?('"$TRVAR"')[[:space:]]*\+|\.[[:space:]]*\$('"$TRVAR"')([^[:alnum:]_]|$)|\$('"$TRVAR"')[[:space:]]*\.|%[[:space:]]*\(?('"$TRVAR"')([^[:alnum:]_]|$)|(format|join)\([[:space:]]*('"$TRVAR"')([^[:alnum:]_]|$)'
    detect "tool-result-unfenced" \
      "(${TRKEY}).*(${TRINTERP})|(${TRINTERP}).*(${TRKEY})" \
      "retrieved text is untrusted input — fence it with a delimiter and tell the model it is data" \
      "$JS|$PY|$PHP" '<<<|"""|'"'''"'|<[a-z_]+>|\[BEGIN|---|```'
  }

  # added_text <file>: at most 256 KiB of what a run added, the whole file when HEAD lacks it, else the `+` lines of `git diff -U0 HEAD`, so an uncommitted earlier edit is judged again.
  added_text() {
    local rel="${1#"$sroot"/}"
    if git -C "$sroot" cat-file -e "HEAD:$rel" 2>/dev/null; then
      GIT_OPTIONAL_LOCKS=0 git -C "$sroot" diff --no-color --no-ext-diff -U0 HEAD -- ":(literal)$rel" 2>/dev/null \
        | awk '/^@@/ { h = 1; next } h && /^\+/ { print substr($0, 2) }'
    else
      cat -- "$1" 2>/dev/null
    fi | head -c 262144
  }

  if [ "$tool" = Bash ]; then
    hit_files=""; seen="
"
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "$p" in
        /*) ;;
        "~/"*) [ -n "${HOME:-}" ] || continue; p="$HOME/${p#??}" ;;
        *) [ "$hascd" = 0 ] || continue; p="$cwd/$p" ;;
      esac
      # One spelling per file, so `./app.js` and `app.js` share a dedup key.
      d=$(CDPATH= cd -- "$(dirname -- "$p")" 2>/dev/null && pwd) || continue
      p="$d/$(basename -- "$p")"
      [ -f "$p" ] || continue
      seen="$seen$p
"
      cc_scope_skip "$p" && continue
      file=$p
      text=$(head -c 262144 "$p" 2>/dev/null)
      [ -n "$text" ] || continue
      before=$hits
      scan_text
      [ "$hits" = "$before" ] || hit_files="${hit_files:+$hit_files }$p"
    done <<EOF_T
$targets
EOF_T
    # A file the run changed that no target names: judged on what it added, as a Write or Edit is on its new text.
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "$seen" in *"
$p
"*) continue ;; esac
      cc_scope_skip "$p" && continue
      file=$p
      text=$(added_text "$p")
      [ -n "$text" ] || continue
      before=$hits
      scan_text
      [ "$hits" = "$before" ] || hit_files="${hit_files:+$hit_files }$p"
    done <<EOF_E
$effects
EOF_E
  else
    cc_scope_skip "$file" && exit 0
    scan_text
    hit_files=$file
  fi

  [ -n "$hits" ] || exit 0
  ctx="${hits}[security] Fix the lines above in ${hit_files}, or say why each is safe; /security:review checks what these patterns cannot. CC_SECURITY_SCAN=off turns these warnings off."
  jq -cn --arg c "$ctx" --arg ev "${hev:-PostToolUse}" \
    '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$c}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
