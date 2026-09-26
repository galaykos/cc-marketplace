#!/usr/bin/env bash
# Remove a plugin (or fold its skills into a host plugin) and update every shared
# touchpoint: marketplace.json, plugin-scout catalog, context-budget baseline, README
# counts + table rows. Dry-run by default; edits only with --apply. Prints a
# residual-reference report either way; validate.sh is the recovery gate after a
# partial failure.
#
# No bundle branches. The all-in bundle went 2026-08-31 and the four themed suites
# 2026-09-26, the day pc_plugin_dependencies started failing any plugin.json that
# declares `dependencies` — so every plugin is a leaf and there is no bundle's dep
# list, README row or member count left for this script to maintain.
#
#   bash scripts/remove-plugin.sh <name> [--merge-into <host>] [--apply]
set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }

name="${1:-}"
[ -n "$name" ] || { echo "usage: remove-plugin.sh <name> [--merge-into <host>] [--apply]" >&2; exit 2; }
shift
host=""
apply=0
while [ $# -gt 0 ]; do
  case "$1" in
    --merge-into) host="${2:-}"; [ -n "$host" ] || { echo "FAIL: --merge-into needs a host name" >&2; exit 2; }; shift 2 ;;
    --apply) apply=1; shift ;;
    *) echo "FAIL: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

MP=.claude-plugin/marketplace.json
CAT=plugins/stack-scan/skills/plugin-scout/references/catalog.md
BASELINE=scripts/context-budget-baseline.json

pdir="plugins/$name"
[ -d "$pdir" ] || { echo "FAIL: $pdir does not exist" >&2; exit 2; }
if [ -n "$host" ]; then
  [ -d "plugins/$host" ] || { echo "FAIL: merge host plugins/$host does not exist" >&2; exit 2; }
  for sd in "$pdir"/skills/*/; do
    [ -d "$sd" ] || continue
    [ -e "plugins/$host/skills/$(basename "$sd")" ] \
      && { echo "FAIL: plugins/$host/skills/$(basename "$sd") already exists" >&2; exit 2; }
  done
fi

say() { if [ "$apply" -eq 1 ]; then echo "edit: $1"; else echo "would: $1"; fi; }

# 1. plugin dir (and skill moves under --merge-into). Non-skill functional files
# are DROPPED by design (merged commands are absorbed by the host) — but say so.
if [ -n "$host" ]; then
  for sd in "$pdir"/skills/*/; do
    [ -d "$sd" ] || continue
    say "move $sd -> plugins/$host/skills/$(basename "$sd")/"
    if [ "$apply" -eq 1 ]; then mkdir -p "plugins/$host/skills"; mv "$sd" "plugins/$host/skills/$(basename "$sd")"; fi
  done
  for df in "$pdir"/commands/*.md "$pdir"/agents/*.md "$pdir"/hooks/*; do
    [ -e "$df" ] || continue
    echo "drop: $df (non-skill artifact — absorb its capability in the host explicitly)"
  done
fi
say "delete $pdir/"
if [ "$apply" -eq 1 ]; then rm -rf "$pdir"; fi

# 2. marketplace.json entry
if jq -e --arg n "$name" '.plugins[] | select(.name==$n)' "$MP" >/dev/null; then
  say "$MP: remove plugin entry '$name'"
  if [ "$apply" -eq 1 ]; then
    tmp=$(mktemp); jq --arg n "$name" '.plugins |= map(select(.name != $n))' "$MP" > "$tmp"; mv "$tmp" "$MP"
  fi
fi

# 3. the scout catalog is GENERATED from marketplace.json (generate.sh catalog
# step) — regenerate it instead of grep-editing a "do not edit" file.
if [ -f "$CAT" ] && grep -qw "$name" "$CAT"; then
  say "$CAT: regenerate via scripts/generate.sh --write (catalog step)"
  if [ "$apply" -eq 1 ]; then bash scripts/generate.sh --write >/dev/null; fi
fi

# 4. context-budget baseline keys — all three channels. Only the always-on file was
# edited until 2026-09-26; the suite retirement had to strip the dynamic and activated
# baselines by hand, and a stale key there is dead weight --update-baseline would
# silently drop anyway.
for bl in "$BASELINE" scripts/context-budget-dynamic-baseline.json scripts/context-budget-activated-baseline.json; do
  if [ -f "$bl" ] && jq -e --arg n "$name" 'has($n)' "$bl" >/dev/null; then
    say "$bl: remove key '$name'"
    if [ "$apply" -eq 1 ]; then
      tmp=$(mktemp); jq --arg n "$name" 'del(.[$n])' "$bl" > "$tmp"; mv "$tmp" "$bl"
    fi
  fi
done

# 5. README table rows naming the plugin as first cell (backtick, bold, or
# linked-bold **[name](path)** forms)
row_re="^\| *(\`$name\`|\*\*$name\*\*|\*\*\[$name\]\([^)]*\)\*\*) *\|"
for rd in README.md; do
  [ -f "$rd" ] || continue
  if grep -qE "$row_re" "$rd"; then
    say "$rd: remove table row for '$name'"
    if [ "$apply" -eq 1 ]; then
      tmp=$(mktemp); grep -vE "$row_re" "$rd" > "$tmp"; mv "$tmp" "$rd"
    fi
  fi
done

# 6. README leaf-count integers ("all N plugins" / "N leaf plugins" prose). Every
# plugin is a leaf, so the count is every plugin dir.
leaves=0
for pj in plugins/*/.claude-plugin/plugin.json; do
  [ -f "$pj" ] || continue
  leaves=$((leaves + 1))
done
[ "$apply" -eq 1 ] || leaves=$((leaves - 1))   # dry-run: dir still present
# Same regex shape as scripts/validate.sh's leaf-count gate — both must see "all N
# plugins", "all N leaf plugins" AND "N leaf plugins", or this script stops maintaining
# the very lines that gate checks. The bare "all N plugins" expression cannot match the
# leaf wording (" plugins" must follow the digits), which is the exact miss that once let
# the count go stale under a gate written to catch it.
if grep -qE "(all [0-9]+ (leaf )?plugins|[0-9]+ leaf plugins)" README.md; then
  say "README.md: set '[all] N [leaf] plugins' counts to $leaves"
  if [ "$apply" -eq 1 ]; then
    tmp=$(mktemp)
    sed -E "s/(all )?[0-9]+ leaf plugins/\1$leaves leaf plugins/g; s/all [0-9]+ plugins/all $leaves plugins/g" README.md > "$tmp"
    mv "$tmp" README.md
  fi
fi

# Residual report: source references that still name the plugin
echo "-- residual references (word-match, excluding .git/CHANGELOG/taskmaster-docs) --"
# Filter the plugin's own dir by full path, not --exclude-dir basename — after
# --merge-into, the moved skill dir plugins/<host>/skills/<name>/ must still be
# scanned or real residuals inside the merged skill body stay hidden.
res=$(grep -rInw "$name" --exclude-dir=.git --exclude-dir=taskmaster-docs --exclude-dir=.claude --exclude=CHANGELOG.md . 2>/dev/null | grep -v "^\./plugins/$name/" || true)
if [ -z "$res" ]; then
  echo "none"
else
  printf '%s\n' "$res" | head -40 || true
  n=$(printf '%s\n' "$res" | wc -l | tr -d ' ')
  if [ "$n" -gt 40 ]; then echo "... ($n total)"; fi
fi
if [ "$apply" -eq 1 ]; then echo "applied. run: bash scripts/validate.sh"; else echo "dry-run only. re-run with --apply to edit."; fi
exit 0
