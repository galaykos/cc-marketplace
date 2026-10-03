#!/usr/bin/env bash
# Deference-gate harness: proves pc_deference_edges (scripts/lib/plugin-checks.sh)
# fires on an unbacked "defers X to <plugin>" claim, passes the shipped tree, SKIPS
# a claim whose target is a host built-in or a plugin class (no directory to
# resolve), and that validate.sh calls it and hands its output to lane_err with its
# hint. The FAIL string reaching the build end-to-end is parity-check.sh's assertion.
# CI step: .github/workflows/validate.yml "deference gate harness".
#
# RUN AGAINST A MIRROR, NEVER THE LIVE TREE (the rule role-floors-check.sh learned
# after three leaked scratch files). Every plant below lands under $T; the live
# tree is only ever READ, and an integrity assertion at exit proves it.
set -u
LIVE="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 2
cd "$LIVE" || exit 2
. scripts/lib/plugin-checks.sh || exit 2
# jq missing is a silent green locally; under CI it is a broken runner image — fail loud.
command -v jq >/dev/null 2>&1 || {
  [ -n "${CI:-}" ] && { echo "FAIL: jq missing on the CI runner"; exit 1; }
  echo "SKIP: jq not installed"; exit 0
}
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
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

# 1. the shipped tree is clean — every plugin-named deference has an edge
out=$(pc_deference_edges plugins) && g=0 || g=$?
if [ "$g" -eq 0 ] && [ -z "$out" ]; then
  echo "PASS: shipped tree — every plugin-named deference claim is backed by a lane edge"
else
  echo "FAIL: shipped tree flagged (rc=$g): $out"; rc=1
fi

# 2. FAIL path — a description that defers to a sibling plugin with no yields_to edge
#    to that plugin must be named as a pair. Synthesized: a mirror of code-architecture
#    whose description is rewritten to defer topology to devops (a real sibling, no
#    lane edge). The shipped code-architecture -> system-design claim this case used
#    to break was retired when system-design folded in on 2026-09-14.
mkdir -p "$T/plugins"
cp -R plugins/code-architecture plugins/devops "$T/plugins/"
jq '.description = "Fixture: defers pipeline topology to the devops plugin."' \
  "$T/plugins/code-architecture/.claude-plugin/plugin.json" > "$T/pj.tmp" && mv "$T/pj.tmp" "$T/plugins/code-architecture/.claude-plugin/plugin.json"
grep -q 'devops:' "$T/plugins/code-architecture/lane.tsv" && { echo "FAIL: fixture already carries a devops edge"; rc=1; }
out=$(pc_deference_edges "$T/plugins") && g=0 || g=$?
case "$g:$out" in
  1:*'deference code-architecture -> devops'*) echo "PASS: unbacked claim fails with 'deference code-architecture -> devops'" ;;
  *) echo "FAIL: unbacked claim not flagged (rc=$g; out=$out)"; rc=1 ;;
esac

# 3. SKIP path — a description that defers to "Claude Code's built-in claude-api skill"
#    names no plugin directory, so the clause must produce no output and no failure.
#    Synthesized fixture: the shipped plugin that carried this wording (llm-app) was
#    removed 2026-09-14, and the check must keep proving the skip path without it.
rm -rf "$T/plugins"; mkdir -p "$T/plugins/defer-fixture/.claude-plugin"
printf '%s\n' '{"name":"defer-fixture","version":"0.0.1","description":"Fixture: defers provider API specifics to Claude Code'"'"'s built-in claude-api skill (harness-provided, not part of this marketplace)."}' \
  > "$T/plugins/defer-fixture/.claude-plugin/plugin.json"
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

# 6. validate.sh wiring — the call runs over plugins/ and its output reaches lane_err
#    with the hint, not an empty message.
DEF_HINT='plugin.json promises deference to a plugin that no lane row yields to — add the yields_to edge or reword the description'
if grep -v '^[[:space:]]*#' scripts/validate.sh | grep -A1 -F 'def_gap=$(pc_deference_edges plugins)' \
   | grep -qF "lane_err \"\$def_gap\" \"$DEF_HINT\""; then
  echo "PASS: validate.sh wiring — pc_deference_edges output reaches lane_err with its hint"
else
  echo "FAIL: validate.sh no longer calls pc_deference_edges plugins with the hint: $DEF_HINT"; rc=1
fi

[ "$rc" -eq 0 ] && echo "deference-check: all PASS"
exit $rc
