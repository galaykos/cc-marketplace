#!/usr/bin/env bash
# Parity harness: proves validate.sh — now sourcing scripts/lib/plugin-checks.sh —
# still fires the SKILL-budget, doc-location, jargon and removed-artifact FAIL
# paths with its exact messages. Plants throwaway violations in a listed plugin
# (including its plugin-root README, backed up and byte-verified on restore),
# runs validate, asserts, cleans up.
# Runnable in CI on every lib change (guards the shared-lib refactor against drift).
set -u
cd "$(dirname "$0")/../../.." || exit 2   # repo root
P=plugins/debugging
SK="$P/skills/_parity_scratch"
DOC="$P/_parity_scratch.md"
RM="$P/README.md"
RBAK=$(mktemp) || exit 2
cp "$RM" "$RBAK" || exit 2
cleanup() {
  rm -rf "$SK" "$DOC" ${DP_TMPDIR:+"$DP_TMPDIR"} ${LD_TMPDIR:+"$LD_TMPDIR"}
  bad=0
  if [ -f "$RBAK" ]; then
    cp "$RBAK" "$RM"
    cmp -s "$RBAK" "$RM" || { echo "FAIL: $RM not restored"; bad=1; }
    rm -f "$RBAK"
  fi
  [ "$bad" -eq 0 ] || exit 1
}
trap cleanup EXIT
mkdir -p "$SK"
{
  echo '---'; echo 'name: _parity_scratch'
  echo 'description: Use when proving the budget check fires on an over-length body.'
  echo '---'; echo
  echo "Resolve card 07 before continuing."
  echo "Then install the vue2 plugin for the legacy apps."
  for i in $(seq 3 170); do echo "line $i"; done
} > "$SK/SKILL.md"
echo "# stray" > "$DOC"
# Plugin-root docs joined the jargon/removed-artifact scan (they escaped it
# entirely before): plant a plural-jargon line and a stale bolded member row in
# the live README — restored byte-identical by cleanup.
{
  echo "Track cards 03 and 05 here."
  echo "- **typescript** — planted stale member row"
} >> "$RM"

out=$(bash scripts/validate.sh 2>&1)
rc=0
printf '%s\n' "$out" | grep -qF "$SK/SKILL.md: body is 171 lines, over the 150-line ceiling" \
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
cleanup_j() { rm -f "$JTMP"; }
trap 'cleanup; cleanup_j' EXIT

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

# RESCUES — honest wording stays legal without a marker.
rassert_clean rescued-claude-api-builtin.md    # "built-in" on the same line
rassert_clean rescued-claude-api-external.md   # "external" on the same line
rassert_clean rescued-claude-api-harness.md    # shipped wrapped disclosure line
rassert_clean rescued-removal-discussion.md    # "was removed"/"plugins were"/"no longer"
rassert_clean clean-ordinary-english.md        # rollout/concurrency/etc. as plain English

# ESCAPE HATCH — <!-- removed-ok --> suppresses a would-be hit.
rassert_clean rescued-removed-ok-marker.md

# ---------------------------------------------------------------------------
# Dispatch-priming gate: both directions, plus the escape hatch.
#
# The bug this gate exists for was invisible for as long as the templates had
# existed: every dispatch site named a rubric and injected nothing, and prose
# promising an injection reads exactly like prose performing one. Exercises
# pc_dispatch_priming directly — same function validate.sh calls.
# ---------------------------------------------------------------------------
DPD=$(mktemp -d) || exit 2
# NOTE: do NOT `trap ... EXIT` here — it would REPLACE the cleanup trap set above
# and leak the planted scratch files into plugins/. Extend cleanup() instead.
DP_TMPDIR="$DPD"
dp() { printf '%s\n' "$2" > "$DPD/$1"; }

dp bad-dispatch.md          'On an apply pick, dispatch the finding list down the chain `x:worker → inline`.'
dp bad-worker.md            'On implement, dispatch the `system-architect` worker with the finding list.'
dp bad-route.md             'Headless aside, route accepted fixes to `task-runner:task-executor` when installed.'
dp ok-doctrine.md           'Dispatch the finding list down the chain. Prime it per `delegation-contracts` § Skill priming.'
dp ok-mechanism.md          'Dispatch the fix list down the chain, and inject `Read <abs-path>` per resolved skill.'
dp ok-marker.md             'Dispatch the finding list down the chain. <!-- priming-ok -->'
dp clean-no-dispatch.md     'What situation should make the main session dispatch this agent, and what does it return?'
dp clean-mention.md         'The reviewer is read-only; a file-editing worker is the wrong shape for a prompt fix.'

