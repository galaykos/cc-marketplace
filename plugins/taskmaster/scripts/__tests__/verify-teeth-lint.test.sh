#!/usr/bin/env bash
# Tests for verify-teeth-lint.sh — the B3(a) author-time denylist lint.
# Each case captures the exit code explicitly and prints PASS/FAIL. The script
# exits 0 only if every case passes.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
lint="$here/../verify-teeth-lint.sh"

[ -x "$lint" ] || { printf 'FAIL: lint not executable at %s\n' "$lint"; exit 1; }

pass=0
fail=0

# run_case <desc> <expected_rc> <expected_stderr_substr> -- <lint args...>
# Empty expected_stderr_substr means "do not check output".
run_case() {
  desc="$1"; exp_rc="$2"; exp_sub="$3"; shift 3
  set +e
  out=$("$lint" "$@" 2>&1)
  rc=$?
  set -e
  ok=1
  [ "$rc" = "$exp_rc" ] || ok=0
  if [ -n "$exp_sub" ]; then
    printf '%s' "$out" | grep -q -- "$exp_sub" || ok=0
  fi
  if [ "$ok" = 1 ]; then
    printf 'PASS: %s (rc=%s)\n' "$desc" "$rc"
    pass=$((pass + 1))
  else
    printf 'FAIL: %s (rc=%s want=%s; out=<%s> want-substr=<%s>)\n' \
      "$desc" "$rc" "$exp_rc" "$out" "$exp_sub"
    fail=$((fail + 1))
  fi
}

# --- Required minimum cases (from the card) ---
run_case "existence-only: test -f"        2 "existence-only"  --line 'test -f out.js'
run_case "bare-suite-pass: npm test"      2 "bare-suite-pass" --line 'npm test'
run_case "require-only: node -e require"  2 "require-only"    --line 'node -e "require(\"./x\")"'
run_case "strong: jest -t + asserts"      0 ""                --line 'jest -t "rejects bad host" asserts throw'

# --- Additional coverage for every weak form and a strong runner line ---
run_case "strong: pytest -k + asserts"    0 ""                --line 'pytest -k reject_malicious_host asserts 422'
run_case "always-true: || true"           2 "always-true"     --line 'curl -s localhost:3000/health || true'
# --- Fix 3: always-true tails that evaded the old '([[:space:]]|$)' boundary ---
run_case "always-true: || true; (semicolon)" 2 "always-true"  --line 'npm test || true;'
run_case "always-true: cmd || true) (paren)" 2 "always-true"  --line 'cmd || true)'
run_case "always-true: (cmd || true) full"   2 "always-true"  --line '(cmd || true)'
run_case "always-true: || : (no-op builtin)" 2 "always-true"  --line 'cmd || :'
run_case "always-true: bash -c quoted || true" 2 "always-true" --line 'bash -c "npm test || true"'
run_case "strong: colon in url not always-true" 0 ""          --line 'curl -s http://localhost:3000/api | grep -q ready'
run_case "compile-only: tsc --noEmit"     2 "compile-only"    --line 'tsc --noEmit'
run_case "import-only: python -c import"   2 "import-only"     --line 'python -c "import app"'
run_case "existence-only: ls whole check" 2 "existence-only"  --line 'ls dist/'
# --- Fix 1: existence-only via `test -d` and the `[ -f ]` bracket form ---
run_case "existence-only: test -d dir"    2 "existence-only"  --line 'test -d dist'
run_case "existence-only: [ -f ] bracket" 2 "existence-only"  --line '[ -f out.js ]'
run_case "existence-only: [ -d ] bracket" 2 "existence-only"  --line '[ -d dist ]'
run_case "strong: [ -f ] && grep guarded" 0 ""                --line '[ -f out.js ] && grep -q ready out.js'
# --- Fix 2: `.toString`/ordinary methods must NOT count as an assertion, so a bare
#     require(...).toString() is still require-only; real jest matchers still count. ---
run_case "require-only: require().toString()" 2 "require-only" --line 'node -e "require(\"./x\").toString()"'
run_case "strong: require().toBeTruthy() matcher" 0 ""        --line 'node -e "require(\"./x\").val.toBeTruthy()"'
run_case "usage: no args"                 3 "usage"

# --- PHP runners: bare forms blocked, --filter named forms pass ---
run_case "weak: php artisan test bare"    2 "bare-suite-pass"    --line 'php artisan test'
run_case "weak: pest bare"                2 "bare-suite-pass"    --line 'pest'
run_case "weak: phpunit bare"             2 "bare-suite-pass"    --line 'phpunit'
run_case "weak: composer test bare"       2 "bare-suite-pass"    --line 'composer test'
run_case "strong: pest --filter="         0 ""                   --line 'pest --filter=RefundTest'
run_case "strong: phpunit --filter space" 0 ""                   --line 'phpunit --filter OrderTest'

