#!/usr/bin/env bash
# Smoke tests for the lane-declaration gates in scripts/lib/plugin-checks.sh —
# pc_lanes_schema, pc_lanes_authority, pc_lanes_resolve, pc_lanes_territory,
# pc_lanes_coverage, pc_lanes_vocabulary, pc_twin_files and pc_phase_guard — plus the
# validate.sh wiring that reports them.
#
# EVERY GATE IS DEMONSTRATED FAILING ON PURPOSE. A gate nobody has watched fail
# is indistinguishable from a gate that returns 0 unconditionally; the territory
# gate in particular has no shipped violation to point at, so these fixtures ARE
# its entire enforcement record.
#
# The two-file cases are the point of the design: collisions are cross-plugin
# (the 8 reviewer-class agents live in 8 plugins with 8 distinct filenames), and
# a blessing must work from EITHER participant's file or the per-plugin
# placement privileges whichever plugin happens to be read first.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
. "$ROOT/scripts/lib/plugin-checks.sh" || exit 2
rc=0
pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; rc=1; }

FIX=$(mktemp -d) || exit 2
trap 'rm -rf "$FIX"' EXIT INT TERM HUP
mkdir -p "$FIX/foo/agents" "$FIX/foo/commands" "$FIX/foo/hooks" "$FIX/foo/skills/sk" "$FIX/bar/agents"
: > "$FIX/foo/agents/alpha.md"
: > "$FIX/foo/commands/cmd.md"
: > "$FIX/foo/skills/sk/SKILL.md"
: > "$FIX/foo/hooks/remind.sh"
: > "$FIX/bar/agents/beta.md"
cat > "$FIX/foo/hooks/hooks.json" <<'EOF'
{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/remind.sh"}]}]}}
EOF

lane() { sed $'s/@@/\t/g' > "$FIX/$1/lane.tsv"; }   # rows on stdin, @@ = TAB
run()  { out=$("$@" 2>&1); grc=$?; }

# fails <label> <substring>   — the last run must have returned 1 AND said this
fails() {
  if [ "$grc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "$2"; then pass "$1"
  else bad "$1 (rc=$grc, output: $out)"; fi
}
# clean <label>               — the last run must have returned 0 with no output
clean() {
  if [ "$grc" -eq 0 ] && [ -z "$out" ]; then pass "$1"
  else bad "$1 (rc=$grc, output: $out)"; fi
}

# ---- pc_lanes_schema ---------------------------------------------------------
lane foo <<'EOF'
# a comment, and the blank line below, are ignored

foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@-
EOF
run pc_lanes_schema "$FIX/foo/lane.tsv"; clean "[schema] a well-formed file passes, comments and blanks ignored"

# (a) the five-field row the card names
lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition
EOF
run pc_lanes_schema "$FIX/foo/lane.tsv"; fails "[schema] a 5-field row fails" "lane-schema $FIX/foo/lane.tsv:1 5 fields (want 6)"

lane foo <<'EOF'
foo:alpha@@daemon@@review@@alpha-territory@@a checkable condition@@-
EOF
run pc_lanes_schema "$FIX/foo/lane.tsv"; fails "[schema] an unknown kind fails" "unknown kind daemon"

lane foo <<'EOF'
foo:alpha@@agent@@refactor@@alpha-territory@@a checkable condition@@-
EOF
run pc_lanes_schema "$FIX/foo/lane.tsv"; fails "[schema] an unknown phase fails" "unknown phase refactor"

lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@one condition@@-
foo:alpha@@agent@@build@@alpha-territory@@another condition@@-
EOF
run pc_lanes_schema "$FIX/foo/lane.tsv"; fails "[schema] a duplicate artifact+owns pair fails" "duplicate artifact+owns foo:alpha alpha-territory"

# ---- pc_lanes_authority (S1b) ------------------------------------------------
lane foo <<'EOF'
# lane-cofire-ok: foo:alpha bar:beta
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@bar:beta
EOF
run pc_lanes_authority "$FIX/foo/lane.tsv"; clean "[authority] own rows pass, and a blessing naming a sibling is a comment, not a claim"

# (e) foo declaring bar's artifact — the hole per-plugin files opened
lane foo <<'EOF'
bar:baz@@agent@@review@@beta-territory@@a checkable condition@@foo:alpha
EOF
run pc_lanes_authority "$FIX/foo/lane.tsv"; fails "[authority] a row naming bar:baz in foo's file fails (S1b)" "bar:baz not owned by foo"

lane foo <<'EOF'
alpha@@agent@@review@@alpha-territory@@a checkable condition@@-
EOF
run pc_lanes_authority "$FIX/foo/lane.tsv"; fails "[authority] an artifact with no plugin: prefix is owned by nobody" "alpha not owned by foo"

# ---- pc_lanes_resolve --------------------------------------------------------
lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@bar:beta
foo:remind@@hook@@any@@hook-territory@@a checkable condition@@-
foo:cmd@@command@@build@@cmd-territory@@a checkable condition@@-
foo:sk@@skill@@build@@skill-territory@@a checkable condition@@-
EOF
run pc_lanes_resolve "$FIX/foo/lane.tsv" "$FIX"; clean "[resolve] agent, hook, command and skill rows all resolve"

# (b) a row naming an artifact that is not in the tree
lane foo <<'EOF'
foo:ghost@@agent@@review@@ghost-territory@@a checkable condition@@-
EOF
run pc_lanes_resolve "$FIX/foo/lane.tsv" "$FIX"; fails "[resolve] a non-existent artifact fails" "foo:ghost names no agent in the tree"

lane foo <<'EOF'
foo:alpha@@command@@review@@alpha-territory@@a checkable condition@@-
EOF
run pc_lanes_resolve "$FIX/foo/lane.tsv" "$FIX"; fails "[resolve] resolution is kind-aware — an agent declared as a command fails" "foo:alpha names no command in the tree"

lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@bar:ghost
EOF
run pc_lanes_resolve "$FIX/foo/lane.tsv" "$FIX"; fails "[resolve] a yields_to naming nothing fails — deference to an artifact that cannot arrive" "yields_to bar:ghost resolves to nothing"

# ---- pc_lanes_territory (S2) -------------------------------------------------
# (c) two rows in TWO DIFFERENT files sharing owns+phase, no yield, no blessing
lane foo <<'EOF'
foo:alpha@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
lane bar <<'EOF'
bar:beta@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
run pc_lanes_territory "$FIX/foo/lane.tsv" "$FIX/bar/lane.tsv"
fails "[territory] a cross-file collision fails" "lane-territory shared-territory review foo:alpha bar:beta"

# the blessing works from the FIRST participant's file …
lane foo <<'EOF'
# lane-cofire-ok: foo:alpha bar:beta
foo:alpha@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
run pc_lanes_territory "$FIX/foo/lane.tsv" "$FIX/bar/lane.tsv"
clean "[territory] a blessing in the FIRST file resolves the collision (S2)"

# … and from the SECOND participant's file. Neither side is privileged: the gate
# collects every blessing from every file before it evaluates any pair.
lane foo <<'EOF'
foo:alpha@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
lane bar <<'EOF'
# lane-cofire-ok: bar:beta foo:alpha
bar:beta@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
run pc_lanes_territory "$FIX/foo/lane.tsv" "$FIX/bar/lane.tsv"
clean "[territory] a blessing in the SECOND file resolves it too, in either order (S2)"

lane bar <<'EOF'
# lane-cofire-ok: bar:beta
bar:beta@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
run pc_lanes_territory "$FIX/foo/lane.tsv" "$FIX/bar/lane.tsv"
fails "[territory] a blessing naming only one party does not resolve it" "lane-territory shared-territory review"

# a yields_to edge resolves it in either direction
lane foo <<'EOF'
foo:alpha@@agent@@review@@shared-territory@@a checkable condition@@bar:beta
EOF
lane bar <<'EOF'
bar:beta@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
run pc_lanes_territory "$FIX/foo/lane.tsv" "$FIX/bar/lane.tsv"
clean "[territory] a yields_to edge from the first row resolves it"

lane foo <<'EOF'
foo:alpha@@agent@@review@@shared-territory@@a checkable condition@@-
EOF
lane bar <<'EOF'
bar:beta@@agent@@review@@shared-territory@@a checkable condition@@ foo:alpha , other:thing
EOF
run pc_lanes_territory "$FIX/foo/lane.tsv" "$FIX/bar/lane.tsv"
clean "[territory] the reverse edge resolves it too, inside a spaced comma-list"

lane bar <<'EOF'
bar:beta@@agent@@build@@shared-territory@@a checkable condition@@-
EOF
run pc_lanes_territory "$FIX/foo/lane.tsv" "$FIX/bar/lane.tsv"
clean "[territory] one territory in two different phases is not a collision"

# ---- pc_lanes_coverage (S1) --------------------------------------------------
rm -f "$FIX/bar/lane.tsv"
mkdir -p "$FIX/bar"
lane bar <<'EOF'
bar:beta@@agent@@review@@beta-territory@@a checkable condition@@-
EOF
lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@-
foo:remind@@hook@@any@@hook-territory@@a checkable condition@@-
foo:cmd@@command@@build@@cmd-territory@@a checkable condition@@-
foo:sk@@skill@@build@@skill-territory@@a checkable condition@@-
EOF
run pc_lanes_coverage "$FIX"; clean "[coverage] a fully declared tree passes with no warnings"

# (d) deleting an AGENT row fails the build …
lane foo <<'EOF'
foo:remind@@hook@@any@@hook-territory@@a checkable condition@@-
foo:cmd@@command@@build@@cmd-territory@@a checkable condition@@-
foo:sk@@skill@@build@@skill-territory@@a checkable condition@@-
EOF
run pc_lanes_coverage "$FIX"; fails "[coverage] a missing AGENT row fails (S1)" "lane-missing agent foo:alpha"

lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@-
foo:cmd@@command@@build@@cmd-territory@@a checkable condition@@-
foo:sk@@skill@@build@@skill-territory@@a checkable condition@@-
EOF
run pc_lanes_coverage "$FIX"; fails "[coverage] a missing UserPromptSubmit HOOK row fails (S1)" "lane-missing hook foo:remind"

# … while deleting a COMMAND row only warns (A3: commands and skills are WARN)
lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@-
foo:remind@@hook@@any@@hook-territory@@a checkable condition@@-
foo:sk@@skill@@build@@skill-territory@@a checkable condition@@-
EOF
run pc_lanes_coverage "$FIX"
if [ "$grc" -eq 0 ] && printf '%s\n' "$out" | grep -qF 'lane-warn command foo:cmd' \
   && ! printf '%s\n' "$out" | grep -q '^lane-missing '; then
  pass "[coverage] a missing COMMAND row only WARNs (S1)"
else
  bad "[coverage] a missing command row should warn, not fail (rc=$grc, output: $out)"
fi

lane foo <<'EOF'
foo:alpha@@agent@@review@@alpha-territory@@a checkable condition@@-
foo:remind@@hook@@any@@hook-territory@@a checkable condition@@-
foo:cmd@@command@@build@@cmd-territory@@a checkable condition@@-
EOF
run pc_lanes_coverage "$FIX"
if [ "$grc" -eq 0 ] && printf '%s\n' "$out" | grep -qF 'lane-warn skill foo:sk'; then
  pass "[coverage] a missing SKILL row only WARNs (S1)"
else
  bad "[coverage] a missing skill row should warn, not fail (rc=$grc, output: $out)"
fi

# ---- pc_lanes_coverage: the deny-capable tool-channel arm ----------------------
# Added to the GATE tier 2026-09-15 and landed with no fixture, which is the shape the
# vocabulary/twin block below refuses in the same breath. Its own mktemp dir, so the
# shared $FIX tree and every later pc_lanes_* assertion are untouched.
#
# The first and last cases carry as much weight as the middle two: the first pins the
# NEGATIVE, so the widened arm cannot quietly become "every tool hook needs a row", and
# the last pins the `exit 2` alternation the check's header argues for.
DC=$(mktemp -d) || exit 2
mkdir -p "$DC/foo/hooks"
cat > "$DC/foo/hooks/hooks.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/scan.sh"}]}]}}
EOF
: > "$DC/foo/lane.tsv"

