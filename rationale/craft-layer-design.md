# craft-layer — design rationale

Moved out of `plugins/craft-layer/README.md` on 2026-07-27. It was 655 lines,
4x the next-largest plugin README, and roughly 470 of them were design essay
rather than usage. `CLAUDE.md` bans design docs inside `plugins/`, but README.md
is on the functional-file allowlist, so the essay passed the doc-location gate
purely by filename — the gate's blind spot.

Nothing loads this at runtime. It is kept because the reasoning behind the
craft flow's gates is genuinely load-bearing for anyone changing them.

---

### Why motion is decided before the build

Every other motion rule in this plugin is a **ceiling** — per-tier budgets, the cumulative
budget, reduced-motion paths, reduced-bundle fallbacks, lazy-loaded 3D. Ceilings stop bad
motion; they cannot produce good motion, and a page with no animation at all clears every one
of them. Two rules close that gap:

- **Step 5 runs before step 6.** Motion decided after a layout is committed can only be
  retrofitted onto markup that was not built for it, so the retrofit lands on the one thing a
  retrofit allows — fade-and-rise reveals. A pinned scroll act, a WebGL hero surface, a
  shared-element route transition, a physics stage: those are structural. They are in the
  build task or they never ship.
- **The signature is the motion floor.** The concept names ONE signature interaction at step 0;
  step 5 assigns it a section, an owning skill, and a tier on the build task's `Signature:`
  line; the audit checks the named mechanism actually shipped there. It is the only gate that
  fails a page for too *little* motion, and entrance reveals never count toward it. It is also
  what makes anime.js, Three.js, physics, and Lottie/Rive reachable at all — the tier picker
  takes the cheapest tier that fits on every ordinary surface, and only the signature surface
  is picked by what the move needs.

No divergence record persisted → the gate reports `not checked`, like every other gate whose
input is missing. It never fails a build that simply never saved one.

### What the run writes outside your app

Working files, at fixed names so a later session — or a standalone
`/craft-layer:audit` — can find them by glob. They live in the taskmaster docs area when the
project has one, otherwise the session scratch area, and **never** in the shipped tree:

| File | Written by | Read by |
| --- | --- | --- |
| `craft/offer-contract.md` | step 0, after the archetype is classified | the audit's scope, length, mode and content-depth gates |
| `craft/divergence-record.md` | step 0, once the concept exists | the audit's anti-sameness gate and the plain-language what-line check |
| `craft/content-source.md` | step 0/1, from the copy that already exists | step 1's briefs, the build, and the audit's content-fidelity gate |
| `craft/section-ledger.md` | step 3 (guided only) | `/ui-ux:build` via the build task, and the audit's conformance gate |
| `craft/reference-board.md` | step 1 at the `ultra-craft` boost, echoed to you before any file is written | the audit's boost-evidence gate, and step 2's concept work |
| `craft/build-task.md` | step 5, once its five lines resolve | `/ui-ux:build` at step 6, and the audit's signature, named-escalation, ambition, banned-vocabulary and buyer-REGISTER gates (`Spine regions:` is the register gate's only input) |

Missing any of them is not a failure — the gates that need them report `not checked` rather
than passing or failing a build that simply never saved one.

Fixed names are findable and collidable in the same move: a second craft run in one session
writes the same paths, and an abandoned run leaves its files exactly where the next audit
globs. So every one of them opens with a RUN STAMP — `Run: <YYYY-MM-DDTHH:MMZ> ·
<product-slug> · <absolute project root>`, computed once at step 0 and copied byte-identical
onto each artifact. When a glob matches more than one file the audit resolves it by that
stamp — a match stamped to another project is dropped, the newest agreeing stamp wins, and an
undecidable set is reported with every candidate rather than silently picking the first hit.
Artifacts whose stamps disagree are a finding: `divergence.mjs`'s `craft-stamp` assertion
fails when they do, when one is stamped to a different project, or when one carries no stamp
while a sibling does. Artifacts written before this rule carry none, and a lone unstamped one
is used and reported as such.

