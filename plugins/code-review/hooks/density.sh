#!/bin/bash
# Comment-volume guard: PreToolUse denies a Write or truncating cat/tee heredoc over the prose:code ceiling (twice per file per session); PostToolUse warns (3 per session) past min(2x sibling median, ceiling).
# Misses: interface and all-abstract files, sed -i/perl -i/printf text, Bash targets past 3, the fan-out aggregate; a ratio is not a judgment. Fails open. Off: CC_COMMENT_GUARD (deny), CC_REMIND (warn).
# Why, limits, history: rationale/derivations/plugin-code-review.md § plugins/code-review/hooks/density.sh

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
  command -v jq  >/dev/null 2>&1 || exit 0
  command -v awk >/dev/null 2>&1 || exit 0
  MAX_BASH_EFFECTS=8   # changed files listed after an interpreter, cp, mv, install or patch run, in git's path order

  input=$(cat)
  # A failed Bash call's PostToolUseFailure takes the PostToolUse lane; its envelope names the event it ran for (hev).
  event=""; sess=""
  { IFS= read -r event; IFS= read -r sess; } < <(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse", .session_id // ""' 2>/dev/null)
  hev=PostToolUse; [ "$event" = PostToolUseFailure ] && { hev=$event; event=PostToolUse; }
  case "$event" in PostToolUse|PreToolUse) ;; *) exit 0 ;; esac
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  # Only a whole file has a ratio: a Write carries one, and so does a truncating Bash heredoc.
  [ "$event" = "PreToolUse" ] && [ "$tool" != "Write" ] && [ "$tool" != "Bash" ] && exit 0
  case "$tool" in Edit|Write|MultiEdit|Bash) ;; *) exit 0 ;; esac
  [ "$tool" = Bash ] && { cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0; }
  # WARN lane only — see scan.sh's note; the PreToolUse deny ignores this switch.
  [ "$event" = "PostToolUse" ] && [ "$(cc_option CC_REMIND on)" = "off" ] && exit 0
  # Read effects with the old marker, then date it on every call this lane sees, or an Edit's file reads as the next run's write.
  effects=""; root=""
  if [ "$event" = "PostToolUse" ]; then
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    if [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(cc_state_root "$cwd"); then
      emark="$(cc_plugin_state "$root" comment-discipline)/bash-effects-density.mark"
      [ "$tool" = Bash ] && effects=$(cc_bash_write_effects "$root" "$emark" "$cmd" "$MAX_BASH_EFFECTS" "$sess")
      cc_bash_effects_mark "$root" "$emark" "$sess"
    fi
  fi
  case "$tool" in
    Edit|Write|MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0 ;;
    Bash)
      # Same guard as scan.sh: the blocks are quadratic in the length of one line, so such a command's text is not parsed.
      tgts=""
      [ "${#cmd}" -gt 32768 ] && printf '%s\n' "$cmd" | awk 'length($0) > 2000 { s += length($0) } length($0) > 8192 || s > 32768 { f = 1; exit } END { exit !f }' \
        || tgts=$(cc_bash_write_targets "$cmd")
      [ -n "$tgts" ] || [ -n "$effects" ] || exit 0 ;;
  esac
  # Sourced only here, below the exit of a Bash call that writes nothing; without the file nothing is governed.
  . "$(dirname "$0")/paths.sh" 2>/dev/null
  if [ "$tool" = Bash ]; then
    gov=0
    while IFS= read -r t; do cd_governed "$t" && gov=1; done <<EOF_G
