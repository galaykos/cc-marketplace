#!/usr/bin/env bash
# Fixture tests for detect-analyzers.sh. The contract under test is the one the
# expert agents depend on: a project with no analyzer must exit 1 so the caller
# STOPS instead of falling back to a remembered checklist, a configured project
# must name the invocation and the baseline, and a demoted rule must surface as
# a strictness record rather than passing for enforcement.
set -u
DET="$(cd "$(dirname "$0")/.." && pwd)/detect-analyzers.sh"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0; fail=0

run() { bash "$DET" "$1" 2>&1; }

check() { # check <name> <root> <expected-exit> [grep…]
  local name="$1" root="$2" want="$3"; shift 3
  local out rc g
  out=$(run "$root"); rc=$?
  if [ "$rc" -ne "$want" ]; then
    echo "FAIL $name: exit $rc, wanted $want"; echo "$out" | sed 's/^/    /'; fail=$((fail+1)); return
  fi
  for g in "$@"; do
    if ! grep -qF -- "$g" <<<"$out"; then
      echo "FAIL $name: output missing '$g'"; echo "$out" | sed 's/^/    /'; fail=$((fail+1)); return
    fi
  done
  pass=$((pass+1))
}

refute() { # refute <name> <root> <string-that-must-not-appear>
  local name="$1" root="$2" g="$3" out
  out=$(run "$root")
  if grep -qF -- "$g" <<<"$out"; then
    echo "FAIL $name: output should not contain '$g'"; echo "$out" | sed 's/^/    /'; fail=$((fail+1)); return
  fi
  pass=$((pass+1))
}

# --- empty project: the stop signal -----------------------------------------
mkdir -p "$tmp/empty"
check "no analyzer exits 1 so the caller stops" "$tmp/empty" 1 "none no analyzer config found"

# --- a manifest with no analyzer config is still 'none' ---------------------
mkdir -p "$tmp/bare"; echo '{}' > "$tmp/bare/package.json"; echo '{}' > "$tmp/bare/composer.json"
check "manifests alone are not an analyzer" "$tmp/bare" 1 "none"

# --- PHP: level, baseline, and the CI cross-check ---------------------------
php="$tmp/php"; mkdir -p "$php/.github/workflows"
echo '{"require-dev":{"phpstan/phpstan":"^1"}}' > "$php/composer.json"
printf 'parameters:\n    level: 6\n' > "$php/phpstan.neon"
: > "$php/phpstan-baseline.neon"
echo '<?xml version="1.0"?><psalm errorLevel="4"></psalm>' > "$php/psalm.xml"
echo 'run: vendor/bin/phpstan analyse' > "$php/.github/workflows/qa.yml"
check "phpstan config, baseline, level and invocation are reported" "$php" 0 \
  "analyzer php phpstan phpstan.neon phpstan-baseline.neon" \
  "vendor/bin/phpstan analyse" \
  "strictness phpstan level 6"
check "a second configured analyzer is reported too" "$php" 0 \
  "analyzer php psalm psalm.xml" "strictness psalm errorLevel 4"
check "CI names which analyzer is authoritative" "$php" 0 \
  "ci .github/workflows/qa.yml phpstan"
refute "CI cross-check does not claim an unrun tool" "$php" "workflows/qa.yml psalm"

# --- TS: the config-gap evidence --------------------------------------------
ts="$tmp/ts"; mkdir -p "$ts"
echo '{"devDependencies":{"typescript":"^5","eslint":"^9"}}' > "$ts/package.json"
echo '{"compilerOptions":{"strict":false}}' > "$ts/tsconfig.json"
printf 'module.exports={rules:{"react-hooks/exhaustive-deps":"warn"}};\n' > "$ts/.eslintrc.js"
check "a disabled strict flag is reported as a gap, not silence" "$ts" 0 \
  "analyzer ts tsc tsconfig.json" "strictness tsconfig strict false"
