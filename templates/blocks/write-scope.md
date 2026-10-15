# Shared block templates/blocks/write-scope.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/write-scope.md
# cc_scope_init <state root> sets the roots a written path is judged against, each symlink-resolved: CLAUDE_PROJECT_DIR, which the
# shell's cd does not move, <state root> (cc_state_root of the payload cwd, empty for none) and $TMPDIR (default /tmp).
# cc_scope_skip <path>: status 0 for scratch, a target under neither root or under the temp dir while the root holding it is not;
# a path not created yet is judged by its nearest existing directory (cc_scope_dir prints it resolved). cc_scope_root <dir> sets
# cc_scope_r to the root holding a resolved dir, the state root first; status 1 when neither does.
# Misses: a sibling repo or worktree written by absolute path from outside both roots is skipped; with no cwd and no
# CLAUDE_PROJECT_DIR only the temp-dir rule holds.
cc_scope_init() {
  cc_scope_pd=""; [ -z "${CLAUDE_PROJECT_DIR:-}" ] || cc_scope_pd=$(CDPATH= cd -- "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P) || cc_scope_pd=""
  cc_scope_sr=""; [ -z "${1:-}" ] || cc_scope_sr=$(CDPATH= cd -- "$1" 2>/dev/null && pwd -P) || cc_scope_sr=""
  cc_scope_tmp=$(CDPATH= cd -- "${TMPDIR:-/tmp}" 2>/dev/null && pwd -P) || cc_scope_tmp=""
  cc_scope_pd=${cc_scope_pd%/}; cc_scope_sr=${cc_scope_sr%/}; cc_scope_tmp=${cc_scope_tmp%/}
}
cc_scope_dir() {
  local d
  d=$(dirname -- "$1")
  while [ ! -d "$d" ]; do d=$(dirname -- "$d"); done
  CDPATH= cd -- "$d" 2>/dev/null && pwd -P
}
cc_scope_root() {
  local r
  cc_scope_r=""
  for r in "$cc_scope_sr" "$cc_scope_pd"; do
    [ -n "$r" ] || continue
    case "$1/" in "$r"/*) cc_scope_r=$r; return 0 ;; esac
  done
  return 1
}
cc_scope_skip() {
  local d
  d=$(cc_scope_dir "$1") || return 1
  if cc_scope_root "$d"; then
    [ -n "$cc_scope_tmp" ] || return 1
    case "$cc_scope_r/" in "$cc_scope_tmp"/*) return 1 ;; esac
  elif [ -n "$cc_scope_sr$cc_scope_pd" ]; then
    return 0
  fi
  [ -n "$cc_scope_tmp" ] || return 1
  case "$d/" in "$cc_scope_tmp"/*) return 0 ;; esac
  return 1
}
