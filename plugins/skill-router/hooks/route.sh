#!/bin/bash
# route.sh — PostToolUse, fails open: matches the edited file, each existing file a Bash command wrote under the project root, and the
# command itself against rules.tsv; prints one additionalContext envelope of `high` nudges, each skill once per context; queues other content matches as pending_low.
# Off: CC_REMIND=off, or unset with the /config option cc_remind off. CC_ROUTE is not read: it names the prompt-level check only.
# Misses: two concurrent calls can drop a pending_low entry; a payload cwd of `/` or `$HOME` outside git is taken for the project root;
# a directory row matches only the directory name it spells (in any case); a command row routes an unquoted mention of its CLI
# and misses a CLI run through a script or an npm alias; a Bash command's write targets past the eighth (MAX_BASH_TARGETS) are not read.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/route.sh
MAX_BASH_TARGETS=8

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
# route_cmd_mask <command> prints the command as command rows see it: quoted text as `_`, heredoc bodies blank, `$(…)` live.
route_cmd_mask() {
  printf '%s\n' "$1" | awk '
    BEGIN { st = "U"; nq = 0; qh = 1 }
    qh <= nq {
      t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (t == hq[qh]) qh++
      print ""; next
    }
    {
      line = $0; out = ""; n = length(line)
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1); two = substr(line, i, 2); top = substr(st, length(st), 1)
        if (top == "S") {
          if (c == "\047") { st = substr(st, 1, length(st) - 1); out = out c } else out = out "_"
          continue
        }
        if (top == "D") {
          if (c == "\\") { out = out "__"; i++ }
          else if (c == "\"") { st = substr(st, 1, length(st) - 1); out = out c }
          else if (two == "$(") { st = st "C"; out = out two; i++ }
          else out = out "_"
          continue
        }
        if (c == "\\") { out = out "__"; i++; continue }
        if (c == "\047") { st = st "S"; out = out c; continue }
        if (c == "\"") { st = st "D"; out = out c; continue }
        if (top == "C" && c == ")") { st = substr(st, 1, length(st) - 1); out = out c; continue }
        if (two == "$(") { st = st "C"; out = out two; i++; continue }
        if (substr(line, i, 3) == "<<<") { out = out "<<<"; i += 2; continue }
        if (two == "<<" && match(substr(line, i + 2), /^-?[ \t]*["\047\\]?[A-Za-z_][A-Za-z0-9_]*["\047]?/)) {
          w = substr(line, i + 2, RLENGTH); sub(/^-?[ \t]*["\047\\]?/, "", w); sub(/["\047]$/, "", w)
          hq[++nq] = w; out = out substr(line, i, RLENGTH + 2); i += RLENGTH + 1; continue
        }
        out = out c
      }
      print out
    }'
}
{
  input=$(cat)
  command -v jq >/dev/null 2>&1 || exit 0

  case "$(cc_option CC_REMIND on)" in off) exit 0 ;; esac

  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  rules="${CLAUDE_PLUGIN_ROOT}/rules.tsv"
  [ -f "$rules" ] || exit 0
  bash_targets=""; cmd_hits=""
  if [ "$tool" = Bash ]; then
    bash_cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    [ -n "$bash_cmd" ] || exit 0
    # Every shape cc_bash_write_targets returns holds one of these words, so a miss skips its awk safely.
    case "$bash_cmd" in
      *'>'*|*tee*|*sed*|*perl*) bash_targets=$(cc_bash_write_targets "$bash_cmd" | head -n "$MAX_BASH_TARGETS") ;;
    esac
    cmd_masked=""; masked=0
    while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
      [ "${conf%$'\r'}" = high ] || continue
      printf '%s' "$bash_cmd" | grep -qE "$pattern" 2>/dev/null || continue
      [ "$masked" = 1 ] || { cmd_masked=$(route_cmd_mask "$bash_cmd"); masked=1; }
      m=$(printf '%s' "$cmd_masked" | grep -m1 -oE "$pattern" 2>/dev/null) || continue
      # An empty marker is spelled `-`: a tab-IFS `read` collapses an empty field and would shift the matched text into it.
      m="${m%%$'\n'*}"; marker="${marker%$'\r'}"; [ -n "$marker" ] || marker=-
      cmd_hits="${cmd_hits}${skill}"$'\t'"${plugin}"$'\t'"${marker}"$'\t'"${m}"$'\n'
    done < <(grep "^command"$'\t' "$rules" 2>/dev/null)
    [ -n "$bash_targets" ] || [ -n "$cmd_hits" ] || exit 0
  fi

  # Context key, not session key: a subagent shares its parent's session_id but has its own transcript.
  session_id=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty' 2>/dev/null) || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  file_path=""
  if [ "$tool" != Bash ]; then
    # pathInProject: the JetBrains MCP create_new_file key.
    file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.pathInProject // empty' 2>/dev/null) || exit 0
    [ -n "$file_path" ] || exit 0
  fi
  [ -n "$session_id" ] || exit 0
  [ -n "$cwd" ] || exit 0
  [ -d "$cwd" ] || exit 0
  root=$(cc_state_root "$cwd") || exit 0

  # Two parallel arrays per target: rec, the spelling pending_low records; abs, the file on disk.
  rec=(); abs=()
  if [ "$tool" = Bash ]; then
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      case "$t" in /*) p="$t" ;; *) p="$cwd/$t" ;; esac
      pd="${p%/*}"; [ -n "$pd" ] || pd=/
      pd=$(CDPATH= cd -- "$pd" 2>/dev/null && pwd) || continue
      p="${pd%/}/${p##*/}"
      [ -f "$p" ] || continue
      case "$p" in "$root"/*) ;; *) continue ;; esac
      rec+=("$p"); abs+=("$p")
    done <<EOF_TARGETS
$bash_targets
EOF_TARGETS
    [ "${#abs[@]}" -gt 0 ] || [ -n "$cmd_hits" ] || exit 0
  else
    p="$cwd/$file_path"
    case "$file_path" in /*) p="$file_path" ;; esac
    rec+=("$file_path"); abs+=("$p")
  fi

  PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"
  . "$(dirname "$0")/plugins-dir.sh" 2>/dev/null
  command -v pr_resolve_plugins_dir >/dev/null 2>&1 && pr_resolve_plugins_dir

  state_dir=$(cc_plugin_state "$root" skill-router)
  # Hashed: the context key is usually an absolute path, and a raw one names a file whose parent directories never exist.
  ctx=$(printf '%s' "$session_id" | cksum 2>/dev/null | cut -d' ' -f1)
  [ -n "$ctx" ] || exit 0
  state_file="$state_dir/fired-$ctx.json"
  fired=""
  [ -r "$state_file" ] && fired=$(jq -r '.fired[]? // empty' "$state_file" 2>/dev/null)

  # set_target <i> — the globals every matcher below reads, for target i.
  set_target() {
    file_path="${rec[$1]}"; target="${abs[$1]}"
    base=$(basename "$file_path")
    rel="$file_path"
    case "$target" in "$root"/*) rel="${target#"$root"/}" ;; esac
  }

  # A code or style file, the only kind a `content`+`high` row fires inline on (nudge_high_matches).
  inline_ext() {
    case "$base" in
      *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.vue|*.svelte|*.astro|*.css|*.scss|*.sass|*.less|*.html|*.php|*.twig|*.erb) return 0 ;;
    esac
    return 1
  }

  plugin_installed() { # $1 owning_plugin — fire-if-uncertain
    command -v pr_plugin_installed >/dev/null 2>&1 || return 0
    pr_plugin_installed "$1"
  }
  already_fired() { printf '%s\n' "$fired" | grep -qxF "$1"; }

  match_glob() { # $1 pattern
    # Case-insensitive: scaffolders ship one framework directory as both `Pages` and `pages`.
    local pat="$1" rc=1 nocase_was_off=1
    shopt -q nocasematch && nocase_was_off=0
    shopt -s nocasematch
    case "$pat" in
      '**/'*'/**')
        local mid="${pat#**/}"; mid="${mid%/**}"
        case "/$rel" in *"/$mid/"*) rc=0 ;; esac ;;
      *)
        case "$base" in $pat) rc=0 ;; esac ;;
    esac
    [ "$nocase_was_off" -eq 1 ] && shopt -u nocasematch
    return "$rc"
  }

  marker_ok() { # $1 stack_marker — 0 = fire, 1 = suppress
    local list="$1" alt m neg req manifest regex mcontent rc
    [ -z "$list" ] || [ "$list" = "-" ] && return 0
    while [ -n "$list" ]; do
      alt="${list%%||*}"
      if [ "$alt" = "$list" ]; then list=""; else list="${list#*||}"; fi
      m="$alt"; neg=0; req=0
      case "$m" in '?'*) req=1; m="${m#'?'}" ;; esac
      case "$m" in '!'*) neg=1; m="${m#!}" ;; esac
      manifest="${m%%~*}"
      regex="${m#*~}"
      [ "$manifest" = "$m" ] && continue
      [ -n "$manifest" ] && [ -n "$regex" ] || continue
      if [ "$manifest" = "@base" ]; then
        mcontent="$base"
      elif [ "$manifest" = "@path" ]; then
        mcontent="$rel"
      elif [ -f "$root/$manifest" ] && [ -r "$root/$manifest" ] \
           && mcontent=$(head -c 65536 "$root/$manifest" 2>/dev/null); then
        :
      else
        [ "$req" -eq 1 ] && return 1
        continue
      fi
      printf '%s' "$mcontent" | grep -qE "$regex" 2>/dev/null
      rc=$?
      [ "$rc" -ge 2 ] && continue
      [ "$neg" -eq 1 ] && rc=$((1 - rc))
      return "$rc"
    done
    return 0
  }

  nudges=""
  emit_nudge() { # $1 skill, $2 owning_plugin, [$3 subject] — accumulates; delivered once below.
    # A subagent has no Skill tool, so the nudge names the SKILL.md path to Read when one is found.
    local sp="" proot="" subj="${3:-This edit touches $base}"
    command -v pr_plugin_root >/dev/null 2>&1 && proot=$(pr_plugin_root "$2")
    [ -n "$proot" ] && [ -f "$proot/skills/$1/SKILL.md" ] && sp=" — Read $proot/skills/$1/SKILL.md"
    nudges="${nudges}$(printf '[skill-router] %s — load the `%s` skill (%s plugin) and review your change against it before continuing.%s' "$subj" "$1" "$2" "$sp")"$'\n'
  }

  nudge_high_matches() {
    fired_now=""
    emitted_now=""
    hcs=()
    i=0
    while [ "$i" -lt "${#abs[@]}" ]; do
      set_target "$i"; i=$((i + 1))
      hc=""; [ -r "$target" ] && hc=$(head -c 65536 "$target" 2>/dev/null)
      hcs+=("$hc")
      inline=0; inline_ext && inline=1
      while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
        case "$stype" in ''|'#'*) continue ;; esac
        conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
        [ "$conf" = high ] || continue
        case "$stype" in
          glob) match_glob "$pattern" || continue ;;
          content)
            [ "$inline" = 1 ] && [ -n "$hc" ] || continue
            already_fired "$skill" && continue
            printf '%s' "$hc" | grep -qE "$pattern" 2>/dev/null || continue ;;
          *) continue ;;
        esac
        plugin_installed "$plugin" || continue
        marker_ok "$marker" || continue
        already_fired "$skill" && continue
        printf '%s\n' "$emitted_now" | grep -qxF "$skill" && continue
        emit_nudge "$skill" "$plugin"
        emitted_now="${emitted_now}${skill}"$'\n'
        fired_now="${fired_now}${skill}"$'\n'
      done < "$rules"
    done
    # A command row has no file, so `@base` and `@path` markers see an empty string.
    base=""; rel=""
    while IFS=$'\t' read -r skill plugin marker frag; do
      [ -n "$skill" ] || continue
      plugin_installed "$plugin" || continue
      marker_ok "$marker" || continue
      already_fired "$skill" && continue
      printf '%s\n' "$emitted_now" | grep -qxF "$skill" && continue
      emit_nudge "$skill" "$plugin" "This command runs \`${frag}\`"
      emitted_now="${emitted_now}${skill}"$'\n'
      fired_now="${fired_now}${skill}"$'\n'
    done <<EOF_CMD
$cmd_hits
EOF_CMD
  }

  deliver_nudges() {
    if [ -n "$nudges" ]; then
      jq -cn --arg ctx "${nudges%$'\n'}" \
        '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$ctx}}'
    fi
  }

  # Reads hcs, the one head per target nudge_high_matches read.
  queue_low_matches() {
    pending_adds=""
    i=0
    while [ "$i" -lt "${#abs[@]}" ]; do
      set_target "$i"; content="${hcs[$i]}"; i=$((i + 1))
      [ -n "$content" ] || continue
      inline=0; inline_ext && inline=1
      while IFS=$'\t' read -r stype pattern skill plugin conf marker || [ -n "$stype" ]; do
        case "$stype" in ''|'#'*) continue ;; esac
        conf="${conf%$'\r'}"; marker="${marker%$'\r'}"
        [ "$stype" = content ] || continue
        [ "$conf" = high ] && [ "$inline" = 1 ] && continue
        plugin_installed "$plugin" || continue
        marker_ok "$marker" || continue
        if printf '%s' "$content" | grep -qE "$pattern" 2>/dev/null; then
          pending_adds="${pending_adds}${skill}"$'\t'"${file_path}"$'\n'
        fi
      done < "$rules"
    done
  }

  persist_state() {
    if [ -n "$fired_now" ] || [ -n "$pending_adds" ]; then
      mkdir -p "$state_dir" 2>/dev/null || exit 0
      [ -e "$state_dir/.gitignore" ] || printf '*\n' > "$state_dir/.gitignore" 2>/dev/null
      json='{"fired":[],"pending_low":[]}'
      if [ -r "$state_file" ]; then
        existing=$(cat "$state_file" 2>/dev/null)
        printf '%s' "$existing" | jq empty 2>/dev/null && json="$existing"
      fi
      if [ -n "$fired_now" ]; then
        while IFS= read -r fskill; do
          [ -n "$fskill" ] || continue
          json=$(printf '%s' "$json" | jq --arg s "$fskill" \
            'if (.fired | index($s) | not) then .fired += [$s] else . end' 2>/dev/null) || exit 0
        done <<EOF_FIRED
$fired_now
EOF_FIRED
      fi
      if [ -n "$pending_adds" ]; then
        while IFS=$'\t' read -r pskill pfile; do
          [ -n "$pskill" ] || continue
          json=$(printf '%s' "$json" | jq --arg sk "$pskill" --arg f "$pfile" \
            'if (.pending_low | any(.skill==$sk and .file==$f)) then . else .pending_low += [{skill:$sk,file:$f}] end' 2>/dev/null) || break
        done <<EOF
$pending_adds
EOF
      fi
      printf '%s\n' "$json" > "$state_file" 2>/dev/null || exit 0
    fi
  }

  nudge_high_matches
  # Before persist_state: an unwritable state dir must not swallow a nudge the model should have seen.
  deliver_nudges
  queue_low_matches
  persist_state
} 2>/dev/null
exit 0
