#!/usr/bin/env bash
# Parity harness: the ONE smoke harness that runs validate.sh end to end; every other
# validate.sh harness calls its pc_* function directly. One run proves each check's FAIL
# string survives validate.sh's call site to the build: SKILL budget, doc-location, jargon
# and removed-artifact (a skill and a plugin-root README), lane schema, deference (and a
# non-zero exit), role-floor unclassified pin and exemption report, stray dir (the only
# line naming it), and both route-prompt checks.
# Plants go into a git mirror, never the live tree: two of them edit shipped files (a
# plugin.json, skill-router's route-prompt.sh), and live plants have both reached a commit
# after a killed run and reverted a completed feature on restore. validate.sh cds to its
# own root, so the mirror's copy validates the mirror. The direct pc_* cases after the run
# only read live fixture files.
set -u
cd "$(dirname "$0")/../../.." || exit 2   # repo root
P=plugins/debugging
SK="$P/skills/_parity_scratch"
DOC="$P/_parity_scratch.md"
RM="$P/README.md"
LT="$P/lane.tsv"
RFA="$P/agents/_parity_rf.md"
RFX="$P/agents/_parity_rf_exempt.md"
RFX_REASON="parity fixture proving the exemption report is wired"
CA=plugins/code-architecture/.claude-plugin/plugin.json
RP=plugins/skill-router/hooks/route-prompt.sh
STRAY=plugins/_parity_stray
EDITED="$RM $LT $CA $RP"
EDITED_SUMS=$(cksum $EDITED) || exit 2
MIRROR=$(mktemp -d) || exit 2
cleanup() {
  rm -rf "$MIRROR"
  [ -n "${JTMP:-}" ] && rm -f "$JTMP"
  bad=0
  for f in "$SK" "$DOC" "$P"/agents/_parity_* plugins/_parity_*; do
    [ -e "$f" ] && { echo "FAIL: parity debris in the live tree: $f"; bad=1; }
  done
  if grep -qE '^Track cards 03 and 05 here\.$|^- \*\*typescript\*\* — planted stale member row$' "$RM" 2>/dev/null; then
    echo "FAIL: planted README lines in the live $RM"; bad=1
  fi
  [ "$(cksum $EDITED)" = "$EDITED_SUMS" ] \
    || { echo "FAIL: a live file the mirror plants edit changed during the run: $EDITED"; bad=1; }
  [ "$bad" -eq 0 ] || exit 1
}
trap cleanup EXIT INT TERM HUP

for d in plugins scripts templates .claude-plugin; do cp -R "$d" "$MIRROR/" || exit 2; done
for f in CLAUDE.md README.md skills-lock.json .gitignore; do cp "$f" "$MIRROR/" || exit 2; done
# The stray check reads git's index, so the index is built before any plant lands.
{ git -C "$MIRROR" init -q && git -C "$MIRROR" add -A; } \
  || { echo "FAIL: could not build the mirror's git index"; exit 1; }

mkdir -p "$MIRROR/$SK"
{
  echo '---'; echo 'name: _parity_scratch'
  echo 'description: Use when proving the budget check fires on an over-length body.'
  echo '---'; echo
  echo "Resolve card 07 before continuing."
  echo "Then install the vue2 plugin for the legacy apps."
  for i in $(seq 3 220); do echo "line $i"; done
} > "$MIRROR/$SK/SKILL.md"
echo "# stray" > "$MIRROR/$DOC"
{
  echo "Track cards 03 and 05 here."
  echo "- **typescript** — planted stale member row"
} >> "$MIRROR/$RM"
printf 'debugging:debugger\tagent\tverify\tno-yields-column\ta checkable condition\n' >> "$MIRROR/$LT"
jq '.description = "Fixture: defers pipeline topology to the devops plugin."' "$MIRROR/$CA" > "$MIRROR/$CA.tmp" \
  && mv "$MIRROR/$CA.tmp" "$MIRROR/$CA" || exit 2
