#!/usr/bin/env bash
# Fixtures for plugins/code-review/scripts/debt-scan.sh. Run by CI via the
# plugins/*/scripts/__tests__/*.test.sh glob.
#
# The ratchet, not the count, is what these lock. A scanner that reports numbers
# is a report; a scanner that fails when a number goes UP and offers an explicit
# way to accept the rise is a gate. Both halves are asserted, plus the
# no-baseline case — silently passing without a baseline would make the gate a
# no-op on every repo that never ran --update-baseline, which is all of them on
# day one.
set -u
SCAN="$(cd "$(dirname "$0")/.." && pwd)/debt-scan.sh"
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/src"

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

expect() { # label want_rc args...
  local label="$1" want="$2"; shift 2
  bash "$SCAN" "$@" >/dev/null 2>&1; local got=$?
  if [ "$got" = "$want" ]; then echo "PASS: $label (rc=$got)"
  else echo "FAIL: $label — want rc=$want, got $got"; rc=1; fi
}

cat > "$FX/src/a.ts" <<'EOF'
// TODO: fix later
// eslint-disable-next-line no-console
console.log(1)
it.skip('broken', () => {})
/** @deprecated use b() */
export function a() {}
if (flags.newCheckout === true) {}
// shortcut: global lock; revisit when throughput matters
EOF

# --check with no baseline must NOT pass — a ratchet with nothing to compare
# against is not a ratchet, and exiting 0 there would make it invisible.
expect "check with no baseline exits 3" 3 --dir "$FX" --baseline "$FX/none.json" --check

expect "update-baseline succeeds" 0 --dir "$FX" --baseline "$FX/base.json" --update-baseline

# the seeded fixture holds exactly one marker per category
for k in suppressions skipped_tests bare_markers deprecated_refs feature_flags shortcuts; do
  v=$(jq -r --arg k "$k" '.[$k] // "missing"' "$FX/base.json")
  if [ "$v" = 1 ]; then
    echo "PASS: category $k counted once ($v)"
  else
    echo "FAIL: category $k — want 1, got $v"; rc=1
  fi
done

expect "unchanged tree passes --check" 0 --dir "$FX" --baseline "$FX/base.json" --check

echo '// FIXME: another one' >> "$FX/src/a.ts"
expect "growth fails --check" 2 --dir "$FX" --baseline "$FX/base.json" --check

# PER-RUNNER skip coverage, asserted in ISOLATION. The aggregate check above is
# satisfied by `it.skip` alone, which is exactly how Pest's chained `->skip()` went
# uncounted: one JS fixture made skipped_tests non-zero and nothing asked whether a
# PHP suite's skips were visible at all. Each runner therefore gets its own tree.
skip_only() { # skip_only <label> <filename> <body>
  local d; d=$(mktemp -d)
  printf '%s\n' "$3" > "$d/$2"
  bash "$SCAN" --dir "$d" --baseline "$d/b.json" --update-baseline >/dev/null 2>&1
  local n; n=$(jq -r '.skipped_tests // 0' "$d/b.json" 2>/dev/null)
  if [ "${n:-0}" -gt 0 ] 2>/dev/null; then echo "PASS: skip form detected — $1 ($n)"
  else echo "FAIL: skip form NOT detected — $1 (got ${n:-0})"; rc=1; fi
  rm -rf "$d"
}

skip_only "Pest ->skip()"      t.php  "it('a', function () {})->skip('flaky');"
skip_only "Pest ->todo()"      u.php  "it('b', function () {})->todo();"
skip_only "PHPUnit markSkipped" v.php '$this->markTestSkipped("wip");'
skip_only "vitest it.skip"     w.ts   "it.skip('c', () => {})"
skip_only "pytest mark"        x.py   '@pytest.mark.skip'
skip_only "go t.Skip"          y.go   't.Skip("later")'
skip_only "JUnit @Disabled"    z.java '@Disabled'

expect "update-baseline accepts the growth" 0 --dir "$FX" --baseline "$FX/base.json" --update-baseline
expect "accepted growth then passes" 0 --dir "$FX" --baseline "$FX/base.json" --check

# Paying debt down must never fail the build — a ratchet that punishes improvement
# is a ratchet nobody runs twice.
: > "$FX/src/a.ts"
expect "removing debt passes --check" 0 --dir "$FX" --baseline "$FX/base.json" --check

# Vendored trees are somebody else's debt; counting them makes the number move on
# a dependency update, which is exactly the noise a ratchet cannot tolerate.
mkdir -p "$FX/node_modules/pkg"
printf '// TODO vendored\n// @ts-ignore\n' > "$FX/node_modules/pkg/index.ts"
expect "node_modules excluded" 0 --dir "$FX" --baseline "$FX/base.json" --check

expect "missing directory exits 3" 3 --dir "$FX/nope" --check

# Shortcut cases run after every scan of $FX itself, so their trees stay out of its counts.
is() { # label got want
  if [ "$2" = "$3" ]; then echo "PASS: $1 ($2)"
  else echo "FAIL: $1 — want $3, got $2"; rc=1; fi
}
shortcuts_in() { # dir -> the shortcuts count its fresh baseline records
  bash "$SCAN" --dir "$1" --baseline "$1/b.json" --update-baseline >/dev/null 2>&1
  jq -r '.shortcuts // "missing"' "$1/b.json" 2>/dev/null
}

