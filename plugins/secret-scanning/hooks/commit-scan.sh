#!/bin/bash
# commit-scan.sh — PreToolUse on Bash: denies a `git commit` or `git push` at a command position (past env assignments, wrappers, `cd <dir>` and `git -C <dir>`) when scripts/scan-range.sh finds a non-placeholder secret in what it would record or send, naming file:line and the pattern, never the value. Fails open. Off: CC_SECRET_COMMIT_SCAN=off; unset, /config decides.
# Reads the index; with -a/-i/-o, a pathspec or an earlier `git add` in the command, also tracked changes against HEAD plus the untracked files that add names (every one for a `$` pathspec); for a push, each commit its refspecs (else a mirror, remote.<name>.push, push.default=matching, else HEAD) send that the destination's remote-tracking refs lack. Its git calls run no fsmonitor, filter or gpg command. Misses: the commit message; a commit in bash -c, eval, a script, an alias or a variable; a `cd`/`-C` it cannot resolve; --git-dir, --work-tree, GIT_DIR; what the same command writes first; a merge's own changes; a file over MAX_FILE_BYTES; past MAX_PUSH_COMMITS or MAX_ADDED_FILES; a run the 10 s timeout kills; what scan-range.sh misses.
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
MAX_FILE_BYTES=1048576

