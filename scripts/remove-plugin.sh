#!/usr/bin/env bash
# remove-plugin.sh <name> [--merge-into <host>] [--apply] — dry-run unless --apply: removes the plugin dir (skills move to the host under --merge-into), its marketplace entry, baseline keys and README row; rewrites the README leaf counts; regenerates the scout catalog and off-switch table; appends a removed-plugins.tsv row and a renames entry.
# The successor is the host only when it registers no blocking hook the plugin lacked, else null. Misses: rules.tsv, lane.tsv edges, smoke fixtures (the residual report prints them), version bumps, a deny only in a sourced file.
# Why, limits, history: rationale/derivations/scripts.md § scripts/remove-plugin.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required" >&2; exit 1; }
command -v shasum >/dev/null 2>&1 || { echo "FAIL: shasum is required (hook identity is a content hash)" >&2; exit 1; }

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
LEDGER=scripts/removed-plugins.tsv

pdir="plugins/$name"
[ -d "$pdir" ] || { echo "FAIL: $pdir does not exist" >&2; exit 2; }
jq -e 'type == "object" and (.plugins | type == "array") and ((.renames // {}) | type == "object")' "$MP" >/dev/null 2>&1 \
  || { echo "FAIL: $MP is not a JSON object with a .plugins array and an object .renames; nothing edited" >&2; exit 2; }
[ -w "$MP" ] && [ -w "$LEDGER" ] || { echo "FAIL: $MP or $LEDGER is not writable; nothing edited" >&2; exit 2; }
if jq -e --arg n "$name" '.renames // {} | has($n)' "$MP" >/dev/null; then
  echo "FAIL: $MP already has renames[\"$name\"]; renames is append-only, so it is not rewritten" >&2; exit 2
