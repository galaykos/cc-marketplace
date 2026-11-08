#!/usr/bin/env bash
# Fixtures for plugins/testing/scripts/mutation-lens.sh, with fake Infection, Stryker and
# mutmut binaries; no real tool is needed. Each fake logs the arguments it was given, so a
# case can check the scope the lens passed, and prints that tool's own report shape.
# The shapes were copied from real runs (Infection 0.35.9, Stryker 10.1.1, mutmut 3.8.1).
set -u
cd "$(dirname "$0")/../../../.." || exit 1
S="$(pwd)/plugins/testing/scripts/mutation-lens.sh"
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
BASEPATH="/usr/bin:/bin"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; rc=1; }
expect_rc() { if [ "$2" = "$3" ]; then pass "$1 (rc=$3)"; else fail "$1 — want rc=$2, got $3"; fi; }
has() { if printf '%s' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1 — missing: $3"; printf '%s\n' "$2" | sed 's/^/      | /'; fi; }

# An empty repo on an unborn main, ignoring the tools' own dirs; each case adds its files and commits.
mkrepo() {
  local r="$FX/$1"; mkdir -p "$r"
  git -C "$r" init -q; git -C "$r" checkout -q -b main
  git -C "$r" config user.email t@example.invalid; git -C "$r" config user.name t
  printf 'vendor/\nnode_modules/\nmutants/\n' > "$r/.gitignore"
  printf '%s' "$r"
}
commit() { git -C "$1" add -A; git -C "$1" commit -qm "$2"; }

# --- Infection ------------------------------------------------------------------
r=$(mkrepo inf); mkdir -p "$r/src" "$r/tests" "$r/vendor/bin"
printf '{}\n' > "$r/composer.json"; printf '{ "source": { "directories": ["src"] } }\n' > "$r/infection.json5"
printf '<?php\n' > "$r/src/Calc.php"; printf '<?php\n' > "$r/tests/CalcTest.php"; printf '# toy\n' > "$r/README.md"
commit "$r" init; git -C "$r" checkout -q -b feat
printf '<?php\n// changed\n' > "$r/src/Calc.php"; commit "$r" change
cat > "$r/vendor/bin/infection" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_LOG"
txt=""; sj=""
for a in "$@"; do case "$a" in --logger-text=*) txt=${a#*=} ;; --logger-summary-json=*) sj=${a#*=} ;; esac; done
case "$FAKE_MODE" in
  crash) echo "In Foo.php line 1: Boom"; exit 1 ;;
  hang) exec sleep 4323 ;;
  graceful) trap 'sleep 1; echo restored > "$FAKE_MARK"; exit 130' INT; while :; do sleep 0.2; done ;;
  nochange) printf ' [OK] Could not find any modified files in the configured sources for the git\n      filter "AM" and the base "abc".\n'; exit 0 ;;
esac
{
  printf 'Escaped mutants:\n================\n\n'
  if [ "$FAKE_MODE" = survivor ]; then
    printf '1) %s/src/Calc.php:14    [M] GreaterThan [ID] 961971f6\n\n@@ @@\n     {\n-        return $n > 0;\n+        return $n >= 0;\n     }\n\n\n' "$PWD"
  fi
  printf 'Timed Out mutants:\n==================\n\nNot Covered mutants:\n====================\n\n'
  if [ "$FAKE_MODE" = survivor ]; then
    printf '1) %s/src/Calc.php:19    [M] IncrementInteger [ID] e9e0ab9f\n\n@@ @@\n-        return $n * 2;\n+        return $n * 3;\n     }\n' "$PWD"
  fi
} > "$txt"
[ "$FAKE_MODE" = survivor ] && printf '{"stats":{"msi":33.33,"escapedCount":1}}' > "$sj" || printf '{"stats":{"msi":100,"escapedCount":0}}' > "$sj"
exit 0
EOF
chmod +x "$r/vendor/bin/infection"
mb=$(git -C "$r" merge-base HEAD main)

