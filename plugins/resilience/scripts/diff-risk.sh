#!/usr/bin/env bash
# diff-risk.sh [--dir DIR] [--base REF] [--since DATE] [--json] — scores each file the change touches (merge-base..worktree, plus untracked) from its git history up to that base: 3 per revert, 2 per fix, +1 per revert or fix landing within 14 days of the file's previous commit. Prints the top files, the commits behind each score and one overall line; inform only.
# Exit 0 scored (also when nothing is touched or nothing scores), 2 usage or no base (no origin/HEAD, main or master; a --base that names no commit), 3 not a git work tree or reading it failed, 4 git or awk missing. Misses: history before a rename, a fix whose subject never says fix, fixes squashed into other commits, signals older than --since.
# Why, limits, history: rationale/derivations/plugin-resilience.md § plugins/resilience/scripts/diff-risk.sh
set -uo pipefail
PROG=diff-risk
FOLLOWUP_DAYS=14 TOP=10 SHOWN=5 PATHSPEC_MAX=2000

usage() { printf '%s: usage error: %s\nusage: diff-risk.sh [--dir DIR] [--base REF] [--since DATE] [--json]\n' "$PROG" "$1" >&2; exit 2; }
die() { printf '%s: %s\n' "$PROG" "$2" >&2; exit "$1"; }

dir=. base= since='1 year ago' json=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help) sed -n '2,3p' "$0"; exit 0 ;;
    --json) json=1 ;;
    --dir | --base | --since)
      [ $# -ge 2 ] && [ -n "$2" ] || usage "$1 needs a value"
      case "$1" in --dir) dir=$2 ;; --base) base=$2 ;; *) since=$2 ;; esac
      shift ;;
    *) usage "unknown argument: $1" ;;
  esac
  shift
done
case "$base" in -*) usage "--base takes a ref, got $base" ;; esac

command -v git >/dev/null 2>&1 || die 4 "git not found"
command -v awk >/dev/null 2>&1 || die 4 "awk not found"
[ -d "$dir" ] || usage "--dir is not a directory: $dir"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && [ -n "$top" ] || die 3 "not a git work tree: $dir"
g() { git -C "$top" -c core.quotePath=false "$@"; }

g rev-parse -q --verify 'HEAD^{commit}' >/dev/null || die 2 "no base: HEAD has no commits yet"
if [ -n "$base" ]; then
  ref=$base
  g rev-parse -q --verify "$ref^{commit}" >/dev/null || die 2 "no base: --base $base names no commit"
else
  ref=
  for r in "$(g symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null)" refs/remotes/origin/main refs/remotes/origin/master refs/heads/main refs/heads/master; do
    if [ -n "$r" ] && g rev-parse -q --verify "$r^{commit}" >/dev/null; then ref=$r; break; fi
  done
  [ -n "$ref" ] || die 2 "no base: no origin/HEAD, main or master; pass --base <ref>"