# --- JVM / .NET / C++ runners: blind until 2026-09-22, when the alternation demanded a
#     literal `mvn test` / `gradle test` and every wrapper form passed as if it named a
#     test. Bare forms blocked; --tests / -Dtest= / --filter named forms pass. ---
run_case "weak: ./gradlew test bare"      2 "bare-suite-pass"    --line './gradlew test'
run_case "weak: mvn -q test bare"         2 "bare-suite-pass"    --line 'mvn -q test'
run_case "weak: dotnet test bare"         2 "bare-suite-pass"    --line 'dotnet test'
run_case "weak: ./mvnw test bare"         2 "bare-suite-pass"    --line './mvnw test'
run_case "weak: sbt test bare"            2 "bare-suite-pass"    --line 'sbt test'
run_case "weak: bazel test bare"          2 "bare-suite-pass"    --line 'bazel test //...'
run_case "weak: ctest bare"               2 "bare-suite-pass"    --line 'ctest'
run_case "strong: gradlew --tests"        0 ""                   --line './gradlew test --tests com.acme.OrderServiceTest'
run_case "strong: mvn -Dtest="            0 ""                   --line 'mvn test -Dtest=OrderServiceTest'
run_case "strong: dotnet test --filter"   0 ""                   --line 'dotnet test --filter FullyQualifiedName~OrderTests'

# --- migration-run-only: the command ran proves the DDL parsed, not the schema ---
run_case "weak: artisan migrate only"     2 "migration-run-only" --line 'php artisan migrate — exits 0'
run_case "weak: alembic upgrade only"     2 "migration-run-only" --line 'alembic upgrade head'
run_case "weak: rails db:migrate only"    2 "migration-run-only" --line 'rails db:migrate runs cleanly'
run_case "strong: migrate + assertion"    0 ""                   --line 'php artisan migrate then assert orders.refund_id is NOT NULL'

# --- --card extraction: weak and strong Verify lines from a markdown card ---
tmp_weak=$(mktemp)
tmp_strong=$(mktemp)
trap 'rm -f "$tmp_weak" "$tmp_strong"' EXIT
printf '# Card 07\n\n- **Goal:** ship it\n- **Verify:** `npm test`\n' > "$tmp_weak"
printf -- '- **Verify:** `pytest -k reject_bad_host asserts 422`\n' > "$tmp_strong"
run_case "card: extracts weak Verify line"   2 "bare-suite-pass" --card "$tmp_weak"
run_case "card: extracts strong Verify line" 0 ""                --card "$tmp_strong"

# --- --card extraction, role-tagged shape: <verify> element wins over a legacy line ---
tmp_tag_weak=$(mktemp); tmp_tag_strong=$(mktemp); tmp_tag_both=$(mktemp); tmp_tag_none=$(mktemp)
trap 'rm -f "$tmp_weak" "$tmp_strong" "$tmp_tag_weak" "$tmp_tag_strong" "$tmp_tag_both" "$tmp_tag_none"' EXIT
printf '# 07\n<card id="07">\n<proof>\n<verify>npm test</verify>\n</proof>\n</card>\n' > "$tmp_tag_weak"
printf '# 07\n<card id="07">\n<proof>\n<verify>`pytest -k reject_bad_host asserts 422`</verify>\n</proof>\n</card>\n' > "$tmp_tag_strong"
printf '# 07\n<verify>pytest -k reject_bad_host asserts 422</verify>\n**Verify:** `npm test`\n' > "$tmp_tag_both"
printf '# 07\n<card id="07">\n<proof>\n<criterion>x</criterion>\n</proof>\n</card>\n' > "$tmp_tag_none"
run_case "card: tagged weak <verify>"          2 "bare-suite-pass" --card "$tmp_tag_weak"
run_case "card: tagged strong <verify>"        0 ""                --card "$tmp_tag_strong"
run_case "card: tagged element beats legacy"   0 ""                --card "$tmp_tag_both"
run_case "card: no element, no line -> usage"  3 "no <verify> element" --card "$tmp_tag_none"

# --- ui-static-only WARN (exit stays 0). The fixture is the shape of card 39 from a run
#     reviewed 2026-09-25: a React component verified by types + lint + a data-test grep.
#     The lint exited 0 on it and the UI shipped with no browser check. ---
ui_dir=$(mktemp -d)
trap 'rm -f "$tmp_weak" "$tmp_strong" "$tmp_tag_weak" "$tmp_tag_strong" "$tmp_tag_both" "$tmp_tag_none"; rm -rf "$ui_dir"' EXIT
cat > "$ui_dir/39-ai-controls.md" <<'CARD'
# 39 — Add AI caption controls to the approval row

<card id="39">
<goal>Approvers regenerate or reject an AI caption from the approval row without leaving the queue.</goal>

