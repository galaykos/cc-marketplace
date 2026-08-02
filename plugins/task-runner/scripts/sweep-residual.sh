#!/usr/bin/env bash
# Sweep-migration residual gate. Freezes the target set of an at-scale mechanical
# change, then RE-MEASURES it after the edits and fails while occurrences survive.
#
# WHY. Given "migrate every axios call to fetch" on a tree with twelve occurrences
# — three behind an aliased import, one built dynamically, one in a CI YAML, one in
# a test fixture — a competent model greps `axios.`, edits what it found, runs a
# green suite (the alias path has no test), and reports the migration complete. The
# failure is not knowledge. Nothing forces a SECOND measurement after the edits,
# and nothing demands that a surviving occurrence be justified in writing. This is
# that second measurement.
#
#   sweep-residual.sh --freeze  --id <id> --pattern <ere> [--dir DIR] [--glob EXT]…
#   sweep-residual.sh --measure --id <id> [--dir DIR]
#   sweep-residual.sh --allow   --id <id> --file PATH --reason "why"
#
# State: .claude/task-runner/sweep-<id>.json — the frozen file list, its git tree
# hash, the original count, the allowlist, and every measurement taken.
#
# Exit codes, mirroring negative-control.sh's vocabulary:
#   0  clean — zero unallowlisted residual
#   2  residual — occurrences survive with no allowlist entry
#   4  target set moved — files appeared or vanished since the freeze
#   5  cannot measure — no state file, no pattern, unreadable tree
#   3  usage error
#
# HONEST LIMITATIONS. The freeze records the file list and a tree hash, not file
# contents, so a file edited between freeze and measure is expected — that IS the
# work. Detection is one ERE over text: a call constructed entirely at runtime from
# pieces no regex spans is invisible here, which is exactly why the enumeration
# step below asks for FOUR passes rather than one, and why the allowlist demands a
# written reason instead of a suppression comment.
set -u
PROG=${0##*/}
usage() { printf '%s: usage error: %s\n' "$PROG" "$1" >&2; exit 3; }
halt()  { printf '%s: %s\n' "$PROG" "$1" >&2; exit 5; }

mode="" id="" pattern="" dir="." file="" reason=""
globs=""
while [ $# -gt 0 ]; do
  case "$1" in
    --freeze) mode=freeze; shift ;;
    --measure) mode=measure; shift ;;
    --allow) mode=allow; shift ;;
    --id) id="${2:-}"; shift 2 ;;
    --pattern) pattern="${2:-}"; shift 2 ;;
    --dir) dir="${2:-}"; shift 2 ;;
    --glob) globs="$globs ${2:-}"; shift 2 ;;
    --file) file="${2:-}"; shift 2 ;;
    --reason) reason="${2:-}"; shift 2 ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) usage "unknown argument $1" ;;
  esac
done

[ -n "$mode" ] || usage "one of --freeze / --measure / --allow is required"
[ -n "$id" ] || usage "--id is required"
command -v jq >/dev/null 2>&1 || halt "jq required"
[ -d "$dir" ] || halt "no such directory: $dir"

STATE_DIR="$dir/.claude/task-runner"
STATE="$STATE_DIR/sweep-$id.json"

# Non-code carriers are IN SCOPE on purpose. A migration that leaves the old name
# in a CI workflow, a fixture, a doc example or an i18n catalogue is not finished —
# and those are precisely the files a code-shaped grep skips.
default_find() {
  find "$dir" \
    \( -name node_modules -o -name vendor -o -name .git -o -name dist -o -name build \
       -o -name .venv -o -name target -o -name __pycache__ -o -name .claude \) -prune \
    -o -type f -print 2>/dev/null
}

occurrences() { # pattern -> "file:count" lines, non-binary only
  local pat="$1"
  default_find | while IFS= read -r f; do
    [ -f "$f" ] || continue
    grep -Iq . "$f" 2>/dev/null || continue          # skip binaries
    n=$(grep -cE "$pat" "$f" 2>/dev/null) || n=0
    [ "${n:-0}" -gt 0 ] && printf '%s\t%s\n' "$f" "$n"
  done
}

tree_hash() {
  if git -C "$dir" rev-parse >/dev/null 2>&1; then
    git -C "$dir" ls-files -s 2>/dev/null | cksum | awk '{print $1}'
  else
    default_find | sort | cksum | awk '{print $1}'
  fi
}

