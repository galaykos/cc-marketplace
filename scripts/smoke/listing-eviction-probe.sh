#!/usr/bin/env bash
# Listing-eviction probe — NOT a CI gate (needs a live model and costs real tokens),
# for the same reason scripts/smoke/canary.sh is not one.
#
# THE QUESTION. Four bundle READMEs, context-budget.sh's listing channel and
# pc_listing_declaration all assert that over the host's skill-listing budget the CLI
# reduces entries to name-only and skills "silently stop being reachable". The
# arithmetic is sound; the behavioural half had never been measured. This measures it.
#
# THE MANIPULATION. A listing entry is built from frontmatter `description`, so the
# faithful simulation of an evicted entry is a SKILL.md with that key absent — same
# name, same body, no description text reaching the model. Two arms differ in nothing
# else. The body tells the model to answer with a unique token, so firing is DETECTED,
# not judged. Conditions 4 and 5 set skillListingBudgetFraction high in the scratch
# project so the CLI's own eviction cannot confound the arms.
#
# RESULT AS OF 2026-09-15 (CLI 2.1.272): 47/50 vs 47/50 — zero delta. Full write-up,
# including what it does NOT establish, in
# rationale/2026-09-15-listing-eviction-probe.md. Re-run it before trusting that
# number against a new CLI or model; state the run count and spread with any delta,
# per CLAUDE.md, or do not state the delta.
#
# IT REPRODUCES THE WHOLE TABLE, and it did not at first: as shipped on 2026-09-15 it
# built three of the five conditions at one flat N, so the doc's "re-runnable harness"
# pointed at a different experiment than the one the doc reported. All five conditions,
# their individual run counts, and the negative control are encoded below. Set
# N_OVERRIDE=2 for a cheap wiring check; that is NOT the shipped design and its totals
# must not be quoted.
#
# IT DEFENDS ITSELF AGAINST THE PRE-PUSH LOOP. CLAUDE.md's prescribed "run the lot" loop
# globs scripts/smoke/*.sh and skips exactly one file BY NAME — canary.sh. Shipping a
# second live-model script here without an opt-in meant anyone following that instruction
# spent real model calls and real money on 100+ sessions. Claiming parity with canary.sh
# in a comment is not parity; this is.
set -u
[ "${LISTING_PROBE:-}" = 1 ] || { echo "SKIP: live-model probe — re-run with LISTING_PROBE=1"; exit 0; }
command -v claude >/dev/null 2>&1 || { echo "SKIP: claude CLI not on PATH"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; exit 0; }

# Per-condition run counts are the shipped design; N_OVERRIDE forces them all to one
# value for a wiring check. `N` is set per condition by probe(), not globally.
N_OVERRIDE=${N_OVERRIDE:-}
ROOT=$(mktemp -d) || exit 2
trap 'rm -rf "$ROOT"' EXIT INT TERM HUP

TARGET_DESC='Use before reusing an existing function, class, or symbol — confirm it is not deprecated or an abandoned orphan — and when a change removes the last caller of something, so no new dead code is left behind.'
PROMPT='There is an existing formatPrice() helper in src/utils. I am going to call it from the new checkout page I am writing.'

# Condition 1's target exists to separate two explanations of a null result: a name that
# already spells out its own trigger needs no description, so it is the arm where the
# description should matter LEAST. Its prompt is recorded here because the shipped table
# cannot be reproduced without it.
SELF_DESC='Use when a PDF contains personal or billing details that must be removed before the file is shared — redaction of invoice documents.'
SELF_PROMPT='We email invoice PDFs to partners and I need the customer address block taken out of them first.'

# build <dir> <arm> <n_decoys> <rivals:0|1> <target_name> <target_desc>
build() {
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" <<'PY'
import os, sys
d, arm, n_decoys, rivals = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]=='1'
tname, tdesc = sys.argv[5], sys.argv[6]
base=os.path.join(d, '.claude', 'skills'); os.makedirs(base, exist_ok=True)
# Conditions 4 and 5 raise the budget so the CLI's OWN eviction cannot confound the
# arms — the only manipulated variable must be the target's description.
if n_decoys > 50:
    open(os.path.join(d, '.claude', 'settings.json'), 'w').write('{ "skillListingBudgetFraction": 0.2 }\n')
def w(name, desc, body="Guidance.\n"):
    p=os.path.join(base, name); os.makedirs(p, exist_ok=True)
    fm = f"---\nname: {name}\n" + (f"description: {desc}\n" if desc else "") + "---\n"
    open(os.path.join(p, 'SKILL.md'), 'w', encoding='utf-8').write(fm + f"# {name}\n\n" + body)
