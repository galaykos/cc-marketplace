#!/bin/bash
# reads.sh (PostToolUse Read|Bash) — records a file read from line 1 and left short (a Read with a limit, head -n N, head -N, sed -n '1,Np') for gate.sh's
#   read warning; a later slice of it (tail, sed -n, a Read offset) merges, and covering the file clears it. Off: CC_READ_LEDGER=off|CC_CANDOR_GATE=off. Prints nothing.
# Misses: a slice starting past line 1 of an unrecorded file; pipes (cmd | head), awk/less/cat -n slices, tail -n +N; a Read's own 2,000-line cap.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/reads.sh

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

LEDGER_TTL_MIN=1440

# A command on stdin, one "path<TAB>start<TAB>end|tail:N<TAB>alt" per head, tail or sed -n print of one file, line-1 slices first; a pipe's own input is not a file.
# `cd DIR` before it moves the base a relative path resolves from; alt is the same path from the payload cwd, for a cd in a subshell.
reads_parse() {
  awk -v base="$1" '
    function unq(s) { if (s ~ /^".*"$/ || s ~ /^\047.*\047$/) s = substr(s, 2, length(s) - 2); return s }
    function file(s) {
      s = unq(s); alt = ""
      if (s == "" || s ~ /[$*?`{}<>]/ || s ~ /^-/) return ""
      if (s !~ /^\//) { if (base != cwd) alt = cwd "/" s; s = base "/" s }
      return s
    }
    function out(l, s) { if (s == "1") print l; else later = later l "\n" }
    BEGIN { cwd = base }
    END { printf "%s", later }
    { gsub(/&&|\|\||;|\|/, "\n"); n = split($0, seg, "\n")
      for (i = 1; i <= n; i++) {
        s = seg[i]; gsub(/[ \t]+[0-9]?>[>&]?[ \t]*[^ \t]+/, "", s); sub(/^[ \t(]+/, "", s); sub(/[ \t)]+$/, "", s)
        m = split(s, w, /[ \t]+/)
        if (w[1] == "cd" && m == 2) { d = unq(w[2]); if (d !~ /[$*?`]/) base = (d ~ /^\// ? d : base "/" d); continue }
        if ((w[1] == "head" || w[1] == "tail") && m == 3 && w[2] ~ /^-n?[0-9]+$/) { k = w[2]; f = w[3] }
        else if ((w[1] == "head" || w[1] == "tail") && m == 4 && w[2] == "-n" && w[3] ~ /^[0-9]+$/) { k = w[3]; f = w[4] }
        else if (w[1] == "sed" && m == 4 && w[2] == "-n" && unq(w[3]) ~ /^[0-9]+(,[0-9]+)?p$/) {
          r = unq(w[3]); sub(/p$/, "", r); a = r; b = r; if (index(r, ",")) { a = substr(r, 1, index(r, ",") - 1); b = substr(r, index(r, ",") + 1) }
          if ((f = file(w[4])) != "") out(f "\t" a "\t" b "\t" alt, a)
          continue
        }
        else continue
        sub(/^-n?/, "", k)
        if ((f = file(f)) == "" || k + 0 < 1) continue
        out(f "\t" (w[1] == "head" ? 1 "\t" k : "tail\t" k) "\t" alt, w[1] == "head" ? "1" : "tail")
      } }'
}

# Ledger <path>\t<lines>\t<a-b,c-d>: record one slice of a file, merge it, drop the file once the slices cover it.
reads_merge() { # ledger path lines start end (end 0: clear)
  awk -F'\t' -v p="$2" -v L="$3" -v s="$4" -v e="$5" '
    function cover(r,   n, i, j, t, a, lo, hi, x, cur) {
      n = split(r, a, ","); for (i = 1; i <= n; i++) { split(a[i], x, "-"); lo[i] = x[1] + 0; hi[i] = x[2] + 0 }
      for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) if (lo[j] < lo[i]) { t = lo[i]; lo[i] = lo[j]; lo[j] = t; t = hi[i]; hi[i] = hi[j]; hi[j] = t }
      out = ""; cur = 0
      for (i = 1; i <= n; i++) {
        if (cur && lo[i] <= ch + 1) { if (hi[i] > ch) ch = hi[i]; continue }
        if (cur) out = out (out == "" ? "" : ",") cl "-" ch
        cl = lo[i]; ch = hi[i]; cur = 1
      }
      if (cur) out = out (out == "" ? "" : ",") cl "-" ch
      return out
    }
    $1 == p { prev = $3; next }
    { print }
    END {
      if (e == 0) exit
      r = cover((prev == "" ? "" : prev ",") s "-" e)
      if (r == "1-" L || (r ~ /^1-[0-9]+$/ && substr(r, 3) + 0 >= L + 0)) exit
      print p "\t" L "\t" r
    }' "$1"
}