case "$mode" in
  freeze)
    [ -n "$pattern" ] || usage "--freeze requires --pattern"
    mkdir -p "$STATE_DIR" || halt "cannot create $STATE_DIR"
    hits=$(occurrences "$pattern")
    total=$(printf '%s' "$hits" | awk -F'\t' '{s+=$2} END {print s+0}')
    files=$(printf '%s' "$hits" | cut -f1 | jq -R . | jq -s .)
    [ -n "$files" ] || files='[]'
    jq -n --arg id "$id" --arg pat "$pattern" --arg th "$(tree_hash)" \
          --argjson files "$files" --argjson total "${total:-0}" \
      '{v:1,id:$id,pattern:$pat,tree_hash:$th,frozen_files:$files,original_total:$total,allowlist:[],measurements:[]}' \
      > "$STATE" || halt "cannot write $STATE"
    printf 'frozen: %s occurrence(s) across %s file(s) → %s\n' \
      "${total:-0}" "$(printf '%s' "$files" | jq 'length')" "$STATE"
    printf 'enumerate in FOUR passes before editing, not one: direct form; aliased,\n'
    printf 're-exported or barrel form; dynamic or string-constructed reference; and\n'
    printf 'non-code carriers (config, CI yaml, docs, fixtures, i18n keys). Anything a\n'
    printf 'single grep missed is invisible to this gate too.\n'
    exit 0 ;;

  allow)
    [ -f "$STATE" ] || halt "no frozen sweep: $STATE"
    [ -n "$file" ] || usage "--allow requires --file"
    [ -n "$reason" ] || usage "--allow requires --reason (an allowlist entry with no written reason is a suppression comment)"
    tmp=$(mktemp)
    jq --arg f "$file" --arg r "$reason" \
      '.allowlist += [{file:$f, reason:$r}]' "$STATE" > "$tmp" && mv "$tmp" "$STATE" || halt "cannot update $STATE"
    printf 'allowlisted: %s — %s\n' "$file" "$reason"
    exit 0 ;;

  measure)
    [ -f "$STATE" ] || halt "no frozen sweep: $STATE (run --freeze first)"
    pattern=$(jq -r '.pattern' "$STATE")
    [ -n "$pattern" ] && [ "$pattern" != null ] || halt "state file carries no pattern"
    orig=$(jq -r '.original_total' "$STATE")
    frozen_n=$(jq -r '.frozen_files | length' "$STATE")

    hits=$(occurrences "$pattern")
    total=$(printf '%s' "$hits" | awk -F'\t' '{s+=$2} END {print s+0}')

    # Residual minus allowlist.
    residual=0
    resid_files=""
    while IFS=$'\t' read -r f n; do
      [ -n "$f" ] || continue
      if jq -e --arg f "$f" '.allowlist | map(.file) | index($f)' "$STATE" >/dev/null 2>&1; then continue; fi
      residual=$((residual + n))
      resid_files="$resid_files  $f ($n)
"
    done <<EOF
$hits
EOF

    tmp=$(mktemp)
    jq --argjson t "${total:-0}" --argjson r "${residual:-0}" \
      '.measurements += [{total:$t, residual:$r}]' "$STATE" > "$tmp" && mv "$tmp" "$STATE"

    printf 'sweep %s: original %s → now %s (unallowlisted residual %s)\n' "$id" "$orig" "${total:-0}" "$residual"

    # Target set moved: new files carrying the pattern that were not frozen. A file
    # added mid-run is the case a one-shot grep cannot see at all.
    newfiles=""
    while IFS=$'\t' read -r f n; do
      [ -n "$f" ] || continue
      jq -e --arg f "$f" '.frozen_files | index($f)' "$STATE" >/dev/null 2>&1 || newfiles="$newfiles  $f
"
    done <<EOF
$hits
EOF
    if [ -n "$newfiles" ]; then
      printf 'TARGET SET MOVED — file(s) carrying the pattern appeared after the freeze:\n%s' "$newfiles"
      printf 're-freeze deliberately (--freeze again) rather than editing the state file.\n'
      exit 4
    fi

    if [ "$residual" -gt 0 ]; then
      printf 'RESIDUAL — occurrence(s) survive with no allowlist entry:\n%s' "$resid_files"
      printf 'either finish them, or record each survivor with:\n'
      printf '  %s --allow --id %s --file <path> --reason "<why it stays>"\n' "$PROG" "$id"
      exit 2
    fi

    printf 'clean: zero unallowlisted residual across %s frozen file(s).\n' "$frozen_n"
    exit 0 ;;
esac
