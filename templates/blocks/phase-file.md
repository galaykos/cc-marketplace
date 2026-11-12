# Shared block templates/blocks/phase-file.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/phase-file.md
# cc_phase_file <root> <session_id> prints <root>/.claude/cc-phase/<key>.json, that session's own phase sentinel; <key> is
# <session_id> with every byte outside A-Za-z0-9_- dropped. An empty key: no output, status 1. Creates nothing.
# Misses: two ids equal once those bytes are dropped share one file (a UUID loses none).
cc_phase_file() {
  local key
  key=$(printf '%s' "${2:-}" | LC_ALL=C tr -cd 'A-Za-z0-9_-')
  [ -n "$key" ] || return 1
  printf '%s/.claude/cc-phase/%s.json\n' "$1" "$key"
}
