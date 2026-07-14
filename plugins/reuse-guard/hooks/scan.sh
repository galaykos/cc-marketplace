#!/bin/bash
# Absolute-path shebang not `/usr/bin/env bash`: the fail-open guarantee must hold
# even under a stripped PATH where `env bash` exits 127.
# PostToolUse Tier-1 "reuse-a-corpse" guard (warn-only). On an Edit/Write/MultiEdit it
# checks whether the *added* content references a symbol the repo has marked deprecated,
# and prints ONE `reuse-guard:` warning if so. Silence is the common case. It NEVER blocks or
# vetoes an edit — it emits no blocking hook JSON, only a plain stdout warning. Fail-open: a
# missing jq/grep/awk, or any error, exits 0. The deprecated-symbol set is built once, cached at
# .claude/reuse-guard/deprecated.tsv (symbol \t path:line \t replacement), rebuilt only when
# the cache is missing or older than ~10 min — not on every Edit.
{
  command -v jq   >/dev/null 2>&1 || exit 0
  command -v grep >/dev/null 2>&1 || exit 0
  command -v awk  >/dev/null 2>&1 || exit 0

  input=$(cat)
  cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null) || exit 0
  [ -n "$cwd" ] || exit 0
  tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
  case "$tool" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

  # Never scan writes to the .claude state tree (don't warn on our own cache / state).
  fp=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
  case "$fp" in
    "$cwd"/.claude/*|"$cwd"/.claude|*/.claude/*) exit 0 ;;
  esac

  # ---- the added content across the three tool shapes ---------------------------------
  added=$(printf '%s' "$input" | jq -r '
    [ .tool_input.content    // empty,
      .tool_input.new_string // empty,
      ( .tool_input.edits // [] | map(.new_string // empty) | join("\n") )
    ] | join("\n")' 2>/dev/null) || exit 0
  [ -n "$added" ] || exit 0

  dir="$cwd/.claude/reuse-guard"
  cache="$dir/deprecated.tsv"

  # ---- (re)build the deprecated-symbol cache only when missing or stale (~10 min TTL) --
  need_build=1
  if [ -f "$cache" ] && [ -z "$(find "$cache" -mmin +10 2>/dev/null)" ]; then
    need_build=0
  fi

  MARKER_RE='@[Dd]eprecated|#\[deprecated|\[Obsolete|[Dd]eprecated:|DeprecationWarning|typing_extensions\.deprecated|typing\.deprecated|DEPRECATED|TODO: ?remove|@remove'

  if [ "$need_build" -eq 1 ]; then
    mkdir -p "$dir" 2>/dev/null || exit 0
    tmp="$cache.tmp.$$"
    : > "$tmp" 2>/dev/null || exit 0

    # Candidate files: those containing any marker, skipping heavy / state dirs. -I skips
    # binaries. Fail-open: no matches / no grep support just leaves an empty cache.
    grep -rlEI "$MARKER_RE" "$cwd" \
      --exclude-dir=.git --exclude-dir=.claude --exclude-dir=node_modules \
      --exclude-dir=target --exclude-dir=dist --exclude-dir=build \
      --exclude-dir=vendor --exclude-dir=.venv --exclude-dir=venv \
      --exclude-dir=__pycache__ 2>/dev/null \
    | while IFS= read -r file; do
        [ -f "$file" ] || continue
        # Line numbers of the marker lines in this file (grep owns the ERE — awk only
        # extracts the nearby symbol, so no fragile dynamic-regex escaping in awk).
        marks=$(grep -nE "$MARKER_RE" "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ' ')
        [ -n "$marks" ] || continue
        # A13a perf: skip files > 200 KB before the awk scanner (awk buffers the whole
        # file into memory via L[NR]=$0). `continue` (not exit) so one large file cannot
        # abort the rest of the cache build in this piped `while read` subshell.
        [ "$(wc -c < "$file" 2>/dev/null || echo 0)" -gt 200000 ] && continue
        awk -v FILE="$file" -v MARKS="$marks" '
          # keyword-led definition anchored near line start (so prose keywords mid-comment
          # do not masquerade as a symbol). Returns the declared name or "".
          function ident_def(line,   m, a, k) {
            if (match(line, /^[ \t]*((export|pub|public|private|protected|internal|static|async|final|abstract)[ \t]+)*(def|function|fn|func|class|struct|interface|type|enum|trait|const|let|var)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
              m = substr(line, RSTART, RLENGTH)
              k = split(m, a, /[ \t]+/)
              return a[k]
            }
            return ""
          }
          # forward-scan extractor: a definition keyword, else the identifier right before
          # "(" (covers `public void OldThing()` style signatures). No bare-assignment here.
          function ident_fwd(line,   m, r) {
            r = ident_def(line); if (r != "") return r
            if (match(line, /[A-Za-z_$][A-Za-z0-9_$]*[ \t]*\(/)) {
              m = substr(line, RSTART, RLENGTH); sub(/[ \t]*\(.*/, "", m); return m
            }
            return ""
          }
          # looser extractor for the def line itself (backward scan), incl. a leading
          # `name = ...` / `name: ...` binding.
          function ident_loose(line,   m, r) {
            r = ident_fwd(line); if (r != "") return r
            if (match(line, /^[ \t]*[A-Za-z_$][A-Za-z0-9_$]*[ \t]*[:=]/)) {
              m = substr(line, RSTART, RLENGTH); sub(/^[ \t]*/, "", m); sub(/[ \t]*[:=].*/, "", m); return m
            }
            return ""
          }
          BEGIN { n2 = split(MARKS, mm, " "); for (i=1; i<=n2; i++) if (mm[i] != "") ismark[mm[i]+0]=1 }
          { L[NR]=$0; T=NR }
          END {
            for (n=1; n<=T; n++) {
              if (!(n in ismark)) continue
              sym = ident_def(L[n])                       # same-line def (e.g. `def f(): # @deprecated`)
              if (sym == "") {                            # def below the marker (comment/decorator above)
                for (k=n+1; k<=n+5 && k<=T; k++) {
                  if (L[k] ~ /^[ \t]*$/) continue
                  s = ident_fwd(L[k]); if (s != "") { sym=s; break }
                  if (L[k] ~ /^[ \t]*(@|#\[|\[|\*|\/\/|\/\*|#)/) continue
                  break
                }
              }
              if (sym == "") {                            # def above the marker (docstring `Deprecated:` inside body)
                for (k=n-1; k>=n-4 && k>=1; k--) {
                  if (L[k] ~ /^[ \t]*$/) continue
                  s = ident_loose(L[k]); if (s != "") { sym=s; break }
                  break
                }
              }
              if (sym == "") continue
              rep = ""                                    # replacement hint: "... use newFoo ..."
              if (match(L[n], /[Uu]se[ \t]+`?[A-Za-z_$][A-Za-z0-9_$.]*/)) {
                rep = substr(L[n], RSTART, RLENGTH); sub(/^[Uu]se[ \t]+`?/, "", rep)
              }
              print sym "\t" FILE ":" n "\t" rep
            }
          }
        ' "$file" >> "$tmp" 2>/dev/null
      done

    # Dedupe by symbol (keep first def), then publish atomically.
    awk -F'\t' '!seen[$1]++' "$tmp" > "$cache.dd.$$" 2>/dev/null && mv "$cache.dd.$$" "$cache" 2>/dev/null
    rm -f "$tmp" "$cache.dd.$$" 2>/dev/null
  fi

  [ -s "$cache" ] || exit 0

  # ---- does the added content reference a deprecated symbol? ----------------------------
  added_ids=$(printf '%s' "$added" | grep -oE '[A-Za-z_$][A-Za-z0-9_$]*' 2>/dev/null | sort -u)
  [ -n "$added_ids" ] || exit 0

  # First cache row whose symbol appears as a whole identifier token in the added content.
  row=$(awk -F'\t' 'NR==FNR{w[$0]=1; next} ($1 in w){print; exit}' \
        <(printf '%s\n' "$added_ids") "$cache" 2>/dev/null)
  [ -n "$row" ] || exit 0

  sym=$(printf '%s' "$row" | cut -f1)
  loc=$(printf '%s' "$row" | cut -f2)
  rep=$(printf '%s' "$row" | cut -f3)
  [ -n "$sym" ] || exit 0

  msg="reuse-guard: added code references \`$sym\`, marked @deprecated at $loc"
  if [ -n "$rep" ]; then
    msg="$msg — prefer \`$rep\` instead."
  else
    msg="$msg — prefer its documented replacement."
  fi
  printf '%s\n' "$msg"
} 2>/dev/null
exit 0