One file DOES land in the project: the asset **provenance manifest**, written at step 4 under
one of the names the licence gate globs for — `ASSETS`, `CREDITS`, `PROVENANCE`, or
`THIRD-PARTY-NOTICES`. A manifest at any other path reads as absent to the gate. An
all-in-code build still owes one, as a first-party declaration.

A second thing lands in the project, and it is deliberately not one of the three above:
`.craft-layer/`, carrying a `.gitignore` holding `*`. It is git-invisible, and it is the only
craft artifact that must OUTLIVE the session — a run log in session scratch has no memory to
offer the next run, which is the whole point of it. It holds `run-log.md` (the project memory)
and `waivers.json` (see the divergence gate below).

### Why two runs no longer look alike

Anti-sameness used to be purely subtractive: a curated registry of overused spines, moves and
hues, refreshed once per release, that every run diverged FROM. A blocklist has exactly one
complement — push every run away from the same points and they all land in the same remaining
pocket. And because the registry was static within a release, run 2 and run 6 read a
byte-identical list, so nothing ever compared a run to the one before it.

Three things changed:

- **A concept deck, not just a blocklist** — the deck lives at
  `plugins/craft-layer/skills/creative-direction/references/concept-deck.md`. Five structural axes — composition strategy, colour behaviour, type role, motion role,
  graphic-system class — each with several STRATEGY options. A run DRAWS one option per axis
  and the creative-director generates its candidates inside that room. Options are strategies,
  never families, products or colour values: the same mechanical test `type-strategy.md`
  applies to type applies here — if the deck needs editing when a new typeface ships, it has
  become a catalog and must be reverted to constraints.
- **A project memory.** `.craft-layer/run-log.md` records what each completed run shipped —
  hue family, type strategy, spine, signature, and the five-axis draw. Step 0 reads it and the
  draw excludes what the last five rows used. An absent or malformed log is treated as empty:
  the run warns, seeds the draw from the brief text plus the date, and carries on. A bad log
  never fails a run.
- **A divergence FLOOR that scales.** The old floor was one departure at every tier, and the
  audit only fired when three conditions held together — so a single departure discharged the
  whole gate. The floor is now 1 / 2 / 3 by ambition, the departures must land on different
  fingerprint axes, and a divergence record that is present but hollow now fails on its own.
  An ABSENT record still reports `not checked`, and an explicitly requested conventional design
  is still a valid justification — the gate never forces novelty nobody asked for.
- **What the concept step ruled OUT travels too.** The record carries a negative-constraints
  block on three fixed keys — `Banned genus:`, `Banned register:`, `Banned vocabulary:` — and
  `Banned vocabulary:` is a comma-separated list of literal terms, not a description. It is
  copied verbatim onto `craft/build-task.md` as one of the lines the motion step resolves
  there — named, never numbered — so the builders get it as a rule, and the audit greps the
  whole shipped tree for its terms ONCE, after the build has finished, matching each term
  word-bounded and case-insensitively (a substring grep for a banned `REV` would fire on every
  `Reviews` and `Revenue` on the page, which is how a gate gets ignored; terms under ~4
  characters are written as quoted phrases). The keys are deliberately not deck-axis names: the divergence gate parses every
  `Key: value` line of the record, so a ban written as `Motion role: not diagrammatic` would
  silently overwrite the drawn option and leave the draw assertion grading a constraint
  string. A build that ships the exact genus its own concept step ruled out is the defect
  this block exists to end — that ruling used to live only in prose.

### The divergence gate — `plugins/craft-layer/template/craft-gates/divergence.mjs`

The attractor rules used to be advice. The audit checked that a type spec was RECORDED and said
outright that it never judges which family won, and `contrast.mjs` measured contrast, never hue
distance — so nothing could fail a build for landing on the model's default.

