#!/bin/bash
# Stop and SubagentStop: refuses a turn end (Stop: JSON block; SubagentStop: exit 2) for one clause per stop, tried 4, 1, 6, 2, 3, 5: an incomplete registered task-runner run, a file:line resolving to nothing, a file:line's quote: `…` in neither that file, its HEAD copy nor the transcript tail's tool output or user turns, a reversal after bare pushback, a naked completion claim (after an Edit or a Bash write to a non-prose file), lockfile drift.
# Misses a wrong API, flag or directory, a Bash write cc_bash_write_targets cannot see (interpreter, cp/mv, a path in a variable), pushback outside its list, entries before the transcript tail, unmatched dependency lines, a UI card with no review diff, quotes past MAX_QUOTES_CHECKED or QUOTE_DEADLINE_SECONDS or beside an ambiguous path; blocks on a citation into a file the turn shortened, renamed or deleted. Fail-open. Off: CC_CANDOR_GATE=off|warn (all), CC_EVIDENCE_GATE=off|warn (3), TASK_RUNNER_STOP_GATE=off|warn (4), CC_LOCKFILE_GATE=off (5); unset, /config.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/gate.sh

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

# Clause 1's lookup, shared with /candor:check. A missing file stands the clause down; it never fails the gate.
. "$(dirname "$0")/cite.sh" 2>/dev/null

INFLIGHT_TTL_MIN=180
# Only for a running.pid with no deadline: seven built-in runners at task-runner's 1800 s suite cap run 210 minutes.
BG_PID_TTL_MIN=240
DISCLOSURE_TAIL_LINES=200
TRANSCRIPT_TAIL_LINES=4000
MAX_CITATIONS_CHECKED=25
MAX_QUOTES_CHECKED=20
# Seconds since the hook started (bash SECONDS), past which no quote check starts: a check reads a 1 MiB file once or twice at 0.7-2.5 s a read under mawk, and the hook is killed at 15.
QUOTE_DEADLINE_SECONDS=6
QUOTE_EXCERPT_BYTES=262144
# Real 10-17 MB transcript tails extract in 0.1-0.15 s; a 22 MB synthetic one took 7.9 s.
QUOTE_EXTRACT_SECONDS=2
BARE_PUSHBACK_MAX_BYTES=400
CLAIM_WINDOW_LINES=30

input=$(cat)

have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1
evt="Stop"; agent_id=""; sid=""
if [ "$have_jq" = 1 ]; then
  evt=$(printf '%s' "$input" | jq -r '.hook_event_name // "Stop"' 2>/dev/null)
  agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
fi
# Not enforcement, so before the off switch: a record kept while the gate was off would hold clause 4's no-gate-pass block silent.
inflight_dir=""; inflight_rec=""
[ -n "$sid" ] && inflight_dir="${TMPDIR:-/tmp}/cc-candor-inflight-$(printf '%s' "$sid" | cksum | cut -d' ' -f1)"
if [ "$evt" = "SubagentStop" ] && [ -n "$inflight_dir" ] && [ -n "$agent_id" ]; then
  inflight_rec="$inflight_dir/$(printf '%s' "$agent_id" | cksum | cut -d' ' -f1)"
  if [ -f "$inflight_rec" ]; then rm -f "$inflight_rec" 2>/dev/null; else inflight_rec=""; fi
fi

gate_mode=$(cc_option CC_CANDOR_GATE block)
case "$gate_mode" in off) exit 0 ;; esac

[ "$have_jq" = 1 ] || { echo "[candor] jq not found, so the Stop check is not enforced." >&2; exit 0; }

sha_active=$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
# -d, not -n: the payload cwd is a host string, and the state mkdir below must never recreate a project the user deleted.
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"
root=$(cc_state_root "$cwd") || exit 0
# Per-agent marker suffix: hashed, so the id never lands raw in a path.
agent_sfx=""
[ -n "$agent_id" ] && agent_sfx="-$(printf '%s' "$agent_id" | cksum | cut -d' ' -f1)"

# The host's stop_hook_active is shared by every Stop hook: only the clause this gate recorded as blocking stands down on its continuation.
state_dir=$(cc_plugin_state "$root" candor)
claimed="$state_dir/blocked$agent_sfx"
skip=""
if [ "$sha_active" = "true" ] && [ -f "$claimed" ]; then
  skip=$(cat "$claimed" 2>/dev/null)
  rm -f "$claimed" 2>/dev/null
fi

verdict=""
detail=""
run_msg=""
run_note=""
run_owed=""
run_items=""
run_labels=""
run_count=0
notes=""
pass_note=""

