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
