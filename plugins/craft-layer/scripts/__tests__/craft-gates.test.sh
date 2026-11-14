#!/usr/bin/env bash
# craft-gates.test.sh — runs divergence.mjs and contrast.mjs over defective/clean fixture controls and asserts each verdict, exit code and
# coverage line, then gates.spec.ts's reduced-motion, keyboard-grid, phone-zoom and forced-colours tests, a tsc --strict compile and the docs' worked examples; fails if git status changes.
# Misses: the browser controls SKIP without a Playwright whose Chromium (bundled, or a system Chrome channel) launches, the type check without typescript and its types; CI installs neither.
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

d="$WS/emoji-waived"; mkdir -p "$d/.cc-artifacts/craft-layer"
write_tokens "$d"
cp "$FIXTURES/fixture-emoji.html" "$d/page.html"
cat > "$d/.cc-artifacts/craft-layer/waivers.json" <<'JSON'
[{ "check": "emoji-as-icon", "value": "*", "reason": "the brief reproduces user chat messages verbatim, emoji included" }]
JSON
out=$(run_divergence "$d")
got=$(state_of "$out" emoji-as-icon)
if [ "$got" = "WAIVED" ]; then ok; else
  bad "waived emoji-as-icon expected WAIVED, got $got" \
      "$(printf '%s\n' "$out" | grep -E 'emoji-as-icon' | head -1)"
fi

# A project from before 2026-11-14 keeps its waivers in .craft-layer/: read only while the new file is absent, never written.
d="$WS/emoji-waived-legacy"; mkdir -p "$d/.craft-layer"; write_tokens "$d"; cp "$FIXTURES/fixture-emoji.html" "$d/page.html"
cp "$WS/emoji-waived/.cc-artifacts/craft-layer/waivers.json" "$d/.craft-layer/waivers.json"
legacy_sum=$(cksum < "$d/.craft-layer/waivers.json")
out=$(run_divergence "$d")
if [ "$(state_of "$out" emoji-as-icon)" = WAIVED ] && [ "$(cksum < "$d/.craft-layer/waivers.json")" = "$legacy_sum" ] && [ ! -e "$d/.cc-artifacts" ]; then ok; else
  bad "an old-only .craft-layer/waivers.json waives, stays untouched, and nothing is written to .cc-artifacts/" \
      "$(printf '%s\n' "$out" | grep -E 'emoji-as-icon' | head -1); $(ls -A "$d")"; fi
mkdir -p "$d/.cc-artifacts/craft-layer"; printf '[]\n' > "$d/.cc-artifacts/craft-layer/waivers.json"
out=$(run_divergence "$d")
if [ "$(state_of "$out" emoji-as-icon)" = FAIL ]; then ok; else
  bad "a new waivers.json wins over the old one, so the legacy waiver no longer applies" \
      "$(printf '%s\n' "$out" | grep -E 'emoji-as-icon' | head -1)"; fi

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
# A build task written from the plugin's own examples must clear the gate: the last fenced `Voice:` line in each
# doc (brief-templates.md's filled example, voice-contract.md's canonical line), on the one line the gate reads.
for doc in skills/design-research/references/brief-templates.md skills/creative-direction/references/voice-contract.md; do
  line=$(awk '/^```/ { f = !f; next } f && /^Voice:/' "$here/../../$doc" | tail -1)
  d="$WS/voice-doc-$(basename "$doc" .md)"; mkdir -p "$d/craft"; write_tokens "$d"
  cp "$WS/voice/ok/page.html" "$d/page.html"
  printf 'Spine regions: plain-what=#hero\n%s\n' "$line" > "$d/craft/build-task.md"
  out=$(run_divergence "$d")
  n=$(printf '%s\n' "$out" | sed -n 's/.*carries a `Voice:` line with \([0-9]*\) literal NEVER.*/\1/p')
  if [ "$(state_of "$out" voice-contract)" = PASS ] && [ "${n:-0}" -ge 2 ]; then ok; else
    bad "the Voice: example in $doc does not clear voice-contract with its NEVERs (line read: ${line:-none})" \
        "$(printf '%s\n' "$out" | grep -E 'voice-contract' | head -1 | cut -c1-200)"
  fi
done

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

# Run records resolve at .cc-artifacts/taskmaster/craft/, and at taskmaster-docs/craft/ (before 2026-11-14) only while the new file is absent.
d="$WS/craft-doc-move"; mkdir -p "$d/taskmaster-docs/craft"; write_tokens "$d"; cp "$WS/voice/ok/page.html" "$d/page.html"
printf 'Run: 2026-11-01T09:00Z \xc2\xb7 tide-app\n' > "$d/taskmaster-docs/craft/build-task.md"
cat "$WS/voice/ok/craft/build-task.md" >> "$d/taskmaster-docs/craft/build-task.md"
legacy_sum=$(cksum < "$d/taskmaster-docs/craft/build-task.md")
out=$(run_divergence "$d")
if printf '%s\n' "$out" | grep -qE '^ +PASS +voice-contract +.*taskmaster-docs/craft/build-task\.md carries'; then ok; else
  bad "an old-only taskmaster-docs/craft/build-task.md is read" "$(printf '%s\n' "$out" | grep -E 'voice-contract' | head -1)"; fi
