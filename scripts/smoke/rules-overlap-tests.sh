#!/usr/bin/env bash
# Smoke tests for pc_rules_overlap (scripts/lib/plugin-checks.sh): the rules.tsv
# overlap gate must flag same-pattern high-confidence glob pairs that are neither
# marker-discriminated nor co-fire-ok-allowlisted — and nothing else.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$ROOT/scripts/lib/plugin-checks.sh"
FIX="$ROOT/scripts/smoke/validate-fixtures/rules-collision.tsv"
rc=0

out=$(pc_rules_overlap "$FIX") && gate_rc=0 || gate_rc=$?

if [ "$gate_rc" -ne 0 ]; then
  echo "PASS: fixture collision makes the gate fail (rc=$gate_rc)"
else
  echo "FAIL: gate passed a fixture containing an unresolved collision"; rc=1
fi

if printf '%s\n' "$out" | grep -qx 'overlap \*\.bad alpha-skill beta-skill'; then
  echo "PASS: unresolved pair flagged (*.bad alpha-skill beta-skill)"
else
  echo "FAIL: unresolved pair not flagged; output: $out"; rc=1
fi

if [ "$(printf '%s\n' "$out" | grep -c '^overlap ')" -eq 1 ]; then
  echo "PASS: exactly one violation reported"
else
  echo "FAIL: expected exactly 1 violation, got: $out"; rc=1
fi

case "$out" in
  *'*.vue'*) echo "FAIL: marker-discriminated pair (*.vue) wrongly flagged"; rc=1 ;;
  *) echo "PASS: marker-discriminated pair allowed" ;;
esac
case "$out" in
  *'*.tsx'*) echo "FAIL: co-fire-ok pair (*.tsx) wrongly flagged"; rc=1 ;;
  *) echo "PASS: co-fire-ok pair allowed" ;;
esac
case "$out" in
  *'*.low'*|*gamma*|*epsilon*) echo "FAIL: low-confidence/content rows wrongly flagged"; rc=1 ;;
  *) echo "PASS: low-confidence and content rows ignored" ;;
esac

if pc_rules_overlap "$ROOT/plugins/skill-router/rules.tsv" >/dev/null; then
  echo "PASS: live rules.tsv is overlap-clean"
else
  echo "FAIL: live rules.tsv has unresolved co-fires"; rc=1
fi

if pc_rules_overlap "$ROOT/scripts/smoke/validate-fixtures/__absent__.tsv"; then
  echo "PASS: missing file returns clean (fail-open for optional consumers)"
else
  echo "FAIL: missing file should return 0"; rc=1
fi


# --- content-row co-firing (pc_rules_cofire) ---------------------------------
# The glob-axis test above flags rows sharing an IDENTICAL pattern. Content rows
# never do, so that algorithm is vacuous for them; these cases prove the corpus
# gate catches what pattern equality structurally cannot.
. scripts/lib/plugin-checks.sh
CORPUS=scripts/smoke/router-corpus
RT=$(mktemp); trap 'rm -f "$RT"' EXIT

# 1. the shipped file is clean (every real pair is blessed)
if pc_rules_cofire plugins/skill-router/rules.tsv "$CORPUS" >/dev/null; then
  echo "PASS[cofire]: shipped rules.tsv has no unblessed content co-fire"
else
  echo "FAIL[cofire]: shipped rules.tsv has an unblessed content co-fire"; rc=1
fi

# 2. an unblessed row with a DISTINCT regex that overlaps on real code must fail
cp plugins/skill-router/rules.tsv "$RT"
printf 'content\t\\b(catch|rescue)\\b\tzz-probe\tzz\tlow\n' >> "$RT"
if pc_rules_cofire "$RT" "$CORPUS" >/dev/null; then
  echo "FAIL[cofire]: distinct-regex overlap went undetected"; rc=1
else
  echo "PASS[cofire]: distinct-regex overlap detected"
fi