fi
base_sha=$(g merge-base HEAD "$ref" 2>/dev/null) || die 2 "no base: $ref shares no history with HEAD"
label=${ref#refs/remotes/}; label=${label#refs/heads/}

tmp=$(mktemp -d 2>/dev/null) || die 3 "mktemp -d failed"
trap 'rm -rf "$tmp"' EXIT
{ g diff --no-color --no-renames --name-only "$base_sha" -- && g ls-files --others --exclude-standard; } >"$tmp/touched" \
  || die 3 "git could not list the changed files"

specs=() quoted=0
while IFS= read -r p; do
  case "$p" in \"*) quoted=1 ;; esac
  specs+=("$p")
done <"$tmp/touched"

# One walk for every file. A C-quoted name is no usable pathspec, so that case walks unfiltered and awk filters.
logargs=(log --no-color --no-merges --full-history --no-renames --no-show-signature --date=short
  '--format=%x1e%H%x1f%at%x1f%ad%x1f%s' --name-only "--since=$since" "$base_sha")
if [ ${#specs[@]} -eq 0 ]; then
  : >"$tmp/log"
elif [ "$quoted" = 0 ] && [ ${#specs[@]} -le "$PATHSPEC_MAX" ]; then
  g --literal-pathspecs "${logargs[@]}" -- "${specs[@]}" >"$tmp/log" || die 3 "git log failed"
else
  g "${logargs[@]}" >"$tmp/log" || die 3 "git log failed"
fi

DR_TOUCHED="$tmp/touched" DR_JSON=$json DR_DAYS=$FOLLOWUP_DAYS DR_TOP=$TOP DR_SHOWN=$SHOWN \
DR_SINCE=$since DR_BASE=$base_sha DR_FROM="merge-base with $label" LC_ALL=C awk '
function clean(s) { gsub(CTL, "?", s); return s }
function jstr(s,   out, i) {
  s = clean(s); out = ""
  while ((i = match(s, /["\\]/)) > 0) { out = out substr(s, 1, i - 1) "\\" substr(s, i, 1); s = substr(s, i + 1) }
  return "\"" out s "\""
}
function classify(s,   l, n, i, a) {
  l = tolower(s); sub(/^[ \t]+/, "", l)
  if (l ~ /^revert "/ || l ~ /^revert(\([^)]*\))?!?:/) return "revert"
  gsub(/[^a-z0-9_-]+/, " ", l)
  n = split(l, a, " ")
  for (i = 1; i <= n; i++) if (a[i] in FIXW) return "fix"
  return ""
}
# Log order is newest first, so the commit read now is the previous change of the one read before it.
function seen(f,   d, k) {
  if ((f in lastAt) && lastSig[f]) {
    d = lastAt[f] - at
    if (d >= 0 && d <= WINDOW) { fu[f, lastSig[f]] = 1; nfu[f]++ }
  }
  lastAt[f] = at; lastSig[f] = 0
  if (kind == "") return
  k = ++ns[f]
  csha[f, k] = sha; cday[f, k] = day; ckind[f, k] = kind; csub[f, k] = subj
  if (kind == "revert") nrev[f]++; else nfix[f]++
  lastSig[f] = k
}
BEGIN {
  CTL = "[" sprintf("%c", 1) "-" sprintf("%c", 31) sprintf("%c", 127) "]"
  US = sprintf("%c", 31); RSEP = sprintf("%c", 30)
  WINDOW = ENVIRON["DR_DAYS"] * 86400; TOPN = ENVIRON["DR_TOP"] + 0; SHOWN = ENVIRON["DR_SHOWN"] + 0
  split("fix fixes fixed hotfix hotfixes hot-fix bugfix bugfixes bug-fix", w, " ")
  for (i in w) FIXW[w[i]] = 1
}
FILENAME == ENVIRON["DR_TOUCHED"] { if ($0 != "" && !($0 in T)) { T[$0] = 1; nt++ }; next }
substr($0, 1, 1) == RSEP {
  r = substr($0, 2)
  i = index(r, US); sha = substr(r, 1, i - 1); r = substr(r, i + 1)
  i = index(r, US); at = substr(r, 1, i - 1) + 0; r = substr(r, i + 1)
  i = index(r, US); day = substr(r, 1, i - 1); subj = substr(r, i + 1)
  kind = classify(subj); next
}
($0 in T) { seen($0) }
END {
  nt += 0; flagged = 0; total = 0
  for (f in T) {
    s = 3 * nrev[f] + 2 * nfix[f] + nfu[f]
    if (s > 0) { score[f] = s; flagged++; total += s }
  }
  n = 0
  while (n < TOPN && n < flagged) {
    best = ""
    for (f in score)
      if (!(f in picked) && (best == "" || score[f] > score[best] || (score[f] == score[best] && f < best))) best = f
    picked[best] = 1; order[++n] = best
  }
  since = clean(ENVIRON["DR_SINCE"]); from = clean(ENVIRON["DR_FROM"]); base = ENVIRON["DR_BASE"]
  formula = "3 per revert + 2 per fix + 1 per follow-up (a revert or fix within " ENVIRON["DR_DAYS"] " days of the previous commit to the file)"
  if (nt == 0) ov = "overall: no touched files vs " substr(base, 1, 10) "; nothing to score"
  else if (flagged == 0) ov = sprintf("overall: 0 of %d touched files carry risk signals in their history since \"%s\"", nt, since)
  else ov = sprintf("overall: %d of %d touched files carry risk signals; highest %s (%d); total %d%s", flagged, nt, clean(order[1]), score[order[1]], total, (flagged > n ? "; top " n " shown" : ""))
  if (ENVIRON["DR_JSON"] == "1") {
    printf "{\"base\":%s,\"base_from\":%s,\"since\":%s,\"followup_days\":%d,\"formula\":%s,\"touched\":%d,\"flagged\":%d,\"total\":%d,\"top\":[", jstr(base), jstr(from), jstr(since), ENVIRON["DR_DAYS"], jstr(formula), nt, flagged, total
    for (j = 1; j <= n; j++) {
      f = order[j]
      printf "%s{\"path\":%s,\"score\":%d,\"reverts\":%d,\"fixes\":%d,\"follow_ups\":%d,\"commits\":[", (j > 1 ? "," : ""), jstr(f), score[f], nrev[f], nfix[f], nfu[f]
      for (k = 1; k <= ns[f]; k++)
        printf "%s{\"sha\":%s,\"date\":%s,\"kind\":%s,\"follow_up\":%s,\"subject\":%s}", (k > 1 ? "," : ""), jstr(csha[f, k]), jstr(cday[f, k]), jstr(ckind[f, k]), (((f, k) in fu) ? "true" : "false"), jstr(csub[f, k])
      printf "]}"
    }
    printf "],\"overall\":%s}\n", jstr(ov)
    exit 0
  }
  printf "diff-risk: %d touched files vs %s (%s), history up to it since \"%s\"\n", nt, substr(base, 1, 10), from, since
  if (n > 0) {
    printf "score = %s\n", formula
    printf "score revert fix follow-up  file\n"
    for (j = 1; j <= n; j++) {
      f = order[j]
      printf "%5d %6d %3d %9d  %s\n", score[f], nrev[f], nfix[f], nfu[f], clean(f)
      for (k = 1; k <= ns[f] && k <= SHOWN; k++)
        printf "      %s %s %-16s %s\n", substr(csha[f, k], 1, 10), cday[f, k], ckind[f, k] (((f, k) in fu) ? ",follow-up" : ""), clean(csub[f, k])
      if (ns[f] > SHOWN) printf "      (%d more)\n", ns[f] - SHOWN
    }
  }
  print ov "; inform only, nothing blocks"
}' "$tmp/touched" "$tmp/log" || die 3 "scoring failed"
exit 0
