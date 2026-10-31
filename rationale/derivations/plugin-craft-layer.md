# craft-layer harnesses, scripts and craft-gates template: the comment text moved out of the code (2026-10-04, 2026-10-28)

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

Seven sections:
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
  7. CONCEPT-DECK WORKED DRAW (added 2026-10-15) — concept-deck.md's example
     must still compute against the deck: each n is its axis's option count,
     each index and carry is the arithmetic, each named option sits at that
     index, the seed is the stated cksum and the lens is that index of
     creative-director's list. A synthetic deck whose Axis 4 gained an option
     must fail it. Before this, an axis gaining an option left the example
     teaching the wrong draw with every gate green. It checks the example only,
     never that a run drew correctly.

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

## plugins/craft-layer/template/craft-gates/divergence.mjs

Moved verbatim on 2026-10-28, with only each comment's leader removed (`//`, `/*`, `/**`, `*/`, a ` * ` gutter, and the continuation indent). `/craft-layer:audit` runs this file from the plugin against the user's project (`commands/audit.md` step 4, never a vendored copy); the file keeps a one-line form of each block where a reader needs it, and nothing where the code says it.

### Header

```text
Craft audit — the anti-attractor divergence gate.
---------------------------------------------------------------------------
Every other craft judgement except contrast and axe is prose graded by a
reading agent, so "do not land on the model's default" has been advice. This
script is the teeth: it reads the shipped token source, the project's run log
and the run's recorded deck draw, and EXITS NON-ZERO when the build landed on
the category default or repeated its own last five runs.

Run from the project root:

    node scripts/divergence.mjs

MISSING TOKEN SOURCE EXITS NON-ZERO — the deliberate divergence from its
sibling `contrast.mjs`, which prints `not measured (token missing)` and exits
0. That precedent is right for a per-pairing check inside a file that was
found; it is wrong here. A gate whose whole subject is "the build defaulted"
cannot treat "I could not find the build" as a pass: a silent pass on a
missing or unparseable file is exactly the failure teeth exist to end. If the
token source lives somewhere unusual, point `CRAFT_TOKEN_SOURCE` at it.

Environment:
  CRAFT_TOKEN_SOURCE       explicit path to the CSS holding the tokens
  CLAUDE_PLUGIN_ROOT       craft-layer's root; makes the anti-corpus LIVE
  CRAFT_CONTRACT           explicit path to the persisted offer contract
  CRAFT_DIVERGENCE_RECORD  explicit path to the persisted divergence record
  CRAFT_BUILD_TASK         explicit path to the persisted build task
  CRAFT_CONTENT_SOURCE     explicit path to the persisted content source

Exit codes: 0 clean · 1 one or more assertions failed · 2 not measured.
```

### Section banners

```text
------------------------------------------------------------- anti-corpus
------------------------------------------------------------ token source
------------------------------------------------------------ hue plumbing
--------------------------------------------------------------- run log
------------------------------------------------- contract + deck record
--------------------------------------------------------------- waivers
--------------------------------------------------------- spine register
------------------------------------------------------- composition shape
---------------------------------------------------------- voice contract
---------------------------------------------------- copy-half fingerprint
------------------------------------------------ utility-layer fingerprint
------------------------------------------------------------------ run
--------------------------------------------------------------- run stamp
(i) accent hue inside the category-default band -------------------------
(ii) accent hue repeats one of the last 5 runs --------------------------
(iii) a shipped family is an anti-corpus entry --------------------------
(iv) a shipped family repeats one of the last 5 runs --------------------
(v) the recorded draw differs on fewer than 3 of 5 axes -----------------
------------------------------------------------------------- report
```

### SNAPSHOT

```text
Embedded fallback ONLY. The registry is refreshed per craft-layer release and
"never refreshing" is one of its own anti-patterns, so a copy frozen into a
template would silently freeze the gate at this date. Both the source used and
its date are printed on every run so a stale snapshot is visible, never
assumed.
```

### DEFAULT_BAND

```text
The category-default accent band. Violet/indigo is the hue generated pages
converged on; it does not age out on the recency window (see the registry's
category-default note). Angles are read in the token's OWN space — 275-315
covers indigo-to-violet in oklch and violet-to-purple in hsl/hex, which is
the same tell either way.
```

### corpusDate

```text
A corpus's OWN freshness stamp — its `verified:` line — never the file's mtime.
mtime is the date the BYTES last moved, which is not the date a human last
reviewed the list: on the shipped tree it printed 2026-09-16 for a corpus whose
own text says `Last verified: 2026-07-26`, overstating freshness by 52 days, and
in a fresh clone it prints the clone date for every corpus ever written. That
number is the only thing a reader has to decide whether to trust the gate.

A corpus carrying no stamp is reported as unstamped rather than handed a date it
never claimed. LIMIT: this proves the file SAYS it was verified then — nothing
here can check that it was, and a stamp nobody updates ages silently.
```

### toChroma

```text
How saturated is this colour, on a 0..1 scale comparable across notations? Only used to
pick the most chromatic token when no accent is named — precision matters less than
ranking the same set the same way every run.
```

### toOklch