mkagent() {  # mkagent <path> <name> [extra frontmatter lines]
  { printf -- '---\n'
    printf 'name: %s\n' "$2"
    printf 'description: Spawned by the parity harness to prove a role-floor path reaches the build.\n'
    printf 'model: sonnet\n'
    printf 'effort: low\n'
    shift 2
    for line in "$@"; do printf '%s\n' "$line"; done
    printf -- '---\n\nscratch\n'
  } > "$MIRROR/$1"
}
mkagent "$RFA" _parity_rf
mkagent "$RFX" _parity_rf_exempt 'floor: none' "floor-reason: $RFX_REASON"
mkdir -p "$MIRROR/$STRAY/.claude/scratch" && : > "$MIRROR/$STRAY/.claude/scratch/marker"
{
  printf 'echo /taskmaster:task\n'
  printf '%s\n' 'printf '"'"'%s'"'"' "$head" | grep -qiE "landing page" && exit 0'
} >> "$MIRROR/$RP"

out=$( cd "$MIRROR" && bash scripts/validate.sh 2>&1 ) && vrc=0 || vrc=$?
rc=0
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: body is 221 lines, over the 200-line ceiling" \
  && echo "PASS: budget FAIL fires" || { echo "FAIL: budget check did not fire"; rc=1; }
printf '%s\n' "$out" | grep -qF "$DOC: non-functional doc inside a plugin" \
  && echo "PASS: doc-location FAIL fires" || { echo "FAIL: doc-location check did not fire"; rc=1; }
# validate.sh's own jargon wiring: the find path set, the taskmaster/task-runner
# skip arm, and the "[$hit]" interpolation. Calling pc_jargon directly (below)
# cannot catch an empty bracket or a broken call site.
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: leaked internal taskmaster jargon [card 07]" \
  && echo "PASS: jargon wiring fires with populated hit" \
  || { echo "FAIL: validate.sh jargon wiring did not fire with [card 07]"; rc=1; }
# Removed-artifact wiring on the same scratch SKILL.md (find path set + "[$rhit]").
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: references removed marketplace artifact [vue2 plugin]" \
  && echo "PASS: removed-refs wiring fires with populated hit" \
  || { echo "FAIL: validate.sh removed-refs wiring did not fire with [vue2 plugin]"; rc=1; }
# Plugin-root doc wiring: both gates must see the planted README lines.
printf '%s\n' "$out" | grep -qF "$RM: leaked internal taskmaster jargon [cards 03]" \
  && echo "PASS: jargon wiring reaches plugin-root README (plural cards NN)" \
  || { echo "FAIL: jargon wiring did not fire on $RM with [cards 03]"; rc=1; }
printf '%s\n' "$out" | grep -qF "$RM: references removed marketplace artifact [**typescript**]" \
  && echo "PASS: removed-refs wiring reaches plugin-root README" \
  || { echo "FAIL: removed-refs wiring did not fire on $RM with [**typescript**]"; rc=1; }
printf '%s\n' "$out" | grep -F "FAIL: lane-schema $LT:" \
  | grep -qF '5 fields (want 6) — a lane row is 6 tab-separated fields (artifact kind phase owns definite_trigger yields_to)' \
  && echo "PASS: e2e lane-schema FAIL reaches the build" \
  || { echo "FAIL: e2e lane-schema FAIL for the 5-field row in $LT did not reach the build"; rc=1; }
[ "$vrc" -ne 0 ] && printf '%s\n' "$out" | grep -qF 'FAIL: deference code-architecture -> devops — plugin.json promises deference to a plugin that no lane row yields to — add the yields_to edge or reword the description' \
  && echo "PASS: e2e deference FAIL reaches the build" \
  || { echo "FAIL: e2e deference FAIL did not reach the build (validate.sh rc=$vrc, want non-zero)"; rc=1; }
printf '%s\n' "$out" | grep -qF "FAIL: $RFA: pins model 'sonnet' but has neither a role-floors row nor 'floor: none'" \
  && echo "PASS: e2e role-floor FAIL reaches the build" \
  || { echo "FAIL: e2e role-floor unclassified-pin FAIL for $RFA did not reach the build"; rc=1; }
printf '%s\n' "$out" | grep -qxF "  $RFX: $RFX_REASON" \
  && echo "PASS: role-floor exemption reaches the build's exemption report" \
  || { echo "FAIL: $RFX's floor-reason is missing from the '== role-floor exemptions ==' report"; rc=1; }
stray_lines=$(printf '%s\n' "$out" | grep -cF "${STRAY#plugins/}")
if printf '%s\n' "$out" | grep -qxF "FAIL: stray directory $STRAY has no tracked files — delete it (a hook or editor left scratch here)" \
   && [ "$stray_lines" -eq 1 ]; then
  echo "PASS: e2e stray-dir FAIL reaches the build and is the only line naming it"
