#!/usr/bin/env bash
# card-set-lint.sh — author-time lint across ONE card set: a <depends-on> naming no card or itself, a dependency cycle, an <interface consumer="Y"> whose card Y is missing or does not depend (directly or through others) on the producer, a card that edits or verifies a path a sibling creates without depending on that sibling, and an <invariant> whose id the spec's `## Shared state & invariants` lacks or whose text differs from that row's Invariant cell (spec path from --spec or 00-INDEX.md; WARN for a spec invariant no card cites). Exit 2 with one `card-set: <reason>: <detail>` line per finding on stderr, 0 clean, 3 usage.
# Misses: a card that touches shared state but cites no <invariant>; a dependency the cards never declare (an import named only in prose), an interface written as prose outside <interface>, a path built from a variable or glob, ordering the index table overrides by hand, a create-order gap on a path already on disk (its creator ran); no lint record is written, so card-lint-observe cannot see that it ran.
# Why, limits, history: rationale/derivations/plugin-taskmaster.md § plugins/taskmaster/scripts/card-set-lint.sh
set -uo pipefail

PROG=card-set-lint
usage() { printf '%s: usage: %s --dir <cards dir> [--spec <spec.md>]\n' "$PROG" "$PROG" >&2; exit 3; }

dir=""; spec=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || usage; dir=$2; shift 2 ;;
    --spec) [ $# -ge 2 ] || usage; spec=$2; shift 2 ;;
    -h | --help) usage ;;
    *) usage ;;
  esac
done
[ -n "$dir" ] && [ -d "$dir" ] || usage

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || root=$PWD
# A path already on disk was created by a card that ran: a follow-up card added later needs no edge to it.
on_disk() { [ -e "$root/$1" ]; }
norm() { local n; n=$(printf '%s' "$1" | sed 's/^0*//'); printf '%s' "${n:-0}"; }

