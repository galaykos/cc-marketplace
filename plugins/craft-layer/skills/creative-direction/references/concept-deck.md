# Concept deck — the positive generator

`sameness-fingerprint.md` is SUBTRACTIVE: it says what a build must move away from. A
blocklist has exactly one complement, so a run pushed off the same points lands in the same
remaining pocket every time. This deck is the other half — a POSITIVE generator that gives
each run a distinct starting point before a single candidate is written.

**Drawn from, never chosen from.** A craft run DRAWS one option per axis under the seeding
rule below. Nobody picks the combination they like best; picking is how a taste attractor
reasserts itself through the front door. An option that genuinely cannot serve the brief is
REDRAWN on that axis alone, with the reason recorded — never quietly swapped for a
favourite.

**A draw is a constraint, not a design.** The five drawn options are the STARTING
CONSTRAINT the concept must work inside. They are not a description of the finished page,
not a section list, and not a substitute for the concept: the creative-director still
generates blind candidates, still scores them, and still has to break the anti-corpus. The
draw only decides which room that reasoning happens in.

**The kill-trigger.** Every option here is a STRATEGY — a way of organising, of carrying
meaning, of spending motion. If this deck would need editing when a new typeface, library,
or product ships, it has become a catalog, and a catalog is how an anti-sameness engine
manufactures a fresh sameness. No option names a family, a product, a vendor, or a colour
value; cataloguing named defaults to diverge FROM stays `sameness-fingerprint.md`'s job,
under its anti-corpus exception.

## How the draw is seeded

1. Read `<project>/.craft-layer/run-log.md` and take the `draw` cell of the last 5 rows.
2. EXCLUDE every option those rows used — the exclusion window is the last 5 draws,
   applied per axis. If an axis has fewer than two options left, drop its oldest exclusions
   until two are drawable again.
3. When the log is absent, empty, or malformed, seed from a hash of the brief text plus
   today's date. A missing log is a first run, never an error.
4. Draw ONE option per axis — five in total — and record them before generating candidates.

## Recording the draw

Write the draw into `craft/divergence-record.md` as five lines, ONE PER AXIS, in the form
`<axis-name>: <option-name>`:

```
Composition strategy: Broken grid
Colour behaviour: Value-driven, hue-flat
Type role: Type as diagram
Motion role: Motion as evidence
Graphic-system class: Diagrammatic system
```

The run log's `draw` cell carries the same five option names joined by ` / `. The audit's
machine gate parses these lines and compares the draw against the logged history, so spell
the axis names exactly as the headings below.

