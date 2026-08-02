#!/usr/bin/env bash
# Fixtures for plugins/task-runner/scripts/sweep-residual.sh.
#
# The fixture tree is the failure the gate exists for, seeded deliberately: twelve
# occurrences is the anecdote, but the SHAPE is what matters — one file a grep for
# the obvious form finds, one where the symbol is aliased before use, and one
# non-code carrier (a CI workflow). A model that edits the obvious file, runs a
# green suite over the paths that have tests, and reports the migration complete
# passes every other check in this repo. It must not pass this one.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
S=plugins/task-runner/scripts/sweep-residual.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

seed() {
  rm -rf "$FX"/*; mkdir -p "$FX/src" "$FX/.github/workflows"
  printf 'import axios from "axios"\naxios.get(a)\naxios.post(b)\n'  > "$FX/src/direct.ts"
  printf 'const http = axios\nhttp.get(c)\naxios.put(d)\n'           > "$FX/src/aliased.ts"
  printf 'run: npx axios-cli check\n'                                > "$FX/.github/workflows/ci.yml"
}

expect() { # label want args...
  local label="$1" want="$2"; shift 2
  bash "$S" "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $label (rc=$got)"
  else echo "FAIL: $label — want rc=$want, got $got"; rc=1; fi
}

seed
expect "freeze succeeds"                 0 --freeze  --id m1 --dir "$FX" --pattern 'axios'
expect "untouched tree is residual"      2 --measure --id m1 --dir "$FX"

# The exact failure mode: the obvious file is done, the aliased one and the CI
# carrier are not. A suite over src/direct.ts would be green here.
printf 'import x from "fetch"\nx.get(a)\n' > "$FX/src/direct.ts"
expect "partial migration still fails"   2 --measure --id m1 --dir "$FX"

printf 'const http = f\nhttp.get(c)\n' > "$FX/src/aliased.ts"
expect "non-code carrier alone fails"    2 --measure --id m1 --dir "$FX"

expect "allow WITHOUT a reason is a usage error" 3 --allow --id m1 --dir "$FX" --file "$FX/.github/workflows/ci.yml"
expect "allow with a reason succeeds"    0 --allow --id m1 --dir "$FX" --file "$FX/.github/workflows/ci.yml" --reason "external CLI, unrelated package"
expect "allowlisted survivor passes"     0 --measure --id m1 --dir "$FX"

# A file carrying the pattern that appeared AFTER the freeze is the case a
# one-shot grep cannot see at all: the target set moved under the migration.
printf 'axios.get(z)\n' > "$FX/src/added-later.ts"
expect "target set moved"                4 --measure --id m1 --dir "$FX"

expect "measure with no freeze"          5 --measure --id never --dir "$FX"
expect "freeze without a pattern"        3 --freeze  --id m2 --dir "$FX"
expect "no mode is a usage error"        3 --id m1 --dir "$FX"

# Residual must be recorded, not just reported — the state file is what makes
# "did this batch move the number" answerable after the fact.
seed
bash "$S" --freeze --id m3 --dir "$FX" --pattern 'axios' >/dev/null 2>&1
bash "$S" --measure --id m3 --dir "$FX" >/dev/null 2>&1
n=$(jq -r '.measurements | length' "$FX/.claude/task-runner/sweep-m3.json" 2>/dev/null)
if [ "${n:-0}" -ge 1 ]; then echo "PASS: measurement recorded in state ($n)"
else echo "FAIL: measurement not recorded"; rc=1; fi

orig=$(jq -r '.original_total' "$FX/.claude/task-runner/sweep-m3.json" 2>/dev/null)
if [ "${orig:-0}" -eq 6 ]; then echo "PASS: original total frozen (6)"
else echo "FAIL: original total wrong (got ${orig:-none}, want 6)"; rc=1; fi

[ "$rc" -eq 0 ] && echo "All sweep-residual fixtures passed."
exit "$rc"
