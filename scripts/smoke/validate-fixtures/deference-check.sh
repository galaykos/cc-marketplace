#!/usr/bin/env bash
# Deference-gate harness: proves pc_deference_edges (scripts/lib/plugin-checks.sh)
# fires on an unbacked "defers X to <plugin>" claim, passes the shipped tree, SKIPS
# a claim whose target is a host built-in or a plugin class (no directory to
# resolve), and that validate.sh's call site carries the FAIL string to the build.
# CI step: .github/workflows/validate.yml "deference gate harness".
#
# RUN AGAINST A MIRROR, NEVER THE LIVE TREE (the rule role-floors-check.sh learned
# after three leaked scratch files). Every plant below lands under $T; the live
# tree is only ever READ, and an integrity assertion at exit proves it.
set -u
LIVE="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 2
cd "$LIVE" || exit 2
. scripts/lib/plugin-checks.sh || exit 2
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not installed"; exit 0; }
rc=0
T=$(mktemp -d) || exit 2
cleanup() {
  bad=0
  for f in "$LIVE"/plugins/zz-*; do
    [ -e "$f" ] && { echo "FAIL: probe leaked into the live tree: $f"; bad=1; }
  done
  cd / 2>/dev/null || true
  rm -rf "$T"
  [ "$bad" -eq 0 ] || exit 1
}
trap cleanup EXIT INT TERM HUP

# 1. the shipped tree is clean — every plugin-named deference has an edge
out=$(pc_deference_edges plugins) && g=0 || g=$?
if [ "$g" -eq 0 ] && [ -z "$out" ]; then
  echo "PASS: shipped tree — every plugin-named deference claim is backed by a lane edge"
else
  echo "FAIL: shipped tree flagged (rc=$g): $out"; rc=1
fi

# 2. FAIL path — code-architecture's description defers topology to system-design;
#    delete that yields_to edge in a mirror and the gate must name the pair.
mkdir -p "$T/plugins"
cp -R plugins/code-architecture plugins/system-design "$T/plugins/"
# portable (GNU + BSD): rewrite through a temp file instead of sed -i
awk -F'\t' 'BEGIN{OFS="\t"} !/^#/ && NF==6 && $6=="system-design:system-design-reviewer" { $6="-" } { print }' \
  "$T/plugins/code-architecture/lane.tsv" > "$T/lane.tmp" && mv "$T/lane.tmp" "$T/plugins/code-architecture/lane.tsv"
grep -q 'system-design:' "$T/plugins/code-architecture/lane.tsv" && { echo "FAIL: fixture edit did not remove the edge"; rc=1; }
out=$(pc_deference_edges "$T/plugins") && g=0 || g=$?
case "$g:$out" in
  1:*'deference code-architecture -> system-design'*) echo "PASS: unbacked claim fails with 'deference code-architecture -> system-design'" ;;
  *) echo "FAIL: unbacked claim not flagged (rc=$g; out=$out)"; rc=1 ;;
esac

# 3. SKIP path — llm-app defers to "Claude Code's built-in claude-api skill";
#    no plugin directory is named, so the clause must produce no output and no failure.
rm -rf "$T/plugins"; mkdir -p "$T/plugins"
cp -R plugins/llm-app "$T/plugins/"
out=$(pc_deference_edges "$T/plugins") && g=0 || g=$?
if [ "$g" -eq 0 ] && [ -z "$out" ]; then
  echo "PASS: host-built-in deference target is skipped, not failed"
else
  echo "FAIL: host-built-in target was flagged (rc=$g; out=$out)"; rc=1
fi

# 4. the clause regex must not fire on prose that merely contains 'to'
rm -rf "$T/plugins"; mkdir -p "$T/plugins/zz-probe/.claude-plugin" "$T/plugins/testing"
printf '{"name":"zz-probe","version":"0.0.1","description":"Routes work to testing. Nothing is deferred here."}\n' > "$T/plugins/zz-probe/.claude-plugin/plugin.json"
out=$(pc_deference_edges "$T/plugins") && g=0 || g=$?
if [ "$g" -eq 0 ] && [ -z "$out" ]; then
  echo "PASS: a description without a defers-clause is not scanned"
else
  echo "FAIL: non-deference prose was flagged (rc=$g; out=$out)"; rc=1
fi

# 5. a plugin with NO lane.tsv at all counts as no edge; the passive verb form is
#    caught too ("is deferred to" — the class the first regex missed)
rm -rf "$T/plugins"; mkdir -p "$T/plugins/zz-deference-probe/.claude-plugin" "$T/plugins/testing"
printf '{"name":"zz-deference-probe","version":"0.0.1","description":"Probe. Everything here is deferred to testing."}\n' > "$T/plugins/zz-deference-probe/.claude-plugin/plugin.json"
out=$(pc_deference_edges "$T/plugins") && g=0 || g=$?
case "$g:$out" in
  1:*'deference zz-deference-probe -> testing'*) echo "PASS: passive 'is deferred to' with no lane.tsv at all fails" ;;
  *) echo "FAIL: no-lane.tsv passive claim not flagged (rc=$g; out=$out)"; rc=1 ;;
esac

# 6. validate.sh wiring — the call site's FAIL string reaches the build. Mirror the
#    tree the way role-floors-check.sh does, break the same edge as case 2, run the
#    real validate.sh there, and assert the lane_err hint verbatim.
MIRROR="$T/mirror"; mkdir -p "$MIRROR"
for _d in plugins scripts templates .claude-plugin; do
  [ -e "$LIVE/$_d" ] && cp -R "$LIVE/$_d" "$MIRROR/" 2>/dev/null
done
for _f in CLAUDE.md README.md skills-lock.json; do
  [ -f "$LIVE/$_f" ] && cp "$LIVE/$_f" "$MIRROR/" 2>/dev/null
done
awk -F'\t' 'BEGIN{OFS="\t"} !/^#/ && NF==6 && $6=="system-design:system-design-reviewer" { $6="-" } { print }' \
  "$MIRROR/plugins/code-architecture/lane.tsv" > "$T/lane.tmp" && mv "$T/lane.tmp" "$MIRROR/plugins/code-architecture/lane.tsv"
vout=$( cd "$MIRROR" && bash scripts/validate.sh 2>&1 ) && vrc=0 || vrc=$?
if [ "$vrc" -ne 0 ] && printf '%s\n' "$vout" | grep -qF 'deference code-architecture -> system-design — plugin.json promises deference to a plugin that no lane row yields to'; then
  echo "PASS: validate.sh wiring — the deference FAIL string reaches the build"
else
  echo "FAIL: validate.sh did not surface the deference string (rc=$vrc)"; printf '%s\n' "$vout" | grep -i 'deference' | head -3; rc=1
fi

[ "$rc" -eq 0 ] && echo "deference-check: all PASS"
exit $rc