else
  echo "FAIL: e2e stray-dir FAIL missing, or $STRAY named on $stray_lines lines (want exactly 1)"; rc=1
fi
printf '%s\n' "$out" | grep -qF 'FAIL: skill-router route-prompt.sh carries literal command token(s): /taskmaster:task — the catalog is built from installed plugins, never hardcoded' \
  && echo "PASS: e2e route-prompt literal-token FAIL reaches the build" \
  || { echo "FAIL: e2e route-prompt literal-token FAIL did not reach the build"; rc=1; }
printf '%s\n' "$out" | grep -qF 'FAIL: skill-router route-prompt.sh matches the prompt 5 times — at most 4 (three narrowing refusals + one work-shaped gate); a fifth is a routing table regrowing in shell' \
  && echo "PASS: e2e route-prompt fifth-grep FAIL reaches the build" \
  || { echo "FAIL: e2e route-prompt fifth-grep FAIL did not reach the build"; rc=1; }

# ---------------------------------------------------------------------------
# Jargon gate: both directions, plus the escape hatch.
#
# Before this block the jargon check had ZERO fixture coverage, its rescue list
# did not exist, and <!-- jargon-ok --> was used zero times in the repo — an
# untested escape from a gate that rejected ordinary English.
#
# Exercises pc_jargon directly — the SAME function validate.sh calls, so there is
# no second copy of the patterns to drift. Direct calls also keep this harness
# fast; routing each case through a full validate.sh run took ~2min.
# ---------------------------------------------------------------------------
. scripts/lib/plugin-checks.sh
JTMP=$(mktemp)

jseed() { printf '%s\n' "$1" > "$JTMP"; }

# Both channels are asserted on every case. validate.sh branches on pc_jargon's
# EXIT STATUS and interpolates its STDOUT; a regression that prints matches while
# returning 0 (gate silently dead) or returns 1 with an empty hit (an empty
# bracket in the error) is invisible to a stdout-only assertion.
jassert_hit() { # $1 desc  $2 line
  jseed "$2"; out_j=$(pc_jargon "$JTMP"); st=$?
  if [ "$st" -eq 1 ] && [ -n "$out_j" ]; then echo "PASS: $1"
  else echo "FAIL: $1 (status=$st hit='$out_j'; want status 1 + non-empty)"; rc=1; fi
}
jassert_clean() { # $1 desc  $2 line
  jseed "$2"; out_j=$(pc_jargon "$JTMP"); st=$?
  if [ "$st" -eq 0 ] && [ -z "$out_j" ]; then echo "PASS: $1"
  else echo "FAIL: $1 (status=$st hit='$out_j'; want status 0 + empty)"; rc=1; fi
}

# TRUE POSITIVE — the internal vocabulary must still be caught.
jassert_hit "jargon fires on 'card 07'" 'Resolve card 07 before continuing.'
# Plural form (2026-07-28): "cards 03, 05" leaked past the singular-only pattern.
jassert_hit "jargon fires on plural 'cards 03'" 'Track cards 03, 05, 06 in one place.'

# FALSE POSITIVES — ordinary English a plugin has every right to write.
jassert_clean "jargon allows: credit card 16 digits"   'Use a credit card 16 digits long.'
jassert_clean "jargon allows: the backlog of stories"  'The backlog of user stories is groomed weekly.'
jassert_clean "jargon allows: finding #2 in a report"  'See finding #2 in the OWASP report for the remediation.'
jassert_clean "jargon allows: smoke test 3 in a suite" 'Run smoke test 3 in the regression suite.'
jassert_clean "jargon allows: cards without numbers"   'A task splits into seven cards; four of them ship.'

# ESCAPE HATCH — an author legitimately quoting the vocabulary.
jassert_clean "<!-- jargon-ok --> suppresses" 'Resolve card 07 here. <!-- jargon-ok -->'
jassert_clean "<!-- jargon-ok --> suppresses plural" 'Track cards 03 and 05 here. <!-- jargon-ok -->'