check "a demoted rule reports its real severity" "$ts" 0 \
  "strictness eslint react-hooks/exhaustive-deps warn"

# --- strict:true and an absent flag are distinguishable ---------------------
st="$tmp/strict"; mkdir -p "$st"
echo '{"devDependencies":{"typescript":"^5"}}' > "$st/package.json"
echo '{"compilerOptions":{"strict":true}}' > "$st/tsconfig.json"
check "strict true is reported as true" "$st" 0 "strictness tsconfig strict true"
ab="$tmp/absent"; mkdir -p "$ab"
echo '{"devDependencies":{"typescript":"^5"}}' > "$ab/package.json"
echo '{"compilerOptions":{"target":"es2022"}}' > "$ab/tsconfig.json"
check "an absent strict flag is distinct from an explicit false" "$ab" 0 "strictness tsconfig strict absent"

# --- Vue supersession: tsc cannot parse .vue, so vue-tsc must win -----------
vue="$tmp/vue"; mkdir -p "$vue"
echo '{"devDependencies":{"vue-tsc":"^2","typescript":"^5"}}' > "$vue/package.json"
echo '{"compilerOptions":{"strict":true}}' > "$vue/tsconfig.json"
check "vue-tsc supersedes tsc when present" "$vue" 0 "analyzer vue vue-tsc tsconfig.json"
refute "plain tsc is not offered on a vue-tsc project" "$vue" "analyzer ts tsc"

# --- Svelte and Astro: tsc parses neither component format ------------------
# Measured 2026-09-22: a SvelteKit project with svelte-check in devDependencies
# and `npm run check` in CI was reported as `npx tsc --noEmit`, with no ci line
# for the check it actually runs.
sv="$tmp/svelte"; mkdir -p "$sv/.github/workflows"
cat > "$sv/package.json" <<'JSON'
{
  "devDependencies": {"svelte": "^5", "svelte-check": "^4", "typescript": "^5"},
  "scripts": {"check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json"}
}
JSON
echo '{"compilerOptions":{"strict":true}}' > "$sv/tsconfig.json"
echo 'jobs: { ci: { steps: [ { run: npm run check } ] } }' > "$sv/.github/workflows/check.yml"
check "svelte-check supersedes tsc on a Svelte project" "$sv" 0 \
  "analyzer svelte svelte-check tsconfig.json" \
  "npx svelte-check --tsconfig ./tsconfig.json" \
  "ci .github/workflows/check.yml svelte-check via-script"
refute "plain tsc is not offered on a Svelte project" "$sv" "analyzer ts tsc"

ast="$tmp/astro"; mkdir -p "$ast/.github/workflows"
cat > "$ast/package.json" <<'JSON'
{
  "devDependencies": {"astro": "^5", "typescript": "^5"},
  "scripts": {"check": "astro check"}
}
JSON
echo '{"compilerOptions":{"strict":true}}' > "$ast/tsconfig.json"
echo 'jobs: { ci: { steps: [ { run: npm run check } ] } }' > "$ast/.github/workflows/check.yml"
check "astro check supersedes tsc on an Astro project" "$ast" 0 \
  "analyzer astro astro-check tsconfig.json" \
  "npx astro check" \
  "ci .github/workflows/check.yml astro-check via-script"
refute "plain tsc is not offered on an Astro project" "$ast" "analyzer ts tsc"

# --- formatters are reported but never listed as analyzers ------------------
fmt="$tmp/fmt"; mkdir -p "$fmt"
echo '{"devDependencies":{"prettier":"^3","eslint":"^9"}}' > "$fmt/package.json"
echo '{}' > "$fmt/.prettierrc"
echo 'module.exports={};' > "$fmt/.eslintrc.js"
check "a formatter is reported on its own line" "$fmt" 0 "formatter js prettier .prettierrc"
refute "a formatter is not promoted to an analyzer" "$fmt" "analyzer js prettier"