```text
oklch() / hsl() / #rrggbb -> { c, h } in OKLCH, h null when achromatic; null when unparsed.
Unlike toHue, one space for every notation, so a hex brand echo and an oklch token compare.
```

### readAccents: the fallback

```text
NAME-BASED RESOLUTION IS NOT ENOUGH. A build whose colour system is value-driven and
hue-flat — one hue, hierarchy from lightness alone — has no accent to name, so it
names its tokens by ROLE instead (paper / ink / rule / overlap). Resolving only by
name reports such a build `not measured`, which this gate treats as a failure, so a
legitimately achromatic design fails by construction and cannot pass however correct
it is. That is the same defect shape as failing a brand-echo build for repeating its
own brand.

Fall back to the most chromatic declared token: whatever hue the system is built on
is the hue worth testing against the category defaults, whether or not anyone called
it an accent. Reported as a fallback so the resolution is never silent.
```

### readFamilies

```text
Every non-generic family named by font-family:, a Tailwind v4 `--font-*`
theme variable, or @font-face in the given CSS.

READS THE TWO FORMS IT USED TO MISS. Matching only literal `font-family:`
made this gate blind on the two setups the anti-corpus most wants to catch:
Tailwind v4 declares the stack as `@theme { --font-sans: Inter, … }` and
never emits a `font-family` line at all, and a project that writes
`font-family: var(--font-sans)` hid the family behind an indirection the old
loop skipped by name. Both recorded SKIP — "no non-generic font declared" —
which the terminator then folded into a green. So the plugin's most-quoted
anti-sameness claim had no teeth in exactly the stack it ships guidance for,
and the way to pass the font gate was to never choose a typeface.
```

### readFamilies: var() indirection

```text
Resolve custom-property indirection first, so `font-family: var(--font-sans)`
is read as whatever --font-sans holds.
```

### readRunLog

```text
Last 5 rows of the seven-column log. A malformed log is EMPTY, never fatal.

PARTIAL malformation is the case worth being loud about. A wholly-unreadable log
already warns, but a log where only SOME rows are hand-edited used to be read
partially and silently — the gate then ran against a quietly truncated history
while craft.md and the README both promise "treated as EMPTY and warned about".
Every dropped row is now counted and reported.

Widths: rows are matched against the HEADER's width when a header is present,
falling back to COLUMNS. Cells map POSITIONALLY, so a column inserted anywhere
but the end of the row shifts every older row's values into the wrong keys —
which reads as a PASS on garbage rather than a skip. New columns are
append-only, and a row wider than its header is reported rather than trusted.
```

### ARTIFACT_PATHS

```text
The candidate list per artifact, in precedence order. Held in ONE table because
the stamp assertion below needs the whole list — the extra candidates are the
ambiguity it reports — while every other reader wants only the first that
exists. Env vars are read per call, so a test can set one between runs.
```

### ECHO_CHROMA_FLOOR

```text
Under 0.05 OKLCH chroma an echoed colour is a tinted neutral ink, not an accent: Tailwind's
slate-900 #0f172a measures 0.040 and gray-900 0.032, a muted brand violet #6b5b95 0.091.
```

### echoNames

```text
What a `Brand echo:` value names: its accent colours as OKLCH hues, and the text outside
parentheses as where a shipped family must appear whole-word. Misses: 3-digit hex and named
colours are not read; a family that is a whole word of a longer named one ("Inter" in
"Inter Display") counts as named, and so does one named outside parentheses in a negation
("not Inter"); and a Tailwind colour utility is read at its family's 500-step hue, so a
violet echo also covers `purple-*`, 11° away.
```

### echoesHue

```text
15°, the hue-repeat window, because a kept brand ships as a ramp of tokens around one hue.
Takes an OKLCH hue.
```

### spine-register

```text
THE BUYER'S QUESTION, ANSWERED IN AN INTEGRATOR'S VOICE.

The offer-spine gate checks each slot is PRESENT. A build once answered all
eight — and answered them with `POST /api/task`, a bearer-token scope, a
`workspace_id` global scope and a 403 body. Every gate reported green; a human
read the page and found API documentation wearing a landing page's clothes.

Only the three BUYER slots are graded — plain-what, audience, problem. Method
disclosure inside `how it works` and `objection` is where the offer contract
ROUTES spec detail, and a limits list is SUPPOSED to be concrete, so a
whole-page grep is the blunt version of this check: it fires on correct pages,
teaches builders to strip real detail, and gets waived into silence.

Scoping it needs a slot -> region mapping, which is why this reads
`craft/build-task.md`'s `Spine regions:` line. Mapping, corpus and declared
limits: skills/creative-direction/references/register-corpus.md

`fixture-register.html` and `fixture-register-clean.html` (in this plugin's
`scripts/__tests__/fixtures/`, with the harness that runs them) are the pair
that proves this fails for the right reason: same product, same facts, same
endpoints and the same limits list — only the register of the three buyer
slots differs. The clean one MUST pass; a run that fails it has become the
whole-page grep. `fixture-register-falsepos.html` is the third of the set: a
correct buyer page whose copy happens to carry `401(k)`, `429 teams` and
`Suite 502`, with every buyer anchor on a TEXT-ONLY leaf. It must pass, and it
must report all three slots CHECKED rather than unreadable.

Point a scratch project at each in turn with a build task carrying, ON ONE LINE
AND NEVER WRAPPED (this parser reads the line the key is on and nothing else):

Spine regions: plain-what=#hero, audience=#hero, problem=#status-quo, how-it-works=#method, price=#pricing, proof=#proof, objection=#limits, cta=#hero
```

