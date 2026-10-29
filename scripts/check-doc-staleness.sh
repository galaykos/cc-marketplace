#!/usr/bin/env bash
# check-doc-staleness.sh [--days N] [--path DIR] [--live] [--inventory] — warns on a `> Last verified: YYYY-MM-DD — <url>[ — npm:<pkg>@<major>[.<minor>]]` stamp (first 6 lines of */references/*.md or skills/*/SKILL.md) older than --days (90); --live compares the npm tail and HEADs the URL; --inventory prints a row per stamp.
# Misses: unstamped files, a URL answering 200 with rewritten content, composer: tails, a versioned docs URL's next major, and --live outside a hand run (CI runs the age check only); age is a proxy. Exits 0 on every path.
# Why, limits, history: rationale/derivations/scripts.md § scripts/check-doc-staleness.sh
set -u
cd "$(dirname "$0")/.." || exit 0

days=90
root="plugins/"
live=0
inventory=0
while [ $# -gt 0 ]; do
  case "$1" in
    --days) [ $# -ge 2 ] || { echo "info: --days needs a value" >&2; break; }; days="$2"; shift 2 ;;
    --path) [ $# -ge 2 ] || { echo "info: --path needs a value" >&2; break; }; root="$2"; shift 2 ;;
    --live) live=1; shift ;;
    --inventory) inventory=1; shift ;;
    *) echo "info: unknown flag '$1' (usage: [--days N] [--path DIR] [--live] [--inventory])" >&2; shift ;;
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

# HTTP status of a stamped URL, or "net" when curl cannot reach it. HEAD
# first; a site that rejects HEAD (405/403) is retried as a ranged GET.
url_status() {
  local code
  code=$(curl -sS -o /dev/null -L -I -m 15 -A 'cc-marketplace-staleness/1' -w '%{http_code}' "$1" 2>/dev/null) || code=net
  case "$code" in
    000|net|403|405) code=$(curl -sS -o /dev/null -L -m 15 -r 0-0 -A 'cc-marketplace-staleness/1' -w '%{http_code}' "$1" 2>/dev/null) || code=net ;;
  esac
  printf '%s' "$code"
}

[ "$inventory" -eq 1 ] && printf 'age_d\tverified\tstamped_npm\tlive_npm\turl_status\tfile\turl\n'

while IFS= read -r f; do
  # Stamp grammar: within the first 6 lines, first match wins; the bold `> **Last verified: …**` form counts too.
  stamp=$(head -6 "$f" | grep -E '^> \*{0,2}Last verified: ?\*{0,2} ?[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  [ -n "$stamp" ] || continue
  d=$(printf '%s' "$stamp" | sed -E 's/^> \*{0,2}Last verified: ?\*{0,2} ?([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/')
  epoch=$(to_epoch "$d")
  if [ -z "$epoch" ]; then
    echo "info: unparsable stamp date '$d' in $f — skipping"
    continue
  fi
  age=$(( (now - epoch) / 86400 ))
  if [ "$age" -gt "$days" ]; then
    echo "⚠ stale (${age}d > ${days}d): $f — last verified $d"
  fi

  # Optional npm tail ` — npm:<package>@<major>[.<minor>]`: greedy [^ ]+ keeps a scoped package's @; a stamped minor is compared too (0.x breaks on minors).
  npm_part=$(printf '%s' "$stamp" | sed -nE 's/.*npm:([^ ]+)@([0-9]+(\.[0-9]+)?)[[:space:]]*$/\1 \2/p')
  pkg=""; stamped_ver="-"; live_ver="-"; status="-"
  if [ -n "$npm_part" ]; then
    pkg=${npm_part% *}
    stamped_ver=${npm_part##* }
  else
    case "$stamp" in
      *npm:*) echo "info: malformed npm tail in stamp of $f — expected npm:<pkg>@<major>[.<minor>]" ;;
    esac
  fi
  url=$(printf '%s' "$stamp" | grep -oE 'https?://[^ ]+' | head -1)

  if [ "$live" -eq 1 ]; then
    if [ -n "$pkg" ]; then
      if live_ver=$(npm view "$pkg" version 2>/dev/null) && [ -n "$live_ver" ]; then
        live_major=${live_ver%%.*}
        stamped_major=${stamped_ver%%.*}
        if [ "$live_major" != "$stamped_major" ]; then
          echo "⚠ major drift: $f — stamped npm:$pkg@$stamped_ver, live is $live_ver"
        elif [ "$stamped_ver" != "$stamped_major" ]; then
          live_minor=$(printf '%s' "$live_ver" | cut -d. -f1,2)
          [ "$live_minor" = "$stamped_ver" ] || echo "⚠ minor drift: $f — stamped npm:$pkg@$stamped_ver, live is $live_ver"
        elif [ "$stamped_major" = "0" ]; then
          echo "info: 0.x package stamped by major only in $f — stamp npm:$pkg@$(printf '%s' "$live_ver" | cut -d. -f1,2) so minor drift is visible"
        fi
      else
        live_ver=net
        echo "info: npm view $pkg failed (npm missing or offline) — skipped live check for $f"
      fi
    fi
    if [ -n "$url" ]; then
      status=$(url_status "$url")
      case "$status" in
        2??|3??) ;;
        net) echo "info: $url unreachable (offline or blocked) — $f" ;;
        *) echo "⚠ url $status: $url — $f" ;;
      esac
    fi
  fi

  [ "$inventory" -eq 1 ] && printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$age" "$d" "${pkg:+$pkg@}$stamped_ver" "$live_ver" "$status" "$f" "${url:--}"
# SKILL.md is scanned too: version-leverage claims live inline in skill bodies, not only under references/.
done < <(find "$root" -type f \( -path '*/references/*.md' -o -path '*/skills/*/SKILL.md' \) 2>/dev/null | sort)

# Warn-only by contract: never fail the caller, even after warnings.
exit 0