$tgts
$effects
EOF_G
    [ "$gov" = 1 ] || exit 0
  else
    cd_governed "$fp" || exit 0
  fi
  # CC_COMMENT_GUARD=off disables the DENY lane and leaves the advisory lane on.
  [ "$event" = "PreToolUse" ] && [ "$(cc_option CC_COMMENT_GUARD on)" = "off" ] && exit 0

  if [ "$tool" = Bash ] && [ "$event" = "PreToolUse" ]; then
    chunks=$(cc_bash_write_chunks "$cmd")
    [ -n "$chunks" ] || exit 0
    nc=0; k=0
    while IFS= read -r l; do
      [ "$nc" -lt 40 ] || break   # 400 one-line heredocs to .sh files took 11 s against a 10 s timeout
      k=$((k + 1)); tgt=$(cc_bash_write_targets "${l#?}" | head -n 1)
      [ -n "$tgt" ] && cd_governed "$tgt" && cd_lang "$tgt" || continue
      # Only a chunk the judge below could refuse is kept, so the cap counts no echo, append or build file.
      case "$cd_lang_key" in dockerfile|make) continue ;; esac
      [ "$(cd_chunk_mode "${l#?}")" = truncate ] || continue
      nc=$((nc + 1)); ctgt[$nc]=$tgt; chdr[$nc]=${l#?}; cnum[$nc]=$k
    done <<EOF_C
$(printf '%s\n' "$chunks" | awk 'substr($0, 1, 1) == "\036"')
EOF_C
    [ "$nc" -gt 0 ] || exit 0
  fi

  [ "$event" = "PostToolUse" ] || cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  # Keyed on the context (transcript_path first), not the session: a subagent shares its parent's session_id.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  # -d too: a session outlives its directories. State sits at the state root, shared with verbosity.sh and scan.sh; re-rooting one alone splits a bound.
  [ -n "$cwd" ] && [ -d "$cwd" ] && [ -n "$sid" ] || exit 0
  [ -n "$root" ] || root=$(cc_state_root "$cwd") || exit 0

  # The floor counts substantive lines, not code lines: a code floor waves through a file that is mostly comment.
  MIN_LINES=50       # comment + code; a file under this, or under MIN_CODE, gets the short rule
  MIN_CODE=8         # enough denominator for a ratio to carry information
  MIN_SIBLINGS=3     # a median of two files is not a house style
  SAMPLE_CAP=25      # bounded cost: this runs after every edit
  MULT=20            # 2.0x, in tenths (integer arithmetic only)
  FLOOR=3            # 0.3, in tenths — absolute lower bound on "outlier"
  CEIL=${COMMENT_DISCIPLINE_CEILING_TENTHS:-3}   # 0.3, in tenths; 0 switches the ceiling off
  case "$CEIL" in ''|*[!0-9]*) CEIL=3 ;; esac
  CEIL=${CEIL#"${CEIL%%[!0]*}"}   # leading zeros dropped: $(( )) would read them as octal
  [ "${#CEIL}" -le 4 ] || CEIL=10000   # past 1000:1 there is no limit, and a longer value overflows the compare
  CEIL=$((10#${CEIL:-0}))
  SHORT_LIMIT=$CEIL; [ "$SHORT_LIMIT" -ge 10 ] || SHORT_LIMIT=10   # 1:1, or the ceiling once a project raised it past that
  MAX_WARN=3

  density_regime() { # <prose> <comment> <code>
    d_regime=ratio
    [ "$(( $2 + $3 ))" -ge "$MIN_LINES" ] && [ "$3" -ge "$MIN_CODE" ] && return 0
    d_regime=short
    [ "$1" -ge 5 ] && [ "$3" -ge 1 ] && [ "$CEIL" -gt 0 ]
  }
  # The printed ratio is rounded up, so a file over its limit never prints the limit's own number.
  density_over() { # <prose> <code> <limit, in tenths>
    d_ratio=$(( ($1 * 10 + $2 - 1) / $2 ))
    [ "$3" -gt 0 ] && [ "$(( $1 * 10 ))" -gt "$(( $3 * $2 ))" ]
  }
  # Not judged: declarations only, with an interface, abstract class or protocol and no body; read a line at a time, since joining is quadratic under mawk.
  density_contract() { # text on stdin
    case "$lang" in php|ts|tsx|java|kt|kts|cs|swift|go|scala|dart|groovy) ;; *) return 1 ;; esac
    awk -v lang="$lang" '
      BEGIN {
        M = "^((export|public|protected|private|internal|sealed|declare|default)[ \t]+)*"
        DECL = M "(interface|abstract[ \t]+class|protocol)[ \t]+[A-Za-z_$]|^type[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]+interface([^A-Za-z0-9_]|$)"
        NS = M "(namespace|module|global)([ \t][^;{]*)?[{]?$"
        TYPE = M "(type[ \t]+[A-Za-z_$][^=]*=|(const[ \t]+)?enum[ \t]+[A-Za-z_$]|declare[ \t])"
        PRE = "^(<[?]|[?]>|(namespace|package|import|use|using|library|part|export[ \t]+([*]|type[ \t]*[{]|[{]))([ \t({]|$)|declare[ \t]*[(]|@|[[]|export[ \t]+default[ \t]+[A-Za-z_$][A-Za-z0-9_$.]*;?$|[]});,]+$)"
        MORE = "^([{|&:,]|(extends|implements|where)([ \t]|$)|[A-Za-z_$][A-Za-z0-9_$.\\\\]*(<[^>]*>)?[ \t]*[,{]?$)"
        BODY = "[)][^;{}()]*[{]|[)][^;{}()=]*=($|[^=>])|(^|[^A-Za-z0-9_$.])(get|set|init)[ \t]*([{]|=>)|[ \t]static[ \t]*[{]" (lang ~ /^(cs|dart)$/ ? "|=>" : "")
      }
      { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t) }
      blk { if (index(t, "*/")) blk = 0; next }
      t ~ /^\/\*/ { if (!index(substr(t, 3), "*/")) blk = 1; next }
      t == "" || t ~ /^(\/\/|\*|#)/ { next }
      {
        s = t; gsub(/"([^"\\]|\\.)*"|\047([^\047\\]|\\.)*\047/, "\"\"", s); sub(/[ \t]*\/\/.*$/, "", s)
        k = dn ? K[dn] : ""; fresh = 0
        if (pend != "" && s !~ MORE) pend = ""
        if (pend != "") kind = pend
        else if (k == "c" || k == "p") kind = k
        else if (imp) { kind = "p"; if (s ~ /^[)]/) imp = 0 }
        else if (s ~ DECL) { kind = "c"; decl = fresh = 1 }
        else if (s ~ NS) { kind = "n"; fresh = 1 }
        else if (s ~ TYPE) { kind = "c"; fresh = 1 }
        else if (s ~ PRE) { kind = "p"; if (s ~ /^import[ \t]*[(]$/) imp = 1 }
        else { no = 1; exit }
        if (kind == "c") { u = cr " " s; if (u ~ BODY) { no = 1; exit }; cr = (u ~ /[)][^;{}()]*$/) ? ")" : "" } else cr = ""
        o = gsub(/[{]/, "{", s); c = gsub(/[}]/, "}", s)
        if (fresh && !o && s !~ /;$/) pend = kind
        for (; o > c; o--) { K[++dn] = kind; pend = "" }
        for (; c > o && dn > 0; c--) dn--
      }
      END { exit !(decl && !no) }' 2>/dev/null
  }
  # d_added: prose lines an Edit adds (each new_string swapped back to its old_string), a Bash write's text adds, or an effect adds over its HEAD copy.
  density_added() { # [<text a Bash command wrote>] -> d_added, a signed count
    local a="" b k=0 o n r x after before f='def frag(k): [(.tool_input.edits // [.tool_input])[] | (.[k] // "") | (if test("^\\s*\\*(\\s|$)") then "/*\n" else "" end) + . + "\n*/"] | join("\n");'
    d_added=""
    if [ "$mode" = effect ]; then
      [ "$(wc -c < "$fp")" -le 262144 ] 2>/dev/null || return 1
      a=$(cd_classify "$lang" "$fp"); b=$(git -C "$root" show "HEAD:${fp#"$root"/}" 2>/dev/null | cd_classify "$lang")
    elif [ "$tool" = Bash ]; then a=$(printf '%s\n' "$1" | cd_classify "$lang"); b=0
    else
      if [ "$(wc -c < "$fp")" -le 262144 ] 2>/dev/null && after=$(cat "$fp" && printf x); then
        before=${after%x}; after=$before
        while IFS= read -r -d '' o && IFS= read -r -d '' n && IFS= read -r -d '' r; do
          if [ "$r" = 1 ]; then x=${before//"$n"/"$o"}; else x=${before/"$n"/"$o"}; fi
          [ -n "$n" ] && [ "$x" != "$before" ] || { k=0; break; }
          before=$x; k=$((k + 1))
        done < <(printf '%s' "$input" | jq -j '(.tool_input.edits // [.tool_input]) | reverse | .[] |
          (.old_string // "" | tostring), "\u0000", (.new_string // "" | tostring), "\u0000", (if .replace_all == true then 1 else 0 end), "\u0000"' 2>/dev/null)
        [ "$k" -gt 0 ] && a=$(printf '%s' "$after" | cd_classify "$lang") && b=$(printf '%s' "$before" | cd_classify "$lang")
      fi
      if [ "$k" = 0 ]; then
        a=$(printf '%s' "$input" | jq -r "$f"' frag("new_string")' 2>/dev/null | cd_classify "$lang")
        b=$(printf '%s' "$input" | jq -r "$f"' frag("old_string")' 2>/dev/null | cd_classify "$lang")
      fi
    fi
    a=${a%% *}; b=${b%% *}
    case "${a:-x}${b:-x}" in *[!0-9]*) return 1 ;; esac
    d_added=$((a - b))
  }

  density_judge() {
  fp=$1 text=$2 mode=$3 msg=""
  [ -n "$fp" ] || return 1
  cd_governed "$fp" || return 1
  if [ "$event" = "PostToolUse" ]; then [ -f "$fp" ] && [ -r "$fp" ] || return 1; fi
  # Same path exclusions as scan.sh, on the same logical path; a missing paths.sh judges nothing.
  command -v cd_path_exempt >/dev/null 2>&1 || return 1
  cd_path_exempt "$fp" "$root" && return 1
  cd_lang "$fp" || return 1
  lang=$cd_lang_key
  # A comment per instruction is idiomatic in a build file; scan.sh still reads them.
  case "$lang" in dockerfile|make) return 1 ;; esac
  # A generator redirected to a file (`gen > src/api.ts`) leaves its marker on disk, not in the command.
  [ "$event" = "PostToolUse" ] && [ "$tool" = Bash ] && cd_generated < "$fp" && return 1

  dir=$(cc_plugin_state "$root" comment-discipline)
  # Hashed: .transcript_path is an absolute path, and raw it names a file whose parents never exist, so no bound engages.
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || return 1
  state="$dir/density-$ctx"
  # A bound that cannot be recorded is not a bound: unwritable state means this hook does nothing.
  mkdir -p "$dir" 2>/dev/null || return 1
  [ -w "$dir" ] || return 1
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null   # the state dir ignores itself

  # PreToolUse lane: deny a whole new file over CEIL, at most twice per file; a deny whose marker cannot land is withheld.
  if [ "$event" = "PreToolUse" ]; then
    [ "$mode" = truncate ] || return 1
    [ "$CEIL" -gt 0 ] || return 1
    content=$text
    [ -n "$content" ] || return 1
    printf '%s\n' "$content" | cd_generated && return 1
    read -r pprose pc pcode <<EOF
$(printf '%s\n' "$content" | cd_classify "$lang")
EOF
    case "${pprose:-x} ${pc:-x} ${pcode:-x}" in *[!0-9\ ]*) return 1 ;; esac
    density_regime "$pprose" "$pc" "$pcode" || return 1
    limit=$CEIL; [ "$d_regime" = short ] && limit=$SHORT_LIMIT
    density_over "$pprose" "$pcode" "$limit" || return 1
    printf '%s\n' "$content" | density_contract && return 1
    key=$(printf '%s' "$fp" | (command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
    [ -n "$key" ] || return 1
    marker="$dir/density-blocked-$ctx-$key"
    # Two tries, not one: a sibling hook's deny can block the write a try was spent on.
    DENY_CAP=2
    # A noclobber file per try (O_CREAT|O_EXCL), not mkdir(1); an old .dN dir or zero-byte marker counts as a try. Two co-firing denies can spend both.
    tries=0
    [ -e "$marker" ] && tries=1
    i=1
    while [ "$i" -le "$DENY_CAP" ]; do [ -e "$marker.d$i" ] && tries=$i; i=$((i + 1)); done
    [ "$tries" -ge "$DENY_CAP" ] && return 1
    # The name goes through the environment: macOS awk refuses a -v value holding a newline.
    msg=$(file_name="${fp##*/}" LC_ALL=C awk -v c="$pprose" -v cd="$pcode" -v r="$d_ratio" -v l="$limit" \
      'BEGIN { f = ENVIRON["file_name"]; printf "comment-discipline: %s would be %.1f:1 comment-to-code (%d comment lines, %d code); the ceiling is %.1f:1. Write it again with the code carrying the meaning: keep only a why-this-not-the-obvious, an external constraint with a link, a deliberate no-op, or a contract fact the signature cannot state (units, ownership, what throws, required call order) — and move the rest to a name, a type, or a test. A project that states a heavier house style sets COMMENT_DISCIPLINE_CEILING_TENTHS in its settings env (5 for 0.5:1). Blocked at most twice per file; after that a write goes through with a warning instead. CC_COMMENT_GUARD=off disables this block for the session (CC_REMIND=off silences the warning it falls back to).", f, r/10, c, cd, l/10 }')
    [ -n "$msg" ] || return 1
    ( set -C; : > "$marker.d$((tries + 1))" ) 2>/dev/null || return 1
    return 0
  fi

  warned=0
  if [ -r "$state" ]; then
    warned=$(grep -c '^warn ' "$state" 2>/dev/null) || warned=0
    case "$warned" in ''|*[!0-9]*) warned=0 ;; esac
    [ "$warned" -ge "$MAX_WARN" ] && return 1
    grep -qxF "file $fp" "$state" 2>/dev/null && return 1   # already reported this file
  fi
  # A Write keeps the whole-file ratio; an Edit or Bash write is judged once it adds prose, or when its text is unreadable (mode whole).
  if [ "$tool" != Write ] && [ "$mode" != whole ]; then density_added "$text" && [ "$d_added" -gt 0 ] 2>/dev/null || return 1; fi

  read -r fprose fc fcode <<EOF
$(cd_classify "$lang" "$fp")
EOF
  case "${fprose:-x} ${fc:-x} ${fcode:-x}" in *[!0-9\ ]*) return 1 ;; esac
  density_regime "$fprose" "$fc" "$fcode" || return 1
  if [ "$d_regime" = short ]; then density_over "$fprose" "$fcode" "$SHORT_LIMIT" || return 1; fi
  density_contract < "$fp" && return 1

  # Baseline: same-language siblings, nearest directory first, cached per directory per session.
  fdir=$(dirname "$fp")
  # Resolved once: the walk's root bound and the ledger must agree, and git reports symlink-free paths.
  rdir=$(cd "$fdir" 2>/dev/null && pwd -P) || rdir="$fdir"
  rfp="$rdir/$(basename "$fp")"
  key=$(printf '%s' "$fdir/$lang" |(command -v shasum >/dev/null 2>&1 && shasum || cksum) 2>/dev/null | cut -d' ' -f1)
  base=""
  [ -n "$key" ] && base=$(awk -v k="$key" '$1=="base" && $2==k {print $3}' "$state" 2>/dev/null | tail -1)

  if [ -z "$base" ]; then
    # Siblings are files git tracks, minus this session's writes, so a fan-out never baselines on its own output; without git, find.
    sibs_from() { # $1 dir, $2 maxdepth
      local d="$1" depth="$2" rel
      # A superset by name, then cd_lang decides: `*.php` also lists Blade files.
      case "$lang" in
        blade) set -- '*.blade.php' ;;
        *) set -- "*.$lang" ;;
      esac
      if command -v git >/dev/null 2>&1 && git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # -z: without it git C-quotes a name holding a quote, a backslash or a non-ASCII byte.
        git -C "$d" ls-files -z -- "$@" 2>/dev/null | while IFS= read -r -d '' rel; do
          case "$rel" in */*/*) [ "$depth" -ge 2 ] || continue ;; esac
          printf '%s/%s\n' "$d" "$rel"
        done
      else
        find "$d" -maxdepth "$depth" -type f -name "$1" 2>/dev/null
      fi | while IFS= read -r rel; do
        cd_lang "$rel" && [ "$cd_lang_key" = "$lang" ] && [ -f "$rel" ] && printf '%s\n' "$rel"   # a name holding a newline splits into pieces that are no file
      done
    }
    pick() { # $1 dir, $2 maxdepth — tracked siblings minus this file minus this run's writes
      sibs_from "$1" "$2" | while IFS= read -r s; do
        case "$s" in "$fp"|"$rfp") continue ;; esac
        grep -qxF "file $s" "$state" 2>/dev/null && continue
        printf '%s\n' "$s"
      done | head -n "$SAMPLE_CAP"
    }
    # Walk up at most 4 levels, never past the repo root (unrelated code is no baseline); both sides go through pwd -P, as macOS /var is /private/var.
    top=""
    if command -v git >/dev/null 2>&1; then
      top=$(cd "$rdir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)
    fi
    [ -n "$top" ] || top=$(cd "$root" 2>/dev/null && pwd -P) || top="$root"

    sibs=""; n=0; d="$rdir"; depth=1; up=0
    while [ "$up" -lt 4 ]; do
      case "$d" in "$top"|"$top"/*) ;; *) break ;; esac
      sibs=$(pick "$d" "$depth")
      n=$(printf '%s\n' "$sibs" | grep -c . )
      [ "$n" -ge "$MIN_SIBLINGS" ] && break
      parent=$(dirname "$d")
      [ "$parent" = "$d" ] && break
      d="$parent"; depth=$((depth + 1)); up=$((up + 1))
    done
    # Median, not mean: one dense interface file must not set the house style; no usable siblings leaves the ceiling alone.
    if [ "$n" -ge "$MIN_SIBLINGS" ]; then
      # One awk for every sibling; a tracked file that is gone from disk would make awk exit with nothing read.
      base=$(set --
             while IFS= read -r s; do [ -f "$s" ] && [ -r "$s" ] && set -- "$@" "$s"; done <<EOS
$sibs
EOS
             [ "$#" -gt 0 ] || exit 0
             # One find for the whole set, -L so a tracked symlink is sized by its target; the size cap keeps the classifier inside the timeout.
             kept=$(find -L "$@" -size -262145c 2>/dev/null); set --
             while IFS= read -r s; do [ -n "$s" ] && set -- "$@" "$s"; done <<EOS
$kept
EOS
             [ "$#" -ge "$MIN_SIBLINGS" ] || exit 0
             cd_classify "$lang" "$@" | awk '$3 >= 10 { print int(($1 * 10 + $3 - 1) / $3) }' |
               sort -n | awk '{v[NR]=$1} END{ if (NR==0) exit; print v[int((NR+1)/2)] }')
      case "${base:-}" in ''|*[!0-9]*) base="" ;; esac
      [ -n "$base" ] && [ -n "$key" ] && printf 'base %s %s\n' "$key" "$base" >> "$state" 2>/dev/null
    fi
  fi

  if [ "$d_regime" = short ]; then
    limit="$SHORT_LIMIT"
  elif [ -n "$base" ]; then
    limit=$(( base * MULT / 10 ))
    [ "$limit" -lt "$FLOOR" ] && limit="$FLOOR"
    [ "$CEIL" -gt 0 ] && [ "$limit" -gt "$CEIL" ] && limit="$CEIL"
  else
    [ "$CEIL" -gt 0 ] || return 1
    limit="$CEIL"
  fi
  density_over "$fprose" "$fcode" "$limit"; over=$?

  # Ledger: every measurement, machine-local, capped at 1 MB; nothing reads it back automatically.
  ledger="${HOME:-/tmp}/.claude/comment-discipline/density-ledger.jsonl"
  if [ "$(wc -c < "$ledger" 2>/dev/null || echo 0)" -lt 1048576 ]; then
    mkdir -p "${ledger%/*}" 2>/dev/null &&
      jq -cn --arg s "$sid" --arg f "$fp" --arg e "$lang" --argjson c "$fprose" \
             --argjson cd "$fcode" --argjson r "$d_ratio" --argjson b "${base:--1}" --argjson l "$limit" \
        '{session:$s,file:$f,ext:$e,comment:$c,code:$cd,ratio_tenths:$r,baseline_tenths:$b,limit_tenths:$l,warned:($r>$l)}' \
        >> "$ledger" 2>/dev/null
  fi

  printf 'file %s\n' "$fp" >> "$state" 2>/dev/null
  [ "$rfp" = "$fp" ] || printf 'file %s\n' "$rfp" >> "$state" 2>/dev/null
  [ "$over" = 0 ] || return 1

  msg=$(file_name="${fp##*/}" LC_ALL=C awk -v c="$fprose" -v cd="$fcode" -v r="$d_ratio" -v b="${base:--1}" -v l="$limit" -v n="$((warned + 1))" -v m="$MAX_WARN" \
    'BEGIN {
      f = ENVIRON["file_name"]
      if (b >= 0) printf "comment-discipline: %s is %.1f:1 comment-to-code (%d comment lines, %d code); its siblings run %.1f:1 and the limit here is %.1f:1.", f, r/10, c, cd, b/10, l/10
      else        printf "comment-discipline: %s is %.1f:1 comment-to-code (%d comment lines, %d code); no committed siblings to compare against, so the ceiling of %.1f:1 applies.", f, r/10, c, cd, l/10
      printf " The default is code that needs no comment. If this file genuinely needs the prose (vendor quirks, a protocol the code cannot show), keep it and move on; otherwise keep only why-comments, linked constraints, deliberate no-ops and contract facts the signature cannot state, and move the rest to a name, a type, or a test. Warning %d of %d this session. CC_REMIND=off silences these.", n, m }')
  [ -n "$msg" ] || return 1
  printf 'warn %s\n' "$fp" >> "$state" 2>/dev/null
  return 0
  }

  emit() {
    if [ "$event" = "PreToolUse" ]; then
      jq -cn --arg r "$msg$1" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    else
      jq -cn --arg m "$msg$1" --arg ev "$hev" \
        '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$m}}'
    fi
  }

  if [ "$tool" != Bash ]; then
    content=""
    if [ "$event" = "PreToolUse" ]; then
      content=$(printf '%s' "$input" | jq -r '.tool_input.content // empty' 2>/dev/null) || exit 0
    fi
    density_judge "$fp" "$content" truncate && emit ""
  elif [ "$event" = "PreToolUse" ]; then
    hascd=0; cd_has_cd "$cmd" && hascd=1
    # A file the command writes twice is not one chunk alone. The block de-duplicates its targets, so each kept header's own target is pointed at /dev/null, the rest read once, and a path met twice goes to the disk lane.
    c=1; all=""; pairs=$nc   # c and nc, not `i` and `n`: density_judge assigns both of those
    while [ "$c" -le "$nc" ]; do
      cabs[$c]=""
      cd_resolve "${ctgt[$c]}" "$cwd" "$hascd" && { cabs[$c]=$cd_path; all="$all$cd_path
"; }
      pairs="$pairs
${ctgt[$c]}
${chdr[$c]}"
      c=$((c + 1))
    done
    while IFS= read -r o; do
      cd_resolve "$o" "$cwd" "$hascd" && all="$all$cd_path
"
    done <<EOF_O
$(cc_bash_write_targets "$(printf '%s\n%s\n' "$pairs" "$cmd" | awk '
      NR == 1 { n = $0 + 0; next }
      NR <= 1 + 2 * n { if (NR % 2) H[++b] = $0; else T[++a] = $0; next }
      { while (k < n && (i = index($0, H[k + 1])) && (j = index(H[k + 1], T[k + 1]))) {
          k++; $0 = substr($0, 1, i + j - 2) "/dev/null" substr($0, i + j - 1 + length(T[k])) }
        print }')")
EOF_O
    twice="
$(printf '%s' "$all" | awk 'seen[$0]++ == 1')
"
    c=1
    while [ "$c" -le "$nc" ]; do
      fp=${cabs[$c]}
      case "$twice" in *"
$fp
"*) fp="" ;; esac
      if [ -n "$fp" ] && cd_target_whole "${chdr[$c]}" "${ctgt[$c]}" \
         && density_judge "$fp" "$(cd_chunk_text "$chunks" "${cnum[$c]}")" truncate; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
      c=$((c + 1))
    done
  else
    hascd=0; [ -n "$tgts" ] && cd_has_cd "$cmd" && hascd=1
    # Each chunk's text by its target as spelled: a heredoc body, or echo/printf arguments less redirects, flags and outer quotes; the first 40.
    chunks=""; [ -z "$tgts" ] || chunks=$(cc_bash_write_chunks "$cmd"); k=0; nb=0
    while IFS= read -r l; do
      k=$((k + 1)); [ "$nb" -lt 40 ] || break
      t=$(cc_bash_write_targets "${l#?}" | head -n 1); [ -n "$t" ] || continue
      nb=$((nb + 1)); btgt[$nb]=$t
      case "${l#?}" in
        *'<<'*) btxt[$nb]=$(cd_chunk_text "$chunks" "$k") ;;
        *) btxt[$nb]=$(cd_chunk_text "$chunks" "$k" | awk '{ sub(/^[ \t]+/, "")
             while (sub(/[ \t]*[0-9&]*>>?[ \t]*("[^"]*"|\047[^\047]*\047|[^ \t"\047]+)[ \t]*$/, "")) ;
             sub(/[ \t]+$/, ""); while (sub(/^-[neE]+[ \t]+/, "")) ;
             if ($0 ~ /^["\047]/ && substr($0, length($0)) == substr($0, 1, 1)) $0 = substr($0, 2, length($0) - 2)
             gsub(/\\n/, "\n"); print }') ;;
      esac
    done <<EOF_B
$(printf '%s\n' "$chunks" | awk 'substr($0, 1, 1) == "\036"')
EOF_B
    nt=0; rtgts=""
    while IFS= read -r tgt; do
      [ "$nt" -lt "$MAX_WARN" ] || break
      fp=$(cd_bash_target "$tgt" "$cwd" "$hascd") && [ -f "$fp" ] || continue
      nt=$((nt + 1))
      wrote=""; c=1; jm=truncate
      while [ "$c" -le "$nb" ]; do [ "${btgt[$c]}" = "$tgt" ] && { jm=""; wrote="$wrote${btxt[$c]}
"; }; c=$((c + 1)); done
      # A redirect no chunk spells the text of (`{ echo …; } > f`, `gen > f`) is measured whole; a sed -i or perl -i target is not.
      if [ -n "$jm" ]; then
        [ -n "$rtgts" ] || { rtgts=${cmd//sed /_sed }; rtgts="
$(cc_bash_write_targets "${rtgts//perl /_perl }")
"; }
        case "$rtgts" in *"
$tgt
"*) jm=whole ;; esac
      fi
      if density_judge "$fp" "$wrote" "${jm:-truncate}"; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
    done <<EOF_T
$tgts
EOF_T
    # A governed file the run changed that no target names, within the same three per call.
    while IFS= read -r fp; do
      [ "$nt" -lt "$MAX_WARN" ] && [ -n "$fp" ] || break
      nt=$((nt + 1))
      if density_judge "$fp" "" effect; then
        emit " Written by a Bash command: $(basename "$fp")."
        exit 0
      fi
    done <<EOF_E
$(cd_effect_files "$effects" "$tgts" "$cwd" "$hascd")
EOF_E
  fi
} 2>/dev/null
exit 0