# A note printed before a later clause blocks still reaches the model: block_turn puts it in front of the reason.
say() { printf '%s\n' "$1" >&2; notes="$notes$1
"; }

# Stop: the host shows systemMessage to the person and feeds reason to the model; a SubagentStop systemMessage stays in the agent's own transcript, so that event keeps exit 2.
block_turn() { # <reason> <one plain line for the person>
  if [ "$evt" = "SubagentStop" ]; then printf '%s\n' "$1" >&2; exit 2; fi
  jq -cn --arg r "$notes$1" --arg m "$2" '{decision:"block",reason:$r,systemMessage:$m}'
  exit 0
}

# Every passing exit once clause 4 has run: shows the person what the run still owes, with no decision key, so it cannot block.
pass_turn() {
  [ -z "$pass_note" ] || jq -cn --arg m "$pass_note" '{systemMessage:$m}'
  exit 0
}

run_item() { # <short label for the person> <action line for the model>
  run_labels="$run_labels${run_labels:+, }$1"
  run_items="$run_items
  - $2"; run_count=$((run_count + 1)); }

inflight_count() {
  local n
  n=$(printf '%s' "$input" | jq -r 'if (.background_tasks | type) == "array"
        then [.background_tasks[] | select(.type == "subagent" or .type == "teammate")] | length
        else "absent" end' 2>/dev/null)
  case "$n" in '' | absent | *[!0-9]*) ;; *) printf '%s' "$n"; return 0 ;; esac
  # -O: a records dir another user created under a shared /tmp is not evidence.
  if [ -n "$inflight_dir" ] && [ -d "$inflight_dir" ] && [ -O "$inflight_dir" ]; then
    find "$inflight_dir" -type f -mmin +"$INFLIGHT_TTL_MIN" -delete 2>/dev/null
    find "$inflight_dir" -type f ! -mmin +"$INFLIGHT_TTL_MIN" 2>/dev/null | wc -l | tr -d ' '
  else
    printf '0'
  fi
}

# bg/running.pid (PID, HEAD, optional deadline) is one worker while its sha is <head>, its deadline unpassed (none: younger than BG_PID_TTL_MIN) and live: with /proc, the PID's or else any <root> process's command line names behavioral-gate.sh (a sandbox records its own namespace's PID); [e] stops the scan's grep matching itself.
# Misses: without /proc liveness is kill -0, so a recycled PID at the same HEAD holds until the deadline or the file ages out.
bg_running() { # <head> -> 1 or 0
  local f="$root/.claude/task-runner/bg/running.pid" pid="" sha="" dl="" rp p
  if [ -r "$f" ]; then
    { read -r pid || :; read -r sha || :; read -r dl || :; } < "$f"
    case "$dl" in
      '' | *[!0-9]*) [ -z "$(find "$f" -mmin +"$BG_PID_TTL_MIN" 2>/dev/null)" ] || pid="" ;;
      *) [ "$(date +%s)" -lt "$dl" ] 2>/dev/null || pid="" ;;
    esac
    case "$pid" in '' | *[!0-9]*) pid="" ;; esac
    case "$sha" in '' | *[!0-9a-f]*) sha="" ;; esac
    if [ -n "$pid" ] && [ "${#sha}" -ge 7 ]; then
      case "$1" in "$sha"*)
        if [ ! -d /proc/self ]; then kill -0 "$pid" 2>/dev/null && { printf '1'; return 0; }
        else
          grep -qsE 'behavioral-gat[e]\.sh' "/proc/$pid/cmdline" && { printf '1'; return 0; }
          rp=$(cd "$root" 2>/dev/null && pwd -P)
          for p in $(grep -lsE 'behavioral-gat[e]\.sh' /proc/[0-9]*/cmdline 2>/dev/null); do
            case "$(readlink "${p%/cmdline}/cwd" 2>/dev/null)/" in "$root"/* | "${rp:-$root}"/*) printf '1'; return 0 ;; esac
          done
        fi ;;
      esac
    fi
  fi
  printf '0'
}

run_clause() {
  local sentinel="$root/.claude/task-runner/active-run.json"
  [ "$evt" != "SubagentStop" ] || return 0
  case "$(cc_option TASK_RUNNER_STOP_GATE block)" in off) return 0 ;; esac
  # A run closes by renaming its sentinel (run.md step 4), so the stop after the report still reads its records; a clean read retires it.
  [ -r "$sentinel" ] || sentinel="$root/.claude/task-runner/closed-run.json"
  [ -r "$sentinel" ] || return 0
  jq empty "$sentinel" 2>/dev/null || { say "[candor] .claude/task-runner/active-run.json is malformed, so the task-runner run is not checked."; return 0; }
  command -v git >/dev/null 2>&1 || { say "[candor] git not found, so the task-runner run is not checked."; return 0; }
  local head run_branch cur_branch slug
  head=$(git -C "$root" rev-parse HEAD 2>/dev/null) || { say "[candor] Not a git repository, so the task-runner run is not checked."; return 0; }
  # A closed run whose gate pass names an earlier HEAD closed there, and its closing stop never reached this clause.
  local closed_at
  case "$sentinel" in */closed-run.json)
    closed_at=$(jq -r '.head // empty' "$root/.claude/task-runner/gate-pass.json" 2>/dev/null)
    if [ -n "$closed_at" ] && [ "$closed_at" != "$head" ]; then rm -f "$sentinel" 2>/dev/null; return 0; fi ;;
  esac

  # An abandoned run leaves its sentinel behind: a run that names its branch is enforced only on that branch.
  run_branch=$(jq -r '.branch // empty' "$sentinel" 2>/dev/null)
  # symbolic-ref, not rev-parse --abbrev-ref: a tag named like the branch prints heads/<branch>. Exit 1 is a detached head; any other failure leaves the branch unknown, which never stands a run down.
  cur_branch=$(git -C "$root" symbolic-ref -q HEAD 2>/dev/null)
  case $? in 0) cur_branch=${cur_branch#refs/heads/} ;; 1) cur_branch=HEAD ;; *) cur_branch="" ;; esac
  if [ -n "$run_branch" ] && [ -n "$cur_branch" ] && [ "$run_branch" != "$cur_branch" ]; then
    say "$(printf '[candor] The task-runner run was registered on branch %s and you are on %s, so it is not checked here.\n  If that run is finished or abandoned, delete .claude/task-runner/%s.' "$run_branch" "$cur_branch" "${sentinel##*/}")"
    return 0
  fi
  RUN_HEAD="$head"; RUN_SENTINEL="$sentinel"
  slug=$(jq -r '.slug // "the active run"' "$sentinel" 2>/dev/null)

  local gatepass="$root/.claude/task-runner/gate-pass.json" v ct cdone cpark
  if [ -r "$gatepass" ] && [ "$(jq -r '.head // empty' "$gatepass" 2>/dev/null)" = "$head" ]; then
    v=$(jq -r '
      if ((.cards_total|type)=="number" and (.cards_done|type)=="number" and (.cards_parked|type)=="number")
      then (if (.cards_done + .cards_parked) < .cards_total then "incomplete"
            elif (.cards_done + .cards_parked) > .cards_total then "malformed"
            else "complete" end)
      elif ((has("cards_total") or has("cards_done") or has("cards_parked")) | not) then "absent"
      else "malformed" end' "$gatepass" 2>/dev/null)
    if [ "$v" = "absent" ] && [ "$(jq -r 'has("index_path")' "$sentinel" 2>/dev/null)" = "true" ]; then
      v="malformed"
    fi
    if [ "$v" = "incomplete" ] || [ "$v" = "malformed" ]; then
      ct=$(jq -r '.cards_total' "$gatepass" 2>/dev/null)
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      cpark=$(jq -r '.cards_parked' "$gatepass" 2>/dev/null)
      run_item "card counts that add up" "$(printf 'Finish or park every card, then record the three counts in .claude/task-runner/gate-pass.json as numbers that add up (now %s: done=%s parked=%s total=%s).' "$v" "$cdone" "$cpark" "$ct")"
    fi
    # Only records newer than this registration count: card ids repeat across runs, and these dirs are never cleared.
    local ncdir="$root/.claude/task-runner/nc" nc_count
    if [ "$v" = "complete" ] && [ -d "$ncdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      nc_count=$(find "$ncdir" -maxdepth 1 \( -name 'nc-pass-*.json' -o -name 'nc-skip-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/nc-(pass|skip)-##; s#\.json$##' | sort -u | wc -l | tr -d ' ')
      if [ "$nc_count" -lt "$cdone" ] 2>/dev/null; then
        run_item "checks that tests fail without the change" "$(printf 'Run the missing checks that a card'"'"'s test fails without the change (%s cards done, only %s have one in .claude/task-runner/nc/) with task-runner'"'"'s scripts/negative-control.sh --record-dir .claude/task-runner/nc --card <id>, or record a skip with its reason (--skip "<why>").' "$cdone" "$nc_count")"
      fi
    fi
    local rvdir="$root/.claude/task-runner/rv" rv_count
    if [ "$v" = "complete" ] && [ -d "$rvdir" ]; then
      cdone=$(jq -r '.cards_done' "$gatepass" 2>/dev/null)
      rv_count=$(find "$rvdir" -maxdepth 1 \( -name 'rv-seen-*.json' -o -name 'rv-skip-*.json' -o -name 'rv-exempt-*.json' \) -newer "$sentinel" 2>/dev/null |
        sed -E 's#.*/rv-(seen|skip|exempt)-##; s#\.json$##' | grep -v '^range-' | sort -u | wc -l | tr -d ' ')
      if [ "$rv_count" -lt "$cdone" ] 2>/dev/null; then
        run_item "card reviews" "$(printf 'Dispatch the missing reviews (%s cards done, only %s have a review recorded in .claude/task-runner/rv/) as task-runner'"'"'s skills/task-execution/references/reviewer-routing.md (Coverage marker) describes, or record why not with scripts/review-skip.sh --card <id> --reason "<why>" (or --exempt no-reviewer-installed).' "$cdone" "$rv_count")"
      fi
    fi
    # A card whose review diff (task-runner's review-diff.sh) names a UI file owes ui-ux-reviewer: the count above let any reviewer stand in.
    local pf card uicards=""
    if [ "$v" = "complete" ] && [ -d "$rvdir" ]; then
      while IFS= read -r pf; do
        # Tests and stories are not UI: reviewer-routing sends a test-only card to code-reviewer alone.
        grep -E '^diff --git a/.* b/.*\.(tsx|jsx|vue|svelte|css|scss|sass|less|blade\.php)$' "$pf" 2>/dev/null |
          grep -qvE '/(__tests__|tests)/|\.(test|spec|stories)\.[^/]*$' || continue
        card=${pf##*/diff-}; card=${card%.patch}
        [ -n "$(find "$rvdir" -maxdepth 1 \( -name "rv-agent-$card@*ui-ux-reviewer.json" -o -name "rv-skip-$card.json" -o -name "rv-exempt-$card.json" \) -newer "$sentinel" 2>/dev/null)" ] ||
          uicards="$uicards $card"
      done < <(find "$rvdir" -maxdepth 1 -name 'diff-*.patch' -newer "$sentinel" 2>/dev/null | sort)
      if [ -n "$uicards" ]; then
        run_item "UI reviews" "$(printf 'Dispatch ui-ux:ui-ux-reviewer (no other reviewer counts) for each card that changed UI files and has no ui-ux-reviewer review recorded:%s, as task-runner'"'"'s skills/task-execution/references/reviewer-routing.md (Coverage marker) describes, or record why not with scripts/review-skip.sh --card <id> --reason "<why>" (or --exempt no-reviewer-installed).' "$uicards")"
      fi
    fi
    # A run with start_sha owes one whole-range review at this HEAD (rv-observe records it from RV-RANGE); after a commit, `from` is the newest reviewed ancestor, so only the commits since it are owed.
    local start_sha rf rid range_ok=0 from
    start_sha=$(jq -r '.start_sha // empty' "$sentinel" 2>/dev/null); from=$start_sha
    if [ -n "$start_sha" ] && [ -d "$rvdir" ]; then
      while IFS= read -r rf; do
        rid=${rf##*range-}; rid=${rid%.json}
        case "$rid" in '' | *[!0-9a-f]*) continue ;; esac
        [ "${#rid}" -ge 7 ] || continue
        case "$head" in "$rid"*) range_ok=1; break ;; esac
        case "$rf" in */range-*) git -C "$root" merge-base --is-ancestor "$rid" HEAD 2>/dev/null &&
          git -C "$root" merge-base --is-ancestor "$from" "$rid" 2>/dev/null && from=$rid ;; esac
      done < <(find "$rvdir" -maxdepth 1 \( -name 'range-*.json' -o -name 'rv-skip-range-*.json' -o -name 'rv-exempt-range-*.json' \) -newer "$sentinel" 2>/dev/null)
      if [ "$range_ok" = 0 ]; then
        run_item "the whole-diff review" "$(printf 'Run /code-review:review %s..HEAD with "RV-RANGE: %s" in its arguments (task-runner'"'"'s run.md step 4), as there is no whole-diff review recorded for HEAD %s, or record why it cannot run with scripts/review-skip.sh --card range-%s --reason "<why>" (or --exempt no-reviewer-installed).' "${from:0:12}" "${head:0:12}" "${head:0:12}" "${head:0:12}")"
      fi
    fi
    # Of the red verdicts only no-behavioral-coverage may pass, beside this HEAD's coverage reduction, which the report must then name.
    local bgdir="$root/.claude/task-runner/bg" bgv covred
    if [ "$v" = "complete" ] && [ -d "$bgdir" ]; then
      if [ ! -r "$bgdir/bg-$head.json" ]; then
        run_item "a behavioral-gate verdict" "$(printf 'Run task-runner'"'"'s scripts/behavioral-gate.sh against HEAD %s: gate-pass.json names it, but behavioral-gate.sh left no verdict record for it (.claude/task-runner/bg/bg-<head>.json).' "${head:0:12}")"
      else
        bgv=$(jq -r '.verdict // empty' "$bgdir/bg-$head.json" 2>/dev/null)
        case "$bgv" in covered | no-executable-surface | '') bgv="" ;; esac
        covred="$root/.claude/task-runner/reductions/coverage-bg-${head:0:12}.json"
        if [ "$bgv" = "no-behavioral-coverage" ] && [ -f "$covred" ] && [ "$covred" -nt "$sentinel" ]; then
          bgv=""
        fi
        if [ "$bgv" = "no-behavioral-coverage" ]; then
          run_item "tests for the changed files" "$(printf 'Add tests a runner here executes and re-run behavioral-gate.sh, which reached "no-behavioral-coverage" for HEAD %s (no test in this project exercises the files the run changed). Or, if that coverage is out of scope: from the repo root run task-runner'"'"'s scripts/reduction-record.sh --kind coverage --id bg-%s --reason "<which files no runner covers, and why>", and name bg-%s and that reason in your closing report.' "${head:0:12}" "${head:0:12}" "${head:0:12}")"
        elif [ -n "$bgv" ]; then
          run_item "a passing behavioral gate" "$(printf 'Fix what behavioral-gate.sh reports and re-run it: it reached "%s" for HEAD %s.' "$bgv" "${head:0:12}")"
        fi
      fi
    fi
    # A boosted run owes the panel unless its diff since the run's base is docs and data only; a missing or unknown base counts as code.
    local rtdir="$root/.claude/task-runner/rt" idx idxp boosted run_base code_touched lenses critic degraded
    if [ "$v" = "complete" ] && [ -d "$rtdir" ]; then
      idx=$(jq -r '.index_path // empty' "$sentinel" 2>/dev/null)
      boosted=0
      case "$idx" in /*) idxp="$idx" ;; *) idxp="$root/$idx" ;; esac
      if [ -n "$idx" ] && [ -r "$idxp" ]; then
        # a Goal: line carrying boost=off (taskmaster goal-lean) is hands-off without the boost
        grep -iE '^[[:space:]]*(Ultra|Goal):[[:space:]]*true' "$idxp" 2>/dev/null | grep -qv 'boost=off' && boosted=1
      fi
      if [ "$boosted" = 1 ]; then
        run_base=$(jq -r '.base // empty' "$sentinel" 2>/dev/null)
        code_touched=unknown
        if [ -n "$run_base" ] && git -C "$root" rev-parse --verify "$run_base" >/dev/null 2>&1; then
          if git -C "$root" diff --name-only "$run_base..HEAD" 2>/dev/null |
               grep -qvE '\.(md|txt|json|ya?ml|lock|csv|svg|png|jpe?g|gif)$|^$'; then
            code_touched=yes
          else
            code_touched=no
          fi
        fi
        [ "$code_touched" = "no" ] && boosted=0
      fi
      if [ "$boosted" = 1 ]; then
        lenses=$(find "$rtdir" -maxdepth 1 -name 'rt-lens-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        critic=$(find "$rtdir" -maxdepth 1 -name 'rt-critic-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        degraded=$(find "$root/.claude/task-runner/reductions" -maxdepth 1 -name 'redteam-*.json' -newer "$sentinel" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$degraded" -eq 0 ] 2>/dev/null && { [ "$lenses" -lt 3 ] || [ "$critic" -lt 1 ]; } 2>/dev/null; then
          run_item "the red-team panel" "$(printf 'Dispatch the missing red-team agents as task-runner'"'"'s code-redteam skill describes, or record a reduced inline pass with scripts/reduction-record.sh --kind redteam --id <ref> --reason "<why>": the run is marked for max effort (Ultra or Goal in its index) and the red-team panel is short (%s of 3 refuters, %s of 1 completeness critic).' "$lenses" "$critic")"
        fi
      fi
    fi
    local ids tp said missing id
    if [ "$v" = "complete" ]; then
      ids=$(find "$rvdir" -maxdepth 1 -name 'rv-skip-*.json' -newer "$sentinel" 2>/dev/null |
              sed -E 's|.*/rv-skip-||; s|\.json$||'
            find "$root/.claude/task-runner/reductions" -maxdepth 1 -name '*.json' -newer "$sentinel" 2>/dev/null |
              sed -E 's|.*/[a-z]+-||; s|\.json$||')
      ids=$(printf '%s\n' "$ids" | sed '/^$/d' | sort -u)
      if [ -n "$ids" ]; then
        tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
        if [ -n "$tp" ] && [ -r "$tp" ]; then
          said=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' "$tp" 2>/dev/null | tail -"$DISCLOSURE_TAIL_LINES")
          missing=""
          for id in $ids; do
            printf '%s' "$said" | grep -qF "$id" || missing="$missing $id"
          done
          if [ -n "$said" ] && [ -n "$missing" ]; then
            run_item "naming skipped steps in the report" "$(printf 'Name each skipped or reduced step the closing report never names, and why it was cut:%s (details in .claude/task-runner/rv/ and reductions/).' "$missing")"
          fi
        fi
      fi
    fi
    if [ "$run_count" -gt 0 ]; then
      local things=things; [ "$run_count" -eq 1 ] && things=thing
      run_msg=$(printf '[candor] Not finished: %s %s must be done before the task-runner run %s can close:%s' "$run_count" "$things" "$slug" "$run_items")
      run_note="candor sent the turn back: $run_count $things to do before the task-runner run $slug can close."
      run_owed="candor let the turn end, but the task-runner run $slug still owes $run_count $things: $run_labels."
      verdict="run"; return 0
    fi
    case "$sentinel" in */closed-run.json) rm -f "$sentinel" 2>/dev/null ;; esac
    return 0
  fi

  # Mid-run and end-of-run look alike, so the message names both; workers in flight: print, block nothing and write no nudge, keeping this HEAD's one block for after the last hand-back.
  local waiting
  waiting=$(inflight_count)
  case "$waiting" in '' | *[!0-9]*) waiting=0 ;; esac
  waiting=$((waiting + $(bg_running "$head")))
  if [ "${waiting:-0}" -gt 0 ] 2>/dev/null; then
    say "$(printf '[candor] The task-runner run %s is not finished, but %s background worker(s) are still running, so this stop is allowed.\n  The check runs again when the last worker reports back.' "$slug" "$waiting")"
    return 0
  fi
  run_msg=$(printf '[candor] The task-runner run %s is not finished: HEAD %s has no recorded pass of behavioral-gate.sh, so do not end the turn here.
  Cards left: start the next card with a tool call now; naming it in prose and stopping leaves the user waiting.
  Need a decision: ask it with AskUserQuestion. Blocked: park the card with a reason.
  Every card done or parked: run the whole-diff review, then from the
    repo root, in the background, run task-runner'"'"'s scripts/behavioral-gate.sh --isolate --changed "<the run'"'"'s touched
    files>" with a Bash timeout of 7200000 (the default can stop it at 30 minutes). --isolate makes and removes its
    own worktree: do not build a checkout or write any .env for it.
    Then write .claude/task-runner/gate-pass.json as {"head":"%s"} plus the card counts, and rename
    active-run.json to closed-run.json (run.md step 4). The repo'"'"'s own test suite passing does not replace this.
  No rush: run one shell step per call and read its result; a denied or failed call ran nothing.
  Not running this task list? The run file is left over: delete .claude/task-runner/%s.' "$slug" "${head:0:12}" "$head" "${sentinel##*/}")
  run_note="candor sent the turn back: the task-runner run $slug is not finished."
  run_owed="candor let the turn end, but the task-runner run $slug still owes a recorded behavioral-gate pass for this commit."
  verdict="run"
}
RUN_HEAD=""; RUN_SENTINEL=""
run_clause

