#!/usr/bin/env bash
# Drives dk-usage.sh on (a) a fabricated project where every column is non-zero — a
# usage ledger, two decision rows naming a component path, a git commit touching that
# path inside the 7-day window, a revisited artifact, a deck with a PDF — and (b) an
# empty project: all zeros and followed-by-commit = n/a. Exit is 0 throughout.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

p="$tmp/proj"; d=.cc-artifacts/design-kit; mkdir -p "$p/$d/decks" "$p/$d/boards" "$p/$d/artifacts/.versions/readout" "$p/$d/previews" "$p/$d/design-system" "$p/src/components"
cd "$p"; git init -q; git config user.email t@t; git config user.name t
echo '{}' > $d/design-system/tokens.json; echo '# ds' > $d/design-system/DESIGN-SYSTEM.md
echo 'export const Button = () => null' > src/components/Button.tsx
git add -A && git commit -q -m base
sleep 1.1  # the decision must post-date the base commit by a whole second: git --since is second-granular
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > $d/usage.jsonl <<EOL
{"ts":"$ts","verb":"system","outcome":"ok","artifact":"$d/design-system/tokens.json"}
{"ts":"$ts","verb":"slides","outcome":"ok","artifact":"$d/decks/d.html"}
{"ts":"$ts","verb":"scratch","outcome":"ok","artifact":"src/__design-kit__/x.tsx"}
{"ts":"$ts","verb":"scratch","outcome":"fail","artifact":""}
{"ts":"$ts","verb":"share","outcome":"ok","artifact":"$d/artifacts/readout.html"}
{"ts":"$ts","verb":"export","outcome":"ok","artifact":"$d/decks/d.pdf"}
EOL
cat > $d/decisions.jsonl <<EOL
{"ts":"$ts","board":"boards/b.html","picked":2,"knobs":{},"text":{},"prompt":"Use \`src/components/Button.tsx\` ghost variant","consumed":true}
{"ts":"$ts","board":"boards/b.html","picked":1,"knobs":{},"text":{},"prompt":"second look","consumed":false}
EOL
echo '<html><title>D</title></html>' > $d/decks/d.html; echo '%PDF-fake' > $d/decks/d.pdf
echo '<html><title>B</title></html>' > $d/boards/b.html; echo png > $d/boards/b-board-1.png
echo '<html>v1</html>' > $d/artifacts/.versions/readout/v1.html
echo '<html>v2</html>' > $d/artifacts/readout.html
touch -t "$(date -v-3d +%Y%m%d%H%M 2>/dev/null || date -d '3 days ago' +%Y%m%d%H%M)" $d/artifacts/.versions/readout/v1.html
echo '// changed after the pick' >> src/components/Button.tsx; git add -A && git commit -q -m "apply pick"

out="$(bash "$here/dk-usage.sh" --projects "$p")"
echo "$out" | grep -q '| system | 1 | 0 | 0 | 0 | 0 | 0 | - |' || fail "system row: $out"
echo "$out" | grep -q '| slides | 1 | 0 | 0 | 0 | 2 | 0 | - |' || fail "slides row (1 export verb + 1 pdf): $out"
echo "$out" | grep -q '| design | 1 | 0 | 2 | 0 | 1 | 0 | 1 |' || fail "design row (2 picks, 1 png, 1 commit): $out"
echo "$out" | grep -q '| in-codebase | 0 | 0 | 1 | 1 | 0 | 0 | 1 |' || fail "in-codebase row (1 consumed, 1 ok scratch): $out"
echo "$out" | grep -q '| artifact | 1 | 1 | 0 | 0 | 0 | 1 | - |' || fail "artifact row (revisited, shared): $out"
echo "$out" | grep -q 'named paths: src/components/Button.tsx' || fail "named path: $out"
echo "$out" | grep -q 'verdict inputs: projects with a design-kit folder = 1; shared = 1; followed-by-commit = 1' || fail "verdict: $out"
j="$(bash "$here/dk-usage.sh" --projects "$p" --json)"; python3 -c "import json,sys;d=json.loads(sys.argv[1]);assert d[0]['followed_by_commit']==1 and d[0]['surfaces']['artifact']['shared']==1" "$j" || fail "json shape"
# a project from before 2026-11-14 holds .design-kit/ and design-system/ instead: the same table
o="$tmp/old"; cp -Rp "$p" "$o"; mv "$o/$d/design-system" "$o/design-system"; mv "$o/$d" "$o/.design-kit"; rmdir "$o/.cc-artifacts"
out3="$(bash "$here/dk-usage.sh" --projects "$o")"
[ "$(echo "$out3" | grep '^|')" = "$(echo "$out" | grep '^|')" ] && echo "$out3" | grep -q '(design-kit folder present: yes' || fail "the legacy layout reads differently: $out3"

e="$tmp/empty"; mkdir -p "$e"
out2="$(bash "$here/dk-usage.sh" --projects "$e")"
echo "$out2" | grep -q '(design-kit folder present: no' || fail "empty presence: $out2"
echo "$out2" | grep -q '| design | 0 | 0 | 0 | 0 | 0 | 0 | n/a |' || fail "empty design row: $out2"
echo "$out2" | grep -q 'followed-by-commit = n/a' || fail "empty verdict: $out2"
echo "PASS dk-usage.test.sh"
