# craft-layer shell harnesses: the comment text moved out of the code (2026-10-04)

The text below was moved verbatim on 2026-10-04 from the files named in the `##` headings, with only each comment's `# ` leader removed; the lines each file kept are not repeated here. A pointer by name was left in each file, `# Why, limits, history: rationale/derivations/plugin-craft-layer.md § <heading>`. Standing: `recorded` — no gate reads this file, and its dates, measurements and citations are as they stood on the day it moved.

## plugins/craft-layer/scripts/__tests__/craft-gates.test.sh

### Header

```text
Tests plugins/craft-layer/template/craft-gates/divergence.mjs and contrast.mjs,
and gates.spec.ts's reduced-motion block when a local Playwright can run it.

Picked up automatically by the repo's "Plugin author-time lint + harness tests"
CI step, which globs plugins/*/scripts/__tests__/*.test.sh.

WHY THIS FILE EXISTS. craft-layer shipped 1,321 lines of gate code and seven
control fixtures with nothing that ran them. The gates were `recorded` tier
wearing a `gate` badge — the exact failure CLAUDE.md's has-teeth convention
forbids, in the plugin whose own doctrine names it. Every fixture pair below
was authored as a control (defective / clean, same copy, one variable changed)
and then verified BY HAND, once, by whoever wrote it. This makes them execute.

Six sections:
The fixtures live HERE, beside this harness, not in template/craft-gates/. They
are this file's inputs and nothing else reads them, so shipping 64K of them to
every installer inside the directory commands/audit.md says to run from — and
never to copy — bought nobody anything (moved 2026-09-22).

  1. FIXTURE CONTROLS — each defective fixture must FAIL the check it was
     built to trip, and its clean twin must PASS. A gate that greens both is
     measuring nothing; a gate that reds both is a gate nobody will keep on.
  2. COVERAGE HONESTY — the terminator must not print an unqualified green
     when every assertion SKIPped. This is the assertion that would have
     caught the "OK: the build clears every divergence assertion" printed over
     1-of-9 graded.
  3. NOT-MEASURED — a missing token source must exit 2, per the file's own
     header contract. contrast.mjs must not print a green having resolved
     zero pairings.
  4. FAIL-OPEN / HYGIENE — the gates must not write into the project they
     measure, and must not crash on absent optional artifacts.
  5. REDUCED-MOTION RUNTIME — the JS/canvas/smooth-scroll/video half of the
     reduced-motion trigger, run through Playwright against fixture-motion-*.
     Needs a local Playwright; without one it prints SKIP and runs nothing.
  6. TYPE CHECK — gates.spec.ts under `tsc --strict`, when a local typescript and
     Playwright's types are found; SKIP otherwise.

The harness snapshots `git status --porcelain` before and after and asserts it
is byte-identical: these gates read a build tree, and proving they only read is
part of the test.
```

### Section banners

```text
---------------------------------------------------------------------------
1. FIXTURE CONTROLS
---------------------------------------------------------------------------
---------------------------------------------------------------------------
2. COVERAGE HONESTY
---------------------------------------------------------------------------
---------------------------------------------------------------------------
3. NOT-MEASURED
---------------------------------------------------------------------------
---------------------------------------------------------------------------
4. FAIL-OPEN / HYGIENE
---------------------------------------------------------------------------
---------------------------------------------------------------------------
5. REDUCED-MOTION RUNTIME CONTROLS (needs a browser; SKIPs without one)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
6. TYPE CHECK (needs typescript locally; SKIPs without it)
---------------------------------------------------------------------------
---------------------------------------------------------------------------
```

### write_tokens

```text
A token source that resolves, so token-dependent assertions do not short out
the run before the check under test is reached.
```

### run_divergence

Editor's note (2026-10-04): stale as moved — the function prints the report first and its `EXIT=` line last.

```text
Run divergence.mjs inside a disposable project root. Echoes exit code on the
first line, then the full report, so callers can assert on both.
```

### composition-shape

```text
composition-shape: the defective fixture must FAIL, its clean twin must PASS.
These two differ ONLY in spatial structure — same six sections, same copy — so
a gate that returns the same verdict for both has stopped measuring shape.
The defective shape fixture must make the RUN fail, not merely report a FAIL
row. A gate whose failing assertion still exits 0 cannot block anything.
```

### spine-register

