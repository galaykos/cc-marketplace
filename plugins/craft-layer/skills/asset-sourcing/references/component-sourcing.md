# Component sourcing — where a SECTION comes from

`sourcing-decision.md` decides where an ASSET comes from. This file decides where a
COMPONENT BLOCK comes from — the nav, the footer, the pricing table, the FAQ, the
testimonial row, the form, and the one section carrying the concept's signature. It
decides on six axes and resolves to one of four categorical classes. Without it every
craft build writes every section from scratch, including the six whose answers are a
solved convention, and spends its scarce authoring effort on furniture.

**Which side of the categorical line this file sits on, and why.**
`../../creative-direction/references/moves-taxonomy.md` binds this plugin to CATEGORIES
plus when-to-use, never an enumerated catalog the agent picks from — because a catalog
feeding a generator manufactures a new sameness. This file obeys that rule the same way
`sourcing-decision.md` does: the classes below are the answer, and a specific registry
never is. Naming a registry as an EXAMPLE of a class is legal; naming one as THE answer
is the catalog failure. So this file curates no ranked list — which registries exist is a
property of the installed plugin set, discoverable at
`plugins/ui-ux/skills/<registry>-best-practices/SKILL.md`, and each such skill owns its
own conventions. **One place a registry MUST be named by name: the target project's own
provenance manifest.** The anti-catalog rule binds what this plugin SHIPS, not what a
build RECORDS about itself, and a provenance line reading "a registry" has recorded
nothing.

## The decision always runs

It is never skipped and never conditional. Skipping it when the target already has a
component library — the shape this rule was first written in — is self-defeating twice
over: it makes the `installed library` class unreachable by construction (its precondition
is exactly the condition that would suppress the decision), and it records NOTHING, so the
build task carries no line for `/craft-layer:audit` or the next session to read. An absent
decision is indistinguishable from a decision nobody made.

Resolve in order; the first that fits wins:

1. **Does the target already ship a component library?** A dependency the app imports, a
   generated `components/ui` tree from a prior init, an internal design-system package.
   → `installed library` for every conventional block, resolved IMMEDIATELY. This is a
   CONSTRAINT being recorded, not a choice being made — and the binding half is the
   negative one: **never introduce a second library beside it.** Two component systems in
   one tree costs more than every block this decision could have saved.
2. **Does this surface carry the concept's signature, its metaphor, or anything the brief
   makes unique?** → `first-party`, always. See the class boundary below.
3. **Is the block conventional furniture?** → `registry block, adapted`.
4. **Is it invisible plumbing?** → `registry block, as-is`.

## The six axes

Score every candidate against all six. Record the scoring on the build task's
`Components / provenance:` line so the choice is reviewable.

1. **Signature load** — does this surface carry the concept? Any signature load at all
   forces `first-party`; this axis is a gate before it is a score.
2. **Conventionality** — is the block's job an ANSWERED convention (nav, footer, pricing
   table, FAQ, testimonial, form, cookie/consent, auth screens)? Conventional furniture is
   where sourcing pays; a section the brief invented is not.
3. **Adaptation cost** — the honest accounting of restyle-to-tokens plus recomposition
   against writing the block outright. A block is cheaper only when adaptation is a token
   and layout pass; one that must be re-architected to fit was never a saving, and
   claiming it as one is how a build ships a foreign structure to protect a sunk paste.
4. **Licence / provenance** — can this block ship, under what obligations, and can its
   origin be DECLARED in a form the gate can read? An undeclarable block fails here before
   any other axis matters (`licence-discipline.md`, plus the marker rule below).
5. **Stack + dependency fit** — framework, styling primitive, and what the block DRAGS IN.
   A block importing a second animation engine collides with the cumulative motion budget
   (`../../motion-tiers/references/tier-budgets.md`); a block importing a second component
   system fails outright, per step 1.
6. **House style** — whose visual dialect the block speaks. This axis is the diversity
   lever and the sameness risk at once, and which one it turns out to be depends entirely
   on whether the block was restyled.

Licence/provenance and stack fit are GATES: fail either and the block is out regardless of
the other four.

## The four classes

The taxonomy is CATEGORICAL. These are the only classes; a named registry is never one.

### 1. first-party

The block is authored in the repo, in the build's own tokens and composition strategy.
- **Pick when** the surface carries signature load, the brief makes it unique, the layout
  is the concept's argument, or no conventional block answers the job.
- **Provenance** — first-party by definition; no marker, no manifest record.
- **Cost/risk** — authoring time, spent where it shows.

