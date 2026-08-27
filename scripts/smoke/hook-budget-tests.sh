#!/usr/bin/env bash
# Smoke tests for the two checks added 2026-08-27 to scripts/lib/plugin-checks.sh:
# pc_hook_timeout (every hooks.json entry declares a timeout) and
# pc_budget_crowding (the ratchet on SKILL bodies written to the 150-line cap).
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
mkskill crowded 149
base 1
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
clean "count equal to baseline — passes"

mkskill crowded2 150
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
fails "count above baseline — fails" "crowding 2 > 1"
printf '%s\n' "$out" | grep -qF 'crowded2/SKILL.md (150)' \
  && pass "names the crowded files" || bad "crowded file not named: $out"

# Directional half: the ratchet must stay silent when the number FALLS.
base 5
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
clean "count below baseline — passes (ratchet, not equality)"

# 147 is under the 3-line window and must not count.
rm -rf "$FIX/bc/p/skills/crowded" "$FIX/bc/p/skills/crowded2"
mkskill edge 147
base 0
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
clean "147-line body is outside the window"

mkskill edge2 148
run pc_budget_crowding "$FIX/bc" "$FIX/base.json"
fails "148-line body is inside the window" "crowding 1 > 0"

run pc_budget_crowding "$FIX/bc" "$FIX/does-not-exist.json"
clean "missing baseline file is not a violation"

# ------------------------------------------------------------------ live tree
run pc_hook_timeout plugins
clean "shipped tree: every hook entry declares a timeout"
run pc_budget_crowding plugins scripts/skill-crowding-baseline.json
clean "shipped tree: crowding at or below the committed baseline"

exit $rc
