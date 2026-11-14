#!/bin/bash
# PostToolUse/PostToolUseFailure on a Write/Edit of a .py, or a Bash redirect/tee/sed -i into one, under the project root that imports bpy, bmesh, bpy_extras, bgl or gpu: runs check_bpy_scripts.py on that file against the version of a .blend beside it, else the project's newest .blend, else `blender --version`, and adds its errors and warnings once per context.
# Misses: interpreter, cp/mv and variable-path writes from Bash, a relative target after an in-command cd, no version source at all (silent), findings past MAX_SHOWN, a run past CHECK_TIMEOUT; every check_bpy_scripts.py limit (names, not types). Warn-only, fail-open. Off: CC_BPY_CHECK=off, or /config.
# Why, limits, history: rationale/derivations/plugin-blender.md § plugins/blender/hooks/bpy-check.sh

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
# CLAUDE_PLUGIN_DATA/<basename>-<cksum>/<name> if non-empty, else <root>/.cc-artifacts/<name>. Status 0; creates nothing.
# The host keeps one data dir per plugin id, not per project (2.1.282); LC_ALL=C: a UTF-8 tr stops at an invalid byte.
# Misses: state another plugin, a skill or the user reads must not use it; an event lacking the variable uses the repo.
cc_plugin_state() {
  local key sum
  if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
    key=$(printf '%s' "$(basename -- "$1")" | LC_ALL=C tr -c 'A-Za-z0-9_-' '-')
    sum=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
    printf '%s/%s-%s/%s\n' "${CLAUDE_PLUGIN_DATA%/}" "$key" "$sum" "$2"
  else
    printf '%s/.cc-artifacts/%s\n' "$1" "$2"
  fi
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

{
  [ "$(cc_option CC_BPY_CHECK on)" = "off" ] && exit 0
  command -v jq >/dev/null 2>&1 || exit 0
  command -v python3 >/dev/null 2>&1 || exit 0

  input=$(cat) || exit 0
  [ -n "$input" ] || exit 0

  MAX_BASH_TARGETS=4  # .py paths read from one Bash command
  MAX_BLENDS=50       # .blend headers read to find the project's newest
  MAX_SHOWN=6         # findings printed per call; the rest are counted
  CHECK_TIMEOUT=15    # seconds per checker run; hooks.json allows 30

  event=$(printf '%s' "$input" | jq -r '.hook_event_name // "PostToolUse"' 2>/dev/null)
  case "$event" in PostToolUse|PostToolUseFailure) ;; *) exit 0 ;; esac
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
  [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  sroot=$(cc_state_root "$cwd") || exit 0

  cands=""
  case "$tool" in
    Write|Edit|MultiEdit)
      fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
      case "$fp" in /*) ;; *) fp="$cwd/$fp" ;; esac
      cands="$fp"$'\n'
      ;;
    Bash)
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
      [ -n "$(cc_bash_write_targets "$cmd")" ] || exit 0
      # After an in-command cd a relative target names a file this hook cannot place: skip it, a miss, never a wrong file.
      hascd=0
      printf '%s\n' "$cmd" | grep -qE '(^|[;&|({[:space:]])(cd|pushd)([[:space:]]|$)' && hascd=1
      while IFS= read -r t; do
        case "$t" in
          /*.py) cands="$cands$t"$'\n' ;;
          *.py) [ "$hascd" = 0 ] && cands="$cands$cwd/$t"$'\n' ;;
        esac
      done < <(cc_bash_write_targets "$cmd" | LC_ALL=C grep -E '\.py$' | head -n "$MAX_BASH_TARGETS")
      ;;
    *) exit 0 ;;
  esac

  files=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in *.py) ;; *) continue ;; esac
    case "$f" in "$sroot"/*) ;; *) continue ;; esac
    [ -f "$f" ] && [ -r "$f" ] || continue
    grep -qE '^[[:space:]]*(import|from)[[:space:]]+(.*[^[:alnum:]_.])?(bpy|bmesh|bpy_extras|bgl|gpu)([^[:alnum:]_]|$)' "$f" 2>/dev/null || continue
    case $'\n'"$files" in *$'\n'"$f"$'\n'*) ;; *) files="$files$f"$'\n' ;; esac
  done <<< "$cands"
  [ -n "$files" ] || exit 0

  checker="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/scripts/check_bpy_scripts.py"
  [ -f "$checker" ] || exit 0
  to=""
  command -v timeout >/dev/null 2>&1 && to="timeout $CHECK_TIMEOUT"

  # Target when the file's own directory holds no .blend: the newest .blend header in the project,
  # then the Blender on PATH. Neither: silent, since every rule is version-windowed.
  fallback() {
    local v
    v=$(find "$sroot" \( -name .git -o -name node_modules -o -name .venv -o -name .claude \) -prune -o -type f -name '*.blend' -print 2>/dev/null \
        | head -n "$MAX_BLENDS" | tr '\n' '\0' | xargs -0 -r $to python3 "$checker" --blend-version 2>/dev/null \
        | sed -nE 's/.*: Blender ([0-9]+)\.([0-9]+) .*/\1 \2/p' | sort -n -k1,1 -k2,2 | tail -n 1 | tr ' ' '.')
    [ -n "$v" ] && { printf '%s\tthe newest .blend in the project\n' "$v"; return 0; }
    command -v blender >/dev/null 2>&1 || return 0
    v=$($to blender --version 2>/dev/null | sed -nE '1s/^Blender ([0-9]+)\.([0-9]+).*/\1.\2/p')
    [ -n "$v" ] && printf '%s\tblender --version on PATH\n' "$v"
  }

  # Keyed on the context, hashed: a subagent shares its parent's session_id, and a raw path as a filename names parents that never exist.
  sid=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null)
  [ -n "$sid" ] || exit 0
  ctx=$(printf '%s' "$sid" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  dir=$(cc_plugin_state "$sroot" blender)
  # Unwritable state means silence: a finding that cannot be recorded as said would repeat on every edit.
  mkdir -p "$dir" 2>/dev/null || exit 0
  [ -w "$dir" ] || exit 0
  [ -e "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore" 2>/dev/null
  find "$dir" -maxdepth 1 -name 'bpy-seen-*' -mmin +1440 -delete 2>/dev/null
  seen="$dir/bpy-seen-$ctx"

  shown=""; nshown=0; more=0; targets=""; fb=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    out=$($to python3 "$checker" "$f" 2>&1); rc=$?
    if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'no target version'; then
      [ -n "$fb" ] || fb=$(fallback)
      [ -n "$fb" ] || continue
      out=$($to python3 "$checker" "$f" --blender "${fb%%$'\t'*}" 2>&1); rc=$?
      out=$(printf '%s\n' "$out" | sed "s/(from --blender)/(from ${fb#*$'\t'})/")
    fi
    [ "$rc" -le 1 ] || continue
    tgt=$(printf '%s\n' "$out" | sed -n 's/^target: //p' | head -n 1)
    while IFS= read -r l; do
      [ -n "$l" ] || continue
      key=$(printf '%s|%s|%s' "$f" "$tgt" "$l" | cksum | cut -d' ' -f1)
      grep -qxF "$key" "$seen" 2>/dev/null && continue
      if [ "$nshown" -lt "$MAX_SHOWN" ]; then
        printf '%s\n' "$key" >> "$seen" 2>/dev/null || exit 0
        shown="$shown${f#"$sroot"/}:${l%%$'\t'*} ${l#*$'\t'}"$'\n'; nshown=$((nshown + 1))
        case "$targets" in *"$tgt"*) ;; *) targets="$targets${targets:+; }$tgt" ;; esac
      else
        more=$((more + 1))
      fi
    done < <(printf '%s\n' "$out" | awk '/^(ERROR|WARNING) [^:]*:[0-9]+: / {
        r = substr($0, index($0, " ") + 1); r = substr(r, index(r, ":") + 1)
        printf "%s\t%s %s\n", substr(r, 1, index(r, ":") - 1), $1, substr(r, index(r, ":") + 2) }')
  done <<< "$files"
  [ "$nshown" -gt 0 ] || exit 0

  msg="blender: check_bpy_scripts.py on the bpy script(s) this $tool call wrote, target $targets:"$'\n'"$shown"
  [ "$more" -gt 0 ] && msg="$msg(+$more more: python3 \"$checker\" <file>)"$'\n'
  msg="${msg}An ERROR is a call that target removed or renamed, so the script raises AttributeError or does nothing; a WARNING is deprecated. Fix them before running the script. Wrong target? Pass --blender X.Y to the checker yourself; this hook reads the version from a .blend, else the Blender on PATH."
  jq -cn --arg e "$event" --arg c "$msg" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$c}}'
} 2>/dev/null
exit 0
