#!/usr/bin/env bash
# Smoke tests for the lane-declaration gates in scripts/lib/plugin-checks.sh —
# pc_lanes_schema, pc_lanes_authority, pc_lanes_resolve, pc_lanes_territory and
# pc_lanes_coverage — plus the validate.sh wiring that reports them.
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

# S2c — the 8 reviewer-class agents. They collide on ROLE, not on filename, so no
# other gate in this repo can see them. Each must carry a row, and none may be
# rescued by a blessing: a blanket "these all co-fire" would pass the territory
# gate while conceding the thing the gate exists to establish.
REVIEWERS="code-review:code-reviewer code-architecture:architecture-reviewer
devops:devops-reviewer terse:terse-reviewer web-dev:frontend-reviewer
ui-ux:ui-ux-reviewer craft-layer:craft-reviewer system-design:system-design-reviewer"
missing=""; blessed=""
for r in $REVIEWERS; do
  p=${r%%:*}
  grep -q "^$r	agent	" "plugins/$p/lane.tsv" 2>/dev/null || missing="$missing $r"
  grep -h '^#[[:space:]]*lane-cofire-ok:' plugins/*/lane.tsv 2>/dev/null \
    | grep -qw -- "$r" && blessed="$blessed $r"
done
[ -z "$missing" ] && pass "[tree] all 8 reviewer-class agents declare a lane row (S2c)" \
                  || bad "[tree] reviewer-class agents with no lane row:$missing"
[ -z "$blessed" ] && pass "[tree] no blessing rescues a reviewer-class agent — the territories are distinct or an explicit yields_to carries the pair (S2c)" \
                  || bad "[tree] a co-fire blessing covers reviewer-class agent(s):$blessed"

# Coverage over the real tree. Scoped to the plugins this change owns: debugging,
# fresh-take and skill-router are written by the card running beside it, so their
# gaps are reported, not asserted. TIGHTEN THIS to a bare "no lane-missing" once
# that card has landed.
PENDING='^lane-missing [a-z]* \(debugging\|fresh-take\|skill-router\):'
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
VT=plugins/testing/lane.tsv
VB=$(mktemp) || exit 2
cp "$VT" "$VB" || exit 2
printf 'testing:test-engineer\tagent\tverify\tno-yields-column\ta checkable condition\n' >> "$VT"
vout=$(bash scripts/validate.sh 2>&1)
cp "$VB" "$VT"
cmp -s "$VB" "$VT" && pass "[wiring] $VT restored byte-identically" || bad "[wiring] $VT not restored"
rm -f "$VB"
if printf '%s\n' "$vout" | grep -qF "FAIL: lane-schema $VT:"; then
  pass "[wiring] validate.sh reports a planted lane-schema violation with its own message"
else
  bad "[wiring] validate.sh did not report the planted lane-schema violation"
fi

[ "$rc" -eq 0 ] && echo "All lane-declaration smoke tests passed."
exit "$rc"