```text
spine-register: the defective fixture answers the buyer-facing spine slots in
an integrator's register and must FAIL; the clean twin and the false-positive
control must both PASS. The falsepos fixture is the important one — a register
check that fires on a correct limits list teaches builds to strip the very
concreteness the offer contract asks for.
The regions line is COMMA-separated and its anchors are the fixture's own
element ids, which differ between the two shapes — the register pair answers
the buyer slots inside `hero` and `status-quo`, the false-positive control
names them directly. Getting this wrong SKIPs the check, which is why the
SKIP branch below is reported as a failure rather than tolerated.
spine-register needs the build task's `Spine regions:` line to know which
region answers which slot; without it the check SKIPs and measures nothing.
A SKIP here is not a pass — it is the check declining to measure. Report it
as the coverage failure it is, with the reason the gate gave.
```

### emoji-as-icon

```text
emoji-as-icon: pictographs standing in for the icon system. The pair differs
only in icon treatment (emoji vs a decided SVG system); both carry the ™ and
© marks every real page ships, which must never fire. The falsepos control's
only pictographs sit inside a customer's quoted testimonial plus a ☎︎ the
author explicitly rendered text-style — a gate that fires on those grades
the customer's voice and the legal line, not the build's icon decision.
...and a waived build must report WAIVED, not FAIL — the new assertions ride
the same waiver lane as every other one, and this is the control that proves
the lane is actually connected.
```

### copy-register

```text
copy-register: the machine-copy lexicon. The pair shares product, facts and
prices; only the register differs. The clean control carries "seamless" as a
lone adjective on purpose — the check is multi-word phrases only, and firing
on a single word would turn it into a vocabulary ban.
```

### voice-contract

```text
voice-contract: the four states, in the order they cost. No build task is a
SKIP (a build is never failed for not saving a file); a build task that EXISTS
and omits the line is the finding; a line with no NEVER has no machine-readable
half; a line with NEVERs passes and hands those literals to copy-register.
...and the NEVER literals must actually reach copy-register. A `Voice:` line the
gate parses and then never grades against is the same shape as the frozen
lexicon this pair replaced: a rule recorded, read by nothing.
The control: same page, same line, the banned string rewritten. Both must clear.
```

### Chrome rows

```text
The three MECHANICAL chrome rows the registry's own note names — the ALL-CAPS
eyebrow, the middle-dot meta string and the trailing arrow. Before they were
lexicon rows, a page reproducing nine registry entries verbatim cleared every
assertion the gate could grade. The clean twin is the false-positive control
and the important half: ONE arrow, ONE middle dot, sentence-case labels. A
`min`-less pattern reds it, and a red control is a gate nobody keeps on.
...and all three must be named, not just whichever fires first. A loader that
reads one row of three is the defect this replaced, one level down.
```

### The live registry

```text
THE LOADER READS THE REGISTRY, not a frozen copy of it. This is the assertion
that would have caught the original finding: the lexicon was six phrases frozen
into the script beside a 13,951-char registry it never opened. With the plugin
root set the run must say `live registry`, and the pattern count must equal the
rows the reference actually carries — a silent fallback to the snapshot reads
identical in every other line of the report.
The live-only rows (added to the registry after the frozen snapshot) are graded by
nothing above: run_divergence runs without the plugin root, so every other fixture
reads the snapshot. This pair runs LIVE. The defective page must name all three
corpus rows; the clean twin carries each row's false positive — "Agentic" opening a
long sentence, humans and agents in one line but not the formula, design engineers
outside the registry headline — and must PASS.
```

### font-anti-corpus

```text
font-anti-corpus must see the family however the project declares it. The two
forms below are the ones the check was blind to: Tailwind v4 emits no
`font-family` line at all, and `font-family: var(--font-sans)` hides the name
behind an indirection. Both used to record "no non-generic font declared" —
so the way to pass the type gate was to never choose a typeface.
A build that declares no typeface at all still SKIPs — that is honest, and the
coverage line is what stops it reading as a pass.
```

### utility-palette and utility-font

```text
utility-palette / utility-font: the Tailwind/JSX blind spot. The palette and
the type reach the page through `className` strings and a font import, so the
two token-reading assertions never see them. The defective fixture below is the
case that used to print "OK: the build clears the N divergence assertion(s)
that could be graded" — which is why this control also asserts that
accent-default-band still PASSes and font-anti-corpus still SKIPs on it. If a
later change makes those two catch this page, this block should be revisited,
not deleted: two assertions reporting the same finding twice is its own defect.
a cleanly derived green accent token no element references
The clean twin: same page, same sections, same shape — a derived green applied
through arbitrary values and a family with an argument behind it. The chart
hexes are the false-positive control on the hue path: legitimate colour outside
the band must never register.
The false-positive guard: a brand that genuinely IS violet, says so in a
waiver, and ships a chart series carrying legitimate hex. It must come out
WAIVED rather than FAIL, and the run must still exit 0 — a gate that cannot be
waived by a build with a reason is a gate that gets switched off.
The hex path, on its own, with no named utility to carry the verdict. It fires
only where sRGB and oklch agree about the band — Tailwind's indigo/violet/purple
hexes read 238.7-270.7 in their OWN space, below the 275 floor, so #d946ef is
what proves this path is wired. That gap is stated in divergence.mjs's residuals
rather than papered over here.
```

