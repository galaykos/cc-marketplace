---
description: Decide a crafted page section by section with the user — batched option rounds recorded in a section ledger.
argument-hint: [page-or-scope]
---

# /craft-layer:sections

Run the guided section-decision loop for the page in `$ARGUMENTS` (if empty, ask
which page or scope is being decided). Apply the `section-decisions` skill from
this plugin and follow it exactly. This command decides; it builds nothing.

Standalone entry point. Inside `/craft-layer:craft` this same loop runs as its
guided step — use this command to decide a page whose concept and tokens already
exist, or to re-decide one section later.

## Steps

1. **Load the contract and the concept.** Read the run's offer contract
   (`skills/creative-direction/references/offer-contract.md` — product, audience,
   primary action, routes, length, mode) and the concept + divergence record. No
   contract yet: pin one first per that reference, or run `/craft-layer:craft`,
   which does it as step 0. Options that contradict the concept are not on the
   menu.

2. **Derive the agenda.** Turn the contract's spine slots into agenda items in
   spine order, expanded per `content-depth.md`'s archetype anchors, plus an
   order-and-rhythm item when the contract declares `long-scroll`, plus the one
   `concept` slot (the concept's metaphor as a section in its own right — offered
   in Round 1, declining it is a legitimate pick). Never add an item beyond those. Where the archetype's section ceiling sits below the
   spine's slot count, slots COMBINE rather than being dropped — Round 1 decides which. Show the agenda before the first question
   so the user knows the length of what they are agreeing to.

3. **Consume what is already decided.** A taskmaster spec, a `## Visual contract`
   section, or an existing ledger for this run: fold those into the ledger as
   settled rows and ask only about what they left open.

4. **Run the rounds** per `skills/section-decisions/references/decision-rounds.md`
   — Shape (whole page, one exchange), Treatment (batched 3–4 sections per
   exchange, most consequential first), Signature (at most one) — under the exchange cap that
   reference sets; "decide the rest for me" offered at every one. Stage options
   through the surfaces that own staging — `taskmaster:visual-decisions` for the
   consent gate and mockups, `/design-preview:preview` or `/shadcn-studio:stage`
   for real components, `/ui-ux:theme` when colour is the decision — and degrade
   to written multiple-choice when none is installed. Headless: auto-decide the
   whole agenda, mark every row `auto`, print the result.

5. **Write the ledger** per `skills/section-decisions/references/section-ledger.md`
   — one row per agenda item (`slot`, `section`, `choice`, `locks`, `why`,
   `source`), in the run's working area, never in the shipped tree.

6. **Thread it.** Inside `/craft-layer:craft`, amend the build task `design-research` wrote —
   adding each row's `Decided` + `Locks` lines — before it reaches `/ui-ux:build`, so the
   picks reach the build rather than sitting in a file. Standalone, with no build task in
   play, report the ledger path plus the `/ui-ux:build` invocation to construct from it.
   Either way, report the count of `user` vs `auto` rows and the next command to run.

## Notes

- Decides SECTION treatment, not requirements — a taskmaster spec is consumed,
  never re-interrogated.
- Every staging surface is optional; the agenda, rounds, ledger, and the audit's
  conformance gate work without any of them installed.
- `/craft-layer:audit` checks the built page against the ledger when one exists.
