#!/usr/bin/env bash
# sync-plan.sh — the scope arithmetic behind `/stack-scan:suggest --sync`. Given the
# scout's recommended set for this project, it reads the three settings files the CLI
# merges for `enabledPlugins` (user, then project, then local — later wins) and prints
# one TSV row per plugin of this marketplace: what --sync should do with it, at which
# scope, and the exact command that does it. Read-only: it never runs `claude`; the
# skill renders the plan, asks, and runs the command column.
#
# Why a script: the precedence is where prose went wrong. A plugin enabled at user
# scope looks "installed" from every project, so the scout's picker offered nothing in
# a repo that relied on user scope; a `false` in .claude/settings.local.json beats a
# user-scope `true`; local scope is one checkout's path, so a linked worktree starts
# bare. Each of those is a row class below with a harness case behind it.
#
# Usage: sync-plan.sh [--persist] [--root DIR] [--catalog FILE] [--] NAME...
#   NAME       the scout's recommended set (tier 1 fired + tier 2 core). stack-scan is
#              always added: a project moved off user scope must keep the tool that
#              manages it.
#   --persist  target scope project (.claude/settings.json) instead of local.
#   --root     the project root (default: .).
#   --catalog  the marketplace's plugin list (default: this plugin's generated
#              skills/plugin-scout/references/catalog.md).
#
# Output: class<TAB>name<TAB>scope<TAB>command, `-` for no command, sorted by class:
#   add          recommended, enabled nowhere            → install at the target scope
#   move         recommended, enabled only at user scope → install at the target scope
#   held         recommended, but a settings file says false → never re-enabled
#   extra        enabled at local/project, not recommended → uninstall at that scope;
#                a project-scope extra gets a command only under --persist (that file is
#                the team's)
#   duplicate    a local copy of a project-scope entry, recommended or not → uninstall
#                the local copy (the project entry still enables it, so removing the
#                copy changes nothing but the record)
#   ok           recommended and enabled at local or project — nothing to do
#   machine-wide not recommended, enabled only at user scope — left alone (other
#                projects may rely on it)
#   unknown      enabled, but not in the catalog: removed from the marketplace, or newer
#                than this stack-scan
#   note         worktree: a linked git worktree under a local target (local scope is
#                this path only; --persist writes the file every worktree checks out)
#   offramp      user scope still enables this marketplace's plugins; name = how many,
#                command = the one-shot user-scope removal, printed, never run here
#
# Exit: 0 plan printed (possibly empty); 2 bad argument, no jq, a NAME the catalog does
# not list, or a settings file that exists and is not a JSON object — a plan built on a
# misread file would install or remove the wrong set.
#
# Residual: reads neither managed policy settings, a --settings file nor a --plugin-dir
# load (the same three all-plugins' hint.sh skips), and not the install records — a
# project-scope `true` for a plugin this machine never installed classes as enabled.
set -u

M=cc-plugins-marketplace
here="$(cd "$(dirname "$0")" && pwd)"
ROOT=.
PERSIST=0
CATALOG="$here/../skills/plugin-scout/references/catalog.md"
names=()

die() { printf 'sync-plan: %s\n' "$1" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --persist) PERSIST=1 ;;
    --root) [ $# -ge 2 ] || die "--root needs a directory"; ROOT="$2"; shift ;;
    --catalog) [ $# -ge 2 ] || die "--catalog needs a file"; CATALOG="$2"; shift ;;
    --) shift; names+=("$@"); break ;;
    -*) die "unknown flag '$1'" ;;
    *) names+=("$1") ;;
  esac
  shift
done

command -v jq >/dev/null 2>&1 || die "jq is not on PATH"
[ -d "$ROOT" ] || die "no such project root '$ROOT'"
[ -r "$CATALOG" ] || die "catalog not readable: $CATALOG"

TARGET=local; [ "$PERSIST" -eq 1 ] && TARGET=project
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
U="$CFG/settings.json"; P="$ROOT/.claude/settings.json"; L="$ROOT/.claude/settings.local.json"

for f in "$U" "$P" "$L"; do
  [ -e "$f" ] || continue
  jq -e 'type == "object"' "$f" >/dev/null 2>&1 || die "not a JSON object: $f — fix it before syncing; nothing was planned"
done

catalog=$(sed -n 's/^\([a-z0-9][a-z0-9-]*\) — \[.*/\1/p' "$CATALOG" | jq -R . | jq -sc .)
[ "$catalog" != "[]" ] || die "no plugin rows in $CATALOG"
for n in ${names[@]+"${names[@]}"}; do
  printf '%s' "$catalog" | jq -e --arg n "$n" 'index($n) != null' >/dev/null || die "'$n' is not a plugin in $CATALOG"