dpassert_hit() {
  out_d=$(pc_dispatch_priming "$DPD/$1"); st=$?
  if [ "$st" -ne 0 ] && [ -n "$out_d" ]; then echo "PASS: dispatch-priming hit: $1"
  else echo "FAIL: dispatch-priming $1 (status=$st hit='$out_d'; want nonzero + name)"; rc=1; fi
}
dpassert_clean() {
  out_d=$(pc_dispatch_priming "$DPD/$1"); st=$?
  if [ "$st" -eq 0 ] && [ -z "$out_d" ]; then echo "PASS: dispatch-priming clean: $1"
  else echo "FAIL: dispatch-priming $1 (status=$st hit='$out_d'; want status 0 + empty)"; rc=1; fi
}

# TRUE POSITIVES — a dispatch with no priming step, in each phrasing that ships.
dpassert_hit   bad-dispatch.md
dpassert_hit   bad-worker.md
dpassert_hit   bad-route.md

# RESCUES — either accepted proof clears it.
dpassert_clean ok-doctrine.md      # cites the doctrine
dpassert_clean ok-mechanism.md     # spells the mechanism out

# ESCAPE HATCH + TRUE NEGATIVES.
dpassert_clean ok-marker.md        # <!-- priming-ok --> suppresses
dpassert_clean clean-no-dispatch.md  # "dispatch this agent" in authoring prose is not a dispatch
dpassert_clean clean-mention.md      # merely mentioning a worker is not a dispatch

# ---------------------------------------------------------------------------
# Ladder-drift gate: both directions, both expression forms.
#
# apply-lane generates 30+ review commands and sat three rounds behind the agent
# side with a stale resolution ladder. Nobody noticed because a stale ladder still
# resolves most skills most of the time — it fails only on the cases each fix was
# written for. The gate must also accept the PROSE form the no-Bash agents use, or
# it fails correct files.
# ---------------------------------------------------------------------------
LDD=$(mktemp -d) || exit 2
LD_TMPDIR="$LDD"
ld() { printf '%s\n' "$2" > "$LDD/$1"; }

FULL_SH='find ~/.claude/plugins/marketplaces \( -path "*/skills/$s/SKILL.md" -o -path "*/skills/*/$s/SKILL.md" \) | grep -v "/[^/]*\.bak/" | grep -v "/marketplaces/[^/]*/\." | sort
awk -F/ "{for(i=NF;i>0;i--) ...}"'
FULL_PROSE='resolve under ~/.claude/plugins/marketplaces, also matching skills/*/<name>/SKILL.md;
discard .bak components and dot-prefixed components under a marketplace root;
among cache paths take the highest version directory.'

ld full-shell.md          "$FULL_SH"
ld full-prose.md          "$FULL_PROSE"
ld stale-no-nested.md     'find ~/.claude/plugins/marketplaces -path "*/skills/$s/SKILL.md" | grep -v "/[^/]*\.bak/" | grep -v "/marketplaces/[^/]*/\." | sort
awk -F/ "{for(i=NF;i>0;i--) ...}"'
ld stale-no-dotdir.md     'find ~/.claude/plugins/marketplaces \( -path "*/skills/$s/SKILL.md" -o -path "*/skills/*/$s/SKILL.md" \) | grep -v "/[^/]*\.bak/" | sort
awk -F/ "{for(i=NF;i>0;i--) ...}"'
ld stale-fixed-index.md   'find ~/.claude/plugins/marketplaces \( -path "*/skills/$s/SKILL.md" -o -path "*/skills/*/$s/SKILL.md" \) | grep -v "/[^/]*\.bak/" | grep -v "/marketplaces/[^/]*/\." | sort
awk -F/ "{print \$(NF-3)}"'
ld not-a-ladder.md        'This file mentions dispatch and priming but never names the resolution search root.'

ldassert_hit() {
  out_l=$(pc_ladder_drift "$LDD/$1"); st=$?
  if [ "$st" -ne 0 ] && [ -n "$out_l" ]; then echo "PASS: ladder-drift hit: $1"
  else echo "FAIL: ladder-drift $1 (status=$st hit='$out_l'; want nonzero + name)"; rc=1; fi
}
ldassert_clean() {
  out_l=$(pc_ladder_drift "$LDD/$1"); st=$?
  if [ "$st" -eq 0 ] && [ -z "$out_l" ]; then echo "PASS: ladder-drift clean: $1"
  else echo "FAIL: ladder-drift $1 (status=$st hit='$out_l'; want status 0 + empty)"; rc=1; fi
}

# TRUE POSITIVES — one per correction the ladder has actually had.
ldassert_hit   stale-no-nested.md      # nested-category skills reported UNRESOLVED
ldassert_hit   stale-no-dotdir.md      # other runtimes' mirrors win head -1
ldassert_hit   stale-fixed-index.md    # NF-3 keys a vendor dir on 74 real paths

# TRUE NEGATIVES — both expression forms are complete, and a non-ladder file is skipped.
ldassert_clean full-shell.md
ldassert_clean full-prose.md
ldassert_clean not-a-ladder.md

exit $rc