if [ "$verdict" = "run" ]; then
  run_mode="$gate_mode"
  case "$(cc_option TASK_RUNNER_STOP_GATE block)" in warn) run_mode=warn ;; esac
  # The switch is named here, the one print site of every clause-4 reason: a blocked reader sees only this text.
  run_msg="$run_msg
  TASK_RUNNER_STOP_GATE=off turns this check off (=warn only prints)."
  if [ "$run_mode" = "block" ]; then
    # One block per HEAD: the nudge counts only while newer than the sentinel, so an earlier run's marker cannot eat this one's block.
    nudge="$root/.claude/task-runner/gate-nudge"
    if [ -r "$nudge" ] && [ "$nudge" -nt "$RUN_SENTINEL" ] && [ "$(cat "$nudge" 2>/dev/null)" = "$RUN_HEAD" ]; then
      pass_note="$run_owed"               # bounded at this HEAD — printed, not blocked
    elif printf '%s' "$RUN_HEAD" > "$nudge" 2>/dev/null; then
      block_turn "$run_msg" "$run_note"
    elif [ "$sha_active" != "true" ]; then
      # No writable marker, so no per-HEAD bound: honour the shared flag here only, or an unwritable state dir blocks forever.
      block_turn "$run_msg" "$run_note"
    fi
  fi
  say "$run_msg"
  # Clause 4 spoke without blocking; a run held once at this HEAD still gets clauses 1-3 and 5 on every stop.
  verdict=""; run_msg=""
