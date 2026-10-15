#!/bin/bash
# Absolute-path shebang: the fail-open guarantee must hold under a broken PATH.
#
# PreToolUse readiness check on `gh pr merge`. Before the merge runs it reads the pull
# request's checks (`gh pr checks`, killed after CHECKS_TIMEOUT seconds) and returns
# permissionDecision "ask" when any check is pending, failing or cancelled, naming those
# checks and the off-switch. All green, no checks reported, or any error: silent, and the
# merge proceeds.
#
# The failure it exists for: a session ran `gh pr merge` while CI was still running, CI
# then failed on the merged commit, and the user had asked to wait for every check first.
# Nothing in the finish protocol reads CI state at the moment of the merge; the command
# is the one place that moment is visible.
#
# Tiering (ask, never deny): a pending or red check is usually a reason to wait, but a
# known-flaky or non-required check is a legitimate merge, and only the user knows which.
# The ask names the checks so that call takes one glance. In a headless run nobody answers
# an ask, so the merge does not happen there, which is the outcome this hook wants.
#
# A NETWORK READ IN A HOOK, against the house rule of no network calls: CI state lives only
# on GitHub, with no local stand-in. It is bounded (one `gh pr checks` per command, killed
# at CHECKS_TIMEOUT, well inside the hooks.json timeout), and every outcome that is not a
# parsed pending/failing row is silence: no gh, not logged in, no network, a timeout, no PR
# for the branch, no checks reported.
#
# WHAT IT READS: `gh pr merge` at a command position (after `;` `&&` `|` `(` `$(` or a
# wrapper such as `sudo`, `env`, `bash -c "…"`; the prefix list is no-ai-trailer.sh's),
# outside heredoc bodies (cc_strip_heredoc_bodies all: a body fed to `bash <<EOF` is not read,
# and every line after a `<<` it cannot place, such as one inside quotes or `${ }`, is read, so a
# `gh pr merge` line in a multi-line quoted string after one is read as a merge). The PR is
# the first positional argument (number, `#n`, URL or branch; never a redirection or a
# quoted value), else the current branch's; `-R/--repo` and a `GH_REPO=`/`GH_HOST=` prefix
# are passed through; gh runs in the payload's cwd.
# Silent on purpose: `--help`, `--disable-auto`, and `--auto`, which hands the wait to
# GitHub (and is what the ask suggests).
#
# WHAT IT DOES NOT CATCH, stated: a PR or repo held in a variable or a substitution
# (`gh pr merge "$n"`); any `gh pr merge` after the first in one command; flags between
# `pr` and `merge`; a merge through the API, the web UI or a push to the base branch;
# non-required checks that `--auto` does not wait for. A `cd` inside the command does not
# move where gh runs, so `cd ../other && gh pr merge 3` reads PR 3 of the session's repo,
# and an `export GH_REPO=…` before it is not read; the ask names the PR, so a wrong one shows.
#
# CC_MERGE_CHECKS=off disables it for the session, and the ask message says so.
# CC_MERGE_CHECKS unset: the /config option cc_merge_checks decides.
# Fail-open: missing jq or gh, unparseable input, any internal error allows the merge.

set -u

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

CHECKS_TIMEOUT=5
MAX_NAMES=5

# Command position, the same anchor and wrapper tokens as no-ai-trailer.sh's GIT_WRITE_RE,
# so the two guards agree on what runs. The tail stops at the next command delimiter
# outside a quoted span. A span counts only where a word, a `=` or a one-letter flag opens
# it; any other quote closes a wrapper's string (`bash -c "gh pr merge 12"`) and ends it.
MERGE_Q='("[^"]*"|'"'"'[^'"'"']*'"'"')'
MERGE_C='([^[:space:];&|`()"'"'"']|[<>]&|&>)'
MERGE_RE='(^|[;&|`()]|\$\()[[:space:]]*(([a-z_][a-z0-9_]*=[^[:space:]]*|bash|sh|zsh|dash|ksh|eval|exec|command|sudo|doas|env|nohup|timeout|nice|time|xargs|then|do|else|elif|if|while|until|-[-a-z0-9]*|[0-9]+|"|'"'"')[[:space:]]*)*([^[:space:]]*/)?gh[[:space:]]+pr[[:space:]]+merge'"([[:space:]]+(-[a-z]$MERGE_Q|$MERGE_Q|$MERGE_C)($MERGE_C|=$MERGE_Q)*)*"

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

