#!/usr/bin/env bash
# Drives `dk drift` (handoff-drift.py --scan) against a temp project: the hit pair
# from the panel finding — a component carrying `#6366f1` and `bg-indigo-500` must
# be reported, its twin using `var(--primary)` and `bg-primary` must come out
# clean — plus the false-positive controls the check would otherwise fire on (the
# token stylesheet that DECLARES the literals, an `href="#dad"` anchor, `bg-white`),
# the `--ci` exit, the not-measured exit, and `--staged`/`--diff` file selection
# including the empty-selection case that must scan nothing rather than everything.
#
# WHAT THIS DOES NOT PROVE. That the hits are the RIGHT ones for a real design
# system — scan mode reads the class string and the literal, never the role — and
# nothing here renders a component. handoff-drift.py's header carries the residuals.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
dk="$here/dk.sh"
drift="$here/handoff-drift.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

repo="$tmp/repo"; mkdir -p "$repo/src/components" "$repo/design-system"
cat > "$repo/src/index.css" <<'EOF'
:root { --primary: #1d4ed8; --surface: #ffffff; --ink: #0b1a3a; }
EOF
cat > "$repo/design-system/tokens.json" <<'EOF'
{ "color": { "primary": { "$type": "color", "$value": "#1d4ed8" },
             "surface": { "$type": "color", "$value": "#ffffff" } } }
EOF
cat > "$repo/src/components/Dirty.tsx" <<'EOF'
export function Dirty() {
  return (
    <a href="#dad" className="bg-indigo-500 text-slate-700/50" style={{ color: '#6366f1' }}>
      <span className="bg-[#6366f1]">go</span>
      <svg><rect fill="rgb(99, 102, 241)" /></svg>
    </a>
  )
}
EOF
cat > "$repo/src/components/Clean.tsx" <<'EOF'
export function Clean() {
  return (
    <a href="#pricing" className="bg-primary text-brand-700 bg-white" style={{ color: 'var(--primary)' }}>
      <span className="border-[color:var(--ink)]">go</span>
    </a>
  )
}
EOF

out="$(python3 "$drift" --scan "$repo/src/components/Dirty.tsx" --repo "$repo")"
grep -q '| literal | #6366f1 | --primary' <<<"$out" || fail "the literal hex hit is missing:
$out"
grep -q '| tw-palette | bg-indigo-500 |' <<<"$out" || fail "the named palette utility hit is missing:
$out"
grep -q '| tw-palette | text-slate-700/50 |' <<<"$out" || fail "the opacity-suffixed palette utility is missing:
$out"
grep -q '| literal | rgb(99, 102, 241) |' <<<"$out" || fail "the rgb() literal is missing:
$out"
grep -q '#dad' <<<"$out" && fail "an href anchor was read as a colour:
$out"
grep -q '^summary: 5 hit(s)' <<<"$out" || fail "summary count:
$out"

out="$(python3 "$drift" --scan "$repo/src/components/Clean.tsx" --repo "$repo")"
grep -q '^summary: 0 hit(s)' <<<"$out" || fail "the token-referencing twin must be clean:
$out"

# The token stylesheet is inside the scanned tree and DECLARES three literals.
# A check that reports them teaches people to hide their token source from it.
out="$(python3 "$drift" --scan "$repo/src" --repo "$repo")"
grep -q 'index.css' <<<"$out" && fail "a --name: declaration line was reported as drift:
$out"
grep -q '^summary: 5 hit(s)' <<<"$out" || fail "whole-dir scan count:
$out"

# --ci is the only thing that turns a table into a gate.
python3 "$drift" --scan "$repo/src" --repo "$repo" >/dev/null || fail "report mode must exit 0 with hits"
if python3 "$drift" --scan "$repo/src" --repo "$repo" --ci >/dev/null; then fail "--ci must exit 1 on a hit"; fi
python3 "$drift" --scan "$repo/src/components/Clean.tsx" --repo "$repo" --ci >/dev/null \
  || fail "--ci must exit 0 on a clean path"

# No token source anywhere is NOT MEASURED (exit 2), never a green.
empty="$tmp/empty"; mkdir -p "$empty"
set +e; out="$(python3 "$drift" --scan "$repo/src" --repo "$empty" --ci)"; rc=$?; set -e
[ "$rc" = 2 ] || fail "a repo with no tokens must exit 2, got $rc"
grep -q 'NOT MEASURED' <<<"$out" || fail "the not-measured line is missing:
$out"

# --staged / --diff select files through git, and an EMPTY selection scans nothing.
proj="$tmp/proj"; mkdir -p "$proj"
cp -R "$repo/src" "$repo/design-system" "$proj/"
( cd "$proj" && git init -q . && git add -A && git -c user.email=t@t -c user.name=t commit -qm init ) \
  || fail "could not build the git fixture"
run_dk() { ( cd "$proj" && bash "$dk" "$@" ) }

out="$(run_dk drift --diff HEAD 2>&1)" || fail "drift --diff exited non-zero on an empty diff: $out"
grep -q 'selected no file — nothing scanned' <<<"$out" \
  || fail "an empty --diff must scan nothing, not the whole tree:
$out"

printf 'export const C = () => <div className="text-rose-600"/>\n' > "$proj/src/components/C.tsx"
( cd "$proj" && git add src/components/C.tsx )
set +e; out="$(run_dk drift --staged --ci 2>&1)"; rc=$?; set -e
[ "$rc" = 1 ] || fail "--staged --ci should have failed on the staged palette utility (rc=$rc): $out"
grep -q 'C.tsx' <<<"$out" || fail "--staged did not select the staged file:
$out"
grep -q 'Dirty.tsx' <<<"$out" && fail "--staged scanned an unstaged file:
$out"

# Every verb logs one usage line; drift is not exempt.
python3 - "$proj/.design-kit/usage.jsonl" <<'PY' || exit 1
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1])]
assert [r for r in rows if r["verb"] == "drift"], rows
assert all(set(r) == {"ts", "verb", "outcome", "artifact"} for r in rows), rows
PY

echo "PASS drift.test.sh"