<facts>
<file path="resources/js/components/approvals/approval-row.tsx" line="42" mode="edit">row renders the caption text only</file>
<file path="resources/js/components/approvals/approval-ai-controls.tsx" mode="create"/>
<convention>interactive hooks carry data-test="…" attributes</convention>
</facts>

<must>
<change>render ApprovalAiControls (Regenerate caption, Reject) inside approval-row, posting to the existing endpoints</change>
<skill name="inertia-best-practices"/>
</must>

<must-not>
<file path="resources/js/pages/approvals/index.tsx" reason="card 40 owns the page layout"/>
</must-not>

<proof>
<criterion>an approver sees Regenerate caption and Reject on a row with an AI caption</criterion>
<verify>npm run types:check && npm run check && grep -c 'data-test="approval-ai-controls"' resources/js/components/approvals/approval-row.tsx</verify>
</proof>

<depends-on>38</depends-on>
<agent>frontend</agent>
</card>
CARD
p1="$ui_dir/39-ai-controls.md"
p1_line=$(sed -n 's|^<verify>\(.*\)</verify>$|\1|p' "$p1")
sed 's|^<verify>.*</verify>$|<verify>npm run types:check \&\& npx vitest run resources/js/components/approvals/approval-row.test.tsx -t "reject returns focus to the row"</verify>|' "$p1" > "$ui_dir/twin-runner.md"
sed 's|^<verify>.*</verify>$|<verify>npx playwright test tests/e2e/approvals.spec.ts -g "regenerate caption"</verify>|' "$p1" > "$ui_dir/twin-browser.md"
awk '{ print } /^<verify>/ { print "<walk surface=\"/approvals\" widths=\"1280,375\">a row with an AI caption: both controls visible; at 375 they sit under the caption</walk>" }' "$p1" > "$ui_dir/with-walk.md"
sed 's|resources/js/components/approvals/|resources/js/Pages/Approvals/|' "$p1" > "$ui_dir/inertia-pages.md"
sed -e 's|path="resources/js/components/approvals/approval-row.tsx"|path="app/Services/CaptionService.php"|' \
    -e 's|path="resources/js/components/approvals/approval-ai-controls.tsx"|path="app/Services/CaptionPrompt.php"|' "$p1" > "$ui_dir/backend-only.md"
sed 's|path="resources/js/components/approvals/approval-ai-controls.tsx"|path="resources/js/components/approvals/approval-row.test.tsx"|; s|path="resources/js/components/approvals/approval-row.tsx"|path="app/Services/CaptionService.php"|' "$p1" > "$ui_dir/test-file-only.md"

run_case "ui-static-only: P1 card 39 WARNs, exit 0"     0 "WARN ui-static-only: resources/js/components/approvals/approval-row.tsx" --card "$p1"
run_case "ui-static-only: names the missing <walk>"    0 "this card has none"     --card "$p1"
run_case "ui-static-only: with <walk>, says so"         0 "<walk> line is the only look" --card "$ui_dir/with-walk.md"
run_case "ui-static-only: Inertia Pages/ (any case)"    0 "WARN ui-static-only"    --card "$ui_dir/inertia-pages.md"

# run_quiet <desc> <lint args...> : exit 0 AND no ui-static-only line. run_case cannot
# assert an ABSENT string, and a twin that passes only because the lint says nothing
# is the load-bearing half of this pair.
run_quiet() {
  desc="$1"; shift
  set +e; out=$("$lint" "$@" 2>&1); rc=$?; set -e
  if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q 'ui-static-only'; then
    printf 'PASS: %s (rc=%s, no WARN)\n' "$desc" "$rc"; pass=$((pass + 1))
  else
    printf 'FAIL: %s (rc=%s out=<%s>)\n' "$desc" "$rc" "$out"; fail=$((fail + 1))
  fi
}
run_quiet "ui-static-only: twin with a named vitest test"   --card "$ui_dir/twin-runner.md"
run_quiet "ui-static-only: twin with a Playwright test"     --card "$ui_dir/twin-browser.md"
run_quiet "ui-static-only: same verify, backend files only" --card "$ui_dir/backend-only.md"
run_quiet "ui-static-only: a test file is not a UI file"    --card "$ui_dir/test-file-only.md"
run_quiet "ui-static-only: --line mode has no files"        --line "$p1_line"
if grep -q "$(printf '\tverify-teeth\twarn\t39-ai-controls.md')" "$ui_dir/.lint-records/39-ai-controls.md.log" 2>/dev/null; then
  printf 'PASS: ui-static-only: run record verdict is warn\n'; pass=$((pass + 1))
else printf 'FAIL: ui-static-only: no warn record under %s\n' "$ui_dir/.lint-records"; fail=$((fail + 1)); fi

printf -- '---- %s passed, %s failed ----\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
