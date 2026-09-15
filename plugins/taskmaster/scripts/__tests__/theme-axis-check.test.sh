#!/usr/bin/env bash
# Fixture tests for theme-axis-check.py — the machine gate behind a theme-axis
# pass. Proves the three exit codes the reference promises, and that the
# per-frame token preset (which lives OUTSIDE .vd-content) does not register as
# a content difference — the whole reason the extraction is scoped that way.
set -u
CHK="$(cd "$(dirname "$0")/.." && pwd)/theme-axis-check.py"
pass=0; fail=0
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

ok() { pass=$((pass+1)); echo "PASS: $1"; }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

# Identical content in all three frames, differing ONLY by a token preset in a
# style block outside .vd-content — an honest theme-axis pass.
cat > "$T/honest.html" <<'EOF'
<html><head><style>
#vd-a .vd-content{--vd-radius:0}
#vd-b .vd-content{--vd-radius:8px}
</style></head><body>
<div id="vd-a" class="vd-frame"><div class="vd-content"><p>Invoice #4821 &mdash; $1,240.00</p></div></div>
<div id="vd-b" class="vd-frame"><div class="vd-content"><p>Invoice #4821 &mdash; $1,240.00</p></div></div>
<div id="vd-c" class="vd-frame"><div class="vd-content"><p>Invoice #4821 &mdash; $1,240.00</p></div></div>
</body></html>
EOF
out=$(python3 "$CHK" "$T/honest.html"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ]; then ok "identical content + differing presets -> exit 0, silent"
else bad "honest pass: rc=$rc out=$out"; fi

# One frame's content differs — the pass is varying content as well as tokens.
cat > "$T/dishonest.html" <<'EOF'
<html><body>
<div class="vd-frame"><div class="vd-content"><p>Invoice #4821</p></div></div>
<div class="vd-frame"><div class="vd-content"><p>Invoice #4821</p></div></div>
<div class="vd-frame"><div class="vd-content"><p>Invoice #9999 plus an extra row</p></div></div>
</body></html>
EOF
out=$(python3 "$CHK" "$T/dishonest.html"); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'vd-content\[2\] differs from vd-content\[0\]'; then
  ok "differing content -> exit 1 naming the frame index"
else bad "dishonest pass: rc=$rc out=$out"; fi

# Entity resolution: &mdash; vs &ndash; must register as a difference, which is
# what convert_charrefs=True buys.
cat > "$T/entity.html" <<'EOF'
<html><body>
<div class="vd-content"><p>a &mdash; b</p></div>
<div class="vd-content"><p>a &ndash; b</p></div>
</body></html>
EOF
python3 "$CHK" "$T/entity.html" >/dev/null 2>&1
if [ $? -eq 1 ]; then ok "entity-only difference is caught"
else bad "entity-only difference slipped through"; fi

# Usage and unreadable-input errors are exit 2, never 0 or 1.
python3 "$CHK" >/dev/null 2>&1
[ $? -eq 2 ] && ok "no argument -> exit 2" || bad "no argument did not exit 2"
python3 "$CHK" "$T/absent.html" >/dev/null 2>&1
[ $? -eq 2 ] && ok "unreadable file -> exit 2" || bad "unreadable file did not exit 2"

# A document with no .vd-content at all is a usage error, not a silent pass:
# a mockup that lost its frames must not read as an honest theme-axis pass.
printf '<html><body><p>no frames here</p></body></html>' > "$T/empty.html"
python3 "$CHK" "$T/empty.html" >/dev/null 2>&1
[ $? -eq 2 ] && ok "no .vd-content -> exit 2, never a false pass" || bad "no .vd-content did not exit 2"

# The shipped, unfilled shell has slot comments that differ per frame, so it is
# expected to FAIL — asserting it keeps the extraction wired to the real asset.
SHELL_HTML="$(cd "$(dirname "$0")/../.." && pwd)/skills/visual-decisions/assets/shell.html"
if [ -f "$SHELL_HTML" ]; then
  python3 "$CHK" "$SHELL_HTML" >/dev/null 2>&1
  [ $? -eq 1 ] && ok "runs against the shipped shell.html (unfilled -> exit 1)" \
    || bad "shipped shell.html did not exit 1"
else
  bad "shell.html not found at $SHELL_HTML"
fi

echo "theme-axis-check tests: $pass passed, $fail failed"
exit $((fail > 0))