# 3. the glob-axis gate must NOT see it — proving the two checks are not redundant
if pc_rules_overlap "$RT" >/dev/null; then
  echo "PASS[cofire]: pattern-equality gate is blind to it, as expected"
else
  echo "FAIL[cofire]: pattern-equality gate unexpectedly flagged a content row"; rc=1
fi

# --- reachability (pc_rules_reachable) ---------------------------------------
# A row that cannot fire is invisible to BOTH gates above: it collides with
# nothing and reaches no marker. `**/routes/api.php` shipped in exactly that
# state for months, so these fixtures lock the CLASS, not the one instance.

# 4. the shipped file is clean
if pc_rules_reachable plugins/skill-router/rules.tsv >/dev/null; then
  echo "PASS[reach]: every shipped rules.tsv row can fire"
else
  echo "FAIL[reach]: shipped rules.tsv carries an unreachable row"; rc=1
fi

# 5. the exact historical defect must be caught
cp plugins/skill-router/rules.tsv "$RT"
printf 'glob\t**/routes/api.php\tzz-probe\tzz\thigh\n' >> "$RT"
if pc_rules_reachable "$RT" >/dev/null; then
  echo "FAIL[reach]: a path-shaped basename glob went undetected"; rc=1
else
  echo "PASS[reach]: path-shaped basename glob detected"
fi

# 6. the ONE multi-segment form route.sh does implement must stay accepted — a
#    gate that rejected the working form would be worse than no gate
cp plugins/skill-router/rules.tsv "$RT"
printf 'glob\t**/probe-dir/**\tzz-probe\tzz\thigh\n' >> "$RT"
if pc_rules_reachable "$RT" >/dev/null; then
  echo "PASS[reach]: **/dir/** form accepted"
else
  echo "FAIL[reach]: **/dir/** form wrongly rejected"; rc=1
fi

# 7. an uncompilable content regex can never match either
cp plugins/skill-router/rules.tsv "$RT"
printf 'content\t[unclosed\tzz-probe\tzz\tlow\n' >> "$RT"
if pc_rules_reachable "$RT" >/dev/null; then
  echo "FAIL[reach]: invalid content regex went undetected"; rc=1
else
  echo "PASS[reach]: invalid content regex detected"
fi

# --- host-skill overlap (pc_host_overlap) ------------------------------------
# Preventive, not corrective: no shipped skill collides today, so these fixtures
# ARE the whole enforcement and must prove both directions.
HOSTFIX="$(mktemp -d)"
mkdir -p "$HOSTFIX/skills/dataviz" "$HOSTFIX/skills/information-design" "$HOSTFIX/commands"
printf -- '---\nname: dataviz\ndescription: x\n---\nbody\n' > "$HOSTFIX/skills/dataviz/SKILL.md"
printf -- '---\nname: information-design\ndescription: x\n---\nbody\n' > "$HOSTFIX/skills/information-design/SKILL.md"
printf -- '---\ndescription: x\n---\nbody\n' > "$HOSTFIX/commands/dataviz.md"

# 8. a skill named after a built-in must fail
if pc_host_overlap "$HOSTFIX/skills/dataviz/SKILL.md" >/dev/null; then
  echo "FAIL[host]: skill colliding with built-in dataviz went undetected"; rc=1
else
  echo "PASS[host]: skill colliding with a built-in detected"
fi

# 9. an ordinary skill must pass
if pc_host_overlap "$HOSTFIX/skills/information-design/SKILL.md" >/dev/null; then
  echo "PASS[host]: non-colliding skill accepted"
else
  echo "FAIL[host]: non-colliding skill wrongly flagged"; rc=1
fi

# 10. COMMANDS are namespaced at the call site, so a command name is not a
#     collision — the gate must stay silent, or ~30 /plugin:review commands break
if pc_host_overlap "$HOSTFIX/commands/dataviz.md" >/dev/null; then
  echo "PASS[host]: command names are out of scope, as designed"
else
  echo "FAIL[host]: gate wrongly flagged a command name"; rc=1
