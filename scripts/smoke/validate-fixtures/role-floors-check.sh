#!/usr/bin/env bash
# Role-floor gate harness: proves each of the nine frozen FAIL strings in
# scripts/validate.sh's role-floor registry gate actually fires. Plants throwaway
# violations across four runs, asserts by EXACT STRING PRESENCE, restores, and
# verifies the paths it touched are byte-identical to where it started.
#
# Assert by presence only, never by FAIL count or absence-of-FAIL: validate.sh
# runs context-budget.sh with `|| true`, and a planted agent pushes its host
# plugin over baseline, so an unrelated budget FAIL is always in the capture.
#
# Runs A-D are separate because the violations are mutually exclusive: one agent
# cannot be both unclassified (string 6) and carry `floor: none` (string 7), and
# an emptied registry (string 5) precludes any row check.
set -u
cd "$(dirname "$0")/../../.." || exit 2   # repo root

RF=plugins/orchestration/skills/delegation-contracts/references/role-floors.md
CR=plugins/code-review/agents/code-reviewer.md
HOST=plugins/debugging/agents
SX="$HOST/_rf_scratch_x.md"
SY="$HOST/_rf_scratch_y.md"
SZ="$HOST/_rf_scratch_z.md"
BAK=$(mktemp -d) || exit 2

cp "$RF" "$BAK/rf" || exit 2
cp "$CR" "$BAK/cr" || exit 2

cleanup() {
  rm -f "$SX" "$SY" "$SZ"
  [ -f "$BAK/rf" ] && cp "$BAK/rf" "$RF"
  [ -f "$CR" ] && [ -f "$BAK/cr" ] && cp "$BAK/cr" "$CR"
  # integrity: only the paths this fixture touches, never the whole tree — a
  # developer running mid-edit must not go red for unrelated work.
  bad=0
  cmp -s "$BAK/rf" "$RF" || { echo "FAIL: $RF not restored"; bad=1; }
  cmp -s "$BAK/cr" "$CR" || { echo "FAIL: $CR not restored"; bad=1; }
  for f in "$SX" "$SY" "$SZ"; do
    [ -e "$f" ] && { echo "FAIL: scratch $f survived"; bad=1; }
  done
  rm -rf "$BAK"
  [ "$bad" -eq 0 ] || exit 1
}
trap cleanup EXIT INT TERM HUP

rc=0
want() {   # want <label> <exact string>
  printf '%s\n' "$out" | grep -qF "$2" \
    && echo "PASS: $1" || { echo "FAIL: $1 did not fire"; rc=1; }
}

# Planted agents must satisfy every other agent check or we grep the wrong
# failure: opener, terminated frontmatter, name/description/model/effort, a
# PROACTIVELY|Spawned by marker, no block scalar, <=500 chars, no "Trigger
# words:", and no /word:word token (validate.sh recurses plugins/*/agents).
mkagent() {  # mkagent <path> <name> <model> [extra frontmatter lines]
  { printf -- '---\n'
    printf 'name: %s\n' "$2"
    printf 'description: Spawned by the role-floor gate harness to prove a FAIL path fires.\n'
    printf 'model: %s\n' "$3"
    printf 'effort: low\n'
    shift 3
    for line in "$@"; do printf '%s\n' "$line"; done
    printf -- '---\n\nscratch\n'
  } > "$1"
}

# ---- Run A: strings 6, 7, 8 (frontmatter side) -------------------------------
mkagent "$SX" _rf_scratch_x sonnet
mkagent "$SY" _rf_scratch_y sonnet 'floor: none' 'floor-reason:'
mkagent "$SZ" _rf_scratch_z auto
out=$(bash scripts/validate.sh 2>&1)
want "6 unclassified pin"  "$SX: pins model 'sonnet' but has neither a role-floors row nor 'floor: none'"
want "7 empty reason"      "$SY: 'floor: none' requires a non-empty floor-reason:"
want "8 bad model value"   "$SZ: frontmatter model 'auto' is not inherit or one of haiku|sonnet|opus|fable"
rm -f "$SX" "$SY" "$SZ"

# ---- Run B: strings 1, 2, 3, 4 (registry side) -------------------------------
{ printf 'code-review:code-reviewer                 sonnet\n'
  printf 'nosuch:agent                              opus\n'
  printf 'code-architecture:architecture-reviewer   banana\n'
  printf 'code-architecture:architecture-reviewer   opus\n'
} > "$BAK/rows"
awk -v rows="$BAK/rows" '
  /^```/ { n++; print; if (n==1) { while ((getline l < rows) > 0) print l; skip=1 } else skip=0; next }
  skip { next } { print }' "$BAK/rf" > "$RF"
out=$(bash scripts/validate.sh 2>&1)
want "1 tier mismatch"     "role-floors registry: code-review:code-reviewer tier 'sonnet' != $CR frontmatter model 'opus'"
want "2 unresolvable key"  "role-floors registry: nosuch:agent resolves to no agent file (plugins/nosuch/agents/agent.md)"
want "3 duplicate key"     "role-floors registry: code-architecture:architecture-reviewer appears more than once"
want "4 tier off ladder"   "role-floors registry: code-architecture:architecture-reviewer tier 'banana' is not one of haiku|sonnet|opus|fable"
cp "$BAK/rf" "$RF"

# ---- Run C: string 9 (row AND floor: none) -----------------------------------
awk '/^effort:/ && !d { print; print "floor: none"; print "floor-reason: harness"; d=1; next } { print }' \
  "$BAK/cr" > "$CR"
out=$(bash scripts/validate.sh 2>&1)
want "9 row + floor:none"  "$CR: has a role-floors row AND 'floor: none' - a row means floored"
cp "$BAK/cr" "$CR"

# ---- Run D: string 5 (registry unparseable) ----------------------------------
awk '/^```/ { n++; print; if (n==1) skip=1; else skip=0; next } skip { next } { print }' \
  "$BAK/rf" > "$RF"
out=$(bash scripts/validate.sh 2>&1)
want "5 empty registry"    "role-floors registry: $RF missing, empty, or has no parseable rows"
cp "$BAK/rf" "$RF"

exit $rc
