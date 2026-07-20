---
name: experience-walkthrough
description: Use when a clarified task spans a whole experience — multiple screens, states, or a cross-screen flow — after per-screen visual decisions: assembles the picks into one clickable demo on the live preview URL, walks it end-to-end, feeds gaps into the ambiguity ledger before the spec freezes.
---

## A different job than visual-decisions

visual-decisions picks BETWEEN options, one axis at a time. This skill validates
the ASSEMBLED whole: the accepted layout picks, wired together as a clickable
flow, walked end-to-end. Per-screen picks can each be right while the experience
is wrong — a signup that collects data screen 2 already asked for, a success
page with no way back, a flow whose happy path is seven clicks. Those bugs are
invisible until someone clicks through, and they cost a rebuild if the spec
freezes first.

Trigger threshold: three or more screens/states, or any flow where sequence
itself is a requirement. A single widget or page stays in visual-decisions.

## The demo artifact

One self-contained HTML file — `taskmaster-docs/mockups/YYYY-MM-DD-<slug>-walkthrough.html`,
copied to `walkthrough.html` on the same session preview server (port
`${PREVIEW_PORT:-8123}`, see visual-decisions; own file so it never clobbers the
mockup tab):

- Every screen is a `<section>`; navigation is anchor links + CSS `:target` —
  the zero-JS baseline that works over `file://`.
- Unlike visual-decisions mockups, MINIMAL vanilla JS is allowed here, capped
  at state visibility: toggling a screen's empty/loading/error/success variants,
  a fake submit that advances the flow, tab switches. If the JS computes
  anything, you are building the feature early — stop.
- Same hygiene as all mockups: inline CSS, system fonts, zero external
  requests, realistic data ("3 invoices, one overdue"), no lorem ipsum.
- Reuse the mockups' visual system, do not re-derive it: copy the shell's
  primitive CSS block (theme tokens + the `vd-*` primitives) into the walkthrough
  file — strip the compare-mode chrome and its JS, keep the `:target`
  screen-swapping — so assembled screens render visually continuous with the
  mockups whose picks they validate, never hand-written CSS in a rival look.
- Fidelity stays mockup-grade. The walkthrough validates FLOW; polishing pixels
  here is procrastination with a preview URL.

## Coverage rules

The demo is complete when it can answer "what happens next" from anywhere:

- Every screen in the accepted flow is present — including the ones nobody
  drew because they felt obvious (confirmation, empty first-run, logged-out
  view of a shared link).
- Every terminal state exists: the success end AND the worst failure end
  (payment declined, validation rejected, session expired mid-flow).
- Entry and exit are explicit: where the user arrives from, where each screen
  lets them go. A screen with no exit is a finding, not an oversight.
- State variants that change behavior get a toggle: empty vs populated list,
  first visit vs returning.

## The walkthrough protocol

1. Hand over the URL with a task script, not a tour: "You just got the invite
   email. Get from the landing page to a configured account" — real goals
   expose navigation the way a feature demo never does.
2. The user clicks through and narrates; you collect every hesitation, wrong
   click, and "wait, where do I…" verbatim.
3. Each friction point becomes a ledger row: UNKNOWN if it needs a user
   decision ("should plan selection come before or after team invite?"),
   ASSUMED if you can name a default fix.
4. Fix the demo in place — same file, same URL, the open tab reloads — and
   re-walk only the changed stretch.
5. Budget: two full passes. A third pass means an upstream decision is
   unsettled — go back to the grill rounds instead of iterating the demo.

Under `ULTRA-GOAL ACTIVE` the walkthrough is self-driven: the model walks the task
script itself and folds every discovered gap into the ledger as an ASSUMED row.

## The narrow-viewport pass

Flows break differently at phone width: navigation collapses, side-by-side
steps stack into a scroll, the "next" button falls below the fold. When the
experience will be used on mobile:

- Walk the demo once more at ~375px (resize the window, or open the preview
  URL on a phone via the LAN-bind option in visual-decisions).
- Mockup-grade responsiveness is enough — stacked sections, readable tap
  targets. The question is "does the SEQUENCE still work this narrow", not
  "is the CSS production-ready".
- A step that only works with hover, or an exit that only exists in a wide
  layout, is a ledger row.

## Feeding the pipeline

- The accepted walkthrough file path goes into the spec as the experience
  record; screens map to spec sections, and later to task cards — a card per
  screen or per state cluster keeps cards single-prompt sized.
- Cross-screen contracts the demo exposed (what data screen 3 assumes screen 1
  collected) are written into the spec explicitly — they are exactly the
  interfaces two cards will later disagree on if left implicit.
- The demo is throwaway after spec freeze: no production code is copied from
  it. Its JS is visibility toggling, not implementation.

## Boundaries

- No framework, no build step, no real network calls, no persistence. The
  moment the demo needs npm, it stopped being a demo.
- Not a substitute for per-screen decisions — variants still get decided in
  visual-decisions first; the walkthrough assembles winners, it does not
  audition candidates.
- Not usability research at scale — one user, the requester, deciding their
  own product. Findings are requirements, not statistics.

## Anti-patterns

- Freezing a multi-screen spec nobody has clicked through — the skill exists
  because prose flows lie.
- Auditioning layout variants inside the walkthrough — that is
  visual-decisions' job, one axis at a time, before assembly.
- JS beyond show/hide: form validation logic, data transforms, fetch calls.
- Happy-path-only demos — the failure exits are where flows actually break.
- Pixel-polishing rounds while flow questions sit open in the ledger.
- Keeping the demo alive after spec freeze as "reference implementation" —
  it is a mockup wearing a flow; archive the file, kill the server.
- A walkthrough for a one-screen task — threshold is three screens or a
  sequence requirement, not enthusiasm.
