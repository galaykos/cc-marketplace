# plugins-dir.sh — sourced, never run, by route.sh, prime.sh and subagent-skills.sh: resolves the installed-plugins root from CLAUDE_PLUGIN_ROOT
#   under a flat (<plugins>/<plugin>) or versioned (<marketplace>/<plugin>/<version>) layout, and which plugins there are installed and enabled.
# Misses: managed-policy settings (a plugin enabled only there is filtered out once another layer enables any plugin); pr_plugin_root's
#   version is the highest it can order, not necessarily the one Claude Code loaded.
# Why, limits, history: rationale/derivations/plugin-skill-router.md § plugins/skill-router/hooks/plugins-dir.sh

# Sets PLUGINS_DIR (empty when undeterminable) and PLUGIN_LAYOUT (flat|versioned).
pr_resolve_plugins_dir() {
  PLUGINS_DIR=""
  PLUGIN_LAYOUT="flat"
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || return 0

  local self parent
  self=$(basename "$CLAUDE_PLUGIN_ROOT" 2>/dev/null) || return 0
  case "$self" in
    [0-9]*|v[0-9]*)
      # A version carries only digits, dots and `v`, so a plugin named `2fa-helper` stays on the flat branch.
      case "$self" in
        *[!0-9.v]*) ;;
        *) PLUGIN_LAYOUT="versioned" ;;
      esac
      ;;
  esac

  if [ "$PLUGIN_LAYOUT" = "versioned" ]; then
    parent=$(dirname "$CLAUDE_PLUGIN_ROOT" 2>/dev/null) || return 0
    PLUGINS_DIR=$(dirname "$parent" 2>/dev/null) || PLUGINS_DIR=""
  else
    PLUGINS_DIR=$(dirname "$CLAUDE_PLUGIN_ROOT" 2>/dev/null) || PLUGINS_DIR=""
  fi

  [ -n "$PLUGINS_DIR" ] && [ -d "$PLUGINS_DIR" ] || PLUGINS_DIR=""
  pr_load_enabled
  return 0
}

# Sets PR_ENABLED: enabledPlugins unioned across user and project settings, by bare name; empty (filters nothing) when unreadable.
pr_load_enabled() {
  PR_ENABLED=""
  command -v jq >/dev/null 2>&1 || return 0

  local f acc="" cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  for f in "$cfg/settings.json" \
           "${CLAUDE_PROJECT_DIR:-.}/.claude/settings.json" \
           "${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json"; do
    [ -f "$f" ] || continue
    acc="$acc$(jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value != false) | .key | split("@")[0]' "$f" 2>/dev/null)
"
  done
  PR_ENABLED=$(printf '%s' "$acc" | grep -v '^[[:space:]]*$' | sort -u)

  # The settings govern only a PLUGINS_DIR under <config>: a scratch, vendored or second-marketplace tree keeps every plugin.
  case "${PLUGINS_DIR:-}/" in
    "$cfg"/*) ;;
    *) PR_ENABLED="" ;;
  esac
  return 0
}

# $1 plugin name → 0 when the plugin is enabled OR enablement is undeterminable.
pr_is_enabled() {
  [ -n "${PR_ENABLED:-}" ] || return 0
  printf '%s\n' "$PR_ENABLED" | grep -qxF -- "$1"
}

# $1 owning_plugin → 0 when the plugin is installed OR the layout is unknown.
pr_plugin_installed() {
  [ -z "${PLUGINS_DIR:-}" ] && return 0
  [ -d "$PLUGINS_DIR/$1" ] || return 1
  pr_is_enabled "$1" || return 1
  return 0
}

# $1 owning_plugin → prints its content root (holding skills/, commands/, agents/), or nothing; versioned, one level below the plugin dir.
pr_plugin_root() {
  [ -n "${PLUGINS_DIR:-}" ] || return 0
  local base="$PLUGINS_DIR/$1"
  [ -d "$base" ] || return 0

  if [ "${PLUGIN_LAYOUT:-flat}" != "versioned" ]; then
    printf '%s\n' "$base"
    return 0
  fi

  # `sort -V` is absent on some BSD userlands; the lexical fallback may pick 0.9.0 over 0.10.0, a worse guess but a real path.
  local pick
  pick=$(ls -1 "$base" 2>/dev/null | sort -V 2>/dev/null | tail -1)
  [ -n "$pick" ] || pick=$(ls -1 "$base" 2>/dev/null | sort | tail -1)
  [ -n "$pick" ] && [ -d "$base/$pick" ] || return 0
  printf '%s\n' "$base/$pick"
}

# Prints one line per installed plugin: `<plugin-name>\t<content-root>`.
pr_plugin_roots() {
  [ -n "${PLUGINS_DIR:-}" ] || return 0
  local d name root
  for d in "$PLUGINS_DIR"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    pr_is_enabled "$name" || continue
    root=$(pr_plugin_root "$name")
    [ -n "$root" ] || continue
    printf '%s\t%s\n' "$name" "$root"
  done
}
