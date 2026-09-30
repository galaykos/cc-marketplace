# --- plugin state --------------------------------------------------------------
# Canonical copy: templates/blocks/plugin-state.md. Every hook defining cc_plugin_state must
# carry this block byte-for-byte (pc_shared_blocks); generated hooks include it.
# cc_plugin_state <root> <name> prints the directory holding a plugin's own per-project hook
# state, <root> being the hook's cc_state_root result: ${CLAUDE_PLUGIN_DATA}/<key>/<name> when
# the host sets that variable, else <root>/.claude/<name>, the path hooks used before it.
# <key> is the root's basename with every character outside [A-Za-z0-9_-] turned into -, a -,
# and the root's cksum: the host gives one data dir per plugin id, not per project (measured
# 2.1.282), and a raw path inside a filename names parents that never exist. tr runs under
# LC_ALL=C because a UTF-8 tr stops at the first invalid byte. Status 0, no stderr; it
# creates nothing, so the caller keeps its own mkdir -p.
# WHY: state read by no one but the plugin's own hooks does not belong in the user's repo —
# the 2026-09-29 review found .claude/code-review/ and .claude/skill-router/ created by one
# prompt and one edit in a fresh repo.
# WHAT IT DOES NOT CATCH: state another plugin, a skill or the user reads must not use it; the
# fallback path is still in the repo; the data dir is keyed by plugin id, so install scopes of
# one plugin share it (inferred from the docs' id rule), while a --plugin-dir copy gets its
# own `-inline` directory and never sees the installed copy's state. The variable was measured
# only in a SessionStart hook; other events are doc-stated. An event that lacks it falls back
# to the repo path, which splits a writer from a reader running on another event.
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