### Coverage honesty

```text
Every run states coverage, and a mostly-skipped run must not read as a clean
sweep. This is the exact regression: 1-of-8 graded printed the same
"OK: the build clears every divergence assertion" as 8-of-8.
A run in which every assertion SKIPped must not print an unqualified green.
This is the regression that let a build with no craft artifacts and a default
font stack read as "clears every divergence assertion".
```

### Not measured

```text
Missing token source must exit 2, per divergence.mjs's own header contract:
"A gate whose whole subject is 'the build defaulted' cannot treat 'I could not
find the build' as a pass."
contrast.mjs must not report a green having resolved zero pairings. A contrast
gate that measures nothing and prints "every pairing clears its threshold" is
worse than no gate: gates.spec.ts switches axe's own color-contrast rule off
and names this file the gate of record.
...and it MUST resolve a real shadcn token set. The PAIRS table is written in
theming-system's role vocabulary; every shadcn build names the same roles
`--foreground`/`--background`/`--primary`. Before the aliases, all 44 pairings
missed and the gate printed OK over a build it had read no colour from.
```

### Fail-open and hygiene

```text
Optional artifacts absent must not crash the gate (exit 0/1/2 are all verdicts;
anything else is a stack trace reaching the user).
The gates must never write into the tree they measure.
```

### Reduced-motion runtime controls

```text
gates.spec.ts's reduced-motion block, run for real — the shipped spec, the
shipped config, Playwright's own runner — against three fixtures that are ONE
page differing in ONE line. The JS twin must fail the JS and smooth-scroll
tests, the canvas twin the canvas test, the clean twin nothing, and each
failure must NAME the element that moved: a red for the wrong reason proves
as little as a green.

No network, so nothing is installed. A Playwright is looked for where one
already lives — $CRAFT_GATES_PLAYWRIGHT (a node_modules dir holding
`playwright`), then the npx cache `npx playwright …` leaves behind — and the
first whose Chromium actually LAUNCHES wins. None → one SKIP line naming what
is missing, and the sections above still count. CI installs no Playwright, so
there this section SKIPs: the proof is local, and the line says so.
The spec imports @playwright/test and @axe-core/playwright by bare name, so
hand it a NODE_PATH holding both. The runner and the spec must share ONE
Playwright instance, hence the shim onto the same package the CLI is from.
axe never runs under --grep, so a stub that refuses construction stands in.
...and for the RIGHT reason: each defective twin's failure names its mover
IN THE CHANNEL THAT SHOULD SEE IT. `#waapi` also moves its computed
transform, so a bare name match would stay green with the WAAPI channel
switched off — each pattern below is that channel's own line shape.
The video twin's "Display", "Google Play" and "Replay" buttons must not read as a
pause control, and the clip inside the open shadow root must be found at all.
```

### Type check

```text
gates.spec.ts runs inside the crafted project, whose tsconfig is often `strict`; a spec
that fails there is a gate the project's own typecheck step reports as broken. Same
lookup as section 5, for a node_modules holding typescript, @playwright/test and
@types/node. axe is stubbed to the three calls the spec makes.
```

## plugins/craft-layer/scripts/__tests__/technique-fingerprint.test.sh

### Header

```text
Offline tests for technique-fingerprint.py — the stack and motion detector the
design-research method runs per motion reference (mining-method.md §2a).

Every fixture is a saved page written into a temp dir and read through --file,
so nothing here touches the network. --file resolves each asset URL by PATH
under the page's directory and ignores the host, which is what makes the
first-party rule testable: a third-party asset sits on disk beside the page,
and the only thing keeping it out of the report is the rule under test.

Picked up by the repo's "Plugin author-time lint + harness tests" CI step,
which globs plugins/*/scripts/__tests__/*.test.sh.
```

### FILL

```text
The homepage must clear the 500-byte shell threshold, so every page carries
this paragraph of real-looking copy.
```

### Case 12: the per-fetch deadline

```text
    A local server drips a byte-sized chunk every 0.1 s for 6 s; urllib's timeout is per
    socket read and never fires, so only the deadline can end the read at ~1 s.
...and an ordinary Content-Length body still reads whole: http.client closes the socket
the moment the length is consumed, so the deadline loop must not touch it again.
```