### loadRegisterCorpus

```text
The corpus, LIVE from the reference when the plugin root is known. Same
contract as the anti-corpus above: source and date are printed every run, so a
frozen snapshot is visible rather than assumed.
```

### readSpineRegions: the key forms

```text
Accept the bare, list-marker AND heading forms. A build task writes six lines and
two are machine-parsed — this one and `Voice:` — so heading form works for both.
A task whose lines are formatted consistently as `## <key>:` therefore had five live
lines and one silently dead one, reported as a SKIP that reads like "nothing to
check". Found on a live run, by nobody's review.
```

### regionFor

```text
The element carrying `id="<anchor>"`, bounded by tag balance on its own tag
name. Bounding matters more than it looks: without it the region runs to the
end of the file and swallows the `how it works` section, which is the blunt
whole-page grep this gate exists to NOT be.
```

### COPY_ATTR: no data-*

```text
`data-*` IS DELIBERATELY ABSENT, and this is the one place this gate reads less
than the banned-vocabulary gate does. That gate looks for literal terms a human
chose, so a `data-` string is worth checking. This one greps for the SHAPE of
code — `\w+_id`, a status number, a route — and `data-testid="task_id"`,
`data-state`, `data-slot` are made of exactly that shape while being code hooks
no reader ever sees. Including them would fire on correct pages, which is the
anti-pattern register-corpus.md names. Stated in its declared limits.
```

### copyChunks

```text
What a READER sees, approximated from source exactly as the banned-vocabulary
gate defines rendered content: text between tags, copy attributes, and quoted
values of copy-bearing keys. CODE IS NOT COPY — an import path, a
`fetch('/api/…')` argument, a `className` and an `href` never reach this list,
which is what keeps a hero with a working signup form out of the findings.

`isCopy` is a PARAMETER with the letter test as its default because the
emoji-as-icon assertion below needs the opposite blindness fixed: an
icon-only leaf — `<div>🚀</div>` — holds no letter at all, and that is the
exact shape an emoji icon ships in.
```

### copyChunks: the leading text run

```text
THE LEADING TEXT RUN, before the first child tag — and the whole of a text-only
leaf, which has no child tag at all. Starting the walk at the first `<` skipped
both: `<h1 id="plain-what">POST /api/task <span>now</span></h1>` graded only
"now", and `<h1 id="plain-what">POST /api/task</h1>` produced ZERO chunks and was
reported as "an element holding no copy" — telling the builder to move the id
onto the element holding the copy, which is where they had already put it, and
craft.md step 6 instructs them to.

WHY THE TEST IS `\p{L}` AND NEVER `[A-Za-z]`. It asks one question — is this run
TEXT rather than whitespace and punctuation — and Latin is not the only script
that answers yes. Under `[A-Za-z]` an entire Hebrew, Arabic, Cyrillic, Greek,
CJK, Thai or Devanagari page has NO copy anywhere: every buyer region reports
"holding no copy", spine-register degrades to SKIP across the whole spine, and
the message instructs the builder to move an id that was already right. Worse,
the regions that DO appear to hold copy are the ones whose slice happens to
contain a JSX identifier — `{ITEMS.map(({ title, body }) => (` — so the gate
grades JavaScript and ignores the prose. A Hebrew run found exactly that.
```

### composition-shape

```text
THE AXIS NOBODY WAS CHECKING.

The deck draws FIVE axes and four of them land somewhere a gate can see:
colour behaviour has accent-default-band and hue-repeat, type role has
font-anti-corpus and font-repeat, motion role is the craft-reviewer's job,
graphic-system class is a `maximal` reach floor. Axis 1 — COMPOSITION
STRATEGY — had nothing, and draw-repeat does not close that hole: it grades
the recorded draw STRING against the run history, so it proves the words are
new and never that the page was built the way they say.

The failure that produced this check: a run drew "Placed clusters" — discrete
positioned groups on an open canvas instead of a running flow — and shipped
`mx-auto max-w-5xl` eleven times in a running flow, which is "Centred spine",
a DIFFERENT option on the same axis. Every assertion passed. The one axis with
no gate was the one that collapsed, and it collapsed to the shape a model
reaches for when nothing argues otherwise: one measure, no exceptions. The
reviewer's words for it were "it looks like a blog post".

SO THIS MEASURES SHAPE, NOT COMPLIANCE. It deliberately does NOT parse the
drawn option and hunt for that option's signature: eight options would need
eight signature tables, each one a fresh way to be wrong, and a wrong
signature table fails correct pages. It asks the blunter question the failure
actually poses — did this page commit to ANY spatial structure at all?

