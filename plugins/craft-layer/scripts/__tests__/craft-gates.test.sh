#!/usr/bin/env bash
# craft-gates.test.sh — runs divergence.mjs and contrast.mjs over defective/clean fixture controls and asserts each verdict, exit code and
# coverage line, then gates.spec.ts's reduced-motion block and a tsc --strict compile; fails if the repository's git status changes during the run.
# Misses: the reduced-motion and type-check sections SKIP without a local Playwright, or typescript with its types, and CI installs neither.
# Why, limits, history: rationale/derivations/plugin-craft-layer.md § plugins/craft-layer/scripts/__tests__/craft-gates.test.sh
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

run_divergence() { # dir
  ( cd "$1" && node "$DIVERGENCE" 2>&1; printf 'EXIT=%s\n' "$?" )
}

# state_of <report> <check> -> PASS|FAIL|SKIP|WAIVED|missing
state_of() {
  printf '%s\n' "$1" | awk -v c="$2" '$2 == c { print $1; found=1; exit } END { if (!found) print "missing" }'
}

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

d="$WS/shape-exit"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-shape.html" "$d/page.html"
out=$(run_divergence "$d")
if printf '%s\n' "$out" | grep -q 'EXIT=1'; then ok; else
  bad "defective shape fixture did not exit 1" "$(printf '%s\n' "$out" | tail -3)"
fi

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
  printf 'Spine regions: %s\n' "$(reg_regions "$fx")" > "$d/craft/build-task.md"
  out=$(run_divergence "$d")
  got=$(state_of "$out" spine-register)
  if [ "$got" = "$want" ]; then ok
  elif [ "$got" = "SKIP" ]; then
    bad "spine-register on $fx SKIPped instead of grading (expected $want)" \
        "$(printf '%s\n' "$out" | grep -E 'spine-register' | head -1)"
  else
    bad "spine-register on $fx expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'spine-register' | head -1)"
  fi
done

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

out=$(run_divergence "$WS/voice/ok")
got=$(state_of "$out" copy-register)
if [ "$got" = "FAIL" ] && printf '%s\n' "$out" | grep -q 'voice NEVER'; then ok; else
  bad "a NEVER literal in shipped copy did not reach copy-register (got $got)" \
      "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
fi
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

d="$WS/chrome-rows"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-chrome.html" "$d/page.html"
out=$(run_divergence "$d")
for row in "all-caps eyebrow" "trailing arrow" "middle-dot meta string"; do
  if printf '%s\n' "$out" | grep -q "\[$row\]"; then ok; else
    bad "copy-register did not report the '$row' row on the chrome fixture" \
        "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
  fi
done

d="$WS/chrome-live"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-chrome.html" "$d/page.html"
out=$( cd "$d" && CLAUDE_PLUGIN_ROOT="$here/../.." node "$DIVERGENCE" 2>&1; printf 'EXIT=%s\n' "$?" )
want_rows=$(awk '/<!-- copy-lexicon:start -->/{f=1;next} /<!-- copy-lexicon:end -->/{f=0} f && / :: / {n++} END{print n+0}' \
  "$here/../../skills/creative-direction/references/sameness-fingerprint.md")
got_rows=$(printf '%s\n' "$out" | sed -n 's/^copy lexicon: *live registry · \([0-9]*\) patterns.*/\1/p')
if [ "$got_rows" = "$want_rows" ] && [ "$want_rows" -gt 6 ]; then ok; else
  bad "copy lexicon did not load live from the registry (wanted $want_rows rows, report said '${got_rows:-nothing}')" \
      "$(printf '%s\n' "$out" | grep -E '^copy lexicon:' | head -2 | tr '\n' ' ')"
fi

# run_divergence sets no plugin root and so reads the frozen snapshot; these three rows exist only in the live registry.
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

d="$WS/live-scrollcue"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-scrollcue.html" "$d/page.html"
out=$( cd "$d" && CLAUDE_PLUGIN_ROOT="$here/../.." node "$DIVERGENCE" 2>&1 )
if [ "$(state_of "$out" copy-register)" = FAIL ] && printf '%s\n' "$out" | grep -q '\[scroll cue\]'; then ok; else
  bad "scroll cue fires: copy-register (live) on fixture-scrollcue.html did not report [scroll cue]" \
      "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"
fi

# Each control pin needs a graded live run, so an unloaded lexicon cannot pass it by silence.
d="$WS/live-scrollcue-clean"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-scrollcue-clean.html" "$d/page.html"
out=$( cd "$d" && CLAUDE_PLUGIN_ROOT="$here/../.." node "$DIVERGENCE" 2>&1 )
line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +copy-register ' | head -1)
for pin in 'real photo credit stays silent:Photo by|Unsplash|Ines Faria' 'prose using scroll stays silent:Scroll back|scrolls sideways|Scroll to top' \
           'functional scroll hint stays silent:Scroll to see more'; do
  label=${pin%%:*}; marker=${pin#*:}
  case $(state_of "$out" copy-register) in PASS|FAIL) graded=1 ;; *) graded=0 ;; esac
  if [ "$graded" = 1 ] && printf '%s\n' "$out" | grep -q '^copy lexicon: *live registry' \
     && ! printf '%s\n' "$line" | grep -qiE "\"[^\"]*($marker)[^\"]*\" \["; then ok; else
    bad "$label: copy-register (live) on fixture-scrollcue-clean.html fired on it or did not grade" "$line"
  fi