### 2. registry block, adapted

An openly-licensed registry block is taken as a STARTING STRUCTURE and restyled to the
build's tokens and composition strategy.
- **Pick when** conventionality is high, signature load is zero, and the adaptation is a
  token/layout pass rather than a rewrite. This is the common answer for the furniture
  sections named on axis 2.
- **Provenance** — third-party: marker + manifest record, both required.
- **Cost/risk** — the restyle is the whole value; an unrestyled block is class 3 wearing
  this class's label, and is a finding (below).

### 3. registry block, as-is

The block ships unmodified.
- **Pick when** it is INVISIBLE PLUMBING — a visually-hidden utility, a portal/overlay
  primitive, a focus-trap or dismiss wrapper, an unstyled headless primitive. Nothing the
  visitor reads as design.
- **Provenance** — third-party: marker + manifest record, both required.
- **Cost/risk** — on any surface the visitor actually sees, this class reproduces the
  category-default composition catalogued in
  `../../creative-direction/references/sameness-fingerprint.md`. A registry's house style
  is a fingerprint default in exactly the way a default icon set is.

### 4. installed library

The target project already has one, and it wins.
- **Pick when** step 1 found it. Recorded, never chosen.
- **Provenance** — the library is already a declared dependency; record which one on the
  build-task line so the next session does not re-run this decision.
- **Cost/risk** — the library's conventions bind the build's composition; the concept
  reaches the surface through tokens and the signature section, not through a second kit.

## The signature is never sourced (class boundary)

A registry block cannot carry the signature interaction BY DEFINITION: the signature is
the one move that is this brief's and no other's, and a block published for general reuse
is the opposite claim. A build whose signature section came from a registry has not
sourced a component — it has replaced the concept with someone else's. The signature gate
(`../../../agents/craft-reviewer.md`, the motion FLOOR) grades whether the named mechanism
shipped; it does not ask where the markup came from, so this boundary holds by discipline
and by the marker record, not by that gate.

## What "adapted" has to mean

