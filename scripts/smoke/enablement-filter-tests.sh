#!/usr/bin/env bash
# Smoke tests for skill-router's ENABLEMENT filter (plugins-dir.sh).
#
# WHY THIS FILE EXISTS. pr_plugin_roots walks every directory under the resolved
# plugins root. On a real install that root is the versioned CACHE, which keeps
# every plugin ever installed — plugins later dropped from the marketplace, and
# bundles the user switched off. Version dedup ran over that list, and the stack
# filter ran over it; enablement never did. route-prompt.sh's catalog therefore
# advertised commands that cannot be invoked: 20 of 108 on the machine where this
# was found, 16 of them owned by plugins absent from marketplace.json.
#
# The failure was invisible to every existing harness because the fixtures build
# their plugin roots by mkdir and never write an enabledPlugins set at all — which
# is exactly the fail-open case, where filtering is correctly a no-op. A harness
# that only builds the undeterminable case cannot observe a filter.
#
# So both directions are asserted, and the suppression cases sit next to the
# firing ones: a "fix" that made the filter always suppress would pass the
# suppression tests and fail the fail-open ones, and vice versa.
#
# HONEST LIMIT: managed-policy settings are not read by the code under test and
# are not modelled here. See the header of plugins-dir.sh for why that is the one
# case where a live plugin can be suppressed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="$ROOT/plugins/skill-router/hooks/plugins-dir.sh"
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not available"; exit 0; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0

expect() { # $1 label, $2 actual, $3 expected
  if [ "$2" = "$3" ]; then
    printf '  ok   %s\n' "$1"
  else
    printf '  FAIL %s\n       expected: [%s]\n       actual:   [%s]\n' "$1" "$3" "$2"
    rc=1
  fi
}

# $1 config dir, $2 project dir, $3 plugin root -> space-separated plugin names
roots_for() {
  (
    PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"; PR_ENABLED=""
    export CLAUDE_CONFIG_DIR="$1" CLAUDE_PROJECT_DIR="$2" CLAUDE_PLUGIN_ROOT="$3"
    . "$LIB"
    pr_resolve_plugins_dir
    pr_plugin_roots | cut -f1 | sort | tr '\n' ' ' | sed 's/ $//'
  )
}

installed_for() { # $1 cfg, $2 proj, $3 plugin root, $4 name -> yes|no
  (
    PLUGINS_DIR=""; PLUGIN_LAYOUT="flat"; PR_ENABLED=""
    export CLAUDE_CONFIG_DIR="$1" CLAUDE_PROJECT_DIR="$2" CLAUDE_PLUGIN_ROOT="$3"
    . "$LIB"
    pr_resolve_plugins_dir
    if pr_plugin_installed "$4"; then echo yes; else echo no; fi
  )
}

# Each scenario gets its OWN config dir with the plugin tree INSIDE it, because
# the scope guard only applies the enabled set to trees under <config>. A fixture
# that puts the tree elsewhere tests the guard, not the filter — so the guard gets
# its own case at the end rather than silently making every other case vacuous.
mkcfg() { # $1 name, $2 settings-json ('' = write no file); echoes the config dir
  local c="$TMP/$1"
  mkdir -p "$c/plugins/mkt"/{alpha,beta,gamma}/commands
  [ -n "$2" ] && printf '%s\n' "$2" > "$c/settings.json"
  printf '%s' "$c"
}

echo "enablement filter — flat layout"
CFG=$(mkcfg cfg '{"enabledPlugins":{"alpha@mkt":true,"beta@mkt":false}}')
NOPROJ="$TMP/noproj"; mkdir -p "$NOPROJ"
expect "enabled plugin survives; false and absent are dropped" \
  "$(roots_for "$CFG" "$NOPROJ" "$CFG/plugins/mkt/alpha")" "alpha"
expect "pr_plugin_installed: enabled -> yes" \
  "$(installed_for "$CFG" "$NOPROJ" "$CFG/plugins/mkt/alpha" alpha)" "yes"
expect "pr_plugin_installed: explicitly false -> no" \
  "$(installed_for "$CFG" "$NOPROJ" "$CFG/plugins/mkt/alpha" beta)" "no"