{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  [ "$(cc_option CC_CANDOR_GATE block)" = off ] && exit 0
  [ "$(cc_option CC_READ_LEDGER warn)" = off ] && exit 0
  [ -z "$(printf '%s' "$input" | jq -r '.agent_id // empty')" ] || exit 0
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
  [ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$PWD"
  case "$(printf '%s' "$input" | jq -r '.tool_name // empty')" in
    Read)
      # "-" for an absent field: read splits on runs of tabs, so an empty one would shift the next into its place.
      slices=$(printf '%s' "$input" | jq -r '.tool_input | select(.pages == null) | [.file_path // "", (.offset // "-"), (.limit // "-")] | @tsv')
      IFS=$'\t' read -r path off lim <<< "$slices"
      [ -n "$path" ] || exit 0
      case "$path" in /*) ;; *) path="$cwd/$path" ;; esac
      [ "$off" = - ] && off=""; [ "$lim" = - ] && lim=""
      case "$off$lim" in
        '') slices=$(printf '%s\t0\t0' "$path") ;;
        *) off=${off:-1}; [ "$off" -ge 1 ] 2>/dev/null || off=1
           if [ -n "$lim" ]; then slices=$(printf '%s\t%s\t%s' "$path" "$off" "$((off + lim - 1))")
           else slices=$(printf '%s\t%s\teof' "$path" "$off"); fi ;;
      esac ;;
    Bash)
      cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
      case "$cmd" in *head*|*tail*|*sed*) ;; *) exit 0 ;; esac
      slices=$(printf '%s\n' "$cmd" | reads_parse "$cwd") ;;
    *) exit 0 ;;
  esac
  [ -n "$slices" ] || exit 0

  ctx=$(printf '%s' "$input" | jq -r '.transcript_path // .session_id // empty')
  [ -n "$ctx" ] || exit 0
  # Under TMPDIR, not the state root: the payload cwd follows a cd, and the gate's would not; private, as /tmp is shared.
  f="${TMPDIR:-/tmp}/cc-candor-reads-$(printf '%s' "$ctx" | cksum | cut -d' ' -f1)"
  # Only a slice from line 1 that stops short opens an entry; any other slice, or a clear, acts on one already there.
  if [ ! -f "$f" ]; then
    open=0
    while IFS=$'\t' read -r path s e alt; do [ "$s" = 1 ] && [ "$e" != eof ] && open=1; done <<< "$slices"
    [ "$open" = 1 ] || exit 0
  fi
  umask 077
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'cc-candor-reads-*' -type f -mmin +"$LEDGER_TTL_MIN" -delete
  touch "$f" || exit 0
  while IFS=$'\t' read -r path s e alt; do
    [ -f "$path" ] || { [ -n "$alt" ] && [ -f "$alt" ] && path=$alt; } || continue
    [ "$s" = 1 ] || awk -F'\t' -v p="$path" '$1 == p { f = 1; exit } END { exit !f }' "$f" || continue
    lines=0
    if [ "$e" != 0 ]; then
      lines=$(awk 'END { print NR }' "$path")
      [ "$lines" -gt 0 ] 2>/dev/null || continue
      case "$s" in tail) s=$((lines - e + 1)); [ "$s" -ge 1 ] || s=1; e=$lines ;; esac
      [ "$e" = eof ] && e=$lines
      [ "$e" -gt "$lines" ] 2>/dev/null && e=$lines
      [ "$s" -le "$e" ] 2>/dev/null || continue
    fi
    reads_merge "$f" "$path" "$lines" "$s" "$e" > "$f.$$" && mv "$f.$$" "$f"
  done <<< "$slices"
  [ -s "$f" ] || rm -f "$f"
} 2>/dev/null
exit 0
