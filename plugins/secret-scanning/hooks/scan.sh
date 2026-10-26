#!/bin/bash
# scan.sh (PreToolUse on Write, Edit, MultiEdit, NotebookEdit, MCP apply_patch/create_new_file and Bash; payload on stdin) — denies a write whose new text
#   (for apply_patch, the whole patch), Bash heredoc body or echo/printf argument landing in a file carries a high-confidence, non-placeholder secret,
#   and a Bash write of redact.ts's [REDACTED: marker unless CC_SECRET_REDACT is off (Write/Edit carrying it are redact.ts's to refuse).
#   PostToolUse on the same tools, and PostToolUseFailure on a Bash call that exited non-zero (hook_event_name), warning only: after a python,
#   node, php, ruby, perl, deno, bun, cp, mv, install or patch run,
#   on the same patterns in what each file git reports changed since this lane's previous call added (the whole file when HEAD lacks it, else its
#   `+` lines against HEAD, so a line any uncommitted edit added is judged again). State: that lane's marker in the plugin's data dir
#   (CLAUDE_PLUGIN_DATA), else <root>/.claude/secret-scanning/ behind a `*` .gitignore.
# Off: CC_SECRET_SCAN=off. Fails open: a timeout, a missing jq or any error but a bad pattern file allows the write.
# Fails closed: a missing or malformed hooks/patterns.tsv, the pattern source, or a missing hooks/patterns.sh, its reader, denies every write with
#   text to scan (the PostToolUse lane stays silent).
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

MAX_BASH_EFFECTS=8
MAX_EFFECT_BYTES=1048576
{
  input=$(cat)
  [ "$(cc_option CC_SECRET_SCAN on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  tool=""; event=""; sess=""
  # context-key-ok: session_id is the effects marker's content, per session by design — a session's subagents share one window.
  { IFS= read -r tool; IFS= read -r event; IFS= read -r sess; } < <(printf '%s' "$input" | jq -r '.tool_name // "", .hook_event_name // "", .session_id // ""' 2>/dev/null)
  case "$tool" in
    Write|Edit|MultiEdit|NotebookEdit) ;;
    # The matcher in hooks.json and this case must widen together.
    *apply_patch|*create_new_file) ;;
    Bash) ;;
    *) exit 0 ;;
  esac

  hit=""
  pat_file="$(dirname "$0")/patterns.tsv"; pat_loaded=""
  # One reader of patterns.tsv for this hook and scan-range.sh; without it every write with text is refused, as for a bad file.
  . "$(dirname "$0")/patterns.sh" || load_patterns() { pat_bad="hooks/patterns.sh is missing"; return 1; }
  # deny <reason> — prints the PreToolUse deny and ends the run.
  deny() {
    jq -cn --arg r "$1" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
    exit 0
  }
  # detect <kind> <label> <flags> <ERE> — sets hit to <label> when a match of <ERE> in $text is no placeholder; a no-op once hit is set.
  # grep needs `--`: the private-key pattern starts with dashes, which grep would read as options.
  detect() {
    local m opts=-oE
    [ -z "$hit" ] || return 0
    [ "$3" = i ] && opts=-oiE
    while IFS= read -r m; do
      [ -n "$m" ] || continue
      pat_value "$1" "$m"
      placeholder "$pat_v" || { hit="$2"; return 0; }
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
      load_patterns "$pat_file" || deny "secret-scanning: blocked this write because the pattern file $pat_file is unusable ($pat_bad). Reinstall or update the plugin. CC_SECRET_SCAN=off turns this check off."
      pat_loaded=1
    fi
    for k in "${!pat_re[@]}"; do
      detect "${pat_kind[$k]}" "${pat_label[$k]}" "${pat_flags[$k]}" "${pat_re[$k]}"
    done
  }

  # The PostToolUse lane: the write has landed, so it warns and never denies. It reads what an interpreter, cp, mv, install or
  # patch run changed (the bash-write-effects block), each file judged on what it added: the whole file when HEAD lacks it, else
  # its `+` lines against HEAD. The effects are read with the old marker, then the marker is dated, on EVERY call this lane sees,
  # a failed Bash call's PostToolUseFailure included.
  if [ "$event" = PostToolUse ] || [ "$event" = PostToolUseFailure ]; then
    cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
    [ -n "$cwd" ] && [ -d "$cwd" ] && root=$(cc_state_root "$cwd") || exit 0
    emark="$(cc_plugin_state "$root" secret-scanning)/bash-effects-scan.mark"
    effects=""
    if [ "$tool" = Bash ]; then
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      effects=$(cc_bash_write_effects "$root" "$emark" "$cmd" "$MAX_BASH_EFFECTS" "$sess")
    fi
    cc_bash_effects_mark "$root" "$emark" "$sess"
    [ -n "$effects" ] || exit 0
    # An unusable pattern file is the PreToolUse lane's to refuse; a lane that cannot deny stays silent.
    load_patterns "$pat_file" || exit 0
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
    jq -cn --arg c "secret-scanning: a Bash command just wrote what looks like a secret to disk:$found
Move each value to an environment variable or secret store before it is committed; for a test fixture, end it in EXAMPLE or use a placeholder word. CC_SECRET_SCAN=off turns this check off." \
      --arg ev "$event" '{hookSpecificOutput:{hookEventName:$ev,additionalContext:$c}}' 2>/dev/null
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
          *'[REDACTED:'*) deny "secret-scanning: this command writes the redaction marker [REDACTED:…] to ${ctgt[$i]}. That would replace the real secret on disk: leave the value out, or edit only the lines around it with the Edit tool. CC_SECRET_REDACT=off, set by the user, allows it and also turns redaction off." ;;
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

  reason="secret-scanning: blocked a write containing ${hit}. Put the value in an environment variable or secret store and reference it by name; for a test fixture, end the value in EXAMPLE or use a placeholder word (example, placeholder, changeme, dummy, xxxx)."
  [ -n "$file" ] && reason="$reason (file: $file)"
  reason="$reason CC_SECRET_SCAN=off turns this check off."
  deny "$reason"
} 2>/dev/null
exit 0
