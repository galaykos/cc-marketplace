#!/usr/bin/env bash
# Smoke tests for scripts/remove-plugin.sh: the --merge-into preflight, the --apply
# prose_match hint, and the dry run.
# remove-plugin.sh cds to its own parent, so the copy in the mirror edits the mirror. Both
# plugins it is pointed at are fixtures with no live counterpart: a run that reached the
# live tree would stop at "does not exist" before deleting anything.
set -u
cd "$(dirname "$0")/../.." || exit 2   # repo root
MP=.claude-plugin/marketplace.json
LEDGER=scripts/removed-plugins.tsv
BASELINES="scripts/context-budget-baseline.json scripts/context-budget-dynamic-baseline.json scripts/context-budget-activated-baseline.json"
EDITED="$MP $LEDGER README.md $BASELINES"
GONE=zz-rp-gone
HOST=zz-rp-host
EDITED_SUMS=$(cksum $EDITED) || exit 2
MIRROR=$(mktemp -d) || exit 2
R="$MIRROR/root"
cleanup() {
  rm -rf "$MIRROR"
  [ "$(cksum $EDITED)" = "$EDITED_SUMS" ] \
    || { echo "FAIL: a live file remove-plugin.sh edits changed during the run: $EDITED"; exit 1; }
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP
fails=0
ok()  { echo "PASS: $1"; }
bad() { echo "FAIL: $1 ($2)"; fails=1; }

# A fresh mirror: copies of the live files the script edits, with $GONE (one skill, alpha)
# registered in each, beside an empty $HOST. A run reaches the marketplace entry, the ledger
# row, the three baselines, the README row and its leaf count. NOT reached: the catalog
# regeneration (the mirror has no scout catalog, so the script's `-f` guard skips it; a
# mirror that adds one must add generate.sh too, or --apply aborts under set -e), the hook
# comparison that nulls a successor, a plain removal with no --merge-into, and the report
# of renames still targeting the name.
mk() {
  rm -rf "$R"
  mkdir -p "$R/.claude-plugin" "$R/scripts" "$R/plugins/$GONE/skills/alpha" || exit 2
  cp scripts/remove-plugin.sh "$LEDGER" "$R/scripts/" || exit 2
  jq --arg n "$GONE" '.plugins += [{name: $n, source: ("./plugins/" + $n)}]' "$MP" > "$R/$MP" || exit 2
  for b in $BASELINES; do jq --arg n "$GONE" '.[$n] = 1' "$b" > "$R/$b" || exit 2; done
  { cat README.md; printf '| `%s` | fixture row |\n' "$GONE"; } > "$R/README.md" || exit 2
  for p in "$GONE" "$HOST"; do
    mkdir -p "$R/plugins/$p/.claude-plugin" || exit 2
    printf '{"name":"%s","version":"0.1.0"}\n' "$p" > "$R/plugins/$p/.claude-plugin/plugin.json"
  done
  printf -- '---\nname: alpha\ndescription: fixture\n---\n' > "$R/plugins/$GONE/skills/alpha/SKILL.md"
}
snap() { ( cd "$R" && find . | LC_ALL=C sort && find . -type f -exec cksum {} + | LC_ALL=C sort ); }
run()  { out=$(bash "$R/scripts/remove-plugin.sh" "$@" 2>&1); rc=$?; }

# Run under --apply: an unchanged mirror is what shows the refusal precedes every edit.
expect_refusal() { # $1 label  $2 the host path that clashes
  before=$(snap)
  run "$GONE" --merge-into "$HOST" --apply
  if [ "$rc" -eq 2 ] && [ "$out" = "FAIL: $2 already exists" ] && [ "$(snap)" = "$before" ]; then ok "$1"
  else bad "$1" "want rc=2, only 'FAIL: $2 already exists', mirror unchanged; got rc=$rc '$out'"; fi
}

mk; mkdir -p "$R/plugins/$HOST/commands" && : > "$R/plugins/$HOST/commands/alpha.md"
expect_refusal "--merge-into refuses a host command of the same name" "plugins/$HOST/commands/alpha.md"

mk; mkdir -p "$R/plugins/$HOST/skills/alpha"
expect_refusal "--merge-into still refuses a host skill of the same name" "plugins/$HOST/skills/alpha"

mk
before=$(snap)
run "$GONE" --merge-into "$HOST"
dry=$out
if [ "$rc" -eq 0 ] && [ "$(snap)" = "$before" ] \
   && printf '%s\n' "$out" | grep -qxF 'dry-run only. re-run with --apply to edit.'; then
  ok "a dry run edits nothing"
else
  bad "a dry run edits nothing" "want rc=0, the dry-run closing line, mirror unchanged; got rc=$rc '$out'"
fi

mk
run "$GONE" --merge-into "$HOST" --apply
hints=$(printf '%s\n' "$out" | grep -c '^next: ')
if [ "$rc" -eq 0 ] && [ "$hints" -eq 1 ] \
   && printf '%s\n' "$out" | grep -q "^next: .*prose_match.*$LEDGER.*'$GONE'" \
   && awk -F'\t' -v n="$GONE" '$1 == n && $4 == "no" { found = 1 } END { exit !found }' "$R/$LEDGER" \
   && ! printf '%s\n' "$dry" | grep -q '^next: '; then
  ok "--apply prints the prose_match review hint"
else
  bad "--apply prints the prose_match review hint" \
    "want rc=0, one 'next:' line naming prose_match, $LEDGER and '$GONE', a '$GONE' row with prose_match no, and no 'next:' line in the dry run; got rc=$rc '$out'"
fi

exit $fails