`divergence.mjs` is a plain Node script run from the project root. It asserts seven things and
exits non-zero on any of them: the accent hue is inside a category-default band; the accent hue
repeats one of the last five logged runs; a shipped font family is an anti-corpus entry; a
shipped family repeats a recent run; the recorded deck draw differs from recent draws on fewer
than three of five axes; one of the three BUYER spine slots is answered in an integrator's
register (`spine-register`, scoped by the build task's `Spine regions:` line); and the run's
craft artifacts disagree about which run wrote them (`craft-stamp`). No model judgement is
involved.

Three details that are load-bearing:

- **A missing or unparseable token source exits NON-ZERO**, printing `not measured`. Its sibling
  `contrast.mjs` exits 0 in that case — this gate diverges on purpose, because a silent pass on
  a missing file is exactly the failure teeth exist to end.
- **It reports where its anti-corpus came from.** The registry is refreshed per release but the
  script ships into your project, so it reads the live registry via `${CLAUDE_PLUGIN_ROOT}` when
  that resolves and falls back to a dated embedded snapshot otherwise — and prints which, with
  the date, on every run.
- **Brand echo is exempt from the repeat half.** A project with an existing brand palette or
  typeface is bound to echo it, and would otherwise fail from run 2 onward. The category-default
  assertions still apply: echoing a brand is a reason to repeat yourself, never a reason to ship
  the default.

Waive a finding with an entry in `.craft-layer/waivers.json` carrying a non-empty `reason`; a
waiver without one does not count.

### The concept fork

After the creative-director returns, the run presents two or three CONCEPT candidates — each a
different deck draw, spine and signature move — and you pick. This binds at every tier, not only
in `guided`, and it forks on the concept, never on three shades of one accent (`/ui-ux:theme`
already does colour at step 2). A headless run auto-picks and records `source: auto`. When fewer
than two candidates clear the usability floor there is no fork; the weak-round path in
`plugins/craft-layer/agents/creative-director.md` takes over.

This is the one exchange a `one-shot` run now carries — everything else about `one-shot` is
unchanged, and Part 6 of the offer contract states it.

### Research is inspiration, not a template

Mining used to name its Lane A sources by brand and then instruct the run to treat agreement
as the answer. That is a catalog feeding an averager: look at the same six products every
time, keep what they have in common, and the output is the category's centre of mass with a
different logo. Three changes:

- **A source CLASS, not a roster.** Lane A is now "the 2–4 interfaces THIS audience already
  compares the target against" — the brief names them, the file does not. It carries the same
  mechanical kill-trigger `type-strategy.md` applies to typefaces: *if this file would need
  editing when a new product launches, it has become a catalog.*
- **Principles, not properties.** The extraction worksheet gained a third column. Column two
  records what the source DOES; column three records the PRINCIPLE behind it and how this
  brief re-expresses it. A row whose third column merely restates the second is a copy, not a
  finding — and the file says so.
- **Agreement is a flag, not a convention.** Where sources converge is where the category is
  most predictable, so convergence is now something to diverge FROM, not adopt. The narrow
  exception — comprehension and accessibility conventions users genuinely rely on — has to be
  justified in the brief rather than assumed. One source may supply a principle; none may
  supply the arrangement.

Lane B's pattern galleries keep their names on purpose: they are breadth on a single pattern,
not a house look, and `ultra-craft`'s research mandate binds three of them by name as a search
floor the audit enforces.

### The brief the run actually acted on

The offer contract pinned eleven rows and echoed them, but nothing showed you how the run had
READ your words, and nine of those rows are inferred rather than stated — mode, ambition,
boost, archetype, palette mood, type strategy, stack, motion tier, content depth. The audit
deliberately refuses to re-infer a contract row from what shipped, so a wrong read was never
caught downstream; it just propagated.

Step 0 now opens with a brief pair, before any row is pinned:

```
Raw brief:      <your words, verbatim>
Upgraded brief: Objective  — the sharpened objective
                Implies    — constraints the brief carries but never states
                Undecided  — what it left open
```

Sharpen, never replace: where the upgrade and the raw line disagree, the raw line wins. And
every inferred row is now marked with what it was inferred FROM — `Ambition: maximal (inferred
← "make it pop")` — so a misread is visible at the one moment it is cheap to correct.

Both are a READOUT, not a question: a `one-shot` run gains no exchange from this. And both are
written into the persisted contract, not merely spoken, because a mark that lives only in the
echo leaves with the transcript.

### Seeing the work

A build once passed a clean typecheck, a clean lint, a 107,016-state sweep, measured WCAG
contrast and a full DOM assertion pass — then a single screenshot showed a leader label reading
`£1,200 DAILY CEILING — ABSOLUT`, clipped mid-word, on the first screen. A DOM assertion proves
an element exists, carries the right text and computes the right colour. It cannot see that the
text runs off the edge of its viewBox, that two annotations land on top of each other, or that a
fixed rail is covering the paragraph beside it. Those are the defects a reader meets first and a
query never meets at all.

So the run now looks at its own output, at **every** tier rather than only under the boost:

- **`gates.spec.ts` captures.** A `capture` trigger writes PNGs at 390, 768 and 1280, light and
  dark — a full-page shot plus a top-of-viewport shot at each. It settles first (scroll to the
  bottom, wait for fonts, lazy images and finite animations, scroll back) because a bare
  `goto()` frame shows an unrevealed page on exactly the scroll-orchestrated builds this plugin
  exists to produce. Capture never runs inside the reduced-motion, forced-colours or 200%-zoom
  contexts: those exist to break the page on purpose, and a shot of a deliberately broken page
  teaches nothing about the shipped design.
- **Something opens the images.** The audit reads them and reports what is visible, hunting the
  class DOM checks are blind to. A refused screenshot path is a reason to retry with an absolute
  path inside an allowed root, never a reason to declare capture impossible.
- **The run says which half ran.** The final message owes `Visual: <n> shots opened` or
  `NOT CAPTURED (<reason>)`. `NOT CAPTURED` is a legitimate outcome — a headless or unbuildable
  target genuinely cannot produce a frame — but it is stated, never implied by silence.
- **Two fixtures keep it honest.** `fixture-sight.html` carries the three defects on purpose and
  `fixture-sight-clean.html` is the identical page without them, so the checks are shown to fail
  for the right reason rather than merely to fail.

Some of this is machine-graded and some is not, and the split is deliberate. Text escaping its
viewBox, text clipped by a hidden-overflow box, and text-over-text overlap are asserted in code.
A fixed element covering content is **agent-graded** — it requires opening the image — and the
fixture header says so. "Structurally verified, not visually verified" is an honest report;
"verified" alone, when no image was opened, is not.

**Shots are captured at the audit, not during the build.** The suite writes two PNGs per
breakpoint — 390, 768, 1280, light and dark — into `.craft-layer/shots/`, and the audit OPENS
them and says what is visible. (Earlier versions also emitted progressive `build-NN-*.png` shots
after each section landed; that was dropped — it duplicated the audit's capture path for an
in-flight view nothing graded.)

### What "award-grade" means here — and what it does not

Several files in this plugin use *award-grade* as a quality bar. Checked against the
actual criteria of the field's main awards platform, that phrase is honest for one half
of the work and overclaims the other, so it is worth pinning down.

The main award weights **Design 40% · Usability 30% · Creativity 20% · Content 10%**, and
runs a **separate developer award** scored on Semantics/SEO, Animations/Transitions,
Accessibility, WPO, Responsive Design, and Markup/Meta-data, with a qualifying bar reported
as **above 7/10**; on the winners sampled, accessibility was the *lowest* sub-score.

(**Last verified 2026-07-25**, and the two halves are not equally sourced. The four weights
come from the platform's own evaluation page. The developer-award criteria and the 7/10 bar
do not — that page defers to a guidelines document that is not publicly readable — so they
rest on secondary reporting that agrees with itself, which is weaker and is marked as such.
Typography is **not** a scored criterion anywhere in the published rubric; it is one element
inside Design, and even that placement is secondary reporting. The argument below survives a
reweighting; the numbers do not.)

- **Those six developer criteria are, almost exactly, this plugin's gate set.** Motion
  with reduced-motion paths, responsive behaviour, performance budgets, semantics, and
  accessibility are what craft-layer measures. Together with Usability and Content — 40%
  of the main rubric, and the half that is genuinely gateable — this is the bar
  craft-layer is built to clear.
- **Half the Design 40% is art direction craft-layer cannot produce, and the split matters.**
  The top-tier winners are built on commissioned work: character illustration, photoreal 3D,
  bespoke type sculpture, cinematic rendering, made by specialist studios. The
  build-vs-source-vs-**commission** decision correctly returns "commission" for that
  class of asset, and the flow has no way to execute it (`asset-sourcing/references/sourcing-decision.md`
  says so plainly). No orchestration layer closes that gap.

  What the flow CAN execute is the other half: art direction authored in code — generative
  and procedural canvas, WebGL and shader surfaces, programmatic SVG systems, sprite systems,
  designer-authored vector. That is real art direction, it is reachable, and until the
  `maximal` ambition tier existed nothing asked for it: every gate was a ceiling, the one
  floor checked that a signature mechanism EXISTED, and a page could be commissioned as
  "award winning" and ship with no authored imagery at all with every gate green. The reach
  floors (see below) are the fix, and they are honest about their limit — a `maximal` build
  reached as far as code-authored craft goes, which is further than the default and is not
  the top of the field.

So: craft-layer aims at the developer-award criteria and the substance half of the design
rubric, on product work — landing pages, SaaS, CRMs. It does not aim at Site of the Year,
which is won with art direction rather than engineering. The signature-interaction floor
measures that a mechanism EXISTS, never its production value; those are different bars and
the plugin only claims the first.

### Dating volatile facts

A research pass over this plugin found the architecture sound and the **facts** rotten.
Everything wrong was a claim with a shelf life — a library version, a bundle size, a
maintenance status, a Baseline state. One reference asserted that a runtime was lighter
than its alternative when it is roughly three times heavier, with no date on the claim to
suggest it might have aged.

So: **any file asserting an OBSERVED FACT ABOUT THE WORLD carries a `Last verified: <date>`
line under its title**, naming what the date covers. Three categories, and only the first
one dates:

**Every shipped file kind, not just `references/`.** The convention was first applied to
references and the next round of facts landed in a command, an agent, and this README —
which is how a rule with an implied scope fails. A field anchor in `plugins/craft-layer/commands/audit.md` and
the award rubric quoted above are observed facts as much as a bundle size is; they are dated
inline, since those files have no header slot.

| Category | Dates? | Examples |
| --- | --- | --- |
| **Observed fact** — true of something we do not control, and can change without notice | **yes** | a library's gzipped size, a release version, a maintenance status, a Baseline/support state, a licence's terms |
| **Policy** — a ceiling or rule this plugin CHOSE | no | "a decorative sprite sheet stays under ~150 KB", the contrast ratios, the section-count floors |
| **Identifier** — a name used to refer to a thing | no | `@lottiefiles/dotlottie-react`, `motion/react`, `oklch()` |

A date on a timeless rule is noise, and noise is how a convention dies. Decision
procedures, taxonomies, and gates carry no date at all.

Two rules make it worth having:

- **A date on an unverified fact is worse than no date**, because it launders a guess into
  a checked claim. When only part of a file was re-verified, say which part
  (`physics-patterns.md` does) — and when a claim rests on secondary reporting because the
  primary source is silent or unreadable, say that too (the award rubric above does). A date
  records that someone looked; it does not record how good the source was, and the two get
  confused exactly when the claim is doing the most work.
- **One source of truth per number.** Where a SKILL body repeats a figure so a decision is
  pickable at a glance, the body names the reference as authoritative; on drift the
  reference is fixed and re-dated first, then mirrored. A SKILL body at its line cap
  discharges this through its References section rather than growing a second pointer —
  the delegation is what matters, not where it is written.
- **Something reads the dates.** `scripts/validate.sh` reports any `Last verified:` older
  than 180 days. It WARNS and never fails: a fact does not become wrong on a schedule, and
  a gate that fails on the calendar teaches people to silence it. The warning is a
  re-verification worklist, and re-dating without re-checking is the one move it cannot
  detect — which is why the "a date on an unverified fact is worse than no date" rule above
  stays a matter of discipline, not enforcement.

### Gates vs triggers

A **gate** is a defect type — wrong contrast, a missing spine slot, an absent signature. A
**trigger** is the condition that SURFACES a fault: the viewport, the zoom level, the motion
preference, the colour mode, the input device. Gate coverage can improve indefinitely while
the trigger set never changes, and any defect reachable only under an unfired trigger stays
invisible however careful the review is — so `/craft-layer:audit` reports both, and names the
triggers it did not fire.

`plugins/craft-layer/template/craft-gates/` ships the browser-driveable set as a drop-in Playwright suite
(200% zoom, reduced-motion, forced-colours, axe in both themes) plus the oklch-aware
contrast script. It runs in about two seconds. Copy it into a crafted project; the audit
hands it to any project that has no suite of its own.

### One-shot or guided

The offer contract declares a **mode**, in the same prompt as everything else:

| Mode | What happens | Use when |
| --- | --- | --- |
| `one-shot` *(default)* | the page is generated from the contract + concept, with the chain's own handoff points (stack, contract echo, token approval) still yours to answer | small page, a re-run, headless |
| `guided` | step 3 runs: you pick each section's treatment before it is built | broad or half-formed brief, the page IS the deliverable, or you want options |

`guided` is pinned by ASKING for it in any words — "guided", "section by section", "give me
options" — not by a flag.

### How much reach — the ambition tier

The contract pins a second dial the same way, from your own words:

| Tier | Pinned by | The build owes |
| --- | --- | --- |
| `restrained` | the `restrained` token, or "conventional", "trust-first", "keep it simple" | the signature floor only |
| `standard` *(default)* | the `standard` token, or saying nothing either way | the signature floor only |
| `maximal` | the `maximal` token, or "award winning", "awwwards", "over the top", "very graphical", "cinematic" — or naming heavy motion libraries as the POINT of the brief | the signature floor **plus** four reach floors |

**Say it outright rather than hoping it is read.** A leading `maximal`, `standard` or
Ambition is read from the brief's own prose — "award winning", "cinematic", heavy motion as the
POINT read as `maximal`; "conventional" or "trust-first" as `restrained`. There is **no ambition
token**. An earlier version accepted a leading `maximal` / `standard` / `restrained` word that
pinned the row outright; it was removed, because it silently ate the first word of a product
genuinely called "Maximal Fitness" and pinned a row prose already infers.

| What you want | What to type |
| --- | --- |
| an award-grade page from a cheap one-shot run | say so in the brief: `/craft-layer:craft an awwwards-grade <brief>` |
| the full process boost as well | `/craft-layer:craft ultra <brief>` |
| the same boost, in a form that also works mid-prose | `/craft-layer:craft ultra-craft <brief>` |

Ambition and boost are different axes and only one implication runs between them. Ambition is
what the OUTPUT owes; `ultra-craft` raises how hard the RUN works — live dated research, a
confirmed reference board, guided rounds, a red-team of the result. `ultra-craft` implies
`maximal`; `maximal` never implies `ultra-craft`. A boost that contradicts the brief's own prose
is asked about, not resolved silently.

The four reach floors, checked by the audit and waivable only by a reasoned divergence-record
entry: **three distinct motion capabilities** driving real surfaces (a tier or a sibling
engine each count once; two is what cheapest-that-fits produces on its own — one for the
signature, one for scroll); **one authored graphic system**
(generative/procedural canvas, WebGL/shader, programmatic SVG, sprites, or designer-authored
vector — rules, borders, icons and type treatment are composition and do not count); and an
**asset posture that is not first-party emptiness** (a manifest declaring nothing shipped
passes the licence gate and fails this floor — they ask different questions); and **one named
escalation** — at least one surface takes a tier the picker would not have chosen, marked
`(escalated ← <reason>)` on the build task. The first floor counts and three cheap capabilities
satisfy a count, so this one asks the question the count cannot: did anything depart from
cheapest-that-fits? The floor names no technique on purpose — a list every build escalates
INTO is how a fresh sameness gets manufactured, which is the failure the whole anti-sameness
side of this plugin exists to stop. It asks for the departure, not the destination.

Nothing is lowered for ambition. Reduced-motion, per-tier and cumulative motion budgets,
contrast, licence, and the delegated a11y pass are unchanged; reach is bought with lazy
loading, not with bytes on first paint. Detail:
`plugins/craft-layer/skills/creative-direction/references/ambition-tiers.md`.

### How hard the run works — `ultra-craft`

Ambition binds what the OUTPUT owes. It says nothing about how the run got there, so a
`maximal` page can still be built from one-shot defaults and design knowledge recalled from
training data. `ultra-craft` is the process boost, and it is a separate word on purpose:

| | Binds | Graded against |
| --- | --- | --- |
| `maximal` | what the build owes | the shipped tree |
| `ultra-craft` | how hard the pipeline works | the receipts it left |

Six bindings: `Ambition` pinned `maximal` and `Mode` pinned `guided` (not read from the
brief); research that actually **fetches** — six live sources minimum across three lanes,
each with a URL, a fetch date and a why-line, recall demoted to a lead labeled `unverified`,
and a category-scoped search recorded at each of three NAMED galleries (`land-book.com` for
shipped page structure, `awwwards.com` for reach and signature candidates, `dribbble.com` for
visual direction only — a shot is a concept, never evidence a pattern ships), because naming
a lane is not naming a source and a full source count never covers a gallery nobody opened;
a **reference board** persisted and echoed *before the first token is generated*, so you
redirect the direction while it still costs nothing; the concept and review agents dispatched
at a boosted tier while builders stay native; and a **red-team** of the shipped tree after
the audit. The audit reads the contract's `Boost` row back and checks the three receipts —
board, ledger, red-team record. Detail: `plugins/craft-layer/skills/ultra-craft/SKILL.md` and
`plugins/craft-layer/skills/ultra-craft/references/research-mandate.md`.

The red-team owes three rules beyond "look again"
(`plugins/craft-layer/skills/ultra-craft/references/red-team-contract.md`), each earned by a build that cleared
every gate and shipped a defect inverting its own claim:

| Rule | Catches |
| --- | --- |
| **Sweep the state space** — enumerate an interactive signature's reachable states and assert the concept's claims in each, rather than reasoning about representative values | the class where the mechanism works perfectly and means the opposite: a drag handle outside the region it defines in 107,016 of 107,016 states; a legend reading "Permitted" inside the excluded zone in 95% of them |
| **Attack the fix list** — treat every "fixed" claim as a claim and go to the source | padding swapped for different padding; a label rebound while the geometry stayed hardcoded; one gate fixed by breaking another |
| **Render it and look** — open the image before calling a surface verified | clipped text, overlapping annotations, truncation, fixed elements covering content — all invisible to DOM assertions and to a clean typecheck |

It implies `maximal`; `maximal` never implies it. It costs wall-clock, exchanges and bundle
weight — where the same brief also asks for fast or cheap, the run asks which order wins
instead of guessing.

```bash
# one-shot
/craft-layer:craft a landing page for Acme, an uptime monitor for solo devs

# guided, from the same prompt
/craft-layer:craft guided — a landing page for Acme, an uptime monitor for solo devs

# boosted: maximal + guided + live research + reference board + red-team
/craft-layer:craft ultra-craft a landing page for Acme, an uptime monitor for solo devs

# or decide sections for a page whose concept and tokens already exist
/craft-layer:sections the Acme landing page
```

Guided costs a handful of exchanges: **Shape** (one whole-page outline pick),
**Treatment** (3–4 sections batched per exchange, most consequential first), and at most one
**Signature** decision — under the exchange cap `section-decisions/references/decision-rounds.md`
sets, with *"decide the rest for me"* offered at every one and *"show me one option"* available
when you want a recommendation instead of a menu. It degrades
cleanly: no mockup plugins installed → written multiple-choice; headless → the whole agenda is
auto-decided, every ledger row marked `auto`, and reported.
