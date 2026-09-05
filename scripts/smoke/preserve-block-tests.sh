#!/usr/bin/env bash
# preserve-block-tests.sh — round trip for the chassis preserve-block escape.
#
# WHY: the only escape from the drift gate used to be a whole-file `optout`. A
# generated file needing ONE different sentence had to be hand-maintained
# forever, forfeiting every later template improvement; the alternative, adding a
# template slot, re-renders all 31 sharers of review-command.md.tmpl and
# patch-bumps 31 plugin.json in one commit. A preserve block is the per-region
# escape between those two.
#
# Runs entirely inside a fixture tree via CHASSIS_ROOT / CHASSIS_TEMPLATES — it
# never touches plugins/ or templates/.
#
# Asserts, in order:
#   1. first stamp writes the template's default body
#   2. an edit INSIDE a preserve block survives --write   (the point)
#   3. --check is clean after that edit                    (not drift)
#   4. an edit OUTSIDE a preserve block is reverted by --write and is drift
#   5. a template change outside the block reaches a file whose block was edited
set -u
cd "$(dirname "$0")/../.." || exit 2
rc=0
FX=$(mktemp -d)
cleanup() { rm -rf "$FX"; }
trap cleanup EXIT

ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; rc=1; }

mkdir -p "$FX/templates/blocks" "$FX/root/.claude-plugin" \
         "$FX/root/plugins/fixture/.claude-plugin" "$FX/root/plugins/fixture/commands" \
         "$FX/root/plugins/plugin-scout/skills/plugin-scout/references"

# generate.sh always runs its repo-level catalog step, which reads marketplace.json
# and writes plugin-scout's catalog. Without these the run dies before any
# comparison and a naive "non-zero exit means drift" test reports a mechanism
# failure that is really a missing fixture file.
cat > "$FX/root/.claude-plugin/marketplace.json" <<'EOF'
{ "name": "fixture-marketplace", "metadata": { "version": "0.0.1" },
  "plugins": [ { "name": "fixture", "source": "./plugins/fixture", "description": "fixture" } ] }
EOF

cat > "$FX/root/plugins/fixture/.claude-plugin/plugin.json" <<'EOF'
{ "name": "fixture", "version": "0.1.0", "description": "fixture", "keywords": ["fixture"] }
EOF
cat > "$FX/root/plugins/fixture/.chassis.json" <<'EOF'
{ "chassis": "suite-uninstall", "bundle": "fixture",
  "lane": { "owns": "fixture-uninstall", "trigger": "invoked as /fixture:uninstall", "yieldsTo": "-" } }
EOF

write_tmpl() { # $1 = the line that lives OUTSIDE the preserve block
  cat > "$FX/templates/suite-uninstall.md.tmpl" <<EOF
<!-- generated from templates/suite-uninstall.md.tmpl -->
$1

<!-- preserve:notes -->
default note from the template
<!-- /preserve:notes -->

trailing line for {{bundle}}
EOF
}
write_tmpl "shared line v1"

gen() { CHASSIS_ROOT="$FX/root" CHASSIS_TEMPLATES="$FX/templates" bash scripts/generate.sh "$1" 2>&1; }
TARGET="$FX/root/plugins/fixture/commands/uninstall.md"

gen --write >/dev/null 2>&1
# A SKIP here would hide an untested mechanism behind a green run. Hard-fail.
if [ ! -f "$TARGET" ]; then
  echo "FAIL: fixture did not stamp — preserve-block logic UNTESTED, not passing"
  CHASSIS_ROOT="$FX/root" CHASSIS_TEMPLATES="$FX/templates" bash scripts/generate.sh --write 2>&1 | head -5
  exit 1
fi
grep -q "default note from the template" "$TARGET" && ok "first stamp writes the default body" \
  || bad "first stamp did not write the default body"

# 2 + 3: edit INSIDE the block
perl -0pi -e 's/default note from the template/LOCAL DIVERGENCE, hand-written/' "$TARGET"
gen --write >/dev/null 2>&1
grep -q "LOCAL DIVERGENCE, hand-written" "$TARGET" \
  && ok "preserve-block edit survives --write" || bad "preserve-block edit was clobbered by --write"
gen --check >/dev/null 2>&1 \
  && ok "preserve-block edit is not drift in --check" || bad "--check reports drift on a preserved edit"

# 4: edit OUTSIDE the block must still be reverted and must still be drift
perl -0pi -e 's/shared line v1/tampered outside the block/' "$TARGET"
gen --check >/dev/null 2>&1 \
  && bad "--check missed an edit OUTSIDE a preserve block" || ok "edit outside the block is still drift"
gen --write >/dev/null 2>&1
grep -q "shared line v1" "$TARGET" \
  && ok "edit outside the block is reverted by --write" || bad "outside-block tamper survived --write"
grep -q "LOCAL DIVERGENCE, hand-written" "$TARGET" \
  || bad "preserved body was lost while reverting an outside edit"

# 5: a template improvement still reaches a file carrying a local divergence —
# the whole reason this is not just an optout.
write_tmpl "shared line v2 — template improved"
gen --write >/dev/null 2>&1
grep -q "shared line v2 — template improved" "$TARGET" \
  && ok "template improvement reaches a file with a preserved edit" \
  || bad "template improvement did not propagate"
grep -q "LOCAL DIVERGENCE, hand-written" "$TARGET" \
  && ok "preserved body survived the template improvement" \
  || bad "preserved body lost on template change"

exit $rc
