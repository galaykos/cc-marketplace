#!/usr/bin/env bash
# Tests plugins/craft-layer/template/craft-gates/divergence.mjs and contrast.mjs.
#
# Picked up automatically by the repo's "Plugin author-time lint + harness tests"
# CI step, which globs plugins/*/scripts/__tests__/*.test.sh.
#
# WHY THIS FILE EXISTS. craft-layer shipped 1,321 lines of gate code and seven
# control fixtures with nothing that ran them. The gates were `recorded` tier
# wearing a `gate` badge — the exact failure CLAUDE.md's has-teeth convention
# forbids, in the plugin whose own doctrine names it. Every fixture pair below
# was authored as a control (defective / clean, same copy, one variable changed)
# and then verified BY HAND, once, by whoever wrote it. This makes them execute.
#
# Four sections:
#   1. FIXTURE CONTROLS — each defective fixture must FAIL the check it was
#      built to trip, and its clean twin must PASS. A gate that greens both is
#      measuring nothing; a gate that reds both is a gate nobody will keep on.
#   2. COVERAGE HONESTY — the terminator must not print an unqualified green
#      when every assertion SKIPped. This is the assertion that would have
#      caught the "OK: the build clears every divergence assertion" printed over
#      1-of-9 graded.
#   3. NOT-MEASURED — a missing token source must exit 2, per the file's own
#      header contract. contrast.mjs must not print a green having resolved
#      zero pairings.
#   4. FAIL-OPEN / HYGIENE — the gates must not write into the project they
#      measure, and must not crash on absent optional artifacts.
#
# The harness snapshots `git status --porcelain` before and after and asserts it
# is byte-identical: these gates read a build tree, and proving they only read is
# part of the test.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GATES="$here/../../template/craft-gates"
DIVERGENCE="$GATES/divergence.mjs"
CONTRAST="$GATES/contrast.mjs"
repo_root=$(cd "$here" && git rev-parse --show-toplevel 2>/dev/null || echo "")

[ -f "$DIVERGENCE" ] || { printf 'FAIL: divergence.mjs not found at %s\n' "$DIVERGENCE"; exit 1; }
[ -f "$CONTRAST" ]   || { printf 'FAIL: contrast.mjs not found at %s\n' "$CONTRAST"; exit 1; }
command -v node >/dev/null 2>&1 || { printf 'SKIP: node not installed\n'; exit 0; }

WS=$(mktemp -d); trap 'rm -rf "$WS"' EXIT
pass=0; fail=0
git_snap() { [ -n "$repo_root" ] && ( cd "$repo_root" && git status --porcelain ) || true; }
SNAP_BEFORE=$(git_snap)

ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }

# A token source that resolves, so token-dependent assertions do not short out
# the run before the check under test is reached.
write_tokens() { # dir [accent-oklch]
  mkdir -p "$1/src"
  cat > "$1/src/index.css" <<CSS
:root {
  --ink-1: oklch(0.15 0 0);
  --ink-2: oklch(0.45 0 0);
  --ink-3: oklch(0.55 0 0);
  --surface-base: oklch(0.99 0 0);
  --surface-raised: oklch(0.97 0 0);
  --surface-sunken: oklch(0.94 0 0);
  --accent-fill: ${2:-oklch(0.55 0.17 145)};
  --accent-on: oklch(0.99 0 0);
  --accent-text: oklch(0.40 0.14 145);
  --accent-display: oklch(0.55 0.17 145);
  --focus-ring: oklch(0.50 0.15 145);
  --control-border: oklch(0.62 0 0);
  --status-good: oklch(0.50 0.14 145);
  --status-warn: oklch(0.52 0.14 85);
  --status-serious: oklch(0.52 0.16 45);
  --status-critical: oklch(0.50 0.18 25);
  --chart-1: oklch(0.55 0.16 145);
  --chart-2: oklch(0.52 0.14 230);
  --chart-3: oklch(0.50 0.15 300);
  --chart-4: oklch(0.54 0.14 85);
  --chart-5: oklch(0.51 0.15 20);
}
.dark {
  --ink-1: oklch(0.97 0 0);
  --ink-2: oklch(0.80 0 0);
  --ink-3: oklch(0.72 0 0);
  --surface-base: oklch(0.16 0 0);
  --surface-raised: oklch(0.21 0 0);
  --surface-sunken: oklch(0.12 0 0);
  --accent-fill: ${2:-oklch(0.72 0.16 145)};
  --accent-on: oklch(0.15 0 0);
  --accent-text: oklch(0.82 0.13 145);
  --accent-display: oklch(0.78 0.15 145);
  --focus-ring: oklch(0.75 0.14 145);
  --control-border: oklch(0.55 0 0);
  --status-good: oklch(0.80 0.13 145);
  --status-warn: oklch(0.82 0.13 85);
  --status-serious: oklch(0.78 0.15 45);
  --status-critical: oklch(0.75 0.16 25);
  --chart-1: oklch(0.78 0.15 145);
  --chart-2: oklch(0.76 0.13 230);
  --chart-3: oklch(0.74 0.14 300);
  --chart-4: oklch(0.80 0.13 85);
  --chart-5: oklch(0.76 0.14 20);
}
CSS
}

