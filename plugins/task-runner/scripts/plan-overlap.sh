#!/usr/bin/env bash
# plan-overlap.sh — computes a card set's dependency levels and the same-level card pairs that write one path (a `dir/` entry covers what is under it). With --group, exit 1 when the named cards cannot run at once: two write one path, one depends on another, or one lists no written file.
# Misses: a file a card writes but does not list, a path built from a glob or variable, generated and lock files a build rewrites, a legacy bold-label card's `Files` text (reported as no-files), shared ports, databases and caches.
# Why, limits, history: rationale/derivations/plugin-task-runner.md § plugins/task-runner/scripts/plan-overlap.sh
set -uo pipefail

PROG=plan-overlap
usage() { printf '%s: usage: %s --dir <cards dir> [--group <card,card,...>]\n' "$PROG" "$PROG" >&2; exit 3; }

dir=""; group=""; has_group=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dir) [ $# -ge 2 ] || usage; dir=$2; shift 2 ;;
    --group) [ $# -ge 2 ] || usage; group=$2; has_group=1; shift 2 ;;
    *) usage ;;
  esac
done
[ -n "$dir" ] && [ -d "$dir" ] || usage

norm() { local n; n=$(printf '%s' "$1" | sed 's/^0*//'); printf '%s' "${n:-0}"; }

facts=""
add() { facts="${facts}$1"$'\n'; }
n=0
for f in "$dir"/[0-9]*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  case "$base" in 00-INDEX.md) continue ;; esac
  shown=$(grep -m1 -oE '<card id="[^"]+"' "$f" | sed -E 's/<card id="([^"]+)"/\1/')
  [ -n "$shown" ] || shown=$(printf '%s' "$base" | grep -oE '^[0-9]+')
  printf '%s' "$shown" | grep -qE '^[0-9]+$' || continue
  id=$(norm "$shown"); n=$((n + 1))
  add "card	$id	$shown"
  deps=$(grep -m1 -oE '<depends-on>[^<]*</depends-on>' "$f" | sed -e 's/<depends-on>//' -e 's#</depends-on>##')
  for d in $(printf '%s' "$deps" | tr ',;' '  ' | grep -oE '[0-9]+'); do
    add "dep	$id	$(norm "$d")"
  done
  while IFS= read -r p; do
    [ -n "$p" ] && add "file	$id	${p#./}"
  done < <(grep -oE '<file[^>]*>' "$f" | grep -E 'mode="(edit|create|new)"' | sed -nE 's/.*path="([^"]+)".*/\1/p' | sort -u)
done
[ "$n" -gt 0 ] || { printf '%s: no cards (NN-*.md) in %s\n' "$PROG" "$dir" >&2; exit 3; }

if [ "$has_group" = 1 ]; then
  members=0
  for g in $(printf '%s' "$group" | tr ',' ' '); do
    printf '%s' "$g" | grep -qE '^[0-9]+$' || { printf '%s: --group takes card numbers: %s\n' "$PROG" "$g" >&2; exit 3; }
    add "group	$(norm "$g")	$g"; members=$((members + 1))
  done
  [ "$members" -ge 2 ] || { printf '%s: --group needs at least two cards\n' "$PROG" >&2; exit 3; }
fi

printf '%s' "$facts" | awk -F'\t' -v grouped="$has_group" '
  $1 == "card"  { shown[$2] = $3; order[++nc] = $2; next }
  $1 == "dep"   { nd[$2]++; dep[$2, nd[$2]] = $3; next }
  $1 == "file"  { nf[$2]++; file[$2, nf[$2]] = $3; next }
  $1 == "group" { member[++ng] = $2; asked[$2] = $3; next }
  function level(a,    i, d, l, best) {
    if (a in lv) return lv[a]
    if (a in visiting) { cyclic = 1; return 0 }
    visiting[a] = 1; best = 0
    for (i = 1; i <= nd[a]; i++) {
      d = dep[a, i]
      if (!(d in shown) || d == a) continue
      l = level(d) + 1; if (l > best) best = l
    }
    delete visiting[a]; lv[a] = best; return best
  }
  function reach(a, b,    i, d) {
    if (lv[a] <= lv[b]) return 0
    for (i = 1; i <= nd[a]; i++) {
      d = dep[a, i]
      if (!(d in shown) || d == a) continue
      if (d == b || reach(d, b)) return 1
    }
    return 0
  }
  function covers(p, q) { return p == q || (p ~ /\/$/ && index(q, p) == 1) }
  function shared(a, b,    i, j, p, q) {
    for (i = 1; i <= nf[a]; i++) for (j = 1; j <= nf[b]; j++) {
      p = file[a, i]; q = file[b, j]
      if (covers(p, q)) return q
      if (covers(q, p)) return p
    }
    return ""
  }
  function pair(a, b,    s) {
    s = shared(a, b)
    if (s != "") { printf "overlap: cards %s and %s both write %s\n", shown[a], shown[b], s; found = 1 }
  }
  END {
    max = 0
    for (i = 1; i <= nc; i++) { l = level(order[i]); if (l > max) max = l }
    if (cyclic) { print "plan-overlap: the cards <depends-on> each other in a cycle; card-set-lint.sh names it" > "/dev/stderr"; exit 3 }
    if (grouped) {
      for (i = 1; i <= ng; i++) if (!(member[i] in shown)) {
        printf "plan-overlap: no card %s in this set\n", asked[member[i]] > "/dev/stderr"; exit 3
      }
      for (i = 1; i <= ng; i++) {
        a = member[i]
        if (nf[a] == 0) { printf "no-files: card %s lists no <file> with a mode, so nothing proves it disjoint\n", shown[a]; found = 1 }
        for (j = i + 1; j <= ng; j++) {
          b = member[j]
          if (reach(a, b)) { printf "dependent: card %s depends on card %s\n", shown[a], shown[b]; found = 1 }
          else if (reach(b, a)) { printf "dependent: card %s depends on card %s\n", shown[b], shown[a]; found = 1 }
          pair(a, b)
        }
      }
      exit found ? 1 : 0
    }
    for (l = 0; l <= max; l++) {
      line = ""
      for (i = 1; i <= nc; i++) if (lv[order[i]] == l) line = line " " shown[order[i]]
      printf "level %d:%s\n", l, line
    }
    for (i = 1; i <= nc; i++) for (j = i + 1; j <= nc; j++)
      if (lv[order[i]] == lv[order[j]]) pair(order[i], order[j])
    for (i = 1; i <= nc; i++) if (nf[order[i]] == 0)
      printf "no-files: card %s lists no <file> with a mode, so nothing proves it disjoint\n", shown[order[i]]
    exit 0
  }'
