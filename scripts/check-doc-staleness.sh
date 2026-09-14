#!/usr/bin/env bash
# Warn-only staleness check for vendored doc digests (hybrid digest +
# fetch-verify strategy). Scans */references/*.md under a root for the
# machine-parsable stamp, expected within the first 6 lines of a digest:
#
#   > Last verified: YYYY-MM-DD — <root doc URL>[ — npm:<package>@<major>[.<minor>]]
#
# and prints a warning for any digest whose stamp is older than the threshold.
# Scans BOTH */references/*.md and skills/*/SKILL.md: a version-leverage claim is
# usually inline in the SKILL body, not in a reference file. Files with no stamp
# are hand-written skill material, not doc-derived — silently ignored here.
# validate.sh separately REQUIRES a stamp from any plugin whose own description
# claims version leverage; that is the blocking half of this pair. NEVER blocks: exits 0 on every path,
# including after warnings (warn-only by contract, spec A2); the CI step adds
# continue-on-error as belt and braces. Runnable locally:
#   bash scripts/check-doc-staleness.sh [--days N] [--path DIR] [--live] [--inventory]
#     --days N    staleness threshold in days (default 90)
#     --path DIR  scan root (default plugins/)
#     --live      also compare npm:<pkg>@<ver> stamps against the live npm
#                 version and HEAD every stamped URL; npm/network errors print
#                 an info line, never warn
#     --inventory print one tab-separated row per stamp (age, date, stamped npm,
#                 live npm, URL status, file) instead of only the warnings — the
#                 table the digest-refresh project skill walks
#
# What the age check does NOT catch, measured: the Astryx digest was 49 days
# old on 2026-09-09 — inside the 90-day window — and already wrong on the
# package layout, the theme API and a category name, because a 0.x package
# had gone 0.3 → 0.5. Age is a proxy; the `npm:` tail is the real signal, and
# for a 0.x package the MINOR is the breaking unit, so the tail may carry
# `@<major>.<minor>` and --live then compares both. A stamp with no npm tail
# is invisible to --live: stamp the package, or accept that only the date is
# read back. Residual: a URL that still answers 200 with rewritten content is
# reported as reachable; only a human or model diff catches that, which is
# what the digest-refresh skill is for.
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
  # Binding stamp grammar: within the first 6 lines, first match wins. The bold form
  # (`> **Last verified: …**`) is accepted because seven shipped craft-layer references
  # used it and were invisible to this script for weeks — a staleness checker that
  # silently skips files is worse than one that reports them, and the marker is for
  # humans, who bold things. Both forms are canonical; neither is preferred.
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

  # Optional npm tail of the stamp: " — npm:<package>@<major>[.<minor>]"
  # (package may be scoped, e.g. npm:@scope/pkg@3 — greedy [^ ]+ keeps the
  # scope's @). A minor is meaningful on its own for 0.x packages, where the
  # minor is the breaking unit; on >=1.x a stamped minor is compared too.
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
# WIDENED 2026-08-02 to include skills/*/SKILL.md. The scan was references-only,
# and every one of the ~15 version-leverage stack plugins — nextjs, nuxt, vue3,
# laravel, php, vite, threejs, node-backend, react-native, livewire, inertia,
# mysql, mariadb, postgresql, sql — ships ZERO files under any references/
# directory. All ten stamped files in the tree sit in ui-ux and craft-layer.
# Their version claims live inline in SKILL.md bodies, which this check had never
# been able to see. Those plugins are exempt from the baseline-redundancy loop
# precisely BECAUSE they encode version leverage, so a stale leverage map turns
# the marketplace's one durable advantage over a blind model into confidently
# wrong advice that decays silently rather than on any edit.
# WIDENED 2026-09-09 to .claude/skills when --path names it; the default root
# stays plugins/ so the CI step's output is unchanged.
done < <(find "$root" -type f \( -path '*/references/*.md' -o -path '*/skills/*/SKILL.md' \) 2>/dev/null | sort)

# Warn-only by contract: never fail the caller, even after warnings.
exit 0