# The quote character a word opens and does not close, else nothing.
open_quote() {
  case "$1" in
    \"*) case "${1#?}" in *\") ;; *) printf '"' ;; esac ;;
    \'*) case "${1#?}" in *\') ;; *) printf "'" ;; esac ;;
  esac
}

# Sets sel and repo from the words after `gh pr merge`, gh_repo and gh_host from a
# GH_REPO=/GH_HOST= prefix. Returns 1 when the call passes silently: help, --auto,
# --disable-auto, or a PR, repo or host this cannot resolve.
parse_merge() {
  local w a t r i=0 n skip=""
  read -r -a w <<< "$1"
  n=${#w[@]}
  while [ "$i" -lt "$n" ]; do
    t=${w[$i]##*[\"\'\(/\`\;\&\|]}
    [ "$t" = gh ] && [ "${w[$((i + 1))]:-}" = pr ] && [ "${w[$((i + 2))]:-}" = merge ] && break
    t=${w[$i]#"${w[$i]%%[!\"\'\(\`\;\&\|\$]*}"}
    case "$t" in
      GH_REPO=*) gh_repo=${t#GH_REPO=} ;;
      GH_HOST=*) gh_host=${t#GH_HOST=} ;;
    esac
    i=$((i + 1))
  done
  [ "$i" -lt "$n" ] || return 1
  i=$((i + 3))
  while [ "$i" -lt "$n" ]; do
    a=${w[$i]}; i=$((i + 1))
    if [ -n "$skip" ]; then
      case "$a" in *"$skip") skip="" ;; esac
      continue
    fi
    # A redirection is no argument; after a bare operator the target is the next word.
    r=${a#"${a%%[!0-9]*}"}
    case "$r" in
      '<'|'>'|'>>'|'<>'|'<<'|'<<-'|'<<<'|'>&'|'<&'|'&>'|'&>>') i=$((i + 1)); continue ;;
      [\<\>]*|'&>'*) continue ;;
    esac
    case "$a" in
      -h|--help|--auto|--disable-auto) return 1 ;;
      -R|--repo) repo=${w[$i]:-}; i=$((i + 1)) ;;
      --repo=*) repo=${a#--repo=} ;;
      -R?*) repo=${a#-R} ;;
      -b|--body|-F|--body-file|-t|--subject|-A|--author-email|--match-head-commit)
        skip=$(open_quote "${w[$i]:-}"); i=$((i + 1)) ;;
      --*=*) skip=$(open_quote "${a#*=}") ;;
      -[btFA]?*) skip=$(open_quote "${a#-?}") ;;
      -*) ;;
      *) [ -n "$sel" ] || sel=$a ;;
    esac
  done
  sel=${sel//[\"\']/}; repo=${repo//[\"\']/}
  gh_repo=${gh_repo//[\"\']/}; gh_host=${gh_host//[\"\']/}
  case "$sel" in *[!A-Za-z0-9._/:#-]*) return 1 ;; esac
  case "$repo$gh_repo" in *[!A-Za-z0-9._/:-]*) return 1 ;; esac
  case "$gh_host" in *[!A-Za-z0-9._:-]*) return 1 ;; esac
  return 0
}

# gh pr checks in <dir>, stdout only, killed after CHECKS_TIMEOUT seconds (status 1).
# A polling watchdog rather than timeout(1), which macOS does not ship.
run_checks() {
  local dir=$1 out pid i=0
  shift
  out=$(mktemp 2>/dev/null) || return 1
  ( cd "$dir" 2>/dev/null || exit 1
    [ -z "$gh_repo" ] || export GH_REPO="$gh_repo"
    [ -z "$gh_host" ] || export GH_HOST="$gh_host"
    exec gh pr checks "$@" ) > "$out" 2>/dev/null < /dev/null &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge $((CHECKS_TIMEOUT * 10)) ]; then
      kill "$pid" 2>/dev/null; rm -f "$out"; return 1
    fi
    sleep 0.1; i=$((i + 1))
  done
  cat "$out" 2>/dev/null; rm -f "$out"
  return 0
}

# Names of the checks whose bucket (gh's non-TTY second column) matches, comma-joined,
# at most MAX_NAMES of them.
names() {
  printf '%s\n' "$1" | awk -F'\t' -v re="$2" -v m="$MAX_NAMES" '
    $2 ~ re { n++; if (n <= m) s = s (s == "" ? "" : ", ") $1 }
    END { if (n > m) s = s " +" (n - m) " more"; printf "%s", s }'
}

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  [ "$(cc_option CC_MERGE_CHECKS on)" = off ] && exit 0
  local input cmd m dir rows failing pending pr reason
  sel=""; repo=""; gh_repo=""; gh_host=""
  input=$(cat 2>/dev/null) || exit 0
  case "$input" in *merge*) ;; *) exit 0 ;; esac
  cmd=$(printf '%s' "$input" | jq -r '
    [ .tool_input.command // empty,
      .tool_input.script // empty,
      .tool_input.cmd // empty ] | map(select(. != "")) | join(" ; ")' 2>/dev/null) || exit 0
  [ -n "$cmd" ] || exit 0
  m=$(cc_strip_heredoc_bodies all "$cmd" | tr '\n' ';' | grep -oiE "$MERGE_RE" | head -n 1)
  [ -n "$m" ] || exit 0
  parse_merge "$m" || exit 0
  command -v gh >/dev/null 2>&1 || exit 0
  dir=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$dir" ] && [ -d "$dir" ] || dir=$PWD
  rows=$(run_checks "$dir" ${sel:+"$sel"} ${repo:+-R "$repo"}) || exit 0
  failing=$(names "$rows" '^(fail|cancel)$')
  pending=$(names "$rows" '^pending$')
  [ -n "$failing" ] || [ -n "$pending" ] || exit 0
  pr="the current branch's pull request"
  [ -n "$sel" ] && pr="PR $sel"
  reason="git-workflow: $pr is not green on CI —"
  [ -n "$failing" ] && reason="$reason failing: $failing;"
  [ -n "$pending" ] && reason="$reason still running: $pending;"
  reason="$reason merging now ships a commit CI has not passed. Approve to merge anyway (a known-flaky or non-required check), or deny and wait: gh pr checks${sel:+ $sel} --watch, or merge with --auto so GitHub merges once the required checks pass. CC_MERGE_CHECKS=off disables this check for the session."
  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}' 2>/dev/null
}

main
exit 0