# ---------------------------------------------------------------------------
# Removed-artifact gate (pc_removed_refs): both directions, plus both escapes.
#
# Fixture FILES live in scripts/smoke/validate-fixtures/removed-refs/ — each is
# a one-shape probe (or a rescue probe) named for what it proves. Direct calls
# exercise the SAME function validate.sh runs; the wiring assertions above
# already proved the call site and the "[$rhit]" interpolation.
# ---------------------------------------------------------------------------
FIXD=scripts/smoke/validate-fixtures/removed-refs
rassert_hit() { # $1 fixture file
  out_r=$(pc_removed_refs "$FIXD/$1"); st=$?
  if [ "$st" -eq 1 ] && [ -n "$out_r" ]; then echo "PASS: removed-refs hit: $1"
  else echo "FAIL: removed-refs $1 (status=$st hit='$out_r'; want status 1 + non-empty)"; rc=1; fi
}
rassert_clean() { # $1 fixture file
  out_r=$(pc_removed_refs "$FIXD/$1"); st=$?
  if [ "$st" -eq 0 ] && [ -z "$out_r" ]; then echo "PASS: removed-refs clean: $1"
  else echo "FAIL: removed-refs $1 (status=$st hit='$out_r'; want status 0 + empty)"; rc=1; fi
}

# TRUE POSITIVES — every reference shape the W6.5 residue actually shipped in.
rassert_hit   violation-vue2-plugin.md         # "<name> plugin" prose
rassert_hit   violation-bold-member-row.md     # **name** pairs-well/member row
rassert_hit   violation-skill-name.md          # removed skill name, word-bounded
rassert_hit   violation-install-target.md      # name@marketplace install pointer
rassert_hit   violation-routing-arrow.md       # "→ name" fan-in routing row
rassert_hit   violation-claude-api.md          # claude-api as if a marketplace skill
rassert_hit   violation-stamp-line-plugin-ref.md # a real plugin ref on a stamp line is still caught

# RESCUES — honest wording stays legal without a marker.
rassert_clean rescued-claude-api-builtin.md    # "built-in" on the same line
rassert_clean rescued-claude-api-external.md   # "external" on the same line
rassert_clean rescued-claude-api-harness.md    # shipped wrapped disclosure line
rassert_clean rescued-removal-discussion.md    # "was removed"/"plugins were"/"no longer"
rassert_clean clean-ordinary-english.md        # rollout/concurrency/etc. as plain English
rassert_clean rescued-npm-version-stamp.md     # npm:<pkg>@<ver> in a Last-verified stamp is a package, not a plugin

# ESCAPE HATCH — <!-- removed-ok --> suppresses a would-be hit.
rassert_clean rescued-removed-ok-marker.md

# ---------------------------------------------------------------------------
# Dispatch-binding gate: both directions, both structural guards, the escape.
#
# A `Workflow` agent() sample that spawns a shipped agent without `agentType`
# dispatches the GENERIC workflow subagent instead — same prompt, no contract, and
# a transcript that reads identically. `agentType` appeared zero times across this
# marketplace before the gate existed, so every shipped agent contract was
# decorative on that path.
#
# Fixtures live under a fake plugins root so the own-plugin and cross-plugin
# resolution arms are both exercised with a real `<root>/<plugin>/agents/<name>.md`
# probe — the same second argument validate.sh passes.
# ---------------------------------------------------------------------------
DFIXD=scripts/smoke/validate-fixtures/dispatch-binding
DR="$DFIXD/fakeplug/skills/s/references"
dassert_hit() { # $1 fixture file, $2 expected agent token
  out_d=$(pc_dispatch_binding "$DR/$1" "$DFIXD"); st=$?
  if [ "$st" -eq 1 ] && printf '%s' "$out_d" | grep -qF "$2"; then echo "PASS: dispatch-binding hit: $1"
  else echo "FAIL: dispatch-binding $1 (status=$st hit='$out_d'; want status 1 + '$2')"; rc=1; fi
}
dassert_clean() { # $1 fixture file
  out_d=$(pc_dispatch_binding "$DR/$1" "$DFIXD"); st=$?
  if [ "$st" -eq 0 ] && [ -z "$out_d" ]; then echo "PASS: dispatch-binding clean: $1"
  else echo "FAIL: dispatch-binding $1 (status=$st hit='$out_d'; want status 0 + empty)"; rc=1; fi
}

dassert_hit   violation-own-agent.md    fakeplug:worker    # backticked own-plugin agent
dassert_hit   violation-cross-plugin.md otherplug:helper   # `plugin:agent` form

dassert_clean clean-agenttype.md      # the binding is present
dassert_clean clean-api-mention.md    # guard 1: `agent()` empty parens is not a call
dassert_clean clean-no-agent-ref.md   # guard 2: no shipped agent named -> generic is right
dassert_clean rescued-dispatch-ok.md  # <!-- dispatch-ok --> suppresses a would-be hit

exit $rc
