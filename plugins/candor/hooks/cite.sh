# cite.sh — sourced, never run, by hooks/gate.sh (clause 1) and scripts/candor-scan.sh (/candor:check): one citation lookup, so the
#   report and the gate cannot disagree on what resolves. Defines functions only.
# cite_extract: filter; prints each file:line in stdin once, sorted. URLs go first (a.php:80 in one is a port); the extension starts with
#   a letter, so v1.2.3:4 and 10:30 never match; a leading / is kept; a host before :<port> (.localhost, .test, .local, .internal,
#   .example, .invalid, .lan and common public TLDs) is no file, and a bare localhost:8000 has no extension; an elided path is skipped.
# cite_miss <file:line> <root> <cwd>: prints why the citation does not resolve — no file of that basename where it searched, or a line
#   past the end — and nothing when it resolves or cannot be decided: a path not found whose basename is not unique, or exists only
#   under <root>'s node_modules or vendor (6 deep). A path is tried from <cwd>, then <root>, then as a suffix, then by basename (8 deep);
#   a suffix two to eight files share resolves if any holds the line, and more than eight is undecidable.
# Misses: a file whose extension is a host name (.env.local:3) is never checked; a name only under dist, build or .venv, or past either
#   depth cap, reads as missing; a wrong line in a basename a dependency also has passes; a wrong directory with a unique basename passes.
# Why, limits, history: rationale/derivations/plugin-candor.md § plugins/candor/hooks/cite.sh

cite_extract() {
  sed -E 's#[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:])"]*##g' \
    | grep -oE '[/A-Za-z0-9_.~][A-Za-z0-9_./-]*\.[A-Za-z][A-Za-z0-9]{0,9}:[0-9]+' 2>/dev/null \
    | grep -vEi '\.(com|net|org|io|co|ai|app|gg|me|localhost|test|local|internal|example|invalid|lan):[0-9]+$' \
    | grep -vF '...' \
    | sort -u
}

# Pruned and depth-capped: a Stop hook must stay cheap on a large repo.
cite_find() { # <root> <find predicate...>
  local r="$1"; shift
  find "$r" -maxdepth 8 \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv \) -prune \
    -o "$@" -type f -print 2>/dev/null
}

cite_miss() {
  local p="${1%:*}" l="${1##*:}" root="$2" cwd="$3" f="" m b n k
  case "$p" in "~/"*) p="${HOME:-}/${p#\~/}" ;; esac
  case "$p" in /*) [ -f "$p" ] && f="$p" ;; esac
  # Abbreviated paths outnumber invented ones (measured), so only a basename found nowhere is fabricated.
  [ -n "$f" ] || { [ -f "$cwd/$p" ] && f="$cwd/$p"; }
  [ -n "$f" ] || { [ -f "$root/$p" ] && f="$root/$p"; }
  if [ -z "$f" ]; then
    m=$(cite_find "$root" -path "*/$p" | head -9); n=$(printf '%s\n' "$m" | grep -c .)
    if [ "$n" -gt 1 ]; then
      [ "$n" -gt 8 ] && return 0
      while IFS= read -r b; do
        k=$(wc -l < "$b" 2>/dev/null | tr -d ' ')
        case "$k" in '' | *[!0-9]*) return 0 ;; esac
        [ "$l" -le $((k + 1)) ] 2>/dev/null && return 0
      done <<< "$m"
      printf 'none of the %s files ending in %s has %s lines\n' "$n" "$p" "$l"
      return 0
    fi
    f="$m"
  fi
  if [ -z "$f" ]; then
    b=${p##*/}
    m=$(cite_find "$root" -name "$b" | head -2)
    n=$(printf '%s\n' "$m" | grep -c .)
    if [ "$n" -eq 0 ]; then
      # Subagents citing a dependency were blocked as inventing it: a basename only there is real but undecidable.
      [ -n "$(find "$root/node_modules" "$root/vendor" -maxdepth 6 -name "$b" -print -quit 2>/dev/null)" ] && return 0
      printf 'no file named %s found under %s (8 deep; node_modules and vendor 6 deep; dist, build, .venv, .git not searched)\n' "$b" "$root"
      return 0
    fi
    [ "$n" -eq 1 ] || return 0
    f="$m"
  fi
  n=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  case "$n" in '' | *[!0-9]*) return 0 ;; esac
  # +1: a final line with no trailing newline is not counted by wc -l.
  [ "$l" -gt $((n + 1)) ] 2>/dev/null && printf '%s has %s lines\n' "$f" "$n"
  return 0
}