# --- CI wrapper resolution: the case a real repo produced --------------------
# Measured 2026-09-15 on a Laravel + Inertia project: CI ran `composer ci:check`,
# which chains through npm scripts to phpstan, tsc, eslint and prettier. Grepping
# the workflow alone reported none of them and would have told the reader their
# analyzers were unenforced — the exact inversion this script exists to prevent.
wrap="$tmp/wrap"; mkdir -p "$wrap/.github/workflows"
cat > "$wrap/composer.json" <<'JSON'
{
  "require-dev": {"phpstan/phpstan": "^1"},
  "scripts": {
    "ci:check": [
      "npm run lint:check",
      "npm run types:check",
      "@test"
    ],
    "lint:check": ["pint --parallel --test"],
    "types:check": ["phpstan analyse --memory-limit=1G"],
    "test": ["@lint:check", "@types:check"]
  }
}
JSON
cat > "$wrap/package.json" <<'JSON'
{
  "devDependencies": {"typescript": "^5", "eslint": "^9"},
  "scripts": {
    "lint:check": "eslint .",
    "types:check": "tsc --noEmit"
  }
}
JSON
printf 'parameters:\n    level: 7\n' > "$wrap/phpstan.neon"
echo '{"compilerOptions":{"strict":true}}' > "$wrap/tsconfig.json"
echo 'module.exports={};' > "$wrap/.eslintrc.js"
echo 'jobs: { ci: { steps: [ { run: composer ci:check } ] } }' > "$wrap/.github/workflows/tests.yml"

check "a tool two script levels below the workflow is found" "$wrap" 0 \
  "ci .github/workflows/tests.yml phpstan via-script"
check "an npm script referenced from a composer script resolves" "$wrap" 0 \
  "ci .github/workflows/tests.yml tsc via-script" \
  "ci .github/workflows/tests.yml eslint via-script"
check "a composer @self reference resolves" "$wrap" 0 \
  "ci .github/workflows/tests.yml pint via-script"

# A tool named straight in the workflow is labelled direct, not via-script.
dir="$tmp/direct"; mkdir -p "$dir/.github/workflows"
echo '{"require-dev":{"phpstan/phpstan":"^1"}}' > "$dir/composer.json"
printf 'parameters:\n    level: 3\n' > "$dir/phpstan.neon"
echo 'run: vendor/bin/phpstan analyse' > "$dir/.github/workflows/qa.yml"
check "a directly named tool is labelled direct" "$dir" 0 \
  "ci .github/workflows/qa.yml phpstan direct"
refute "a direct hit is not also reported as via-script" "$dir" "phpstan via-script"

# An unreferenced analyzer stays unreported: absence of a ci line must still mean
# something, or the resolution above would make every tool look enforced.
un="$tmp/unenforced"; mkdir -p "$un/.github/workflows"
echo '{"require-dev":{"vimeo/psalm":"^5"}}' > "$un/composer.json"
echo '<?xml version="1.0"?><psalm errorLevel="2"></psalm>' > "$un/psalm.xml"
echo 'jobs: { ci: { steps: [ { run: echo hello } ] } }' > "$un/.github/workflows/noop.yml"
check "an analyzer no workflow reaches is reported as configured" "$un" 0 "analyzer php psalm"
refute "an analyzer no workflow reaches gets no ci record" "$un" "ci .github/workflows/noop.yml psalm"