Two conditions, and it bites only when BOTH hold, so a build with real
structure ANYWHERE clears it:

  1. ONE MEASURE — the dominant `mx-auto max-w-*` container accounts for 70%+
     of all such containers. A page of full-bleed panels or an asymmetric
     split does not read this way; a stacked document does.
  2. NO ESCAPES — positioned, spanning and bleeding elements number fewer than
     one per two sections. Layered depth, off-axis fields and placed clusters
     all REQUIRE these; a running flow uses none.

Vertical rhythm is measured and REPORTED but is not a fail condition. On the
page that motivated this check the rhythm was the weakest of the three signals
(py-12/20/28, three values, 67% dominant) while the page was unmistakably one
shape — rhythm variety is cheap and buys no structure, so gating on it would
have taught builders to sprinkle padding values.

A PAGE WITH NO FIXED MEASURE AT ALL PASSES, and says why: zero `mx-auto
max-w-*` containers is the opposite of this failure, not a severe case of it.

A CENTRED SPINE IS A LEGITIMATE DRAW AND THIS GATE FAILS IT. That is on
purpose, and it is what the waiver lane is for — draw the axis, build the
spine, write the waiver with the reason. What must never happen silently is
the page that never decided.
```

### NOT_THE_PAGE

```text
THE PAGE, NOT THE HARNESS. `sourceFiles()` walks everything shipped, which is
right for the register gate — copy is copy wherever it lives — and wrong here.
A Playwright spec that ASSERTS on layout quotes every utility this check
counts, so the first run of this gate scored the test file at 8 escapes and
PASSED the very page it was written to catch. Tests, stories, scripts and
config describe the page; they are not it.
```

### compositionShape: escapes

```text
Escapes are counted ONLY inside class strings. Counting them file-wide
scores the word "absolute" in a prose comment as spatial structure —
which is how a page carrying one positioned element reported four.
```

### compositionShape: rhythm

```text
Only SECTION-scale padding. `py-2` is a button and `py-4` is a nav row;
counting them reports a rhythm variety the page's structure never had.
```

### voice-contract

```text
THE PRODUCT-SPECIFIC HALF OF THE COPY GRADE.

`copy-register` below grades a CATEGORY list — phrases any generated page
reaches for. It cannot know that THIS product does not say "everything you
need", because that is a concept decision and not a category default. The
concept records it on `craft/build-task.md`'s `Voice:` line as
`NEVER "<literal>"` items, and those literals join the lexicon for this run.

Standing, split on purpose (references/voice-contract.md carries the table):
  - the LINE's presence, and that it carries at least one NEVER, is this
    assertion — a GATE, exit 1.
  - the NEVER literals in shipped copy are graded by `copy-register` — a GATE.
  - the voice ITSELF — person, sentence band, what it does with fragments —
    is the craft-reviewer's, agent-graded. Nothing here counts a sentence.

NO BUILD TASK AT ALL IS A SKIP, never a FAIL: a build is never failed for not
having saved a file, the same rule spine-register and craft-stamp ride. A
build task that EXISTS and omits the line is the finding — that is a resolved
artifact missing a line the flow's own step 5 owes it, which is an ungraded
gate wearing a green rather than a run that never started.
```

### readVoice: the key forms

```text
Same tolerant key shape as `Spine regions:` — bare, list-marker and heading
forms all resolve, because a task whose five lines are formatted as
`## <key>:` had four live lines and one silently dead one.
```

### emoji-as-icon and copy-register

```text
THE COPY HALF OF THE FINGERPRINT — MECHANICAL SUBSET ONLY.

The sameness registry carries a copy register (sameness-fingerprint.md,
"Recurring copy register"): the machine-copy lexicon a reader identifies as
generated in one line, the way the violet gradient is identified in one
glance. Most of that section is register and cadence — the craft-reviewer's
territory, agent-graded. Two tells are mechanical, and a check a machine can
run is never left to a judgement:

  emoji-as-icon — pictographs standing in for the icon system. 🚀 in a
      heading means no icon decision was made, and it is the single fastest
      visual identifier of a generated page.
  copy-register — the multi-word machine-copy phrases. MULTI-WORD ON
      PURPOSE: "supercharge your" is a verdict, while "seamless" alone is a
      word honest copy is allowed to use — a single-word list fires on
      correct pages, which is the anti-pattern register-corpus.md names.

Both read the reader-visible copy the spine-register assertion reads
(copyChunks), across the whole PAGE rather than a mapped region — a
pictograph or a lexicon phrase is a tell wherever it lands. The harness is
excluded the way composition-shape excludes it: a spec asserting a phrase is
banned QUOTES the phrase, and grading the quote fails the test that guards
the page. Both are waivable with a reason, the same lane as every assertion.
```

### COPY_SNAPSHOT

```text
FROZEN FALLBACK ONLY. The live list is the registry's `copy-lexicon` block in
sameness-fingerprint.md — same contract as the anti-corpus and the register
corpus above: source, kind and date are printed every run, so a snapshot in use
is visible rather than assumed. A frozen copy of a list whose own first
anti-pattern is "never refreshing" freezes the gate at this date, which is why
the live read is the default and this is the fallback.

