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
# RESULT AS OF 2026-09-15 (CLI 2.1.272): 47/55 vs 47/55 — zero delta. Full write-up,
# including what it does NOT establish, in
# rationale/2026-09-15-listing-eviction-probe.md. Re-run it before trusting that
# number against a new CLI or model; state the run count and spread with any delta,
# per CLAUDE.md, or do not state the delta.
set -u
command -v claude >/dev/null 2>&1 || { echo "SKIP: claude CLI not on PATH"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; exit 0; }

N=${N:-5}                       # runs per arm; the shipped table used 5-20
ROOT=$(mktemp -d) || exit 2
trap 'rm -rf "$ROOT"' EXIT INT TERM HUP

TARGET_DESC='Use before reusing an existing function, class, or symbol — confirm it is not deprecated or an abandoned orphan — and when a change removes the last caller of something, so no new dead code is left behind.'
PROMPT='There is an existing formatPrice() helper in src/utils. I am going to call it from the new checkout page I am writing.'

# build <dir> <arm> <n_decoys> <rivals:0|1>
build() {
  python3 - "$1" "$2" "$3" "$4" "$TARGET_DESC" <<'PY'
import os, sys
d, arm, n_decoys, rivals, tdesc = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]=='1', sys.argv[5]
base=os.path.join(d, '.claude', 'skills'); os.makedirs(base, exist_ok=True)
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
w('reuse-hygiene', tdesc if arm == 'with-desc' else None,
  "When this skill is invoked, the FIRST line of your reply must be exactly:\n\nPROBE_FIRED\n\nThen stop.\n")
PY
}

run_arm() { # <dir> -> "<hits> <seq>"
  local hits=0 seq="" i out
  for i in $(seq 1 "$N"); do
    out=$(cd "$1" && claude -p "$PROMPT" --permission-mode bypassPermissions 2>/dev/null | head -3)
    case "$out" in *PROBE_FIRED*) hits=$((hits+1)); seq="$seq+" ;; *) seq="$seq." ;; esac
  done
  printf '%s %s' "$hits" "$seq"
}

printf '%-46s %10s %10s\n' "condition" "with-desc" "name-only"
tw=0; tn=0
probe() { # <label> <n_decoys> <rivals>
  local a b
  for arm in with-desc name-only; do
    rm -rf "$ROOT/$arm"; mkdir -p "$ROOT/$arm"; build "$ROOT/$arm" "$arm" "$2" "$3"
  done
  a=$(run_arm "$ROOT/with-desc"); b=$(run_arm "$ROOT/name-only")
  tw=$((tw + ${a%% *})); tn=$((tn + ${b%% *}))
  printf '%-46s %10s %10s\n' "$1" "${a%% *}/$N ${a##* }" "${b%% *}/$N ${b##* }"
}

probe "1 skill, opaque target name"            0   0
probe "13 skills, described decoys"            12  0
probe "205 skills, 8 same-territory rivals"    196 1

echo
echo "TOTAL  with-desc $tw   name-only $tn   (N=$N per arm per condition)"
echo "A delta here is only a finding if it survives a re-run — see the rationale doc."
