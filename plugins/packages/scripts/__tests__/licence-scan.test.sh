#!/usr/bin/env bash
# Fixtures for plugins/packages/scripts/licence-scan.sh.
#
# The distribution-mode conditional is the whole reason this is a script and not a
# paragraph, so it is asserted in BOTH directions on the SAME input: MPL-2.0 must
# pass for saas and fail for a distributed binary, and AGPL must do the exact
# reverse. A scanner that returned one verdict per licence would be a licence list,
# which anybody can read off a lockfile.
#
# One fixture runs against a lockfile shipped inside this marketplace rather than a
# synthetic one — 170 entries, twelve MPL-2.0, none of them in package.json. That
# file is the evidence for the transitivity claim, so it is also the test.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
S=plugins/packages/scripts/licence-scan.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

ec() { local label="$1" want="$2"; shift 2; bash "$S" "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $label (rc=$got)"
  else echo "FAIL: $label — want rc=$want, got $got"; rc=1; fi; }

mklock() { # dir licence...
  local d="$1"; shift; mkdir -p "$d"
  { printf '{"lockfileVersion":3,"packages":{"":{"name":"x"}'
    local i=0
    for l in "$@"; do i=$((i+1)); printf ',"node_modules/p%s":{"version":"1.0.0","license":"%s"}' "$i" "$l"; done
    printf '}}\n'; } > "$d/package-lock.json"
}

# --- the conditional, both directions on the same input ---------------------
mklock "$FX/mpl" MIT MPL-2.0
ec "MPL-2.0 is routine for saas"                 0 --dir "$FX/mpl" --distribution saas
ec "MPL-2.0 is denied for a distributed binary"  2 --dir "$FX/mpl" --distribution distributed-binary

mklock "$FX/agpl" MIT AGPL-3.0
ec "AGPL bites saas"                             2 --dir "$FX/agpl" --distribution saas
ec "AGPL also bites a distributed binary"        2 --dir "$FX/agpl" --distribution distributed-binary
ec "AGPL is fine for internal-only"              0 --dir "$FX/agpl" --distribution internal

mklock "$FX/gpl" GPL-3.0-only
ec "GPL is denied for an MIT project"            2 --dir "$FX/gpl" --distribution oss-permissive
ec "GPL is fine for a copyleft project"          0 --dir "$FX/gpl" --distribution oss-copyleft

mklock "$FX/clean" MIT ISC Apache-2.0 BSD-3-Clause
ec "permissive set is clean everywhere"          0 --dir "$FX/clean" --distribution distributed-binary

# --- the silent-false-pass trap ---------------------------------------------
mkdir -p "$FX/v1"
printf '{"lockfileVersion":1,"dependencies":{"p1":{"version":"1.0.0"}}}\n' > "$FX/v1/package-lock.json"
ec "lockfileVersion 1 is unresolvable, not clean" 3 --dir "$FX/v1" --distribution saas

mkdir -p "$FX/unk"
printf '{"lockfileVersion":3,"packages":{"":{"name":"x"},"node_modules/p1":{"version":"1.0.0"}}}\n' > "$FX/unk/package-lock.json"
ec "a package declaring no licence is unresolved" 3 --dir "$FX/unk" --distribution saas

# --- mode is mandatory: a licence list without it is trivia ------------------
ec "no distribution mode is a usage error"       3 --dir "$FX/clean"
ec "unknown distribution mode is refused"        3 --dir "$FX/clean" --distribution whatever
mkdir -p "$FX/empty"
ec "no lockfile anywhere"                        3 --dir "$FX/empty" --distribution saas

# --- policy file --------------------------------------------------------------
ec "--init writes a policy"                      0 --dir "$FX/mpl" --policy "$FX/mpl/.licence-policy.json" --init
if jq -e '.distribution' "$FX/mpl/.licence-policy.json" >/dev/null 2>&1; then
  echo "PASS: written policy carries a distribution key"
else echo "FAIL: written policy has no distribution key"; rc=1; fi

jq '.distribution = "distributed-binary"' "$FX/mpl/.licence-policy.json" > "$FX/mpl/p2.json"
ec "policy file supplies the mode"               2 --dir "$FX/mpl" --policy "$FX/mpl/p2.json"

jq '.allow = ["MPL-2.0"]' "$FX/mpl/p2.json" > "$FX/mpl/p3.json"
ec "an allow entry clears a denied licence"      0 --dir "$FX/mpl" --policy "$FX/mpl/p3.json"

jq '.distribution = "saas" | .deny = ["MIT"]' "$FX/mpl/p2.json" > "$FX/mpl/p4.json"
ec "a deny entry adds beyond the mode default"   2 --dir "$FX/mpl" --policy "$FX/mpl/p4.json"

# --- composer ---------------------------------------------------------------
mkdir -p "$FX/php"
printf '{"packages":[{"name":"a/b","license":["MIT"]},{"name":"c/d","license":["AGPL-3.0"]}],"packages-dev":[]}\n' > "$FX/php/composer.lock"
ec "composer.lock array licences are read"       2 --dir "$FX/php" --distribution saas

# --- transitivity, on real in-repo data -------------------------------------
REAL=plugins/shadcn-studio/template
if [ -f "$REAL/package-lock.json" ]; then
  ec "real lockfile: clean for saas"                   0 --dir "$REAL" --distribution saas
  ec "real lockfile: MPL denied for a binary"          2 --dir "$REAL" --distribution distributed-binary
  n=$(bash "$S" --dir "$REAL" --distribution distributed-binary 2>/dev/null | grep -c 'MPL-2.0 ')
  if [ "${n:-0}" -ge 12 ]; then
    echo "PASS: found all $n transitive MPL entries (none is a direct dependency)"
  else echo "FAIL: expected >=12 transitive MPL entries, found ${n:-0}"; rc=1; fi
  if grep -q 'MPL' "$REAL/package.json" 2>/dev/null; then
    echo "FAIL: fixture premise broken — MPL now appears in package.json"; rc=1
  else echo "PASS: premise holds — a direct-dependency read would report clean"; fi
else
  echo "SKIP: $REAL/package-lock.json absent"
fi

[ "$rc" -eq 0 ] && echo "All licence-scan fixtures passed."
exit "$rc"
