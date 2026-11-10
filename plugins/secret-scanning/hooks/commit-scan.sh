#!/bin/bash
# commit-scan.sh — PreToolUse on Bash: denies a `git commit` or `git push` at a command position (past env assignments, wrappers, `cd <dir>` and `git -C <dir>`) when scripts/scan-range.sh finds a non-placeholder secret in what it would record or send, naming file:line and the pattern, never the value. Fails open. Off: CC_SECRET_COMMIT_SCAN=off; unset, /config decides.
# Reads the index; with -a/-i/-o, a pathspec or an earlier `git add` in the command, tracked changes against HEAD plus the untracked files that add names; for a push, each commit its refspecs (else HEAD, minus @{upstream}) send that no remote-tracking ref holds. Misses: a commit in bash -c, eval, a script, an alias or a variable; a `cd`/`-C` it cannot resolve; --git-dir, --work-tree, GIT_DIR; what the same command writes first; a merge's own changes; past MAX_PUSH_COMMITS or MAX_ADDED_FILES; what scan-range.sh misses.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/hooks/commit-scan.sh

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

MAX_SHOWN=5
MAX_PUSH_COMMITS=1000
MAX_ADDED_FILES=1000

# git_actions <cwd>, command on stdin: per git commit/push/add, `verb\037dir\037…\036` (dir empty when unresolvable); commit: cached|tracked;
# push: D (HEAD), A (branches), T (tags), S<source>; add: flags (A all, u update, f force, X unknown) then pathspecs.
git_actions() {
  CS_CWD=$1 LC_ALL=C awk '
    { buf = (NR == 1 ? $0 : buf "\n" $0) }
    function bt_end(i,   c) {
      for (; i <= n; i++) { c = substr(buf, i, 1); if (c == "\\") { i++; continue }; if (c == "`") return i }
      return n
    }
    # i just past <<: queues the delimiter, returns its last character.
    function hd_open(i,   t, d, c, q) {
      t = 0; if (substr(buf, i, 1) == "-") { t = 1; i++ }
      while (substr(buf, i, 1) ~ /[ \t]/) i++
      d = ""; q = ""
      for (; i <= n; i++) {
        c = substr(buf, i, 1)
        if (q != "") { if (c == q) q = ""; else d = d c; continue }
        if (c ~ /[ \t\n;&|()<>]/) break
        if (c == "\\") { i++; d = d substr(buf, i, 1) } else if (c == "\047" || c == "\"") q = c; else d = d c
      }
      if (d != "") { PD[++np] = d; PT[np] = t }
      return i - 1
    }
    # i on a newline with bodies queued: returns the newline ending the last terminator.
    function skip_bodies(i,   k, s, e, line) {
      for (k = 1; k <= np; k++) {
        while (i < n) {
          s = i + 1; e = index(substr(buf, s), "\n")
          if (e == 0) { line = substr(buf, s); i = n } else { line = substr(buf, s, e - 1); i = s + e - 1 }
          if (PT[k]) sub(/^\t+/, "", line)
          if (line == PD[k]) break
        }
      }
      np = 0
      return i
    }
    # i just past $( or <(: returns the matching ).
    function skip_sub(i,   d, c, nx, q) {
      d = 1; q = ""
      for (; i <= n; i++) {
        c = substr(buf, i, 1); nx = substr(buf, i + 1, 1)
        if (q == "\047") { if (c == "\047") q = ""; continue }
        if (c == "\\") { i++; continue }
        if (q == "\"") { if (c == "\"") q = ""; else if (c == "$" && nx == "(") i = skip_sub(i + 2); else if (c == "`") i = bt_end(i + 1); continue }
        if (c == "\047" || c == "\"") { q = c; continue }
        if (c == "`") { i = bt_end(i + 1); continue }
        if (c == "$" && nx == "(") { i = skip_sub(i + 2); continue }
        if (c == "(") { d++; continue }
        if (c == ")") { if (--d == 0) return i; continue }
        if (c == "<" && nx == "<" && substr(buf, i + 2, 1) != "<") { i = hd_open(i + 2); continue }
        if (c == "\n" && np) i = skip_bodies(i)
      }
      return n
    }
    function dquote(i,   c, nx, j) {
      inw = 1
      for (; i <= n; i++) {
        c = substr(buf, i, 1); nx = substr(buf, i + 1, 1)
        if (c == "\"") return i
        if (c == "\\" && (nx == "$" || nx == "`" || nx == "\"" || nx == "\\" || nx == "\n")) { if (nx != "\n") w = w nx; i++; continue }
        if (c == "$" && nx == "(") { j = skip_sub(i + 2); w = w substr(buf, i, j - i + 1); dyn = 1; i = j; continue }
        if (c == "`") { j = bt_end(i + 1); w = w substr(buf, i, j - i + 1); dyn = 1; i = j; continue }
        if (c == "$") dyn = 1
        w = w c
      }
      return n
    }
    # A word after a redirection operator is its target, never an argument.
    function flush() {
      if (!inw) return
      if (!rt) { nw++; W[nw] = w; F[nw] = dyn }
      w = ""; inw = 0; dyn = 0; rt = 0
    }
    function cut() { flush(); endseg(); nw = 0; rt = 0 }
    function resolve(base, p) {
      if (p == "~") return home
      if (substr(p, 1, 2) == "~/") return home substr(p, 2)
      if (p == "" || substr(p, 1, 1) == "~") return ""
      if (substr(p, 1, 1) == "/") return p
      return base == "" ? "" : base "/" p
    }
    function emit(verb, dir, a) { printf "%s\037%s\037%s\036", verb, dir, a }
    function endseg(   i, x, b, dir, gd, mode, j, ch, a, nop, dd, fl) {
      if (nw == 0) return
      i = 1; gd = 0
      while (i <= nw) {
        x = W[i]
        if (!F[i] && x ~ /^[A-Za-z_][A-Za-z0-9_]*=/) { if (x ~ /^GIT_(DIR|WORK_TREE|INDEX_FILE|OBJECT_DIRECTORY|COMMON_DIR|NAMESPACE)=/) gd = 1; i++; continue }
        if (x ~ /^(then|do|else|elif|if|while|until|!|\{|\}|time|nohup|command|builtin|exec|noglob)$/) { i++; continue }
        b = x; sub(/^.*\//, "", b)
        if (b == "env") {
          for (i++; i <= nw && W[i] ~ /^-/; i++) {
            if (W[i] ~ /^(-C|-S|--chdir|--split-string)/) return
            if (W[i] == "-u" || W[i] == "--unset") i++
          }
          continue
        }
        if (b == "sudo" || b == "doas") {
          for (i++; i <= nw && W[i] ~ /^-/; i++) {
            if (W[i] ~ /^(-D|--chdir)/) return
            if (W[i] ~ /^-[ughpCUTrta]$/) i++
          }
          continue
        }
        if (b == "nice" || b == "timeout") {
          for (i++; i <= nw && W[i] ~ /^-/; i++) if (W[i] ~ /^-[nsk]$/) i++
          if (b == "timeout") i++
          continue
        }
        break
      }
      if (i > nw || F[i]) return
      b = W[i]; sub(/^.*\//, "", b)
      if (b == "cd" || b == "pushd") {
        for (i++; i <= nw && W[i] ~ /^-[LPe@]+$/; i++);
        if (i > nw) cur = home; else if (F[i] || W[i] == "-") cur = ""; else cur = resolve(cur, W[i])
        return
      }
      if (b == "popd") { cur = ""; return }
      if (b != "git") return
      dir = cur
      for (i++; i <= nw; i++) {
        x = W[i]
        if (x == "-C") { i++; dir = (i <= nw && !F[i]) ? resolve(dir, W[i]) : ""; continue }
        if (x ~ /^(-c|--config-env|--namespace|--attr-source)$/) { i++; continue }
        if (x ~ /^--(git-dir|work-tree)(=|$)/) { gd = 1; if (x !~ /=/) i++; continue }
        if (x ~ /^-/) continue
        break
      }
      if (gd || i > nw || F[i]) return
      x = W[i]
      if (x == "commit") {
        mode = "cached"; dd = 0
        for (i++; i <= nw; i++) {
          x = W[i]
          if (dd || x !~ /^-./) { mode = "tracked"; continue }
          if (x == "--") { dd = 1; continue }
          if (x ~ /^--(dry-run|help)$/ || x == "-h") return
          if (x ~ /^--(all|include|only|patch|pathspec-from-file)(=|$)/) { mode = "tracked"; if (x == "--pathspec-from-file") i++; continue }
          if (x ~ /^--(message|file|author|date|template|reuse-message|reedit-message|fixup|squash|cleanup|trailer)$/) { i++; continue }
          if (x ~ /^--/) continue
          for (j = 2; j <= length(x); j++) {
            ch = substr(x, j, 1)
            if (ch ~ /[aiop]/) mode = "tracked"
            if (ch ~ /[mFcCt]/) { if (j == length(x)) i++; break }
            if (ch ~ /[uS]/) break
          }
        }
        emit("commit", dir, mode)
      } else if (x == "push") {
        a = ""; nop = 0; dd = 0
        for (i++; i <= nw; i++) {
          x = W[i]
          if (!dd && x ~ /^-./) {
            if (x == "--") { dd = 1; continue }
            if (x ~ /^--(dry-run|delete|help)$/ || x == "-h") return
            if (x ~ /^--(all|branches|mirror)$/) { a = a "\037A"; if (x == "--mirror") a = a "\037T"; continue }
            if (x == "--tags") { a = a "\037T"; continue }
            if (x ~ /^--(push-option|repo|receive-pack|exec)$/) { i++; continue }
            if (x ~ /^--/) continue
            for (j = 2; j <= length(x); j++) {
              ch = substr(x, j, 1)
              if (ch == "n" || ch == "d") return
              if (ch == "o") { if (j == length(x)) i++; break }
            }
            continue
          }
          if (++nop == 1) continue
          if (x == "tag" && i < nw) x = W[++i]
          if (F[i]) { a = a "\037D"; continue }
          sub(/^\+/, "", x); sub(/:.*/, "", x)
          if (x != "") a = a "\037S" x
        }
        if (a == "" && nop < 2) a = "\037D"
        if (a != "") emit("push", dir, substr(a, 2))
      } else if (x == "add" || x == "stage") {
        fl = ""; a = ""; dd = 0
        for (i++; i <= nw; i++) {
          x = W[i]
          if (F[i]) { fl = fl "X"; continue }
          if (!dd && x ~ /^-./) {
            if (x == "--") { dd = 1; continue }
            if (x ~ /^--(dry-run|help)$/ || x == "-h") return
            if (x ~ /^--(all|no-ignore-removal)$/) fl = fl "A"
            else if (x == "--update") fl = fl "u"
            else if (x == "--force") fl = fl "f"
            else if (x ~ /^--(pathspec-from-file|interactive|patch|edit)/) { fl = fl "X"; if (x == "--pathspec-from-file") i++ }
            else if (x == "--chmod") i++
            else if (x !~ /^--/) for (j = 2; j <= length(x); j++) {
              ch = substr(x, j, 1)
              if (ch == "n") return
              if (ch == "A") fl = fl "A"; else if (ch == "u") fl = fl "u"; else if (ch == "f") fl = fl "f"; else if (ch ~ /[ipe]/) fl = fl "X"
            }
            continue
          }
          a = a "\037" x
        }
        emit("add", dir, fl a)
      }
    }
    END {
      home = ENVIRON["HOME"]; cur = ENVIRON["CS_CWD"]; n = length(buf); nw = 0; np = 0; w = ""; inw = 0; dyn = 0; rt = 0
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1); nx = substr(buf, i + 1, 1)
        if (c == "\\") { if (nx != "\n") { w = w nx; inw = 1 }; i++; continue }
        if (c == "\047") { j = index(substr(buf, i + 1), "\047"); if (j == 0) j = n - i + 1; w = w substr(buf, i + 1, j - 1); inw = 1; i += j; continue }
        if (c == "$" && nx == "\047") {
          for (j = i + 2; j <= n && substr(buf, j, 1) != "\047"; j++) if (substr(buf, j, 1) == "\\") j++
          w = w substr(buf, i + 2, j - i - 2); inw = 1; dyn = 1; i = j; continue
        }
        if (c == "\"") { i = dquote(i + 1); continue }
        if (c == "`") { j = bt_end(i + 1); w = w substr(buf, i, j - i + 1); inw = 1; dyn = 1; i = j; continue }
        if (c == "$" && nx == "(") { j = skip_sub(i + 2); w = w substr(buf, i, j - i + 1); inw = 1; dyn = 1; i = j; continue }
        if (c == "$") { w = w c; inw = 1; dyn = 1; continue }
        if (c == " " || c == "\t") { flush(); continue }
        if (c == "\n") { cut(); if (np) i = skip_bodies(i); continue }
        if (c == "#" && !inw) { j = index(substr(buf, i), "\n"); if (j == 0) break; i += j - 2; continue }
        if (c == ";" || c == "|" || c == "&" && nx != ">" || c == "(" || c == ")") {
          cut()
          if (nx == c || c == "|" && nx == "&" || c == ";" && nx == "&") i++
          continue
        }
        if (c == "<" || c == ">" || c == "&") {
          if (nx == "(" && c != "&") { i++; j = skip_sub(i + 1); w = w substr(buf, i - 1, j - i + 2); inw = 1; dyn = 1; i = j; continue }
          if (inw && w ~ /^[0-9]+$/) { w = ""; inw = 0 } else flush()
          if (c == "<" && nx == "<" && substr(buf, i + 2, 1) != "<") { i = hd_open(i + 2); continue }
          while (substr(buf, i + 1, 1) ~ /[<>&|]/) i++
          rt = 1; continue
        }
        w = w c; inw = 1
      }
      cut()
    }'
}