SC="$FX/sc"; mkdir -p "$SC"
printf '%s\n' '// shortcut: global lock; revisit when throughput matters' '// shortcut: no pool; REVISIT WHEN load grows' > "$SC/a.ts"
echo 'retries = 0  # shortcut: no backoff' > "$SC/b.py"
printf '%s\n' '/* shortcut: a */' '<!-- shortcut: b -->' > "$SC/c.vue"
is "shortcut markers counted" "$(shortcuts_in "$SC")" 5

out=$(bash "$SCAN" --dir "$SC" --baseline "$SC/b.json" 2>&1)
is "no-trigger list names a marker without '; revisit when'" "$(printf '%s\n' "$out" | grep -c 'b.py:1  shortcut: no backoff$')" 1
is "no-trigger list leaves out a marker with '; revisit when', in any case" "$(printf '%s\n' "$out" | grep -cE 'global lock|no pool')" 0

jq 'del(.shortcuts)' "$SC/b.json" > "$SC/old.json"
out=$(bash "$SCAN" --dir "$SC" --baseline "$SC/old.json" --check 2>&1); got=$?
is "baseline without shortcuts passes --check and prints -" \
  "$got $(printf '%s\n' "$out" | grep -cE '^shortcuts +5 +- +-$')" "0 1"

echo '// shortcut: skip the cache' >> "$SC/a.ts"
expect "growth in shortcuts fails --check" 2 --dir "$SC" --baseline "$SC/b.json" --check

PR="$FX/prose"; mkdir -p "$PR"
echo 'const tip = "Press the shortcut: Ctrl+K";' > "$PR/a.ts"
is "shortcut: in prose outside a comment not counted" "$(shortcuts_in "$PR")" 0

ED="$FX/edge"; mkdir -p "$ED/sub:12:dir"
echo '// shortcut: c' > "$ED/sub:12:dir/a.ts"
printf '// shortcut: d\n\000\n' > "$ED/nul.ts"
echo 'const s = "shortcut: a; revisit when b"; // shortcut: e' > "$ED/str.ts"
out=$(bash "$SCAN" --dir "$ED" --baseline "$ED/b.json" 2>&1)
is "no-trigger list keeps a path holding :12: whole" "$(printf '%s\n' "$out" | grep -c '/sub:12:dir/a.ts:1  shortcut: c$')" 1
is "no-trigger list reads a file holding a NUL byte" "$(printf '%s\n' "$out" | grep -c '/nul.ts:1  shortcut: d$')" 1
is "trigger check starts at the comment-led marker, not a string before it" "$(printf '%s\n' "$out" | grep -c '/str.ts:1  shortcut: e$')" 1
is "shortcuts count includes the marker in a file holding a NUL byte" "$(shortcuts_in "$ED")" 3

MN="$FX/midnul"; mkdir -p "$MN"
printf '// shortcut: f\000 // shortcut: g\n' > "$MN/a.ts"
# GNU grep splits a line at a NUL unless -a is given; BSD grep does not, so only CI catches a lost -a here.
is "shortcuts count keeps a NUL mid-line as one line" "$(shortcuts_in "$MN")" 1

LG="$FX/long"; mkdir -p "$LG"
awk 'BEGIN { for (i = 0; i < 41; i++) { printf "// shortcut: "; for (j = 0; j < 130; j++) printf "x"; print "" } }' > "$LG/a.ts"
out=$(bash "$SCAN" --dir "$LG" --baseline "$LG/b.json" 2>&1)
is "no-trigger list keeps 40 entries cut at 120 characters" "$(printf '%s\n' "$out" | grep -cE 'shortcut: x{110}$')" 40
is "no-trigger list counts the rest as +N more" "$(printf '%s\n' "$out" | grep -c '^  +1 more$')" 1

if command -v git >/dev/null 2>&1; then
  AG="$FX/age"; mkdir -p "$AG"
  echo '// TODO: plain marker' > "$AG/a.ts"
  printf '// TODO: nul marker\n\000\n' > "$AG/nul.ts"
  printf '\211PNG\000\001 XXX\002\003 junk\n' > "$AG/img.png"
  git -C "$AG" init -q && git -C "$AG" add . \
    && git -C "$AG" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -qm f --no-verify
  out=$(bash "$SCAN" --dir "$AG" --baseline "$AG/b.json" --age 2>&1)
  is "--age lists the marker in a file holding a NUL byte" "$(printf '%s\n' "$out" | grep -c ' TODO: nul marker$')" 1
  is "--age adds no row for a binary file whose bytes spell XXX" "$(printf '%s\n' "$out" | grep -c 'XXX')" 0
  utf8=$(locale -a 2>/dev/null | grep -ixE 'en_US\.utf-?8|C\.utf-?8' | head -n 1)
  if [ -n "$utf8" ]; then
    printf '// TODO: bad byte \000\377\n' > "$AG/bad.ts"
    out=$(LC_ALL=$utf8 bash "$SCAN" --dir "$AG" --baseline "$AG/b.json" --age 2>&1)
    is "--age under $utf8 still lists markers beside a line holding a NUL and a non-UTF-8 byte" "$(printf '%s\n' "$out" | grep -c ' TODO: plain marker$')" 1
  else
    echo "SKIP: --age under a UTF-8 locale — locale -a lists none of en_US.UTF-8, en_US.utf8, C.UTF-8, C.utf8"
  fi
else
  echo "SKIP: git not found — --age cases"
fi

[ "$rc" -eq 0 ] && echo "All debt-scan fixtures passed."
exit "$rc"
