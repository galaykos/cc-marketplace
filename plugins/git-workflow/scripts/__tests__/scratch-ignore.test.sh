#!/usr/bin/env bash
# Drives scratch-ignore.sh: --check names an unignored scratch dir (exit 1), --apply
# writes one managed block that ignores it and leaves tracked/state paths alone,
# a second --apply does not duplicate, an empty repo and a non-repo exit 0.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"; s="$here/scratch-ignore.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*"; exit 1; }

repo="$tmp/repo"; mkdir -p "$repo/brain" "$repo/.design-kit/decks"; cd "$repo"
git init -q; git config user.email t@t; git config user.name t
echo "# map" > brain/INDEX.md; git add brain && git commit -q -m brain
echo "<html>" > .design-kit/decks/a.html

set +e; out="$(bash "$s" --check)"; rc=$?; set -e
[ "$rc" -eq 1 ] || fail "--check should exit 1 with an unignored scratch dir (rc=$rc)"
grep -q "NEEDS IGNORE" <<<"$out" || fail "no NEEDS IGNORE row: $out"
grep -qE '^\.design-kit/ .*NEEDS IGNORE' <<<"$out" || fail ".design-kit/ not named: $out"
grep -qE '^brain/ .*state.*left to you' <<<"$out" || fail "brain/ should be left to you: $out"

bash "$s" --apply >/dev/null
[ -f .gitignore ] || fail "no .gitignore written"
git check-ignore -q .design-kit/decks/a.html || fail ".design-kit not ignored after --apply"
git check-ignore -q __design-kit__/x.html || fail "cleaned pattern should be in the block too"
grep -q '^brain/$' .gitignore && fail "brain/ (state) must not be in the block"
grep -q '^design-system/$' .gitignore && fail "design-system/ (state) must not be in the block"
[ "$(grep -c 'cc-plugins-marketplace scratch (managed' .gitignore)" -eq 1 ] || fail "block header count"
bash "$s" --check >/dev/null || fail "--check should pass after --apply"

bash "$s" --apply >/dev/null
[ "$(grep -c 'cc-plugins-marketplace scratch (managed' .gitignore)" -eq 1 ] || fail "second --apply duplicated the block"
[ "$(grep -c '^\.design-kit/$' .gitignore)" -eq 1 ] || fail "pattern duplicated"

# a tracked scratch path is warned about, never added
mkdir -p taskmaster-docs && echo spec > taskmaster-docs/spec.md && git add -f taskmaster-docs && git commit -q -m spec
out="$(bash "$s" --apply)"
grep -q "WARN taskmaster-docs/ has tracked files" <<<"$out" || fail "tracked scratch should warn: $out"
grep -q '^taskmaster-docs/$' .gitignore && fail "tracked path must not enter the block"

# user lines outside the block survive a rewrite
echo "node_modules/" >> .gitignore; bash "$s" --apply >/dev/null
grep -q '^node_modules/$' .gitignore || fail "user line lost on rewrite"

empty="$tmp/empty"; mkdir -p "$empty"; cd "$empty"; git init -q
out="$(bash "$s" --check)"; grep -q "clean" <<<"$out" || fail "empty repo should be clean: $out"

nongit="$tmp/nongit"; mkdir -p "$nongit"; cd "$nongit"
out="$(bash "$s" --check)"; grep -q "not a git repository" <<<"$out" || fail "non-repo: $out"

# every inventory row has four tab-separated fields and a known kind
awk -F'\t' '!/^#/ && NF {if (NF!=4 || $3!~/^(scratch|cleaned|state)$/) {print "bad row: " $0; bad=1}} END {exit bad}' \
  "$here/../skills/branch-completion/references/marketplace-scratch.tsv" || fail "inventory shape"
echo "PASS scratch-ignore.test.sh"