Rows are `label :: flags :: min :: pattern`. `min` is how many DISTINCT copy
chunks must match before the label is a finding, and it is what lets the three
mechanical chrome rows ride here at all: the registry says the eyebrow sits
"above every heading" and the arrow is "appended to every link", so repetition
is the tell and one honest `Read more ->` is not. Same judgement as the
multi-word rule beside it — a row that fires on correct pages is waived into
silence within one run.
```

### loadCopyLexicon

```text
The copy lexicon, LIVE from the registry when the plugin root is known. Reads
the same `label :: flags :: min :: pattern` rows the reference documents, so
adding a mechanical row there arms it here with no code change — the defect
this replaced was a frozen six-phrase list beside a registry of 13,951
characters, of which the gate read 1,683.
```

### TEXT_MARKS

```text
Text-default pictographs prose legitimately carries — the legal marks — plus
anything the author explicitly rendered text-style with U+FE0E. Keycap
digits (#️⃣, 3️⃣) never match at all: their base characters carry the Emoji
property, not Extended_Pictographic, so they need no exclusion row here.
```

### QUOTED_RE

```text
A QUOTED VOICE IS NOT THE BUILD'S ICON SYSTEM. An emoji inside a
<blockquote> or <q> is the customer's own register — testimonial content the
content-fidelity gate wants reproduced verbatim — so quoted subtrees are
blanked before extraction. An emoji the BUILD authored into a heading or a
feature row is the finding.
```

### pageCopy

```text
Shipped page source with its text, harness excluded, one read for both
copy-half assertions.
```

### copyRegister: the run's NEVERs

```text
The run's own NEVERs ride the category lexicon as extra rows — same chunks,
same waiver lane, same one-row-per-label reporting. Whitespace is relaxed so a
literal that wrapped in the markup still matches.
```

### copyRegister: a phrase across lines

```text
A phrase can span a source line break; collapse it or the one-row
reporting shape gains a literal newline.
```

### copyRegister: repetition rows

```text
A row whose `min` is above 1 is a REPETITION tell, so it becomes a finding
only once that many distinct chunks carry it — see the lexicon block's own
note. Counted across the whole page set, because "on every heading" is a page
property and a build that splits its sections across files has not stopped
doing it.
```

### utility-palette and utility-font

```text
THE HALF OF THE FINGERPRINT THAT NEVER REACHES THE STYLESHEET.

Standing: GATE. Both assertions below FAIL the run (exit 1) and both are
waivable through `.craft-layer/waivers.json` with a reason — the same lane
every other assertion in this file rides.

`accent-default-band` decides the category-default hue by reading CSS custom
properties and nothing else (readAccents, above), and `font-anti-corpus` reads
families out of the token stylesheet plus its siblings. On a Tailwind/JSX build
neither the palette nor the type passes through either input: the hue arrives
as `from-indigo-500 via-purple-500 to-violet-600` inside a `className`, and the
family arrives as `import { Inter } from 'next/font/google'`. So both
assertions returned green on a page that IS the fingerprint — a violet gradient
hero set in Inter, over a `src/index.css` whose cleanly derived accent token no
element ever referenced — and the terminator printed "OK: the build clears the
N divergence assertion(s) that could be graded". That is the has-teeth
over-claim this repo's convention forbids, printed by the file that calls
itself the teeth.

These read SOURCE only, so like the register / shape / copy assertions they run
BEFORE the token resolution and their verdicts survive an exit-2 run. That
ordering is load-bearing rather than tidy here: the build most likely to ship
its palette in class strings is the same build least likely to have a token
stylesheet this gate can find.

WHAT THESE DO NOT CATCH — named, not implied:

 - THEY NEVER RUN ON `/ui-ux:build`. divergence.mjs has exactly ONE call
   site: `/craft-layer:audit` step 4. A `/craft-layer:craft` run reaches it
   only by calling that command at its step 7, which explicitly forbids
   running the gates itself. Meanwhile ui-ux's `build.md:75` calls itself the most reachable UI entry
   point in this marketplace. The most-used way into a UI is the one path this
   gate has never been on.
 - THEY COUNT A HUE AND A FAMILY, NOT A COMPOSITION. Three equal cards, the
   ribbon on the middle one, the centred hero: all uncounted. `text-center` is
   read here as context and never as a finding, and `composition-shape` above
   grades a measure rather than an arrangement.
 - THEY CANNOT TELL A CHOICE FROM A DEFAULT. A legitimately violet brand and a
   third-party logo's own hex are indistinguishable from a hue reached for by
   not choosing, unless the contract's `Brand echo:` names that value. Otherwise
   that is what the waiver REASON is for.
 - THEY SAY NOTHING ABOUT COPY DEPTH OR PROP VALIDITY. Prop validity is a
   compiler's job — `tsc --noEmit` for a typed registry, `validate_usage` for
   ReUI — and copy depth is the craft-reviewer's, agent-graded.
 - A CLASS STRING THIS FILE CANNOT SEE IS NOT GRADED. CLASS_RE reads literal
   `class`/`className` values only; a list assembled in a variable or inside
   `cn(...)`, and a colour arriving through a component prop, are invisible.
 - THE HEX PATH IS READ IN THE VALUE'S OWN SPACE, exactly as
   `accent-default-band` has always read it (see DEFAULT_BAND's note above) —
   and the two spaces DISAGREE about this band. Measured: Tailwind's own
   indigo/violet/purple hexes read 238.7° (#6366f1), 258.3° (#8b5cf6) and
   270.7° (#a855f7) in sRGB, all BELOW the 275° floor, while the same swatches
   are 277.1/292.7/303.9 in oklch. So the hex path fires only where the two
   readings agree (fuchsia/magenta-side values such as #d946ef at 292.2°); the
   named-utility path catches the NAMES; the DEFAULT_SWATCHES set below catches
   those same colours written as hex. Any OTHER in-band hex is still only seen
   where the two colour spaces agree, and that residual is real.
   Re-spacing the band or converting hex to oklch would change
   `accent-default-band`'s verdicts for every existing build, so it is stated
   here rather than done quietly.
 - `utility-font` matches the anti-corpus TEXT only. The per-script Noto
   pattern (NOTO_DEFAULT, further down) belongs to `font-anti-corpus` and reads
   the stylesheet, so `font-['Noto_Sans_Hebrew']` reaching the page through a
   class string is not caught here.
```

### UTIL_FAMILY

```text
WHY EXACTLY indigo / violet / purple — DERIVED FROM DEFAULT_BAND, NOT PICKED.
Tailwind's own oklch hue angles put indigo-500 at ~277.1°, violet-500 at
~292.7° and purple-500 at ~303.9°, all three inside the 275-315° band declared
above, while the immediate neighbours fall outside it: blue-500 at ~259.8°
below and fuchsia-500 at ~322.1° above. The list is therefore auditable
against the band rather than against taste. If DEFAULT_BAND ever moves,
RE-DERIVE this list from the ramp's oklch angles — never extend it by feel.
```

### DEFAULT_SWATCHES

```text
THE HUE TEST ALONE CANNOT SEE A DEFAULT SWATCH WRITTEN AS HEX, so it is paired with a
literal set. toHue reads a hex in sRGB, where Tailwind's indigo-500 (#6366f1) is 238.7
degrees — far BELOW this band's 275 floor — while the same swatch is 277.1 in oklch,
inside it. An adversarial audit on 2026-08-18 shipped `bg-[#6366f1]` straight through
this assertion while the PASS line asserted "no in-band arbitrary hex": a gate making a
false affirmative claim, and worse, missing what the ui-ux ADVISORY catches by list.
Re-spacing the band would flip accent-default-band's verdicts for every existing build,
so the fix is to name the swatches whose two readings disagree. Steps 400/500/600 of the
three in-band families.
```

### utilityPalette: hex in a class string

```text
A hex literal inside a class attribute is BY CONSTRUCTION not a token —
the token layer is where a derived accent lives, and an arbitrary value
is the shape of skipping it. Band-gated all the same: firing on EVERY
hex would fire on a chart series and on a third-party mark's own colour,
which is the anti-pattern register-corpus.md names.
```

### FONT_ARBITRARY_RE

```text
The three ways a family reaches a Tailwind/JSX page without ever touching the
token stylesheet `font-anti-corpus` reads. Underscores are Tailwind's escape
for a space inside an arbitrary value, so `font-['Playfair_Display']` is the
family "Playfair Display"; `+` plays that role in a Google Fonts query.
```

### spineRegister: runs first

```text
The register assertion reads SOURCE + the build task and needs nothing the
token gate resolves, so it runs FIRST and its verdict survives an exit-2 run.
A page whose CSS lives somewhere unusual is not a page whose copy is unchecked.
```

### spineRegister: a partial result

```text
A CLEAN RESULT OVER PART OF THE BUYER SLOTS IS NOT A CLEAN RESULT.
Unreadable slots used to be notes only, so one of three regions resolving was
enough to PASS with two slots ungraded — a note nobody reads standing in for a
verdict. A FAIL still stands (a marker found is evidence whatever else was
missed), but a no-hit run over an incomplete set is SKIP, exactly like every
other input this gate cannot see.
```

### craft-stamp

```text
FOUR ARTIFACTS, ONE RUN — OR EVERY GATE BELOW IS GRADING SOMEONE ELSE'S BUILD.

The craft artifacts live at FIXED names so a later session can find them without
being told. That is also what lets a SECOND run in one session land on the first
run's files, and it has happened: a previous run's contract sat exactly where the
audit globs, and a person caught it rather than a gate. So every artifact opens
with an identical `Run: <instant> · <slug> · <project root>` stamp
(creative-direction/references/offer-contract.md, Part 8), and this assertion is
the scripted half of the tiebreak stated there. Three shapes fail, and each means
at least one file was left behind by an earlier run: the artifacts DISAGREE, one
is stamped to a project that is not this one, or one carries no stamp while a
sibling does. A second candidate path holding a different stamp fails too —
precedence picked one, which is not the same as deciding between them.

It never guesses a winner. No stamp anywhere is a SKIP that says so, exactly like
every other input this gate cannot see.
```

### foreignProject

```text
The stamp's third field, when it names a project that is not this one. A
non-absolute or absent field is not a mismatch — there is nothing to compare.
```

### Run order

```text
Reads SOURCE only, so like the register assertion it runs BEFORE the token
resolution below and its verdict survives an exit-2 run. A page whose CSS
lives somewhere unusual is not a page whose SHAPE goes unmeasured.
```

```text
The copy-half pair reads SOURCE only too, so it also runs ahead of the token
resolution and its verdicts survive an exit-2 run. One walk feeds both.
```

```text
Same walk, same reason: the utility-layer pair reads SOURCE only, so its
verdicts survive the exit-2 path below. A build that ships its palette in
class strings is the one most likely to have no token stylesheet at all.
```

### flushEarly

```text
Print what IS measured before a not-measured exit, so the register verdict is
never swallowed by a missing token source.
```

### The run's own log row

```text
THE RUN MUST NOT BE COMPARED AGAINST ITSELF.

craft.md appends this run's row AFTER the audit, so the first pass sees a log without
it. Every pass after that — a re-run, a CI job on a committed project, anyone typing the
command twice — sees the row this same build just wrote and fails the build for
repeating a hue it never repeated. The gate would be single-use, and worse, it would
fail hardest on projects diligent enough to keep their log.

The draw is the run's fingerprint. A LAST row whose five-axis draw equals the draw in
the current divergence record can only be this run's own record, because the draw is
written once per run and excludes what earlier rows used. Drop exactly that row, and say
so, so the exclusion is never silent.
```

```text
Draw match is the strongest signal, but a run with no persisted divergence record has
no draw to match — and that run would then fail against its own row, which is the
whole defect. Fall back to the hue family, which every logged row carries and which
the gate has already resolved for this build.
```

### NOTO_DEFAULT

```text
THE ANTI-CORPUS WAS LATIN-ONLY, SO EVERY OTHER SCRIPT HAD NO DEFAULT.

The registry names Inter and Geist — the faces a generated page reaches for
first. That list is correct and it is entirely Latin, and the matcher below
needs the shipped family name to appear IN the registry text, so no wording
in a markdown bullet can cover a family-per-script.

A Hebrew build shipped "Noto Sans Hebrew Variable" and passed clean. Noto is
Google's universal-coverage fallback set: `Noto Sans <script>` is what an
unstyled page renders in for that script, what the CLI installs, and what a
model names when asked for "a font that supports <script>". It is Inter's
exact role in every writing system Latin does not own — the category default,
arrived at by not choosing.

So the Noto rule lives in CODE rather than in the registry text, and it is a
PATTERN over the family name rather than a list, because the list would need
one row per script and would be wrong the day a script was missing.

This is waivable and often SHOULD be waived: for some scripts the quality
alternatives are few or none, and Noto is then a real choice rather than a
default. A waiver with that reason is the difference — same as a centred
spine in `composition-shape`. What must not pass silently is the build that
never looked.
```

### Coverage before verdict

```text
COVERAGE BEFORE VERDICT. Every assertion here SKIPs when its input artifact is
absent, and a build that produced no craft artifacts and declared no typeface
skips nearly all of them — so the terminator used to print the identical green
over 1-of-7 graded as over 7-of-7. That is the has-teeth over-claim this repo's
own convention forbids, printed by the file that calls itself "the teeth": the
laziest possible build read as "clears every divergence assertion", while a
build that did the work was the only one that could fail. Coverage is now
stated on every run, and the clean line says how many assertions it speaks for.
A SKIP is still not a failure — the gate genuinely cannot grade an input it was
never given — but it can no longer be silently counted as a pass.
```

## plugins/craft-layer/template/craft-gates/contrast.mjs

Moved verbatim on 2026-10-28, leaders removed as above. `plugins/ui-ux/scripts/contrast.mjs` is the twin of this file, identical save its TWIN line (`pc_twin_files`), and points at this heading too. The header stays a `/* */` block in both copies because the twin's `# TWIN:` line must sit inside a comment.

### Header

```text
Craft audit — accent/ink-on-surface contrast gate.
Parses the oklch() token values out of src/index.css, converts to sRGB, and
computes WCAG 2 relative-luminance ratios for every pairing that matters.

WCAG 2 is the conformance gate (per ui-ux theming-system/accent-system):
APCA is not normative and WCAG 3 has not settled a contrast algorithm.

Run from the PROJECT ROOT, against the plugin's own copy — no vendoring needed:
  cd <project> && node ${CLAUDE_PLUGIN_ROOT}/template/craft-gates/contrast.mjs

WHY THE TOKEN SOURCE IS RESOLVED FROM `process.cwd()` AND NOT FROM THIS FILE.
It used to be `new URL('../src/index.css', import.meta.url)` — relative to the
SCRIPT — which silently made the gate work in exactly one layout: copied to
`<project>/scripts/`. Run any other way it read the PLUGIN's own template CSS,
or crashed. So the gate was coupled to being vendored, and vendoring is what
produces a stale snapshot that passes builds the current gate fails. Reading
from the working directory is what lets one copy of this file, in the plugin,
grade any project — and it matches how `divergence.mjs` has always resolved
its token source, including the same env override and candidate list.
```

### ROLE_ALIASES

```text
ROLE ALIASES — the repair that made this gate able to measure anything.
The PAIRS table above is written in theming-system's ROLE vocabulary, and
`--ink-1` / `--surface-base` / `--accent-display` are names no project in this
marketplace emits: theming-system itself calls them `ink-primary/secondary/
tertiary`, and every shadcn build — the stack ui-ux ships guidance for —
writes `--foreground` / `--background` / `--primary`. So all 44 pairings
resolved to nothing, every line printed `not measured (token missing)`,
`failures` stayed 0, and the terminator printed "OK: every pairing clears its
WCAG 2 threshold" over a build it had never read a single colour from — while
gates.spec.ts switched axe's own `color-contrast` rule off and named THIS file
the gate of record. A contrast gate that cannot resolve a token is not a
passing contrast gate; it is no contrast gate, and it was standing in for one.

Each role now resolves to the first name present in the block, so one table
grades both vocabularies.
```

### Zero measured

```text
ZERO MEASURED IS NOT A PASS. Same reasoning divergence.mjs states in its own
header and applies to a missing token source: a gate whose subject is "does
this build clear the threshold" cannot treat "I read no colours" as clearing
it — least of all while it is the reason a real checker is switched off.
```

## plugins/craft-layer/template/craft-gates/playwright.config.ts

Moved verbatim on 2026-10-28, leaders removed as above.

### Header

```text
craft-layer — the config that makes `gates.spec.ts` RUNNABLE FROM THE PLUGIN.
---------------------------------------------------------------------------
WHAT IT CATCHES. Playwright has no `--spec <file>` flag: a bare
`npx playwright test` in a crafted project scans THAT project's testDir, finds
no craft gate, and exits 0 having run nothing — the failure mode `commands/audit.md`
step 4 calls "a gate never run", reported as green. Pointing `--config` at this
file makes the directory holding the spec the testDir, so the suite that runs is
the plugin's, at the plugin's version, with no copy to go stale.

WHAT IT DOES NOT DO. It cannot supply the dependencies, and it cannot find
them either. Node resolves `@playwright/test` and `@axe-core/playwright` by
walking up from THIS FILE — inside the installed plugin, which has no
`node_modules` — so both this config and the spec beside it die with
MODULE_NOT_FOUND unless the caller exports `NODE_PATH=<project>/node_modules`.
That is why `commands/audit.md` step 4 carries it; measured 2026-09-22, the
invocation without it never reaches a single test. It also proves nothing
about WHICH build answers at BASE_URL — that is `CRAFT_EXPECT_TITLE`'s job,
inside the spec.

Two paths, resolved against different roots on purpose:
 - `testDir` is relative, and Playwright resolves config paths against the
   CONFIG's directory — so `.` is this directory and the spec beside it is the
   whole suite, wherever the plugin is installed.
 - `outputDir` is pinned under the PROJECT's cwd. The default, `test-results/`
   beside the config, would have the gate writing into the installed plugin —
   the tree audit.md step 4 treats as read-only. The spec's own screenshots
   already go to `<cwd>/.craft-layer/shots`, where audit.md step 5 looks.
```

## plugins/craft-layer/scripts/technique-fingerprint.py

Moved verbatim on 2026-10-28: the module docstring (quotes removed; `--help` prints argparse's own description, never this text) and one `#` block. The file keeps a docstring of a summary and three lines.

### Module docstring

```text
technique-fingerprint.py — name a reference site's stack and motion techniques.

design-research used to describe a reference's motion from a still, which for a
WebGL or scroll-driven page is a blank frame or one static state. This fetches the
homepage plus capped first-party JS and CSS and greps them for library signatures,
so a research row can say "GSAP + ScrollTrigger + Lenis" instead of guessing.

Ported from the design-corpus detector
(rationale/2026-09-25-design-capability-corpus/tools/detect.py): the signature
table, the manifest-mention guard, the first-party asset rule, and the rule that
View Transitions and CSS scroll-driven animation count only from markup or CSS.
Fonts, colour flags and hosting are corpus statistics and were not ported.

Usage:
    technique-fingerprint.py URL [--json] [--max-js N] [--max-css N] [--max-bytes N]
    technique-fingerprint.py --file PAGE.html [--base-url URL] [--json] [...]

--file reads a saved page instead of fetching. Each asset URL the page names is
resolved by its PATH under the page's directory (the host is ignored, and a path
escaping that directory is refused), so a saved "page + assets" folder works
offline. Pass --base-url with the page's real address when the saved HTML holds
absolute asset URLs, so the first-party rule sees the right host.

Exit codes:
    0  a report was produced from a readable homepage
    1  the homepage was refused, unreachable, a bot challenge or a near-empty
       shell — the report still prints and names why; record it, do not guess
    2  usage error, or a --file that cannot be read

LIMITATION: a match is positive evidence; no match is NOT evidence of absence
(lazy chunks past the cap, server-rendered markup with no client bundle, bot
walls, a library bundled under a minified name). It reads source text, never
behaviour: whether the motion honours reduced motion is visible only in a
browser, which is why the research method also asks for a reduced-motion capture
and a short scroll clip.
```

### MARKUP

```text
A page that SAYS "leaflet" does not load it. The homepage is matched as its tags
(attributes, classes, URLs), comments and inline <script>/<style> bodies; the text
between tags — the visible copy — is dropped, for every signature.
```
