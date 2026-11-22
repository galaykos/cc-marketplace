#!/bin/bash
# install-guard.sh — PreToolUse on Bash: denies `skills add|install|i` (npx, bunx, pnpx, pnpm dlx, yarn dlx, bun x, npm exec or a bare skills) with -g/--global, --skill '*' or --all; asks on `claude plugin install|uninstall|enable|disable` with no -s/--scope, and on `npm audit fix --force`. Fails open.
# Misses: a command held in a variable, alias, function or script, or inside a double-quoted $( ); a wrapper option it cannot place (sudo -u NAME); npx --package=skills spellings; the /plugin slash command; a command the user runs with !.
# Why, limits, history: rationale/derivations/plugin-stack-scan.md § plugins/stack-scan/hooks/install-guard.sh

set -u

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

# One line per simple command outside quotes, its words unquoted and joined by \037; ; & | ( ) ` $( and newlines end a command.
segments() {
  printf '%s' "$1" | LC_ALL=C awk '
    BEGIN { RS = "\001" }
    function flush() { if (hw) seg = seg (seg == "" ? "" : "\037") w; w = ""; hw = 0 }
    function endseg() { flush(); if (seg != "") print seg; seg = "" }
    {
      s = $0; n = length(s); w = ""; hw = 0; seg = ""; q = ""
      for (i = 1; i <= n; i++) {
        c = substr(s, i, 1); nx = substr(s, i + 1, 1)
        if (q == "\047") { if (c == "\047") q = ""; else w = w c; continue }
        if (q == "\"") {
          if (c == "\"") { q = ""; continue }
          if (c == "\\" && nx ~ /["\\$`]/) { w = w nx; i++; continue }
          w = w c; continue
        }
        if (c == "\047" || c == "\"") { q = c; hw = 1; continue }
        if (c == "\\") { i++; if (nx != "\n") { w = w nx; hw = 1 }; continue }
        if (c == " " || c == "\t") { flush(); continue }
        if (c == "#" && !hw) { while (i <= n && substr(s, i, 1) != "\n") i++; endseg(); continue }
        if (c == "&" && (nx == ">" || w ~ /[<>]$/)) { w = w c; hw = 1; continue }
        if (c == "$" && nx == "(") { endseg(); i++; continue }
        if (c ~ /[;&|()\n`]/) { endseg(); continue }
        w = w c; hw = 1
      }
      endseg()
    }'
}

verdict=""; reason=""; depth=0

deny() { verdict=deny; reason=$1; }
ask() { [ -n "$verdict" ] || { verdict=ask; reason=$1; }; }

# The skills CLI after its launcher: [opts] skills[@v] add|install|i <args>. Denies on a forbidden flag.
skills_args() {
  local -a a=("$@"); local i=0 n=$# t in_skill=0 hit=""
  while [ "$i" -lt "$n" ]; do
    case "${a[$i]}" in -p|--package) i=$((i + 2)) ;; -*) i=$((i + 1)) ;; *) break ;; esac
  done
  case "${a[$i]:-}" in skills|skills@*) ;; *) return 0 ;; esac
  case "${a[$((i + 1))]:-}" in add|install|i) ;; *) return 0 ;; esac
  for t in "${a[@]:$((i + 2))}"; do
    case "$t" in
      -g|--global|--all|--skill=\*|-s=\*) hit=$t; break ;;
      -s|--skill) in_skill=1 ;;
      --*) in_skill=0 ;;
      -[A-Za-z]*) case "$t" in *[!A-Za-z-]*) ;; *g*) hit=$t; break ;; esac; in_skill=0 ;;
      '*') [ "$in_skill" = 1 ] && { hit="--skill '*'"; break; } ;;
    esac
  done
  [ -n "$hit" ] || return 0
  deny "stack-scan denied this skills.sh install: $hit installs machine-wide or a repository's whole skill set, and the vercel-skills-scout skill installs one picked skill per command, project-level (npx -y skills add <owner>/<repo> --skill '<listed name>' -y). Drop the flag and install the picked skill by name; a user who wants a global or whole-repo install runs the command themselves."
}

plugin_args() { # the words after `claude plugin`
  local verb=${1:-} t def
  case "$verb" in install|i|uninstall|remove) def="user scope, every project on this machine" ;; enable|disable) def="a scope it auto-detects" ;; *) return 0 ;; esac
  shift
  for t in "$@"; do
    case "$t" in -s*|--scope|--scope=*|-h|--help) return 0 ;; esac
  done
  ask "stack-scan: claude plugin $verb without --scope acts at the CLI's default, $def. Approve only if that is the scope you mean; otherwise add --scope local (this repository only), --scope project (committed for the team) or --scope user."
}

audit_args() { # the words after `npm`
  [ "${1:-}" = audit ] && [ "${2:-}" = fix ] || return 0
  local t
  for t in "$@"; do
    case "$t" in
      --force|-f) ask "stack-scan: npm audit fix --force applies semver-major upgrades across the dependency tree in one step, breaking changes included. Approve only to take every major at once; otherwise run npm audit fix without --force and take each major on its own (stack-scan's package-hygiene skill)."; return 0 ;;
    esac
  done
}

# One simple command: wrappers and assignments skipped, then the command word decides.
classify_words() {
  local -a w=("$@"); local i=0 n=$# t cmd
  while [ "$i" -lt "$n" ]; do
    t=${w[$i]}
    case "$t" in
      [A-Za-z_]*=*) case "${t%%=*}" in *[!A-Za-z0-9_]*) break ;; esac ;;
      sudo|doas|command|builtin|exec|nohup|time|nice|env|xargs|then|do|else|elif|if|while|until|'!'|'{')
        while [ $((i + 1)) -lt "$n" ] && case "${w[$((i + 1))]}" in -*) true ;; *) false ;; esac; do i=$((i + 1)); done ;;
      timeout)
        while [ $((i + 1)) -lt "$n" ] && case "${w[$((i + 1))]}" in -*) true ;; *) false ;; esac; do i=$((i + 1)); done
        i=$((i + 1)) ;;
      [0-9]*'>'*|[0-9]*'<'*|'>'*|'<'*|'&>'*) ;;
      *) break ;;
    esac
    i=$((i + 1))
  done
  [ "$i" -lt "$n" ] || return 0
  cmd=${w[$i]##*/}
  set -- "${w[@]:$((i + 1))}"
  case "$cmd" in
    npx|bunx|pnpx) skills_args "$@" ;;
    pnpm|yarn) [ "${1:-}" = dlx ] && { shift; skills_args "$@"; } ;;
    bun) [ "${1:-}" = x ] && { shift; skills_args "$@"; } ;;
    skills|skills@*) skills_args "$cmd" "$@" ;;
    npm)
      case "${1:-}" in exec|x) shift; skills_args "$@" ;; *) audit_args "$@" ;; esac ;;
    claude) case "${1:-}" in plugin|plugins) shift; plugin_args "$@" ;; esac ;;
    bash|sh|zsh|dash|ksh)
      while [ $# -gt 0 ]; do
        case "$1" in -*c*) [ $# -ge 2 ] && classify_command "$2"; return 0 ;; -*) shift ;; *) return 0 ;; esac
      done ;;
    eval) [ $# -gt 0 ] && classify_command "$*" ;;
  esac
  return 0
}

classify_command() {
  local line seg
  depth=$((depth + 1))
  [ "$depth" -le 3 ] || { depth=$((depth - 1)); return 0; }
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    IFS=$'\037' read -r -a seg <<<"$line"
    [ "${#seg[@]}" -gt 0 ] && classify_words "${seg[@]}"
    [ "$verdict" = deny ] && break
  done < <(segments "$(cc_strip_heredoc_bodies inert "$1")")
  depth=$((depth - 1))
  return 0
}

if [ "${1:-}" = "--check" ]; then
  classify_command "${2:-}"
  printf '%s\n' "${verdict:-allow}"; exit 0
fi

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  local input cmd
  input=$(cat 2>/dev/null) || exit 0
  case "$input" in *skills*|*plugin*|*audit*) ;; *) exit 0 ;; esac
  cmd=$(printf '%s' "$input" | jq -r '
    [ .tool_input.command // empty,
      .tool_input.script // empty,
      .tool_input.cmd // empty ] | map(select(. != "")) | join(" ; ")' 2>/dev/null) || exit 0
  [ -n "$cmd" ] || exit 0
  classify_command "$cmd"
  [ -n "$verdict" ] || exit 0
  jq -cn --arg d "$verdict" --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}' 2>/dev/null
}

main 2>/dev/null
exit 0