# Run divergence.mjs inside a disposable project root. Echoes exit code on the
# first line, then the full report, so callers can assert on both.
run_divergence() { # dir
  ( cd "$1" && node "$DIVERGENCE" 2>&1; printf 'EXIT=%s\n' "$?" )
}

# state_of <report> <check> -> PASS|FAIL|SKIP|WAIVED|missing
state_of() {
  printf '%s\n' "$1" | awk -v c="$2" '$2 == c { print $1; found=1; exit } END { if (!found) print "missing" }'
}

# ---------------------------------------------------------------------------
# 1. FIXTURE CONTROLS
# ---------------------------------------------------------------------------

# composition-shape: the defective fixture must FAIL, its clean twin must PASS.
# These two differ ONLY in spatial structure — same six sections, same copy — so
# a gate that returns the same verdict for both has stopped measuring shape.
for pair in "fixture-shape.html:FAIL" "fixture-shape-clean.html:PASS"; do
  fx=${pair%%:*}; want=${pair##*:}
  [ -f "$GATES/$fx" ] || { bad "composition-shape fixture missing" "$fx"; continue; }
  d="$WS/shape-${want}"; mkdir -p "$d"
  write_tokens "$d"
  cp "$GATES/$fx" "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" composition-shape)
  if [ "$got" = "$want" ]; then ok; else
    bad "composition-shape on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'composition-shape' | head -1)"
  fi
done

# The defective shape fixture must make the RUN fail, not merely report a FAIL
# row. A gate whose failing assertion still exits 0 cannot block anything.
d="$WS/shape-exit"; mkdir -p "$d"; write_tokens "$d"; cp "$GATES/fixture-shape.html" "$d/page.html"
out=$(run_divergence "$d")
if printf '%s\n' "$out" | grep -q 'EXIT=1'; then ok; else
  bad "defective shape fixture did not exit 1" "$(printf '%s\n' "$out" | tail -3)"
fi