if rivals:
    for n, ds in {
     'dead-code-sweep':'Use when code may be unreachable or unused — orphaned helpers, symbols with no callers, exports nobody imports.',
     'deprecation-audit':'Use when a symbol may be deprecated — check annotations and replacement guidance before calling an existing function.',
     'import-hygiene':'Use when adding an import or calling a module from a new place — path conventions, circular dependencies, public API.',
     'helper-extraction':'Use when logic is duplicated — decide whether to reuse an existing helper, extend it, or write a new one.',
     'shared-utils-review':'Use when touching shared utility modules — who depends on them and whether a helper is safe to call from a new surface.',
     'legacy-code-contact':'Use when new code will call into older parts of the codebase — what to verify before depending on existing behaviour.',
     'api-surface-check':'Use before depending on an existing function from another module — is it public API, stable, still maintained.',
     'refactor-safety':'Use when changing or reusing existing code — callers, covering tests, what breaks if behaviour shifts.',
    }.items(): w(n, ds)
verbs="review audit shape plan verify trace profile model scaffold migrate harden document inspect refactor bundle".split()
nouns="pipeline schema payload widget cache queue router session manifest fixture locale gradient telemetry invoice sprite".split()
made=0
for v in verbs:
    for n in nouns:
        if made >= n_decoys: break
        w(f"{v}-{n}", f"Use when you need to {v} the {n} — covers {n} conventions, common {v} pitfalls, and how to verify the {n} afterwards.")
        made += 1
w(tname, tdesc if arm == 'with-desc' else None,
  "When this skill is invoked, the FIRST line of your reply must be exactly:\n\nPROBE_FIRED\n\nThen stop.\n")
PY
}

run_arm() { # <dir> <n> <prompt> -> "<hits> <seq>"
  local hits=0 seq="" i out
  for i in $(seq 1 "$2"); do
    out=$(cd "$1" && claude -p "$3" --permission-mode bypassPermissions 2>/dev/null | head -3)
    case "$out" in *PROBE_FIRED*) hits=$((hits+1)); seq="$seq+" ;; *) seq="$seq." ;; esac
  done
  printf '%s %s' "$hits" "$seq"
}

printf '%-46s %6s %11s %11s\n' "condition" "N" "with-desc" "name-only"
tw=0; tn=0; tN=0
probe() { # <label> <n_decoys> <rivals> <n_runs> <target_name> <target_desc> <prompt>
  local a b n="$4"
  [ -n "$N_OVERRIDE" ] && n="$N_OVERRIDE"
  for arm in with-desc name-only; do
    rm -rf "$ROOT/$arm"; mkdir -p "$ROOT/$arm"; build "$ROOT/$arm" "$arm" "$2" "$3" "$5" "$6"
  done
  a=$(run_arm "$ROOT/with-desc" "$n" "$7"); b=$(run_arm "$ROOT/name-only" "$n" "$7")
  tw=$((tw + ${a%% *})); tn=$((tn + ${b%% *})); tN=$((tN + n))
  printf '%-46s %6s %11s %11s\n' "$1" "$n" "${a%% *}/$n ${a##* }" "${b%% *}/$n ${b##* }"
}

probe "1  1 skill, self-describing name"    0   0  5  redact-invoice-pdf "$SELF_DESC"  "$SELF_PROMPT"
probe "2  1 skill, opaque name"             0   0  5  reuse-hygiene      "$TARGET_DESC" "$PROMPT"
probe "3  13 skills, 12 described decoys"   12  0  20 reuse-hygiene      "$TARGET_DESC" "$PROMPT"
probe "4  226 skills, 225 described decoys" 225 0  10 reuse-hygiene      "$TARGET_DESC" "$PROMPT"
probe "5  205 skills, 8 same-territory rivals" 196 1  10 reuse-hygiene      "$TARGET_DESC" "$PROMPT"

echo
echo "TOTAL  with-desc $tw/$tN   name-only $tn/$tN"

# Negative control. Without it a table of 5/5s proves only that the target always fires.
nc_runs=3; [ -n "$N_OVERRIDE" ] && nc_runs="$N_OVERRIDE"
rm -rf "$ROOT/nc"; mkdir -p "$ROOT/nc"
build "$ROOT/nc" with-desc 0 0 reuse-hygiene "$TARGET_DESC"
nc=$(run_arm "$ROOT/nc" "$nc_runs" 'What is the capital of Portugal?')
echo "NEGATIVE CONTROL (off-topic prompt, must be 0)  ${nc%% *}/$nc_runs ${nc##* }"
[ "${nc%% *}" = 0 ] || echo "WARN: the target fired on an unrelated prompt — the harness is not discriminating, and the table above means nothing."
echo
echo "A delta here is only a finding if it survives a re-run — see the rationale doc."