printf '#!/bin/sh\necho advisory\n' > "$DC/foo/hooks/scan.sh"
run pc_lanes_coverage "$DC"
clean "[coverage] a Pre/PostToolUse hook that returns no verdict needs no row"

printf '#!/bin/sh\nprintf %%s "{\\"hookSpecificOutput\\":{\\"permissionDecision\\":\\"deny\\"}}"\n' > "$DC/foo/hooks/scan.sh"
run pc_lanes_coverage "$DC"
fails "[coverage] a deny-capable PreToolUse hook with no row fails (S1)" "lane-missing hook foo:scan (returns a permissionDecision)"

printf 'foo:scan\thook\tany\tscan-territory\ta checkable condition\t-\n' > "$DC/foo/lane.tsv"
run pc_lanes_coverage "$DC"
clean "[coverage] declaring the row clears it"

: > "$DC/foo/lane.tsv"
printf '#!/bin/sh\nif bad; then\n  exit 2\nfi\n' > "$DC/foo/hooks/scan.sh"
run pc_lanes_coverage "$DC"
fails "[coverage] an exit-2 denier counts as a verdict channel too" "lane-missing hook foo:scan"
rm -rf "$DC"

# ---- the real tree -----------------------------------------------------------
LANES=$(find plugins -maxdepth 2 -name lane.tsv | sort)
lrc=0
while IFS= read -r lf; do
  [ -n "$lf" ] || continue
  pc_lanes_schema    "$lf" >/dev/null || { echo "  schema: $lf"; lrc=1; }
  pc_lanes_authority "$lf" >/dev/null || { echo "  authority: $lf"; lrc=1; }
  pc_lanes_resolve   "$lf" >/dev/null || { echo "  resolve: $lf"; lrc=1; }
