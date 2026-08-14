# Layout-agnostic resolution of the installed-plugins root. Sourced by prime.sh,
# route.sh and route-prompt.sh — the three hooks that need to see SIBLING plugins.
# Not executable and has no shebang: it is only ever sourced.
#
# WHY THIS EXISTS. All three hooks used `dirname "$CLAUDE_PLUGIN_ROOT"`, which is
# the plugins root only under a FLAT layout (`<plugins>/<plugin>`). A real install
# is VERSIONED (`<marketplace>/<plugin>/<version>`), so dirname landed on
# `<marketplace>/<plugin>`, whose only children are version directories. Every
# `[ -d "$plugins_dir/<sibling>" ]` check then reported the sibling missing, the
# installed-filter suppressed every rule, and `route-prompt.sh`'s catalog glob
# matched nothing — the router was silent on every real install. The smoke
# fixtures build a flat layout by construction, so CI stayed green throughout.
# Both layouts are now resolved, and `versioned-layout-tests.sh` runs the whole
# suite a second time against a versioned fixture so this cannot regress silently.
#
# DETECTION IS ONE RULE: `CLAUDE_PLUGIN_ROOT`'s basename is version-shaped
# (`0.10.0`, `v1.2`, `2`) → versioned, the root is two levels up; anything else →
# flat, one level up. It needs neither a plugin.json nor a probe of sibling
# directories, so it holds on a partially populated cache and on a checkout whose
# siblings are bare directories. No plugin is named like a bare version number.
#
# RESIDUAL, stated rather than implied: the cache keeps every version ever
# installed (6 of skill-router on the machine this was found on) and nothing on
# disk marks which one is enabled. `pr_plugin_root` returns the highest version it
# can order, which is a guess — a good one, and the callers only use it to name a
# path they have already confirmed exists. It is not a claim about which version
# Claude Code loaded.

# Sets PLUGINS_DIR (empty when undeterminable) and PLUGIN_LAYOUT (flat|versioned).
# Empty PLUGINS_DIR is the fire-if-uncertain case every caller already handles:
# route.sh and prime.sh surface the skill anyway, route-prompt.sh skips its
# catalog. Both are the safe direction for their respective jobs.
pr_resolve_plugins_dir() {
  PLUGINS_DIR=""
  PLUGIN_LAYOUT="flat"
  [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || return 0

  local self parent
  self=$(basename "$CLAUDE_PLUGIN_ROOT" 2>/dev/null) || return 0
  case "$self" in
    [0-9]*|v[0-9]*)
      # Version-shaped: reject anything with a character a version cannot carry,
      # so a plugin named `2fa-helper` stays on the flat branch.
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
  return 0
}

# $1 owning_plugin → 0 when the plugin is installed OR the layout is unknown.
# "Fire-if-uncertain" is the router's declared bias: a nudge toward a plugin that
# turns out to be absent costs one line; a suppressed nudge costs the whole point
# of the router, which is exactly the failure this file was written for.
pr_plugin_installed() {
  [ -z "${PLUGINS_DIR:-}" ] && return 0
  [ -d "$PLUGINS_DIR/$1" ] && return 0
  return 1
}

# $1 owning_plugin → prints that plugin's CONTENT root (the directory holding
# skills/, commands/, agents/), or nothing. Under the versioned layout that is one
# level deeper than the plugin directory, which is why callers cannot just join
# paths onto PLUGINS_DIR themselves.
pr_plugin_root() {
  [ -n "${PLUGINS_DIR:-}" ] || return 0
  local base="$PLUGINS_DIR/$1"
  [ -d "$base" ] || return 0

  if [ "${PLUGIN_LAYOUT:-flat}" != "versioned" ]; then
    printf '%s\n' "$base"
    return 0
  fi

  # Highest version wins. `sort -V` is not POSIX and is absent on some BSD
  # userlands; a lexical sort can pick 0.9.0 over 0.10.0, which is a valid
  # installed version and a worse guess, never a broken path.
  local pick
  pick=$(ls -1 "$base" 2>/dev/null | sort -V 2>/dev/null | tail -1)
  [ -n "$pick" ] || pick=$(ls -1 "$base" 2>/dev/null | sort | tail -1)
  [ -n "$pick" ] && [ -d "$base/$pick" ] || return 0
  printf '%s\n' "$base/$pick"
}

# Prints one line per installed plugin: `<plugin-name>\t<content-root>`.
# Exactly one line per plugin whatever the layout — a versioned cache holding six
# releases of one plugin must not put six copies of its commands in a catalog.
pr_plugin_roots() {
  [ -n "${PLUGINS_DIR:-}" ] || return 0
  local d name root
  for d in "$PLUGINS_DIR"/*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    root=$(pr_plugin_root "$name")
    [ -n "$root" ] || continue
    printf '%s\t%s\n' "$name" "$root"
  done
}