# --- JSONC: commented-out flags must NOT read as enabled ---------------------
# Measured 2026-09-15 on a real project. tsc scaffolds a tsconfig that is ~100
# lines of commented-out flags with explanatory text; grepping it raw reported
# noUncheckedIndexedAccess and exactOptionalPropertyTypes as ON when
# `tsc --showConfig` resolves both as absent. A false "covered" is the worst
# output this script can produce, because naming what the checker cannot see IS
# the deliverable.
jsonc="$tmp/jsonc"; mkdir -p "$jsonc"
echo '{"devDependencies":{"typescript":"^5"}}' > "$jsonc/package.json"
cat > "$jsonc/tsconfig.json" <<'JSON'
{
    "compilerOptions": {
        "strict": true /* Enable all strict type-checking options. */,
        // "strictNullChecks": true,                  /* take null into account. */
        // "exactOptionalPropertyTypes": true,        /* optional props as written. */
        // "noUncheckedIndexedAccess": true,          /* add undefined on index access. */
        "skipLibCheck": true
    }
}
JSON
check "a commented-out flag is reported absent, not enabled" "$jsonc" 0 \
  "strictness tsconfig noUncheckedIndexedAccess absent" \
  "strictness tsconfig exactOptionalPropertyTypes absent"
refute "a commented-out flag is never reported true" "$jsonc" "noUncheckedIndexedAccess true"
check "an inline block comment does not hide the real value" "$jsonc" 0 \
  "strictness tsconfig strict true" "strictness tsconfig skipLibCheck true"

# --- strict implication: covered-by-strict is not the same as absent ---------
check "a flag strict turns on is labelled true-via-strict" "$jsonc" 0 \
  "strictness tsconfig strictNullChecks true-via-strict"
refute "a strict-implied flag is not reported absent" "$jsonc" "strictNullChecks absent"

# With strict off, the same implied flag must read absent, not via-strict.
nostrict="$tmp/nostrict"; mkdir -p "$nostrict"
echo '{"devDependencies":{"typescript":"^5"}}' > "$nostrict/package.json"
echo '{"compilerOptions":{"strict":false}}' > "$nostrict/tsconfig.json"
check "with strict off, an implied flag reads absent" "$nostrict" 0 \
  "strictness tsconfig strict false" "strictness tsconfig strictNullChecks absent"
refute "with strict off, nothing claims via-strict" "$nostrict" "true-via-strict"

# An explicit setting always wins over the implication.
expl="$tmp/explicit"; mkdir -p "$expl"
echo '{"devDependencies":{"typescript":"^5"}}' > "$expl/package.json"
echo '{"compilerOptions":{"strict":true,"strictNullChecks":false}}' > "$expl/tsconfig.json"
check "an explicit false overrides the strict implication" "$expl" 0 \
  "strictness tsconfig strictNullChecks false"

# --- extends is disclosed, because grep cannot follow it --------------------
ext="$tmp/extends"; mkdir -p "$ext"
echo '{"devDependencies":{"typescript":"^5"}}' > "$ext/package.json"
echo '{"extends":"./tsconfig.base.json","compilerOptions":{"strict":true}}' > "$ext/tsconfig.json"
check "an extends chain is disclosed as a limitation" "$ext" 0 \
  "strictness tsconfig extends present"

# --- the printed eslint invocation must actually run ------------------------
# ESLint 9 removed the `unix` formatter from core ("no longer part of core
# ESLint"), so the first version of this script printed a command that exits
# non-zero on every ESLint 9 project — a detector whose output cannot be run.
fmtck="$tmp/fmtck"; mkdir -p "$fmtck"
echo '{"devDependencies":{"eslint":"^9"}}' > "$fmtck/package.json"
echo 'module.exports={};' > "$fmtck/.eslintrc.js"
refute "the eslint invocation does not use the removed unix formatter" "$fmtck" "--format=unix"
check "the eslint invocation is version-portable" "$fmtck" 0 "'npx eslint .'"

# --- usage ------------------------------------------------------------------
out=$(bash "$DET" "$tmp/does-not-exist" 2>&1); rc=$?
if [ "$rc" -eq 2 ] && grep -qF 'not a directory' <<<"$out"; then
  pass=$((pass+1))
else
  echo "FAIL missing root exits 2: exit $rc"; fail=$((fail+1))
fi

echo "detect-analyzers: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
