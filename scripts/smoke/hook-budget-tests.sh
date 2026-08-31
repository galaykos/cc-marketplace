#!/usr/bin/env bash
# Smoke tests for the two checks added 2026-08-27 to scripts/lib/plugin-checks.sh:
# pc_hook_timeout (every hooks.json entry declares a timeout) and
# pc_budget_crowding (the ratchet on SKILL bodies written to the 200-line cap).
#
# BOTH ARE DEMONSTRATED FAILING ON PURPOSE, for the reason lanes-tests.sh states:
# a gate nobody has watched fail is indistinguishable from one that returns 0
# unconditionally. Neither has a shipped violation to point at — the whole fleet
# was brought clean in the same commit that added them — so these fixtures ARE
# their entire enforcement record.
#
# The crowding ratchet gets a directional pair specifically: a check that only
# ever fires upward must be shown NOT firing when the number falls, or "ratchet"
# is a claim rather than a behaviour.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 2
. "$ROOT/scripts/lib/plugin-checks.sh" || exit 2
rc=0
pass() { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; rc=1; }

FIX=$(mktemp -d) || exit 2
trap 'rm -rf "$FIX"' EXIT INT TERM HUP

run()   { out=$("$@" 2>&1); grc=$?; }
fails() { if [ "$grc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "$2"; then pass "$1"
          else bad "$1 (rc=$grc, output: $out)"; fi }
clean() { if [ "$grc" -eq 0 ] && [ -z "$out" ]; then pass "$1"
          else bad "$1 (rc=$grc, output: $out)"; fi }

# ---------------------------------------------------------------- pc_hook_timeout
mkdir -p "$FIX/ht/foo/hooks" "$FIX/ht/bar/hooks" "$FIX/ht/nohooks"

cat > "$FIX/ht/foo/hooks/hooks.json" <<'EOF'
{"hooks":{"UserPromptSubmit":[{"hooks":[
  {"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/remind.sh","timeout":10}]}]}}
EOF
run pc_hook_timeout "$FIX/ht"
clean "timeout declared — passes"

cat > "$FIX/ht/bar/hooks/hooks.json" <<'EOF'
{"hooks":{"PostToolUse":[{"matcher":"Edit","hooks":[
  {"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/scan.sh"}]}]}}
EOF
run pc_hook_timeout "$FIX/ht"
fails "timeout missing — fails" "hook-timeout bar:PostToolUse:scan.sh"

# A plugin with several entries must report EVERY undeclared one, not just the
# first: a per-plugin early exit would hide the second hook in the same file.
cat > "$FIX/ht/bar/hooks/hooks.json" <<'EOF'
{"hooks":{"PostToolUse":[{"matcher":"Edit","hooks":[
  {"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/a.sh"},
  {"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/b.sh","timeout":5}]}],
 "Stop":[{"hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/c.sh"}]}]}}
EOF
run pc_hook_timeout "$FIX/ht"
if [ "$grc" -ne 0 ] \
   && printf '%s\n' "$out" | grep -qF 'hook-timeout bar:PostToolUse:a.sh' \
   && printf '%s\n' "$out" | grep -qF 'hook-timeout bar:Stop:c.sh' \
   && ! printf '%s\n' "$out" | grep -qF 'b.sh'; then
  pass "reports every undeclared entry, and only those"
else bad "multi-entry reporting (rc=$grc, output: $out)"; fi

rm -f "$FIX/ht/bar/hooks/hooks.json"
run pc_hook_timeout "$FIX/ht"
clean "plugin with no hooks.json is not a violation"

# ------------------------------------------------------------ pc_budget_crowding
# A body of N lines: the function counts lines AFTER the second '---'.
mkskill() { # mkskill <dir> <body_lines>
  mkdir -p "$FIX/bc/p/skills/$1"
  { printf -- '---\nname: %s\n---\n' "$1"; seq "$2" | sed 's/^/line /'; } \
    > "$FIX/bc/p/skills/$1/SKILL.md"
}
base() { printf '{"within_3_of_line_cap": %s}\n' "$1" > "$FIX/base.json"; }

mkskill short 40
mkskill crowded 199
base 1
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
clean "count equal to baseline — passes"

mkskill crowded2 200
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
fails "count above baseline — fails" "crowding 2 > 1"
printf '%s\n' "$out" | grep -qF 'crowded2/SKILL.md (200)' \
  && pass "names the crowded files" || bad "crowded file not named: $out"

# Directional half: the ratchet must stay silent when the number FALLS.
base 5
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
clean "count below baseline — passes (ratchet, not equality)"