# git_actions <cwd>, command on stdin: per git commit/push/add, `verb\037dir\037…\036` (dir empty when unresolvable); commit: cached|tracked;
# push: R<remote> (Q: held in a variable) then D (no source named), A (branches), T (tags), M (matching), S<source>; add: flags (A all, u tracked only, f force, X unknown) then pathspecs.
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
    function endseg(   i, x, b, dir, gd, mode, j, ch, a, nop, dd, fl, rm, rp, tg) {
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
        a = ""; nop = 0; dd = 0; rm = "R"; rp = "R"
        for (i++; i <= nw; i++) {
          x = W[i]
          if (!dd && x ~ /^-./) {
            if (x == "--") { dd = 1; continue }
            if (x ~ /^--(dry-run|delete|help)$/ || x == "-h") return
            if (x ~ /^--(all|branches|mirror)$/) { a = a "\037A"; if (x == "--mirror") a = a "\037T"; continue }
            if (x == "--tags") { a = a "\037T"; continue }
            if (x == "--repo") { i++; rp = (i <= nw && !F[i]) ? "R" W[i] : "Q"; continue }
            if (x ~ /^--repo=/) { rp = F[i] ? "Q" : "R" substr(x, 8); continue }
            if (x ~ /^--(push-option|receive-pack|exec)$/) { i++; continue }
            if (x ~ /^--/) continue
            for (j = 2; j <= length(x); j++) {
              ch = substr(x, j, 1)
              if (ch == "n" || ch == "d") return
              if (ch == "o") { if (j == length(x)) i++; break }
            }
            continue
          }
          if (++nop == 1) { rm = F[i] ? "Q" : "R" x; continue }
          tg = 0; if (x == "tag" && i < nw) { x = W[++i]; tg = 1 }
          if (F[i]) { a = a (tg ? "\037T" : "\037A"); continue }
          sub(/^\+/, "", x)
          if (x == ":") { a = a "\037M"; continue }
          sub(/:.*/, "", x)
          if (x ~ /\*/) a = a (x ~ /^refs\/tags\// ? "\037T" : "\037A")
          else if (x != "") a = a "\037S" x
        }
        if (a == "" && nop < 2) a = "\037D"
        if (a != "") emit("push", dir, (nop ? rm : rp) a)
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
            else if (x ~ /^--(patch|edit)/) fl = fl "u"
            else if (x ~ /^--(pathspec-from-file|interactive)/) { fl = fl "X"; if (x == "--pathspec-from-file") i++ }
            else if (x == "--chmod") i++
            else if (x !~ /^--/) for (j = 2; j <= length(x); j++) {
              ch = substr(x, j, 1)
              if (ch == "n") return
              if (ch == "A") fl = fl "A"; else if (ch ~ /[upe]/) fl = fl "u"; else if (ch == "f") fl = fl "f"; else if (ch == "i") fl = fl "X"
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
  out=$(cd "$top" 2>/dev/null && { [ "$1" != --tracked ] || nofilter; } && bash "$RANGE" "$@" 2>/dev/null)
  [ $? -eq 1 ] || return 0
  found="$found$(printf '%s\n' "$out" | sed -E 's/ \([^()]*\*\*\*\*, [0-9]+ chars\)$//')
"
}

# nofilter: blanks, for this shell's git calls, every clean or process filter driver git config names, so a worktree diff runs none.
nofilter() {
  local d n=$GIT_CONFIG_COUNT
  while IFS= read -r -d '' d; do
    d=${d#filter.}; d=${d%.*}
    export "GIT_CONFIG_KEY_$n=filter.$d.clean" "GIT_CONFIG_VALUE_$n=" "GIT_CONFIG_KEY_$((n + 1))=filter.$d.process" \
      "GIT_CONFIG_VALUE_$((n + 1))=" "GIT_CONFIG_KEY_$((n + 2))=filter.$d.required" "GIT_CONFIG_VALUE_$((n + 2))=false"
    n=$((n + 3))
  done < <(git config -z --name-only --get-regexp '^filter\..+\.(clean|process)$' 2>/dev/null)
  export GIT_CONFIG_COUNT=$n
}

# slot <top>: sets k to <top>'s index in the per-repository arrays, adding it.
slot() {
  k=0
  while [ "$k" -lt "${#R_TOP[@]}" ]; do [ "${R_TOP[$k]}" = "$1" ] && return 0; k=$((k + 1)); done
  R_TOP[$k]=$1; R_ADD[$k]=""; R_COMMIT[$k]=""
}

# pslot <top> <remote>: sets j to the push job for that repository and destination ("" when unknown), adding it.
pslot() {
  j=0
  while [ "$j" -lt "${#P_TOP[@]}" ]; do [ "${P_TOP[$j]}" = "$1" ] && [ "${P_REM[$j]}" = "$2" ] && return 0; j=$((j + 1)); done
  P_TOP[$j]=$1; P_REM[$j]=$2; P_REVS[$j]=""
}

# cget [-a] <key>: the last value of <key> in $cfg, a `git config --get-regexp` dump (a bare boolean reads true); -a: each value.
cget() {
  local l v="" all=""
  [ "$1" = -a ] && { all=1; shift; }
  while IFS= read -r l; do
    case "$l" in "$1") v=true ;; "$1 "*) v=${l#* } ;; *) continue ;; esac
    [ -z "$all" ] || printf '%s\n' "$v"
  done <<<"$cfg"
  [ -n "$all" ] || printf '%s\n' "$v"
}

# spec <refspec>: a configured push refspec as git_actions tokens one: M for `:`, T or A for a glob, S<source>, nothing for a delete.
spec() {
  local x=${1#+}
  case "$x" in :) echo M ;; :*) ;; refs/tags/*\**) echo T ;; *\**) echo A ;; *) printf 'S%s\n' "${x%%:*}" ;; esac
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
  # Nothing a repository configures may run before the prompt (fsmonitor here, filters in nofilter, gpg and submodules in scan-range.sh); a file over the threshold diffs as binary.
  export GIT_OPTIONAL_LOCKS=0 GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=core.fsmonitor GIT_CONFIG_VALUE_0=false \
    GIT_CONFIG_KEY_1=core.bigFileThreshold GIT_CONFIG_VALUE_1=$MAX_FILE_BYTES
  T=$(mktemp -d) || exit 0
  trap 'rm -rf "$T"' EXIT
  R_TOP=(); R_ADD=(); R_COMMIT=(); P_TOP=(); P_REM=(); P_REVS=()
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
        case "${f[0]}" in *u*) continue ;; esac
        ex=--exclude-standard; case "${f[0]}" in *f*) ex=--full-name ;; esac
        if [ "${#f[@]}" -gt 1 ] && [ "${f[0]}" = "${f[0]#*X}" ]; then
          git -C "$dir" ls-files -z -o "$ex" --full-name -- "${f[@]:1}"
        else
          case "${f[0]}" in *[AX]*) git -C "$top" ls-files -z -o "$ex" --full-name ;; esac
        fi 2>/dev/null >> "$T/add.$k" ;;
      commit)
        [ "${f[0]}" = tracked ] || [ -n "${R_ADD[$k]}" ] && R_COMMIT[$k]=tracked
        [ -n "${R_COMMIT[$k]}" ] || R_COMMIT[$k]=cached
        [ -f "$T/add.$k" ] && { cat "$T/add.$k" >> "$T/new.$k"; rm -f "$T/add.$k"; } ;;
      push)
        rem=${f[0]}; f=("${f[@]:1}"); cfg=""
        case " $rem ${f[*]} " in *" R "* | *" D "*) cfg=$(git -C "$top" config --get-regexp \
          '^(branch\..+\.(pushremote|remote)|remote\..+\.(push|mirror)|remote\.pushdefault|push\.default)$' 2>/dev/null) ;; esac
        case "$rem" in
          Q) rem="" ;;
          R) b=$(git -C "$top" symbolic-ref -q --short HEAD 2>/dev/null)
             rem=$(cget "branch.$b.pushremote"); [ -n "$rem" ] || rem=$(cget remote.pushdefault)
             [ -n "$rem" ] || rem=$(cget "branch.$b.remote"); rem=${rem:-origin} ;;
          *) rem=${rem#R} ;;
        esac
        pslot "$top" "$rem"
        # No source named: what git push would send there, from a mirror remote, remote.<name>.push or push.default=matching.
        toks=()
        for s in "${f[@]}"; do
          if [ "$s" != D ] || [ -z "$rem" ]; then toks+=("$s"); continue; fi
          case "$(cget "remote.$rem.mirror")" in [Tt]rue | [Yy]es | [Oo]n | 1) toks+=(A T); continue ;; esac
          sp=$(cget -a "remote.$rem.push")
          if [ -n "$sp" ]; then while IFS= read -r x; do toks+=("$(spec "$x")"); done <<<"$sp"
          elif [ "$(cget push.default)" = matching ]; then toks+=(M)
          else toks+=(D); fi
        done
        for s in "${toks[@]}"; do
          [ "$s" = M ] && [ -z "$rem" ] && s=A
          case "$s" in
            D) r=HEAD ;;
            A) r=$(git -C "$top" for-each-ref --format='%(objectname)' refs/heads/ 2>/dev/null) ;;
            T) r=$(git -C "$top" for-each-ref --format='%(objecttype) %(objectname) %(*objecttype) %(*objectname)' refs/tags/ 2>/dev/null \
                 | awk '$1 == "commit" { print $2 } $3 == "commit" { print $4 }') ;;
            M) r=$(git -C "$top" for-each-ref --format='%(refname) %(objectname)' refs/heads/ "refs/remotes/$rem/" 2>/dev/null \
                 | awk -v p="refs/remotes/$rem/" 'index($1, p) == 1 { s[substr($1, length(p) + 1)] = 1; next } { h[substr($1, 12)] = $2 }
                     END { for (b in h) if (b in s) print h[b] }') ;;
            S-*) r="" ;;
            # An unresolvable source (a typo the push will refuse) reads every branch.
            S?*) r=$(git -C "$dir" rev-parse -q --verify "${s#S}^{commit}" 2>/dev/null) \
                   || r=$(git -C "$top" for-each-ref --format='%(objectname)' refs/heads/ 2>/dev/null) ;;
            *) r="" ;;
          esac
          P_REVS[$j]="${P_REVS[$j]}"$'\n'$r
        done ;;
    esac
  done <<<"$recs"

  found=""; cw=""; pw=""
  k=0
  while [ "$k" -lt "${#R_TOP[@]}" ]; do
    top=${R_TOP[$k]}; before=$found
    case "${R_COMMIT[$k]}" in
      # The index too, when it differs from HEAD: after an add or with -i the commit keeps staged lines the tree may have dropped.
      tracked) git -C "$top" diff --cached --quiet 2>/dev/null || scan "$top" --cached; scan "$top" --tracked ;;
      cached) scan "$top" --cached ;;
    esac
    if [ -s "$T/new.$k" ]; then
      new=(); while IFS= read -r -d '' p; do new+=("./$p"); done < "$T/new.$k"
      if [ "${#new[@]}" -le "$MAX_ADDED_FILES" ]; then
        small=(); while IFS= read -r -d '' p; do small+=("$p"); done \
          < <(cd "$top" && find "${new[@]}" -prune -type f -size -$((MAX_FILE_BYTES + 1))c -print0 2>/dev/null)
        [ "${#small[@]}" -gt 0 ] && scan "$top" "${small[@]}"
      fi
    fi
    [ "$found" = "$before" ] || cw=1
    k=$((k + 1))
  done
  j=0
  while [ "$j" -lt "${#P_TOP[@]}" ]; do
    top=${P_TOP[$j]}; rem=${P_REM[$j]}; revs=(); before=$found
    while IFS= read -r r; do [ -n "$r" ] && revs+=("$r"); done <<<"${P_REVS[$j]}"
    # Sent means on the destination's own remote-tracking refs: a URL or path has none, an unknown remote counts every one.
    # Past the cap there, the commits no remote holds are read instead, so a fork far behind its upstream still has its own read.
    not=--remotes; arg=--outgoing
    if [ -n "$rem" ]; then
      arg="--outgoing=$rem"; not=""; git check-ref-format "refs/remotes/$rem/x" 2>/dev/null && not="--remotes=$rem"
    fi
    if [ "${#revs[@]}" -gt 0 ] && n=$(git -C "$top" rev-list --count --no-merges "${revs[@]}" --not ${not:+"$not"} 2>/dev/null); then
      [ "$n" -gt "$MAX_PUSH_COMMITS" ] && [ "$arg" != --outgoing ] && arg=--outgoing \
        && n=$(git -C "$top" rev-list --count --no-merges "${revs[@]}" --not --remotes 2>/dev/null)
      [ "$n" -gt 0 ] && [ "$n" -le "$MAX_PUSH_COMMITS" ] && scan "$top" "$arg" "${revs[@]}"
    fi
    [ "$found" = "$before" ] || pw=1
    j=$((j + 1))
  done
  what=${cw:+commit}; [ -n "$pw" ] && what="${what:+$what and }push"
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
