#!/usr/bin/env bash
# Tests plugins/craft-layer/template/craft-gates/divergence.mjs and contrast.mjs,
# and gates.spec.ts's reduced-motion block when a local Playwright can run it.
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
# Six sections:
# The fixtures live HERE, beside this harness, not in template/craft-gates/. They
# are this file's inputs and nothing else reads them, so shipping 64K of them to
# every installer inside the directory commands/audit.md says to run from — and
# never to copy — bought nobody anything (moved 2026-09-22).
#
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
#   5. REDUCED-MOTION RUNTIME — the JS/canvas/smooth-scroll/video half of the
#      reduced-motion trigger, run through Playwright against fixture-motion-*.
#      Needs a local Playwright; without one it prints SKIP and runs nothing.
#   6. TYPE CHECK — gates.spec.ts under `tsc --strict`, when a local typescript and
#      Playwright's types are found; SKIP otherwise.
#
# The harness snapshots `git status --porcelain` before and after and asserts it
# is byte-identical: these gates read a build tree, and proving they only read is
# part of the test.
set -u

here=$(cd "$(dirname "$0")" && pwd)
GATES="$here/../../template/craft-gates"
FIXTURES="$here/fixtures"
DIVERGENCE="$GATES/divergence.mjs"
CONTRAST="$GATES/contrast.mjs"
repo_root=$(cd "$here" && git rev-parse --show-toplevel 2>/dev/null || echo "")

[ -f "$DIVERGENCE" ] || { printf 'FAIL: divergence.mjs not found at %s\n' "$DIVERGENCE"; exit 1; }
[ -f "$CONTRAST" ]   || { printf 'FAIL: contrast.mjs not found at %s\n' "$CONTRAST"; exit 1; }
[ -d "$FIXTURES" ]   || { printf 'FAIL: control fixtures not found at %s\n' "$FIXTURES"; exit 1; }
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
  [ -f "$FIXTURES/$fx" ] || { bad "composition-shape fixture missing" "$fx"; continue; }
  d="$WS/shape-${want}"; mkdir -p "$d"
  write_tokens "$d"
  cp "$FIXTURES/$fx" "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" composition-shape)
  if [ "$got" = "$want" ]; then ok; else
    bad "composition-shape on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'composition-shape' | head -1)"
  fi
done

# The defective shape fixture must make the RUN fail, not merely report a FAIL
# row. A gate whose failing assertion still exits 0 cannot block anything.
d="$WS/shape-exit"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-shape.html" "$d/page.html"
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
  [ -f "$FIXTURES/$fx" ] || { bad "spine-register fixture missing" "$fx"; continue; }
  d="$WS/reg-${fx%%.html}"; mkdir -p "$d/craft"
  write_tokens "$d"
  cp "$FIXTURES/$fx" "$d/page.html"
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
  [ -f "$FIXTURES/$fx" ] || { bad "emoji-as-icon fixture missing" "$fx"; continue; }
  d="$WS/emoji-${fx%%.html}"; mkdir -p "$d"
  write_tokens "$d"
  cp "$FIXTURES/$fx" "$d/page.html"
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
cp "$FIXTURES/fixture-emoji.html" "$d/page.html"
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
  [ -f "$FIXTURES/$fx" ] || { bad "copy-register fixture missing" "$fx"; continue; }
  d="$WS/copy-${fx%%.html}"; mkdir -p "$d"
  write_tokens "$d"
  cp "$FIXTURES/$fx" "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" copy-register)
  if [ "$got" = "$want" ]; then ok; else
    bad "copy-register on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
  fi
done

# voice-contract: the four states, in the order they cost. No build task is a
# SKIP (a build is never failed for not saving a file); a build task that EXISTS
# and omits the line is the finding; a line with no NEVER has no machine-readable
# half; a line with NEVERs passes and hands those literals to copy-register.
mkdir -p "$WS/voice"/{none,noline,nonever,ok}/craft
for k in none noline nonever ok; do
  write_tokens "$WS/voice/$k"
  cat > "$WS/voice/$k/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><section id="hero"><h1>Fieldnote for survey crews</h1>