mkdir -p "$d/.cc-artifacts/taskmaster/craft"
sed 's/2026-11-01T09:00Z/2026-11-14T09:00Z/' "$d/taskmaster-docs/craft/build-task.md" > "$d/.cc-artifacts/taskmaster/craft/build-task.md"
out=$(run_divergence "$d")
if printf '%s\n' "$out" | grep -qE '^ +PASS +voice-contract +.*\.cc-artifacts/taskmaster/craft/build-task\.md carries' \
   && [ "$(state_of "$out" craft-stamp)" = PASS ] && [ "$(cksum < "$d/taskmaster-docs/craft/build-task.md")" = "$legacy_sum" ]; then ok; else
  bad "the new build task wins, the older one is no craft-stamp candidate, and it stays untouched" \
      "$(printf '%s\n' "$out" | grep -E 'voice-contract|craft-stamp' | head -2 | cut -c1-240)"; fi

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

d="$WS/util-falsepos"; mkdir -p "$d/src" "$d/.cc-artifacts/craft-layer"
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
cat > "$d/.cc-artifacts/craft-layer/waivers.json" <<'JSON'
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

# Hex is read in OKLCH: violet-700/800 (#6d28d9, #5b21b6: 262-263° in sRGB, 293° in OKLCH) are in the band
# and not in DEFAULT_SWATCHES, so they prove the hex path is wired; fuchsia (#d946ef, 292° sRGB, 322° OKLCH) is outside it.
for k in violet:FAIL:6d28d9:5b21b6 fuchsia:PASS:d946ef:c026d3; do
  IFS=: read -r name want cls sty <<EOF
$k
EOF
  d="$WS/util-hex-$name"; mkdir -p "$d/src"
  write_tokens "$d"
  printf 'export default function Page() {\n  return <main><h1 className="bg-[#%s]" style={{ color: '"'"'#%s'"'"' }}>Ship the thing</h1></main>\n}\n' "$cls" "$sty" > "$d/src/page.tsx"
  out=$(run_divergence "$d")
  got=$(state_of "$out" utility-palette)
  if [ "$got" = "$want" ]; then ok; else
    bad "arbitrary-value + inline-style hex path on $name (#$cls, #$sty) expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'utility-palette' | head -1)"
  fi
done

# accent-default-band reads every notation in OKLCH. Tailwind indigo-500 as hex, violet-500 as hsl() and the
# shadcn v3 bare triplet are in the band; fuchsia hex is outside it; zinc (286°, chroma 0.006) is a neutral, not judged.
for k in 'hex-indigo|#6366f1|FAIL' 'hsl-violet|hsl(258 90% 66%)|FAIL' 'triplet-indigo|243 75% 59%|FAIL' \
         'hex-fuchsia|#d946ef|PASS' 'hex-zinc|#18181b|PASS' 'triplet-zinc|240 5.9% 10%|PASS' 'oklch-zinc|oklch(0.21 0.006 285.885)|PASS'; do
  name=${k%%|*}; rest=${k#*|}; val=${rest%%|*}; want=${rest##*|}
  d="$WS/band-$name"; mkdir -p "$d/src"
  printf ':root { --background: 0 0%% 100%%; --primary: %s; --primary-foreground: 0 0%% 98%%; }\n' "$val" > "$d/src/index.css"
  printf '<!doctype html><html lang="en"><body><main><h1>Harbour tide tables</h1></main></body></html>\n' > "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" accent-default-band)
  if [ "$got" = "$want" ] && ! printf '%s\n' "$out" | grep -q 'EXIT=2'; then ok; else
    bad "accent-default-band on --primary: $val expected $want, got $got" \
        "$(printf '%s\n' "$out" | grep -E 'accent-default-band|not measured|EXIT' | head -2)"
  fi
done

