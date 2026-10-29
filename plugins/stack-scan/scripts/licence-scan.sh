#!/usr/bin/env bash
# Dependency-licence scan over every package-lock.json (v2+) and composer.lock entry, transitive ones included, judged by distribution mode: MPL/LGPL bite a distributed binary, AGPL bites SaaS. An npm lockfileVersion 1 has no licence field: reported UNRESOLVABLE (exit 3), never clean.
# Misses: legal truth (DECLARED metadata only, not legal advice); a dual-licensed package declaring one side, vendored code with no manifest entry, a LICENSE file contradicting the SPDX id, a licence changed since the locked version; lockfiles deeper than three directory levels; pnpm, yarn and bun lockfiles (no per-package licence field).
# Why, limits, history: rationale/derivations/plugin-stack-scan.md § plugins/stack-scan/scripts/licence-scan.sh (marketplace repository)

#   licence-scan.sh [--dir DIR] [--distribution MODE] [--policy FILE] [--init]
#
#     MODE: saas | distributed-binary | internal | oss-permissive | oss-copyleft
#
# Policy resolution: --distribution wins, else .licence-policy.json at the repo
# root, else exit 3.
#
# Exit: 0 clean · 2 a denied licence for this distribution mode · 3 cannot resolve
#       (no mode, no lockfile, or a lockfile whose licence data is unreadable)
set -u
PROG=${0##*/}

dir="." ; mode="" ; policy="" ; init=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) dir="${2:-}"; shift 2 ;;
    --distribution) mode="${2:-}"; shift 2 ;;
    --policy) policy="${2:-}"; shift 2 ;;
    --init) init=1; shift ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^#!.*//; s/^# \{0,1\}//'; exit 0 ;;
    *) printf '%s: unknown argument %s\n' "$PROG" "$1" >&2; exit 3 ;;
  esac
done

[ -d "$dir" ] || { printf '%s: no such directory: %s\n' "$PROG" "$dir" >&2; exit 3; }
command -v jq >/dev/null 2>&1 || { printf '%s: jq required\n' "$PROG" >&2; exit 3; }
[ -n "$policy" ] || policy="$dir/.licence-policy.json"

if [ "$init" -eq 1 ]; then
  cat > "$policy" <<'JSON'
{
  "_comment": "distribution decides which copyleft classes matter. saas: AGPL is the hazard, MPL/LGPL are routine. distributed-binary: MPL/LGPL/GPL are the hazard. internal: almost nothing is. oss-*: your own outbound licence constrains what you may link.",
  "distribution": "saas",
  "allow": [],
  "deny": [],
  "review": []
}
JSON
  printf 'wrote %s — set "distribution" before relying on it.\n' "$policy"
  exit 0
fi

if [ -z "$mode" ] && [ -f "$policy" ]; then
  mode=$(jq -r '.distribution // empty' "$policy" 2>/dev/null)
fi
if [ -z "$mode" ]; then
  printf '%s: no distribution mode. Pass --distribution <saas|distributed-binary|internal|oss-permissive|oss-copyleft>,\n' "$PROG" >&2
  printf '       or run --init to write %s. The mode IS the decision — without it a licence list is trivia.\n' "$policy" >&2
  exit 3
fi

# Deny sets per distribution mode: AGPL and MPL sit on opposite sides of the saas / distributed-binary line.
case "$mode" in
  saas)               deny_re='^(AGPL|SSPL|BUSL|Commons-Clause|Elastic-2)'; note="a network-served product triggers AGPL/SSPL source-provision; MPL and LGPL are routine here" ;;
  distributed-binary) deny_re='^(GPL-[23]|AGPL|SSPL|BUSL|MPL-|LGPL-|CDDL|EPL-|CPL-|Commons-Clause|Elastic-2)'; note="shipping the artifact triggers file- and library-level copyleft; MPL/LGPL/GPL all matter" ;;
  internal)           deny_re='^(SSPL|BUSL|Commons-Clause|Elastic-2)'; note="no distribution and no network service — only source-available/non-open licences with usage limits bite" ;;
  oss-permissive)     deny_re='^(GPL-[23]|AGPL|SSPL|BUSL|Commons-Clause|Elastic-2)'; note="an MIT/Apache project cannot absorb reciprocal copyleft" ;;
  oss-copyleft)       deny_re='^(SSPL|BUSL|Commons-Clause|Elastic-2)'; note="GPL-compatible copyleft is fine; source-available licences are not open source" ;;
  *) printf '%s: unknown distribution mode "%s"\n' "$PROG" "$mode" >&2; exit 3 ;;
esac

extra_deny=""; extra_allow=""
if [ -f "$policy" ]; then
  extra_deny=$(jq -r '(.deny // []) | join("|")' "$policy" 2>/dev/null)
  extra_allow=$(jq -r '(.allow // []) | join("|")' "$policy" 2>/dev/null)
fi

WORK=$(mktemp -d) || exit 3
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/pkgs"          # name<TAB>licence<TAB>source
unresolvable=0
sources=0