# 147 is under the 3-line window and must not count.
rm -rf "$FIX/bc/p/skills/crowded" "$FIX/bc/p/skills/crowded2"
mkskill edge 197
base 0
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
clean "197-line body is outside the window"

mkskill edge2 198
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
fails "198-line body is inside the window" "crowding 1 > 0"

run pc_budget_crowding "$FIX/bc" "$FIX/does-not-exist.json"
clean "missing baseline file is not a violation"

# ------------------------------------------------------------------ pc_pick_parity
mkdir -p "$FIX/pp/plugin-scout/scripts" "$FIX/pp/vercel-skills-scout/scripts"
printf 'same\n' > "$FIX/pp/plugin-scout/scripts/pick.sh"
printf 'same\n' > "$FIX/pp/vercel-skills-scout/scripts/pick.sh"
run pc_pick_parity "$FIX/pp"
clean "identical pickers — passes"

printf 'same\n# drift\n' > "$FIX/pp/vercel-skills-scout/scripts/pick.sh"
run pc_pick_parity "$FIX/pp"
fails "diverged pickers — fails" "pick-parity"

rm -f "$FIX/pp/vercel-skills-scout/scripts/pick.sh"
run pc_pick_parity "$FIX/pp"
clean "one picker absent is not a violation"

# --------------------------------------------------- pc_listing_declaration
# A bundle over the 6,000-char floor without a README mention of
# skillListingBudgetFraction must FAIL; the mention or the bless marker clears
# it; an under-floor bundle needs nothing. The over-floor fixture is one skill
# with a 1,536-char (capped) description repeated across five members — cheap to
# build and safely past the floor. This gate previously had NO harness
# (gate-coverage.sh reported NONE): a regression in its dependency-resolution
# sed would have passed CI silently.
LD="$FIX/ld"; mkdir -p "$LD"
bigdesc=$(printf 'x%.0s' $(seq 1 1600))
for m in m1 m2 m3 m4 m5; do
  mkdir -p "$LD/$m/.claude-plugin" "$LD/$m/skills/big"
  printf '{"name":"%s","version":"0.0.1","description":"d"}\n' "$m" > "$LD/$m/.claude-plugin/plugin.json"
  printf -- '---\ndescription: %s\n---\nbody\n' "$bigdesc" > "$LD/$m/skills/big/SKILL.md"
done
mkdir -p "$LD/bigbundle/.claude-plugin"
printf '{"name":"bigbundle","version":"0.0.1","description":"d","dependencies":["m1","m2","m3","m4","m5"]}\n' \
  > "$LD/bigbundle/.claude-plugin/plugin.json"
printf '# bigbundle\n' > "$LD/bigbundle/README.md"
run pc_listing_declaration "$LD"
fails "over-floor bundle without a declaration fails" "listing-floor-undeclared bigbundle"
printf 'Set skillListingBudgetFraction in settings.json.\n' >> "$LD/bigbundle/README.md"
run pc_listing_declaration "$LD"
clean "the skillListingBudgetFraction mention clears it"
printf '# bigbundle\n<!-- listing-floor-ok: test fixture -->\n' > "$LD/bigbundle/README.md"
run pc_listing_declaration "$LD"
clean "the bless marker clears it"
LD2="$FIX/ld2"; mkdir -p "$LD2/smallbundle/.claude-plugin" "$LD2/m1/.claude-plugin" "$LD2/m1/skills/s"
printf '{"name":"m1","version":"0.0.1","description":"d"}\n' > "$LD2/m1/.claude-plugin/plugin.json"
printf -- '---\ndescription: tiny\n---\nbody\n' > "$LD2/m1/skills/s/SKILL.md"
printf '{"name":"smallbundle","version":"0.0.1","description":"d","dependencies":["m1"]}\n' \
  > "$LD2/smallbundle/.claude-plugin/plugin.json"
printf '# smallbundle\n' > "$LD2/smallbundle/README.md"
run pc_listing_declaration "$LD2"
clean "an under-floor bundle needs no declaration"

# ------------------------------------------------------------------ live tree
run pc_hook_timeout plugins
clean "shipped tree: every hook entry declares a timeout"
run pc_budget_crowding plugins scripts/skill-crowding-baseline.json
clean "shipped tree: crowding at or below the committed baseline"
run pc_pick_parity plugins
clean "shipped tree: the two scout pickers are byte-identical"
run pc_listing_declaration plugins
clean "shipped tree: every over-floor bundle declares the requirement"

exit $rc
