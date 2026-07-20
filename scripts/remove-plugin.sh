#!/usr/bin/env bash
# Remove a plugin (or fold its skills into a host plugin) and update every shared
# touchpoint: marketplace.json, everything-bundle deps, plugin-scout catalog,
# context-budget baseline, README counts + table rows. Dry-run by default; edits
# only with --apply. Prints a residual-reference report either way; validate.sh
# is the recovery gate after a partial failure.
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
EV=plugins/everything/.claude-plugin/plugin.json
CAT=plugins/plugin-scout/skills/plugin-scout/references/catalog.md
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

is_bundle=0
jq -e 'has("dependencies")' "$pdir/.claude-plugin/plugin.json" >/dev/null 2>&1 && is_bundle=1

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

# 3. everything-bundle dependency (leaves only; bundles are never deps)
if [ "$is_bundle" -eq 0 ] && [ -f "$EV" ] && jq -e --arg n "$name" '.dependencies | index($n)' "$EV" >/dev/null 2>&1; then
  say "$EV: remove dependency '$name'"
  if [ "$apply" -eq 1 ]; then
    tmp=$(mktemp); jq --arg n "$name" '.dependencies |= map(select(. != $n))' "$EV" > "$tmp"; mv "$tmp" "$EV"
  fi
fi

# 4. plugin-scout catalog is GENERATED from marketplace.json (generate.sh catalog
# step) — regenerate it instead of grep-editing a "do not edit" file.
if [ -f "$CAT" ] && grep -qw "$name" "$CAT"; then
  say "$CAT: regenerate via scripts/generate.sh --write (catalog step)"
  if [ "$apply" -eq 1 ]; then bash scripts/generate.sh --write >/dev/null; fi
fi

# 5. context-budget baseline key
if [ -f "$BASELINE" ] && jq -e --arg n "$name" 'has($n)' "$BASELINE" >/dev/null; then
  say "$BASELINE: remove key '$name'"
  if [ "$apply" -eq 1 ]; then
    tmp=$(mktemp); jq --arg n "$name" 'del(.[$n])' "$BASELINE" > "$tmp"; mv "$tmp" "$BASELINE"
  fi
fi

# 6. README table rows naming the plugin as first cell (backtick, bold, or
# linked-bold **[name](path)** forms)
row_re="^\| *(\`$name\`|\*\*$name\*\*|\*\*\[$name\]\([^)]*\)\*\*) *\|"
for rd in README.md plugins/everything/README.md; do
  [ -f "$rd" ] || continue
  if grep -qE "$row_re" "$rd"; then
    say "$rd: remove table row for '$name'"
    if [ "$apply" -eq 1 ]; then
      tmp=$(mktemp); grep -vE "$row_re" "$rd" > "$tmp"; mv "$tmp" "$rd"
    fi
  fi
done

# 7. README leaf-count integers ("all N plugins" prose + the everything bundle-table
# row) — leaves only. Other bundles listing the leaf get a warning, not an edit.
if [ "$is_bundle" -eq 0 ]; then
  leaves=0
  for pj in plugins/*/.claude-plugin/plugin.json; do
    jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 && continue
    leaves=$((leaves + 1))
  done
  [ "$apply" -eq 1 ] || leaves=$((leaves - 1))   # dry-run: dir still present
  if grep -qE "all [0-9]+ plugins" README.md; then
    say "README.md: set 'all N plugins' counts to $leaves"
    if [ "$apply" -eq 1 ]; then
      tmp=$(mktemp); sed -E "s/all [0-9]+ plugins/all $leaves plugins/g" README.md > "$tmp"; mv "$tmp" README.md
    fi
  fi
  if grep -qE '^\| *`everything` *\| *[0-9]+ *\|' README.md; then
    say "README.md: set everything bundle-table count to $leaves"
    if [ "$apply" -eq 1 ]; then
      tmp=$(mktemp); sed -E "s/^(\| *\`everything\` *\| *)[0-9]+( *\|)/\1$leaves\2/" README.md > "$tmp"; mv "$tmp" README.md
    fi
  fi
  for pj in plugins/*/.claude-plugin/plugin.json; do
    jq -e 'has("dependencies")' "$pj" >/dev/null 2>&1 || continue
    bn=$(jq -r .name "$pj")
    [ "$bn" = "everything" ] && continue
    jq -e --arg n "$name" '.dependencies | index($n)' "$pj" >/dev/null 2>&1 \
      && echo "WARN: bundle '$bn' lists '$name' — update its deps + README suite-table count manually"
  done
  if grep -qE '\([0-9]+ today\)' plugins/everything/README.md 2>/dev/null; then
    say "plugins/everything/README.md: set '(N today)' count to $leaves"
    if [ "$apply" -eq 1 ]; then
      tmp=$(mktemp); sed -E "s/\([0-9]+ today\)/($leaves today)/" plugins/everything/README.md > "$tmp"; mv "$tmp" plugins/everything/README.md
    fi
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