fi

# 11. the documented escape must work
printf -- '---\nname: dataviz\ndescription: x\n---\n<!-- host-ok --> defers to the built-in\n' > "$HOSTFIX/skills/dataviz/SKILL.md"
if pc_host_overlap "$HOSTFIX/skills/dataviz/SKILL.md" >/dev/null; then
  echo "PASS[host]: <!-- host-ok --> rescue honoured"
else
  echo "FAIL[host]: <!-- host-ok --> rescue ignored"; rc=1
fi
rm -rf "$HOSTFIX"

# --- cross-plugin handoff resolution (pc_handoff_refs) -----------------------
# ~90 bare `plugin:agent` edges ship across 37 distinct targets and nothing
# checked any of them: validate.sh gates the SLASH form only, and pc_removed_refs
# knows a hardcoded list of DELETED plugins. A typo or a missed rename in a live
# name failed silently at runtime — the model reads a name that does not exist
# and quietly works inline instead of delegating.
HFIX="$(mktemp -d)"

# 12. every shipped doc resolves
hrc=0
while IFS= read -r hf; do pc_handoff_refs "$hf" >/dev/null || hrc=1; done < <(
  find plugins -type f \( -path '*/skills/*/SKILL.md' -o -path '*/skills/*/references/*.md' \
    -o -path '*/commands/*.md' -o -path '*/agents/*.md' \) | sort -u)
if [ "$hrc" -eq 0 ]; then
  echo "PASS[handoff]: every shipped cross-plugin handoff resolves"
else
  echo "FAIL[handoff]: a shipped cross-plugin handoff does not resolve"; rc=1
fi

# 13. a typo in a LIVE plugin name must be caught — the class pc_removed_refs
#     structurally cannot see, since the plugin was never removed
printf 'route to ui-ux:ui-ux-enginer now\n' > "$HFIX/typo.md"
if pc_handoff_refs "$HFIX/typo.md" >/dev/null; then
  echo "FAIL[handoff]: typo in a live agent name went undetected"; rc=1
else
  echo "PASS[handoff]: typo in a live agent name detected"
fi

# 14. a real reference must pass
printf 'dispatch code-review:code-reviewer then task-runner:task-executor\n' > "$HFIX/ok.md"
if pc_handoff_refs "$HFIX/ok.md" >/dev/null; then
  echo "PASS[handoff]: resolving reference accepted"
else
  echo "FAIL[handoff]: resolving reference wrongly flagged"; rc=1
fi

# 15. Blade/Livewire component tags share the syntax exactly and must NOT trip it
printf '@foreach ($i as $x) <livewire:item-row :item="$x" /> @endforeach\n' > "$HFIX/blade.md"
if pc_handoff_refs "$HFIX/blade.md" >/dev/null; then
  echo "PASS[handoff]: markup tag ignored (preceded by <)"
else
  echo "FAIL[handoff]: markup tag wrongly flagged as a handoff"; rc=1
fi

# 16. a non-plugin LHS is out of scope with no exclusion list
printf 'set model:opus and fetch http:whatever\n' > "$HFIX/lhs.md"
if pc_handoff_refs "$HFIX/lhs.md" >/dev/null; then
  echo "PASS[handoff]: non-plugin left-hand side out of scope"
else
  echo "FAIL[handoff]: non-plugin left-hand side wrongly flagged"; rc=1
fi

# 17. the documented escape must work
printf 'bad example ui-ux:nope <!-- handoff-ok -->\n' > "$HFIX/esc.md"
if pc_handoff_refs "$HFIX/esc.md" >/dev/null; then
  echo "PASS[handoff]: <!-- handoff-ok --> rescue honoured"
else
  echo "FAIL[handoff]: <!-- handoff-ok --> rescue ignored"; rc=1
fi
rm -rf "$HFIX"

[ "$rc" -eq 0 ] && echo "All rules-overlap smoke tests passed."
exit "$rc"