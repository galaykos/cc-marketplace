---
name: design
description: Use when drafting UI directions for a screen, flow, landing page or feature before any code — 2-4 artboards on one local canvas with editable text and adjustment knobs, the pick and edits pasted back as a prompt. Structural divergence, real content, one signature element, a11y floor. Reached by /design-kit:design.
---

<!-- host-ok --> The host's own `/design` publishes artboards to claude.ai as an artifact and
needs a signed-in session. This skill draws the same kind of board into local files under
`.design-kit/boards/`, served on your own machine, and never uploads. Use the host's when
you want the claude.ai canvas; use this when the board must stay on disk, work offline, or
feed the rest of this plugin.

## What a board is

One HTML file: 2–4 artboards side by side on a pan/zoom canvas, each a **different
structural answer** to the same brief, each framed at a device size, each with a title and
a one-line trade-off. The reader edits text in place, moves knobs, picks one, and clicks
"Copy edits as prompt"; the text that lands back in the session is the decision. Mockups
are for deciding — the pick is implemented with the project's own components, not by
pasting the artboard's HTML into the tree.

## Procedure

1. **Read the brief for the job, the audience, and the one metric.** If the brief names
   none, propose all three in one line and continue; do not draft against a subject you
   have not named.
2. **Choose the axis of divergence** before writing any HTML. Directions differ on
   structure — navigation model, information hierarchy, density, primary action
   placement, what is on the first screen — never on colour or radius (the knobs do that
   for free, and two artboards that differ only by palette waste the reader's comparison).
   Write each artboard's `tradeoff` line first; if you cannot state what a direction
   costs, it is not a direction.
3. **Write the spec** (`references/spec-format.md`) to `.design-kit/boards/<slug>.spec.json`
   using the primitives in `references/primitives.md`. Real names, real numbers, real
   copy in the product's voice. Every artboard shows the populated state; at most one
   shows a dialog; put empty/loading/error states in the direction whose trade-off
   depends on them.
4. **Give each artboard one signature element** — the thing a reader remembers — and keep
   everything else quiet. Spend the `css` field on that element, not on decoration.
5. **Build and serve**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/dk.sh board <spec>` builds,
   starts or reuses the server and prints `url=`; give the user that URL. The builder
   refuses lorem, external assets and artboard counts outside 2–4 — fix the spec, do
   not work around the gate.
6. **Ask for the pick** with the URL in hand. The board records every pick, knob move and
   text edit to the local server as it happens (loopback only; a phone on the LAN is
   not recorded). Offer via AskUserQuestion: read my pick (`dk.sh decision --board
   <board> --consume`) · pick an artboard · revise one direction · add a direction ·
   stop. The read-back and the pasted "Copy edits as prompt" text are the same prose;
   read it literally — knob values and text edits are requirements now, a global knob
   applies to every artboard, a scoped one to its artboard only.
7. **Hand off**: with a pick, `dk.sh decision --record "…"` writes one line to
   `design-system/DECISIONS.md`; then run `/design-kit:in-codebase` with no arguments
   (it reads the same pick) or the project's UI plugin's build command. Export PNG or
   PDF (`dk.sh export <board> --png|--pdf`) only when someone outside the session needs it.

## Rules the draft gets wrong from memory

- **Same layout, three palettes** is one direction shown three times. Change the
  structure; leave colour to the hue knob. *Standing: agent-graded.*
- **Placeholder content** hides layout problems — a real 34-character vendor name breaks
  a column that "Vendor name" never will. The builder blocks lorem; it cannot see "Item
  1 / Item 2". *Standing: gate for lorem, agent-graded for the rest.*
- **The first screen carries the direction.** A landing page's hero, a tool's first
  row: open with the most characteristic thing, not a generic stat strip.
- **Default tells** read as generated: an all-caps eyebrow over every heading, numbered
  01/02/03 markers on content that is not a sequence, a gradient wash as decoration, an
  arrow glued to every link. Use each only when the content asks for it.
- **Accessibility floor is not a knob.** 44px targets (`dk-btn`, `dk-input` default),
  visible focus (the shell provides it), body text on `--dk-bg` at the shell's contrast,
  `aria-current` on the active nav item, labels bound to inputs. A hand-written body can
  undo all of it; check yours. *Standing: recorded — nothing here measures contrast; the
  craft-layer audit does when it is installed.*
- **Copy is design.** Buttons name their consequence; empty states invite an action;
  errors say what happened and what to do. Sentence case, no filler.
- **Do not ship the board.** Artboard HTML is a decision aid; its classes and CSS
  variables exist only in the shell. Implementation starts from the project's tokens and
  components.

## The knobs, and their limits

Spacing base (6–14px), corner radius (0–24px), accent hue (0–360°), type scale
(×0.85–1.25), density (×0.85–1.2), light/dark — global or per artboard, persisted in the
browser's localStorage per board file, so a reload keeps them and a different browser
does not. They restyle the shell's primitives only; a body's inline styles ignore them.
The hue knob rotates the accent and keeps its saturation and lightness, so a brand whose
accent is a near-neutral needs the token file (`design-system/tokens.json`) rather than the
knob. Text edits persist the same way and are reported as `was → now` pairs; an edit that
restores the original text drops out of the report.

## When not to use this

A colour decision alone → `/ui-ux:theme`. A page whose shape is settled and only needs
building → the UI plugin's build command. A choice between two API payload shapes or a
schema → a table in chat, not artboards. A flow across many screens → draft the two or
three screens that differ, not all of them.
