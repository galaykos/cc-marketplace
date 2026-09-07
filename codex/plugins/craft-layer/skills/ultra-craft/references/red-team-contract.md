# Red-team contract — what the panel owes beyond "look at it again"

The audit grades GATES: is there a signature, does reduced motion have a path, does the
manifest declare what shipped. A gate is a checklist, and a checklist cannot ask the question
that matters most — *does the thing mean what it claims to mean?* That is the red-team's job,
and two rules below exist because a run cleared every gate and still shipped a page whose
central instrument argued the opposite of its thesis.

Both are binding at `ultra-craft`.

## Rule 1 — sweep the state space, do not reason about it

**When it applies:** the concept's signature is an INTERACTIVE INSTRUMENT — controls the
visitor operates that drive geometry, layout, or content. Anything where the rendered output
is a function of user-set values.

**What the panel does:** enumerate the reachable state space and assert the concept's own
claims in EVERY state. Not representative values, not the default, not "a few edge cases" —
the product of the control ranges.

**Why reasoning fails here.** The defect class this catches is the one where the mechanism
works perfectly and means the wrong thing. Reading the code, it is correct: the handle is
placed at the corner the controls define. Running the default, it looks right. Only
enumeration reveals that the corner is outside the permitted region in *every reachable
state*, so the page's grab handle lives in the zone the page argues is impossible. No gate
specifies that. No reviewer reading one rendered state sees it.

Three findings from the run that produced this rule, each invisible to gates and to
single-state inspection:

- a drag handle outside the envelope in **107,016 of 107,016** states;
- a legend reading "Permitted" printed inside the excluded region in **101,702 of 107,016**
  states, including the default;
- a trace clipper reporting "move 0 of 10" with an empty path and a marker drawn outside the
  boundary it named, in **2,788** states.

**Sizing the sweep.** Integer controls with small ranges: take the full product. Continuous or
large ranges: a dense lattice plus every boundary value plus the corners where two controls
are simultaneously extreme. Above roughly a million states, sample — but then SAY the sweep
was bounded and how, because "swept" and "sampled 1%" are different claims and only one of
them justifies "in every state".

**What to assert.** Turn the concept's load-bearing claims into predicates. If the concept
says a region is impossible, assert nothing interactive renders inside it. If it says a
control is a hard ceiling, assert no state exceeds it. If a label names a region, assert the
label is inside the region it names. The predicates come from the divergence record, not from
the reviewer's taste.

**Report shape:** `<states swept> / <states violating> / <a concrete violating input>`. A
violation with no reproducing input does not count.

## Rule 2 — attack the fix list, not only the original build

A post-audit fix report is a confident self-assessment written by the author of the defects.
That is precisely the artifact adversarial review exists to break, and it arrives already
written down, so the marginal cost of attacking it is close to zero.

**What the panel does:** treat every "fixed" claim as a claim. Go to the source, and try to
prove the fix does not do what its author says it does.

**The three shapes seen so far**, each of which passed a re-read and failed a refutation:

- **Padding swapped for different padding.** A motion capability counted toward a reach floor
  was replaced by another thing that also is not a motion capability. The count still read 3;
  the reality was still 2.
- **The label bound, the geometry not.** A dimension arrow whose *value* was rewired to a real
  numeral while its endpoints stayed hardcoded pixels. The refutation is one sentence: change
  the numeral and the drawing is identical.
- **One gate fixed by breaking another.** Making a dark theme reachable satisfied the theming
  gate and simultaneously violated the divergence record's explicit refusal of the dark
  register. The fix report mentioned the first half.

**The tell to hunt for:** a fix that changes what a document SAYS without changing what the
code DOES, and a fix whose report is narrower than its blast radius.

**Ordering:** the fix-list pass runs after fixes are applied and before the run is called
done. A run that fixes findings and stops has verified nothing about the fixes.

## Rule 3 — render it and LOOK, before calling any surface verified

A DOM assertion proves an element exists, carries the right text, and computes the right
colour. It cannot see that the text runs off the edge of its viewBox, that two annotations
land on top of each other, or that a fixed rail is squeezing the column beside it. Those are
the defects a reader meets first and a query never meets at all.

In the run that produced this file, a build passed a clean typecheck, a clean lint, a
107,016-state sweep, measured WCAG contrast, and a full DOM assertion pass — and then a single
screenshot showed a leader label reading `£1,200 DAILY CEILING — ABSOLUT`, clipped mid-word,
on the first screen. Two more of the same class sat in the signature section.

**What the panel does:** capture the shipped surface at the breakpoints that matter, open the
image, and describe what is actually visible. Specifically hunt the class that DOM checks are
blind to: text clipped at a container or viewBox edge, overlapping labels and annotations,
truncation ellipses, fixed elements covering content, and any element whose rendered position
differs from where the markup implies it sits.

**When a screenshot will not save:** retry with an absolute path inside an allowed root before
concluding the capability is unavailable. A tool that refuses one path is not a tool that
cannot write. Declaring "visual verification is impossible here" without that retry is the
same failure as any other unverified assertion — and it is the one that lets every defect in
this rule's class through.

**Never claim a surface looks right without having looked.** "Structurally verified, not
visually verified" is an honest report. "Verified" alone, when no image was opened, is not.

## What these rules share

Neither asks the panel to have better taste than the author. Both ask it to check a claim
against something mechanical — an enumerated state space, or the source behind a sentence.
That is why they work when a re-read does not: a re-read shares the author's model of the
system, and the model is usually where the defect lives.

## Reporting

Per attacked claim: the claim, a verdict of `refuted` or `survives`, and evidence citing
`file:line` or a reproducing input. Default to `refuted` when uncertain — a panel that blesses
under doubt is worse than no panel, because it launders the doubt into a receipt.

State plainly when a panel did not run, or ran as a single inline pass. Never report a panel
that did not happen.

## Anti-patterns

- **Representative-value review** — checking the default state and two hand-picked extremes on
  an instrument with a six-figure state space, then reporting it as verified.
- **Sweep without predicates** — enumerating states and asserting only "it did not crash". The
  concept's claims are the assertions; absent them the sweep proves the code runs.
- **Unbounded sweep claimed as total** — sampling and reporting "every state".
- **Fix list taken on trust** — re-reading the fix report rather than the code it describes.
- **Blessing under doubt** — `survives` used to mean "I could not tell", which converts an
  unexamined claim into a passed one.