The record's FIRST line under its title is the run stamp — `Run: <instant> · <product-slug>
· <absolute project root>`, copied byte-identical from the contract
(`offer-contract.md` Part 8). It is what tells this run's record from the previous run's at
the same fixed path, and `Run` is not a deck axis, so it is never parsed as one.

## Recording what the build may NOT be

A draw says which room the concept is generated inside. It says nothing about which room
the build must stay OUT of — and that second half is what a prior build in a sibling
directory, an adjacent product of the same client, or a drawn option's laziest execution
makes urgent. A drawn `Diagrammatic system` sitting next to a prior drafting-sheet build
walks straight back into it unless something forbids it by name.

So the record carries a NEGATIVE-CONSTRAINTS BLOCK beside the draw — up to three lines,
each naming what is off-limits and why:

```
Banned genus: technical drafting sheet — the prior build in the sibling directory ships it, and the drawn Diagrammatic system defaults back into it
Banned register: draughting-office sheet labelling
Banned vocabulary: SHEET, TITLE BLOCK, "REV A", "DRAWN BY", SCALE 1:1, first angle projection
```

**The three keys are fixed and the line format is a hard rule.**

- Exactly these keys: `Banned genus:`, `Banned register:`, `Banned vocabulary:`. One
  constraint per LINE, never wrapped — a continuation line is read as its own line.
- `Banned vocabulary:` is a COMMA-SEPARATED list of literal strings: the terms a grep can
  find in shipped source. A described register ("nothing draughting-flavoured") is not
  greppable, so it belongs on `Banned register:`, which a reading agent grades, beside a
  vocabulary line that a command can actually fail on.
- **How a term is MATCHED — stated here once, cited everywhere else.** Each term is greped
  **word-bounded and case-insensitively**. Not a substring: a substring grep for a banned
  `REV` hits *Reviews*, *Revenue* and *Reveal*, and one for `DRAWN` hits *drawn from* — a
  landing page is full of all four, so every one becomes a finding the run must explain away,
  and a gate that fires on correct copy is waived into silence inside one run. A term shorter
  than ~4 characters, or one that is an ordinary English word on its own, must therefore be
  given as a **quoted phrase** carrying the context that makes it the banned thing — `"REV A"`
  and `"DRAWN BY"` above, never bare `REV` and `DRAWN`. A quoted phrase is matched whole,
  quotes stripped. `/craft-layer:audit`, `craft-reviewer` and `orchestration`'s
  `tree-wide-gates.md` all CITE this paragraph rather than restating it: a second statement of
  match semantics is a second semantics, and the two disagree the first time either is edited.
- **NEVER restate a constraint as an axis line.** A line reading `Motion role: not
  diagrammatic`, or `Graphic-system class: not a drafting sheet`, is the defect written
  twice: the audit's machine gate scans EVERY line of this record with a generic
  `Key: value` regex, matches any key naming a deck axis, and assigns it unconditionally,
  last-write-wins. Such a line silently REPLACES the drawn option, and the draw-repeat
  assertion then compares a constraint string against the logged run history and reports a
  verdict on garbage — no error, no warning, no symptom. The three `Banned …` keys are
  chosen because no deck axis is named that way; inventing a fourth key re-opens the
  collision, so extend the vocabulary list instead of adding a key.
- One reason per line, after an em dash. A ban nobody can trace is waived by the first
  agent who finds it inconvenient.
- Nothing to ban is a legitimate outcome: write `Banned vocabulary: none` rather than
  dropping the line, so a later reader can tell a considered nothing from a skipped step.

This is a per-run constraint, not a deck entry — naming one build's forbidden genus here
does not make this file a catalog, because nothing in the list above is drawn FROM.

**Where the block goes next, because a record nobody reads bans nothing.** Two hand-offs,
and both are required:

1. `Banned vocabulary:` is copied VERBATIM onto `craft/build-task.md` as one of the lines the
   motion step resolves there, so the builders receive it as a rule in their dispatch rather
   than as background. Named, never numbered — the build task's line set grows, and a
   positional claim about it is wrong the next time it does.
2. Its terms are the input to ONE tree-wide grep the audit runs over the whole shipped
   tree, after every parallel builder has finished. N builders each grepping their own
   files is not that check: each reports green over its own subset and the ban is verified
   nowhere. The general form of that rule — one cross-cutting gate, run by the
   orchestrator after fan-in — is `orchestration:delegation-contracts`'
   `references/tree-wide-gates.md`.

## Axis 1 — Composition strategy

How the page is spatially organised.

- **Strict column grid** — everything snaps to one declared measure, and the grid is meant
  to be legible as structure.
- **Broken grid** — one ordered field with deliberate, argued escapes; the exceptions carry
  the meaning.
- **Full-bleed panels** — a sequence of edge-to-edge zones, each with its own local logic.
- **Asymmetric split** — a persistent unequal division held down the page (a fixed side
  against a moving side).
- **Centred spine** — one narrow measure top to bottom; everything hangs off the centre.
- **Layered depth stack** — planes overlap and occlude, so hierarchy comes from stacking
  rather than from size.
- **Off-axis field** — the organising direction is not the page edge.
- **Placed clusters** — discrete positioned groups on an open canvas instead of a running
  flow.

## Axis 2 — Colour behaviour

How colour carries meaning — not which colour.

- **One exception** — a single quiet field where exactly one hue appears, only where the
  argument turns.
- **Two-temperature system** — a warm/cool opposition does all the classifying work.
- **Value-driven, hue-flat** — lightness alone builds hierarchy; hue stays constant.
- **Sectional environments** — each section owns a colour room, and scrolling changes rooms.
- **Material-derived** — colour comes from the depicted substance or substrate, never from
  a palette picker.
- **Colour as encoding** — hue is reserved for encoding values and is banned as decoration.
- **Polarity flip** — the page runs in one polarity and inverts wholesale at the argument's
  hinge.
- **Loud ground, quiet marks** — the field carries the colour and the content stays neutral.

## Axis 3 — Type role

What typography is doing in the argument.

- **Type is the image** — no pictorial hero; the setting itself is the visual.
- **Type recedes** — typography deliberately steps back so imagery or data carries the page.
- **Editorial voice** — the page reads as a publication: headline, standfirst, byline,
  running text.
- **Type as control surface** — typography does a working tool's labelling job; it is
  instrumental, not expressive.
- **Single-voice discipline** — one family, hierarchy from weight and size alone; contrast
  comes from restraint.
- **Two-voice argument** — a deliberate classification clash that mirrors an opposition in
  the content.
- **Type as diagram** — words are POSITIONED to show a relationship, not only to be read.
- **Documentary plainness** — the setting claims no style at all; the content is the whole
  claim.

## Axis 4 — Motion role

What motion is for. (Every option still obeys the reduced-motion and keyboard floors.)

- **Motion as continuity** — movement exists only to explain where a thing went.
- **Motion as evidence** — animation demonstrates the product's actual behaviour.
- **Motion as pacing** — timing meters how fast the argument can be taken in.
- **Motion as material** — movement reveals what things are made of: weight, friction,
  give.
- **Motion as reveal** — sequence is the point; what is withheld, and when it lands.
- **Motion as feedback** — nothing moves except to confirm that an action registered.
- **Stillness by design** — near-zero motion is the statement; only state changes move, and
  the restraint is argued.

## Axis 5 — Graphic-system class

What kind of AUTHORED graphic the build owns.

- **Photographic system** — art-directed photography under a stated shooting rule (angle,
  light, crop).
- **Drawn system** — an illustration language with a stated construction rule (weight,
  joinery, viewpoint).
- **Diagrammatic system** — the build's own explanatory drawings; the graphic IS the
  explanation.
- **Parametric system** — marks produced by a rule the build authors and states.
- **Typographic ornament** — the graphic layer is built out of the type system itself
  (rules, marks, glyph forms).
- **Dimensional system** — modelled or rendered objects under a stated staging rule.
- **Document artefact** — forms, tickets, scans, plots treated as authored objects rather
  than decoration.
- **Declared none** — the build ships no graphic system and says so; layout and type carry
  everything, and the absence must be argued.

## Anti-patterns

- **Choosing instead of drawing** — reading the deck and picking the combination that feels
  right; that reproduces the attractor the deck exists to escape.
- **Redrawing until it is comfortable** — one redraw per axis, with a recorded reason. A
  second redraw is a choice wearing a draw's clothes.
- **Treating the draw as the design** — shipping the five option names as if they were a
  concept; they are the constraint the concept is generated inside.
- **Letting the draw license a default** — if a drawn option's laziest execution IS an
  anti-corpus entry, the draw does not excuse it; find the other execution.
- **Adding named answers** — an entry naming a typeface, product, vendor, library or
  colour value turns this file into a catalog and retires it.
- **Skipping the record** — an unrecorded draw cannot be excluded next run, so the log
  never accumulates and the deck degrades into a coin toss.
- **Banning in prose** — writing "we should avoid the drafting-sheet look" into the
  record's narrative instead of onto `Banned vocabulary:`. Nothing greps a paragraph, the
  builders never see it, and the build ships the banned register with every gate green.