# spine-register: the defective fixture answers the buyer-facing spine slots in
# an integrator's register and must FAIL; the clean twin and the false-positive
# control must both PASS. The falsepos fixture is the important one — a register
# check that fires on a correct limits list teaches builds to strip the very
# concreteness the offer contract asks for.
# The regions line is COMMA-separated and its anchors are the fixture's own
# element ids, which differ between the two shapes — the register pair answers
# the buyer slots inside `hero` and `status-quo`, the false-positive control
# names them directly. Getting this wrong SKIPs the check, which is why the
# SKIP branch below is reported as a failure rather than tolerated.
reg_regions() { # fixture -> the Spine regions: value
  case "$1" in
    fixture-register-falsepos.html)
      echo 'plain-what=plain-what, audience=audience, problem=problem, how-it-works=method, objection=limits' ;;
    *)
      echo 'plain-what=hero, audience=hero, problem=status-quo, how-it-works=method, objection=limits' ;;
  esac
}
for pair in "fixture-register.html:FAIL" "fixture-register-clean.html:PASS" "fixture-register-falsepos.html:PASS"; do
  fx=${pair%%:*}; want=${pair##*:}
  [ -f "$GATES/$fx" ] || { bad "spine-register fixture missing" "$fx"; continue; }
  d="$WS/reg-${fx%%.html}"; mkdir -p "$d/craft"
  write_tokens "$d"
  cp "$GATES/$fx" "$d/page.html"
  # spine-register needs the build task's `Spine regions:` line to know which
  # region answers which slot; without it the check SKIPs and measures nothing.
  printf 'Spine regions: %s\n' "$(reg_regions "$fx")" > "$d/craft/build-task.md"
  out=$(run_divergence "$d")
  got=$(state_of "$out" spine-register)
  if [ "$got" = "$want" ]; then ok
  elif [ "$got" = "SKIP" ]; then
    # A SKIP here is not a pass — it is the check declining to measure. Report it
    # as the coverage failure it is, with the reason the gate gave.
    bad "spine-register on $fx SKIPped instead of grading (expected $want)" \
        "$(printf '%s\n' "$out" | grep -E 'spine-register' | head -1)"
  else
    bad "spine-register on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'spine-register' | head -1)"
  fi
done

# emoji-as-icon: pictographs standing in for the icon system. The pair differs
# only in icon treatment (emoji vs a decided SVG system); both carry the ™ and
# © marks every real page ships, which must never fire. The falsepos control's
# only pictographs sit inside a customer's quoted testimonial plus a ☎︎ the
# author explicitly rendered text-style — a gate that fires on those grades
# the customer's voice and the legal line, not the build's icon decision.
for pair in "fixture-emoji.html:FAIL" "fixture-emoji-clean.html:PASS" "fixture-emoji-falsepos.html:PASS"; do
  fx=${pair%%:*}; want=${pair##*:}
  [ -f "$GATES/$fx" ] || { bad "emoji-as-icon fixture missing" "$fx"; continue; }
  d="$WS/emoji-${fx%%.html}"; mkdir -p "$d"
  write_tokens "$d"
  cp "$GATES/$fx" "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" emoji-as-icon)
  if [ "$got" = "$want" ]; then ok; else
    bad "emoji-as-icon on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'emoji-as-icon' | head -1)"
  fi
done

# ...and a waived build must report WAIVED, not FAIL — the new assertions ride
# the same waiver lane as every other one, and this is the control that proves
# the lane is actually connected.
d="$WS/emoji-waived"; mkdir -p "$d/.craft-layer"
write_tokens "$d"
cp "$GATES/fixture-emoji.html" "$d/page.html"
cat > "$d/.craft-layer/waivers.json" <<'JSON'
[{ "check": "emoji-as-icon", "value": "*", "reason": "the brief reproduces user chat messages verbatim, emoji included" }]
JSON
out=$(run_divergence "$d")
got=$(state_of "$out" emoji-as-icon)
if [ "$got" = "WAIVED" ]; then ok; else
  bad "waived emoji-as-icon expected WAIVED, got $got" \
      "$(printf '%s\n' "$out" | grep -E 'emoji-as-icon' | head -1)"
fi

# copy-register: the machine-copy lexicon. The pair shares product, facts and
# prices; only the register differs. The clean control carries "seamless" as a
# lone adjective on purpose — the check is multi-word phrases only, and firing
# on a single word would turn it into a vocabulary ban.
for pair in "fixture-copy.html:FAIL" "fixture-copy-clean.html:PASS"; do
  fx=${pair%%:*}; want=${pair##*:}
  [ -f "$GATES/$fx" ] || { bad "copy-register fixture missing" "$fx"; continue; }
  d="$WS/copy-${fx%%.html}"; mkdir -p "$d"
  write_tokens "$d"
  cp "$GATES/$fx" "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" copy-register)
  if [ "$got" = "$want" ]; then ok; else
    bad "copy-register on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
  fi
done

# font-anti-corpus must see the family however the project declares it. The two
# forms below are the ones the check was blind to: Tailwind v4 emits no
# `font-family` line at all, and `font-family: var(--font-sans)` hides the name
# behind an indirection. Both used to record "no non-generic font declared" —
# so the way to pass the type gate was to never choose a typeface.
i=0
for decl in \
  '@theme { --font-sans: Inter, ui-sans-serif, system-ui; --primary: oklch(0.55 0.17 145); }' \
  ':root { --brand-face: Inter, sans-serif; --primary: oklch(0.55 0.17 145); } body { font-family: var(--brand-face); }' \
  ':root { --primary: oklch(0.55 0.17 145); } body { font-family: Inter, sans-serif; }'
do
  i=$((i + 1)); d="$WS/font-$i"; mkdir -p "$d/src"
  printf '%s\n' "$decl" > "$d/src/index.css"
  cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>x</h1></main></body></html>
HTML
  out=$(run_divergence "$d")
  got=$(state_of "$out" font-anti-corpus)
  if [ "$got" = "FAIL" ]; then ok; else
    bad "font-anti-corpus did not catch Inter in declaration form $i (got $got)" \
        "$(printf '%s\n' "$out" | grep -E 'font-anti-corpus' | head -1)"
  fi
done

# A build that declares no typeface at all still SKIPs — that is honest, and the
# coverage line is what stops it reading as a pass.
d="$WS/font-none"; mkdir -p "$d/src"
printf ':root { --primary: oklch(0.55 0.17 145); }\n' > "$d/src/index.css"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>x</h1></main></body></html>
HTML
out=$(run_divergence "$d")
[ "$(state_of "$out" font-anti-corpus)" = "SKIP" ] && ok || \
  bad "undeclared typeface should SKIP font-anti-corpus, not grade it" \
      "$(printf '%s\n' "$out" | grep -E 'font-anti-corpus' | head -1)"

# ---------------------------------------------------------------------------
# 2. COVERAGE HONESTY
# ---------------------------------------------------------------------------

# Every run states coverage, and a mostly-skipped run must not read as a clean
# sweep. This is the exact regression: 1-of-8 graded printed the same
# "OK: the build clears every divergence assertion" as 8-of-8.
d="$WS/coverage"; mkdir -p "$d/src"
printf ':root { --primary: oklch(0.55 0.17 145); }\n' > "$d/src/index.css"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>Ship faster</h1></main></body></html>
HTML
out=$(run_divergence "$d")
printf '%s\n' "$out" | grep -qE 'coverage: [0-9]+/[0-9]+ assertion' && ok || \
  bad "no coverage line on a partially-skipped run" "$(printf '%s\n' "$out" | tail -3)"
if printf '%s\n' "$out" | grep -qE 'clears every divergence assertion'; then
  bad "terminator claimed a clean sweep over a mostly-skipped run" \
      "$(printf '%s\n' "$out" | tail -2)"
else ok; fi

# A run in which every assertion SKIPped must not print an unqualified green.
# This is the regression that let a build with no craft artifacts and a default
# font stack read as "clears every divergence assertion".
d="$WS/allskip"; mkdir -p "$d"; write_tokens "$d"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>Nothing here</h1></main></body></html>
HTML
out=$(run_divergence "$d")
graded=$(printf '%s\n' "$out" | grep -cE '^\s+(PASS|FAIL|WAIVED) ' || true)
if [ "$graded" -eq 0 ]; then
  if printf '%s\n' "$out" | grep -qiE 'coverage:|0/|not measured|nothing was graded'; then ok; else
    bad "all-SKIP run printed no coverage qualifier" \
        "terminator was: $(printf '%s\n' "$out" | grep -iE '^OK:|assertion' | tail -1)"
  fi
else
  ok  # some assertion graded; coverage honesty is not under test in this shape
fi

# ---------------------------------------------------------------------------
# 3. NOT-MEASURED
# ---------------------------------------------------------------------------

# Missing token source must exit 2, per divergence.mjs's own header contract:
# "A gate whose whole subject is 'the build defaulted' cannot treat 'I could not
# find the build' as a pass."
d="$WS/notokens"; mkdir -p "$d"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>No tokens anywhere</h1></main></body></html>
HTML
out=$(run_divergence "$d")
if printf '%s\n' "$out" | grep -q 'EXIT=2'; then ok; else
  bad "missing token source did not exit 2" "$(printf '%s\n' "$out" | tail -2)"
fi

# contrast.mjs must not report a green having resolved zero pairings. A contrast
# gate that measures nothing and prints "every pairing clears its threshold" is
# worse than no gate: gates.spec.ts switches axe's own color-contrast rule off
# and names this file the gate of record.
d="$WS/contrast-empty"; mkdir -p "$d/src"
cat > "$d/src/index.css" <<'CSS'
:root { --totally-unrelated: oklch(0.5 0 0); }
CSS
out=$( cd "$d" && node "$CONTRAST" 2>&1; printf 'EXIT=%s\n' "$?" )
if printf '%s\n' "$out" | grep -q 'EXIT=2'; then ok; else
  bad "contrast.mjs did not exit 2 having resolved zero pairings" \
      "$(printf '%s\n' "$out" | tail -2)"
fi
if printf '%s\n' "$out" | grep -qiE 'clears (its|their) WCAG'; then
  bad "contrast.mjs printed a green having resolved zero pairings" \
      "$(printf '%s\n' "$out" | grep -iE 'clears' | head -1)"
else ok; fi

# ...and it MUST resolve a real shadcn token set. The PAIRS table is written in
# theming-system's role vocabulary; every shadcn build names the same roles
# `--foreground`/`--background`/`--primary`. Before the aliases, all 44 pairings
# missed and the gate printed OK over a build it had read no colour from.
d="$WS/contrast-shadcn"; mkdir -p "$d/src"
cat > "$d/src/index.css" <<'CSS'
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
}
CSS
out=$( cd "$d" && node "$CONTRAST" 2>&1; printf 'EXIT=%s\n' "$?" )
n=$(printf '%s\n' "$out" | sed -n 's/^coverage: \([0-9]*\)\/.*/\1/p')
if [ -n "$n" ] && [ "$n" -gt 0 ]; then ok; else
  bad "contrast.mjs resolved no pairing against a stock shadcn token set" \
      "$(printf '%s\n' "$out" | grep -i coverage | head -1)"