<p>Everything you need to run a crew.</p></section></main></body></html>
HTML
done
rmdir "$WS/voice/none/craft"
printf 'Spine regions: plain-what=#hero\n' > "$WS/voice/noline/craft/build-task.md"
printf 'Spine regions: plain-what=#hero\nVoice: first person plural to a crew lead \xc2\xb7 6-14 words a sentence\n' > "$WS/voice/nonever/craft/build-task.md"
printf 'Spine regions: plain-what=#hero\nVoice: first person plural to a crew lead \xc2\xb7 6-14 words \xc2\xb7 NEVER "everything you need", NEVER "simple, powerful, flexible"\n' > "$WS/voice/ok/craft/build-task.md"
for pair in "none:SKIP" "noline:FAIL" "nonever:FAIL" "ok:PASS"; do
  k=${pair%%:*}; want=${pair##*:}
  out=$(run_divergence "$WS/voice/$k")
  got=$(state_of "$out" voice-contract)
  if [ "$got" = "$want" ]; then ok; else
    bad "voice-contract on the '$k' shape expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'voice-contract' | head -1)"
  fi
done

# ...and the NEVER literals must actually reach copy-register. A `Voice:` line the
# gate parses and then never grades against is the same shape as the frozen
# lexicon this pair replaced: a rule recorded, read by nothing.
out=$(run_divergence "$WS/voice/ok")
got=$(state_of "$out" copy-register)
if [ "$got" = "FAIL" ] && printf '%s\n' "$out" | grep -q 'voice NEVER'; then ok; else
  bad "a NEVER literal in shipped copy did not reach copy-register (got $got)" \
      "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
fi
# The control: same page, same line, the banned string rewritten. Both must clear.
d="$WS/voice-clean"; mkdir -p "$d/craft"; write_tokens "$d"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><section id="hero"><h1>Fieldnote for survey crews</h1>
<p>One sheet per crew, synced at the van.</p></section></main></body></html>
HTML
cp "$WS/voice/ok/craft/build-task.md" "$d/craft/build-task.md"
out=$(run_divergence "$d")
if [ "$(state_of "$out" copy-register)" = "PASS" ] && [ "$(state_of "$out" voice-contract)" = "PASS" ]; then ok; else
  bad "the voice control fixture did not come out clean" \
      "$(printf '%s\n' "$out" | grep -E 'copy-register|voice-contract' | head -2 | tr '\n' ' ')"
fi

# The three MECHANICAL chrome rows the registry's own note names — the ALL-CAPS
# eyebrow, the middle-dot meta string and the trailing arrow. Before they were
# lexicon rows, a page reproducing nine registry entries verbatim cleared every
# assertion the gate could grade. The clean twin is the false-positive control
# and the important half: ONE arrow, ONE middle dot, sentence-case labels. A
# `min`-less pattern reds it, and a red control is a gate nobody keeps on.
for pair in "fixture-chrome.html:FAIL" "fixture-chrome-clean.html:PASS"; do
  fx=${pair%%:*}; want=${pair##*:}
  [ -f "$FIXTURES/$fx" ] || { bad "chrome fixture missing" "$fx"; continue; }
  d="$WS/chrome-${fx%%.html}"; mkdir -p "$d"
  write_tokens "$d"
  cp "$FIXTURES/$fx" "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" copy-register)
  if [ "$got" = "$want" ]; then ok; else
    bad "copy-register on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
  fi
done

# ...and all three must be named, not just whichever fires first. A loader that
# reads one row of three is the defect this replaced, one level down.
d="$WS/chrome-rows"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-chrome.html" "$d/page.html"
out=$(run_divergence "$d")
for row in "all-caps eyebrow" "trailing arrow" "middle-dot meta string"; do
  if printf '%s\n' "$out" | grep -q "\[$row\]"; then ok; else
    bad "copy-register did not report the '$row' row on the chrome fixture" \
        "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
  fi
done

# THE LOADER READS THE REGISTRY, not a frozen copy of it. This is the assertion
# that would have caught the original finding: the lexicon was six phrases frozen
# into the script beside a 13,951-char registry it never opened. With the plugin
# root set the run must say `live registry`, and the pattern count must equal the
# rows the reference actually carries — a silent fallback to the snapshot reads
# identical in every other line of the report.
d="$WS/chrome-live"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-chrome.html" "$d/page.html"
out=$( cd "$d" && CLAUDE_PLUGIN_ROOT="$here/../.." node "$DIVERGENCE" 2>&1; printf 'EXIT=%s\n' "$?" )
want_rows=$(awk '/<!-- copy-lexicon:start -->/{f=1;next} /<!-- copy-lexicon:end -->/{f=0} f && / :: / {n++} END{print n+0}' \
  "$here/../../skills/creative-direction/references/sameness-fingerprint.md")
got_rows=$(printf '%s\n' "$out" | sed -n 's/^copy lexicon: *live registry · \([0-9]*\) patterns.*/\1/p')
if [ "$got_rows" = "$want_rows" ] && [ "$want_rows" -gt 6 ]; then ok; else
  bad "copy lexicon did not load live from the registry (wanted $want_rows rows, report said '${got_rows:-nothing}')" \
      "$(printf '%s\n' "$out" | grep -E '^copy lexicon:' | head -2 | tr '\n' ' ')"
fi

# The live-only rows (added to the registry after the frozen snapshot) are graded by
# nothing above: run_divergence runs without the plugin root, so every other fixture
# reads the snapshot. This pair runs LIVE. The defective page must name all three
# corpus rows; the clean twin carries each row's false positive — "Agentic" opening a
# long sentence, humans and agents in one line but not the formula, design engineers
# outside the registry headline — and must PASS.
for pair in "fixture-agent-copy.html:FAIL" "fixture-agent-copy-clean.html:PASS"; do
  fx=${pair%%:*}; want=${pair##*:}
  [ -f "$FIXTURES/$fx" ] || { bad "agent-copy fixture missing" "$fx"; continue; }
  d="$WS/live-${fx%%.html}"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/$fx" "$d/page.html"
  out=$( cd "$d" && CLAUDE_PLUGIN_ROOT="$here/../.." node "$DIVERGENCE" 2>&1; printf 'EXIT=%s\n' "$?" )
  got=$(state_of "$out" copy-register)
  if [ "$got" = "$want" ]; then ok; else
    bad "copy-register (live) on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
  fi
  [ "$want" = FAIL ] || continue
  for row in "agentic headline" "for humans and agents" "for design engineers"; do
    printf '%s\n' "$out" | grep -q "\[$row\]" && ok || \
      bad "copy-register (live) did not report the '$row' row on $fx" "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
  done
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

# utility-palette / utility-font: the Tailwind/JSX blind spot. The palette and
# the type reach the page through `className` strings and a font import, so the
# two token-reading assertions never see them. The defective fixture below is the
# case that used to print "OK: the build clears the N divergence assertion(s)
# that could be graded" — which is why this control also asserts that
# accent-default-band still PASSes and font-anti-corpus still SKIPs on it. If a
# later change makes those two catch this page, this block should be revisited,
# not deleted: two assertions reporting the same finding twice is its own defect.
d="$WS/util-defective"; mkdir -p "$d/src"
write_tokens "$d"   # a cleanly derived green accent token no element references
cat > "$d/src/page.tsx" <<'TSX'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export default function Page() {
  return (
    <main className={inter.className}>
      <section className="mx-auto max-w-5xl text-center py-24">
        <h1 className="bg-gradient-to-r from-indigo-500 via-purple-500 to-violet-600 bg-clip-text text-transparent">
          Ship the thing
        </h1>
        <a className="bg-[#6366f1] rounded-lg px-6 py-3 text-white" href="/signup">Start free</a>
      </section>
    </main>
  )
}
TSX
out=$(run_divergence "$d")
for want in "utility-palette:FAIL" "utility-font:FAIL" "accent-default-band:PASS" "font-anti-corpus:SKIP"; do
  chk=${want%%:*}; exp=${want##*:}; got=$(state_of "$out" "$chk")
  if [ "$got" = "$exp" ]; then ok; else
    bad "defective utility fixture: $chk expected $exp, got $got" \
        "$(printf '%s\n' "$out" | grep -E "$chk" | head -1)"
  fi
done
if printf '%s\n' "$out" | grep -q 'EXIT=1'; then ok; else
  bad "defective utility fixture did not exit 1" "$(printf '%s\n' "$out" | tail -3)"
fi

# The clean twin: same page, same sections, same shape — a derived green applied
# through arbitrary values and a family with an argument behind it. The chart
# hexes are the false-positive control on the hue path: legitimate colour outside
# the band must never register.
d="$WS/util-clean"; mkdir -p "$d/src"
write_tokens "$d"
cat > "$d/src/page.tsx" <<'TSX'
import { Fraunces } from 'next/font/google'

const display = Fraunces({ subsets: ['latin'] })

export default function Page() {
  return (
    <main className={display.className}>
      <section className="mx-auto max-w-5xl py-24">
        <h1 className="font-['Fraunces'] text-[#166534]">Ship the thing</h1>
        <a className="bg-[#166534] rounded-lg px-6 py-3 text-white" href="/signup">Start free</a>
        <svg><rect style={{ fill: '#22c55e' }} /><rect style={{ fill: '#0ea5e9' }} /></svg>
      </section>
    </main>
  )
}
TSX
out=$(run_divergence "$d")
for want in "utility-palette:PASS" "utility-font:PASS"; do
  chk=${want%%:*}; exp=${want##*:}; got=$(state_of "$out" "$chk")
  if [ "$got" = "$exp" ]; then ok; else
    bad "clean utility fixture: $chk expected $exp, got $got" \
        "$(printf '%s\n' "$out" | grep -E "$chk" | head -1)"
  fi
done

# The false-positive guard: a brand that genuinely IS violet, says so in a
# waiver, and ships a chart series carrying legitimate hex. It must come out
# WAIVED rather than FAIL, and the run must still exit 0 — a gate that cannot be
# waived by a build with a reason is a gate that gets switched off.
d="$WS/util-falsepos"; mkdir -p "$d/src" "$d/.craft-layer"
write_tokens "$d" 'oklch(0.55 0.22 295)'
cat > "$d/src/page.tsx" <<'TSX'
export default function Page() {
  return (
    <main className="font-['Fraunces']">
      <section className="mx-auto max-w-5xl py-24">
        <h1 className="text-violet-700">Aubergine Coffee Roasters</h1>
        <a className="bg-violet-600 rounded-lg px-6 py-3 text-white" href="/shop">Buy beans</a>
        <svg><rect style={{ fill: '#22c55e' }} /><rect style={{ fill: '#0ea5e9' }} /></svg>
      </section>
    </main>
  )
}
TSX
cat > "$d/.craft-layer/waivers.json" <<'JSON'
[
  { "check": "utility-palette", "value": "*", "reason": "the brand mark has been aubergine since 1998; the offer contract records it as a brand echo" },
  { "check": "accent-default-band", "value": "*", "reason": "same brand echo — the accent token is derived FROM the mark, not reached for" }
]
JSON
out=$(run_divergence "$d")
got=$(state_of "$out" utility-palette)
if [ "$got" = "WAIVED" ]; then ok; else
  bad "violet-brand false-positive guard expected WAIVED, got $got" \
      "$(printf '%s\n' "$out" | grep -E 'utility-palette' | head -1)"
fi
if printf '%s\n' "$out" | grep -q 'EXIT=0'; then ok; else
  bad "waived violet-brand build did not exit 0" "$(printf '%s\n' "$out" | tail -3)"
fi

# The hex path, on its own, with no named utility to carry the verdict. It fires
# only where sRGB and oklch agree about the band — Tailwind's indigo/violet/purple
# hexes read 238.7-270.7 in their OWN space, below the 275 floor, so #d946ef is
# what proves this path is wired. That gap is stated in divergence.mjs's residuals
# rather than papered over here.
d="$WS/util-hex"; mkdir -p "$d/src"
write_tokens "$d"
cat > "$d/src/page.tsx" <<'TSX'
export default function Page() {
  return <main><h1 className="bg-[#d946ef]" style={{ color: '#c026d3' }}>Ship the thing</h1></main>
}
TSX
out=$(run_divergence "$d")
got=$(state_of "$out" utility-palette)
if [ "$got" = "FAIL" ]; then ok; else
  bad "arbitrary-value + inline-style hex path expected FAIL, got $got" \
      "$(printf '%s\n' "$out" | grep -E 'utility-palette' | head -1)"
fi

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
d="$WS/bare"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-shape-clean.html" "$d/page.html"
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
d="$WS/readonly"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-shape-clean.html" "$d/page.html"
before=$( cd "$d" && find . -type f | sort )
run_divergence "$d" >/dev/null
after=$( cd "$d" && find . -type f | sort )
if [ "$before" = "$after" ]; then ok; else
  bad "divergence.mjs wrote into the project it measured" "$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -5)"
fi

# ---------------------------------------------------------------------------
# 5. REDUCED-MOTION RUNTIME CONTROLS (needs a browser; SKIPs without one)
# ---------------------------------------------------------------------------

# gates.spec.ts's reduced-motion block, run for real — the shipped spec, the
# shipped config, Playwright's own runner — against three fixtures that are ONE
# page differing in ONE line. The JS twin must fail the JS and smooth-scroll
# tests, the canvas twin the canvas test, the clean twin nothing, and each
# failure must NAME the element that moved: a red for the wrong reason proves
# as little as a green.
#
# No network, so nothing is installed. A Playwright is looked for where one
# already lives — $CRAFT_GATES_PLAYWRIGHT (a node_modules dir holding
# `playwright`), then the npx cache `npx playwright …` leaves behind — and the
# first whose Chromium actually LAUNCHES wins. None → one SKIP line naming what
# is missing, and the sections above still count. CI installs no Playwright, so
# there this section SKIPs: the proof is local, and the line says so.
pw_launches() { # node_modules-dir -> exit 0 when its chromium starts
  node -e '
    const t = setTimeout(() => process.exit(3), 20000)
    require(process.argv[1] + "/playwright").chromium.launch()
      .then((b) => b.close()).then(() => { clearTimeout(t); process.exit(0) }, () => process.exit(1))
  ' "$1" >/dev/null 2>&1
}
PW=""
for nm in ${CRAFT_GATES_PLAYWRIGHT:-} $(ls -dt "$HOME"/.npm/_npx/*/node_modules 2>/dev/null); do
  [ -f "$nm/playwright/cli.js" ] || continue
  if pw_launches "$nm"; then PW="$nm"; break; fi
done

if [ -z "$PW" ]; then
  printf 'SKIP  reduced-motion runtime controls: no Playwright whose Chromium launches (looked in $CRAFT_GATES_PLAYWRIGHT and ~/.npm/_npx) — the three fixture-motion-* controls did NOT run\n'
else
  # The spec imports @playwright/test and @axe-core/playwright by bare name, so
  # hand it a NODE_PATH holding both. The runner and the spec must share ONE
  # Playwright instance, hence the shim onto the same package the CLI is from.
  # axe never runs under --grep, so a stub that refuses construction stands in.
  shim="$WS/pw/node_modules"; mkdir -p "$shim/@playwright/test" "$shim/@axe-core/playwright"
  if [ -d "$PW/@playwright/test" ]; then
    rm -rf "$shim/@playwright/test"; ln -s "$PW/@playwright/test" "$shim/@playwright/test"
  else
    printf '{"name":"@playwright/test","main":"index.js"}\n' > "$shim/@playwright/test/package.json"
    printf 'module.exports = require(%s)\n' "\"$PW/playwright/test\"" > "$shim/@playwright/test/index.js"
  fi
  if [ -d "$PW/@axe-core/playwright" ]; then
    rm -rf "$shim/@axe-core/playwright"; ln -s "$PW/@axe-core/playwright" "$shim/@axe-core/playwright"
  else
    printf '{"name":"@axe-core/playwright","main":"index.js"}\n' > "$shim/@axe-core/playwright/package.json"
    printf 'class AxeBuilder { constructor() { throw new Error("axe stub: the reduced-motion controls never run axe") } }\nmodule.exports = AxeBuilder\nmodule.exports.default = AxeBuilder\n' \
      > "$shim/@axe-core/playwright/index.js"
  fi

  # rm_verdicts <fixture> -> one "<key> <passed|failed|…> <error text>" line per test.
  rm_verdicts() {
    local run="$WS/rm-${1%%.html}"; mkdir -p "$run"
    local url; url=$(node -p 'require("url").pathToFileURL(process.argv[1]).href' "$FIXTURES/$1")
    ( cd "$run" && BASE_URL="$url" NODE_PATH="$shim" PLAYWRIGHT_JSON_OUTPUT_NAME="$run/report.json" \
        node "$PW/playwright/cli.js" test --config "$GATES/playwright.config.ts" \
        --grep 'prefers-reduced-motion' --reporter=json >/dev/null 2>"$run/stderr" )
    node -e '
      const keys = [["page renders", "css"], ["JS motion", "js"], ["canvas:", "canvas"],
                    ["smooth-scroll:", "smooth"], ["video:", "video"]]
      let r; try { r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")) } catch { process.exit(0) }
      const walk = (s) => [...(s.specs || []), ...(s.suites || []).flatMap(walk)]
      for (const spec of (r.suites || []).flatMap(walk)) {
        const k = keys.find(([p]) => spec.title.startsWith(p))
        const res = spec.tests?.[0]?.results?.at(-1)
        if (!k || !res) continue
        const err = (res.errors || []).map((e) => e.message || "").join(" ").replace(/\x1b\[[0-9;]*m/g, "").replace(/\s+/g, " ")
        console.log(`${k[1]} ${res.status} ${err}`)
      }
    ' "$run/report.json"
  }

  for pair in \
    "fixture-motion-js.html:css=passed js=failed canvas=passed smooth=failed video=passed" \
    "fixture-motion-canvas.html:css=passed js=passed canvas=failed smooth=passed video=passed" \
    "fixture-motion-clean.html:css=passed js=passed canvas=passed smooth=passed video=passed" \
    "fixture-motion-video.html:video=failed" \
    "fixture-motion-video-clean.html:video=passed"
  do
    fx=${pair%%:*}; want=${pair#*:}
    [ -f "$FIXTURES/$fx" ] || { bad "reduced-motion fixture missing" "$fx"; continue; }
    out=$(rm_verdicts "$fx")
    if [ -z "$out" ]; then
      bad "reduced-motion suite produced no verdicts on $fx" "$(tail -3 "$WS/rm-${fx%%.html}/stderr" 2>/dev/null)"
      continue
    fi
    for kv in $want; do
      k=${kv%%=*}; exp=${kv#*=}
      got=$(printf '%s\n' "$out" | awk -v k="$k" '$1 == k { print $2; exit }')
      if [ "$got" = "$exp" ]; then ok; else
        bad "reduced-motion '$k' on $fx expected $exp, got ${got:-missing}" \
            "$(printf '%s\n' "$out" | awk -v k="$k" '$1 == k' | cut -c1-240)"
      fi
    done
    # ...and for the RIGHT reason: each defective twin's failure names its mover
    # IN THE CHANNEL THAT SHOULD SEE IT. `#waapi` also moves its computed
    # transform, so a bare name match would stay green with the WAAPI channel
    # switched off — each pattern below is that channel's own line shape.
    # The video twin's "Display", "Google Play" and "Replay" buttons must not read as a
    # pause control, and the clip inside the open shadow root must be found at all.
    case "$fx" in
      fixture-motion-js.html)     need='js|div#waapi\.card: transform over
js|div#tween\.card: matrix\(
js|div#parallax\.card: [0-9]+ transform changes across
js|div#drift\.card: [0-9]+ translate changes across [0-9]+ scroll stops \(translate
smooth|Lenis smooth-scrolled a wheel event' ;;
      fixture-motion-canvas.html) need='canvas|canvas\[#scene\] 320x160: [0-9.]+% then' ;;
      fixture-motion-video.html)  need='video|video#hero-loop \(
video|video#shadow-loop inside <clip-player> \(' ;;
      *)                          need="" ;;
    esac
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      k=${n%%|*}; what=${n#*|}
      if printf '%s\n' "$out" | awk -v k="$k" '$1 == k' | grep -qE "$what"; then ok; else
        bad "reduced-motion '$k' on $fx did not name $what" \
            "$(printf '%s\n' "$out" | awk -v k="$k" '$1 == k' | cut -c1-240)"
      fi
    done <<EOF
$need
EOF
  done
fi

# ---------------------------------------------------------------------------
# 6. TYPE CHECK (needs typescript locally; SKIPs without it)
# ---------------------------------------------------------------------------

# gates.spec.ts runs inside the crafted project, whose tsconfig is often `strict`; a spec
# that fails there is a gate the project's own typecheck step reports as broken. Same
# lookup as section 5, for a node_modules holding typescript, @playwright/test and
# @types/node. axe is stubbed to the three calls the spec makes.
TSNM=""
for nm in ${CRAFT_GATES_PLAYWRIGHT:-} $(ls -dt "$HOME"/.npm/_npx/*/node_modules 2>/dev/null); do
  if [ -f "$nm/typescript/bin/tsc" ] && [ -d "$nm/@playwright/test" ] && [ -d "$nm/@types/node" ]; then TSNM="$nm"; break; fi
done
if [ -z "$TSNM" ]; then
  printf 'SKIP  type check: no node_modules holding typescript, @playwright/test and @types/node (looked in $CRAFT_GATES_PLAYWRIGHT and ~/.npm/_npx) — gates.spec.ts was NOT compiled\n'
else
  tc="$WS/tsc"; mkdir -p "$tc/node_modules/@axe-core/playwright" "$tc/node_modules/@types"
  ln -s "$TSNM/@playwright" "$tc/node_modules/@playwright"
  ln -s "$TSNM/@types/node" "$tc/node_modules/@types/node"
  printf '{"name":"@axe-core/playwright","types":"index.d.ts"}\n' > "$tc/node_modules/@axe-core/playwright/package.json"
  printf '%s\n' 'export default class AxeBuilder {' '  constructor(o: unknown)' \
    '  withTags(t: string[]): this' '  disableRules(r: string[]): this' \
    '  analyze(): Promise<{ violations: { id: string; impact?: string | null; help: string; nodes: { target: unknown }[] }[] }>' '}' \
    > "$tc/node_modules/@axe-core/playwright/index.d.ts"
  cp "$GATES/gates.spec.ts" "$tc/gates.spec.ts"
  if out=$(cd "$tc" && node "$TSNM/typescript/bin/tsc" --noEmit --strict --skipLibCheck --target es2022 \
      --module esnext --moduleResolution bundler --lib es2023,dom,dom.iterable gates.spec.ts 2>&1); then ok
  else bad "gates.spec.ts does not compile under tsc --strict" "$(printf '%s\n' "$out" | head -4)"; fi
fi

# ---------------------------------------------------------------------------

SNAP_AFTER=$(git_snap)
if [ "$SNAP_BEFORE" != "$SNAP_AFTER" ]; then
  bad "harness mutated the repository working tree" \
      "$(diff <(printf '%s\n' "$SNAP_BEFORE") <(printf '%s\n' "$SNAP_AFTER") | head -5)"
fi

printf '\ncraft-gates: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
