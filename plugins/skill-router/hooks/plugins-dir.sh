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
  pr_load_enabled
  return 0
}

# ---- enablement -------------------------------------------------------------
# WHY THIS EXISTS. pr_plugin_roots walks every directory under PLUGINS_DIR. On a
# real install that root is the versioned CACHE, which keeps every plugin ever
# installed — including plugins later dropped from the marketplace and bundles the
# user switched off. Version dedup ran on that list and the stack filter ran on it;
# enablement never did. So route-prompt.sh's catalog advertised commands that
# cannot be invoked, at the exact surface where the model picks a tool. Measured on
# the machine this was found on: 20 of 108 advertised commands were unreachable,
# 16 of them owned by plugins no longer present in marketplace.json.
#
# FAIL OPEN, deliberately, and it is the same bias the rest of this file declares.
# PR_ENABLED stays EMPTY whenever enablement cannot be read — jq absent, no
# settings file, no enabledPlugins key — and an empty set filters nothing, which is
# byte-for-byte the previous behaviour. Only a plugin we can positively prove is
# not enabled gets suppressed.
#
# LAYERS. enabledPlugins is settable at user and project scope, so the set is the
# UNION of every file readable here. Reading one layer would suppress plugins that
# another layer legitimately enables. A key is `<name>@<marketplace>`; the
# marketplace half is dropped because every consumer here addresses plugins by
# bare name.
#
# HONEST LIMIT, stated rather than implied: managed-policy settings are not read.
# On a fleet that enables plugins ONLY through managed policy, some other layer
# will usually still list something, and those policy-enabled plugins would then be
# filtered out. That is the one case where this can suppress a live plugin, and it
# is why the union above is as wide as it is.
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

  # SCOPE GUARD, and it is the whole reason this is safe. `enabledPlugins`
  # describes the user's OWN install and nothing else. PLUGINS_DIR is not always
  # that tree: smoke harnesses build scratch roots under $TMPDIR, a vendored
  # checkout resolves here, and so does a second marketplace. Against those trees
  # the enabled set is not an authority, and applying it suppressed every row —
  # which is exactly how this was caught, by versioned-layout-tests.sh and
  # route-marker-tests.sh going red the first time the filter shipped without
  # this guard.
  #
  # So the settings under <config> govern only trees UNDER <config>. Anything
  # else falls back to the undeterminable path and keeps every plugin, which is
  # the previous behaviour. A name-overlap heuristic was tried first and is not
  # enough: a scratch tree that happens to contain one real plugin name would
  # activate the filter and then suppress every fixture-only sibling.
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
# "Fire-if-uncertain" is the router's declared bias: a nudge toward a plugin that
# turns out to be absent costs one line; a suppressed nudge costs the whole point
# of the router, which is exactly the failure this file was written for.
pr_plugin_installed() {
  [ -z "${PLUGINS_DIR:-}" ] && return 0
  [ -d "$PLUGINS_DIR/$1" ] || return 1
  pr_is_enabled "$1" || return 1
  return 0
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
    pr_is_enabled "$name" || continue
    root=$(pr_plugin_root "$name")
    [ -n "$root" ] || continue
    printf '%s\t%s\n' "$name" "$root"
  done
}