# --- npm ---------------------------------------------------------------------
while IFS= read -r lock; do
  [ -f "$lock" ] || continue
  sources=$((sources + 1))
  lv=$(jq -r '.lockfileVersion // 0' "$lock" 2>/dev/null)
  if [ "${lv:-0}" -lt 2 ] 2>/dev/null; then
    printf 'UNRESOLVABLE  %s — lockfileVersion %s carries no license field at all.\n' "$lock" "${lv:-?}" >&2
    printf '              A scan of this file returns zero findings for the wrong reason. Upgrade with\n' >&2
    printf '              `npm install --lockfile-version 3`, or resolve from node_modules.\n' >&2
    unresolvable=1
    continue
  fi
  jq -r --arg s "${lock#$dir/}" '
    (.packages // {}) | to_entries[]
    | select(.key != "")
    | [ (.key | sub("^node_modules/"; "")), (.value.license // "UNKNOWN"), $s ]
    | @tsv' "$lock" 2>/dev/null >> "$WORK/pkgs"
done < <(find "$dir" -maxdepth 3 -name package-lock.json -not -path '*/node_modules/*' 2>/dev/null)

# --- composer ----------------------------------------------------------------
while IFS= read -r lock; do
  [ -f "$lock" ] || continue
  sources=$((sources + 1))
  jq -r --arg s "${lock#$dir/}" '
    ((.packages // []) + (."packages-dev" // []))[]
    | [ .name, ((.license // []) | if type=="array" then (join(" OR ")) else . end | if . == "" then "UNKNOWN" else . end), $s ]
    | @tsv' "$lock" 2>/dev/null >> "$WORK/pkgs"
done < <(find "$dir" -maxdepth 3 -name composer.lock -not -path '*/vendor/*' 2>/dev/null)

if [ "$sources" -eq 0 ]; then
  # pnpm, yarn and bun lockfiles carry no per-package license field: name the one found, so exit 3 does not read as "no dependencies".
  other=$(find "$dir" -maxdepth 3 \( -name pnpm-lock.yaml -o -name yarn.lock -o -name bun.lock -o -name bun.lockb \) -not -path '*/node_modules/*' 2>/dev/null | head -3)
  if [ -n "$other" ]; then
    printf '%s: found %s, which carries no per-package license field — this lane reads package-lock.json and composer.lock only.\n' \
      "$PROG" "$(printf '%s' "$other" | xargs -n1 basename 2>/dev/null | paste -sd, - 2>/dev/null)" >&2
    printf '%s: run `npm install --package-lock-only` for a readable lockfile, or use the package manager'"'"'s own licence tooling.\n' "$PROG" >&2
  else
    printf '%s: no package-lock.json or composer.lock found under %s\n' "$PROG" "$dir" >&2
  fi
  exit 3
fi

total=$(wc -l < "$WORK/pkgs" | tr -d ' ')
printf 'licence-scan: %s package entries from %s lockfile(s)\n' "$total" "$sources"
printf 'distribution: %s — %s\n\n' "$mode" "$note"

printf 'declared licences:\n'
cut -f2 "$WORK/pkgs" | sort | uniq -c | sort -rn | head -15 | sed 's/^/  /'

denied=""
while IFS=$'\t' read -r name lic src; do
  [ -n "$name" ] || continue
  [ -n "$extra_allow" ] && printf '%s' "$lic" | grep -qE "^($extra_allow)$" && continue
  hit=0
  printf '%s' "$lic" | grep -qE "$deny_re" && hit=1
  [ -n "$extra_deny" ] && printf '%s' "$lic" | grep -qE "^($extra_deny)$" && hit=1
  [ "$hit" -eq 1 ] && denied="$denied$(printf '  %-46s %-16s %s' "$name" "$lic" "$src")
"
done < "$WORK/pkgs"

unknown=$(awk -F'\t' '$2=="UNKNOWN"' "$WORK/pkgs" | wc -l | tr -d ' ')

if [ -n "$denied" ]; then
  printf '\nDENIED for distribution=%s:\n%s' "$mode" "$denied"
  printf '\nEach is transitive unless it also appears in a manifest — check before assuming\n'
  printf 'a direct dependency introduced it. Remove, replace, or record an exception in\n'
  printf '%s under "allow" with a reason a reviewer can read.\n' "${policy#$dir/}"
fi
if [ "${unknown:-0}" -gt 0 ]; then
  printf '\n%s entry/entries declare no licence. Unresolved is not permissive — resolve each\n' "$unknown"
  printf 'from the package itself before shipping.\n'
fi

printf '\nThis reads DECLARED metadata, not legal truth: blind to dual-licensed packages\n'
printf 'declaring one side, vendored code with no manifest entry, and a LICENSE file that\n'
printf 'contradicts the declared SPDX id. Not legal advice.\n'

[ -n "$denied" ] && exit 2
[ "$unresolvable" -eq 1 ] && exit 3
[ "${unknown:-0}" -gt 0 ] && exit 3
printf '\nclean for distribution=%s.\n' "$mode"
exit 0
