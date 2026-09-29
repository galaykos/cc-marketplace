#!/usr/bin/env bash
# Role-floor gate harness: proves each of the nine frozen FAIL strings that
# pc_role_floors (scripts/lib/plugin-checks.sh) emits actually fires. Plants throwaway
# violations across four runs in a mirror and asserts by EXACT STRING PRESENCE on the
# function's output — validate.sh err()s each `fail` line verbatim, and the end-to-end
# run through validate.sh lives in parity-check.sh. The wiring check at the end greps
# the live validate.sh for the call and the exemptions header; it does not run either.
#
# Assert by presence only, never by FAIL count: a plant trips lines it did not aim at
# (Run B's four-row registry leaves every other floored agent unclassified), so a
# count would couple this harness to the live agent inventory.
#
# Runs A-D are separate because the violations are mutually exclusive: one agent
# cannot be both unclassified (string 6) and carry `floor: none` (string 7), and
# an emptied registry (string 5) precludes any row check.
set -u
LIVE="$(cd "$(dirname "$0")/../../.." && pwd)" || exit 2

# RUN AGAINST A MIRROR, NEVER THE LIVE TREE.
# This fixture rewrites role-floors.md and code-reviewer.md and writes three fake
# agent files into a REAL shipped plugin directory, relying on a trap to undo it.
# A trap does not survive SIGKILL, a harness timeout, or two runs overlapping, and
# all three happened while the lane gates were being built — leaving _rf_scratch_*.md
# inside plugins/debugging/agents/. That is worse now than it used to be: since
# pc_lanes_coverage gates agents, a leaked scratch agent demands a lane row that will
# never exist, so an interrupted test run turns into a build failure in a file nobody
# edited. Copying first makes the blast radius a temp directory.
MIRROR="$(mktemp -d)" || exit 2
for _d in plugins scripts; do
  [ -e "$LIVE/$_d" ] && cp -R "$LIVE/$_d" "$MIRROR/" 2>/dev/null
done
cd "$MIRROR" || exit 2
. scripts/lib/plugin-checks.sh || exit 2

RF=plugins/task-runner/skills/delegation-contracts/references/role-floors.md
CR=plugins/code-review/agents/code-reviewer.md
HOST=plugins/debugging/agents
SX="$HOST/_rf_scratch_x.md"
SY="$HOST/_rf_scratch_y.md"
SZ="$HOST/_rf_scratch_z.md"
BAK=$(mktemp -d) || exit 2

cp "$RF" "$BAK/rf" || exit 2
cp "$CR" "$BAK/cr" || exit 2

cleanup() {
  # Everything this fixture wrote lives under $MIRROR, so removal is the whole of
  # the restore — nothing to put back, nothing that can be half-restored. The
  # integrity assertions below check the LIVE tree instead: they are what proves the
  # mirror indirection actually holds, and they would have caught the leaked scratch
  # agents that motivated it.
  bad=0
  for f in _rf_scratch_x _rf_scratch_y _rf_scratch_z; do
    [ -e "$LIVE/plugins/debugging/agents/$f.md" ] && {
      echo "FAIL: scratch $f.md leaked into the live tree"; bad=1; }
  done
  cd / 2>/dev/null || true
  rm -rf "$MIRROR" "$BAK"
  [ "$bad" -eq 0 ] || exit 1
}
trap cleanup EXIT INT TERM HUP

rc=0
want() {   # want <label> <exact string>
  printf '%s\n' "$out" | grep -qF "$2" \
    && echo "PASS: $1" || { echo "FAIL: $1 did not fire"; rc=1; }
}

# A plant carries a complete agent frontmatter so it differs from a shipped agent
# only in the model/floor keys under test.
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
out=$(pc_role_floors "$RF" plugins 2>&1)
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
out=$(pc_role_floors "$RF" plugins 2>&1)
want "1 tier mismatch"     "role-floors registry: code-review:code-reviewer tier 'sonnet' != $CR frontmatter model 'opus'"
want "2 unresolvable key"  "role-floors registry: nosuch:agent resolves to no agent file (plugins/nosuch/agents/agent.md)"
want "3 duplicate key"     "role-floors registry: code-architecture:architecture-reviewer appears more than once"
want "4 tier off ladder"   "role-floors registry: code-architecture:architecture-reviewer tier 'banana' is not one of haiku|sonnet|opus|fable"
cp "$BAK/rf" "$RF"

# ---- Run C: string 9 (row AND floor: none) -----------------------------------
awk '/^effort:/ && !d { print; print "floor: none"; print "floor-reason: harness"; d=1; next } { print }' \
  "$BAK/cr" > "$CR"
out=$(pc_role_floors "$RF" plugins 2>&1)
want "9 row + floor:none"  "$CR: has a role-floors row AND 'floor: none' - a row means floored"
cp "$BAK/cr" "$CR"

# ---- Run D: string 5 (registry unparseable) ----------------------------------
awk '/^```/ { n++; print; if (n==1) skip=1; else skip=0; next } skip { next } { print }' \
  "$BAK/rf" > "$RF"
out=$(pc_role_floors "$RF" plugins 2>&1)
want "5 empty registry"    "role-floors registry: $RF missing, empty, or has no parseable rows"
cp "$BAK/rf" "$RF"

if grep -qF 'pc_role_floors "$RF" plugins' "$LIVE/scripts/validate.sh" \
   && grep -qF '== role-floor exemptions ==' "$LIVE/scripts/validate.sh"; then
  echo "PASS: wiring — validate.sh calls pc_role_floors and prints the exemptions header"
else
  echo "FAIL: wiring — validate.sh lacks 'pc_role_floors \"\$RF\" plugins' or the '== role-floor exemptions ==' header"; rc=1
fi

exit $rc
