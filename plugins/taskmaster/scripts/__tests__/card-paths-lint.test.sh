#!/usr/bin/env bash
# Tests for card-paths-lint.sh: the retro 2026-11-05 card misses (an unreplaced __B__, a verify target that
# does not exist, an edited file that does not exist) exit 2, and their neighbours that must stay clean exit 0.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); lint="$here/../card-paths-lint.sh"
[ -x "$lint" ] || { printf 'FAIL: lint not executable at %s\n' "$lint"; exit 1; }
WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
R="$WS/repo"; mkdir -p "$R/app/Models" "$R/tests/Feature" "$R/cards" "$R/Assets/Scripts"
git -C "$R" init -q 2>/dev/null
printf '<?php\n' > "$R/app/Models/Report.php"; printf '<?php\n' > "$R/tests/Feature/ReportTest.php"
export CC_CARDLINT_DIR="$WS/records"
pass=0; fail=0
card() { # name verify-line [extra lines] -> path
  local f="$R/cards/$1.md"; shift
  { printf '<card id="x">\n<facts>\n'; printf '%s\n' "${@:2}"; printf '</facts>\n<proof><verify>%s</verify></proof>\n</card>\n' "$1"; } > "$f"
  printf '%s' "$f"
}
case_() { # desc want-rc want-substr card
  local out rc; out=$("$lint" --card "$4" --root "$R" 2>&1); rc=$?
  if [ "$rc" = "$2" ] && { [ -z "$3" ] || printf '%s' "$out" | grep -qF -- "$3"; }; then pass=$((pass+1)); printf 'PASS: %s\n' "$1"
  else fail=$((fail+1)); printf 'FAIL: %s (rc=%s want=%s out=<%s>)\n' "$1" "$rc" "$2" "$out"; fi
}

case_ "clean: an edited file and a verify target that exist" 0 "" \
  "$(card 01 'vendor/bin/pest tests/Feature/ReportTest.php --filter=totals' '<file path="app/Models/Report.php" line="12" mode="edit">totals</file>')"
case_ "retro: __B__ left in a verify line" 2 "placeholder: __B__" \
  "$(card 02 'flock __B____B__ vendor/bin/pest tests/Feature/ReportTest.php' '<file path="app/Models/Report.php" line="3" mode="edit">x</file>')"
case_ "an all-caps {{CARD_ID}} token is a placeholder" 2 "placeholder: {{CARD_ID}}" \
  "$(card 03 'vendor/bin/pest tests/Feature/ReportTest.php' '<file path="app/Models/Report.php" line="3" mode="edit">see {{CARD_ID}}</file>')"
case_ "neighbour: PHP __DIR__ and a Blade {{ \$user->name }} are code, not tokens" 0 "" \
  "$(card 04 'vendor/bin/pest tests/Feature/ReportTest.php' '<file path="app/Models/Report.php" line="3" mode="edit">require __DIR__ and render {{ $user->name }}</file>')"
case_ "retro: card 09's verify names a test file that does not exist" 2 "verify-target-missing: tests/Feature/CardNineTest.php" \
  "$(card 09 'vendor/bin/pest tests/Feature/CardNineTest.php' '<file path="app/Models/Report.php" line="3" mode="edit">x</file>')"
case_ "neighbour: a verify target this card creates is fine" 0 "" \
  "$(card 10 'vendor/bin/pest tests/Feature/NewTest.php' '<file path="tests/Feature/NewTest.php" mode="create"/>')"
card 11 'vendor/bin/pest tests/Feature/Sibling.php' '<file path="tests/Feature/Sibling.php" mode="create"/>' >/dev/null
case_ "neighbour: a verify target a sibling card creates is fine" 0 "" \
  "$(card 12 'vendor/bin/pest tests/Feature/Sibling.php' '<file path="app/Models/Report.php" line="3" mode="edit">x</file>')"
case_ "retro: an edited file that does not exist (StarDef.cs)" 2 "edit-missing: Assets/Scripts/StarDef.cs" \
  "$(card 13 'dotnet test core/Tests' '<file path="Assets/Scripts/StarDef.cs" line="40" mode="edit">dead reference</file>')"
case_ "neighbour: URLs, flags, globs and absolute paths in verify are not targets" 0 "" \
  "$(card 14 'curl -fsS http://localhost/api/x.json && npx playwright test e2e/*.spec.ts --reporter=line /tmp/out.log' '<file path="app/Models/Report.php" line="3" mode="edit">x</file>')"
printf '# Card 15\n\n**Verify:** `vendor/bin/pest tests/Feature/Ghost.php`\n' > "$R/cards/15.md"
case_ "legacy bold Verify line is read too" 2 "verify-target-missing: tests/Feature/Ghost.php" "$R/cards/15.md"
out=$("$lint" --card "$R/cards/nope.md" 2>&1); rc=$?
[ "$rc" = 3 ] && { pass=$((pass+1)); echo "PASS: a missing card is a usage error"; } || { fail=$((fail+1)); echo "FAIL: missing card rc=$rc"; }
[ -s "$WS/records/01.md.log" ] && grep -q 'card-paths' "$WS/records/01.md.log" \
  && { pass=$((pass+1)); echo "PASS: a run record is written"; } || { fail=$((fail+1)); echo "FAIL: no run record"; }

echo "card-paths-lint: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