# poster-first: the pair differs in the hero's two motion lines; a logo <img> is no still, a chart canvas outside the hero is no hero motion.
for pair in "fixture-poster.html:FAIL" "fixture-poster-clean.html:PASS"; do
  fx=${pair%%:*}; want=${pair##*:}
  [ -f "$FIXTURES/$fx" ] || { bad "poster-first fixture missing" "$fx"; continue; }
  d="$WS/poster-${fx%%.html}"; mkdir -p "$d"; write_tokens "$d"; cp "$FIXTURES/$fx" "$d/page.html"
  out=$(run_divergence "$d")
  got=$(state_of "$out" poster-first)
  if [ "$got" = "$want" ]; then ok; else
    bad "poster-first on $fx expected $want, got $got" "$(printf '%s\n' "$out" | grep -E 'poster-first' | head -1)"
  fi
  [ "$want" = FAIL ] || continue
  line=$(printf '%s\n' "$out" | grep -E '^ +FAIL +poster-first ')
  if printf '%s\n' "$line" | grep -q '<video> at page.html:17' && printf '%s\n' "$line" | grep -q '<canvas> at page.html:18' && ! printf '%s\n' "$line" | grep -q 'page.html:2[0-9]'; then ok; else
    bad "poster-first names the hero <video> and <canvas> and not the chart canvas outside the hero" "$line"
  fi
done

# The plain-what anchor finds a hero no class names; a Poster component is a still, a gradient fallback is not.
for k in poster gradient; do
  d="$WS/poster-anchor-$k"; mkdir -p "$d/src" "$d/craft"; write_tokens "$d"
  printf 'Spine regions: plain-what=#opening, audience=#opening\n' > "$d/craft/build-task.md"
  fb='<OpeningPoster />'; [ "$k" = gradient ] && fb='<div className="h-full bg-gradient-to-b from-teal-700 to-slate-900" />'
  printf 'export default function Opening() {\n  return (\n    <section id="opening">\n      <h1>Tide tables for forty harbours</h1>\n      <Suspense fallback={%s}><Canvas camera={{ fov: 40 }}><Scene /></Canvas></Suspense>\n    </section>\n  )\n}\n' "$fb" > "$d/src/Opening.tsx"
  out=$(run_divergence "$d")
  want=PASS; [ "$k" = gradient ] && want=FAIL
  got=$(state_of "$out" poster-first)
  if [ "$got" = "$want" ]; then ok; else
    bad "poster-first via the plain-what anchor with a $k fallback expected $want, got $got" "$(printf '%s\n' "$out" | grep -E 'poster-first' | head -1)"
  fi
done

# A waiver names one hero element (its kind or file:line); the elements it does not name still fail.
d="$WS/poster-waive"; mkdir -p "$d/.cc-artifacts/craft-layer"; write_tokens "$d"; cp "$FIXTURES/fixture-poster.html" "$d/page.html"
printf '[{"check":"poster-first","value":"video","reason":"the clip is a placeholder until the shoot"}]\n' > "$d/.cc-artifacts/craft-layer/waivers.json"
out=$(run_divergence "$d"); line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +poster-first ')
if [ "$(state_of "$out" poster-first)" = FAIL ] && printf '%s\n' "$line" | grep -q '<canvas> at page.html:18' && ! printf '%s\n' "$line" | grep -q '<video> at'; then ok; else
  bad "a poster-first waiver for the video leaves the hero canvas failing" "$line"; fi
printf '[{"check":"poster-first","value":"video","reason":"the clip is a placeholder until the shoot"},{"check":"poster-first","value":"page.html:18","reason":"a decorative overlay"}]\n' > "$d/.cc-artifacts/craft-layer/waivers.json"
out=$(run_divergence "$d")
if [ "$(state_of "$out" poster-first)" = WAIVED ]; then ok; else
  bad "waivers naming both hero elements waive poster-first" "$(printf '%s\n' "$out" | grep -E 'poster-first' | head -1)"; fi

# The hero <video> tag is read whole past a JSX arrow handler, and a hero file holding a hero class grades its element once.
for k in poster bare; do
  d="$WS/poster-jsx-$k"; mkdir -p "$d/src"; write_tokens "$d"
  attr=' poster="/media/harbour.avif"'; [ "$k" = bare ] && attr=''
  printf 'export default function Hero() {\n  const [ready, setReady] = useState(false)\n  return (\n    <section className="hero">\n      <video autoPlay muted loop playsInline onCanPlay={() => setReady(true)}%s src="/media/harbour.mp4" />\n    </section>\n  )\n}\n' "$attr" > "$d/src/Hero.tsx"
  out=$(run_divergence "$d"); line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +poster-first ')
  if [ "$k" = poster ]; then
    if [ "$(state_of "$out" poster-first)" = PASS ] && printf '%s\n' "$line" | grep -q ' 1 hero video'; then ok; else
      bad "a JSX hero <video> with an arrow handler before its poster passes, graded once" "$line"; fi
  else
    if [ "$(state_of "$out" poster-first)" = FAIL ] && [ "$(printf '%s\n' "$line" | grep -o '<video> at src/Hero.tsx:5' | wc -l)" -eq 1 ]; then ok; else
      bad "a JSX hero <video> with an arrow handler and no poster fails, listed once" "$line"; fi
  fi
done

# A hero class on the <video>/<canvas> itself, behind a `hero-title` h1, is graded in the element around it.
for k in video-bare:FAIL video-poster:PASS canvas-still:PASS canvas-bare:FAIL; do
  name=${k%%:*}; want=${k##*:}
  d="$WS/poster-self-$name"; mkdir -p "$d"; write_tokens "$d"
  case $name in
    video-bare)   body='<video class="hero-video" autoplay muted loop src="/media/harbour.mp4"></video>' ;;
    video-poster) body='<video class="hero-video" autoplay muted loop poster="/media/harbour.avif" src="/media/harbour.mp4"></video>' ;;
    canvas-still) body='<img src="/media/harbour.avif" alt="" width="640" height="360"><canvas id="hero-scene"></canvas>' ;;
    canvas-bare)  body='<canvas id="hero-scene"></canvas>' ;;
  esac
  printf '<!doctype html><html lang="en"><body><main>\n<section>\n<h1 class="hero-title">Tide tables for forty harbours</h1>\n%s\n</section>\n</main></body></html>\n' "$body" > "$d/page.html"
  out=$(run_divergence "$d"); line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +poster-first ')
  if [ "$(state_of "$out" poster-first)" = "$want" ] && { [ "$want" = PASS ] || printf '%s\n' "$line" | grep -q 'page.html:4'; }; then ok; else
    bad "poster-first with the hero class on the motion element itself ($name) expected $want naming page.html:4" "$line"; fi
done