facts=""
add() { facts="${facts}$1"$'\n'; }
n=0
for f in "$dir"/[0-9]*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  case "$base" in 00-INDEX.md) continue ;; esac
  id=$(grep -m1 -oE '<card id="[^"]+"' "$f" | sed -E 's/<card id="([^"]+)"/\1/')
  [ -n "$id" ] || id=$(printf '%s' "$base" | grep -oE '^[0-9]+')
  [ -n "$id" ] || continue
  id=$(norm "$id"); n=$((n + 1))
  add "card	$id	$base"
  deps=$(grep -m1 -oE '<depends-on>[^<]*</depends-on>' "$f" | sed -e 's/<depends-on>//' -e 's#</depends-on>##')
  set -f
  for d in $(printf '%s' "$deps" | tr ',;' '  '); do
    case "$d" in none | None | NONE | - | —) continue ;; esac
    printf '%s' "$d" | grep -qE '^[0-9]+$' || { add "badref	$id	$d"; continue; }
    add "dep	$id	$(norm "$d")"
  done
  set +f
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    printf '%s' "$c" | grep -qE '^[0-9]+$' || { add "badref	$id	$c"; continue; }
    add "iface	$id	$(norm "$c")"
  done < <(grep -oE '<interface[^>]*consumer="[^"]+"' "$f" | sed -E 's/.*consumer="([^"]+)".*/\1/' | tr ',' '\n' | tr -d ' ')
  while IFS= read -r p; do
    [ -n "$p" ] && add "create	$id	$p"
  done < <(grep -oE '<file[^>]*>' "$f" | grep -E 'mode="(create|new)"' | sed -nE 's/.*path="([^"]+)".*/\1/p' | sort -u)
  while IFS= read -r p; do
    [ -n "$p" ] && ! on_disk "$p" && add "use	$id	$p"
  done < <(grep -oE '<file[^>]*>' "$f" | grep -E 'mode="edit"' | sed -nE 's/.*path="([^"]+)".*/\1/p' | sort -u)
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    iid=$(printf '%s' "$l" | sed -nE 's/^<invariant id="([^"]+)">.*/\1/p')
    itx=$(printf '%s' "$l" | sed -nE 's#^<invariant id="[^"]+">(.*)</invariant>.*#\1#p')
    [ -n "$iid" ] && add "inv	$id	$iid	$itx"
  done < <(grep -E '^<invariant id=' "$f")
  vline=$(grep -m1 -oE '<verify>.*</verify>' "$f" | sed -e 's/<verify>//' -e 's#</verify>##')
  if [ -n "$vline" ]; then
    while IFS= read -r p; do
      p=${p#./}
      [ -n "$p" ] && ! on_disk "$p" && add "use	$id	$p"
    done < <(printf '%s\n' "$vline" | tr -d '`"'"'" | tr ' =' '\n\n' \
             | grep -E '^[A-Za-z0-9_.@-][A-Za-z0-9_./@-]*/[A-Za-z0-9_.@-]+\.[A-Za-z0-9]{1,6}$' \
             | grep -vE '^(https?|file):|^\.\./|^/|[*?]' | sort -u)
  fi
done
[ "$n" -gt 0 ] || { printf '%s: no cards (NN-*.md) in %s\n' "$PROG" "$dir" >&2; exit 3; }

hits=$(printf '%s' "$facts" | awk -F'\t' '
  $1 == "card"   { card[$2] = $3; next }
  $1 == "dep"    { nd[$2]++; dep[$2, nd[$2]] = $3; next }
  $1 == "iface"  { ni++; ip[ni] = $2; ic[ni] = $3; next }
  $1 == "create" { if (!(($3) in creator)) creator[$3] = $2; else creator[$3] = creator[$3] " " $2; next }
  $1 == "use"    { nu++; up[nu] = $2; uq[nu] = $3; next }
  $1 == "badref" { printf "card-set: bad-ref: card %s names \"%s\", not a card number\n", $2, $3; next }
  function reach(a, b,    i, d, outer) {   # does a depend on b, directly or through others?
    if ((a, b) in memo) return memo[a, b]
    if (a in visiting) { cut = 1; return 0 }
    visiting[a] = 1; outer = cut; cut = 0
    for (i = 1; i <= nd[a]; i++) {
      d = dep[a, i]
      if (d == a) continue
      if (d == b || reach(d, b)) { delete visiting[a]; memo[a, b] = 1; return 1 }
    }
    # A zero reached through a cycle cut short is not final, so it is not memoised.
    delete visiting[a]; if (!cut) memo[a, b] = 0
    cut = cut || outer; return 0
  }
  END {
    for (a in card) for (i = 1; i <= nd[a]; i++) {
      d = dep[a, i]
      if (d == a) printf "card-set: depends-self: card %s (%s) depends on itself\n", a, card[a]
      else if (!(d in card)) printf "card-set: depends-missing: card %s (%s) depends on %s, which has no card\n", a, card[a], d
    }
    for (a in card) if (reach(a, a) && !(a in cyc)) {
      cyc[a] = 1; printf "card-set: depends-cycle: card %s (%s) reaches itself through <depends-on>\n", a, card[a]
    }
    for (i = 1; i <= ni; i++) {
      p = ip[i]; c = ic[i]
      if (!(c in card)) printf "card-set: interface-consumer-missing: card %s declares an interface for card %s, which has no card\n", p, c
      else if (c != p && !reach(c, p)) printf "card-set: interface-unordered: card %s (%s) reads an interface card %s (%s) produces but does not depend on it, so it can run first\n", c, card[c], p, card[p]
    }
    for (i = 1; i <= nu; i++) {
      u = up[i]; q = uq[i]
      if (!(q in creator)) continue
      ns = split(creator[q], cs, " "); own = 0; ok = 0
      for (j = 1; j <= ns; j++) { if (cs[j] == u) own = 1; if (reach(u, cs[j])) ok = 1 }
      if (!own && !ok) printf "card-set: create-unordered: card %s (%s) uses %s, which card %s creates, without depending on it\n", u, card[u], q, cs[1]
    }
  }' | sort -u)

# Invariants: each card's <invariant> against the spec's `## Shared state & invariants` table.
if [ -z "$spec" ] && [ -f "$dir/00-INDEX.md" ]; then
  spec=$(grep -oE '[^][ ()`"'"'"'<>|]*specs/[^][ ()`"'"'"'<>|]*\.md' "$dir/00-INDEX.md" | head -1)
fi
if [ -n "$spec" ] && [ ! -f "$spec" ]; then
  for c in "$root/$spec" "$dir/$spec"; do [ -f "$c" ] && { spec=$c; break; }; done
fi
invs=$(printf '%s' "$facts" | grep -E '^inv	' || true)
if [ -n "$spec" ] && [ -f "$spec" ]; then
  rows=$(awk '
    tolower($0) ~ /^##+[[:space:]]+shared state/ { grab = 1; next }
    grab && /^##[^#]/ { exit }
    grab && /^\|/ {
      line = $0; sub(/^[[:space:]]*\|/, "", line); sub(/\|[[:space:]]*$/, "", line); gsub(/\\\|/, "\001", line)
      n = split(line, f, "|")
      for (i = 1; i <= n; i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[i]); gsub(/\001/, "|", f[i]) }
      if (!hdr) { hdr = 1; for (i = 1; i <= n; i++) if (tolower(f[i]) == "invariant") col = i; next }
      if (col && f[1] ~ /^I[0-9]+$/) printf "spec\t%s\t%s\n", f[1], f[col]
    }
    END { if (hdr && !col) print "nocol" }' "$spec")
  more=$(printf '%s\n%s\n' "$rows" "$invs" | awk -F'\t' '
    function norm(x) { gsub(/\\\|/, "|", x); gsub(/[[:space:]]+/, " ", x); gsub(/^ | $/, "", x); return x }
    $1 == "nocol" { nocol = 1; print "card-set: invariant-header: the spec'"'"'s Shared state & invariants table has no Invariant column, so no card can be checked against it"; next }
    $1 == "spec" { want[$2] = norm($3); order[++ns] = $2; next }
    $1 == "inv"  { cited[$3] = 1
      if (nocol) next
      if (!($3 in want)) printf "card-set: invariant-unknown: card %s cites %s, which the spec'"'"'s Shared state & invariants table does not hold\n", $2, $3
      else if (norm($4) != want[$3]) printf "card-set: invariant-drift: card %s copies %s as \"%s\" but the spec row says \"%s\"\n", $2, $3, norm($4), want[$3]
    }
    END { for (i = 1; i <= ns; i++) if (!(order[i] in cited)) printf "card-set: WARN invariant-orphan: spec invariant %s is cited by no card\n", order[i] }')
  hits=$(printf '%s\n%s\n' "$hits" "$(printf '%s\n' "$more" | grep -v ': WARN ' || true)" | sed '/^$/d')
  warns=$(printf '%s\n' "$more" | grep ': WARN ' || true)
  [ -n "$warns" ] && printf '%s\n' "$warns" >&2
elif [ -n "$invs" ]; then
  printf '%s: NOTE cards cite <invariant> but no spec was found (--spec, or a specs/*.md path in 00-INDEX.md) — invariants unchecked\n' "$PROG" >&2
fi

if [ -n "$hits" ]; then
  printf '%s\n' "$hits" >&2
  exit 2
fi
exit 0