done
rec=$( { printf '%s\n' stack-scan; for n in ${names[@]+"${names[@]}"}; do printf '%s\n' "$n"; done; } | jq -R . | jq -sc 'unique')

scope_json() { # settings file → {"<name>": true|false} for this marketplace's keys
  [ -e "$1" ] || { printf '{}'; return; }
  jq -c --arg m "@$M" '(.enabledPlugins // {})
    | if type == "object" then with_entries(select((.key | endswith($m)) and (.value | type == "boolean")) | .key |= rtrimstr($m)) else {} end' "$1"
}

jq -rn --argjson u "$(scope_json "$U")" --argjson p "$(scope_json "$P")" --argjson l "$(scope_json "$L")" \
  --argjson rec "$rec" --argjson cat "$catalog" --arg t "$TARGET" --arg m "$M" '
  def cmd($verb; $s): "claude plugin \($verb) \(.)@\($m) --scope \($s)";
  def r($c; $n; $s; $k): {c: $c, n: $n, s: $s, k: $k};
  def rank: {"add":0,"move":1,"held":2,"extra":3,"duplicate":4,"ok":5,"machine-wide":6,"unknown":7}[.];
  [ ([$u, $p, $l | keys[]] + $rec | unique)[] as $n
    | $u[$n] as $U | $p[$n] as $P | $l[$n] as $L
    | (if $L != null then $L elif $P != null then $P else $U end) as $eff
    | if ($cat | index($n)) == null then
        (if $eff == true then r("unknown"; $n; (if $L == true then "local" elif $P == true then "project" else "user" end); "-") else empty end)
      elif ($rec | index($n)) != null then
        if $eff == false then r("held"; $n; (if $L == false then "local" elif $P == false then "project" else "user" end); "-")
        elif $t == "local" then
          if $L == true or $P == true then
            r("ok"; $n; (if $P == true then "project" else "local" end); "-"),
            (if $L == true and $P == true then r("duplicate"; $n; "local"; ($n | cmd("uninstall"; "local"))) else empty end)
          elif $U == true then r("move"; $n; "local"; ($n | cmd("install"; "local")))
          else r("add"; $n; "local"; ($n | cmd("install"; "local"))) end
        else
          if $P == true then
            r("ok"; $n; "project"; "-"),
            (if $L == true then r("duplicate"; $n; "local"; ($n | cmd("uninstall"; "local"))) else empty end)
          elif $L == true then
            r("add"; $n; "project"; ($n | cmd("install"; "project"))),
            r("duplicate"; $n; "local"; ($n | cmd("uninstall"; "local")))
          elif $U == true then r("move"; $n; "project"; ($n | cmd("install"; "project")))
          else r("add"; $n; "project"; ($n | cmd("install"; "project"))) end
        end
      elif $eff != true then empty
      else
        (if $L == true then r((if $P == true then "duplicate" else "extra" end); $n; "local"; ($n | cmd("uninstall"; "local"))) else empty end),
        (if $P == true then r("extra"; $n; "project"; (if $t == "project" then ($n | cmd("uninstall"; "project")) else "-" end)) else empty end),
        (if $L != true and $P != true then r("machine-wide"; $n; "user"; "-") else empty end)
      end
  ] | sort_by((.c | rank), .n)[] | [.c, .n, .s, .k] | @tsv' || die "jq failed to classify the settings files"

in_linked_worktree() {
  local g c
  g=$(git -C "$ROOT" rev-parse --git-dir 2>/dev/null) || return 1
  c=$(git -C "$ROOT" rev-parse --git-common-dir 2>/dev/null) || return 1
  g=$(cd "$ROOT" && cd "$g" && pwd -P) || return 1
  c=$(cd "$ROOT" && cd "$c" && pwd -P) || return 1
  [ "$g" != "$c" ]
}
if [ "$TARGET" = local ] && command -v git >/dev/null 2>&1 && in_linked_worktree; then
  printf 'note\tworktree\tlocal\t-\n'
fi

user_on=$(scope_json "$U" | jq '[.[] | select(. == true)] | length')
if [ "$user_on" -gt 0 ]; then
  printf 'offramp\t%s\tuser\tbash "%s/plugins/marketplaces/%s/plugins/all-plugins/scripts/all-plugins.sh" uninstall --scope user --self\n' \
    "$user_on" "$CFG" "$M"
fi
exit 0