fi

# ---------------------------------------------------------------------------
# 4. FAIL-OPEN / HYGIENE
# ---------------------------------------------------------------------------

# Optional artifacts absent must not crash the gate (exit 0/1/2 are all verdicts;
# anything else is a stack trace reaching the user).
d="$WS/bare"; mkdir -p "$d"; write_tokens "$d"; cp "$GATES/fixture-shape-clean.html" "$d/page.html"
out=$(run_divergence "$d")
code=$(printf '%s\n' "$out" | sed -n 's/^EXIT=//p')
case "$code" in
  0|1|2) ok ;;
  *) bad "gate crashed with no optional artifacts (exit $code)" "$(printf '%s\n' "$out" | tail -5)" ;;
esac
if printf '%s\n' "$out" | grep -qE 'Error:|at Object\.|node:internal'; then
  bad "gate printed a stack trace on the bare-project path" "$(printf '%s\n' "$out" | grep -E 'Error:' | head -1)"
else ok; fi

# The gates must never write into the tree they measure.
d="$WS/readonly"; mkdir -p "$d"; write_tokens "$d"; cp "$GATES/fixture-shape-clean.html" "$d/page.html"
before=$( cd "$d" && find . -type f | sort )
run_divergence "$d" >/dev/null
after=$( cd "$d" && find . -type f | sort )
if [ "$before" = "$after" ]; then ok; else
  bad "divergence.mjs wrote into the project it measured" "$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -5)"
fi

# ---------------------------------------------------------------------------

SNAP_AFTER=$(git_snap)
if [ "$SNAP_BEFORE" != "$SNAP_AFTER" ]; then
  bad "harness mutated the repository working tree" \
      "$(diff <(printf '%s\n' "$SNAP_BEFORE") <(printf '%s\n' "$SNAP_AFTER") | head -5)"
fi

printf '\ncraft-gates: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
