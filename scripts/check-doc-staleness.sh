#!/usr/bin/env bash
# Warn-only staleness check for vendored doc digests (hybrid digest +
# fetch-verify strategy). Scans */references/*.md under a root for the
# machine-parsable stamp, expected within the first 6 lines of a digest:
#
#   > Last verified: YYYY-MM-DD — <root doc URL>[ — npm:<package>@<major>]
#
# and prints a warning for any digest whose stamp is older than the threshold.
# Reference files with no stamp are hand-written skill material, not
# doc-derived — silently ignored. NEVER blocks: exits 0 on every path,
# including after warnings (warn-only by contract, spec A2); the CI step adds
# continue-on-error as belt and braces. Runnable locally:
#   bash scripts/check-doc-staleness.sh [--days N] [--path DIR] [--live]
#     --days N    staleness threshold in days (default 90)
#     --path DIR  scan root (default plugins/)
#     --live      also compare npm:<pkg>@<major> stamps against the live npm
#                 major; npm/network errors print an info line, never warn
set -u
cd "$(dirname "$0")/.." || exit 0

days=90
root="plugins/"
live=0
while [ $# -gt 0 ]; do
  case "$1" in
    --days) [ $# -ge 2 ] || { echo "info: --days needs a value" >&2; break; }; days="$2"; shift 2 ;;
    --path) [ $# -ge 2 ] || { echo "info: --path needs a value" >&2; break; }; root="$2"; shift 2 ;;
    --live) live=1; shift ;;
    *) echo "info: unknown flag '$1' (usage: [--days N] [--path DIR] [--live])" >&2; shift ;;
  esac
done

case "$days" in
  ''|*[!0-9]*) echo "info: non-numeric --days '$days' — using 90" >&2; days=90 ;;
esac
if [ ! -d "$root" ]; then
  echo "info: scan root '$root' not found — nothing to scan" >&2
  exit 0
fi

now=$(date +%s)

# Epoch for a YYYY-MM-DD on both GNU date (ubuntu CI) and BSD date (darwin
# dev). GNU accepts -d <date>; BSD needs -j -f <fmt> — detect once, branch.
if date -u -d '1970-01-01' +%s >/dev/null 2>&1; then date_is_gnu=1; else date_is_gnu=0; fi
to_epoch() {
  if [ "$date_is_gnu" -eq 1 ]; then
    date -d "$1" +%s 2>/dev/null
  else
    # BSD date normalizes impossible dates (2026-02-31 → 2026-03-03); reject
    # unless the parsed date round-trips to the input.
    [ "$(date -j -f "%Y-%m-%d" "$1" +%Y-%m-%d 2>/dev/null)" = "$1" ] || return 0
    date -j -f "%Y-%m-%d" "$1" +%s 2>/dev/null
  fi
}

while IFS= read -r f; do
  # Binding stamp grammar: within the first 6 lines, first match wins.
  stamp=$(head -6 "$f" | grep -E '^> Last verified: [0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  [ -n "$stamp" ] || continue
  d=$(printf '%s' "$stamp" | sed -E 's/^> Last verified: ([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
  epoch=$(to_epoch "$d")
  if [ -z "$epoch" ]; then
    echo "info: unparsable stamp date '$d' in $f — skipping"
    continue
  fi
  age=$(( (now - epoch) / 86400 ))
  if [ "$age" -gt "$days" ]; then
    echo "⚠ stale (${age}d > ${days}d): $f — last verified $d"
  fi
  if [ "$live" -eq 1 ]; then
    # Optional npm tail of the stamp: " — npm:<package>@<major>" (package may
    # be scoped, e.g. npm:@scope/pkg@3 — greedy [^ ]+ keeps the scope's @).
    npm_part=$(printf '%s' "$stamp" | sed -nE 's/.*npm:([^ ]+)@([0-9]+)[[:space:]]*$/\1 \2/p')
    if [ -z "$npm_part" ]; then
      case "$stamp" in
        *npm:*) echo "info: malformed npm tail in stamp of $f — expected npm:<pkg>@<major>" ;;
      esac
      continue
    fi
    pkg=${npm_part% *}
    major=${npm_part##* }
    if live_ver=$(npm view "$pkg" version 2>/dev/null) && [ -n "$live_ver" ]; then
      live_major=${live_ver%%.*}
      if [ "$live_major" != "$major" ]; then
        echo "⚠ major drift: $f — stamped npm:$pkg@$major, live is $live_ver"
      fi
    else
      echo "info: npm view $pkg failed (npm missing or offline) — skipped live check for $f"
    fi
  fi
done < <(find "$root" -type f -path '*/references/*.md' 2>/dev/null)

# Warn-only by contract: never fail the caller, even after warnings.
exit 0