done

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

d="$WS/font-none"; mkdir -p "$d/src"
printf ':root { --primary: oklch(0.55 0.17 145); }\n' > "$d/src/index.css"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>x</h1></main></body></html>
HTML
out=$(run_divergence "$d")
[ "$(state_of "$out" font-anti-corpus)" = "SKIP" ] && ok || \
  bad "undeclared typeface should SKIP font-anti-corpus, not grade it" \
      "$(printf '%s\n' "$out" | grep -E 'font-anti-corpus' | head -1)"

# Both runs ship violet and Inter in the stylesheet and the utility layer; each echo names one of them (the hex in another notation) and leaves the other judged.
for run in 'violet|accent #7c3aed, type Fraunces' 'inter|accent #0f766e, type Inter'; do
  k=${run%%|*}; d="$WS/echo-$k"; mkdir -p "$d/craft"
  write_tokens "$d" 'oklch(0.55 0.22 295)'
  printf 'body { font-family: Inter, sans-serif; }\n' >> "$d/src/index.css"
  printf 'Brand echo: %s\n' "${run#*|}" > "$d/craft/offer-contract.md"
  cat > "$d/src/page.tsx" <<'TSX'
import { Inter } from 'next/font/google'

export default function Page() {
  return <main><h1 className="text-violet-700">Aubergine Coffee Roasters</h1><a className="bg-[#7c3aed] text-white" href="/shop">Buy beans</a></main>
}
TSX
  out=$(run_divergence "$d")
  case $k in
    violet) p1='echoed violet accent passes:accent-default-band:PASS'; p2='unechoed Inter still fails:font-anti-corpus:FAIL'
            p3='echoed violet utility palette passes:utility-palette:PASS'; p4='unechoed utility font still fails:utility-font:FAIL' ;;
    *)      p1='unechoed violet accent still fails:accent-default-band:FAIL'; p2='echoed Inter passes:font-anti-corpus:PASS'
            p3='unechoed utility palette still fails:utility-palette:FAIL'; p4='echoed Inter via utility font passes:utility-font:PASS' ;;
  esac
  for pin in "$p1" "$p2" "$p3" "$p4"; do
    label=${pin%%:*}; rest=${pin#*:}; chk=${rest%%:*}; want=${rest#*:}
    got=$(state_of "$out" "$chk")
    if [ "$got" = "$want" ]; then ok; else
      bad "$label: $chk expected $want, got $got" "$(printf '%s\n' "$out" | grep -E "$chk" | head -1)"
    fi
  done
done

# The accent at 280° sits within 15° of both inks' hues, so only the chroma floor keeps it judged.
d="$WS/echo-edge"; mkdir -p "$d/craft"
write_tokens "$d" 'oklch(0.55 0.2 280)'
printf 'body { font-family: Inter, sans-serif; }\n' >> "$d/src/index.css"
printf 'Brand echo: ink #18181b and #0f172a, type S\xc3\xb6hne (not Inter, which the old site dropped)\n' > "$d/craft/offer-contract.md"
out=$(run_divergence "$d")
for pin in 'neutral ink in the echo does not exempt an accent:accent-default-band' 'parenthetical family is not echoed:font-anti-corpus'; do
  label=${pin%%:*}; chk=${pin#*:}; got=$(state_of "$out" "$chk")
  if [ "$got" = FAIL ]; then ok; else
    bad "$label: $chk expected FAIL, got $got" "$(printf '%s\n' "$out" | grep -E "$chk" | head -1)"
  fi
done

# accent-default-band PASS and font-anti-corpus SKIP are asserted on purpose: a second check reporting this page would double-count it.
d="$WS/util-defective"; mkdir -p "$d/src"
write_tokens "$d"
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

# Tailwind's indigo/violet/purple hexes read below the 275 floor in sRGB, so a fuchsia like #d946ef is what proves the hex path is wired.
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

d="$WS/notokens"; mkdir -p "$d"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>No tokens anywhere</h1></main></body></html>
HTML
out=$(run_divergence "$d")
if printf '%s\n' "$out" | grep -q 'EXIT=2'; then ok; else
  bad "missing token source did not exit 2" "$(printf '%s\n' "$out" | tail -2)"
fi

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

# Exit 0, 1 and 2 are all verdicts; any other code is a crash.
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

d="$WS/readonly"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/fixture-shape-clean.html" "$d/page.html"
before=$( cd "$d" && find . -type f | sort )
run_divergence "$d" >/dev/null
after=$( cd "$d" && find . -type f | sort )
if [ "$before" = "$after" ]; then ok; else
  bad "divergence.mjs wrote into the project it measured" "$(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -5)"
fi

# Nothing is installed (no network): an existing Playwright is used, and only if its Chromium launches.
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
  # The runner and the spec must share one Playwright instance, so the shim points at the package the CLI comes from.
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
    # Each pattern is its channel's own line shape: #waapi also moves its computed transform, so a bare name would pass with WAAPI off.
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

# --strict because the crafted project's tsconfig often is, and a spec failing there reads as a broken gate.
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

SNAP_AFTER=$(git_snap)
if [ "$SNAP_BEFORE" != "$SNAP_AFTER" ]; then
  bad "harness mutated the repository working tree" \
      "$(diff <(printf '%s\n' "$SNAP_BEFORE") <(printf '%s\n' "$SNAP_AFTER") | head -5)"
fi

printf '\ncraft-gates: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