# The eyebrow row skips table headers, labels and buttons set in caps; three caps lines in body copy still fire it.
for k in th:PASS p:FAIL; do
  tag=${k%%:*}; want=${k##*:}
  d="$WS/caps-$tag"; mkdir -p "$d"; write_tokens "$d"
  if [ "$tag" = th ]; then
    printf '<!doctype html><html lang="en"><body><main><h1>Invoices</h1><form><label>DUE DATE <input name="due"></label><button type="submit">SAVE AND CLOSE</button></form>\n<table><thead><tr><th>INVOICE NO</th><th>DUE DATE</th><th>NET TOTAL</th></tr></thead><tbody><tr><td>A-1</td><td>1 Dec</td><td>40</td></tr></tbody></table></main></body></html>\n' > "$d/page.html"
  else
    printf '<!doctype html><html lang="en"><body><main><p>INVOICE NO</p><h2>Invoices</h2><p>DUE DATE</p><h2>Dates</h2><p>NET TOTAL</p><h2>Totals</h2></main></body></html>\n' > "$d/page.html"
  fi
  out=$(run_divergence "$d")
  if [ "$(state_of "$out" copy-register)" = "$want" ]; then ok; else
    bad "copy-register on caps text in <$tag> expected $want" "$(printf '%s\n' "$out" | grep -E 'copy-register' | head -1)"; fi
done

# The run log's last row is this run's own only when it carries this run's draw or Run: stamp (slug and date).
# audit.md appends the row AFTER the audit, so at audit time a matching hue there is the previous run: a repeat.
log_project() { # dir slug-in-last-row date-in-last-row [stamp]
  mkdir -p "$1/.cc-artifacts/craft-layer" "$1/src"; printf ':root { --primary: oklch(0.55 0.15 250); }\n' > "$1/src/index.css"
  printf '<!doctype html><html lang="en"><body><main><h1>Harbour tide tables</h1></main></body></html>\n' > "$1/page.html"
  printf '| date | brief-slug | hue-family | type-strategy | spine | signature | draw |\n|---|---|---|---|---|---|---|\n| 2026-11-01 | ferry-app | green | Fraunces | x | y | a / b / c / d / e |\n| %s | %s | blue | Fraunces | x | y | a / b / c / d / e |\n' "$3" "$2" > "$1/.cc-artifacts/craft-layer/run-log.md"
  if [ -n "${4:-}" ]; then mkdir -p "$1/craft"; printf '# Offer contract\nRun: %s\n' "$4" > "$1/craft/offer-contract.md"; fi
}
for k in 'previous|tide-app|2026-11-08||FAIL' 'own-stamp|tide-app|2026-11-11|2026-11-11T09:30Z · tide-app · ROOT|PASS' \
         'other-slug|ferry-app|2026-11-11|2026-11-11T09:30Z · tide-app · ROOT|FAIL'; do
  IFS='|' read -r name slug date stamp want <<EOF
$k
EOF
  d="$WS/log-$name"; log_project "$d" "$slug" "$date" "${stamp/ROOT/$WS/log-$name}"
  out=$(run_divergence "$d")
  if [ "$(state_of "$out" hue-repeat)" = "$want" ]; then ok; else
    bad "hue-repeat with a blue last row ($name) expected $want" "$(printf '%s\n' "$out" | grep -E 'hue-repeat|note' | head -3)"; fi
done
# A run log only in .craft-layer/ (before 2026-11-14) is still the project memory; a new log, once written, replaces it.
d="$WS/log-legacy"; log_project "$d" tide-app 2026-11-08; mv "$d/.cc-artifacts/craft-layer" "$d/.craft-layer"; rmdir "$d/.cc-artifacts"
legacy_sum=$(cksum < "$d/.craft-layer/run-log.md")
out=$(run_divergence "$d")
if [ "$(state_of "$out" hue-repeat)" = FAIL ] && printf '%s\n' "$out" | grep -q 'sed -n .1,20p. \.craft-layer/run-log\.md'; then ok; else
  bad "an old-only .craft-layer/run-log.md is read (blue last row → hue-repeat FAIL naming that file)" "$(printf '%s\n' "$out" | grep -E 'hue-repeat' | head -1 | cut -c1-240)"; fi
mkdir -p "$d/.cc-artifacts/craft-layer"; head -3 "$d/.craft-layer/run-log.md" > "$d/.cc-artifacts/craft-layer/run-log.md"
out=$(run_divergence "$d")
if [ "$(state_of "$out" hue-repeat)" = PASS ] && [ "$(cksum < "$d/.craft-layer/run-log.md")" = "$legacy_sum" ]; then ok; else
  bad "a new run log holding only the green row wins over the old one (hue-repeat PASS), and the old log stays untouched" "$(printf '%s\n' "$out" | grep -E 'hue-repeat' | head -1 | cut -c1-240)"; fi

# asset-manifest: three heavy assets (a video by kind, a 150 KB image, a 120 KB CSS texture); a 2 KB icon and a remote font are not heavy.
asset_project() { # dir
  mkdir -p "$1/public/media" "$1/public/img" "$1/src"; write_tokens "$1"
  head -c 4096 /dev/zero > "$1/public/media/harbour.mp4"
  head -c 153600 /dev/zero > "$1/public/img/hero.avif"
  head -c 2048 /dev/zero > "$1/public/img/icon.png"
  head -c 122880 /dev/zero > "$1/public/img/texture.jpg"
  cat > "$1/page.html" <<'HTML'
<!doctype html><html lang="en"><head><link rel="preload" href="https://fonts.example.com/tide.woff2" as="font"></head>
<body><main><section><h1>Tideline</h1><video muted loop src="/media/harbour.mp4" poster="/img/hero.avif"></video>
<img src="/img/icon.png" alt=""></section></main></body></html>
HTML
  printf '.band { background-image: url(/img/texture.jpg); }\n' > "$1/src/site.css"
}
d="$WS/assets-bad"; asset_project "$d"
cat > "$d/ASSETS.md" <<'MD'
# Assets
- ref: public/media/harbour.mp4 · origin: third-party · licence-class: CC-BY · source: Pexels clip 4471
- ref: public/img/hero.avif · origin: third-party · licence-class: unknown · source: found online
MD
out=$(run_divergence "$d")
line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +asset-manifest ')
if [ "$(state_of "$out" asset-manifest)" = FAIL ] && printf '%s\n' "$line" | grep -q 'hero.avif.*no licence-class' \
   && printf '%s\n' "$line" | grep -q 'texture.jpg.*has no manifest record' && ! printf '%s\n' "$line" | grep -qE 'icon\.png|harbour\.mp4 \('; then ok; else
  bad "asset-manifest fails the unknown licence and the unlisted CSS texture, and leaves the listed video and the 2 KB icon alone" "$line"
fi

d="$WS/assets-ok"; asset_project "$d"
cat > "$d/ASSETS.md" <<'MD'
| ref | origin | licence-class | source |
| --- | --- | --- | --- |
| public/media/harbour.mp4 | third-party | CC-BY | Pexels clip 4471, credited in the footer |
| public/img/hero.avif | third-party | permissive (MIT) | the harbour board's press kit |

- ref: public/img/texture.jpg
  origin: first-party
  source: scanned in-house from the 1962 chart
MD
out=$(run_divergence "$d")
if [ "$(state_of "$out" asset-manifest)" = PASS ]; then ok; else
  bad "asset-manifest passes a complete manifest (table rows and an indented first-party record)" "$(printf '%s\n' "$out" | grep -E 'asset-manifest' | head -1)"
fi
d="$WS/assets-json"; asset_project "$d"
printf '[{"ref":"media/harbour.mp4","origin":"third-party","licence-class":"CC-BY","source":"Pexels"},{"ref":"img/hero.avif","origin":"commissioned","licence":"commissioned","source":"Ines Faria, 2026"},{"path":"img/texture.jpg","origin":"first-party","source":"in-house"}]\n' > "$d/public/CREDITS.json"
out=$(run_divergence "$d")
if [ "$(state_of "$out" asset-manifest)" = PASS ]; then ok; else
  bad "asset-manifest reads a CREDITS.json in the asset directory" "$(printf '%s\n' "$out" | grep -E 'asset-manifest' | head -1)"
fi
d="$WS/assets-none"; asset_project "$d"
out=$(run_divergence "$d")
if [ "$(state_of "$out" asset-manifest)" = FAIL ] && printf '%s\n' "$out" | grep -q 'no manifest (ASSETS'; then ok; else
  bad "asset-manifest fails heavy assets with no manifest at all" "$(printf '%s\n' "$out" | grep -E 'asset-manifest' | head -1)"
fi
# A waiver names one asset; the assets it does not name still fail.
d="$WS/assets-waive"; asset_project "$d"; mkdir -p "$d/.cc-artifacts/craft-layer"
printf -- '- ref: public/img/hero.avif · origin: third-party · licence-class: unknown · source: found online\n' > "$d/ASSETS.md"
printf '[{"check":"asset-manifest","value":"harbour.mp4","reason":"re-shoot pending, record lands with it"}]\n' > "$d/.cc-artifacts/craft-layer/waivers.json"
out=$(run_divergence "$d"); line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +asset-manifest ')
if [ "$(state_of "$out" asset-manifest)" = FAIL ] && printf '%s\n' "$line" | grep -q 'texture.jpg' && printf '%s\n' "$line" | grep -q 'hero.avif' \
   && ! printf '%s\n' "$line" | grep -q 'harbour.mp4 ('; then ok; else
  bad "an asset-manifest waiver for the first failing asset (harbour.mp4) leaves hero.avif and texture.jpg failing" "$line"; fi
printf '[{"check":"asset-manifest","value":"hero.avif","reason":"licence being cleared"},{"check":"asset-manifest","value":"texture.jpg","reason":"scanned in-house"},{"check":"asset-manifest","value":"harbour.mp4","reason":"re-shoot pending"}]\n' > "$d/.cc-artifacts/craft-layer/waivers.json"
out=$(run_divergence "$d")
if [ "$(state_of "$out" asset-manifest)" = WAIVED ]; then ok; else
  bad "waivers naming every failing asset waive asset-manifest" "$(printf '%s\n' "$out" | grep -E 'asset-manifest' | head -1)"; fi

# A licence-class must open with a fixed token, and NC/ND or non-commercial is none of them.
d="$WS/assets-nc"; asset_project "$d"
cat > "$d/ASSETS.md" <<'MD'
- ref: public/media/harbour.mp4 · origin: third-party · licence-class: CC-BY-NC · source: Vimeo clip 88
- ref: public/img/hero.avif · origin: third-party · licence-class: non-commercial · source: a photographer's site
- ref: public/img/texture.jpg · origin: first-party · source: scanned in-house
MD
out=$(run_divergence "$d"); line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +asset-manifest ')
if [ "$(state_of "$out" asset-manifest)" = FAIL ] && printf '%s\n' "$line" | grep -q 'CC-BY-NC' && printf '%s\n' "$line" | grep -q '"non-commercial"'; then ok; else
  bad "asset-manifest fails CC-BY-NC and non-commercial on commercial builds" "$line"; fi

# A record is matched on a whole path tail, full path first: hero-bg.jpg is no record for bg.jpg, a prose mention no record at all.
d="$WS/assets-tail"; mkdir -p "$d/public/img"; write_tokens "$d"
head -c 153600 /dev/zero > "$d/public/img/bg.jpg"; head -c 153600 /dev/zero > "$d/public/img/tide.jpg"
printf '<!doctype html><html lang="en"><body><main><h1>Tideline</h1><img src="/img/bg.jpg" alt=""><img src="/img/tide.jpg" alt=""></main></body></html>\n' > "$d/page.html"
cat > "$d/ASSETS.md" <<'MD'
- ref: public/img/hero-bg.jpg · origin: third-party · licence-class: CC0 · source: Unsplash 1234
- ref: tide.jpg · origin: third-party · licence-class: CC0 · source: Unsplash 5678
MD
out=$(run_divergence "$d"); line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +asset-manifest ')
if [ "$(state_of "$out" asset-manifest)" = FAIL ] && printf '%s\n' "$line" | grep -q '/img/bg.jpg .*has no manifest record' && ! printf '%s\n' "$line" | grep -q 'tide.jpg ('; then ok; else
  bad "asset-manifest fails bg.jpg beside a hero-bg.jpg record, and matches tide.jpg by its basename" "$line"; fi
for k in record prose; do
  d="$WS/assets-$k-first"; asset_project "$d"
  { printf '# Assets\nThe hero clip harbour.mp4 was re-cut in November; its record is below.\n\n| ref | origin | licence-class | source |\n| --- | --- | --- | --- |\n'
    [ "$k" = record ] && printf '| public/media/harbour.mp4 | third-party | CC-BY | Pexels clip 4471 |\n'
    printf '| public/img/hero.avif | commissioned | commissioned | Ines Faria, 2026 |\n| public/img/texture.jpg | first-party | | scanned in-house |\n'; } > "$d/ASSETS.md"
  out=$(run_divergence "$d"); line=$(printf '%s\n' "$out" | grep -E '^ +[A-Z]+ +asset-manifest ')
  if [ "$k" = record ]; then
    if [ "$(state_of "$out" asset-manifest)" = PASS ]; then ok; else bad "a prose line mentioning harbour.mp4 above its table row is not taken for its record" "$line"; fi
  else
    if [ "$(state_of "$out" asset-manifest)" = FAIL ] && printf '%s\n' "$line" | grep -q 'harbour.mp4'; then ok; else bad "harbour.mp4 named only in prose still fails" "$line"; fi
  fi
done

d="$WS/assets-light"; mkdir -p "$d/public/img"; write_tokens "$d"; head -c 2048 /dev/zero > "$d/public/img/icon.png"
printf '<!doctype html><html lang="en"><body><main><h1>Tideline</h1><img src="/img/icon.png" alt=""></main></body></html>\n' > "$d/page.html"
out=$(run_divergence "$d")
if [ "$(state_of "$out" asset-manifest)" = SKIP ]; then ok; else
  bad "asset-manifest SKIPs a page whose only asset is light" "$(printf '%s\n' "$out" | grep -E 'asset-manifest' | head -1)"
fi

d="$WS/coverage"; mkdir -p "$d/src"
printf ':root { --primary: oklch(0.55 0.17 145); }\n' > "$d/src/index.css"
cat > "$d/page.html" <<'HTML'
<!doctype html><html lang="en"><body><main><h1>Ship faster</h1></main></body></html>
HTML
out=$(run_divergence "$d")
printf '%s\n' "$out" | grep -qE 'coverage: [0-9]+/[0-9]+ assertion' && ok || \
  bad "no coverage line on a partially-skipped run" "$(printf '%s\n' "$out" | tail -3)"
# The coverage line counts the rows as printed, and the green names that count, never the total.
graded=$(printf '%s\n' "$out" | grep -cE '^ +(PASS|FAIL|WAIVED) ' || true)
skipped=$(printf '%s\n' "$out" | grep -cE '^ +SKIP ' || true)
if [ "$skipped" -gt 0 ] && printf '%s\n' "$out" | grep -qx "coverage: $graded/$((graded + skipped)) assertion(s) graded, $skipped SKIP (.*)" \
   && printf '%s\n' "$out" | grep -qx "OK: the build clears the $graded divergence assertion(s) that could be graded."; then ok; else
  bad "a mostly-skipped run's coverage line and terminator speak for the $graded graded of $((graded + skipped)) rows only" \
      "$(printf '%s\n' "$out" | tail -2)"
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

# The dark theme is the rule named `.dark`, not the first text match: stock shadcn v4
# puts `@custom-variant dark (&:is(.dark *))` above it, and a text search graded :root twice.
contrast_in() { ( cd "$1" && node "$CONTRAST" 2>&1; printf 'EXIT=%s\n' "$?" ); }
dark_of() { printf '%s\n' "$1" | sed -n '/^DARK$/,/^coverage/p'; }
d="$WS/contrast-dark"; mkdir -p "$d/src"
cat > "$d/src/index.css" <<'CSS'
@custom-variant dark (&:is(.dark *));
/* .dark { --foreground: oklch(1 0 0); } */
:root { --background: oklch(1 0 0); --foreground: oklch(0.145 0 0); --input: oklch(0.4 0 0); }
.dark { --background: oklch(0.145 0 0); --foreground: oklch(0.2 0 0); --input: oklch(1 0 0 / 10%); }
CSS
out=$(contrast_in "$d")
if dark_of "$out" | grep -qE 'FAIL body text +1\.[0-9]+:1'; then ok; else
  bad "an unreadable dark body text was not failed under @custom-variant dark" "$(dark_of "$out" | head -3)"
fi
if printf '%s\n' "$out" | grep -q 'EXIT=1'; then ok; else bad "a failing dark theme did not exit 1" "$(printf '%s\n' "$out" | tail -2)"; fi
# A 10% white border on a near-black ground is about 1.3:1; read as opaque white it "passed" at 19.8:1.
if dark_of "$out" | grep -qE 'FAIL control border +1\.[0-9]+:1'; then ok; else
  bad "a translucent border was not composited over its surface" "$(dark_of "$out" | grep 'control border' | head -1)"
fi

d="$WS/contrast-nodark"; mkdir -p "$d/src"
cat > "$d/src/index.css" <<'CSS'
:root { --background: #fff; --foreground: #000; }
CSS
out=$(contrast_in "$d")
if dark_of "$out" | grep -q 'not measured: no .dark' && ! dark_of "$out" | grep -qE 'PASS|FAIL'; then ok; else
  bad "a build with no dark rule was given dark verdicts" "$(dark_of "$out" | head -3)"
fi
if printf '%s\n' "$out" | grep -qE 'PASS body text +21\.00:1' && printf '%s\n' "$out" | grep -q 'EXIT=0'; then ok; else
  bad "hex tokens were not measured (#000 on #fff is 21.00:1)" "$(printf '%s\n' "$out" | grep -E 'body text|EXIT' | head -2)"
fi

# Notations the same colour can be written in must give the same ratio, and never NaN.
d="$WS/contrast-notations"; mkdir -p "$d/src"
for v in 'oklch(62.8% 0.2577 29.23)|oklch(0.628 0.2577 29.23deg)' 'hsl(0 100% 50%)|0 100% 50%' 'rgb(255 0 0)|#f00' 'hsla(0, 100%, 50%, 1)|#ff0000ff'; do
  printf ':root { --background: oklch(1 0 none); --foreground: %s; }\n[data-theme="dark"] { --background: #000; --foreground: %s; }\n' "${v%%|*}" "${v##*|}" > "$d/src/index.css"
  out=$(contrast_in "$d")
  if printf '%s\n' "$out" | grep -qE 'FAIL body text +4\.00:1' && dark_of "$out" | grep -qE 'PASS body text +5\.25:1' && ! printf '%s\n' "$out" | grep -q NaN; then ok; else
    bad "pure red written as $v did not measure 4.00:1 on white and 5.25:1 on black" "$(printf '%s\n' "$out" | grep 'body text')"
  fi
done
cat > "$d/src/index.css" <<'CSS'
@media (prefers-color-scheme: dark) { :root { --background: #000; --foreground: #fff; } }
:root { --background: #fff; --foreground: var(--brand-ink); }
CSS
out=$(contrast_in "$d")
if printf '%s\n' "$out" | sed -n '/^LIGHT$/,/^DARK$/p' | grep -q 'body text .*not measured (--foreground is not a colour value'; then ok; else
  bad "a var() token was not reported as not measured" "$(printf '%s\n' "$out" | grep 'body text' | head -1)"
fi
if dark_of "$out" | grep -qE 'PASS body text +21\.00:1'; then ok; else
  bad "a prefers-color-scheme: dark rule was not read as the dark theme" "$(dark_of "$out" | head -2)"
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

# Nothing is installed (no network): an existing Playwright is used, and only if its bundled Chromium or a system Chrome launches.
how_launches() { # node_modules-dir -> prints "bundled" or "chrome" for the first that starts
  node -e '
    const t = setTimeout(() => process.exit(3), 30000)
    const { chromium } = require(process.argv[1] + "/playwright")
    ;(async () => {
      for (const [how, o] of [["bundled", {}], ["chrome", { channel: "chrome" }]]) {
        try { const b = await chromium.launch(o); await b.close(); console.log(how); clearTimeout(t); process.exit(0) } catch {}
      }
      process.exit(1)
    })()
  ' "$1" 2>/dev/null
}
PW=""; HOW=""
for nm in ${CRAFT_GATES_PLAYWRIGHT:-} $(ls -dt "$HOME"/.npm/_npx/*/node_modules 2>/dev/null); do
  [ -f "$nm/playwright/cli.js" ] || continue
  if HOW=$(how_launches "$nm"); then PW="$nm"; break; fi
done
channel=""; [ "$HOW" = chrome ] && channel=chrome

if [ -z "$PW" ]; then
  printf 'SKIP  browser controls: no Playwright whose Chromium (bundled, or a system Chrome channel) launches (looked in $CRAFT_GATES_PLAYWRIGHT and ~/.npm/_npx) — the fixture-motion-* and fixture-triggers controls did NOT run\n'
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

  # Clean twins: the page with its `<!-- defect -->` lines deleted, so it differs from the defective one in nothing else.
  for fx in fixture-motion-css fixture-triggers; do grep -v '<!-- defect -->' "$FIXTURES/$fx.html" > "$WS/$fx-clean.html"; done

  # rm_verdicts <fixture> -> one "<key> <passed|failed|…> <error text>" line per test (a fixture, else a derived twin in $WS).
  rm_verdicts() {
    local run="$WS/rm-${1%%.html}"; mkdir -p "$run"
    local page="$FIXTURES/$1"; [ -f "$page" ] || page="$WS/$1"
    local url; url=$(node -p 'require("url").pathToFileURL(process.argv[1]).href' "$page")
    ( cd "$run" && BASE_URL="$url" CRAFT_BROWSER_CHANNEL="$channel" NODE_PATH="$shim" PLAYWRIGHT_JSON_OUTPUT_NAME="$run/report.json" \
        node "$PW/playwright/cli.js" test --config "$GATES/playwright.config.ts" \
        --grep 'prefers-reduced-motion|floods the tab order|phone @200|High Contrast' --reporter=json >/dev/null 2>"$run/stderr" )
    node -e '
      const keys = [["page renders", "css"], ["JS motion", "js"], ["canvas:", "canvas"],
                    ["smooth-scroll:", "smooth"], ["video:", "video"], ["no interactive grid", "grid"],
                    ["no horizontal overflow at phone", "phone"], ["content survives", "forced"]]
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
    "fixture-motion-video-clean.html:video=passed" \
    "fixture-motion-css.html:css=failed" \
    "fixture-motion-css-clean.html:css=passed" \
    "fixture-triggers.html:grid=failed phone=failed forced=passed" \
    "fixture-triggers-clean.html:grid=passed phone=passed forced=passed css=passed"
  do
    fx=${pair%%:*}; want=${pair#*:}
    [ -f "$FIXTURES/$fx" ] || [ -f "$WS/$fx" ] || { bad "browser control fixture missing" "$fx"; continue; }
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
      fixture-motion-css.html)    need='css|p#slide: @keyframes slide animates transform
css|div#reveal\.reveal: a transform transition ran
css|a#lift\.card: a transform transition ran' ;;
      fixture-triggers.html)      need='grid|DIV\[grid\] contributes 10 tab stops
phone|overflow 4[0-9]{2}>320' ;;
      *)                          need="" ;;
    esac
    while IFS= read -r n; do
      [ -n "$n" ] || continue
      k=${n%%|*}; what=${n#*|}
      if printf '%s\n' "$out" | awk -v k="$k" '$1 == k' | grep -qE "$what"; then ok; else
        bad "browser control '$k' on $fx did not name $what" \
            "$(printf '%s\n' "$out" | awk -v k="$k" '$1 == k' | cut -c1-240)"
      fi
    done <<EOF
$need
EOF
    # The silent neighbours: a fade, a transition list that only names transform, a 0.01ms snap.
    if [ "$fx" = fixture-motion-css.html ] && printf '%s\n' "$out" | awk '$1 == "css"' | grep -qE '#fade|#tw|#snap'; then
      bad "reduced-motion 'css' on $fx named a silent neighbour (#fade, #tw or #snap)" "$(printf '%s\n' "$out" | awk '$1 == "css"' | cut -c1-300)"
    elif [ "$fx" = fixture-motion-css.html ]; then ok; fi
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

# The concept deck's worked draw must still compute: each line's n is its axis's option count, the
# index and carry are the arithmetic, the option named is that index of that axis, the seed is the
# stated cksum, and the lens is that index of creative-director's list. An axis gaining an option
# changed none of this text before, so the example silently taught the wrong draw.
DECK="$here/../../skills/creative-direction/references/concept-deck.md"
AGENT="$here/../../agents/creative-director.md"
deck_example_errors() { # deck agent -> one line per error, nothing when the example holds
  node -e '
    const fs = require("fs"), cp = require("child_process")
    const deck = fs.readFileSync(process.argv[1], "utf8"), agent = fs.readFileSync(process.argv[2], "utf8")
    const err = (m) => console.log(m)
    const axes = []
    for (const sec of deck.split(/^## /m).slice(1)) {
      if (!/^Axis \d+ — /.test(sec)) continue
      axes.push([...sec.matchAll(/^- \*\*(.+?)\*\* —/gm)].map((m) => m[1]))
    }
    const counts = axes.map((a) => a.length).join(" ")
    const loop = deck.match(/for n in ([\d ]+); do/)
    if (!loop || loop[1].trim() !== counts) err(`loop n list "${loop && loop[1]}" != option counts "${counts}"`)
    const prose = deck.replace(/\s+/g, " ").match(/so n is ([\d, ]+?) down the axes/)
    if (!prose || prose[1].replace(/,/g, "") !== counts) err(`prose n list "${prose && prose[1]}" != option counts "${counts}"`)
    const lines = [...deck.matchAll(/^\s*axis (\d+): +(\d+) mod (\d+) = (\d+), carry +(\d+) -> (.+)$/gm)]
    if (lines.length !== axes.length) err(`example shows ${lines.length} axes, deck has ${axes.length}`)
    let carry = null
    for (const [, i, a, n, k, c, name] of lines) {
      const opts = axes[i - 1] || [], A = BigInt(a), N = BigInt(n)
      if (carry !== null && A !== carry) err(`axis ${i}: starts from ${a}, previous carry was ${carry}`)
      if (Number(n) !== opts.length) err(`axis ${i}: n=${n} but the axis lists ${opts.length} options`)
      if (A % N !== BigInt(k) || A / N !== BigInt(c)) err(`axis ${i}: ${a} mod ${n} is ${A % N}, carry ${A / N}`)
      if (opts[k] !== name.trim()) err(`axis ${i}: option ${k} is "${opts[k]}", example names "${name.trim()}"`)
      carry = BigInt(c)
    }
    const lens = deck.match(/^\s*lens: +(\d+) mod 4 = (\d+) +-> (.+)$/m)
    const lenses = [...(agent.split("ROTATE the lens")[1] || "").split("Name the lens")[0].matchAll(/^\s+- \*\*(.+?)\*\* —/gm)].map((m) => m[1])
    if (!lens || BigInt(lens[1]) !== carry || Number(lens[1]) % 4 !== Number(lens[2]) || lenses[lens[2]] !== lens[3].trim())
      err(`lens line "${lens && lens[0].trim()}" disagrees with carry ${carry} and lens list ${lenses.join(", ")}`)
    const sd = deck.match(/brief \x27(.+?)\x27, date (\S+)\n\s*seed = .*= (\d+)/)
    const sum = sd && cp.execFileSync("cksum", { input: sd[1] + sd[2] }).toString().split(" ")[0]
    if (!sd || sum !== sd[3] || !lines[0] || lines[0][2] !== sd[3]) err(`seed line does not match cksum (${sum})`)
  ' "$1" "$2"
}
if out=$(deck_example_errors "$DECK" "$AGENT") && [ -z "$out" ]; then ok
else bad "concept-deck worked example: the shipped deck's example holds" "$out"; fi
GROWN="$WS/concept-deck-grown.md"
awk '{ print } /^- \*\*Stillness by design\*\* —/ { print "- **Motion as wayfinding** — a synthetic eighth option for the harness." }' "$DECK" > "$GROWN"
if out=$(deck_example_errors "$GROWN" "$AGENT") && printf '%s\n' "$out" | grep -q 'axis 4: n=7 but the axis lists 8'; then ok
else bad "concept-deck worked example: an axis gaining an option fails it" "${out:-no error reported}"; fi

SNAP_AFTER=$(git_snap)
if [ "$SNAP_BEFORE" != "$SNAP_AFTER" ]; then
  bad "harness mutated the repository working tree" \
      "$(diff <(printf '%s\n' "$SNAP_BEFORE") <(printf '%s\n' "$SNAP_AFTER") | head -5)"
fi

printf '\ncraft-gates: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