expect "pr_plugin_installed: on disk but unlisted -> no" \
  "$(installed_for "$CFG" "$NOPROJ" "$CFG/plugins/mkt/alpha" gamma)" "no"

# ---- union across layers ----------------------------------------------------
PROJ2="$TMP/proj2"; mkdir -p "$PROJ2/.claude"
printf '{"enabledPlugins":{"gamma@mkt":true}}\n' > "$PROJ2/.claude/settings.json"
expect "project layer unions with user layer" \
  "$(roots_for "$CFG" "$PROJ2" "$CFG/plugins/mkt/alpha")" "alpha gamma"

PROJ3="$TMP/proj3"; mkdir -p "$PROJ3/.claude"
printf '{"enabledPlugins":{"beta@mkt":true}}\n' > "$PROJ3/.claude/settings.local.json"
expect "settings.local.json counts, and re-enables a user-scope false" \
  "$(roots_for "$CFG" "$PROJ3" "$CFG/plugins/mkt/alpha")" "alpha beta"

# ---- fail open --------------------------------------------------------------
echo "fail open — the filter must be a no-op when enablement is unreadable"
C1=$(mkcfg c_nofile '')
expect "no settings file -> every plugin kept" \
  "$(roots_for "$C1" "$NOPROJ" "$C1/plugins/mkt/alpha")" "alpha beta gamma"

C2=$(mkcfg c_nokey '{"permissions":{"allow":[]}}')
expect "settings.json without enabledPlugins -> every plugin kept" \
  "$(roots_for "$C2" "$NOPROJ" "$C2/plugins/mkt/alpha")" "alpha beta gamma"

C3=$(mkcfg c_bad 'not json at all')
expect "unparseable settings.json -> every plugin kept" \
  "$(roots_for "$C3" "$NOPROJ" "$C3/plugins/mkt/alpha")" "alpha beta gamma"

# A PATH with the coreutils this library uses but WITHOUT jq. Emptying PATH
# outright would also remove cut/sort/tr/sed and prove nothing about jq.
nojq="$TMP/nojq"; mkdir -p "$nojq"
for t in bash sh cut sort tr sed grep ls basename dirname mktemp rm; do
  src=$(command -v "$t" 2>/dev/null) && ln -sf "$src" "$nojq/$t"
done
expect "jq absent -> every plugin kept" \
  "$(PATH="$nojq" roots_for "$CFG" "$NOPROJ" "$CFG/plugins/mkt/alpha")" "alpha beta gamma"

# ---- scope guard ------------------------------------------------------------
# enabledPlugins describes the user's own install. A plugins tree OUTSIDE the
# config dir — a smoke fixture, a vendored checkout, a second marketplace — is not
# governed by it. Shipping the filter without this guard turned
# versioned-layout-tests.sh and route-marker-tests.sh red, which is what caught it.
echo "scope guard — settings govern only trees under the config dir"
OUT="$TMP/outside"; mkdir -p "$OUT"/{alpha,beta,gamma}/commands
expect "tree outside the config dir -> filter does not apply" \
  "$(roots_for "$CFG" "$NOPROJ" "$OUT/alpha")" "alpha beta gamma"

# ---- versioned layout -------------------------------------------------------
# The bug class this file guards against first shipped because a harness only
# built the flat layout. Assert the filter under the versioned layout too.
VCFG="$TMP/vcfg"; mkdir -p "$VCFG/plugins/mkt"/{alpha,beta,gamma}/0.1.0/commands
printf '{"enabledPlugins":{"alpha@mkt":true,"beta@mkt":false}}\n' > "$VCFG/settings.json"
echo "enablement filter — versioned layout"
expect "versioned: enabled plugin survives, others dropped" \
  "$(roots_for "$VCFG" "$NOPROJ" "$VCFG/plugins/mkt/alpha/0.1.0")" "alpha"
VNO="$TMP/vno"; mkdir -p "$VNO/plugins/mkt"/{alpha,beta,gamma}/0.1.0/commands
expect "versioned: fail open still keeps everything" \
  "$(roots_for "$VNO" "$NOPROJ" "$VNO/plugins/mkt/alpha/0.1.0")" "alpha beta gamma"

exit $rc
