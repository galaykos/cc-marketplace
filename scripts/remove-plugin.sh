#!/usr/bin/env bash
# Remove a plugin (or fold its skills into a host plugin). Edits: the plugin dir, its
# marketplace.json entry, the plugin's key in all three context-budget baselines, its
# README table row and leaf counts, and — through one full generate.sh --write run —
# the plugin-scout catalog and the README off-switch table. Under --merge-into it moves
# the skill dirs to the host and drops the rest. It appends a scripts/removed-plugins.tsv
# row and a marketplace.json renames entry; the successor is the host only under
# --merge-into and only when the host registers no blocking hook (as that TSV's header
# defines it) the removed plugin lacked, else null — a renames successor is installed
# without asking. Command hooks compare by event, script basename and content hash, so
# only an identical script cancels; prompt/agent hooks by event and definition; matchers
# are ignored. A PreToolUse script counts when it contains permissionDecision or `exit 2`,
# so a deny emitted only from a file it sources is missed; a command that does not resolve
# to a readable file after quote-stripping and ${CLAUDE_PLUGIN_ROOT} substitution (a
# `bash …` wrapper, unbraced $CLAUDE_PLUGIN_ROOT, an inline command, an empty one) counts
# as blocking. The row's removed column is the run date (UTC): correct it to the deleting
# commit's date if they differ. Its prose_match is `no`: flipping it to plug/moved/both,
# which makes pc_removed_refs flag the name in prose, is a reviewed edit of the TSV.
# Existing renames entries are append-only history and never edited; any that target the
# removed plugin are printed. marketplace.json is validated and its new content built
# before anything is deleted.
# Does NOT edit skill-router's rules.tsv, other plugins' lane.tsv edges or smoke fixtures
# (the report prints the first 40 word-match lines, which may name them), bump stack-scan's
# plugin.json and CHANGELOG for the regenerated catalog, or, under --merge-into, bump the
# host's plugin.json and CHANGELOG or re-baseline its context budget. Dry-run by default;
# edits only with --apply. validate.sh is the recovery gate after a partial failure.
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

# Prints one key per blocking hook registration, sorted: <Event>:<basename>:<hash> for a
# command resolving to a readable file, <Event>:unresolved:<command> for any other
# command, <Event>:<type>:<hash of the hook definition> for prompt/agent hooks.
blocking_hooks() {
  local hj="plugins/$1/hooks/hooks.json" ev type cmd def script key
  [ -f "$hj" ] || return 0
  jq -r '.hooks // {} | to_entries[] | .key as $e | .value[] | .hooks[]?
         | [$e, (.type // "command"), ((.command // "") | gsub("[\t\n\r]"; " ")), tojson] | join("\u001f")' "$hj" |
  while IFS=$'\x1f' read -r ev type cmd def; do
    script=$(printf '%s' "$cmd" | tr -d "\"'" | sed "s#\${CLAUDE_PLUGIN_ROOT}#plugins/$1#g")
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
targets=$(jq -r --arg n "$name" '.renames // {} | to_entries[] | select(.value == $n) | .key' "$MP")
mp_re="^\./\.claude-plugin/marketplace\.json:[0-9]+: *\"$name\": "
if [ -n "$targets" ]; then
  if [ "$apply" -eq 1 ]; then verb="now continue"; else verb="would continue"; fi
  echo "renames entries targeting '$name': $(printf '%s\n' "$targets" | paste -sd ',' - | sed 's/,/, /g') — kept (append-only history); their chains $verb through renames[\"$name\"] = $succ_json"
  mp_re="$mp_re|^\./\.claude-plugin/marketplace\.json:[0-9]+: *\"($(printf '%s\n' "$targets" | paste -sd '|' -))\": \"$name\""
fi
echo "-- residual references (word-match; excluding .git, .claude, taskmaster-docs, CHANGELOG.md, removed-plugins.tsv, plugins/$name/, and renames entries naming '$name') --"
# Filter the plugin's own dir by full path, not --exclude-dir basename — after
# --merge-into, the moved skill dir plugins/<host>/skills/<name>/ must still be
# scanned or real residuals inside the merged skill body stay hidden. The ledger row and
# the renames entries naming the plugin are dropped: this list is what a person rewrites,
# and those are append-only history.
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
