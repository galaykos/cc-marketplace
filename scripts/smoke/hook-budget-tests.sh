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
#
# Two more checks joined them on 2026-09-22 and are exercised the same way:
# pc_hook_shebang (a registered hook must start `#!/bin/bash`) and
# pc_command_arg_hint (a command reading `$ARGUMENTS` must declare the hint the
# host shows in the slash menu). The shebang one has 11 live offenders and is
# WARN-tier in validate.sh until they land, so these fixtures are the only place
# its FAIL path is executed at all.
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

# ------------------------------------------------------------- pc_plugin_corpus
# Corpus = .md under skills/, generated files and non-.md runtime assets excluded.
mkref() { # mkref <plugin> <skill> <file> <bytes> [generated]
  mkdir -p "$FIX/pcx/$1/skills/$2/references"
  { [ -n "${5:-}" ] && printf '<!-- generated by scripts/generate.sh -->\n'
    head -c "$4" /dev/zero | tr '\0' 'x'; } > "$FIX/pcx/$1/skills/$2/references/$3"
}
cbase() { printf '{"plugins_over_cap": %s}\n' "$1" > "$FIX/cbase.json"; }

mkdir -p "$FIX/pcx/small/skills/a"; printf -- '---\nname: a\n---\nbody\n' > "$FIX/pcx/small/skills/a/SKILL.md"
cbase 0
run pc_plugin_corpus "$FIX/pcx" "$FIX/cbase.json"
clean "small plugin is under cap"

mkref big s1 heavy.md 170000
run pc_plugin_corpus "$FIX/pcx" "$FIX/cbase.json"
fails "plugin over the 160,000 B cap — fails" "corpus 1 > 0"
printf '%s\n' "$out" | grep -qF 'big (' \
  && pass "names the offending plugin with its byte count" || bad "offender not named: $out"

cbase 1
run pc_plugin_corpus "$FIX/pcx" "$FIX/cbase.json"
clean "count equal to baseline — passes"

cbase 5
run pc_plugin_corpus "$FIX/pcx" "$FIX/cbase.json"
clean "count below baseline — passes (ratchet, not equality)"

# The generated exclusion is the whole reason marketplace growth cannot fail this
# gate inside stack-scan (host of the scout catalog). A generated file of the same size must not count.
rm -f "$FIX/pcx/big/skills/s1/references/heavy.md"
mkref big s1 catalog.md 170000 gen
cbase 0
run pc_plugin_corpus "$FIX/pcx" "$FIX/cbase.json"
clean "a generated .md of the same size does not count"

# Runtime assets are code the plugin RUNS, not prose the model READS. Counting
# them read taskmaster at 70,664 against a real 36,037.
rm -f "$FIX/pcx/big/skills/s1/references/catalog.md"
mkdir -p "$FIX/pcx/big/skills/s1/assets"
head -c 170000 /dev/zero | tr '\0' 'x' > "$FIX/pcx/big/skills/s1/assets/shell.html"
run pc_plugin_corpus "$FIX/pcx" "$FIX/cbase.json"
clean "a 170,000 B runtime .html does not count"

run pc_plugin_corpus "$FIX/pcx" "$FIX/does-not-exist.json"
clean "missing baseline file is not a violation"

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

# --------------------------------------------------------------- pc_hook_shebang
# Only a script a hooks.json REGISTERS is in scope, so the fixtures must go through
# a real hooks.json — a loose .sh in hooks/ must not be read at all.
HSOK="$FIX/hsok"; HSBAD="$FIX/hsbad"; HSMARK="$FIX/hsmark"
mkdir -p "$HSOK/good/hooks" "$HSBAD/bad/hooks" "$HSMARK/blessed/hooks"
hooksjson() { cat > "$1" <<EOF
{"hooks":{"UserPromptSubmit":[{"hooks":[
  {"type":"command","command":"\${CLAUDE_PLUGIN_ROOT}/hooks/h.sh","timeout":5}]}]}}
EOF
}
hooksjson "$HSOK/good/hooks/hooks.json"
hooksjson "$HSBAD/bad/hooks/hooks.json"
hooksjson "$HSMARK/blessed/hooks/hooks.json"
printf '#!/bin/bash\nexit 0\n' > "$HSOK/good/hooks/h.sh"
run pc_hook_shebang "$HSOK"
clean "absolute shebang — passes"

printf '#!/usr/bin/env bash\nexit 0\n' > "$HSBAD/bad/hooks/h.sh"
run pc_hook_shebang "$HSBAD"
fails "env shebang on a registered hook — fails" "hook-shebang bad:h.sh"

printf '#!/usr/bin/env bash\n# env-shebang-ok: NixOS image has no /bin/bash\nexit 0\n' > "$HSMARK/blessed/hooks/h.sh"
run pc_hook_shebang "$HSMARK"
clean "the env-shebang-ok marker clears it"

# An UNREGISTERED script with the wrong shebang is out of scope by design.
printf '#!/usr/bin/env bash\nexit 0\n' > "$HSOK/good/hooks/helper.sh"
run pc_hook_shebang "$HSOK"
clean "an unregistered hooks/*.sh is not read"

# ------------------------------------------------------------ pc_command_arg_hint
AHOK="$FIX/ahok"; AHBAD="$FIX/ahbad"; AHNONE="$FIX/ahnone"
mkdir -p "$AHOK/good/commands" "$AHBAD/bad/commands" "$AHNONE/noargs/commands"
printf -- '---\ndescription: d\nargument-hint: [path]\n---\n\nReview $ARGUMENTS.\n' > "$AHOK/good/commands/c.md"
run pc_command_arg_hint "$AHOK"
clean "\$ARGUMENTS with a hint — passes"

printf -- '---\ndescription: d\n---\n\nReview $ARGUMENTS.\n' > "$AHBAD/bad/commands/c.md"
run pc_command_arg_hint "$AHBAD"
fails "\$ARGUMENTS with no hint — fails" "command-arg-hint bad:c"

printf -- '---\ndescription: d\n---\n\nRun the audit over the working tree.\n' > "$AHNONE/noargs/commands/c.md"
run pc_command_arg_hint "$AHNONE"
clean "a command taking no arguments needs no hint"

# `argument-hint` in the BODY is not a declaration — the host reads frontmatter.
printf -- '---\ndescription: d\n---\n\nSet argument-hint: [path] one day. Review $ARGUMENTS.\n' > "$AHBAD/bad/commands/c.md"
run pc_command_arg_hint "$AHBAD"
fails "the key in the body does not count" "command-arg-hint bad:c"

# ------------------------------------------------------------------ live tree
run pc_hook_timeout plugins
clean "shipped tree: every hook entry declares a timeout"
run pc_command_arg_hint plugins
clean "shipped tree: every \$ARGUMENTS command declares an argument-hint"
run pc_budget_crowding plugins scripts/skill-crowding-baseline.json
clean "shipped tree: crowding at or below the committed baseline"
run pc_listing_declaration plugins
clean "shipped tree: every over-floor bundle declares the requirement"


run pc_plugin_corpus plugins scripts/plugin-corpus-baseline.json
clean "shipped tree: plugins over the corpus cap at or below the committed baseline"

exit $rc
