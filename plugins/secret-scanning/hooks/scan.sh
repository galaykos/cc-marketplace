#!/bin/bash
# scan.sh (PreToolUse on Write, Edit, MultiEdit, NotebookEdit, MCP apply_patch/create_new_file and Bash; payload on stdin) — denies a write whose new text
#   (for apply_patch, the whole patch), Bash heredoc body or echo/printf argument landing in a file carries a high-confidence, non-placeholder secret.
# Off: CC_SECRET_SCAN=off. Fails open: any error, a timeout or a missing jq allows the write.
# CC_SECRET_SCAN unset: the /config option cc_secret_scan decides.
# Misses: a NotebookEdit cell (its new_source is not read); a URL password under 6 characters or led by `$` or `{`, a URL scheme not listed, a
#   webhook URL other than Slack's; a real value holding a placeholder word; an MCP write tool with other key names; on Bash, a command with no
#   write target, interpreter writes, cp/mv, sed/perl -i text and what cc_bash_write_chunks misses; a command that outruns the hook timeout (no per-call cap).
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
{
  input=$(cat)
  [ "$(cc_option CC_SECRET_SCAN on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    # The matcher in hooks.json and this case must widen together.
    *apply_patch|*create_new_file) ;;
    Bash) ;;
    *) exit 0 ;;
  esac

  hit=""
  # placeholder <matched-value> — 0 when the value announces itself as fake.
  placeholder() {
    local v="$1" lc
    lc=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
    case "$lc" in *example) return 0 ;; esac
    printf '%s' "$lc" | grep -qE 'example|placeholder|changeme|change-me|your[_-]|dummy|redacted|sample|fake|todo|xxxx' && return 0
    [ "$(printf '%s' "$v" | fold -w1 | sort -u | wc -l | tr -d ' ')" -le 1 ] && return 0
    return 1
  }
  # detect <label> <ERE> — sets hit to <label> when a match of <ERE> in $text is no placeholder; a no-op once hit is set.
  # grep needs `--`: the private-key pattern starts with dashes, which grep would read as options.
  detect() {
    local m
    [ -z "$hit" ] || return 0
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      placeholder "$m" || { hit="$1"; return 0; }
    done <<EOF_M
$(printf '%s' "$text" | grep -oE -- "$2" 2>/dev/null)
EOF_M
  }
  # Case-insensitive detect, for the assigned-literal rule only: -i would loosen the provider prefixes toward noise.
  detect_i() {
    local m v
    [ -z "$hit" ] || return 0
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      # The placeholder test reads the value after the operator, never the variable name.
      v=$(printf '%s' "$m" | sed -E 's/^[^:=]*[:=]["'"'"' ]*//')
      placeholder "${v:-$m}" || { hit="$1"; return 0; }
    done <<EOF_M
$(printf '%s' "$text" | grep -oiE -- "$2" 2>/dev/null)
EOF_M
  }
  # scan_for_secret <text> — the one scanner for both paths: resets hit, then sets it to the first label whose match is no placeholder.
  scan_for_secret() {
    text=$1; hit=""
    [ -n "$text" ] || return 0
    detect "an AWS access key ID"      'AKIA[0-9A-Z]{16}'
    detect "a private key block"       '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
    detect "a GitHub token"            'gh[pousr]_[A-Za-z0-9]{36,}'
    detect "a Slack token"             'xox[baprs]-[A-Za-z0-9-]{10,}'
    detect "a Google API key"          'AIza[0-9A-Za-z_-]{35}'
    detect "a Stripe live secret key"  'sk_live_[0-9a-zA-Z]{24,}'
    detect "a credential embedded in a URL" '(postgres|postgresql|mysql|mongodb(\+srv)?|redis|rediss|amqp|amqps|https?)://[^:/@[:space:]]+:[^@[:space:]/?#${][^@[:space:]/?#]{5,}@'
    detect "a Slack webhook URL" 'hooks\.slack\.com/services/T[^/]+/B[^/]+/.{16,}'
    detect_i "an assigned secret literal" '(api[_-]?key|secret|token|passwd|password)([_-][A-Za-z0-9]+)*["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9/+=_-]{24,}'
  }

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
        ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
      ] | join("\n")' 2>/dev/null) || exit 0
    file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null)
    scan_for_secret "$text"
  fi
  [ -n "$hit" ] || exit 0

  reason="secret-scanning: this write appears to contain ${hit}. Blocked before it reaches disk. Move the value to an environment variable or a secret store and reference it by name; if this is a deliberate fixture, make the value announce itself — end it in EXAMPLE, or use a placeholder word (example, placeholder, changeme, dummy, xxxx) — and the guard lets it through."
  [ -n "$file" ] && reason="$reason (file: $file)"
  reason="$reason CC_SECRET_SCAN=off disables this guard for the session."

  jq -cn --arg r "$reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
  exit 0
} 2>/dev/null
exit 0