done <<EOF
$LANES
EOF
[ "$lrc" -eq 0 ] && pass "[tree] every shipped lane.tsv is well-formed, self-owned and resolvable" \
                 || bad "[tree] a shipped lane.tsv is malformed"

run pc_lanes_territory $LANES
clean "[tree] no two shipped artifacts claim one territory in one phase"

# S2c — the 6 reviewer-class agents. They collide on ROLE, not on filename, so no
# other gate in this repo can see them. Each must carry a row, and none may be
# rescued by a blessing: a blanket "these all co-fire" would pass the territory
# gate while conceding the thing the gate exists to establish. (system-design's
# reviewer folded into architecture-reviewer 2026-09-14; terse-reviewer dropped with
# the terse merge into candor the same day.)
REVIEWERS="code-review:code-reviewer code-architecture:architecture-reviewer
devops:devops-reviewer web-dev:frontend-reviewer
ui-ux:ui-ux-reviewer craft-layer:craft-reviewer"
missing=""; blessed=""
for r in $REVIEWERS; do
  p=${r%%:*}
  grep -q "^$r	agent	" "plugins/$p/lane.tsv" 2>/dev/null || missing="$missing $r"
  grep -h '^#[[:space:]]*lane-cofire-ok:' plugins/*/lane.tsv 2>/dev/null \
    | grep -qw -- "$r" && blessed="$blessed $r"
done
[ -z "$missing" ] && pass "[tree] all 6 reviewer-class agents declare a lane row (S2c)" \
                  || bad "[tree] reviewer-class agents with no lane row:$missing"
[ -z "$blessed" ] && pass "[tree] no blessing rescues a reviewer-class agent — the territories are distinct or an explicit yields_to carries the pair (S2c)" \
                  || bad "[tree] a co-fire blessing covers reviewer-class agent(s):$blessed"

# Coverage over the real tree. Scoped to the plugins this change owns: debugging
# and skill-router are written by the card running beside it, so their gaps are
# reported, not asserted. TIGHTEN THIS to a bare "no lane-missing" once that card
# has landed. (fresh-take was in this list until it merged into approaches, 2026-09-14.)
PENDING='^lane-missing [a-z]* \(debugging\|skill-router\):'
cov=$(pc_lanes_coverage plugins) || true
gaps=$(printf '%s\n' "$cov" | grep '^lane-missing ' | grep -v "$PENDING" || true)
[ -z "$gaps" ] && pass "[tree] every agent and prompt/Stop hook outside the sibling card's plugins has a row" \
               || bad "[tree] uncovered gate-tier artifacts: $(printf '%s' "$gaps" | tr '\n' ' ')"
printf '%s\n' "$cov" | grep "$PENDING" | sed 's/^/  pending (sibling card): /'

# ---- validate.sh wiring ------------------------------------------------------
# The functions above can all be correct while the call site interpolates an
# empty message or never runs. Plant one real violation, assert the exact FAIL
# line, restore byte-identically. PRESENCE ONLY, never exit code: validate.sh
# has other reasons to be red mid-change and this must not read them as a pass.
# PLANT INTO A COPY, NEVER THE LIVE TREE. An earlier version appended the bad row
# to the real plugins/testing/lane.tsv and restored it afterwards. That holds only
# while nothing interrupts: a killed run or two overlapping runs leave the malformed
# row on disk, and the next validate.sh then fails on a file nobody edited. It
# happened during this gate's own development. validate.sh cds to its own repo root
# (validate.sh:4), so running the COPY's copy of it scopes everything to the mirror.
# .claude-plugin is required — without it validate.sh exits early on
# "marketplace.json missing" and the assertion below would never fire.
VT=plugins/testing/lane.tsv
VLIVE=$(mktemp) || exit 2
cp "$VT" "$VLIVE" || exit 2

VMIR="$(mktemp -d)" || exit 2
for _d in plugins scripts templates .claude-plugin; do cp -R "$_d" "$VMIR/" 2>/dev/null; done
for _f in CLAUDE.md README.md skills-lock.json; do [ -f "$_f" ] && cp "$_f" "$VMIR/" 2>/dev/null; done

printf 'testing:test-engineer\tagent\tverify\tno-yields-column\ta checkable condition\n' >> "$VMIR/$VT"
vout=$( cd "$VMIR" && bash scripts/validate.sh 2>&1 )
rm -rf "$VMIR"

if printf '%s\n' "$vout" | grep -qF "FAIL: lane-schema $VT:"; then
  pass "[wiring] validate.sh reports a planted lane-schema violation with its own message"
else
  bad "[wiring] validate.sh did not report the planted lane-schema violation"
fi
cmp -s "$VLIVE" "$VT" && pass "[wiring] the live $VT was never written to" \
                      || bad "[wiring] the harness mutated the real tree"
rm -f "$VLIVE"

# ---------------------------------------------------------------- pc_lanes_vocabulary
# Both gates below were added 2026-09-15 and shipped with NO harness, in a repo whose CI
# asserts exact gate strings — gate-coverage.sh reported them as NONE. These are that
# coverage. The vocabulary check's most important property is the one a fail-open would
# destroy silently: a MISSING vocabulary file must fail, not pass.
VOC="$FIX/vocab.txt"
printf '# --- review ---\napproved-noun\n' > "$VOC"

lane foo <<'EOF'
foo:alpha@@agent@@review@@approved-noun@@a checkable condition@@-
EOF
rm -f "$FIX/bar/lane.tsv"
run pc_lanes_vocabulary "$FIX" "$VOC"
clean "[vocab] a declared owns noun passes"

lane foo <<'EOF'
foo:alpha@@agent@@review@@yet-another-diff-review@@a checkable condition@@-
EOF
run pc_lanes_vocabulary "$FIX" "$VOC"
fails "[vocab] an undeclared owns noun fails" "lane-vocab $FIX/foo/lane.tsv yet-another-diff-review"

run pc_lanes_vocabulary "$FIX" "$FIX/does-not-exist.txt"
fails "[vocab] a MISSING vocabulary file fails rather than passing silently" "lane-vocab MISSING"

# A row with spaces instead of tabs belongs to pc_lanes_schema, not to this check.
printf 'a b c d e f\n' > "$FIX/foo/lane.tsv"
run pc_lanes_vocabulary "$FIX" "$VOC"
clean "[vocab] a malformed space-separated row is left to the schema gate"

# An unterminated final line. Every sibling lane check parses with awk and still sees this
# row; a bare `read` loop drops it, so the LAST row of such a file was schema-checked and
# territory-checked yet exempt from the vocabulary gate. Verified 2026-09-15 against the
# pre-fix function: exit 0, no output.
printf 'foo:alpha\tagent\treview\tundeclared-tail-noun\ta checkable condition\t-' > "$FIX/foo/lane.tsv"
run pc_lanes_vocabulary "$FIX" "$VOC"
fails "[vocab] the last row of a file with no trailing newline is still checked" "undeclared-tail-noun"

# A CRLF file must not report the carriage return as part of the noun.
printf 'foo:alpha\tagent\treview\tapproved-noun\ta checkable condition\t-\r\n' > "$FIX/foo/lane.tsv"
run pc_lanes_vocabulary "$FIX" "$VOC"
clean "[vocab] a CRLF row resolves to the same noun as an LF row"

# ------------------------------------------------------------------- pc_phase_guard
# This gate had NO harness at all before 2026-09-15 — gate-coverage.sh reported NONE —
# and on that day its SCOPE was widened from {UserPromptSubmit, Stop} to also cover
# Pre/PostToolUse, following pc_lanes_coverage into the same tier. A widened gate with no
# fixture is exactly the shape this file exists to refuse.
PG=$(mktemp -d) || exit 2
mkdir -p "$PG/foo/hooks"
: > "$PG/foo/hooks/guard.sh"
cat > "$PG/foo/hooks/hooks.json" <<'EOF'
{"hooks":{"PreToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh"}]}]}}
EOF

printf 'foo:guard\thook\tbuild\tsome-noun\ta checkable condition\t-\n' > "$PG/foo/lane.tsv"
run pc_phase_guard "$PG"
fails "[phase] a PreToolUse hook naming a phase without reading the sentinel fails" "phase-unguarded foo:guard.sh"

printf 'foo:guard\thook\tany\tsome-noun\ta checkable condition\t-\n' > "$PG/foo/lane.tsv"
run pc_phase_guard "$PG"
clean "[phase] the same hook declared \`any\` is exempt — a guard fires in every phase"

printf 'foo:guard\thook\tbuild\tsome-noun\ta checkable condition\t-\n' > "$PG/foo/lane.tsv"
printf '#!/bin/sh\n# reads .claude/cc-phase.json\n' > "$PG/foo/hooks/guard.sh"
run pc_phase_guard "$PG"
clean "[phase] a hook that reads the sentinel may name a specific phase"

cat > "$PG/foo/hooks/hooks.json" <<'EOF'
{"hooks":{"PostToolUse":[{"matcher":"Edit","hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/guard.sh"}]}]}}
EOF
: > "$PG/foo/hooks/guard.sh"
run pc_phase_guard "$PG"
fails "[phase] PostToolUse is in scope too, not only PreToolUse" "phase-unguarded foo:guard.sh"
rm -rf "$PG"

# --------------------------------------------------------------------- pc_twin_files
TW=$(mktemp -d) || exit 2
mkdir -p "$TW/a/hooks" "$TW/b/hooks"
printf '#!/bin/sh\n# TWIN: %s/b/hooks/g.sh is an identical copy save this line.\necho hi\n' "$TW" > "$TW/a/hooks/g.sh"
printf '#!/bin/sh\n# TWIN: %s/a/hooks/g.sh is an identical copy save this line.\necho hi\n' "$TW" > "$TW/b/hooks/g.sh"
run pc_twin_files "$TW"
clean "[twin] a matching declared pair passes"

printf 'echo drift\n' >> "$TW/b/hooks/g.sh"
run pc_twin_files "$TW"
fails "[twin] a drifted pair fails" "twin $TW/a/hooks/g.sh"

printf '#!/bin/sh\n# TWIN: %s/nope.sh is an identical copy save this line.\n' "$TW" > "$TW/a/hooks/g.sh"
rm -f "$TW/b/hooks/g.sh"
run pc_twin_files "$TW"
fails "[twin] a partner that does not exist fails" "(missing)"

# A REWORDED marker must be loud. The extraction wants one exact sentence, so editing the
# comment on both copies previously retired the gate in silence while both files still read
# to a human as a declared pair.
printf '#!/bin/sh\n# TWIN: %s/b/hooks/g.sh - identical copy apart from this line\necho hi\n' "$TW" > "$TW/a/hooks/g.sh"
run pc_twin_files "$TW"
fails "[twin] a reworded marker fails rather than skipping the file" "unparseable marker"

printf '#!/bin/sh\n# TWIN: %s/a/hooks/g.sh is an identical copy save this line.\necho hi\n' "$TW/a/hooks/g.sh" > /dev/null
printf '#!/bin/sh\n# TWIN: %s is an identical copy save this line.\necho hi\n' "$TW/a/hooks/g.sh" > "$TW/a/hooks/g.sh"
run pc_twin_files "$TW"
fails "[twin] a file declaring itself its own twin fails" "declares itself"
rm -rf "$TW"

# ---------------------------------------------------------------- pc_lanes_adjacency
# CROWDING, the defect pc_lanes_territory structurally cannot see: it compares `owns`
# as a string and the shipped vocabulary is 1:1 with the claimed nouns, so it has never
# had a live pair. The probe (rationale/2026-09-15-listing-eviction-probe.md:60-66)
# measured what crowding costs — eight rivals on one territory dropped firing from 100%
# to ~75% — so the fixtures below are the whole enforcement record for the check that
# prices it. Triggers are DERIVED (rules.tsv globs for a skill, `bestpractices-skill`
# for an agent), which is the half most worth watching fail.
AD=$(mktemp -d) || exit 2
ADR="$ROOT/scripts/smoke/validate-fixtures/lanes-adjacency-rules.tsv"
mkdir -p "$AD/foo/agents" "$AD/bar/agents"
adlane()  { sed $'s/@@/\t/g' > "$AD/$1/lane.tsv"; }   # rows on stdin, @@ = TAB
adagent() {                                           # <plugin> <name> <skills|->
  { printf -- '---\nname: %s\n' "$2"
    [ "$3" = '-' ] || printf 'bestpractices-skill: %s\n' "$3"
    printf -- '---\n\nBody prose.\n'
  } > "$AD/$1/agents/$2.md"
}
: > "$AD/bar/lane.tsv"

adlane foo <<'EOF'
foo:alpha-skill@@skill@@build@@alpha-noun@@a checkable condition@@-
foo:beta-skill@@skill@@build@@beta-noun@@a checkable condition@@-
EOF
adlane bar <<'EOF'
bar:gamma-skill@@skill@@build@@gamma-noun@@a checkable condition@@-
EOF
run pc_lanes_adjacency "$AD" "$ADR"
fails "[adjacency] three skills on one glob in one phase are a cluster" \
  "lane-adjacency *.qq build bar:gamma-skill foo:alpha-skill foo:beta-skill"

# the same three, but one phase apart: the model never sees them at once
adlane bar <<'EOF'
bar:gamma-skill@@skill@@review@@gamma-noun@@a checkable condition@@-
EOF
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] one shape in two phases is not a cluster"

# two is a pair, and pairs are pc_rules_overlap's job, not this one
: > "$AD/bar/lane.tsv"
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] two artifacts are below the default threshold"
run pc_lanes_adjacency "$AD" "$ADR" 2
fails "[adjacency] the threshold is a parameter" "lane-adjacency *.qq build foo:alpha-skill foo:beta-skill"

# a SINGLE yields_to edge does not clear a crowd — it settles one pair of three
adlane foo <<'EOF'
foo:alpha-skill@@skill@@build@@alpha-noun@@a checkable condition@@foo:beta-skill
foo:beta-skill@@skill@@build@@beta-noun@@a checkable condition@@-
EOF
adlane bar <<'EOF'
bar:gamma-skill@@skill@@build@@gamma-noun@@a checkable condition@@-
EOF
run pc_lanes_adjacency "$AD" "$ADR"
fails "[adjacency] one yields_to edge leaves the other two pairs contested" "lane-adjacency *.qq build"

adlane foo <<'EOF'
foo:alpha-skill@@skill@@build@@alpha-noun@@a checkable condition@@foo:beta-skill,bar:gamma-skill
foo:beta-skill@@skill@@build@@beta-noun@@a checkable condition@@bar:gamma-skill
EOF
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] every pair settled by yields_to clears the cluster"

# blessings resolve pairs too, and are collected from EVERY file before anything is judged
adlane foo <<'EOF'
# lane-cofire-ok: foo:alpha-skill foo:beta-skill
# lane-cofire-ok: foo:alpha-skill bar:gamma-skill
foo:alpha-skill@@skill@@build@@alpha-noun@@a checkable condition@@-
foo:beta-skill@@skill@@build@@beta-noun@@a checkable condition@@-
EOF
adlane bar <<'EOF'
# lane-cofire-ok: bar:gamma-skill foo:beta-skill
bar:gamma-skill@@skill@@build@@gamma-noun@@a checkable condition@@-
EOF
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] pairs blessed across both files clear the cluster"

# an AGENT has no glob of its own: its shape is the shape of the skills it declares
adlane foo <<'EOF'
foo:alpha-skill@@skill@@build@@alpha-noun@@a checkable condition@@-
foo:beta-skill@@skill@@build@@beta-noun@@a checkable condition@@-
EOF
adlane bar <<'EOF'
bar:worker@@agent@@build@@worker-noun@@a checkable condition@@-
EOF
adagent bar worker delta-skill
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] an agent declaring a skill on another glob joins no cluster"

adagent bar worker alpha-skill
run pc_lanes_adjacency "$AD" "$ADR"
fails "[adjacency] an agent is pulled in by its bestpractices-skill globs" \
  "lane-adjacency *.qq build bar:worker foo:alpha-skill foo:beta-skill"

# … but it does NOT contest the skills it READS: those shapes came from them
adagent bar worker 'alpha-skill, beta-skill'
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] an agent does not contest a skill it declares"

# the key is frontmatter-only; the same line in the body is prose
{ printf -- '---\nname: worker\n---\n\nbestpractices-skill: alpha-skill\n'; } > "$AD/bar/agents/worker.md"
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] bestpractices-skill in the BODY derives nothing"

# a command declares no file shape anywhere in this tree, so it can never complete one
adagent bar worker -
adlane bar <<'EOF'
bar:gamma-skill@@command@@build@@gamma-noun@@a checkable condition@@-
EOF
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] a command row derives no shape (stated limitation)"

# content rows fire on a file's BODY — pc_rules_cofire owns those, with a corpus
adlane bar <<'EOF'
bar:eps-skill@@skill@@build@@eps-noun@@a checkable condition@@-
EOF
run pc_lanes_adjacency "$AD" "$ADR"; clean "[adjacency] a content-routed skill is not a file shape"

# a missing rules.tsv must not fail the build of a tree that ships no router
run pc_lanes_adjacency "$AD" "$AD/no-such-rules.tsv"; clean "[adjacency] an absent rules file is a no-op"
rm -rf "$AD"

[ "$rc" -eq 0 ] && echo "All lane-declaration smoke tests passed."
exit "$rc"