fi

read_transcript() {
  # A subagent's report lives in its own transcript; the parent's path is the fallback for a payload without one.
  tp=$(printf '%s' "$input" | jq -r '.agent_transcript_path // .transcript_path // empty' 2>/dev/null)
  tail_jsonl=""
  if [ -n "$tp" ] && [ -r "$tp" ]; then
    tail_jsonl=$(tail -n "$TRANSCRIPT_TAIL_LINES" "$tp" 2>/dev/null)
  fi

  handback=""
  if [ "$evt" = "SubagentStop" ]; then
    [ -n "$tail_jsonl" ] && handback=$(printf '%s' "$tail_jsonl" | jq -rs --arg n "SubagentHandback" '
      def usertext: .type=="user" and (.isCompactSummary|not) and ((.message.content // null) as $c
        | if ($c|type)=="string" then $c
          elif ($c|type)=="array" and (any($c[]; .type=="tool_result")|not) then [$c[] | select(.type=="text") | .text][0]
          else null end
        | type=="string" and (test("^\\s*(<system-reminder>|<task-notification>|\\[SYSTEM NOTIFICATION|Stop hook feedback:)")|not));
      . as $e | ([range(0; length) | select($e[.] | usertext)] | last // -1) as $b
      | [ $e[$b+1:][] | select(.type=="assistant") | (.message.content // [])[]
            | select(.type=="tool_use" and .name==$n) | .input.message // empty
            | select(type=="string" and length>0) ] | last // empty' 2>/dev/null)
  fi

  # A malformed JSONL line empties the -s slurp, which fails open: hence each fallback tests for empty.
  last_msg=$handback
  [ -n "$last_msg" ] || last_msg=$(printf '%s' "$input" | jq -r '.last_assistant_message // empty' 2>/dev/null)
  [ -n "$last_msg" ] || [ -z "$tail_jsonl" ] || last_msg=$(printf '%s' "$tail_jsonl" | jq -rs '
    [ .[] | select(.type=="assistant")
          | ((.message.content // []) | map(select(.type=="text") | .text) | join("\n"))
          | select(length > 0) ] | last // empty' 2>/dev/null)
}
read_transcript

clause_fabricated_citation() {
  [ -z "$verdict" ] && [ -n "$last_msg" ] && [ "$skip" != "citation" ] || return 0
  command -v cite_miss >/dev/null 2>&1 || { say "[candor] hooks/cite.sh not loaded, so file:line citations are not checked."; return 0; }
  # hooks/cite.sh: what counts as a citation (a dev host's :port does not) and when one is fabricated (its header has the limits).
  cites=$(printf '%s' "$last_msg" | cite_extract)
  misses=""
  checked=0
  for c in $cites; do
    [ "$checked" -ge "$MAX_CITATIONS_CHECKED" ] && break
    checked=$((checked + 1))
    r=$(cite_miss "$c" "$root" "$cwd")
    [ -n "$r" ] && misses="$misses
  - $c — $r"
  done

  if [ -n "$misses" ]; then
    verdict="citation"
    detail="$misses"
  fi
}
clause_fabricated_citation

# True only when <quote> is in neither <file> nor git's HEAD copy of it: a review may quote the code its turn then changed.
quote_missing() { # <file> <line> <quote> <scratch file>
  local d="${1%/*}" b="${1##*/}"
  cc_quote_match "$1" "$2" "$3" all; [ $? -eq 1 ] || return 1
  if [ -n "$4" ] && git -C "${d:-/}" show "HEAD:./$b" > "$4" 2>/dev/null; then
    cc_quote_match "$4" "$2" "$3" all; [ $? -eq 1 ]; return
  fi
  # In the index but not in HEAD there is no copy to compare; untracked, or outside a repository, the file is the only copy.
  ! git -C "${d:-/}" ls-files --error-unmatch -- "$b" >/dev/null 2>&1
}

# The quote's identifier words, longest first: no spacing falls inside one, so each sits verbatim in any copy of the quote.
quote_words() {
  printf '%s\n' "$1" | LC_ALL=C grep -oE '[A-Za-z_$][A-Za-z0-9_$]*' | LC_ALL=C awk '!seen[$0]++ { print length($0), $0 }' | sort -rn -k1,1 | cut -d' ' -f2-
}

# Clause 6: per line outside a fence, the last quote: `…` (or ``…``) span outside any code span, judged against every file:line before it.
clause_misquote() {
  [ -z "$verdict" ] && [ -n "$last_msg" ] && [ "$skip" != "quote" ] || return 0
  command -v cc_quote_match >/dev/null 2>&1 && command -v cite_file >/dev/null 2>&1 || return 0
  local recs pre q cs c f miss label qtmp late=0 hits="" misses=""
  # A fence closes only on its own character, at least as long; a backslash ending a single-backtick span escaped nothing.
  recs=$(printf '%s\n' "$last_msg" | LC_ALL=C awk -v max="$MAX_QUOTES_CHECKED" '
    match($0, /^[ \t]*(````*|~~~~*)/) {
      r = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", r)
      if (!fl) { fc = substr(r, 1, 1); fl = length(r); next }
      if (substr(r, 1, 1) == fc && length(r) >= fl && substr($0, RSTART + RLENGTH) ~ /^[ \t\r]*$/) { fl = 0; next }
    }
    fl || !index($0, "quote:") { next }
    {
      l = " " $0; L = length(l); i = 2; o = 0; mq = 0
      while (i <= L) {
        ch = substr(l, i, 1)
        if (ch == "`") {
          j = i; while (j <= L && substr(l, j, 1) == "`") j++
          if (!o) o = j - i; else if (j - i == o) o = 0
          i = j; continue
        }
        if (!o && ch == "q" && substr(l, i, 6) == "quote:" && substr(l, i - 1, 1) !~ /[A-Za-z0-9_]/) {
          k = i + 6; while (substr(l, k, 1) ~ /[ \t]/) k++
          if (substr(l, k, 1) == "`") { mq = i; mk = k }
        }
        i++
      }
      if (!mq) next
      p = substr(l, 1, mq - 1); s = substr(l, mk)
      if (p !~ /\.[A-Za-z][A-Za-z0-9]*:[0-9]/) next
      if (substr(s, 1, 2) == "``") { s = substr(s, 3); e = index(s, "``"); d = 1 } else { s = substr(s, 2); e = index(s, "`"); d = 0 }
      if (e < 2) next
      q = substr(s, 1, e - 1)
      if (!d) sub(/\\+$/, "", q)
      if (q == "") next
      printf "%s\037%s\n", p, q
      if (++n >= max + 0) exit
    }' 2>/dev/null)
  [ -n "$recs" ] || return 0
  command -v git >/dev/null 2>&1 || { say "[candor] git not found, so quote: marks are not checked."; return 0; }
  qtmp=$(mktemp "${TMPDIR:-/tmp}/cc-candor-quote.XXXXXX" 2>/dev/null) || return 0
  while IFS=$'\037' read -r pre q; do
    [ "$late" = 0 ] || break
    cs=$(printf '%s\n' "$pre" | cite_extract)
    miss=0; label=""
    for c in $cs; do
      # Past the deadline mid-line, the quote is left undecided.
      [ "$SECONDS" -lt "$QUOTE_DEADLINE_SECONDS" ] || { late=1; miss=0; break; }
      f=$(cite_file "${c%:*}" "$root" "$cwd") && quote_missing "$f" "${c##*:}" "$q" "$qtmp" \
        && cite_file "${c%:*}" "$root" "$cwd" sole >/dev/null || { miss=0; break; }
      miss=1; label="$label${label:+ / }$c"
    done
    [ "$miss" = 1 ] && hits="$hits$label"$'\037'"$q
"
  done <<EOF_QUOTES
$recs
EOF_QUOTES
  # Would block: text the transcript tail already showed is not invented — a tool result (a diff, a PR not checked out, an older
  # copy) or a user turn (a pasted hunk, a dispatch prompt, a background agent's <result>). Never the assistant's own text, a tool-use
  # error, hook feedback, a harness note, a skill or slash-command body, a compaction summary, or a user line holding a quote: mark.
  local jp kp w n found
  if [ -n "$hits" ] && [ "$SECONDS" -lt "$QUOTE_DEADLINE_SECONDS" ]; then
    printf '%s\n' "$tail_jsonl" > "$qtmp.in"
    jq -nrR '
      def plain: if type == "string" then . elif type == "array" then ([.[] | select(.type == "text") | .text] | join("\n")) else "" end;
      def shown:
        ([match("<result>([\\s\\S]*?)</result>"; "g") | .captures[0].string | select(. != null)] | .[]),
        (gsub("<(system-reminder|task-notification)>[\\s\\S]*?</(system-reminder|task-notification)>"; "")
         | select(test("^\\s*(Stop hook feedback:|SubagentStop hook feedback:|\\[SYSTEM NOTIFICATION)") | not)
         | split("\n") | map(select(test("quote:[ \\t]*`") | not)) | join("\n"));
      foreach (inputs | fromjson? | select(.type == "user" and (.isCompactSummary | not))) as $e ({cmd: false, e: null};
          ($e.message.content | plain) as $t
          | .e = (if $e.isMeta == true and (.cmd or ($t | startswith("Base directory for this skill:"))) then null else $e end)
          | .cmd = ($t | test("<command-name>"));
          .e // empty)
      | .message.content as $c
      | if ($c | type) == "string" then ($c | shown)
        elif ($c | type) == "array" then ($c[]
          | if .type == "text" then (.text | shown)
            elif .type == "tool_result" then (.content | plain | select(startswith("<tool_use_error>") | not))
            else empty end)
        else empty end
      | split("\n")[] | select(test("quotes text that is not in that file: `") | not) | sub("^ *[0-9]+(\t|→)"; "")' "$qtmp.in" > "$qtmp.raw" 2>/dev/null & jp=$!
    ( sleep "$QUOTE_EXTRACT_SECONDS"; kill "$jp" 2>/dev/null ) </dev/null >/dev/null 2>&1 & kp=$!
    # Killed at its budget, the extraction leaves every quote not judged.
    if wait "$jp"; then
      kill "$kp" 2>/dev/null
      LC_ALL=C tr -d '\000' < "$qtmp.raw" > "$qtmp"
      while IFS=$'\037' read -r label q; do
        [ -n "$label" ] || continue
        found=skip
        for w in $(quote_words "$q"); do
          # Past the deadline the rest are not judged.
          [ "$SECONDS" -lt "$QUOTE_DEADLINE_SECONDS" ] || break 2
          LC_ALL=C grep -a -F -C3 -- "$w" "$qtmp" 2>/dev/null | head -c $((QUOTE_EXCERPT_BYTES + 1)) > "$qtmp.part"
          n=$(wc -c < "$qtmp.part")
          # A word found nowhere cannot be in any copy of the quote; one so common its context passes the cap gives way to the next.
          [ "$n" -gt 0 ] || { found=miss; break; }
          [ "$n" -le "$QUOTE_EXCERPT_BYTES" ] || continue
          cc_quote_match "$qtmp.part" 1 "$q" all
          case $? in 1) found=miss ;; *) found=seen ;; esac
          break
        done
        [ "$found" = miss ] || continue
        misses="$misses
  - $label quotes text that is not in that file: \`${q:0:60}\`."
      done <<EOF_HITS
$hits
EOF_HITS
    else
      kill "$kp" 2>/dev/null
    fi
  fi
  rm -f "$qtmp" "$qtmp".*
  if [ -n "$misses" ]; then
    verdict="quote"
    detail="$misses"
  fi
}
clause_misquote

clause_unevidenced_reversal() {
  [ -z "$verdict" ] && [ -n "$last_msg" ] && [ -n "$tail_jsonl" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "reversal" ] || return 0
  # Tool results arrive as type "user" with no text block, so selecting text excludes them.
  last_user=$(printf '%s' "$tail_jsonl" | jq -rs '
    [ .[] | select(.type=="user")
          | (if (.message.content | type) == "string" then .message.content
             else ((.message.content // []) | map(select(.type=="text") | .text) | join("\n")) end)
          | select(length > 0) ] | last // empty' 2>/dev/null)

  PUSHBACK='are you sure|you sure|are you certain|is that (right|true|correct|actually)|that.?s (not right|wrong|incorrect|false|not true)|that is (not right|wrong|incorrect|false)|you.?re (wrong|mistaken)|you are (wrong|mistaken)|i don.?t think (so|that|it)|i disagree|doesn.?t (seem|sound|look) right|does not (seem|sound|look) right|check (it )?again|double.?check|really\?|no,? (it|that|this|they|you) |nope|prove it|where did you (get|see|find) that|you (made|just made) (that|it) up|hallucinat|that.?s not (how|what|where)'

  # Pushback that brings its own evidence (a backtick, a path, a file:line, an argued paragraph) is new information, not a bare challenge.
  user_has_evidence=0
  if [ -n "$last_user" ]; then
    printf '%s' "$last_user" | grep -q '`' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+' && user_has_evidence=1
    printf '%s' "$last_user" | grep -qE '\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' && user_has_evidence=1
    [ "$(printf '%s' "$last_user" | wc -c | tr -d ' ')" -gt "$BARE_PUSHBACK_MAX_BYTES" ] && user_has_evidence=1
  fi

  CAVE='you.?re (absolutely |completely |totally |quite |entirely )?right|you are (absolutely |completely |totally |quite |entirely )?right|you.?re correct|you are correct|my (mistake|apologies|bad|error)|i (was|am) wrong|i apologi[sz]e|apologies|good catch|i stand corrected|i (was|got) (confused|mistaken)|that was (wrong|my (mistake|error))|let me correct'

  # HOLD: the message names what it re-checked, or keeps part of its position — candour either way.
  HOLD='i still (think|believe|maintain)|i do (think|believe)|i.?m not (changing|reversing)|re-?read|re-?ran|re-?checked|i (checked|verified|confirmed)|after (checking|re-?reading|running|re-?running)|the (file|output|test|error|transcript) (shows|says)|i disagree|on (that|this) (one|point) i|partly|only partly|to be clear, i'

  if [ -n "$last_user" ] && [ "$user_has_evidence" -eq 0 ] \
     && printf '%s' "$last_user" | grep -qiE "$PUSHBACK" \
     && printf '%s' "$last_msg" | grep -qiE "$CAVE" \
     && ! printf '%s' "$last_msg" | grep -qiE "$HOLD"; then
    ran=$(printf '%s' "$tail_jsonl" | jq -r '
      if .type=="user" then
        (if ((.message.content | type) == "string")
            or (((.message.content // []) | map(select(.type=="text")) | length) > 0)
         then "USER" else "" end)
      elif .type=="assistant" then
        ([.message.content[]? | select(.type=="tool_use") | .name] | join(" "))
      else "" end' 2>/dev/null \
      | awk '{ if ($0 == "USER") { after = 0 } else if (NF > 0) { after = 1 } } END { print (after ? "yes" : "no") }')
    if [ "$ran" = "no" ]; then
      verdict="reversal"
      detail="$last_user"
    fi
  fi
}
clause_unevidenced_reversal

ev_mode=$(cc_option CC_EVIDENCE_GATE block)
# An edit to a prose file (.md, .txt, .rst, .adoc and kin), by Edit or by Bash, does not arm clause 3: no command's failure proves a README wrong.
PROSE_EXTS='md|mdx|markdown|txt|rst|adoc|asciidoc'

# One line per command list of <command>, heredoc bodies dropped, LAST first: R when a pipeline element's command word runs
# something (pytest | tee log, pytest > out.json), - when every word only writes, moves or announces files, a tab, then the text.
bash_command_units() {
  cc_strip_heredoc_bodies all "$1" | LC_ALL=C awk '
    function runs(s,   n, w, i, x, sk) {
      n = split(s, w, /[ \t]+/); sk = 0
      for (i = 1; i <= n; i++) {
        x = w[i]; sub(/^[({!]+/, "", x); sub(/[)}]+$/, "", x)
        if (x == "") continue
        if (sk) { sk = 0; continue }
        if (x ~ /^[0-9]*[<>]/) { if (x ~ /^[0-9]*[<>]+[&|]?$/) sk = 1; continue }
        if (x ~ /^-/ || x ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || x ~ /^(then|do|else|elif|if|while|until|time|sudo|command|env|nohup)$/) continue
        return x !~ /^(cat|tee|echo|printf|sed|perl|cp|mv|rm|ln|mkdir|touch|chmod|cd|pushd|popd|true|:|fi|done|esac)$/
      }
      return 0
    }
    {
      line = $0; m = ""; q = ""; esc = 0
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (esc) { m = m "_"; esc = 0; continue }
        if (q == "") { if (c == "\\") { esc = 1; m = m "_"; continue }; if (c == "\047" || c == "\"") q = c; m = m c }
        else if (c == q) { q = ""; m = m c }
        else { if (q == "\"" && c == "\\") esc = 1; m = m "_" }
      }
      st = 1; es = 1; r = 0
      for (i = 1; i <= length(m) + 1; i++) {
        c = substr(m, i, 1); c2 = substr(m, i, 2)
        if (i > length(m) || c == ";" || c2 == "&&" || c2 == "||" || c == "&" && c2 != "&>" && substr(m, i - 1, 1) !~ /[<>]/) {
          if (runs(substr(m, es, i - es))) r = 1
          if (substr(m, st, i - st) ~ /[^ \t]/) u[++nu] = (r ? "R" : "-") "\t" substr(line, st, i - st)
          if (c2 == "&&" || c2 == "||") i++
          st = i + 1; es = st; r = 0
        } else if (c == "|") {
          if (runs(substr(m, es, i - es))) r = 1
          if (c2 == "|&") i++
          es = i + 1
        }
      }
    }
    END { for (k = nu; k >= 1; k--) print u[k] }'
}

# Status 0 when <command> writes a non-prose file and nothing runs after that write in it: a write-then-run command
# (cat > t.py <<EOF … EOF && pytest) clears itself, because the clause already takes any later run as evidence.
bash_call_edits() {
  local flag text
  case "$1" in *'>'* | *tee* | *sed* | *perl*) ;; *) return 1 ;; esac
  while IFS=$'\t' read -r flag text; do
    [ "$flag" = R ] && return 1
    [ -n "$text" ] && cc_bash_write_targets "$text" | LC_ALL=C grep -qviE "\\.($PROSE_EXTS)\$" && return 0
  done <<EOF_UNITS
$(bash_command_units "$1")
EOF_UNITS
  cc_bash_write_targets "$1" | LC_ALL=C grep -qviE "\\.($PROSE_EXTS)\$"
}

clause_naked_completion() {
  [ -z "$verdict" ] && [ -n "$tail_jsonl" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "evidence" ] && [ "$ev_mode" != "off" ] || return 0
  # grep -w, not \b: BSD grep has no \b, and an unanchored 'done' would match 'abandoned'.
  said=$(printf '%s' "$tail_jsonl" \
    | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null \
    | tail -"$CLAIM_WINDOW_LINES")
  CLAIM='done|complete|completed|finished|implemented|fixed|resolved|verified|passes|passing|works now|working now|should work|all set|good to go'
  # ACK must state this turn's verification state: a failure named as the thing fixed stays part of the claim.
  ACK='not tested|untested|unverified|not verified|did not (run|rerun)|didn.t (run|rerun)|have not (run|rerun)|haven.t (run|rerun)|not (run|rerun) yet|cannot verify|could not verify|not green|still fail(ing|s)?|currently fail(ing|s)?|(tests?|suite|build|lint|checks?|it) (is|are|was|were) (still |currently )?fail(ing|ed|s)?|(tests?|suite|build|lint|checks?|it) (still |currently )?fail(ing|ed|s)?|fail(ing|s) (with|on|because|due)|in progress|still working|wip|not done|incomplete|halt|halting|halted|blocked|parked|known issue|please verify|verify manually|left to do|remains to'
  if [ -n "$said" ] && printf '%s' "$said" | grep -qiwE "$CLAIM" && ! printf '%s' "$said" | grep -qiwE "$ACK"; then
    # Each Bash call's command follows its entry's names as a JSON string line; only the last Bash call can be the last edit or run, so only it is read.
    ev=$(printf '%s' "$tail_jsonl" \
      | jq -r 'select(.type=="assistant")
               | [.message.content[]? | select(.type=="tool_use")] as $u
               | ([$u[] | .name + (if (.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$|apply_patch$|create_new_file$"))
                             then "@" + ((.input.file_path // "") | ascii_downcase | (if test("\\.[a-z0-9]+$") then sub(".*\\."; "") else "" end))
                             else "" end)]
                  | join(" ")),
                 ($u[] | select(.name == "Bash") | (.input.command // "") | tostring | tojson)' 2>/dev/null \
      | awk -v prose="$PROSE_EXTS" '
          /^"/ { cmd = $0; next }
          { for (i = 1; i <= NF; i++) { n++
              if ($i ~ /^(Edit|Write|MultiEdit|NotebookEdit)(@|$)/ && $i !~ ("@(" prose ")$")) last_edit = n
              if ($i ~ /^(Agent|Task)$/)   last_exec = n
              if ($i == "Bash")            last_bash = n } }
          END {
            if (last_bash > last_edit && last_bash > last_exec) { print "bash"; print cmd; exit }
            if (last_bash > last_exec)    last_exec = last_bash
            if (!last_edit)               print "no-edits"
            else if (last_exec > last_edit) print "evidence"
            else                          print "naked-claim" }')
    case "$ev" in
      bash$'\n'*) if bash_call_edits "$(printf '%s' "${ev#bash$'\n'}" | jq -r '.' 2>/dev/null)"; then ev=naked-claim; else ev=evidence; fi ;;
      bash) ev=evidence ;;
    esac
    if [ "$ev" = "naked-claim" ]; then
      verdict="evidence"
      detail="$said"
    fi
  fi
}
clause_naked_completion

# Armed only by a dependency-shaped change; the $skip test is load-bearing, as in clauses 1-3, or the clause re-fires on its own continuation.
clause_lockfile_drift() {
  [ -z "$verdict" ] && [ "$evt" != "SubagentStop" ] && [ "$skip" != "lockfile" ] && [ "$(cc_option CC_LOCKFILE_GATE on)" != "off" ] || return 0
  if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    changed=$(git -C "$root" status --porcelain 2>/dev/null | awk '{print $NF}')
    if [ -n "$changed" ]; then
      lock_detail=""
      while IFS='|' read -r man locks; do
        printf '%s\n' "$changed" | grep -qx "$man" || continue
        # JSON manifests compare parsed dependency maps: a one-line package.json puts version and dependencies on one diff line.
        case "$man" in
          package.json|composer.json)
            head_deps=$(git -C "$root" show "HEAD:$man" 2>/dev/null \
              | jq -cS '{d:(.dependencies//{}),dd:(.devDependencies//{}),p:(.peerDependencies//{}),o:(.optionalDependencies//{}),r:(.require//{}),rd:(."require-dev"//{})}' 2>/dev/null)
            work_deps=$(jq -cS '{d:(.dependencies//{}),dd:(.devDependencies//{}),p:(.peerDependencies//{}),o:(.optionalDependencies//{}),r:(.require//{}),rd:(."require-dev"//{})}' "$root/$man" 2>/dev/null)
            # Unparseable on either side: fall through to the line test, never a silent allow.
            if [ -n "$head_deps" ] && [ -n "$work_deps" ]; then
              [ "$head_deps" = "$work_deps" ] && continue
            else
              git -C "$root" diff -U0 -- "$man" 2>/dev/null | grep -qE '^[+-].*"(dependencies|devDependencies|peerDependencies|optionalDependencies|require|require-dev)"' || continue
            fi
            ;;
          *)
            # A dependency line, not any line; TOML metadata keys are excluded by name because a line cannot see its table.
            meta_re='^[+-][[:space:]]*(version|name|description|readme|license|authors|maintainers|homepage|repository|documentation|keywords|classifiers|requires-python|edition|rust-version|publish|include|exclude|packages|scripts|urls)[[:space:]]*='
            case "$man" in
              pyproject.toml)
                dep_re='^[+-][[:space:]]*("[^"]+"[[:space:]]*,?[[:space:]]*$|[A-Za-z0-9._-]+[[:space:]]*=[[:space:]]*[{"^~>=<*]|dependencies[[:space:]]*=|\[(tool\.poetry\.(dev-)?dependencies|project\.optional-dependencies|build-system)\])' ;;
              Gemfile)
                dep_re='^[+-][[:space:]]*(gem[[:space:]]|gemspec|source[[:space:]]|git[[:space:]]|path[[:space:]])'
                meta_re='^$' ;;
              Cargo.toml)
                dep_re='^[+-][[:space:]]*([A-Za-z0-9._-]+[[:space:]]*=[[:space:]]*[{"^~>=<*]|\[(dependencies|dev-dependencies|build-dependencies|workspace\.dependencies)\])' ;;
              go.mod)
                dep_re='^[+-][[:space:]]*(require|replace|exclude|retract)?[[:space:]]*[a-z0-9.-]+\.[a-z]{2,}/'
                meta_re='^[+-][[:space:]]*(module|go|toolchain)[[:space:]]' ;;
              *)
                dep_re='^[+-]'
                meta_re='^$' ;;
            esac
            git -C "$root" diff -U0 -- "$man" 2>/dev/null \
              | grep -E "$dep_re" 2>/dev/null | grep -qvE "$meta_re" || continue
            ;;
        esac
        satisfied=0
        for l in $locks; do printf '%s\n' "$changed" | grep -qx "$l" && satisfied=1; done
        [ "$satisfied" -eq 1 ] && continue
        [ -n "$lock_detail" ] && lock_detail="$lock_detail, "
        lock_detail="$lock_detail$man (expected one of: $(printf '%s' "$locks" | tr ' ' '/'))"
      done <<'MANIFESTS'
package.json|package-lock.json npm-shrinkwrap.json yarn.lock pnpm-lock.yaml bun.lock bun.lockb
composer.json|composer.lock
Gemfile|Gemfile.lock
pyproject.toml|poetry.lock uv.lock pdm.lock requirements.txt
Cargo.toml|Cargo.lock
go.mod|go.sum
MANIFESTS
      if [ -n "$lock_detail" ]; then
        verdict="lockfile"
        detail="$lock_detail"
      fi
    fi
  fi
}
clause_lockfile_drift

[ -n "$verdict" ] || pass_turn

report_verdict() {
  mode="$gate_mode"
  case "$verdict" in
    evidence) case "$ev_mode" in warn) mode=warn ;; esac ;;
  esac

  # Loop guard: one block per clause and final text, a line per clause, so two clauses on one unchanged text cannot take turns.
  marker="$state_dir/last$agent_sfx"
  state=$(printf '%s|%s' "$verdict" "$detail$last_msg" | (command -v shasum >/dev/null 2>&1 && shasum | cut -d' ' -f1 || cksum | cut -d' ' -f1))
  if [ -r "$marker" ] && grep -qxF "$verdict $state" "$marker" 2>/dev/null; then
    pass_turn
  fi
  if ! { mkdir -p "$state_dir" 2>/dev/null && { [ -e "$state_dir/.gitignore" ] || printf '*\n' > "$state_dir/.gitignore" 2>/dev/null || :; } \
         && { grep -v "^$verdict " "$marker" 2>/dev/null; printf '%s %s\n' "$verdict" "$state"; } > "$marker.$$" 2>/dev/null \
         && mv -f "$marker.$$" "$marker" 2>/dev/null; }; then
    # No marker, no per-text bound: honour the shared flag here only, so unwritable state cannot block the same turn forever.
    [ "$sha_active" = "true" ] && pass_turn
  fi

  if [ "$mode" = "block" ]; then
    mkdir -p "$state_dir" 2>/dev/null && printf '%s' "$verdict" > "$claimed" 2>/dev/null
  fi

  local msg note
  case "$verdict" in
    citation)
      what="This turn"; [ "$evt" = "SubagentStop" ] && what="This report"
      msg=$(printf '[candor] %s cites a location that does not exist.%s\n' "$what" "$detail"
        printf '  Open the file and cite what is there, or drop the line number and say you are inferring, not quoting.\n'
        # A subagent that re-sent only the correction lost its whole report: the caller receives the last hand-back alone.
        [ "$evt" = "SubagentStop" ] && printf '  Then re-send your COMPLETE report, corrected: only your last message reaches the caller.\n'
        printf '  CC_CANDOR_GATE=off turns this check off (=warn only prints).\n')
      note="candor sent the turn back: the reply cites a file:line that does not exist." ;;
    quote)
      what="This turn"; [ "$evt" = "SubagentStop" ] && what="This report"
      msg=$(printf '[candor] %s quotes code that is not in the file it cites.%s\n' "$what" "$detail"
        printf '  Read: the text from `quote: ` to the next backtick (doubled backticks hold one), whitespace ignored, searched in the whole\n'
        printf '  file, its HEAD copy, and the tool output and user turns of this transcript; quoting another file needs its own path:line.\n'
        printf '  Fix the quote, or write `was:` for code the change removed.\n'
        [ "$evt" = "SubagentStop" ] && printf '  Then re-send your COMPLETE report, corrected: only your last message reaches the caller.\n'
        printf '  CC_CANDOR_GATE=off turns the whole gate off (=warn only prints).\n')
      note="candor sent the turn back: the reply quotes code that is not in the file it cites." ;;
    reversal)
      msg=$(printf '[candor] The user pushed back with no new information, and this turn retracts your position anyway without re-checking anything.\n'
        printf '  Re-check (run the command or read the file that settles it, then report what it showed), or keep your position and say why.\n'
        printf '  CC_CANDOR_GATE=off turns this check off (=warn only prints).\n')
      note="candor sent the turn back: the reply took back its answer after pushback without re-checking anything." ;;
    lockfile)
      msg=$(printf '[candor] A dependency manifest changed and its lockfile did not: %s.\n' "$detail"
        printf '  Run the installer (npm/pnpm/yarn install, composer update <pkg>, bundle install, cargo build, go mod tidy) and keep\n'
        printf '  the lockfile with the manifest, or say why the lockfile stays unchanged. CC_LOCKFILE_GATE=off turns this check off.\n')
      note="candor sent the turn back: a dependency manifest changed and its lockfile did not." ;;
    evidence)
      msg=$(printf '[candor] This turn says the work is done, but no command ran after the last edit.\n'
        printf '  Run the check that would fail if the change were broken (a test, build, lint, or the changed code) and show its\n'
        printf '  output, or say what changed, what was not verified, and the command the user can run to verify it.\n'
        printf '  CC_EVIDENCE_GATE=off turns this check off (=warn only prints).\n')
      note="candor sent the turn back: the reply says the work is done, but nothing ran after the last edit." ;;
  esac

  [ "$mode" = "block" ] || { printf '%s\n' "$msg" >&2; pass_turn; }
  # A blocked subagent keeps running: put back the in-flight record removed above.
  if [ -n "$inflight_rec" ]; then
    printf '%s\n' "$agent_id" > "$inflight_rec" 2>/dev/null
  fi
  block_turn "$msg" "$note"
}
report_verdict