Four things a restyle touches, or the word is a colour swap: the build's **tokens**
(colour, type, radius, elevation, spacing — never the registry's defaults), the
**composition** (the section's shape and rhythm per the concept, not the block's demo
layout), the **motion** (the build's tier decisions, not the block's house transitions),
and the **copy** (the client's own words per `../../creative-direction/references/content-source.md`,
never the block's placeholder text). A block that kept the registry's defaults on any of
the four has shipped that registry's dialect under this build's name.

## Provenance — the marker, and what the gate can actually see

**Start from the honest limit.** The licence gate CANNOT see a sourced component. Its
orphan scan enumerates committed asset FILES and third-party source REFS — absolute-URL,
inline `data:`, over-threshold `<svg>` with a marker, URL-fetched — and a pasted,
restyled block is ordinary first-party-looking source with no URL and no file signature.
It matches no branch. So "a registry block belongs in the manifest the same way a font
does" is FALSE as an unaided claim, and shipping it unqualified would be exactly the
defect this discipline exists to end: a rule stated in prose and recorded as a gate.

**The route taken here is the greppable marker**, because the alternative — declaring the
obligation and admitting nothing can check it — leaves the honest builds and the silent
ones identical to every reader. Every block in class 2 or 3 carries ONE line, in a comment
adjacent to the block's root/export (top of file when the file IS the block):

```
component-source: <class> · <origin + block name> · <licence-class> · component:<id>
```

`<class>` is `registry-adapted` or `registry-as-is`. `<origin + block name>` names the
actual registry and block — this is the one place naming names is REQUIRED.
`<licence-class>` is a token from `licence-discipline.md`. `component:<id>` is the manifest
key, mirroring `inline:<id>`.

The manifest (`licence-discipline.md`'s existing file, at one of its accepted names)
carries the matching record: `ref: component:<id> · origin: third-party ·
licence-class: <token> · source: <registry> <block> @ <version-or-date>`.

**Class 4 is recorded ONCE, not per block.** An installed library is already a declared
dependency, so one manifest record for the library plus the build-task line is the whole
obligation; a marker on every component that touches it would be noise the scan then has
to wade through. The exception is a block LIFTED out of such a library and modified in
place — that is class 2 in substance and takes a marker like any other.

**What the extended orphan scan checks (teeth):** both directions of correspondence — a
`component-source:` marker with no manifest record is an orphan finding, and a
`component:<id>` record naming an id no marker in the tree carries is a stale-record
finding. Both are one grep, and both are decidable.

**What it still cannot see (declared blind spot, binding to state):** an UNMARKED pasted
block. Unmarked source is presumed first-party — the same presumption
`licence-discipline.md` grants a sub-threshold inline blob, and for the same
decidability reason. The marker converts an invisible obligation into a DECLARED one that
is then checked; it does not make detection complete. Anyone quoting this gate says both
halves or over-claims it.

## Registry choice as a diversity lever — recorded, not gated

Registries have genuinely different house styles, so which one a build draws from is a
real fork in visual outcome, not a procurement detail. Record it: the marker's `<origin>`
field and the build-task line together say which registry this run drew from, which is the
input a don't-repeat-recent rule would need — the rule that already exists for hues and
typefaces (`hue-repeat` / `font-repeat` in `../../../template/craft-gates/divergence.mjs`).

**No assertion enforces this today, and none is scheduled by this file.** The run log's
row is seven columns (`date · brief-slug · hue-family · type-strategy · spine · signature
· draw`) and carries no registry column; `divergence.mjs` has no `registry-repeat` check.
Two runs may draw from the same registry with nothing anywhere reporting it. Making it a
gate needs a run-log column APPENDED AT THE END — the parser maps cells POSITIONALLY
against the header, so a column inserted anywhere else shifts every historical row's
values into the wrong keys and the repeat checks then grade garbage as a pass; a
wider-than-header row is reported, which is a note about width and not a defence against a
mis-positioned key — plus its own assertion beside the two existing repeat checks. Until
both exist this is a recorded decision, not a gate — and the cheap half is already worth
having, because a decision nobody recorded cannot be diverged from later.

## Survey the registry before picking from it — recorded, not gated

The section above asks WHICH registry. This one asks how much of it the run actually saw,
and it is the half that decides whether a registry buys structure or decoration.

A run briefed on two named registries shipped **one** component from a **270**-component
registry and four primitives from a 1051-component one, and picked, from a catalogue
holding Hero Parallax, Sticky Scroll Reveal, Bento Grid, Container Scroll and Tracing Beam,
the generic hover-card. The run's own note recorded that registry as holding "~60" — it had
never counted, and the estimate it substituted was off by a factor of four in the direction
that made the pick look reasonable. Nothing was wrong with the pick in isolation. What was wrong is
that the alternatives were never enumerated: the run worked from what it could RECALL of
the registry instead of from what the registry CONTAINS, and recall is biased toward
whatever is most common, which is the definition of the default this plugin exists to
leave. That registry answered 200 on every path, the whole time.

**A gated registry gates the ENDPOINT, not the component.** The same run hit the other
registry's install path, took a 401, and stopped there. The 401 was real — that host
answers `Authentication required … Bearer YOUR_LICENSE_KEY`, and a licence key is not
something this flow may request, hold, or enter. But the components behind it were MIT in
the project's own repository, and MIT is MIT wherever it is served from. A licence check on
a CONVENIENCE API is a fact about paying for tooling; the question `licence-discipline.md`
asks is what terms the CODE carries. Read the repository's LICENSE, take the source from a
path that is actually open, and record THAT retrieval path in `PROVENANCE.md` rather than
the one that was attempted.

Both directions of this are wrong and the run made each in turn: a paywalled installer
reported as an unavailable component, and later — reading the vendor's own "free and
open-source" page — a gated endpoint reported as open. Marketing copy describes the
project; an HTTP status describes the endpoint; the LICENSE file describes the terms.
Cite the one that answers the question being asked.

**Enumerate, then pick.** Before the class decision in "The four classes" runs for a
surface, the run needs the registry's actual index in front of it, not its memory of one:

- **The shadcn MCP server is the cheap way** and it works with any shadcn-compatible
  registry — `npx shadcn@latest mcp init --client claude`, with third-party registries
  declared in `components.json` under `registries` (`{"@acme": "https://…/{name}.json"}`).
  It exposes search and view, so "what does this registry have for a hero" becomes a query
  rather than a recollection.
- **Without MCP, fetch the registry index** (`/registry.json`, the components listing page)
  and read it. A fetch that fails escalates the same way research does — and a 401 on a
  guessed path is evidence about the PATH, never about the terms.

**The index also prices the run's motion reach, which nothing else does.** A registry index
lists each item's dependencies, so reading it answers a question the tier picker otherwise
answers by guessing: what a block COSTS. One registry's index resolves to `three`,
`@react-three/fiber`, `@react-three/drei`, `three-globe`, `cobe`, `simplex-noise` and
`@tsparticles/*` — meaning a 3D capability can arrive as a component choice rather than as
a separate engine decision, and meaning a casually-picked block can put a WebGL runtime in
the bundle that nobody budgeted. Both directions matter: `ambition-tiers.md` floor 1 wants
three distinct capabilities and the section below forbids buying them with house motion, so
the index is where a build learns which blocks would do that BEFORE installing one.

**Record the survey on the build task**: which registries were listed, roughly how many
components were in scope, and what was picked. Two lines. The point is not an audit trail
for its own sake — it is that a run which writes `surveyed: 60, picked: 1` has been made to
notice the ratio, and a run that never counted cannot notice anything.

**No script gates this, and none can.** "Components considered" leaves no trace in the
shipped tree; only the picked ones ship. This binds the BUILD and is checkable by the
`craft-reviewer` agent only insofar as the build task records it. Treat a maximal-ambition
build that drew one generic block from a registry full of structural ones as an under-reach
— and note that it will not surface as a component finding, it will surface as
`composition-shape` failing in `../../../template/craft-gates/divergence.mjs`, because the
structure those unseen components would have carried is exactly what that check measures.

## An unrestyled block is a finding

A class-3 block on a surface the visitor reads, or a class-2 block that kept the
registry's tokens, motion and layout, is a finding at `/craft-layer:audit` — the same
standing as a divergence-record entry contradicted by what shipped.

**Named checker:** the `craft-reviewer` agent's licence/provenance step, which greps the
markers. It is AGENT-GRADED, not a script: the class-declaration half is decidable (a
`registry-as-is` marker on a block rendering visible page content), and the "was it
actually restyled" half is judged the way that agent already judges divergence-record
entries — one at a time against the shipped source. **No script implements either half**,
and `gates.spec.ts` / `divergence.mjs` do not see components at all. Recording that plainly
is the point: an agent-graded check is a real check with a known variance, and calling it
a gate would be the over-claim.

## A registry's house motion must not satisfy an ambition reach floor

Floor 1 of `../../creative-direction/references/ambition-tiers.md` counts three distinct
motion capabilities DRIVING real surfaces — capabilities the build decided on, not
capabilities that arrived inside someone else's block.

**And this clause is currently unenforceable, which is the useful part to know.** Floor 1
is measured by import-grep (`/craft-layer:audit` step 1 detection), and a registry block
importing an animation engine registers that capability exactly as first-party code does.
The detection cannot tell a decided capability from an inherited one. The discriminator
that WOULD make it checkable: count toward floor 1 only capabilities named on the build
task's `Motion:` line AND cross-checked as present in the tree — the two-sided test floor 4
already applies to its escalation mark. The audit does not apply it to floor 1 today, so
this clause binds the BUILD (do not buy reach with house motion you did not choose) and
binds no gate. Treat a `maximal` build whose third capability came from a pasted block as
an under-reach the audit will not catch.

## What has teeth and what is recorded

| Statement | Enforced by | Standing |
| --- | --- | --- |
| Marker ↔ manifest correspondence, both directions | orphan scan (`craft-reviewer`, licence gate) | **gate** — one grep, decidable |
| Unmarked sourced block | nothing — presumed first-party | declared blind spot |
| Class 2/3 carries a marker at all | the same scan, on what IS marked | **gate** for declared blocks only |
| `registry-as-is` on a visible surface | `craft-reviewer`, agent-graded | finding, no script |
| An `adapted` block that was not actually restyled | `craft-reviewer`, agent-graded | finding, no script |
| Registry recorded per run (diversity lever) | build-task line + marker | **recorded, ungated** — no log column, no assertion |
| House motion must not satisfy floor 1 | nothing — import-grep cannot discriminate | **unenforceable today**; discriminator named above |
| Never a second component library | this file + the build-task line | discipline, agent-graded |

## Anti-patterns

- **A registry as the answer** — "use the <registry> pricing block" written as the
  decision. The class is the decision; the registry is what the RECORD names afterwards.
- **Sourcing the signature** — the one class boundary that has no exception.
- **Paste-and-ship** — class 2 declared, class 3 delivered; the restyle is the value.
- **A second library** — introduced beside one the target already had, to reach a block.
- **Silent sourcing** — a pasted block with no marker. It passes every gate here by being
  invisible to them, which is the reason to state the blind spot rather than paper it.
- **Reach bought from a block** — a third motion capability that arrived inside sourced
  markup and was counted as the build's own.