# scan <top> <scan-range argument>…: appends each hit scan-range.sh prints there, its masked value dropped, to $found.
scan() {
  local top=$1 out
  shift
  out=$(cd "$top" 2>/dev/null && bash "$RANGE" "$@" 2>/dev/null)
  [ $? -eq 1 ] || return 0
  found="$found$(printf '%s\n' "$out" | sed -E 's/ \([^()]*\*\*\*\*, [0-9]+ chars\)$//')
"
}

# slot <top>: sets k to <top>'s index in the per-repository arrays, adding it.
slot() {
  k=0
  while [ "$k" -lt "${#R_TOP[@]}" ]; do [ "${R_TOP[$k]}" = "$1" ] && return 0; k=$((k + 1)); done
  R_TOP[$k]=$1; R_ADD[$k]=""; R_COMMIT[$k]=""; R_PUSH[$k]=""
}

{
  IFS= read -r -d '' input
  case "$input" in *commit*|*push*) ;; *) exit 0 ;; esac
  [ "$(cc_option CC_SECRET_COMMIT_SCAN on)" = off ] && exit 0
  command -v jq >/dev/null 2>&1 && command -v git >/dev/null 2>&1 || exit 0
  both=$(printf '%s' "$input" | jq -j '(.tool_input.command // "") + "\u001e" + (.cwd // "")' 2>/dev/null) || exit 0
  cmd=${both%$'\036'*}; cwd=${both##*$'\036'}
  [ -n "$cmd" ] && [ -n "$cwd" ] && [ -d "$cwd" ] || exit 0
  recs=$(printf '%s\n' "$cmd" | git_actions "$cwd")
  [ -n "$recs" ] || exit 0

  RANGE="$(cd "$(dirname "$0")/.." && pwd)/scripts/scan-range.sh"
  [ -f "$RANGE" ] || exit 0
  # A repository's core.fsmonitor names a command git would run for a worktree diff; the hook runs before the permission prompt.
  export GIT_OPTIONAL_LOCKS=0 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.fsmonitor GIT_CONFIG_VALUE_0=false
  T=$(mktemp -d) || exit 0
  trap 'rm -rf "$T"' EXIT
  R_TOP=(); R_ADD=(); R_COMMIT=(); R_PUSH=()
  while IFS= read -r -d $'\036' rec; do
    verb=${rec%%$'\037'*}; rec=${rec#*$'\037'}
    dir=${rec%%$'\037'*}; rec=${rec#*$'\037'}
    [ -n "$dir" ] && [ -d "$dir" ] || continue
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && [ -n "$top" ] || continue
    slot "$top"
    f=(); while :; do f+=("${rec%%$'\037'*}"); [ "$rec" = "${rec#*$'\037'}" ] && break; rec=${rec#*$'\037'}; done
    case "$verb" in
      add)
        R_ADD[$k]=1
        case "${f[0]}" in *[uX]*) continue ;; esac
        ex=--exclude-standard; case "${f[0]}" in *f*) ex=--full-name ;; esac
        if [ "${#f[@]}" -gt 1 ]; then
          git -C "$dir" ls-files -z -o "$ex" --full-name -- "${f[@]:1}"
        else
          case "${f[0]}" in *A*) git -C "$top" ls-files -z -o "$ex" --full-name ;; esac
        fi 2>/dev/null >> "$T/add.$k" ;;
      commit)
        [ "${f[0]}" = tracked ] || [ -n "${R_ADD[$k]}" ] && R_COMMIT[$k]=tracked
        [ -n "${R_COMMIT[$k]}" ] || R_COMMIT[$k]=cached
        [ -f "$T/add.$k" ] && { cat "$T/add.$k" >> "$T/new.$k"; rm -f "$T/add.$k"; } ;;
      push)
        for s in "${f[@]}"; do
          case "$s" in
            D) R_PUSH[$k]="${R_PUSH[$k]}"$'\n'D ;;
            A) R_PUSH[$k]="${R_PUSH[$k]}"$'\n'$(git -C "$top" for-each-ref --format='%(objectname)' refs/heads/ 2>/dev/null) ;;
            T) R_PUSH[$k]="${R_PUSH[$k]}"$'\n'$(git -C "$top" for-each-ref --format='%(objecttype) %(objectname) %(*objecttype) %(*objectname)' refs/tags/ 2>/dev/null \
                 | awk '$1 == "commit" { print $2 } $3 == "commit" { print $4 }') ;;
            S-*) ;;
            S?*) r=$(git -C "$dir" rev-parse -q --verify "${s#S}^{commit}" 2>/dev/null) && R_PUSH[$k]="${R_PUSH[$k]}"$'\n'$r ;;
          esac
        done ;;
    esac
  done <<<"$recs"

  found=""; what=""
  k=0
  while [ "$k" -lt "${#R_TOP[@]}" ]; do
    top=${R_TOP[$k]}; before=$found
    [ -n "${R_COMMIT[$k]}" ] && scan "$top" "--${R_COMMIT[$k]}"
    if [ -s "$T/new.$k" ]; then
      new=(); while IFS= read -r -d '' p; do new+=("./$p"); done < "$T/new.$k"
      [ "${#new[@]}" -le "$MAX_ADDED_FILES" ] && scan "$top" "${new[@]}"
    fi
    [ "$found" = "$before" ] || what="commit"
    if [ -n "${R_PUSH[$k]}" ]; then
      revs=(); before=$found
      while IFS= read -r r; do
        [ -n "$r" ] || continue
        if [ "$r" = D ]; then
          revs+=(HEAD); u=$(git -C "$top" rev-parse -q --verify '@{upstream}' 2>/dev/null) && revs+=("^$u")
        else revs+=("$r"); fi
      done <<<"${R_PUSH[$k]}"
      if [ "${#revs[@]}" -gt 0 ] && n=$(git -C "$top" rev-list --count --no-merges "${revs[@]}" --not --remotes 2>/dev/null) \
        && [ "$n" -gt 0 ] && [ "$n" -le "$MAX_PUSH_COMMITS" ]; then
        scan "$top" --outgoing "${revs[@]}"
      fi
      [ "$found" = "$before" ] || what="${what:+$what and }push"
    fi
    k=$((k + 1))
  done
  found=$(printf '%s' "$found" | awk 'NF && !seen[$0]++')
  [ -n "$found" ] || exit 0

  total=$(printf '%s\n' "$found" | wc -l | tr -d ' ')
  list=$(printf '%s\n' "$found" | head -n "$MAX_SHOWN" | awk '{ printf "%s%s", (NR > 1 ? "; " : ""), $0 }')
  [ "$total" -gt "$MAX_SHOWN" ] && list="$list; and $((total - MAX_SHOWN)) more"
  fix="Move each value to an environment variable or secret store and out of this commit."
  case "$what" in *push*) fix="Move each value to an environment variable or secret store. A <commit>:<file>:<line> hit is in that unpushed commit: rewrite it, since a later commit deleting the line still sends it." ;; esac
  reason="secret-scanning: blocked this git $what: $total added line(s) match a secret pattern ($list). $fix For a test fixture, end the value in EXAMPLE or use a placeholder word. CC_SECRET_COMMIT_SCAN=off turns this check off."
  jq -cn --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}' 2>/dev/null
} 2>/dev/null
exit 0