export FAKE_LOG="$FX/inf.log"; : > "$FAKE_LOG"
out=$(cd "$r" && FAKE_MODE=survivor PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "Infection survivors exit 1" 1 "$got"
has "Infection detected from infection.json5 + vendor/bin/infection" "$out" "== Infection (vendor/bin/infection, infection.json5) =="
has "Infection scoped by its own git-diff flags to the merge-base" "$(cat "$FAKE_LOG")" "--git-diff-filter=AM --git-diff-base=$mb"
has "Infection asked for uncovered mutants too" "$(cat "$FAKE_LOG")" "--with-uncovered"
has "an escaped mutant parsed as path:line — mutator — what survived" "$out" 'src/Calc.php:14 — GreaterThan — `return $n > 0;` → `return $n >= 0;`'
has "a not-covered mutant is reported and labelled" "$out" 'src/Calc.php:19 — IncrementInteger — `return $n * 2;` → `return $n * 3;` — no test covers this line'
has "Infection's MSI is reported" "$out" "score: MSI 33.33%"

out=$(cd "$r" && FAKE_MODE=clean PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "Infection with every mutant killed exits 0" 0 "$got"
has "a clean run says none survived" "$out" "surviving mutants: none"

out=$(cd "$r" && FAKE_MODE=nochange PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "Infection finding no changed source exits 0" 0 "$got"
has "Infection's own no-files message is relayed" "$out" "no mutants in scope: Could not find any modified files"

(cd "$r" && FAKE_MODE=crash PATH="$BASEPATH" bash "$S" >/dev/null 2>&1); expect_rc "a tool that crashes with no report exits 4" 4 "$?"

start=$(date +%s)
out=$(cd "$r" && FAKE_MODE=hang PATH="$BASEPATH" bash "$S" --max-seconds 2 2>&1); got=$?
expect_rc "a tool past --max-seconds exits 4" 4 "$got"
has "the cap is named" "$out" "ran past --max-seconds 2"
[ $(( $(date +%s) - start )) -lt 30 ] && pass "the hung tool was cut at the cap" || fail "the cap did not cut the run"
pgrep -f '^sleep 4323' >/dev/null && fail "the hung tool survived the cap" || pass "the hung tool's process group was killed"
has "after the cap it names the files to git diff" "$out" "check: git diff -- src/Calc.php"

# At the cap, and on an interrupt, the tool gets SIGINT and time to clean up before any SIGKILL.
export FAKE_MARK="$FX/restored"; rm -f "$FAKE_MARK"
out=$(cd "$r" && FAKE_MODE=graceful PATH="$BASEPATH" bash "$S" --max-seconds 2 2>&1); got=$?
expect_rc "a tool stopped at the cap exits 4" 4 "$got"
[ -s "$FAKE_MARK" ] && pass "at the cap the tool got SIGINT and its cleanup ran" || fail "the tool was killed before its SIGINT cleanup"
rm -f "$FAKE_MARK"; : > "$FAKE_LOG"
set -m # job control: an async command of a shell without it starts with SIGINT ignored, and so would the tool
(cd "$r" && FAKE_MODE=graceful PATH="$BASEPATH" exec bash "$S" --max-seconds 120) > "$FX/int.out" 2>&1 &
pid=$!
set +m
for _ in $(seq 1 100); do [ -s "$FAKE_LOG" ] && break; sleep 0.1; done
sleep 0.3; kill -TERM "$pid"; wait "$pid"; got=$?
expect_rc "an interrupted lens exits 4" 4 "$got"
[ -s "$FAKE_MARK" ] && pass "on an interrupt the tool got SIGINT and its cleanup ran" || fail "the interrupt killed the tool before its cleanup"
has "an interrupted run names the files to git diff" "$(cat "$FX/int.out")" "check: git diff -- src/Calc.php"

# Nearest silent input: only a non-PHP file changed, so Infection is never started.
git -C "$r" checkout -q -b docs main; printf '# toy, reworded\n' > "$r/README.md"; commit "$r" docs
: > "$FAKE_LOG"
out=$(cd "$r" && FAKE_MODE=survivor PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "no changed .php file exits 0" 0 "$got"
has "it says there is nothing to mutate" "$out" "no changed .php file vs the base: nothing to mutate"
[ -s "$FAKE_LOG" ] && fail "Infection ran with nothing to mutate" || pass "Infection was not started"

out=$(cd "$r" && PATH="$BASEPATH" bash "$S" --base HEAD 2>&1); got=$?
expect_rc "an explicit --base HEAD with a clean tree exits 0" 0 "$got"

# --- Stryker --------------------------------------------------------------------
r=$(mkrepo str); mkdir -p "$r/src" "$r/node_modules/.bin"
printf '{ "devDependencies": { "@stryker-mutator/core": "10.1.1" } }\n' > "$r/package.json"
printf 'export const a = 1;\n' > "$r/src/a.ts"; printf 'test\n' > "$r/src/a.test.ts"; printf 'export const b = 2;\n' > "$r/src/b.ts"; printf '{}\n' > "$r/vite.config.ts"
commit "$r" init; git -C "$r" checkout -q -b feat
printf 'export const a = 3;\n' > "$r/src/a.ts"; printf 'test 2\n' > "$r/src/a.test.ts"; printf '{ }\n' > "$r/vite.config.ts"
cat > "$r/node_modules/.bin/stryker" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_LOG"
printf '\033[32mAll tests\033[39m\n\n'
printf '[Survived] ConditionalExpression\n\033[36msrc/a.ts\033[39m:\033[33m3\033[39m:\033[33m10\033[39m\n-     return n > 0;\n+     return true;\nTests ran:\n    a works\n\n'
printf '[NoCoverage] ArithmeticOperator\nsrc/a.ts:7:12\n-     return x * 2;\n+     return x / 2;\n\n'
printf -- '----------|------------------|----------|\n          | %% Mutation score |          |\nFile      |  total | covered | # killed |\n'
printf 'All files |  66.67 |   80.00 |        4 |\n a.ts     |  66.67 |   80.00 |        4 |\n'
EOF
chmod +x "$r/node_modules/.bin/stryker"
export FAKE_LOG="$FX/str.log"; : > "$FAKE_LOG"
out=$(cd "$r" && PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "Stryker survivors exit 1" 1 "$got"
has "Stryker detected from the package.json devDependency" "$out" "== Stryker (node_modules/.bin/stryker, package.json) =="
has "Stryker mutates only the changed source file: no test, config or unchanged file" "$(cat "$FAKE_LOG")" "run --mutate src/a.ts --reporters clear-text"
has "a Stryker survivor parsed through its colour codes" "$out" 'src/a.ts:3 — ConditionalExpression — `return n > 0;` → `return true;`'
has "a NoCoverage mutant is labelled" "$out" 'src/a.ts:7 — ArithmeticOperator — `return x * 2;` → `return x / 2;` — no test covers this line'
has "Stryker's score is the All files row" "$out" "score: 66.67%"

# A moved and edited file is in scope under its new name (renames are not detected, so it reads as added).
r=$(mkrepo strmv); mkdir -p "$r/src" "$r/node_modules/.bin"
printf '{ "devDependencies": { "@stryker-mutator/core": "10.1.1" } }\n' > "$r/package.json"
printf 'export const b = 2;\nexport const c = 3;\n' > "$r/src/b.ts"; commit "$r" init; git -C "$r" checkout -q -b feat
git -C "$r" mv src/b.ts src/moved.ts; printf 'export const d = 4;\n' >> "$r/src/moved.ts"; commit "$r" move
cp "$FX/str/node_modules/.bin/stryker" "$r/node_modules/.bin/stryker"
: > "$FAKE_LOG"
(cd "$r" && PATH="$BASEPATH" bash "$S" >/dev/null 2>&1)
has "a moved and edited file is mutated under its new name" "$(cat "$FAKE_LOG")" "run --mutate src/moved.ts --reporters clear-text"

# Stryker with inPlace: true mutates the user's sources, so the lens refuses it; inPlace false runs.
r=$(mkrepo strinplace); mkdir -p "$r/src" "$r/node_modules/.bin"
printf '{ "devDependencies": { "@stryker-mutator/core": "10.1.1" } }\n' > "$r/package.json"
printf '{ "inPlace": true }\n' > "$r/stryker.config.json"; printf 'export const a = 1;\n' > "$r/src/a.ts"
commit "$r" init; git -C "$r" checkout -q -b feat; printf 'export const a = 2;\n' > "$r/src/a.ts"
cp "$FX/str/node_modules/.bin/stryker" "$r/node_modules/.bin/stryker"
: > "$FAKE_LOG"
out=$(cd "$r" && PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "Stryker with inPlace: true is refused: exit 3" 3 "$got"
has "the refusal names inPlace" "$out" "sets inPlace: true, so it mutates your source files"
[ -s "$FAKE_LOG" ] && fail "Stryker ran with inPlace: true" || pass "Stryker was not started with inPlace: true"
printf '{ "inPlace": false }\n' > "$r/stryker.config.json"
(cd "$r" && PATH="$BASEPATH" bash "$S" >/dev/null 2>&1); got=$?
expect_rc "Stryker with inPlace: false runs (survivors, exit 1)" 1 "$got"

# --- mutmut 3 -------------------------------------------------------------------
r=$(mkrepo mm); mkdir -p "$r/src/pkg" "$r/tests" "$FX/mmbin"
printf '[project]\nname = "pkg"\n\n[tool.mutmut]\nsource_paths = ["src/"]\n' > "$r/pyproject.toml"
printf 'def add(a, b):\n    return a + b\n' > "$r/src/pkg/calc.py"; printf 'def test_x(): pass\n' > "$r/tests/test_calc.py"
commit "$r" init; git -C "$r" checkout -q -b feat
printf 'def add(a, b):\n    return a + b\n\n\ndef is_positive(n):\n    return n > 0\n' > "$r/src/pkg/calc.py"; printf 'def test_y(): pass\n' > "$r/tests/test_calc.py"
cat > "$FX/mmbin/mutmut" <<'EOF'
#!/bin/bash
case "$1" in
  --version) [ "${FAKE_MODE:-}" = v2 ] && { echo "Error: No such option: --version" >&2; exit 2; }; echo "mutmut, version 3.8.1"; exit 0 ;;
  run) printf '%s\n' "$*" >> "$FAKE_LOG"
       printf '\r⠋ Generating mutants\r    done in 12ms\n\nMutant results\n--------------\n'
       printf '🎉 pkg.calc.x_add__mutmut_1\n🙁 pkg.calc.x_is_positive__mutmut_1\n🫥 pkg.calc.x_is_positive__mutmut_2\n🎉 pkg.calc.x_is_positive__mutmut_3\n\n' ;;
  show) case "$2" in
          *_1) printf '# %s: survived\n--- src/pkg/calc.py\n+++ src/pkg/calc.py\n@@ -1,2 +1,2 @@\n def is_positive(n):\n-    return n > 0\n+    return n >= 0\n' "$2" ;;
          *) printf '# %s: no tests\n--- src/pkg/calc.py\n+++ src/pkg/calc.py\n@@ -1,2 +1,2 @@\n def is_positive(n):\n-    return n > 0\n+    return n > 1\n' "$2" ;;
        esac ;;
esac
EOF
chmod +x "$FX/mmbin/mutmut"
export FAKE_LOG="$FX/mm.log"; : > "$FAKE_LOG"
out=$(cd "$r" && PATH="$FX/mmbin:$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "mutmut survivors exit 1" 1 "$got"
has "mutmut detected from [tool.mutmut]" "$out" "== mutmut (pyproject.toml [tool.mutmut]) =="
if [ "$(cat "$FAKE_LOG")" = "run pkg.calc.*" ]; then pass "mutmut is scoped to the changed module, src/ stripped and tests left out"
else fail "mutmut got the wrong scope: $(cat "$FAKE_LOG")"; fi
has "a mutmut survivor lands on its file line, not the function-relative one" "$out" 'src/pkg/calc.py:6 — pkg.calc.x_is_positive__mutmut_1 — `return n > 0` → `return n >= 0`'
has "a mutmut no-tests mutant is labelled" "$out" "pkg.calc.x_is_positive__mutmut_2 — \`return n > 0\` → \`return n > 1\` — no test covers this line"
has "mutmut's score uses its badge formula" "$out" "score: 50.0%"

out=$(cd "$r" && FAKE_MODE=v2 PATH="$FX/mmbin:$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "a mutmut without a 3.x version is not run: exit 3" 3 "$got"
has "the mutmut 2 case says how to run it by hand" "$out" "mutmut run --paths-to-mutate"

# Nearest silent input: a Python project with mutmut on PATH but no [tool.mutmut] table is not run.
r=$(mkrepo mmnocfg); mkdir -p "$r/src/pkg"; printf '[project]\nname = "pkg"\n' > "$r/pyproject.toml"
printf 'def f():\n    return 1\n' > "$r/src/pkg/m.py"; commit "$r" init; git -C "$r" checkout -q -b feat
printf 'def f():\n    return 2\n' > "$r/src/pkg/m.py"
: > "$FAKE_LOG"
out=$(cd "$r" && PATH="$FX/mmbin:$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "mutmut on PATH without [tool.mutmut]: exit 3" 3 "$got"
has "it says the table is missing" "$out" "has no [tool.mutmut] table"
[ -s "$FAKE_LOG" ] && fail "mutmut ran without its config" || pass "mutmut was not started without its config"

# --- no tool: exit 3, naming the config that would enable one ---------------------
r=$(mkrepo none); printf '{}\n' > "$r/composer.json"; commit "$r" init
out=$(cd "$r" && PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "a PHP project with no mutation tool exits 3" 3 "$got"
has "it names the Infection config that would enable one" "$out" "PHP: infection.json5 plus \`composer require --dev infection/infection\`"
has "it says it never installs" "$out" "never installs a tool"

r=$(mkrepo cfgonly); printf '{}\n' > "$r/infection.json5"; commit "$r" init
out=$(cd "$r" && PATH="$BASEPATH" bash "$S" 2>&1); got=$?
expect_rc "Infection configured but not installed exits 3" 3 "$got"
has "it says the config exists but the binary is missing" "$out" "Infection is configured (infection.json5) but not installed"

# --- usage ----------------------------------------------------------------------
ec() { local label="$1" want="$2"; shift 2; (cd "$FX/inf" && PATH="$BASEPATH" "$@" >/dev/null 2>&1); expect_rc "$label" "$want" "$?"; }
ec "an unknown flag is a usage error" 2 bash "$S" --bogus
ec "--max-seconds 0 is a usage error" 2 bash "$S" --max-seconds 0
ec "a --base that is not a commit is a usage error" 2 bash "$S" --base no-such-ref
mkdir -p "$FX/nogit"; (cd "$FX/nogit" && GIT_CEILING_DIRECTORIES="$FX" PATH="$BASEPATH" bash "$S" >/dev/null 2>&1)
expect_rc "outside a git work tree is a usage error" 2 "$?"

[ "$rc" -eq 0 ] && echo "All mutation-lens fixtures passed."
exit "$rc"