fi
if [ -n "$host" ]; then
  [ "$host" != "$name" ] || { echo "FAIL: --merge-into host is the plugin being removed" >&2; exit 2; }
  [ -d "plugins/$host" ] || { echo "FAIL: merge host plugins/$host does not exist" >&2; exit 2; }
  for sd in "$pdir"/skills/*/; do
    [ -d "$sd" ] || continue
    for clash in "plugins/$host/skills/$(basename "$sd")" "plugins/$host/commands/$(basename "$sd").md"; do
      if [ -e "$clash" ]; then echo "FAIL: $clash already exists" >&2; exit 2; fi
    done
  done
fi

say() { if [ "$apply" -eq 1 ]; then echo "edit: $1"; else echo "would: $1"; fi; }

# One sorted key per blocking hook: <Event>:<basename>:<hash>, <Event>:unresolved:<command>, or <Event>:<type>:<definition hash> for prompt/agent hooks.
blocking_hooks() {
  local hj="plugins/$1/hooks/hooks.json" ev type cmd def script key
  [ -f "$hj" ] || return 0
  jq -r '.hooks // {} | to_entries[] | .key as $e | .value[] | .hooks[]?
         | [$e, (.type // "command"), ((.command // "") | gsub("[\t\n\r]"; " ")), tojson] | join("\u001f")' "$hj" |
  while IFS=$'\x1f' read -r ev type cmd def; do
    script=$(printf '%s' "$cmd" | tr -d "\"'" | sed -E 's#^(bash|sh)[[:space:]]+##' | sed "s#\${CLAUDE_PLUGIN_ROOT}#plugins/$1#g")
    if [ -f "$script" ] && [ -r "$script" ]; then
      h=$(shasum < "$script") || exit 1
      key="$ev:$(basename "$script"):${h:0:12}"
    else
      key="$ev:unresolved:$script"
    fi
    case "$ev:$type" in
      *:prompt|*:agent) h=$(printf '%s' "$def" | shasum) || exit 1; echo "$ev:$type:${h:0:12}" ;;
      Stop:*|SubagentStop:*|PermissionRequest:*) echo "$key" ;;
      PreToolUse:*)
        if [ "$key" = "$ev:unresolved:$script" ] || grep -qE 'permissionDecision|exit 2([^0-9]|$)' "$script"; then
          echo "$key"
        fi ;;
    esac
  done | LC_ALL=C sort -u
}

succ=null
if [ -n "$host" ]; then
  removed_set=$(blocking_hooks "$name")
  host_set=$(blocking_hooks "$host")
  extra=$(LC_ALL=C comm -13 <(printf '%s\n' "$removed_set") <(printf '%s\n' "$host_set") | paste -sd ',' - | sed 's/,/, /g')
  if [ -z "$extra" ]; then
    succ="$host"
    reason="removed by remove-plugin.sh --merge-into $host; successor $host: host registers no blocking hook the removed plugin lacked"
  else
    reason="removed by remove-plugin.sh --merge-into $host; successor null: host registers $extra the removed plugin lacked"
  fi
else
  reason="removed by remove-plugin.sh; successor null: no --merge-into"
fi
if [ "$succ" = null ]; then succ_json=null; else succ_json="\"$succ\""; fi

mp_new=$(mktemp)
trap 'rm -f "$mp_new"' EXIT
jq --arg n "$name" --arg s "$succ" \
  '.plugins |= map(select(.name != $n)) | .renames[$n] = (if $s == "null" then null else $s end)' "$MP" > "$mp_new"

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

# 2. marketplace.json entry out and renames migration entry in (the file built above),
# then the removed-plugins ledger row
if jq -e --arg n "$name" '.plugins[] | select(.name==$n)' "$MP" >/dev/null; then
  say "$MP: remove plugin entry '$name'"
fi
say "$MP: renames[\"$name\"] = $succ_json"
row=$(printf '%s\t%s\t%s\tno\t%s' "$name" "$succ" "$(date -u +%F)" "$reason")
say "$LEDGER: append $row"
if [ "$apply" -eq 1 ]; then
  mv "$mp_new" "$MP"
  if [ -s "$LEDGER" ] && [ -n "$(tail -c1 "$LEDGER")" ]; then printf '\n' >> "$LEDGER"; fi
  printf '%s\n' "$row" >> "$LEDGER"
fi

# 3. the scout catalog is GENERATED from marketplace.json (generate.sh catalog
# step) — regenerate it instead of grep-editing a "do not edit" file.
if [ -f "$CAT" ] && grep -qw "$name" "$CAT"; then
  say "$CAT: regenerate via scripts/generate.sh --write (catalog step)"
  if [ "$apply" -eq 1 ]; then bash scripts/generate.sh --write >/dev/null; fi
fi

# 4. context-budget baseline keys — all three channels.
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
# Same regex shape as validate.sh's leaf-count gate, so this keeps maintaining every line that gate checks.
if grep -qE "(all [0-9]+ (leaf )?plugins|[0-9]+ leaf plugins)" README.md; then
  say "README.md: set '[all] N [leaf] plugins' counts to $leaves"
  if [ "$apply" -eq 1 ]; then
    tmp=$(mktemp)
    sed -E "s/(all )?[0-9]+ leaf plugins/\1$leaves leaf plugins/g; s/all [0-9]+ plugins/all $leaves plugins/g" README.md > "$tmp"
    mv "$tmp" README.md
  fi
fi

# Residual report: source references that still name the plugin
targets=$(jq -r --arg n "$name" '.renames // {} | to_entries[] | select(.value == $n) | .key' "$MP")
mp_re="^\./\.claude-plugin/marketplace\.json:[0-9]+: *\"$name\": "
if [ -n "$targets" ]; then
  if [ "$apply" -eq 1 ]; then verb="now continue"; else verb="would continue"; fi
  echo "renames entries targeting '$name': $(printf '%s\n' "$targets" | paste -sd ',' - | sed 's/,/, /g') — kept (append-only history); their chains $verb through renames[\"$name\"] = $succ_json"
  mp_re="$mp_re|^\./\.claude-plugin/marketplace\.json:[0-9]+: *\"($(printf '%s\n' "$targets" | paste -sd '|' -))\": \"$name\""
fi
echo "-- residual references (word-match; excluding .git, .claude, taskmaster-docs, CHANGELOG.md, removed-plugins.tsv, plugins/$name/, and renames entries naming '$name') --"
# The plugin's own dir is filtered by full path, not --exclude-dir basename, so a merged skill dir is still scanned; the ledger and renames history are dropped.
res=$(grep -rInw "$name" --exclude-dir=.git --exclude-dir=taskmaster-docs --exclude-dir=.claude --exclude=CHANGELOG.md --exclude=removed-plugins.tsv . 2>/dev/null \
  | grep -v "^\./plugins/$name/" | grep -vE "$mp_re" || true)
if [ -z "$res" ]; then
  echo "none"
else
  printf '%s\n' "$res" | head -40 || true
  n=$(printf '%s\n' "$res" | wc -l | tr -d ' ')
  if [ "$n" -gt 40 ]; then echo "... ($n total)"; fi
fi
if [ "$apply" -eq 1 ]; then
  echo "applied. run: bash scripts/validate.sh"
  echo "next: review prose_match in the new $LEDGER row for '$name' — it is 'no', so pc_removed_refs ignores the name; plug, moved or both makes it fail the name in reference shapes only (see that file's header)"
else
  echo "dry-run only. re-run with --apply to edit."
fi
exit 0
