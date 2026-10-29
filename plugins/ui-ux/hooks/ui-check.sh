#!/bin/bash
# ui-check.sh (Stop) — sends the turn back once when the session or a finished subagent edited a project UI file (Edit/Write/MultiEdit, Bash >/tee/sed -i) in this turn and after the last browser call; unsure of a browser, or asked once and declined: one line, no block. Off: CC_UI_CHECK=off|warn.
# Misses: a subagent's own turn (SubagentStop is not hooked), a browser it does not recognise, interpreter, cp and mv writes, Bash writes past the newest MAX_BASH_CANDIDATES commands; a browser word read as a substring counts as a check.
# Why, limits, history: rationale/derivations/plugin-ui-ux.md § plugins/ui-ux/hooks/ui-check.sh

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

LC_ALL=C; export LC_ALL
MAX_BASH_CANDIDATES=8
MAX_HEREDOC_CHECKS=8
MAX_FILES_NAMED=3
MAX_FILES_LISTED=8
RUNNING_SUB_MIN=30
DECLINE_PROMPTS=2
UI_EXTS='tsx jsx vue blade.php svelte astro html erb twig css scss'
WORKTREE_RE='^\.claude/worktrees/[^/]+/'
SCRATCH_RE='^(\.[^/]+|taskmaster-docs)/|(^|/)(dist|build|out|coverage|storybook-static|node_modules|\.next|\.nuxt|\.svelte-kit)/'
NOT_UI_RE='(^|/)(__tests__|__mocks__|tests?|e2e|cypress|spec|playwright)/|\.(test|spec|stories|story|cy)\.[^/]*$|(^|/)setupTests\.[^/]*$'
AVAIL_WORDS='playwright browser_ chrome puppeteer'
TOOL_BROWSER_WORDS="$AVAIL_WORDS screenshot"
BASH_BROWSER_WORDS='playwright puppeteer cypress dusk browser test-storybook wdio lighthouse lhci pa11y e2e chrom --screenshot --headless backstop axe'
SKIP_VERBS='cat head tail less more grep egrep fgrep rg ag ls find tree wc diff git gh echo printf tee touch cp mv rm mkdir chmod ln stat file sed awk jq code vim vi nano open which type man sort uniq cut tr cd pushd popd export unset source'
DEV_RE='(^|[^[:alnum:]_-])((npm|pnpm|yarn)[[:space:]]+run[[:space:]]+(dev|serve|start)|vite|next[[:space:]]+dev|php[[:space:]]+artisan[[:space:]]+serve)([^[:alnum:]_-]|$)'
FRAME_RE='^[[:space:]]*(<system-reminder>|\[SYSTEM NOTIFICATION|Stop hook feedback:|<local-command-)'
ui_alt=${UI_EXTS//./\\.}; ui_alt=${ui_alt// /|}
UI_EXT_RE="\\.($ui_alt)\$"
SUB_SCAN_RE='"(file_path|command)":[[:space:]]*"([^"\\]|\\.)*\.('"$ui_alt"')|"name":[[:space:]]*"[^"]*('"${TOOL_BROWSER_WORDS// /|}"')|"command":[[:space:]]*"([^"\\]|\\.)*('"${BASH_BROWSER_WORDS// /|}"')'
PROMPT_RE='"role":[[:space:]]*"user",[[:space:]]*"content":[[:space:]]*("|\[[[:space:]]*\{[[:space:]]*"type":[[:space:]]*"(text|image)")'
WORDS_RE="\\.($ui_alt)|${TOOL_BROWSER_WORDS// /|}|${BASH_BROWSER_WORDS// /|}|run[[:space:]]+(dev|serve|start)|vite|next[[:space:]]+dev|artisan[[:space:]]+serve"
# A browser word counts in a command segment that runs something: not a reader, writer, VCS or cd, not a package install, quoted text masked.
CHECK_DEFS='
  def has_word($ws): ascii_downcase as $l | any($ws[]; . as $w | $l | contains($w));
  def is_check:
    gsub("\u0027[^\u0027]*\u0027"; "") | gsub("\"([^\"\\\\]|\\\\.)*\""; "") | ascii_downcase
    | [splits("&&|\\|\\||[;|&()\n]")]
    | any(.[];
        sub("^[[:space:]]*(((sudo|time|env|exec|command|nohup|xargs)[[:space:]]+)|([a-z_][a-z0-9_]*=[^[:space:]]*[[:space:]]+))*"; "")
        | [splits("[[:space:]]+") | select(length > 0)] as $w
        | (($w[0] // "") | split("/") | last) as $v
        | (any($skipverbs[]; . == $v) | not)
          and ((any(("npm", "pnpm", "yarn", "bun", "npx", "pnpx", "bunx"); . == $v)
                and any($w[1:][]; . == "i" or . == "install" or . == "add" or . == "ci" or . == "remove" or . == "uninstall" or . == "update")) | not)
          and ($w | join(" ") | has_word($bashwords)));'
NL='
'

mode=$(cc_option CC_UI_CHECK on | tr '[:upper:]' '[:lower:]')
case "$mode" in off | false | 0 | no) exit 0 ;; esac
command -v jq >/dev/null 2>&1 || exit 0

later() { [[ "$1" > "$2" ]]; }
json_list() { printf '["%s"]' "${1// /\",\"}"; }

# Prints yes, no or unknown: enabledPlugins local > project > user, MCP servers minus the disabled ones, .mcp.json servers only once approved.
browser_configured() {
  local a=() f k
  for k in sl:"$root/.claude/settings.local.json" sp:"$root/.claude/settings.json" su:"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" \
           sm:"$root/.mcp.json" sc:"${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json"; do
    f=${k#??:}
    [ -f "$f" ] && [ -r "$f" ] && a+=(--slurpfile "${k%%:*}" "$f")
  done
  jq -n -r --arg re "${AVAIL_WORDS// /|}" --arg r "$root" --arg c "$cwd" "${a[@]}" '
    def one($k): ($ARGS.named[$k] // [{}])[0] | if type == "object" then . else {} end;
    def names: if type == "object" then keys[] else empty end;
    one("sl") as $l | one("sp") as $p | one("su") as $u | one("sm") as $m | one("sc") as $cj
    | (($cj.projects // {}) | (.[$r] // .[$c] // {})) as $cp
    | (($u.enabledPlugins // {}) + ($p.enabledPlugins // {}) + ($l.enabledPlugins // {})) as $ep
    | ([$l, $p, $u, $cp] | map(.disabledMcpjsonServers // []) | add) as $djs
    | ([$l, $p, $u, $cp] | map(.enabledMcpjsonServers // []) | add) as $ejs
    | any($l, $p, $u, $cp; .enableAllProjectMcpServers == true) as $all
    | ([$l, $p, $u, $cp, $cj] | map(.disabledMcpServers // []) | add) as $ds
    | [ ($ep | to_entries[] | select(.value == true) | .key | sub("@.*$"; "")),
        (([$cj.mcpServers | names] + [$cp.mcpServers | names]) - $ds | .[]),
        ($m.mcpServers | names | select(. as $s | ($all or any($ejs[]; . == $s)) and (any($djs[]; . == $s) | not))) ]
    | if any(.[]; ascii_downcase | test($re)) then "yes" else "no" end' 2>/dev/null || echo unknown
}

# <base64 command> <base64 record cwd> — the first UI file the command writes that counts, root-relative.
bash_ui_target() {
  local cmd rcwd hascd=0
  cmd=$(printf '%s' "$1" | base64 --decode 2>/dev/null) || return 0
  rcwd=$(printf '%s' "$2" | base64 --decode 2>/dev/null)
  case "$(cc_strip_heredoc_bodies cd "$cmd")" in *"cd "* | *"pushd "*) hascd=1 ;; esac
  cc_bash_write_targets "$cmd" | ROOT="$root" RCWD="$rcwd" HASCD="$hascd" UIX="$UI_EXT_RE" SCR="$SCRATCH_RE" NOTUI="$NOT_UI_RE" WT="$WORKTREE_RE" awk '
    { t = $0
      if (t !~ /^\//) { if (ENVIRON["HASCD"] == 1) next; t = (ENVIRON["RCWD"] ~ /^\// ? ENVIRON["RCWD"] : ENVIRON["ROOT"]) "/" t }
      while (sub(/\/\.\//, "/", t)) ;
      r = ENVIRON["ROOT"] "/"
      if (index(t, r) != 1) next
      rel = substr(t, length(r) + 1); in_tree = rel; sub(ENVIRON["WT"], "", in_tree)
      if (rel ~ /(^|\/)\.\.(\/|$)/ || tolower(rel) !~ ENVIRON["UIX"] || in_tree ~ ENVIRON["SCR"] || in_tree ~ ENVIRON["NOTUI"]) next
      print rel; exit }'
}

{
  input=$(cat)
  active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
  [ "$active" = "false" ] || exit 0
  tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  [ -n "$tp" ] && [ -f "$tp" ] && [ -r "$tp" ] || exit 0
  sd=${tp%.jsonl}
  # A background subagent still writing UI work may be mid-edit: the stop after it finishes decides, and nothing is recorded now.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -qE '"finished":[[:space:]]*true' "${f%.jsonl}.meta.json" 2>/dev/null && continue
    grep -qE '"requestShape":[[:space:]]*"background"' "${f%.jsonl}.meta.json" 2>/dev/null || continue
    grep -qiE "$SUB_SCAN_RE" "$f" 2>/dev/null && exit 0
  done <<EOF
$([ -d "$sd/subagents" ] && find "$sd/subagents" -maxdepth 1 -name '*.jsonl' -mmin -"$RUNNING_SUB_MIN" 2>/dev/null)
EOF
  done_subs=()
  while IFS= read -r f; do
    f="${f%.meta.json}.jsonl"
    [ -f "$f" ] && [ -r "$f" ] && done_subs+=("$f")
  done <<EOF
$([ -d "$sd/subagents" ] && grep -lE '"finished":[[:space:]]*true' "$sd"/subagents/*.meta.json 2>/dev/null)
EOF
  subs=()
  [ "${#done_subs[@]}" -gt 0 ] && while IFS= read -r f; do
    [ -n "$f" ] && subs+=("$f")
  done <<EOF
$(grep -liE "$SUB_SCAN_RE" "${done_subs[@]}" 2>/dev/null)
EOF
  grep -qiE "\\.($ui_alt)" "$tp" 2>/dev/null || [ "${#subs[@]}" -gt 0 ] || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "${CLAUDE_PROJECT_DIR:-$cwd}") || exit 0

  ctx=$(printf '%s' "$tp" | cksum | cut -d' ' -f1)
  dir=$(cc_plugin_state "$root" ui-ux)
  marker="$dir/ui-check-$ctx"
  m_ts=""; m_state=""; m_anchor=""
  [ -r "$marker" ] && read -r m_ts m_state m_anchor < "$marker" 2>/dev/null
  case "$m_anchor" in '' | -) m_anchor=$m_ts ;; esac

  # Event line: time, source (m, s<n>), kind U UI edit, C Bash maybe-write, B browser, W browser word beside a heredoc, S dev server, P prompt, N other opener, F failed call, D0/D+/D- tool list, X bad line.
  # jq compiles a regex on every test() call, so per-record checks are string checks first.
  prog="$CHECK_DEFS"'
    def uiext: ascii_downcase as $l | any($exts[]; . as $e | $l | endswith($e));
    def rootrel($cwd):
      (if startswith("/") then . elif ($cwd | type) == "string" and ($cwd | startswith("/")) then $cwd + "/" + . else $root + "/" + . end)
      | if contains("/./") then gsub("/(\\./)+"; "/") else . end
      | if startswith($root + "/") and ((contains("/..") and test("/\\.\\.(/|$)")) | not) then .[($root | length) + 1:] else null end;
    def counts: (if startswith(".claude/worktrees/") then sub($worktree; "") else . end) | (test($scratch) | not) and (test($notui) | not);
    def writes: gsub("[0-9]*>&[0-9-]+|&?[0-9]*>>?[[:space:]]*/dev/(null|stdout|stderr)"; "")
      | contains(">") or test("(^|[^[:alnum:]_-])(tee|sed|perl)([[:space:]]|$)");
    foreach (inputs | select(length > 0)) as $line ({src: "", ts: ""};
        ($line | index("\t")) as $p | ($line[$p + 1:]) as $rest | ($rest | index("\t")) as $q
        | ($rest[$q + 1:] | try fromjson catch "bad") as $r
        | (if .src == $line[0:$p] then .ts else "" end) as $prev
        | .src = $line[0:$p] | .r = $r | .carrier = ($rest[0:$q] == "~")
        | .ts = (if ($r | type) == "object" and ($r.timestamp | type) == "string" then $r.timestamp else $prev end);
      .r as $r | .ts as $ts | .src as $src
      | if .carrier then empty
        elif ($r | type) != "object" then "\t\($src)\tX"
        else
          ( if $r.type == "assistant" then
              ($r.message.content? | if type == "array" then . else [] end) | to_entries[]
              | .key as $i | .value | select(type == "object" and .type == "tool_use")
              | (.id // "\($src).\($ts).\($i)") as $k | ((.name // "") | tostring) as $n
              | if $n == "Edit" or $n == "Write" or $n == "MultiEdit" then
                  (.input.file_path? // null) as $f
                  | if ($f | type) == "string" and ($f | uiext) then
                      ($f | rootrel($r.cwd)) as $rr
                      | if $rr != null and ($rr | counts) then "U\t\($k)\t\($rr | @base64)" else empty end
                    else empty end
                elif $n == "Bash" then
                  (.input.command? // null) as $c
                  | if ($c | type) != "string" then empty
                    else
                      (if ($c | has_word($exts)) and ($c | writes)
                         then "C\t\($k)\t\($c | @base64)\t\(($r.cwd // "") | tostring | @base64)" else empty end),
                      (if ($c | has_word($bashwords)) | not then empty
                       elif ($c | contains("<<")) then "W\t\($k)\t\($c | @base64)"
                       elif ($c | is_check) then "B" else empty end),
                      (if ($c | has_word(["dev", "serve", "start", "vite"])) and ($c | ascii_downcase | test($dev)) then "S" else empty end)
                    end
                elif ($n | has_word($toolwords)) then "B"
                else empty end
            elif $r.type == "user" then
              ($r.message.content? // null) as $mc
              | if ($mc | type) == "array" and any($mc[]; type == "object" and .type == "tool_result") then
                  $mc[] | select(type == "object" and .type == "tool_result" and .is_error == true) | "F\t\(.tool_use_id // "")"
                elif $src == "m" and $r.isMeta != true and $r.isCompactSummary != true then
                  (if ($mc | type) == "string" then $mc
                   elif ($mc | type) == "array" and ($mc[0] | type) == "object" and $mc[0].type == "image" then "image"
                   elif ($mc | type) == "array" then ([$mc[] | select(type == "object" and .type == "text") | .text] | first // null)
                   else null end) as $t
                  | if ($t | type) != "string" or ($t | test($frame)) then empty
                    elif ($t | sub("^[[:space:]]+"; "") | startswith("<task-notification>")) then "N"
                    else "P" end
                else empty end
            elif $r.type == "attachment" and $src == "m" and ($r.attachment | type) == "object"
                 and $r.attachment.type == "deferred_tools_delta" then
              "D0",
              ($r.attachment | (.addedNames, .readdedNames) | arrays | .[] | strings | select(has_word($availwords)) | "D+\t\(.)"),
              ($r.attachment.removedNames | arrays | .[] | strings | select(has_word($availwords)) | "D-\t\(.)")
            else empty end )
          | "\($ts)\t\($src)\t\(.)"
        end)'
  events=$(set -o pipefail
    MAIN="$tp" WORDS="$WORDS_RE" PROMPT="$PROMPT_RE" awk 'FILENAME != last { last = FILENAME; k++; carrier = "" }
      function wanted() {
        if (index($0, "\"tool_use\"")) return tolower($0) ~ ENVIRON["WORDS"]
        if (index($0, "deferred_tools_delta")) return 1
        if (index($0, "is_error") && $0 ~ /"is_error":[[:space:]]*true/) return 1
        return index($0, "\"user\"") && $0 ~ ENVIRON["PROMPT"]
      }
      { stamped = index($0, "\"timestamp\"") }
      wanted() { src = (FILENAME == ENVIRON["MAIN"] ? "m" : "s" k)
                 if (!stamped && carrier != "") print src "\t~\t" carrier
                 print src "\t\t" $0 }
      stamped { carrier = $0 }' "$tp" "${subs[@]}" 2>/dev/null \
      | jq -nR -r --arg root "$root" --arg scratch "$SCRATCH_RE" --arg notui "$NOT_UI_RE" --arg frame "$FRAME_RE" \
          --arg worktree "$WORKTREE_RE" --arg dev "$DEV_RE" --argjson exts "$(json_list ".${UI_EXTS// / .}")" \
          --argjson toolwords "$(json_list "$TOOL_BROWSER_WORDS")" --argjson availwords "$(json_list "$AVAIL_WORDS")" \
          --argjson bashwords "$(json_list "$BASH_BROWSER_WORDS")" --argjson skipverbs "$(json_list "$SKIP_VERBS")" "$prog" 2>/dev/null \
      | sort -s -t "$(printf '\t')" -k1,1) || exit 0

  # A browser word in a command holding a heredoc is judged without its bodies; past the newest few, such a command counts as a check.
  notchecks=""
  while IFS=$'\t' read -r key b64; do
    [ -n "$key" ] || continue
    cmd=$(printf '%s' "$b64" | base64 --decode 2>/dev/null) || continue
    verdict=$(cc_strip_heredoc_bodies inert "$cmd" | jq -Rs -r --argjson bashwords "$(json_list "$BASH_BROWSER_WORDS")" \
      --argjson skipverbs "$(json_list "$SKIP_VERBS")" "$CHECK_DEFS"' if is_check then "y" else "n" end' 2>/dev/null)
    [ "$verdict" = n ] && notchecks="$notchecks $key"
  done <<EOF
$(printf '%s\n' "$events" | awk -F'\t' '$3 == "W" { print $4 "\t" $5 }' | tail -n "$MAX_HEREDOC_CHECKS")
EOF

  # A bad session line silences the check (it could be the browser call); a bad subagent line drops only that subagent.
  summary=$(printf '%s\n' "$events" | NOTCHECKS="$notchecks" ANCHOR="$m_anchor" awk -F'\t' '
    BEGIN { split(ENVIRON["NOTCHECKS"], nc, " "); for (i in nc) notcheck[nc[i]] = 1; anchor = ENVIRON["ANCHOR"] }
    $3 == "X" { if ($2 == "m") { bad = 1; exit } drop[$2] = 1; next }
    ($2 in drop) { next }
    $3 == "D0" { known = 1; next }
    $3 == "D+" { tool[$4] = 1; next }
    $3 == "D-" { delete tool[$4]; next }
    $3 == "F" { failed[$4] = 1; next }
    $3 == "W" && ($4 in notcheck) { next }
    $3 == "B" || $3 == "W" { n = 0; cut = 0; lastb = $1; next }
    $3 == "P" { if (anchor != "" && $1 > anchor) prompts++; cut = n; next }
    $3 == "N" { cut = n; next }
    $3 == "S" { if (anchor != "" && $1 > anchor) dev = 1; next }
    $3 == "U" || $3 == "C" { ev[++n] = $0; mine[n] = ($2 == "m") }
    END {
      if (bad) exit 1
      avail = "unknown"
      if (known) { avail = "no"; for (t in tool) avail = "yes" }
      for (i = n; i >= 1; i--) {
        if (mine[i] && i <= cut) continue
        split(ev[i], f, "\t")
        if (f[3] == "U") { if ((f[4] in failed) || (f[5] in seen)) continue; seen[f[5]] = 1; u++ }
        out[++m] = ev[i]
      }
      print "meta\t" avail "\t" (lastb == "" ? "-" : lastb) "\t" u + 0 "\t" prompts + 0 "\t" dev + 0
      for (i = 1; i <= m; i++) { if (out[i] ~ /^\t/) out[i] = "-" out[i]; print out[i] } }') || exit 0

  newest=""; entries=""; cnames=""; ccount=0; checked=0; listed_n=0
  {
    IFS=$'\t' read -r _ avail last_b ucount pcount devstart
    [ "$last_b" = - ] && last_b=""
    while IFS=$'\t' read -r ts src kind key a b; do
      if [ "$kind" = U ]; then
        entry="U$src	$a"
      else
        [ "$checked" -lt "$MAX_BASH_CANDIDATES" ] || continue
        checked=$((checked + 1))
        t=$(bash_ui_target "$a" "$b")
        [ -n "$t" ] || continue
        case "$NL$cnames$NL" in *"$NL$t$NL"*) continue ;; esac
        cnames="$cnames$NL$t"; ccount=$((ccount + 1))
        entry="T$src	$t"
      fi
      if [ -z "$newest" ]; then
        newest=$ts
        [ "$newest" != - ] || exit 0
        [ -z "$m_ts" ] || later "$newest" "$m_ts" || exit 0
      fi
      entries="$entries$entry$NL"; listed_n=$((listed_n + 1))
      [ "$listed_n" -lt "$MAX_FILES_LISTED" ] || break
    done
  } <<EOF
$summary
EOF
  [ -n "$newest" ] || exit 0
  count=$((ucount + ccount))

  listed=""; shown=""; shown_n=0; subn=0
  while IFS=$'\t' read -r tag f; do
    [ -n "$f" ] || continue
    t=""; case "$tag" in ?s*) t=" (a subagent's edit)"; subn=$((subn + 1)) ;; esac
    listed="$listed${listed:+$NL}  - $f$t"
    [ "$shown_n" -lt "$MAX_FILES_NAMED" ] && shown="$shown${shown:+, }${f##*/}" && shown_n=$((shown_n + 1))
  done <<EOF
$(printf '%s' "$entries" | jq -R -r 'split("\t") | [.[0], (if .[0][0:1] == "U" then (.[1] | @base64d) else .[1] end)] | @tsv' 2>/dev/null)
EOF
  [ -n "$listed" ] || exit 0
  [ "$count" -gt "$MAX_FILES_NAMED" ] && shown="$shown and $((count - MAX_FILES_NAMED)) more"
  [ "$count" -gt "$listed_n" ] && listed="$listed$NL  - and $((count - listed_n)) more"
  was=were; [ "$count" -eq 1 ] && was=was
  by=""
  if [ "$subn" -eq "$listed_n" ]; then by=" by a subagent"
  elif [ "$subn" -gt 0 ]; then by=" ($subn by a subagent)"; fi

  # A block with no browser call since is a decline: print instead, until a browser call, a second prompt or a dev-server start.
  declined=0
  case "$m_state" in blocked | declined)
    later "$last_b" "$m_anchor" || [ "${pcount:-0}" -ge "$DECLINE_PROMPTS" ] || [ "$devstart" = 1 ] || declined=1 ;;
  esac
  [ "$avail" = unknown ] && avail=$(browser_configured)
  if [ "$mode" = "warn" ]; then state=noticed; anchor=-
  elif [ "$declined" = 1 ]; then state=declined; anchor=$m_anchor
  elif [ "$avail" != yes ]; then state=noticed; anchor=-
  else state=blocked; anchor=$newest; fi

  recorded=0
  if mkdir -p "$dir" 2>/dev/null; then
    [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
    printf '%s %s %s\n' "$newest" "$state" "$anchor" > "$marker" 2>/dev/null && recorded=1
  fi

  if [ "$mode" = "warn" ]; then
    msg="ui-ux: $shown changed$by and no browser check was seen after it; CC_UI_CHECK=warn, so the turn was not sent back."
  elif [ "$declined" = 1 ]; then
    msg="ui-ux: $shown changed$by and no browser check was seen after it; an earlier request for one in this session was not taken up, so this only prints. CC_UI_CHECK=off hides this."
  elif [ "$avail" != yes ]; then
    msg="ui-ux: $shown changed$by and no browser check was seen after it (the playwright plugin or a browser MCP server lets this check ask for one). CC_UI_CHECK=off hides this."
  elif [ "$recorded" != 1 ]; then
    msg="ui-ux: $shown changed$by and no browser check was seen after it; the check could not save its state, so the turn was not sent back."
  else
    reason=$(printf '[ui-ux] These UI files changed after the last browser check: render the changed page at 375, 768 and 1280 px wide and read the browser console, then stop, or say in one line why it cannot be checked in a browser.\n%s\n  CC_UI_CHECK=off turns this check off (=warn only prints).' "$listed")
    jq -cn --arg r "$reason" --arg m "ui-ux sent the turn back: $shown changed$by and $was not checked in a browser." \
      '{decision:"block",reason:$r,systemMessage:$m}'
    exit 0
  fi
  jq -cn --arg m "$msg" '{systemMessage:$m}'
} 2>/dev/null
exit 0
